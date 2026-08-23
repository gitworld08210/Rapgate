# Daily Code Review Notes

Issues identified during code review that should NOT be auto-fixed due to risk or complexity. These require human review and decision-making.

---

## 1. PushupSessionModel.unlockGrantedUntil vs BlockedAppsConfig.unlockGrantedUntil

**Risk: Medium | Category: Data Source Confusion**

The `unlockGrantedUntil` field exists in both `PushupSessionModel` and `BlockedAppsConfigModel`. The `HealthProvider.isAppsUnlocked` getter now checks both sources (pushup-session-based unlock AND fine-paid/server-granted unlock from blocked_apps_config). This has been partially addressed by combining both expiry sources in `unlockExpiresAt`, but the dual-source pattern is still confusing and could lead to inconsistent UI states if either source has stale data.

**Suggestion:** Document clearly which system writes to which field. Consider a single source of truth for unlock state, or at minimum add inline comments explaining the precedence rules.

---

## 2. UPI ID in constants.dart is a placeholder

**Risk: High | Category: Configuration**

The UPI ID in `lib/utils/constants.dart` is set to `'yourname@upi'` which is a placeholder value. This must be configured with a real UPI ID before any production release or payment flows will fail silently or send money to the wrong destination.

**Action Required:** Replace with the actual UPI ID before production deployment. Consider moving this to a remote config or environment variable so it can be updated without a code release.

---

## 3. NotificationService navigation TODO items

**Risk: Low | Category: Incomplete Feature**

The `NotificationService` contains TODO comments for handling navigation when a user taps on a notification. Currently, notification taps do nothing (or navigate to a default screen). This is not a crash risk but degrades user experience since tapping a notification about water reminders or pushup sessions won't navigate to the relevant screen.

**Suggestion:** Implement deep-link routing from notification payloads to the appropriate screen (e.g., water reminder -> WaterTrackerScreen, pushup reminder -> PushupScreen).

---

## 4. dailyPushupCheck iterates ALL users without pagination

**Risk: High at scale | Category: Cloud Functions Performance**

In `functions/src/scheduled.ts`, the `dailyPushupCheck` function fetches and iterates ALL user documents with no pagination or batching. As the user base grows, this function will:
- Exceed Cloud Functions timeout limits (540s max for gen1, 9min for gen2)
- Consume excessive memory
- Result in incomplete processing if it times out partway through

**Suggestion:** Implement cursor-based pagination (process N users per batch) or use Firebase Extensions / task queues to distribute the work. Consider adding a `lastCheckedAt` field to skip recently-processed users.

---

## 5. sendPreLockReminder fetches full user documents unnecessarily

**Risk: Medium | Category: Performance / Cost**

In `functions/src/scheduled.ts`, `sendPreLockReminder` fetches ALL user documents with their complete data when it only needs the `fcmTokens` field. This wastes Firestore read bandwidth and increases costs as user documents grow.

**Suggestion:** Use `.select('fcmTokens')` on the query to fetch only the required field. This reduces bandwidth, lowers costs, and improves function execution time.

---

## 6. Duplicate food log writes (client + server)

**Risk: High | Category: Data Integrity Bug**

In `functions/src/food.ts`, the `scanFoodImage` Cloud Function writes a food log entry to Firestore after processing the image. However, the client in `lib/screens/food/food_scanner_screen.dart` ALSO writes a food log entry via `firestoreService.addFoodLog()` after the function returns. This results in duplicate food log entries in Firestore for every scanned food item.

**Action Required:** Remove one of the two writes. Either:
- Remove the server-side write in `food.ts` and let the client handle it (gives user a chance to edit before saving), OR
- Remove the client-side write and rely on the server (simpler but less flexible)

---

*Last updated: Review session for daily scan/bugfix task*
