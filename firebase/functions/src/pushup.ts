import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import {
  db,
  FieldValue,
  Timestamp,
  RUNTIME,
  paths,
  PUSHUP,
  hoursFromNow,
  startOfLocalDay,
} from "./config";

/**
 * Server-authoritative push-up verification.
 *
 * The client's self-reported rep count is IGNORED entirely. The client streams
 * per-frame elbow angles and face-visibility flags; this module recomputes the
 * rep count from that sequence and applies the anti-cheat envelope.
 *
 * What this can and cannot catch — stated honestly:
 *   CAN  — partial-range reps, inhuman cadence, a hidden face, a propped-up
 *          phone replaying a looped video, duplicated frames.
 *   CANNOT — a genuinely different person doing the push-ups, or a
 *          sufficiently sophisticated synthetic landmark stream. This is a
 *          commitment device, not biometric attestation.
 *
 * STORAGE DESIGN — a session is submitted in ~10s batches. An earlier version
 * appended every frame to a `rawSamples` array on the session document and
 * re-read/re-wrote the whole array on each batch. That was O(n²) in data
 * transfer over a session and would eventually breach Firestore's 1 MiB
 * per-document limit, failing the write outright mid-workout.
 *
 * Instead we persist only [SessionVerifyState]: a fixed-size carry-over of the
 * rep-counting state machine plus running aggregates. Its size does not grow
 * with session length, so each batch is a small constant-cost write.
 */

interface FrameSample {
  timestamp: number;
  avgElbowAngle: number | null;
  faceVisible: boolean;
}

/**
 * Everything needed to resume rep counting on the next batch, and to produce
 * the final summary — without retaining any raw frames.
 */
interface SessionVerifyState {
  reps: number;
  phase: "up" | "down";
  reachedFlexion: boolean;
  phaseStartTs: number;
  framesInCycle: number;

  totalFrames: number;
  framesWithFace: number;

  angleFrames: number;
  duplicateAngleFrames: number;

  repDurationSumMs: number;
  repDurationCount: number;

  minAngle: number | null;
  maxAngle: number | null;

  /** Bounded sliding window of recent angle fingerprints, for loop detection. */
  recentAngleKeys: string[];
}

/** Size of the loop-detection window. Bounded so the doc stays small. */
const DUP_WINDOW = 60;

function initialState(): SessionVerifyState {
  return {
    reps: 0,
    phase: "up",
    reachedFlexion: false,
    phaseStartTs: 0,
    framesInCycle: 0,
    totalFrames: 0,
    framesWithFace: 0,
    angleFrames: 0,
    duplicateAngleFrames: 0,
    repDurationSumMs: 0,
    repDurationCount: 0,
    minAngle: null,
    maxAngle: null,
    recentAngleKeys: [],
  };
}

/** Computes the adaptive target from streak length. */
export function computeTarget(currentStreak: number): number {
  const weeks = Math.floor(Math.max(0, currentStreak) / 7);
  const target = PUSHUP.baseTarget + weeks * PUSHUP.incrementPerWeek;
  return Math.min(target, PUSHUP.maxTarget);
}

export const startPushupSession = onCall(RUNTIME, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const streakSnap = await paths.streaks(uid).get();
  const currentStreak = (streakSnap.get("currentPushupStreak") as number) ?? 0;
  const requiredReps = computeTarget(currentStreak);

  const ref = await paths.pushupSessions(uid).add({
    status: "pending",
    requiredReps,
    repCount: 0,
    faceVisibleCheck: false,
    angleValidCheck: false,
    poseLandmarkSummary: null,
    verifyState: initialState(),
    startedAt: FieldValue.serverTimestamp(),
    completedAt: null,
    unlockGrantedUntil: null,
    rejectionReason: null,
  });

  logger.info("Push-up session started", { uid, requiredReps });

  return { sessionId: ref.id, requiredReps };
});

/**
 * Recounts reps from an incremental landmark batch and, once the target is
 * genuinely met, marks the session verified and grants the unlock.
 */
