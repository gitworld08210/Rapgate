/**
 * HealthPush Cloud Functions
 *
 * Everything that represents an earned or verified outcome is computed here,
 * never on the client:
 *   * push-up rep counts and the 24-hour unlock window
 *   * streaks and adaptive difficulty
 *   * fine creation, and fine approval (admin only)
 *
 * Deploy:  npm --prefix firebase/functions run deploy
 */

// --- Admin authorisation (custom claim, server-side email allowlist) ---
export { claimAdminRole, revokeAdminRole } from "./admin-role";

// --- Push-up verification ---
export { startPushupSession, submitPushupFrameBatch } from "./pushup";

// --- Food ---
export { scanFoodImage, searchFoodByBarcode } from "./food";

// --- Manual UPI fine settlement ---
export { submitFineProof, reviewFine } from "./fines";

// --- Scheduled jobs, accountability, messaging ---
export {
  dailyPushupCheck,
  sendPreLockReminder,
  setAccountabilityContact,
  registerFcmToken,
} from "./scheduled";
