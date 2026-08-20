import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

import {
  db,
  FieldValue,
  Timestamp,
  RUNTIME,
  paths,
  PUSHUP,
  FINE_AMOUNT_PAISE,
  hoursFromNow,
} from "./config";
import { requireAdmin, writeAudit } from "./admin-role";

type FineStatus = "pending" | "submitted" | "approved" | "rejected";

/**
 * Manual UPI fine settlement.
 *
 * The status machine, and who is allowed to drive each transition:
 *
 *   (server)  ──create──▶  pending
 *   (user)    pending|rejected ──submit proof──▶ submitted
 *   (admin)   submitted ──approve──▶ approved   → grants 24h unlock
 *   (admin)   submitted ──reject───▶ rejected   → stays unpaid, resubmittable
 *
 * A user can never reach `approved`. Security rules block direct writes to
 * `status`, so the only path is through these functions.
 */

/** Creates a fine. Server-internal only (called by the scheduled checker). */
export async function createFine(
  uid: string,
  reason: string,
  amountPaise = FINE_AMOUNT_PAISE
): Promise<string> {
  // Don't stack duplicate fines for the same reason on the same day.
  const since = new Date(Date.now() - 20 * 60 * 60 * 1000);
  const existing = await paths
    .fines(uid)
    .where("reason", "==", reason)
    .where("createdAt", ">=", Timestamp.fromDate(since))
    .limit(1)
    .get();

  if (!existing.empty) {
    logger.info("Skipping duplicate fine", { uid, reason });
    return existing.docs[0].id;
  }

  const ref = await paths.fines(uid).add({
    uid, // denormalised so admins can run a collectionGroup query
    amount: amountPaise,
    reason,
    status: "pending" satisfies FineStatus,
    createdAt: FieldValue.serverTimestamp(),
    upiUtr: null,
    screenshotUrl: null,
    submittedAt: null,
    reviewedAt: null,
    reviewedBy: null,
    reviewNote: null,
  });

  logger.info("Fine created", { uid, reason, fineId: ref.id, amountPaise });
  return ref.id;
}

/**
 * User submits proof of a UPI payment: a UTR reference and/or a screenshot.
 * At least one is required. This only moves the fine to `submitted` — it
 * does NOT mark it paid.
 */
export const submitFineProof = onCall(RUNTIME, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const fineId = String(request.data?.fineId ?? "");
  const rawUtr = request.data?.upiUtr;
  const screenshotUrl = request.data?.screenshotUrl;

  if (!fineId) {
    throw new HttpsError("invalid-argument", "fineId is required.");
  }

  const upiUtr =
    typeof rawUtr === "string" && rawUtr.trim().length > 0
      ? rawUtr.trim().toUpperCase()
      : null;
  const shot =
    typeof screenshotUrl === "string" && screenshotUrl.length > 0
      ? screenshotUrl
      : null;

  if (!upiUtr && !shot) {
    throw new HttpsError(
      "invalid-argument",
      "Provide a UTR number or a payment screenshot."
    );
  }

  if (upiUtr && !/^[A-Z0-9]{8,24}$/.test(upiUtr)) {
    throw new HttpsError(
      "invalid-argument",
      "That UTR doesn't look valid. Check your payment app."
    );
  }

  // Reject a UTR already used on any other fine — stops one payment being
  // reused to clear several fines.
  if (upiUtr) {
    const reused = await db
      .collectionGroup("fines")
      .where("upiUtr", "==", upiUtr)
      .limit(5)
      .get();

    const clash = reused.docs.find((d) => d.id !== fineId);
    if (clash) {
      logger.warn("UTR reuse attempt", { uid, upiUtr, fineId });
      throw new HttpsError(
        "already-exists",
        "That UTR has already been submitted for another fine."
      );
    }
  }

  const ref = paths.fines(uid).doc(fineId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That fine no longer exists.");
    }

    const status = snap.get("status") as FineStatus;

    if (status === "approved") {
      throw new HttpsError(
        "failed-precondition",
        "This fine is already paid."
      );
    }
    if (status === "submitted") {
      throw new HttpsError(
        "failed-precondition",
        "Your proof is already awaiting review."
      );
    }

    tx.update(ref, {
      status: "submitted" satisfies FineStatus,
      upiUtr,
      screenshotUrl: shot,
      submittedAt: FieldValue.serverTimestamp(),
      // Clear any prior rejection so the UI doesn't show a stale reason.
      reviewNote: null,
      reviewedAt: null,
      reviewedBy: null,
    });
  });

  logger.info("Fine proof submitted", {
    uid,
    fineId,
    hasUtr: !!upiUtr,
    hasScreenshot: !!shot,
  });

  return { submitted: true };
});

