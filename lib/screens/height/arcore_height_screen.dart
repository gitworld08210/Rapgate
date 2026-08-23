import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Placeholder screen shown when ARCore measurement is selected
/// but not available on the device.
class ARCoreHeightScreen extends StatelessWidget {
  const ARCoreHeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARCore Measurement'),
        leading: CircleIconButton(
          icon: Icons.arrow_back_rounded,
          iconSize: 20,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page.copyWith(top: 60, bottom: 32),
          child: Column(
            children: [
              // Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.pastelBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.view_in_ar_rounded,
                  size: 56,
                  color: isDark ? AppColors.protein : AppColors.protein,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'ARCore Not Available',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'ARCore-based height measurement is not available on this device. '
                'This feature requires the Google ARCore framework and compatible hardware.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey500,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Info card
              SoftCard(
                color: isDark ? AppColors.darkCard : AppColors.pastelBlue,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: isDark ? AppColors.protein : AppColors.protein,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Why is this unavailable?',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.protein,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ARCore requires specific hardware support (depth sensor, compatible processor) '
                      'that not all Android devices have. The ARCore plugin is also not installed in this app version.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.grey500,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Suggestion to use Pose method
              SoftCard(
                color: isDark ? AppColors.darkCard : AppColors.limeWash,
                border: Border.all(
                  color: AppColors.limeBright.withOpacity(0.4),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.limeDeep,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Try the "Pose + Reference Object" method instead. It works on all phones!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              PillButton(
                label: 'Go Back',
                variant: PillVariant.dark,
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
