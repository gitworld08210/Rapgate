import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

import { db, FieldValue, Timestamp, RUNTIME, paths } from "./config";
import { createFine } from "./fines";

const TZ = "Asia/Kolkata";

/**
 * Nightly check: for every user, did they complete a verified push-up session
 * in the last 24h, or settle a fine? If not, break the streak and raise a fine.
 *
 * Runs just after local midnight.
 */
export const dailyPushupCheck = onSchedule(
  { schedule: "5 0 * * *", timeZone: TZ, region: RUNTIME.region },
  async () => {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const users = await db.collection("users").select().get();

    logger.info("dailyPushupCheck starting", { userCount: users.size });

    let missed = 0;

    for (const userDoc of users.docs) {
      const uid = userDoc.id;
      try {
        const verified = await paths
          .pushupSessions(uid)
          .where("status", "==", "verified")
          .where("completedAt", ">=", Timestamp.fromDate(cutoff))
          .limit(1)
          .get();

        if (!verified.empty) continue; // did the work

        // An approved fine in the window also counts as settled.
        const paid = await paths
          .fines(uid)
          .where("status", "==", "approved")
          .where("reviewedAt", ">=", Timestamp.fromDate(cutoff))
          .limit(1)
          .get();

        if (!paid.empty) continue;

        // Missed: break the streak and raise a fine.
        await paths.streaks(uid).set(
          { currentPushupStreak: 0 },
          { merge: true }
        );

        await createFine(uid, "pushup_skipped");
        await notifyAccountabilityContact(uid);
        missed++;
      } catch (e) {
        logger.error("dailyPushupCheck failed for user", { uid, error: String(e) });
      }
    }

    logger.info("dailyPushupCheck done", { missed });
  }
);

/**
 * Reminder an hour before the daily deadline, for anyone who hasn't yet
 * completed a verified session today.
 */
export const sendPreLockReminder = onSchedule(
  { schedule: "0 23 * * *", timeZone: TZ, region: RUNTIME.region },
  async () => {
    const since = new Date(Date.now() - 23 * 60 * 60 * 1000);
    const users = await db.collection("users").get();

    for (const userDoc of users.docs) {
      const uid = userDoc.id;
      try {
        const verified = await paths
          .pushupSessions(uid)
          .where("status", "==", "verified")
          .where("completedAt", ">=", Timestamp.fromDate(since))
          .limit(1)
          .get();

        if (!verified.empty) continue;

        const tokens: string[] = userDoc.get("fcmTokens") ?? [];
        if (tokens.length === 0) continue;

        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: "1 ghanta baaki hai 💪",
            body: "Push-ups complete karo warna apps lock ho jayenge aur fine lagega.",
          },
          data: { type: "pre_lock_reminder", channel: "pushup_reminders" },
          android: { priority: "high" },
        });
      } catch (e) {
        logger.warn("Reminder failed", { uid, error: String(e) });
      }
    }
  }
);

/** Notifies an opted-in accountability contact that a streak broke. */
async function notifyAccountabilityContact(uid: string): Promise<void> {
  try {
    const link = await paths.accountability(uid).get();
    if (!link.exists || link.get("notifyOnMiss") !== true) return;

    const contactUid = link.get("linkedContactUid") as string | undefined;
    if (!contactUid) return; // phone-only contacts would need an SMS provider

    const contact = await paths.user(contactUid).get();
    const tokens: string[] = contact.get("fcmTokens") ?? [];
    if (tokens.length === 0) return;

    const name = (await paths.user(uid).get()).get("name") ?? "Your friend";

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Accountability nudge",
        body: `${name} missed their push-ups today.`,
      },
      data: { type: "accountability_miss", channel: "streaks" },
    });
  } catch (e) {
    logger.warn("Accountability notify failed", { uid, error: String(e) });
  }
}

/** Opt in / out of an accountability contact. */
export const setAccountabilityContact = onCall(RUNTIME, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const notifyOnMiss = request.data?.notifyOnMiss === true;
  const contactPhone =
    typeof request.data?.contactPhone === "string"
      ? request.data.contactPhone.trim().slice(0, 20)
      : null;
  const contactName =
    typeof request.data?.contactName === "string"
      ? request.data.contactName.trim().slice(0, 80)
      : null;

  // Resolve a phone number to an existing app user, so notifications can be
  // delivered in-app rather than needing an SMS gateway.
  let linkedContactUid: string | null = null;
  if (contactPhone) {
    try {
      const contact = await admin.auth().getUserByPhoneNumber(contactPhone);
      linkedContactUid = contact.uid;
    } catch {
      linkedContactUid = null; // not an app user — stored for reference only
    }
  }

  await paths.accountability(uid).set(
    {
      notifyOnMiss,
      contactPhone,
      contactName,
      linkedContactUid,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { saved: true, linkedToAppUser: linkedContactUid !== null };
});

/**
 * Registers an FCM token against the user so the server can reach them.
 * Tokens are deduplicated and capped to avoid unbounded growth.
 */
export const registerFcmToken = onCall(RUNTIME, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const token = String(request.data?.token ?? "");
  if (!token) throw new HttpsError("invalid-argument", "token is required.");

  await paths.user(uid).set(
    { fcmTokens: FieldValue.arrayUnion(token) },
    { merge: true }
  );

  return { registered: true };
});
