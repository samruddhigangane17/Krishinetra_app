import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/core/widgets/app_common_widgets.dart';
import 'package:krishinetra/core/widgets/branded_logo_header.dart';
import 'package:krishinetra/core/widgets/radar_pulse_loader.dart';
import 'package:krishinetra/core/widgets/ui_kit.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/features/profile/data/farmer_profile_service.dart';
import 'package:krishinetra/features/profile/domain/models/farmer_profile.dart';
import 'package:krishinetra/features/recommendation/data/gemini_service.dart';
import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';
import 'package:krishinetra/features/recommendation/presentation/pages/recommendation_report_screen.dart';

/// The "Scan" tab's diagnostic form. Collects an optional crop photo
/// (camera or gallery) plus N/P/K/pH readings and a target crop, then —
/// the moment "Analyze Soil" is tapped — calls [geminiAgriService]
/// automatically and, on success, routes smoothly into
/// [RecommendationReportScreen] via a standard forward push (so the back
/// button returns here to run another scan).
class SoilScanScreen extends StatefulWidget {
  const SoilScanScreen({this.language = LanguageOption.defaultLanguage, super.key});

  final LanguageOption language;

  @override
  State<SoilScanScreen> createState() => _SoilScanScreenState();
}

class _SoilScanScreenState extends State<SoilScanScreen> {
  final TextEditingController _nController = TextEditingController();
  final TextEditingController _pController = TextEditingController();
  final TextEditingController _kController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _moistureController = TextEditingController();
  final TextEditingController _cropController = TextEditingController();
  String? _cropStage;
  bool? _usesOrganicInputs;

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _pickedImageBytes;
  String? _pickedImageMimeType;
  bool _isPickingImage = false;

  bool _isAnalyzing = false;
  String? _errorMessage;

  final List<FertilizerHistoryEntry> _fertilizerHistory = [];

  @override
  void initState() {
    super.initState();
    // Prefill from the farmer's standing profile, if one exists — the
    // farmer can still change either per scan, since actual practice for
    // a given field/season can differ from their general default.
    final FarmerProfile? profile = farmerProfileService.profile;
    _usesOrganicInputs = profile?.usesOrganicInputs;
    if (profile != null && profile.primaryCrops.isNotEmpty) {
      _cropController.text = profile.primaryCrops.first;
    }
  }

  bool get _hasCompleteNpk =>
      _nController.text.isNotEmpty &&
      _pController.text.isNotEmpty &&
      _kController.text.isNotEmpty &&
      _phController.text.isNotEmpty;

  bool get _hasPartialNpk =>
      !_hasCompleteNpk &&
      (_nController.text.isNotEmpty ||
          _pController.text.isNotEmpty ||
          _kController.text.isNotEmpty ||
          _phController.text.isNotEmpty);

  // NPK/pH are optional now: a photo alone is enough to run a scan, so
  // the button enables on (a photo) OR (a full set of readings). A
  // half-filled set of readings with no photo is still blocked, since
  // partial numbers with nothing to fall back on would just be guessing.
  bool get _canAnalyze =>
      !_isAnalyzing && (_pickedImageBytes != null || _hasCompleteNpk);

