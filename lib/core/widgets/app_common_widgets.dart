import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';

/// Small spinner sized to sit inside a full-width [ElevatedButton] while an
/// async action (auth, AI analysis, etc.) is in flight.
class AppButtonSpinner extends StatelessWidget {
  const AppButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

/// Inline error banner used by any screen that surfaces a recoverable
/// failure (auth errors, AI analysis errors) without a full-screen error
/// state.
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
