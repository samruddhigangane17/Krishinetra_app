import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:krishinetra/core/services/language_manager.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({required this.onContinue, super.key});

  /// The selected language has already been committed to
  /// [languageManager] by the time this fires — callers don't need to
  /// carry it forward themselves anymore.
  final void Function(BuildContext context) onContinue;

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  LanguageOption? _pendingSelection;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.translate_rounded, color: colorScheme.primary, size: 32),
                        const SizedBox(height: AppSpacing.md),
                        // This heading renders in whatever locale is
                        // currently active (English by default, or a
                        // previously-selected language if the farmer is
                        // revisiting this screen) — it isn't per-choice
                        // translated below, so no hand-spliced second
                        // string is needed here anymore.
                        Text(l10n.chooseYourLanguage, style: textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(l10n.changeAnytimeHint, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 140),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final LanguageOption language = LanguageOption.supported[index];
                      final bool isSelected = _pendingSelection?.code == language.code;

                      return _LanguageCard(
                        language: language,
                        isSelected: isSelected,
                        onTap: () => setState(() => _pendingSelection = language),
                      );
                    }, childCount: LanguageOption.supported.length),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyContinueBar(
                enabled: _pendingSelection != null,
                label: l10n.continueLabel,
                onContinue: () async {
                  final LanguageOption? selection = _pendingSelection;
                  if (selection == null) return;
                  // Commits the choice to the centralized language
                  // manager: switches the app's live locale immediately
                  // (so every screen from here on — including this one,
                  // if the farmer navigates back — renders in the chosen
                  // language without waiting for a restart) and persists
                  // it so it's still selected next time the app opens.
                  await languageManager.setLanguage(selection);
                  if (!context.mounted) return;
                  widget.onContinue(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.language, required this.isSelected, required this.onTap});

  final LanguageOption language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${language.englishName}, ${language.nativeName}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardRadius,
              color: isSelected ? colorScheme.primary.withOpacity(0.10) : AppColors.surface,
              border: Border.all(
                color: isSelected ? colorScheme.primary : AppColors.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                if (isSelected)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary),
                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          language.nativeName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colorScheme.primary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          language.englishName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyContinueBar extends StatelessWidget {
  const _StickyContinueBar({
    required this.enabled,
    required this.label,
    required this.onContinue,
  });

  final bool enabled;
  final String label;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: ClipRRect(
        borderRadius: AppRadii.buttonRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: AppRadii.buttonRadius,
              color: Colors.white.withOpacity(0.55),
              border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: ElevatedButton(
              onPressed: enabled ? onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.25),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