  @override
  void dispose() {
    _nController.dispose();
    _pController.dispose();
    _kController.dispose();
    _phController.dispose();
    _moistureController.dispose();
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (file == null) return; // user cancelled

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageMimeType = file.mimeType ?? 'image/jpeg';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not access the ${source == ImageSource.camera ? 'camera' : 'gallery'}: $error';
      });
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageMimeType = null;
    });
  }

  Future<void> _runAnalysis() async {
    final bool hasImage = _pickedImageBytes != null;

    if (!hasImage && !_hasCompleteNpk) {
      setState(() {
        _errorMessage = 'Enter all four soil readings, or attach a crop/soil photo to analyze.';
      });
      return;
    }

    if (_hasPartialNpk && !hasImage) {
      setState(() {
        _errorMessage = 'Fill in all four soil readings, or clear them and attach a photo instead.';
      });
      return;
    }

    // Only send NPK/pH to the analyzer when the full set was entered —
    // otherwise leave them null so the photo (image-only flow) drives the
    // analysis instead.
    double? n, p, k, ph;
    if (_hasCompleteNpk) {
      n = double.tryParse(_nController.text);
      p = double.tryParse(_pController.text);
      k = double.tryParse(_kController.text);
      ph = double.tryParse(_phController.text);

      if (n == null || p == null || k == null || ph == null) {
        setState(() => _errorMessage = 'Enter valid numbers for N, P, K, and pH.');
        return;
      }
    }

    // Moisture is independent of the N/P/K/pH "complete set" gate above —
    // a farmer can add it, skip it, or enter it alone alongside a photo.
    final double? moisture = _moistureController.text.trim().isEmpty
        ? null
        : double.tryParse(_moistureController.text.trim());

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final SoilHealthAssessment assessment = await geminiAgriService.analyzeSoil(
        n,
        p,
        k,
        ph,
        _cropController.text.trim(),
        moisture: moisture,
        cropStage: _cropStage,
        usesOrganicInputs: _usesOrganicInputs,
        imageBytes: _pickedImageBytes,
        imageMimeType: _pickedImageMimeType,
        fertilizerHistory: _fertilizerHistory,
        language: widget.language,
      );

      if (!mounted) return;

      setState(() => _isAnalyzing = false);

      // Smooth forward routing into the report — a standard push keeps
      // the back button returning here for another scan.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecommendationReportScreen(
            assessment: assessment,
            language: widget.language,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Something went wrong analyzing this sample: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 760;
          final double horizontal = compact ? 16 : 32;
          final double maxWidth = compact ? double.infinity : 1120;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Scan your soil', style: textTheme.headlineMedium),
                              const SizedBox(height: 6),
                              Text(
                                'Upload a soil or crop photo, or enter your lab readings. We\'ll turn them into a clear action plan.',
                                style: textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight.withOpacity(.28),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
                                SizedBox(width: 7),
                                Text('AI-powered', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      AppErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _isAnalyzing
                          ? const Padding(
                              key: ValueKey('radar'),
                              padding: EdgeInsets.only(bottom: 18),
                              child: RadarPulseLoader(),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-radar')),
                    ),
                    _SectionCard(
                      icon: Icons.photo_camera_back_rounded,
                      title: 'Crop / Soil Photo',
                      subtitle: 'A photo alone is enough. For best results, use a clear, well-lit image.',
                      child: _ImageUploaderSection(
                        imageBytes: _pickedImageBytes,
                        isBusy: _isPickingImage,
                        onCamera: () => _pickImage(ImageSource.camera),
                        onGallery: () => _pickImage(ImageSource.gallery),
                        onClear: _clearImage,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      icon: Icons.science_rounded,
                      title: 'Soil readings',
                      subtitle: _pickedImageBytes != null
                          ? 'Optional — the photo can drive the analysis by itself.'
                          : 'Enter all four values, or attach a photo instead.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, fieldConstraints) {
                              final bool stack = fieldConstraints.maxWidth < 620;
                              final fields = [
                                _NutrientField(label: 'Nitrogen (N)', suffix: 'kg/acre', controller: _nController, onChanged: (_) => setState(() {}), icon: Icons.eco_rounded),
                                _NutrientField(label: 'Phosphorus (P)', suffix: 'kg/acre', controller: _pController, onChanged: (_) => setState(() {}), icon: Icons.local_florist_rounded),
                                _NutrientField(label: 'Potassium (K)', suffix: 'kg/acre', controller: _kController, onChanged: (_) => setState(() {}), icon: Icons.terrain_rounded),
                                _NutrientField(label: 'Soil pH', suffix: '0–14', controller: _phController, onChanged: (_) => setState(() {}), icon: Icons.water_drop_rounded),
                              ];
                              if (stack) {
                                return Column(children: [
                                  fields[0], const SizedBox(height: 12), fields[1],
                                  const SizedBox(height: 12), fields[2], const SizedBox(height: 12), fields[3],
                                ]);
                              }
                              return Column(children: [
                                Row(children: [Expanded(child: fields[0]), const SizedBox(width: 14), Expanded(child: fields[1])]),
                                const SizedBox(height: 14),
                                Row(children: [Expanded(child: fields[2]), const SizedBox(width: 14), Expanded(child: fields[3])]),
                              ]);
                            },
                          ),
                          const SizedBox(height: 14),
                          _NutrientField(
                            label: 'Soil Moisture (optional)',
                            suffix: '%',
                            controller: _moistureController,
                            onChanged: (_) => setState(() {}),
                            icon: Icons.opacity_rounded,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _cropStage,
                            decoration: const InputDecoration(
                              labelText: 'Crop growth stage (optional)',
                              prefixIcon: Icon(Icons.timeline_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Sowing', child: Text('Sowing')),
                              DropdownMenuItem(value: 'Vegetative', child: Text('Vegetative')),
                              DropdownMenuItem(value: 'Flowering', child: Text('Flowering')),
                              DropdownMenuItem(value: 'Maturity', child: Text('Maturity')),
                            ],
                            onChanged: (value) => setState(() => _cropStage = value),
                          ),
                          const SizedBox(height: 14),
                          Text('Do you use organic/bio-based inputs?', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          SegmentedButton<bool?>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('Yes')),
                              ButtonSegment(value: false, label: Text('No')),
                              ButtonSegment(value: null, label: Text('Not sure')),
                            ],
                            selected: {_usesOrganicInputs},
                            onSelectionChanged: (selection) => setState(() => _usesOrganicInputs = selection.first),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _cropController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Target crop (optional)',
                              hintText: 'e.g. Wheat, Cotton, Rice',
                              prefixIcon: Icon(Icons.grass_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Previously used fertilisers',
                      subtitle: 'Optional context that helps make recommendations more practical.',
                      child: _FertilizerHistorySection(
                        entries: _fertilizerHistory,
                        onAdd: _addFertilizerEntry,
                        onRemove: _removeFertilizerEntry,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _canAnalyze ? _runAnalysis : null,
                        icon: _isAnalyzing ? const AppButtonSpinner() : const Icon(Icons.auto_awesome_rounded),
                        label: Text(_isAnalyzing ? 'Analyzing your sample…' : 'Analyze soil'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Your photo and readings are used only to prepare this assessment.',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addFertilizerEntry() async {
    final FertilizerHistoryEntry? entry = await showModalBottomSheet<FertilizerHistoryEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddFertilizerSheet(),
    );
    if (entry == null || !mounted) return;
    setState(() => _fertilizerHistory.add(entry));
  }

  void _removeFertilizerEntry(int index) {
    setState(() => _fertilizerHistory.removeAt(index));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(.7)),
        boxShadow: const [BoxShadow(color: Color(0x12002112), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.secondaryLight.withOpacity(.30), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ])),
          ]),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// "Camera" / "Gallery" buttons plus a thumbnail preview once a photo has
/// been picked, sitting above the soil reading fields as requested.
class _ImageUploaderSection extends StatelessWidget {
  const _ImageUploaderSection({
    required this.imageBytes,
    required this.isBusy,
    required this.onCamera,
    required this.onGallery,
    required this.onClear,
  });

  final Uint8List? imageBytes;
  final bool isBusy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(fit: StackFit.expand, children: [
                Image.memory(imageBytes!, fit: BoxFit.cover),
                Positioned(
                  top: 12, right: 12,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: onClear, tooltip: 'Remove photo'),
                  ),
                ),
                Positioned(
                  left: 12, bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, color: Colors.white, size: 16), SizedBox(width: 6), Text('Photo attached', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(builder: (context, constraints) {
          final stack = constraints.maxWidth < 520;
          final camera = OutlinedButton.icon(onPressed: isBusy ? null : onCamera, icon: const Icon(Icons.photo_camera_rounded), label: const Text('Take photo'));
          final gallery = OutlinedButton.icon(onPressed: isBusy ? null : onGallery, icon: const Icon(Icons.photo_library_rounded), label: const Text('Choose from gallery'));
          if (stack) return Column(children: [SizedBox(width: double.infinity, child: camera), const SizedBox(height: 10), SizedBox(width: double.infinity, child: gallery)]);
          return Row(children: [Expanded(child: camera), const SizedBox(width: 12), Expanded(child: gallery)]);
        }),
      ],
    );
  }
}