export const submitPushupFrameBatch = onCall(RUNTIME, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const sessionId = String(request.data?.sessionId ?? "");
  const batch = request.data?.poseLandmarkBatch;
  const meta = request.data?.frameMeta ?? {};

  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (!Array.isArray(batch)) {
    throw new HttpsError(
      "invalid-argument",
      "poseLandmarkBatch must be a list."
    );
  }
  // Bound the payload so a client cannot exhaust the function.
  if (batch.length > 2000) {
    throw new HttpsError("invalid-argument", "Batch too large.");
  }

  const ref = paths.pushupSessions(uid).doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }
  if (snap.get("status") === "verified") {
    return {
      currentValidatedReps: snap.get("repCount") ?? 0,
      sessionComplete: true,
    };
  }

  const requiredReps =
    (snap.get("requiredReps") as number) ?? PUSHUP.baseTarget;

  // ---------------- normalise this batch only ----------------
  const samples: FrameSample[] = batch
    .map((f: Record<string, unknown>) => ({
      timestamp: Number(f?.timestamp ?? 0),
      avgElbowAngle:
        f?.avgElbowAngle === null || f?.avgElbowAngle === undefined
          ? null
          : Number(f.avgElbowAngle),
      faceVisible: f?.faceVisible === true,
    }))
    .filter((f) => Number.isFinite(f.timestamp) && f.timestamp > 0)
    .sort((a, b) => a.timestamp - b.timestamp);

  // Resume from the carried state; no raw frames are ever retained.
  const prior =
    (snap.get("verifyState") as SessionVerifyState | undefined) ??
    initialState();

  const state = advanceVerification(prior, samples);
  const verdict = evaluate(state, meta);

  const complete = state.reps >= requiredReps && verdict.ok;

  if (complete) {
    const unlockUntil = hoursFromNow(PUSHUP.unlockHours);

    await db.runTransaction(async (tx) => {
      tx.update(ref, {
        status: "verified",
        repCount: state.reps,
        faceVisibleCheck: verdict.faceOk,
        angleValidCheck: verdict.angleOk,
        poseLandmarkSummary: summarise(state),
        completedAt: FieldValue.serverTimestamp(),
        unlockGrantedUntil: Timestamp.fromDate(unlockUntil),
        rejectionReason: null,
        // The carry-over state has served its purpose.
        verifyState: FieldValue.delete(),
      });

      tx.set(
        paths.blockedAppsConfig(uid),
        {
          lastUnlockedAt: FieldValue.serverTimestamp(),
          unlockGrantedUntil: Timestamp.fromDate(unlockUntil),
          unlockSource: "pushup_verified",
        },
        { merge: true }
      );
    });

    await bumpStreak(uid);

    logger.info("Push-up session verified", {
      uid,
      sessionId,
      reps: state.reps,
    });
  } else {
    await ref.update({
      repCount: state.reps,
      faceVisibleCheck: verdict.faceOk,
      angleValidCheck: verdict.angleOk,
      verifyState: state,
      rejectionReason: verdict.ok ? null : verdict.reason,
    });
  }

  return {
    currentValidatedReps: state.reps,
    sessionComplete: complete,
    ...(verdict.ok ? {} : { rejectionReason: verdict.reason }),
  };
});

/**
 * Folds a batch of samples into the running state.
 *
 * A rep only counts on a complete extended → flexed → extended cycle, which is
 * what defeats "hover near the threshold" partial-motion spoofing.
 */
export function advanceVerification(
  prior: SessionVerifyState,
  samples: FrameSample[]
): SessionVerifyState {
  // Copy so the caller's object is never mutated.
  const s: SessionVerifyState = {
    ...prior,
    recentAngleKeys: [...(prior.recentAngleKeys ?? [])],
  };

  for (const sample of samples) {
    s.totalFrames++;
    if (sample.faceVisible) s.framesWithFace++;

    const angle = sample.avgElbowAngle;
    if (angle === null || !Number.isFinite(angle)) continue;

    s.angleFrames++;

    // --- loop / duplicate-frame detection over a bounded window ---
    const key = angle.toFixed(3);
    if (s.recentAngleKeys.includes(key)) s.duplicateAngleFrames++;
    s.recentAngleKeys.push(key);
    if (s.recentAngleKeys.length > DUP_WINDOW) s.recentAngleKeys.shift();

    // --- range tracking ---
    s.minAngle = s.minAngle === null ? angle : Math.min(s.minAngle, angle);
    s.maxAngle = s.maxAngle === null ? angle : Math.max(s.maxAngle, angle);

    // Seed the phase clock on the very first angle frame.
    if (s.phaseStartTs === 0) s.phaseStartTs = sample.timestamp;

    s.framesInCycle++;

    // --- rep state machine ---
    if (s.phase === "up" && angle <= PUSHUP.minElbowAngleFlexed) {
      s.phase = "down";
      s.reachedFlexion = true;
    } else if (
      s.phase === "down" &&
      angle >= PUSHUP.maxElbowAngleExtended &&
      s.reachedFlexion
    ) {
      const duration = sample.timestamp - s.phaseStartTs;
      if (
        duration >= PUSHUP.minMsPerRep &&
        duration <= PUSHUP.maxMsPerRep &&
        s.framesInCycle >= PUSHUP.minFramesPerRep
      ) {
        s.reps++;
        s.repDurationSumMs += duration;
        s.repDurationCount++;
      }
      s.phase = "up";
      s.phaseStartTs = sample.timestamp;
      s.framesInCycle = 0;
      s.reachedFlexion = false;
    }
  }

  return s;
}

