import 'package:flutter/foundation.dart' show immutable;

/// One government agricultural scheme, mirroring the columns of the
/// Maharashtra agriculture-schemes dataset
/// (`assets/agriculture_schemes.json`) exactly — see [SchemeRepository]
/// for how it's loaded.
@immutable
class Scheme {
  const Scheme({
    required this.id,
    required this.name,
    required this.category,
    required this.government,
    required this.department,
    required this.description,
    required this.beneficiary,
    required this.eligibility,
    required this.benefits,
    required this.requiredDocuments,
    required this.applicationMode,
    required this.officialLink,
    required this.status,
  });

  final String id;
  final String name;
  final String category;

  /// Raw value from the dataset: `"Central"`, `"State"`, or
  /// `"Central/State"` — this dataset is Maharashtra-only, so there is no
  /// separate Indian-state field to filter by (see [SchemeFilterBar]'s
  /// doc comment for why the state filter requirement maps to this field
  /// instead).
  final String government;

  final String department;
  final String description;
  final String beneficiary;
  final String eligibility;
  final String benefits;
  final String requiredDocuments;
  final String applicationMode;
  final String officialLink;
  final String status;

  factory Scheme.fromJson(Map<String, dynamic> json) => Scheme(
        id: json['scheme_id'] as String,
        name: json['scheme_name'] as String,
        category: json['category'] as String,
        government: json['government'] as String,
        department: json['department'] as String,
        description: json['description'] as String,
        beneficiary: json['beneficiary'] as String,
        eligibility: json['eligibility'] as String,
        benefits: json['benefits'] as String,
        requiredDocuments: json['required_documents'] as String,
        applicationMode: json['application_mode'] as String,
        officialLink: json['official_link'] as String,
        status: json['status'] as String,
      );

  /// Cheap combined haystack for keyword search — built once per query
  /// rather than per-field, since the search bar filters against name,
  /// category, and description together.
  String get searchHaystack => '$name $category $description $department'.toLowerCase();
}

/// The 7 fixed categories present in the current dataset, in the same
/// order the dataset naturally groups them — used to build the category
/// filter chips without having to scan the whole list first just to
/// discover what categories exist.
abstract final class SchemeCategories {
  static const List<String> all = [
    'Direct Income Support & Institutional Agri-Credit',
    'On-Farm Irrigation & Water Infrastructure Components',
    'Farm Mechanization & Agri-Machinery Profiles',
    'Horticulture Crop Variants & Protected Farming',
    'Post-Harvest Storage, Processing & FPO Infrastructure',
    'Soil Health, Seeds & Sustainable Bio-Farming',
    'Social Upliftment & Special Category Farm Programs',
  ];

  /// Short label for filter chips — the full category strings are long
  /// enough to wrap awkwardly in a horizontal chip row.
  static String shortLabel(String category) {
    switch (category) {
      case 'Direct Income Support & Institutional Agri-Credit':
        return 'Income & Credit';
      case 'On-Farm Irrigation & Water Infrastructure Components':
        return 'Irrigation';
      case 'Farm Mechanization & Agri-Machinery Profiles':
        return 'Mechanization';
      case 'Horticulture Crop Variants & Protected Farming':
        return 'Horticulture';
      case 'Post-Harvest Storage, Processing & FPO Infrastructure':
        return 'Storage & Processing';
      case 'Soil Health, Seeds & Sustainable Bio-Farming':
        return 'Soil & Organic';
      case 'Social Upliftment & Special Category Farm Programs':
        return 'Social Upliftment';
      default:
        return category;
    }
  }
}
