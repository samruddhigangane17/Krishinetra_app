import 'package:flutter/foundation.dart' show immutable;

/// A farmer's standing profile — distinct from [AuthUser] (which is
/// login/session identity) and from any single [SoilInputs] (which is
/// one scan's readings). This is the durable, cross-session context
/// KrishiNetra didn't previously have anywhere: state/district, land
/// size, the crops a farmer normally grows, and a standing organic-input
/// preference.
///
/// Two concrete gaps this closes:
/// - The schemes screen previously lost all personalization on every app
///   restart because it only had the (session-only) latest scan to read
///   from. `usesOrganicInputs` here gives it a durable fallback default.
/// - The scheme dataset is Maharashtra-only with no way to tell a farmer
///   outside Maharashtra that results may not apply — `state` is what
///   the schemes screen now checks for that warning.
///
/// One profile per device — this app has never modeled per-account data
/// (see [SoilReportHistoryStore], `LanguageManager`), and a shared family
/// device with multiple `AuthUser`s would make per-account profiles more
/// confusing than helpful without a much bigger identity model. If that
/// changes, this is the object to key by uid instead.
@immutable
class FarmerProfile {
  const FarmerProfile({
    this.name,
    this.state,
    this.district,
    this.landSizeAcres,
    this.primaryCrops = const [],
    this.usesOrganicInputs,
    this.updatedAt,
  });

  final String? name;
  final String? state;
  final String? district;
  final double? landSizeAcres;
  final List<String> primaryCrops;

  /// Standing default for "does this farmer generally use organic/bio
  /// inputs" — the soil-scan form still asks per-scan (a farmer's
  /// practice can change), but pre-fills from this when set.
  final bool? usesOrganicInputs;

  final DateTime? updatedAt;

  bool get isEmpty =>
      name == null &&
      state == null &&
      district == null &&
      landSizeAcres == null &&
      primaryCrops.isEmpty &&
      usesOrganicInputs == null;

  FarmerProfile copyWith({
    String? name,
    String? state,
    String? district,
    double? landSizeAcres,
    List<String>? primaryCrops,
    bool? usesOrganicInputs,
    DateTime? updatedAt,
  }) {
    return FarmerProfile(
      name: name ?? this.name,
      state: state ?? this.state,
      district: district ?? this.district,
      landSizeAcres: landSizeAcres ?? this.landSizeAcres,
      primaryCrops: primaryCrops ?? this.primaryCrops,
      usesOrganicInputs: usesOrganicInputs ?? this.usesOrganicInputs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state,
        'district': district,
        'landSizeAcres': landSizeAcres,
        'primaryCrops': primaryCrops,
        'usesOrganicInputs': usesOrganicInputs,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static FarmerProfile? tryFromJson(Map<String, dynamic> json) {
    try {
      return FarmerProfile(
        name: json['name'] as String?,
        state: json['state'] as String?,
        district: json['district'] as String?,
        landSizeAcres: (json['landSizeAcres'] as num?)?.toDouble(),
        primaryCrops: (json['primaryCrops'] as List<dynamic>?)?.cast<String>() ?? const [],
        usesOrganicInputs: json['usesOrganicInputs'] as bool?,
        updatedAt: json['updatedAt'] == null ? null : DateTime.tryParse(json['updatedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Indian states/UTs for the profile's state picker. Deliberately the
/// full list (not just Maharashtra) — the schemes screen uses this field
/// to warn a farmer outside Maharashtra that the current scheme dataset
/// may not apply to them, which only works if they can honestly select
/// their real state rather than being limited to the one this dataset
/// covers.
const List<String> kIndianStatesAndUts = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];
