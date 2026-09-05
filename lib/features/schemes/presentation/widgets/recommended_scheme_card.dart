import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/schemes/domain/scheme_match_engine.dart';
import 'package:krishinetra/features/schemes/presentation/widgets/scheme_detail_sheet.dart';

/// A single "Recommended For You" card — a scheme plus the specific,
/// soil-report-derived reasoning that earned it a spot here. Visually
/// distinct from the plain scheme list below (gradient border + a
/// "Matched to your soil report" tag) so it reads as personalized, not
/// just another list entry.
class RecommendedSchemeCard extends StatelessWidget {
  const RecommendedSchemeCard({super.key, required this.match});

  final SchemeMatch match;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showSchemeDetailSheet(context, match.scheme),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary.withOpacity(.08), AppColors.mustard.withOpacity(.10)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Matched to your soil report', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              match.scheme.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              match.scheme.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              match.reason,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text('View details  →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