/** Applies the anti-cheat envelope to the accumulated state. */
export function evaluate(
  s: SessionVerifyState,
  meta: Record<string, unknown>
): {
  ok: boolean;
  reason: string | null;
  faceOk: boolean;
  angleOk: boolean;
} {
  const faceRatio =
    s.totalFrames === 0 ? 0 : s.framesWithFace / s.totalFrames;
  const faceOk = faceRatio >= PUSHUP.faceVisibilityRatio;
  const angleOk = s.angleFrames > 0 && s.reps > 0;

  const duplicateRatio =
    s.angleFrames === 0 ? 0 : s.duplicateAngleFrames / s.angleFrames;
  const motionVariance = Number(meta?.motionVariance ?? 0);

  let reason: string | null = null;

  if (s.totalFrames < PUSHUP.minFramesPerRep) {
    reason = "Not enough camera data was captured.";
  } else if (!faceOk) {
    reason =
      "Your face was not visible for enough of the session. Keep it in frame.";
  } else if (duplicateRatio > 0.5 && s.angleFrames > 30) {
    // A looped video repeats identical values within a short window; genuine
    // movement rarely does. Checking a sliding window rather than global
    // uniqueness avoids falsely flagging long honest sessions, which naturally
    // revisit similar angles many times.
    reason = "The camera feed looked repetitive. Please do the session live.";
  } else if (motionVariance > 0 && motionVariance < PUSHUP.minMotionVariance) {
    reason =
      "No device movement was detected. Hold or strap the phone to your body.";
  } else if (s.reps === 0 && s.angleFrames > 30) {
    reason =
      "No full push-ups detected — go all the way down and fully extend.";
  }

  return { ok: reason === null, reason, faceOk, angleOk };
}

/** Small, human-readable record of how the session was judged. */
function summarise(s: SessionVerifyState): Record<string, unknown> {
  return {
    totalFrames: s.totalFrames,
    framesWithAngle: s.angleFrames,
    faceVisibleRatio:
      s.totalFrames === 0
        ? 0
        : Number((s.framesWithFace / s.totalFrames).toFixed(3)),
    duplicateAngleRatio:
      s.angleFrames === 0
        ? 0
        : Number((s.duplicateAngleFrames / s.angleFrames).toFixed(3)),
    avgRepMs:
      s.repDurationCount === 0
        ? null
        : Math.round(s.repDurationSumMs / s.repDurationCount),
    minAngle: s.minAngle,
    maxAngle: s.maxAngle,
  };
}

/** Extends the streak, at most once per local day. */
export async function bumpStreak(uid: string): Promise<void> {
  const ref = paths.streaks(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const today = startOfLocalDay(new Date());

    // Read structurally rather than casting to the Timestamp type: `Timestamp`
    // is re-exported from config as a value, not a type.
    const lastRaw = snap.get("lastPushupDate") as
      | { toDate?: () => Date }
      | undefined;
    const last = lastRaw?.toDate?.();

    if (last && startOfLocalDay(last).getTime() === today.getTime()) {
      return; // already counted today
    }

    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const continued =
      last && startOfLocalDay(last).getTime() === yesterday.getTime();

    const current = continued
      ? ((snap.get("currentPushupStreak") as number) ?? 0) + 1
      : 1;
    const longest = Math.max(
      current,
      (snap.get("longestPushupStreak") as number) ?? 0
    );

    tx.set(
      ref,
      {
        currentPushupStreak: current,
        longestPushupStreak: longest,
        lastPushupDate: Timestamp.fromDate(new Date()),
      },
      { merge: true }
    );

    // Adaptive difficulty rides on the streak.
    tx.set(
      paths.user(uid),
      { pushupTarget: computeTarget(current) },
      { merge: true }
    );
  });
}
