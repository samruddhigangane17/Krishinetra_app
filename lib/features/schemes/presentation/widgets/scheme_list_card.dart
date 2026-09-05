import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/schemes/domain/models/scheme.dart';
import 'package:krishinetra/features/schemes/presentation/widgets/scheme_detail_sheet.dart';

/// Compact card for the searchable "All Schemes" list — tap to open the
/// full detail sheet ([showSchemeDetailSheet]). Deliberately simpler than
/// [RecommendedSchemeCard]: no reasoning text here, since these aren't
/// personalized matches, just the browsable directory.
class SchemeListCard extends StatelessWidget {
  const SchemeListCard({super.key, required this.scheme});

  final Scheme scheme;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showSchemeDetailSheet(context, scheme),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    scheme.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _governmentColor(scheme.government).withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    scheme.government,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _governmentColor(scheme.government)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              SchemeCategories.shortLabel(scheme.category),
              style: textTheme.bodySmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              scheme.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Color _governmentColor(String government) {
    if (government.contains('Central') && government.contains('State')) return AppColors.mustard;
    if (government == 'Central') return AppColors.secondary;
    return AppColors.primary;
  }
}
