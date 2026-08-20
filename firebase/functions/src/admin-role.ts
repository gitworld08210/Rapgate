import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { auth, db, FieldValue, RUNTIME, isAdminEmail, paths } from "./config";

/**
 * Admin authorisation.
 *
 * Design notes — this is the security boundary for the whole admin surface:
 *
 *  1. The admin PASSWORD exists only in Firebase Auth. It is not in this
 *     repo, not in the app bundle, and not in any config file.
 *  2. The allowlist of admin emails lives in the server-only environment
 *     (`ADMIN_EMAILS`), so the client cannot read or influence it.
 *  3. Authorisation is carried by a Firebase custom claim, which is signed
 *     into the ID token. A patched client cannot forge it.
 *  4. Every privileged callable re-runs `requireAdmin()` on the decoded
 *     token. The app's own claim check only decides what UI to render.
 */

/** Throws unless the caller holds a verified `admin` claim. */
export function requireAdmin(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const token = request.auth?.token as Record<string, unknown> | undefined;

  if (token?.admin !== true) {
    logger.warn("Non-admin attempted a privileged call", {
      uid,
      email: token?.email,
    });
    throw new HttpsError(
      "permission-denied",
      "You are not authorised to perform this action."
    );
  }

  // Defence in depth: even a valid claim is rejected if the email has since
  // been removed from the allowlist (e.g. admin access was revoked).
  if (!isAdminEmail(token?.email as string | undefined)) {
    logger.error("Claim present but email no longer allowlisted", {
      uid,
      email: token?.email,
    });
    throw new HttpsError(
      "permission-denied",
      "Admin access has been revoked for this account."
    );
  }

  return uid;
}

/** Append-only audit trail of every privileged action. */
export async function writeAudit(entry: {
  actorUid: string;
  actorEmail?: string;
  action: string;
  targetUid?: string;
  targetId?: string;
  detail?: Record<string, unknown>;
}): Promise<void> {
  await paths.adminAudit().add({
    ...entry,
    at: FieldValue.serverTimestamp(),
  });
}

/**
 * Grants the `admin` claim to the signed-in user **iff** their email is on the
 * server-side allowlist and has been verified.
 *
 * Safe to call from any account: a non-allowlisted caller simply gets
 * `{ granted: false }` and nothing changes.
 */
export const claimAdminRole = onCall(RUNTIME, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const user = await auth.getUser(uid);
  const email = user.email?.toLowerCase();

  if (!isAdminEmail(email)) {
    // Deliberately not an error: ordinary users call this on launch and we
    // don't want to surface a scary failure. Log for intrusion visibility.
    logger.info("claimAdminRole denied — not allowlisted", { uid, email });
    return { granted: false, reason: "not_allowlisted" };
  }

  // Require a verified email so that merely *registering* the admin address
  // on another provider cannot escalate.
  if (!user.emailVerified) {
    throw new HttpsError(
      "failed-precondition",
      "Verify your email address before enabling admin access."
    );
  }

  const already = (user.customClaims ?? {})["admin"] === true;
  if (!already) {
    await auth.setCustomUserClaims(uid, {
      ...(user.customClaims ?? {}),
      admin: true,
    });

    // Force existing sessions to pick up the new claim on next refresh.
    await db.collection("users").doc(uid).set(
      { adminClaimUpdatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );

    await writeAudit({
      actorUid: uid,
      actorEmail: email,
      action: "admin_claim_granted",
    });

    logger.info("Admin claim granted", { uid, email });
  }

  return { granted: true, alreadyGranted: already };
});

/**
 * Revokes the `admin` claim from a target account. Callable only by an
 * existing admin; cannot be used to revoke your own last remaining access
 * by accident (guarded by the self-revoke check).
 */
export const revokeAdminRole = onCall(RUNTIME, async (request) => {
  const actorUid = requireAdmin(request);
  const targetUid = String(request.data?.targetUid ?? "");

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }
  if (targetUid === actorUid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot revoke your own admin access."
    );
  }

  const target = await auth.getUser(targetUid);
  const claims = { ...(target.customClaims ?? {}) };
  delete claims["admin"];
  await auth.setCustomUserClaims(targetUid, claims);
  await auth.revokeRefreshTokens(targetUid);

  await writeAudit({
    actorUid,
    actorEmail: request.auth?.token?.email as string | undefined,
    action: "admin_claim_revoked",
    targetUid,
  });

  return { revoked: true };
});
