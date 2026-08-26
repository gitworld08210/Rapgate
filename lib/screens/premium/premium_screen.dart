import 'package:flutter/material.dart';

import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Beautiful paywall screen for RepGate Pro subscription.
///
/// Displays feature comparison, pricing cards, and CTA. Payment integration
/// will be connected once the backend is ready.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [AppColors.ink, Color(0xFF1A2E1A)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ---------- Top bar ----------
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      iconSize: 20,
                      background: Colors.white.withOpacity(0.12),
                      iconColor: Colors.white,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Restore purchases - coming soon'),
                          ),
                        );
                      },
                      child: Text(
                        'Restore',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ---------- Hero section ----------
              Padding(
                padding: AppSpacing.page,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.limeBright, AppColors.limeDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.limeBright.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.diamond_rounded,
                        size: 38,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'RepGate Pro',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unlock your full potential with premium features',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ---------- Feature comparison ----------
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you get',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Everything in Free, plus:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 22),

                      // Feature list
                      ...SubscriptionService.proFeatures.map(
                        (feature) => _featureRow(context, feature, true),
                      ),

                      const SizedBox(height: 16),

                      // Free tier limitations
                      Text(
                        'Free tier includes:',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.grey500),
                      ),
                      const SizedBox(height: 12),
                      _featureRow(context, '3 AI food scans per day', false),
                      _featureRow(context, 'Basic push-up tracking', false),
                      _featureRow(context, 'Standard analytics', false),
                      _featureRow(
                          context, '1 emergency unlock per week', false),

                      const SizedBox(height: 32),

                      // ---------- Pricing cards ----------
                      Text(
                        'Choose your plan',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _pricingCard(
                              context,
                              title: 'Monthly',
                              price: '149',
                              period: '/month',
                              badge: null,
                              isPopular: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _pricingCard(
                              context,
                              title: 'Yearly',
                              price: '999',
                              period: '/year',
                              badge: 'Save 44%',
                              isPopular: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ---------- CTA ----------
                      PillButton(
                        label: 'Subscribe to Pro',
                        variant: PillVariant.lime,
                        icon: Icons.diamond_rounded,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Coming soon - payment integration in progress',
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Restore purchases
                      Center(
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Restore purchases - coming soon'),
                              ),
                            );
                          },
                          child: Text(
                            'Restore Purchases',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.grey500,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Terms note
                      Center(
                        child: Text(
                          'Cancel anytime. No questions asked.',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.grey300),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(BuildContext context, String feature, bool isPro) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isPro
                  ? AppColors.limeSoft
                  : AppColors.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPro ? Icons.check_circle_rounded : Icons.check_rounded,
              size: 16,
              color: isPro ? AppColors.limeDeep : AppColors.grey300,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isPro ? FontWeight.w600 : FontWeight.w400,
                    color: isPro ? AppColors.ink : AppColors.grey500,
                  ),
            ),
          ),
          if (isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.limeSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'PRO',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.limeDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pricingCard(
    BuildContext context, {
    required String title,
    required String price,
    required String period,
    String? badge,
    required bool isPopular,
  }) {
    return SoftCard(
      color: isPopular ? AppColors.ink : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isPopular ? Colors.white : AppColors.ink,
                    ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.limeBright,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    badge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\u20B9$price',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isPopular ? AppColors.limeBright : AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 3),
              Text(
                period,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isPopular ? Colors.white54 : AppColors.grey500,
                    ),
              ),
            ],
          ),
          if (isPopular) ...[
            const SizedBox(height: 8),
            Text(
              'Most popular',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.limeBright,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
