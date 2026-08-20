# Admin Access Setup

How the single admin account is secured, and what you need to do once.

## Security model

The admin password is **never** in this repository, the app bundle, or any
config file. It exists only inside Firebase Authentication.

```
┌─────────────────────────────────────────────────────────────┐
│ Firebase Auth        │ stores the admin email + password    │
│                      │ (password never leaves Firebase)     │
├──────────────────────┼──────────────────────────────────────┤
│ functions/.env       │ ADMIN_EMAILS allowlist               │
│ (gitignored)         │ server-only, never sent to the app   │
├──────────────────────┼──────────────────────────────────────┤
│ Custom claim         │ { admin: true } signed into the ID    │
│                      │ token — unforgeable by a client      │
├──────────────────────┼──────────────────────────────────────┤
│ Flutter app          │ reads the claim ONLY to decide        │
│                      │ whether to render the admin entry    │
└─────────────────────────────────────────────────────────────┘
```

**Why the app can't be patched to gain admin access.** The client's claim check
only controls which widgets render. Every privileged operation goes through
`reviewFine`, which calls `requireAdmin()` and re-verifies the claim *and* the
email allowlist against the decoded token server-side. Someone who patches the
APK to force the admin screen open sees an empty queue, and every approve/reject
fails with `permission-denied`.

## One-time setup

### 1. Create the admin account

Firebase Console → **Authentication** → **Users** → **Add user**

- Email: the address you set in `ADMIN_EMAILS` (see `firebase/functions/.env`)
- Password: set it here. **Do not** put it in any file.

> The admin address is deliberately not written in this committed doc — it
> lives only in the gitignored `.env`. No need to advertise which account
> holds admin.

### 2. Verify the email

`claimAdminRole` refuses to grant the claim to an unverified address, so that
merely registering that email elsewhere cannot escalate.

Sign in as the admin once in the app and complete email verification, or mark
`emailVerified` via the Admin SDK.

### 3. Confirm the allowlist

`firebase/functions/.env` (gitignored) must contain your admin address:

```
ADMIN_EMAILS=your-admin@example.com
```

It is already populated with yours. Add more addresses comma-separated if you
ever need a second admin.

### 4. Deploy

```bash
# Cloud Functions
npm --prefix firebase/functions install
firebase deploy --only functions

# Security rules — these are what actually enforce the model
firebase deploy --only firestore:rules,storage:rules

# Composite indexes for the admin review queue
firebase deploy --only firestore:indexes
```

### 5. Sign in

Sign in as the admin in the app. On first launch `AdminGate` calls
`claimAdminRole`, the server confirms the email is allowlisted and verified,
grants the claim, and the **Admin → Fine review queue** card appears in
Settings. No other account ever sees it.

## Rotating the password

Do this now — the password was shared in a chat, so treat it as compromised.

Firebase Console → Authentication → Users → ⋮ → **Reset password**.

Nothing in the codebase needs changing; the password is not referenced anywhere.

## Revoking admin access

```bash
# From the app, as another admin:
revokeAdminRole({ targetUid: "<uid>" })
```

Or remove the email from `ADMIN_EMAILS` and redeploy — `requireAdmin()`
re-checks the allowlist on every call, so access dies even if the cached claim
is still present in an ID token.

## Fine settlement flow

| Step | Actor | What happens |
|---|---|---|
| 1 | Server | `dailyPushupCheck` finds a missed day → creates a fine as `pending` |
| 2 | User | Scans the UPI QR, pays |
| 3 | User | Submits UTR **and/or** screenshot → `submitFineProof` → `submitted` |
| 4 | **You** | Review queue → **Approve** → `approved`, 24h unlock granted |
| 4b | **You** | Or **Reject** with a reason → `rejected`, user can resubmit |

Guards worth knowing about:

- A UTR already used on another fine is rejected (`already-exists`), so one
  payment cannot clear several fines.
- Only `submitted` fines can be reviewed; approving twice is impossible.
- Every approve/reject is written to `admin_audit` with actor, target and note.
- Security rules restrict the user's own write to `upiUtr` and `screenshotUrl`
  only — `status` is not writable by any client.

## Configure your UPI details

In `lib/utils/constants.dart`:

```dart
static const String upiId = 'yourname@upi';       // ← your real UPI ID
static const String upiPayeeName = 'HealthPush';
```

The QR is generated from these at runtime. To use your bank's own QR image
instead, drop it in `assets/images/` and set:

```dart
static const String? upiQrAssetPath = 'assets/images/upi_qr.png';
```
