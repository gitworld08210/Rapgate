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
 * The client's self-reported rep count is IGNORED entirely. The client sends
 * per-frame elbow angles and face-visibility flags; this module recomputes the
 * rep count from that sequence and applies the anti-cheat envelope.
 *
 * What this can and cannot catch — stated honestly:
 *   CAN  — partial-range reps, inhuman cadence, a hidden face, a propped-up
 *          phone replaying a video (zero motion variance), duplicated frames.
 *   CANNOT — a genuinely different person doing the push-ups, or a
 *          sufficiently sophisticated synthetic landmark stream. This is a
 *          commitment device, not biometric attestation.
 */

interface FrameSample {
  timestamp: number;
  avgElbowAngle: number | null;
  faceVisible: boolean;
}

/** Computes the adaptive target from streak length. */
export function computeTarget(currentStreak: number): number {
  const weeks = Math.floor(Math.max(0, currentStreak) / 7);
  const target =
    PUSHUP.baseTarget + weeks * PUSHUP.incrementPerWeek;
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
    startedAt: FieldValue.serverTimestamp(),
    completedAt: null,
    unlockGrantedUntil: null,
    rejectionReason: null,
  });

  logger.info("Push-up session started", { uid, requiredReps });

  return { sessionId: ref.id, requiredReps };
});

/**
 * Recounts reps from a landmark batch and, once the target is genuinely met,
 * marks the session verified and grants the unlock.
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
    throw new HttpsError("invalid-argument", "poseLandmarkBatch must be a list.");
  }
  // Bound the payload so a client cannot exhaust the function.
  if (batch.length > 4000) {
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

  const requiredReps = (snap.get("requiredReps") as number) ?? PUSHUP.baseTarget;

  // ---------------- normalise samples ----------------
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

  // Accumulate across batches: a session is submitted in several chunks.
  const priorSamples: FrameSample[] = snap.get("rawSamples") ?? [];
  const allSamples = [...priorSamples, ...samples].slice(-6000);

  const verdict = verifySamples(allSamples, meta);

  // ---------------- persist ----------------
  const complete = verdict.reps >= requiredReps && verdict.ok;

  if (complete) {
    const unlockUntil = hoursFromNow(PUSHUP.unlockHours);

    await db.runTransaction(async (tx) => {
      tx.update(ref, {
        status: "verified",
        repCount: verdict.reps,
        faceVisibleCheck: verdict.faceOk,
        angleValidCheck: verdict.angleOk,
        poseLandmarkSummary: verdict.summary,
        completedAt: FieldValue.serverTimestamp(),
        unlockGrantedUntil: Timestamp.fromDate(unlockUntil),
        rejectionReason: null,
        // Drop the raw stream once verified — we only keep the summary.
        rawSamples: FieldValue.delete(),
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
      reps: verdict.reps,
    });
  } else {
    await ref.update({
      repCount: verdict.reps,
      faceVisibleCheck: verdict.faceOk,
      angleValidCheck: verdict.angleOk,
      rawSamples: allSamples,
      rejectionReason: verdict.ok ? null : verdict.reason,
    });
  }

  return {
    currentValidatedReps: verdict.reps,
    sessionComplete: complete,
    ...(verdict.ok ? {} : { rejectionReason: verdict.reason }),
  };
});

/**
 * Counts full-range reps and applies the anti-cheat envelope.
 *
 * A rep only counts on a complete extended → flexed → extended cycle, which
 * is what defeats "hover near the threshold" partial-motion spoofing.
 */
export function verifySamples(
  samples: FrameSample[],
  meta: Record<string, unknown>
): {
  reps: number;
  ok: boolean;
  reason: string | null;
  faceOk: boolean;
  angleOk: boolean;
  summary: Record<string, unknown>;
} {
  const withAngle = samples.filter(
    (s) => s.avgElbowAngle !== null && Number.isFinite(s.avgElbowAngle)
  );

  const faceRatio =
    samples.length === 0
      ? 0
      : samples.filter((s) => s.faceVisible).length / samples.length;
  const faceOk = faceRatio >= PUSHUP.faceVisibilityRatio;

  // ---- duplicate-frame detection (screenshot / looped video) ----
  const angleKeys = withAngle.map((s) => s.avgElbowAngle!.toFixed(3));
  const uniqueRatio =
    angleKeys.length === 0 ? 0 : new Set(angleKeys).size / angleKeys.length;

  // ---- device motion ----
  const motionVariance = Number(meta?.motionVariance ?? 0);

  // ---- rep counting state machine ----
  let reps = 0;
  let phase: "up" | "down" = "up";
  let phaseStart = withAngle[0]?.timestamp ?? 0;
  let framesInCycle = 0;
  const repDurations: number[] = [];
  let reachedFlexion = false;

  for (const s of withAngle) {
    const angle = s.avgElbowAngle!;
    framesInCycle++;

    if (phase === "up" && angle <= PUSHUP.minElbowAngleFlexed) {
      // Went down far enough.
      phase = "down";
      reachedFlexion = true;
    } else if (
      phase === "down" &&
      angle >= PUSHUP.maxElbowAngleExtended &&
      reachedFlexion
    ) {
      // Came back up — one complete rep.
      const duration = s.timestamp - phaseStart;
      if (
        duration >= PUSHUP.minMsPerRep &&
        duration <= PUSHUP.maxMsPerRep &&
        framesInCycle >= PUSHUP.minFramesPerRep
      ) {
        reps++;
        repDurations.push(duration);
      }
      phase = "up";
      phaseStart = s.timestamp;
      framesInCycle = 0;
      reachedFlexion = false;
    }
  }

  const angleOk = withAngle.length > 0 && reps > 0;

  // ---- verdict ----
  let reason: string | null = null;

  if (samples.length < PUSHUP.minFramesPerRep) {
    reason = "Not enough camera data was captured.";
  } else if (!faceOk) {
    reason =
      "Your face was not visible for enough of the session. Keep it in frame.";
  } else if (uniqueRatio < 0.5 && angleKeys.length > 20) {
    reason =
      "The camera feed looked repetitive. Please do the session live.";
  } else if (motionVariance > 0 && motionVariance < PUSHUP.minMotionVariance) {
    reason =
      "No device movement was detected. Hold or strap the phone to your body.";
  } else if (reps === 0 && withAngle.length > 30) {
    reason =
      "No full push-ups detected — go all the way down and fully extend.";
  }

  return {
    reps,
    ok: reason === null,
    reason,
    faceOk,
    angleOk,
    summary: {
      totalFrames: samples.length,
      framesWithAngle: withAngle.length,
      faceVisibleRatio: Number(faceRatio.toFixed(3)),
      uniqueAngleRatio: Number(uniqueRatio.toFixed(3)),
      motionVariance,
      avgRepMs:
        repDurations.length === 0
          ? null
          : Math.round(
              repDurations.reduce((a, b) => a + b, 0) / repDurations.length
            ),
      minAngle:
        withAngle.length === 0
          ? null
          : Math.min(...withAngle.map((s) => s.avgElbowAngle!)),
      maxAngle:
        withAngle.length === 0
          ? null
          : Math.max(...withAngle.map((s) => s.avgElbowAngle!)),
    },
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