/**
 * Admin approves or rejects a submitted fine.
 *
 * Approving marks the fine paid and grants a 24-hour "paid bypass" unlock.
 * Rejecting leaves it unpaid and resubmittable, with a reason for the user.
 */
export const reviewFine = onCall(RUNTIME, async (request) => {
  const actorUid = requireAdmin(request);

  const targetUid = String(request.data?.targetUid ?? "");
  const fineId = String(request.data?.fineId ?? "");
  const approve = request.data?.approve === true;
  const note =
    typeof request.data?.note === "string"
      ? String(request.data.note).slice(0, 500)
      : null;

  if (!targetUid || !fineId) {
    throw new HttpsError(
      "invalid-argument",
      "targetUid and fineId are required."
    );
  }
  if (!approve && !note) {
    throw new HttpsError(
      "invalid-argument",
      "A reason is required when rejecting."
    );
  }

  const fineRef = paths.fines(targetUid).doc(fineId);

  // Computed up-front rather than inside the transaction: the unlock window
  // doesn't depend on transaction state, and assigning it inside the callback
  // would leave TypeScript unable to narrow the type afterwards.
  const unlockUntil: Date | null = approve
    ? hoursFromNow(PUSHUP.unlockHours)
    : null;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(fineRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That fine no longer exists.");
    }

    const status = snap.get("status") as FineStatus;
    if (status !== "submitted") {
      throw new HttpsError(
        "failed-precondition",
        `Only submitted fines can be reviewed (this one is "${status}").`
      );
    }

    tx.update(fineRef, {
      status: (approve ? "approved" : "rejected") satisfies FineStatus,
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: actorUid,
      reviewNote: note,
    });

    if (approve && unlockUntil) {
      // Paid bypass: same 24h unlock a verified push-up session would grant.
      tx.set(
        paths.blockedAppsConfig(targetUid),
        {
          lastUnlockedAt: FieldValue.serverTimestamp(),
          unlockGrantedUntil: Timestamp.fromDate(unlockUntil),
          unlockSource: "fine_paid",
        },
        { merge: true }
      );
    }
  });

  await writeAudit({
    actorUid,
    actorEmail: request.auth?.token?.email as string | undefined,
    action: approve ? "fine_approved" : "fine_rejected",
    targetUid,
    targetId: fineId,
    detail: { note },
  });

  // Tell the user, and nudge the native service to drop the overlay.
  await notifyFineReviewed(targetUid, approve, note);

  logger.info("Fine reviewed", { actorUid, targetUid, fineId, approve });

  return {
    reviewed: true,
    approved: approve,
    unlockUntil: unlockUntil ? unlockUntil.toISOString() : null,
  };
});

async function notifyFineReviewed(
  uid: string,
  approved: boolean,
  note: string | null
): Promise<void> {
  try {
    const userSnap = await paths.user(uid).get();
    const tokens: string[] = userSnap.get("fcmTokens") ?? [];
    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: approved ? "Fine approved ✅" : "Payment rejected",
        body: approved
          ? "Your payment was verified. Apps unlocked for 24 hours."
          : note ?? "Your payment proof was rejected. Please resubmit.",
      },
      data: {
        type: "fine_reviewed",
        approved: String(approved),
        channel: "fines",
      },
      android: { priority: "high" },
    });
  } catch (e) {
    // Never fail the review because a notification could not be delivered.
    logger.warn("Could not send fine review notification", { uid, error: e });
  }
}
