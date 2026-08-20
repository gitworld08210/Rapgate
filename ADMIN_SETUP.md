# Admin Access Setup

How the single admin account is secured, and what you need to do once.

## Security model

The admin password is **never** in this repository, the app bundle, or any
config file. It exists only inside Supabase Auth.

```
┌─────────────────────────────────────────────────────────────┐
│ Supabase Auth        │ stores the admin email + password    │
│                      │ (password never leaves Supabase)     │
├──────────────────────┼──────────────────────────────────────┤
│ supabase/functions   │ ADMIN_EMAILS allowlist               │
│ /.env (gitignored)   │ server-only, never sent to the app   │
├──────────────────────┼──────────────────────────────────────┤
│ admin_roles table    │ row keyed by user_id, checked by     │
│                      │ every privileged Edge Function       │
├──────────────────────┼──────────────────────────────────────┤
│ Flutter app          │ reads admin status ONLY to decide     │
│                      │ whether to render the admin entry    │
└─────────────────────────────────────────────────────────────┘
```

**Why the app can't be patched to gain admin access.** The client's check
only controls which widgets render. Every privileged operation goes through
the `review-fine` Edge Function, which requires a valid Supabase JWT, a
confirmed email on the `ADMIN_EMAILS` allowlist, *and* an active row in
`admin_roles` — re-verified server-side on every call. Someone who patches
the APK to force the admin screen open sees an empty queue, and every
approve/reject fails with a 403.

## One-time setup

### 1. Create the admin account

Supabase Dashboard → **Authentication** → **Users** → **Add user**

- Email: the address you set in `ADMIN_EMAILS` (see `supabase/functions/.env`)
- Password: set it here. **Do not** put it in any file.

> The admin address is deliberately not written in this committed doc — it
> lives only in the gitignored `.env`. No need to advertise which account
> holds admin.

### 2. Verify the email

`claim-admin-role` refuses to grant access to an unverified address, so that
merely registering that email elsewhere cannot escalate.

Sign in as the admin once in the app and complete email verification (or
confirm it manually from the Dashboard).

### 3. Confirm the allowlist

`supabase/functions/.env` (gitignored) must contain your admin address:

```
ADMIN_EMAILS=your-admin@example.com
```

Add more addresses comma-separated if you ever need a second admin, then
re-upload secrets:

```bash
supabase secrets set --env-file supabase/functions/.env
```

### 4. Deploy

```bash
# Schema (tables, RLS policies, RPCs)
supabase db push

# Edge Functions
supabase functions deploy claim-admin-role
supabase functions deploy revoke-admin-role
supabase functions deploy review-fine
supabase functions deploy submit-fine-proof
# ...and the rest listed in SUPABASE_SETUP.md
```

### 5. Sign in

Sign in as the admin in the app. On first launch `AdminGate` calls
`claim-admin-role`; the server confirms the email is allowlisted and
verified, inserts an `admin_roles` row, and the **Admin → Fine review queue**
card appears in Settings. No other account ever sees it.

## Rotating the password

Do this now if the password was ever shared outside Supabase — treat it as
compromised.

Supabase Dashboard → Authentication → Users → select the user → **Send
password recovery** (or set a new password directly).

Nothing in the codebase needs changing; the password is not referenced
anywhere.

## Revoking admin access

Call `revoke-admin-role` as another admin:

```json
POST /functions/v1/revoke-admin-role
{ "targetUid": "<uid>" }
```

Or remove the email from `ADMIN_EMAILS` and re-upload secrets —
`requireAdmin()` re-checks the allowlist on every call, so access dies even
if the `admin_roles` row is still present.

## Fine settlement flow

| Step | Actor | What happens |
|---|---|---|
| 1 | Server | `daily-pushup-check` finds a missed day → creates a fine as `pending` |
| 2 | User | Scans the UPI QR, pays |
| 3 | User | Submits UTR **and/or** screenshot → `submit-fine-proof` → `submitted` |
| 4 | **You** | Review queue → **Approve** → `approved`, 24h unlock granted |
| 4b | **You** | Or **Reject** with a reason → `rejected`, user can resubmit |

Guards worth knowing about:

- A UTR already used on another fine is rejected (unique partial index), so
  one payment cannot clear several fines.
- Only `submitted` fines can be reviewed; approving twice is impossible.
- Every approve/reject is written to `admin_audit` with actor, target and note.
- RLS restricts the user's own write to `upi_utr` and `screenshot_path`
  only — `status` is not writable by any client (enforced by a Postgres
  trigger, not just app logic).

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
