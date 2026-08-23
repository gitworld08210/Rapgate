import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

/// Premium subscription paywall screen.
///
/// Displays premium features, pricing tiers, and purchase CTAs.
/// Actual in-app purchase integration is marked with TODOs.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlan = 1; // 0 = monthly, 1 = yearly

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.ink,
              Color(0xFF1A2A12), // subtle green-tinted dark
              AppColors.ink,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ---------- Close button ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: CircleIconButton(
                    icon: Icons.close_rounded,
                    iconSize: 20,
                    background: Colors.white12,
                    iconColor: AppColors.white,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---------- Hero section ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.limeBright,
                            AppColors.limeDeep,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppShadows.limeGlow,
                      ),
                      child: const Icon(Icons.star_rounded,
                          size: 36, color: AppColors.ink),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'RepGate Premium',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock your full potential with advanced features',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ---------- Feature list ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SoftCard(
                  color: Colors.white.withOpacity(0.06),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _featureRow(
                        Icons.water_drop_rounded,
                        AppColors.water,
                        'Custom Water Targets',
                        'Set personalized daily hydration goals',
                      ),
                      const SizedBox(height: 18),
                      _featureRow(
                        Icons.bar_chart_rounded,
                        AppColors.limeBright,
                        'Advanced Reports',
                        'Weekly email with detailed analytics',
                      ),
                      const SizedBox(height: 18),
                      _featureRow(
                        Icons.discount_rounded,
                        AppColors.success,
                        'Reduced Fine Amounts',
                        '50% lower fines for missed push-ups',
                      ),
                      const SizedBox(height: 18),
                      _featureRow(
                        Icons.speed_rounded,
                        AppColors.burned,
                        'Priority Admin Review',
                        'Faster fine payment approvals',
                      ),
                      const SizedBox(height: 18),
                      _featureRow(
                        Icons.schedule_rounded,
                        AppColors.protein,
                        'Custom Push-up Schedules',
                        'Flexible timing and rest days',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ---------- Pricing plans ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _PlanCard(
                        title: 'Monthly',
                        price: '₹99',
                        period: '/month',
                        isSelected: _selectedPlan == 0,
                        onTap: () => setState(() => _selectedPlan = 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlanCard(
                        title: 'Yearly',
                        price: '₹799',
                        period: '/year',
                        badge: 'SAVE 33%',
                        isSelected: _selectedPlan == 1,
                        onTap: () => setState(() => _selectedPlan = 1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ---------- CTA buttons ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    PillButton(
                      label: _selectedPlan == 0
                          ? 'Start 7-Day Free Trial'
                          : 'Start 7-Day Free Trial',
                      variant: PillVariant.lime,
                      icon: Icons.rocket_launch_rounded,
                      onPressed: _handleSubscribe,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _handleRestorePurchase,
                      child: Text(
                        'Restore Purchase',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ---------- Privacy note ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Payment will be charged to your app store account. '
                  'Subscription auto-renews unless cancelled at least 24 hours '
                  'before the end of the current period. Manage subscriptions '
                  'in your device settings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white38, height: 1.5),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
      IconData icon, Color tint, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: tint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle_rounded,
            size: 20, color: AppColors.limeBright),
      ],
    );
  }

  void _handleSubscribe() {
    // TODO: Implement in-app purchase flow
    // 1. Initialize RevenueCat or play_billing plugin
    // 2. Fetch available packages
    // 3. Purchase the selected plan (_selectedPlan == 0 ? monthly : yearly)
    // 4. Verify receipt server-side via Supabase Edge Function
    // 5. Update user premium status in the database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('In-app purchase setup coming soon!'),
      ),
    );
  }

  void _handleRestorePurchase() {
    // TODO: Implement restore purchase logic
    // 1. Call RevenueCat restorePurchases() or equivalent
    // 2. Verify entitlements
    // 3. Update local premium status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for existing purchases...'),
      ),
    );
  }
}

/// Individual pricing plan card.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String period;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.limeBright.withOpacity(0.1)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.limeBright : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.limeBright,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              period,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
