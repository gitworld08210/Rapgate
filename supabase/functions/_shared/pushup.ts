export const PUSHUP = {
  baseTarget: 10,
  maxTarget: 25,
  incrementPerWeek: 1,
  unlockHours: 24,
  minElbowAngleFlexed: 90,
  maxElbowAngleExtended: 150,
  // 0.9 was unreachable in practice: the head naturally drops and turns during
  // a rep, so ML Kit loses the eye landmarks for a chunk of every set and every
  // honest session was rejected with "face was not visible".
  faceVisibilityRatio: 0.7,
  minMsPerRep: 800,
  maxMsPerRep: 8000,
  minMotionVariance: 0.01,
  minFramesPerRep: 4,
} as const;

export interface FrameSample {
  timestamp: number;
  avgElbowAngle: number | null;
  faceVisible: boolean;
}

export interface SessionVerifyState {
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
  recentAngleKeys: string[];
}

export function initialState(): SessionVerifyState {
  return { reps: 0, phase: "up", reachedFlexion: false, phaseStartTs: 0, framesInCycle: 0, totalFrames: 0, framesWithFace: 0, angleFrames: 0, duplicateAngleFrames: 0, repDurationSumMs: 0, repDurationCount: 0, minAngle: null, maxAngle: null, recentAngleKeys: [] };
}

export function computeTarget(currentStreak: number): number {
  return Math.min(PUSHUP.maxTarget, PUSHUP.baseTarget + Math.floor(Math.max(0, currentStreak) / 7) * PUSHUP.incrementPerWeek);
}

export function normaliseBatch(value: unknown): FrameSample[] {
  if (!Array.isArray(value) || value.length > 2000) throw new Error("poseLandmarkBatch must be a list of at most 2000 frames.");
  return value.map((raw) => {
    const frame = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
    return { timestamp: Number(frame.timestamp ?? 0), avgElbowAngle: frame.avgElbowAngle === null || frame.avgElbowAngle === undefined ? null : Number(frame.avgElbowAngle), faceVisible: frame.faceVisible === true };
  }).filter((sample) => Number.isFinite(sample.timestamp) && sample.timestamp > 0).sort((a, b) => a.timestamp - b.timestamp);
}

export function advanceVerification(prior: SessionVerifyState, samples: FrameSample[]): SessionVerifyState {
  const s: SessionVerifyState = { ...initialState(), ...prior, recentAngleKeys: [...(prior.recentAngleKeys ?? [])] };
  for (const sample of samples) {
    s.totalFrames++;
    if (sample.faceVisible) s.framesWithFace++;
    const angle = sample.avgElbowAngle;
    if (angle === null || !Number.isFinite(angle)) continue;
    s.angleFrames++;
    const key = angle.toFixed(3);
    if (s.recentAngleKeys.includes(key)) s.duplicateAngleFrames++;
    s.recentAngleKeys.push(key);
    if (s.recentAngleKeys.length > 60) s.recentAngleKeys.shift();
    s.minAngle = s.minAngle === null ? angle : Math.min(s.minAngle, angle);
    s.maxAngle = s.maxAngle === null ? angle : Math.max(s.maxAngle, angle);
    if (s.phaseStartTs === 0) s.phaseStartTs = sample.timestamp;
    s.framesInCycle++;
    if (s.phase === "up" && angle <= PUSHUP.minElbowAngleFlexed) {
      s.phase = "down";
      s.reachedFlexion = true;
      // Time the rep from the start of the descent. Previously phaseStartTs was
      // seeded on the very first frame of the session, so however long the user
      // spent getting into position was billed to rep #1 -- routinely pushing it
      // past maxMsPerRep and silently discarding it.
      s.phaseStartTs = sample.timestamp;
      s.framesInCycle = 1;
    } else if (s.phase === "down" && angle >= PUSHUP.maxElbowAngleExtended && s.reachedFlexion) {
      const duration = sample.timestamp - s.phaseStartTs;
      if (duration >= PUSHUP.minMsPerRep && duration <= PUSHUP.maxMsPerRep && s.framesInCycle >= PUSHUP.minFramesPerRep) {
        s.reps++; s.repDurationSumMs += duration; s.repDurationCount++;
      }
      s.phase = "up"; s.phaseStartTs = sample.timestamp; s.framesInCycle = 0; s.reachedFlexion = false;
    }
  }
  return s;
}

export function evaluate(s: SessionVerifyState, meta: Record<string, unknown>): { ok: boolean; reason: string | null; faceOk: boolean; angleOk: boolean } {
  const faceOk = s.totalFrames > 0 && s.framesWithFace / s.totalFrames >= PUSHUP.faceVisibilityRatio;
  const angleOk = s.angleFrames > 0 && s.reps > 0;
  const duplicateRatio = s.angleFrames === 0 ? 0 : s.duplicateAngleFrames / s.angleFrames;
  const motionVariance = Number(meta.motionVariance ?? 0);
  let reason: string | null = null;
  if (s.totalFrames < PUSHUP.minFramesPerRep) reason = "Not enough camera data was captured.";
  else if (!faceOk) reason = "Your face was not visible for enough of the session. Keep it in frame.";
  else if (duplicateRatio > 0.5 && s.angleFrames > 30) reason = "The camera feed looked repetitive. Please do the session live.";
  else if (motionVariance > 0 && motionVariance < PUSHUP.minMotionVariance) reason = "No device movement was detected. Hold or strap the phone to your body.";
  else if (s.reps === 0 && s.angleFrames > 30) reason = "No full push-ups detected — go all the way down and fully extend.";
  return { ok: reason === null, reason, faceOk, angleOk };
}

export function summarise(s: SessionVerifyState): Record<string, unknown> {
  return { totalFrames: s.totalFrames, framesWithAngle: s.angleFrames, faceVisibleRatio: s.totalFrames === 0 ? 0 : Number((s.framesWithFace / s.totalFrames).toFixed(3)), duplicateAngleRatio: s.angleFrames === 0 ? 0 : Number((s.duplicateAngleFrames / s.angleFrames).toFixed(3)), avgRepMs: s.repDurationCount === 0 ? null : Math.round(s.repDurationSumMs / s.repDurationCount), minAngle: s.minAngle, maxAngle: s.maxAngle };
}
