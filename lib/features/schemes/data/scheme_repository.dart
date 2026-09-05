import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:krishinetra/features/schemes/domain/models/scheme.dart';

/// Loads the bundled scheme dataset from `assets/agriculture_schemes.json`
/// once and caches it in memory — this is offline, static reference data
/// (see the dataset's own `status: Active` field), so there's no network
/// fetch or refresh logic needed, only a one-time asset read.
class SchemeRepository {
  List<Scheme>? _cache;

  Future<List<Scheme>> loadAll() async {
    final List<Scheme>? cached = _cache;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString('assets/agriculture_schemes.json');
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final List<Scheme> schemes = decoded
        .map((e) => Scheme.fromJson(e as Map<String, dynamic>))
        .where((s) => s.status.toLowerCase() == 'active')
        .toList();

    _cache = schemes;
    return schemes;
  }
}

/// App-wide singleton — the schemes screen and the match engine share one
/// cached load instead of each re-reading the asset.
final SchemeRepository schemeRepository = SchemeRepository();
