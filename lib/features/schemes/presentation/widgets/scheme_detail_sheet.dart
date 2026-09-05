import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/schemes/domain/models/scheme.dart';

/// Shows the full detail of a [Scheme] in a bottom sheet. Shared by both
/// [RecommendedSchemeCard] and [SchemeListCard] so a scheme's full
/// write-up looks the same regardless of which card the farmer tapped.
Future<void> showSchemeDetailSheet(BuildContext context, Scheme scheme) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SchemeDetailSheet(scheme: scheme),
  );
}

class _SchemeDetailSheet extends StatelessWidget {
  const _SchemeDetailSheet({required this.scheme});

  final Scheme scheme;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Tag(label: scheme.government, color: AppColors.secondary),
                  _Tag(label: SchemeCategories.shortLabel(scheme.category), color: AppColors.primary),
                  _Tag(label: scheme.applicationMode, color: AppColors.mustard),
                ],
              ),
              const SizedBox(height: 12),
              Text(scheme.name, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(scheme.department, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              _Section(title: 'About', body: scheme.description),
              const SizedBox(height: 14),
              _Section(title: 'Who can apply', body: scheme.eligibility),
              const SizedBox(height: 14),
              _Section(title: 'Benefits', body: scheme.benefits),
              const SizedBox(height: 14),
              _Section(title: 'Required documents', body: scheme.requiredDocuments),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        scheme.officialLink,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Scheme rules, amounts and application windows can change — verify the latest '
                'details on the official portal above before applying.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.5)),
        ],
      );
}
