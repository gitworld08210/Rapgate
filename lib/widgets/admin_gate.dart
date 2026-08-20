import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/fine_service.dart';

/// Renders [child] only when the signed-in account holds the `admin` custom
/// claim, otherwise renders [fallback] (nothing by default).
///
/// This is a UI convenience, NOT a security control. The claim is verified
/// again inside every privileged Cloud Function, so a user who forces this
/// widget to render gains no actual capability — the admin screen would simply
/// show an empty queue and every action would fail with permission-denied.
class AdminGate extends StatefulWidget {
  const AdminGate({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),

    /// Attempt to claim the admin role on mount. The Cloud Function only
    /// grants it to a server-side allowlisted, email-verified account, so this
    /// is a no-op for ordinary users.
    this.attemptClaim = true,
  });

  final Widget child;
  final Widget fallback;
  final bool attemptClaim;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late Future<bool> _check;

  @override
  void initState() {
    super.initState();
    _check = _resolve();
  }

  Future<bool> _resolve() async {
    final service = context.read<FineService>();

    // Fast path: claim already present on the cached token.
    if (await service.isCurrentUserAdmin()) return true;

    if (!widget.attemptClaim) return false;

    // The allowlisted admin account won't have the claim on first ever login,
    // so give the server one chance to grant it, then re-read the token.
    try {
      final granted = await service.claimAdminRole();
      if (!granted) return false;
      return service.isCurrentUserAdmin(forceRefresh: true);
    } catch (_) {
      // Never let an admin-bootstrap failure break the screen for a normal user.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.data == true) return widget.child;
        return widget.fallback;
      },
    );
  }
}