class _NutrientField extends StatelessWidget {
  const _NutrientField({
    required this.label,
    required this.suffix,
    required this.controller,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final String suffix;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// A small, friendly, rustic icon shown inside the field (e.g. a leaf
  /// for Nitrogen, a soil mound for Potassium) so the four readings feel
  /// like familiar farm concepts rather than lab jargon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
      ),
    );
  }
}

/// "Previously Used Fertilisers (Optional)" — lets the farmer log zero or
/// more past fertilizer applications before scanning. Purely optional
/// context for the recommendation engine; skipping it entirely is the
/// default and requires no action.
class _FertilizerHistorySection extends StatelessWidget {
  const _FertilizerHistorySection({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final List<FertilizerHistoryEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Previously Used Fertilisers (Optional)', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add any fertilizers you\'ve used recently — this helps explain '
          'your soil result, it doesn\'t change the measured readings above.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.grain_rounded, size: 18, color: AppColors.secondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(_entrySubtitle(entries[i]), style: textTheme.bodyMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Remove',
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(entries.isEmpty ? 'Add Fertilizer' : 'Add Another Fertilizer'),
        ),
      ],
    );
  }

  String _entrySubtitle(FertilizerHistoryEntry entry) {
    final List<String> parts = [entry.name];
    if (entry.quantity != null && entry.quantity!.isNotEmpty) parts.add(entry.quantity!);
    if (entry.date != null) parts.add(_formatDate(entry.date!));
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Bottom sheet for logging one fertilizer: name (required), quantity and
/// date (both optional). Uses only standard Material widgets/pickers —
/// no new dependencies.
class _AddFertilizerSheet extends StatefulWidget {
  const _AddFertilizerSheet();

  @override
  State<_AddFertilizerSheet> createState() => _AddFertilizerSheetState();
}

class _AddFertilizerSheetState extends State<_AddFertilizerSheet> {
  static const List<String> _quickPicks = ['Urea', 'DAP', 'MOP', 'NPK', 'SSP', 'Zinc Sulphate'];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submit() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    final String quantity = _quantityController.text.trim();
    Navigator.of(context).pop(
      FertilizerHistoryEntry(
        name: name,
        quantity: quantity.isEmpty ? null : quantity,
        date: _selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Fertilizer', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Fertilizer name', hintText: 'e.g. Urea'),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final String pick in _quickPicks)
                ActionChip(
                  label: Text(pick),
                  onPressed: () => setState(() => _nameController.text = pick),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity (optional)',
              hintText: 'e.g. 50 kg',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(
              _selectedDate == null
                  ? 'Date used (optional)'
                  : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                        '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                        '${_selectedDate!.year}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
