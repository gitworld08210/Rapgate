import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export const storage = admin.storage();
export const FieldValue = admin.firestore.FieldValue;
export const Timestamp = admin.firestore.Timestamp;

/** Shared runtime options — keep instances low for a personal-scale app. */
export const RUNTIME = {
  region: "asia-south1" as const,
  maxInstances: 10,
  // Project: parallaxai-7653c
};

// ---------------------------------------------------------------------------
// Domain constants. These MUST mirror lib/utils/constants.dart, but the server
// copy is the authoritative one — the client's values are only for display.
// ---------------------------------------------------------------------------

export const PUSHUP = {
  baseTarget: 10,
  maxTarget: 25,
  /** Target grows by this much per full week of unbroken streak. */
  incrementPerWeek: 1,
  unlockHours: 24,

  // Anti-cheat envelope
  minElbowAngleFlexed: 90, // must bend at least to here
  maxElbowAngleExtended: 150, // must straighten at least to here
  faceVisibilityRatio: 0.9, // ≥90% of frames must show a face
  minMsPerRep: 800, // faster than this is not human
  maxMsPerRep: 8000, // slower than this is not a rep
  minMotionVariance: 0.01, // a static phone means a looped video
  minFramesPerRep: 4, // too few samples to trust
};

export const FINE_AMOUNT_PAISE = Number(
  process.env.FINE_AMOUNT_PAISE ?? 5000
);

/**
 * Emails permitted to hold the `admin` claim.
 *
 * Read from the server-only environment — never shipped to the client. The
 * account password lives exclusively in Firebase Auth and appears nowhere
 * in this codebase.
 */
export function adminEmails(): string[] {
  return (process.env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter((e) => e.length > 0);
}

export function isAdminEmail(email: string | undefined): boolean {
  if (!email) return false;
  return adminEmails().includes(email.toLowerCase());
}

// ---------------------------------------------------------------------------
// Firestore path helpers
// ---------------------------------------------------------------------------

export const paths = {
  user: (uid: string) => db.collection("users").doc(uid),
  foodLogs: (uid: string) => paths.user(uid).collection("food_logs"),
  waterLogs: (uid: string) => paths.user(uid).collection("water_logs"),
  weightLogs: (uid: string) => paths.user(uid).collection("weight_logs"),
  pushupSessions: (uid: string) =>
    paths.user(uid).collection("pushup_sessions"),
  fines: (uid: string) => paths.user(uid).collection("fines"),
  emergencyUnlocks: (uid: string) =>
    paths.user(uid).collection("emergency_unlocks"),
  blockedAppsConfig: (uid: string) =>
    paths.user(uid).collection("config").doc("blocked_apps_config"),
  streaks: (uid: string) => paths.user(uid).collection("meta").doc("streaks"),
  accountability: (uid: string) =>
    db.collection("accountability_links").doc(uid),
  adminAudit: () => db.collection("admin_audit"),
};

/** Start of the local day, in the user's own timezone offset (minutes). */
export function startOfLocalDay(date: Date, tzOffsetMinutes = 330): Date {
  const shifted = new Date(date.getTime() + tzOffsetMinutes * 60_000);
  shifted.setUTCHours(0, 0, 0, 0);
  return new Date(shifted.getTime() - tzOffsetMinutes * 60_000);
}

export function hoursFromNow(hours: number): Date {
  return new Date(Date.now() + hours * 60 * 60 * 1000);
}
