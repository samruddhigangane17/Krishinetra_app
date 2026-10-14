import 'package:flutter/material.dart';

import 'package:krishinetra/core/services/auth_service.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/features/profile/data/farmer_profile_service.dart';
import 'package:krishinetra/features/profile/domain/models/farmer_profile.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

/// Profile & Settings tab: account info + language (unchanged from the
/// old inline `_Profile` widget) plus the new [FarmerProfile] section —
/// state/district, land size, primary crops, and a standing organic-input
/// preference. See `farmer_profile.dart` for why this exists as a
/// separate, durable object rather than living on [AuthUser] or a single
/// scan's `SoilInputs`.
class FarmerProfileScreen extends StatefulWidget {
  const FarmerProfileScreen({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  final AuthUser user;
  final VoidCallback onSignOut;
  final LanguageOption currentLanguage;
  final ValueChanged<LanguageOption> onLanguageChanged;

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  bool _editing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _landSizeController = TextEditingController();
  final TextEditingController _cropInputController = TextEditingController();

  String? _state;
  final List<String> _crops = [];
  bool? _usesOrganicInputs;

  @override
  void initState() {
    super.initState();
    _loadFromProfile(farmerProfileService.profile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _landSizeController.dispose();
    _cropInputController.dispose();
    super.dispose();
  }

  void _loadFromProfile(FarmerProfile? profile) {
    _nameController.text = profile?.name ?? '';
    _districtController.text = profile?.district ?? '';
    _landSizeController.text = profile?.landSizeAcres?.toString() ?? '';
    _state = profile?.state;
    _crops
      ..clear()
      ..addAll(profile?.primaryCrops ?? const []);
    _usesOrganicInputs = profile?.usesOrganicInputs;
  }

  void _startEditing() {
    _loadFromProfile(farmerProfileService.profile);
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    _loadFromProfile(farmerProfileService.profile);
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double? landSize = double.tryParse(_landSizeController.text.trim());

    await farmerProfileService.save(FarmerProfile(
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      state: _state,
      district: _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
      landSizeAcres: landSize,
      primaryCrops: List.of(_crops),
      usesOrganicInputs: _usesOrganicInputs,
    ));

    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSavedConfirmation)));
  }

  void _addCropFromInput() {
    final String value = _cropInputController.text.trim();
    if (value.isEmpty || _crops.contains(value)) {
      _cropInputController.clear();
      return;
    }
    setState(() {
      _crops.add(value);
      _cropInputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: farmerProfileService,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.profileTitle, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(l10n.profileSubtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 22),

                  _Section(
                    title: l10n.farmerProfileSectionTitle,
                    trailing: _editing
                        ? null
                        : TextButton.icon(
                            onPressed: _startEditing,
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: Text(l10n.editProfileButton),
                          ),
                    child: _editing
                        ? _ProfileEditForm(
                            l10n: l10n,
                            nameController: _nameController,
                            districtController: _districtController,
                            landSizeController: _landSizeController,
                            cropInputController: _cropInputController,
                            crops: _crops,
                            state: _state,
                            usesOrganicInputs: _usesOrganicInputs,
                            onStateChanged: (value) => setState(() => _state = value),
                            onOrganicChanged: (value) => setState(() => _usesOrganicInputs = value),
                            onAddCrop: _addCropFromInput,
                            onRemoveCrop: (crop) => setState(() => _crops.remove(crop)),
                            onSave: _save,
                            onCancel: _cancelEditing,
                          )
                        : _ProfileSummary(l10n: l10n, profile: farmerProfileService.profile, onStart: _startEditing),
                  ),
                  const SizedBox(height: 16),

                  _Section(
                    title: 'Account',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.surfaceContainerLow,
                        child: Icon(Icons.person_rounded, color: AppColors.primary),
                      ),
                      title: Text(
                        widget.user.displayName ?? (widget.user.isGuest ? l10n.guestFarmerName : l10n.farmerNameFallback),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(widget.user.isGuest ? l10n.offlineGuestModeChip : (widget.user.phoneNumber ?? l10n.phoneLabel)),
                      trailing: FilledButton(onPressed: widget.onSignOut, child: Text(l10n.signOut)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _Section(
                    title: l10n.languageLabel,
                    child: DropdownButtonFormField<LanguageOption>(
                      initialValue: widget.currentLanguage,
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.language_rounded), labelText: l10n.languageLabel),
                      items: LanguageOption.supported.map((l) => DropdownMenuItem(value: l, child: Text(l.nativeName))).toList(),
                      onChanged: (value) {
                        if (value != null) widget.onLanguageChanged(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.l10n, required this.profile, required this.onStart});
  final AppLocalizations l10n;
  final FarmerProfile? profile;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (profile == null || profile!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.noProfileYetTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(l10n.noProfileYetHint, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add_rounded), label: Text(l10n.editProfileButton)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile!.name != null) _SummaryRow(icon: Icons.badge_rounded, label: l10n.nameFieldLabel, value: profile!.name!),
        if (profile!.state != null) _SummaryRow(icon: Icons.map_rounded, label: l10n.stateFieldLabel, value: profile!.state!),
        if (profile!.district != null) _SummaryRow(icon: Icons.location_city_rounded, label: l10n.districtFieldLabel, value: profile!.district!),
        if (profile!.landSizeAcres != null)
          _SummaryRow(icon: Icons.crop_square_rounded, label: l10n.landSizeFieldLabel, value: '${profile!.landSizeAcres} acres'),
        if (profile!.primaryCrops.isNotEmpty)
          _SummaryRow(icon: Icons.grass_rounded, label: l10n.primaryCropsFieldLabel, value: profile!.primaryCrops.join(', ')),
        if (profile!.usesOrganicInputs != null)
          _SummaryRow(
            icon: Icons.eco_rounded,
            label: l10n.organicDefaultLabel,
            value: profile!.usesOrganicInputs! ? l10n.yesLabel : l10n.noLabel,
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditForm extends StatelessWidget {
  const _ProfileEditForm({
    required this.l10n,
    required this.nameController,
    required this.districtController,
    required this.landSizeController,
    required this.cropInputController,
    required this.crops,
    required this.state,
    required this.usesOrganicInputs,
    required this.onStateChanged,
    required this.onOrganicChanged,
    required this.onAddCrop,
    required this.onRemoveCrop,
    required this.onSave,
    required this.onCancel,
  });

  final AppLocalizations l10n;
  final TextEditingController nameController;
  final TextEditingController districtController;
  final TextEditingController landSizeController;
  final TextEditingController cropInputController;
  final List<String> crops;
  final String? state;
  final bool? usesOrganicInputs;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<bool?> onOrganicChanged;
  final VoidCallback onAddCrop;
  final ValueChanged<String> onRemoveCrop;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.nameFieldLabel, prefixIcon: const Icon(Icons.badge_rounded)),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: state,
          decoration: InputDecoration(labelText: l10n.stateFieldLabel, prefixIcon: const Icon(Icons.map_rounded)),
          hint: Text(l10n.statePickerHint),
          isExpanded: true,
          items: kIndianStatesAndUts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onStateChanged,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: districtController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.districtFieldLabel, prefixIcon: const Icon(Icons.location_city_rounded)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: landSizeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.landSizeFieldLabel, prefixIcon: const Icon(Icons.crop_square_rounded)),
        ),
        const SizedBox(height: 14),
        Text(l10n.primaryCropsFieldLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String crop in crops)
              Chip(
                label: Text(crop),
                onDeleted: () => onRemoveCrop(crop),
              ),
          ],
        ),
        if (crops.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: cropInputController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l10n.primaryCropsHint, prefixIcon: const Icon(Icons.grass_rounded)),
          onSubmitted: (_) => onAddCrop(),
        ),
        const SizedBox(height: 16),
        Text(l10n.organicDefaultLabel, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        SegmentedButton<bool?>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.yesLabel)),
            ButtonSegment(value: false, label: Text(l10n.noLabel)),
            ButtonSegment(value: null, label: Text(l10n.notSureLabel)),
          ],
          selected: {usesOrganicInputs},
          onSelectionChanged: (selection) => onOrganicChanged(selection.first),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: FilledButton(onPressed: onSave, child: Text(l10n.saveProfileButton))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(onPressed: onCancel, child: Text(l10n.cancelButton))),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              if (trailing != null) trailing!,
            ]),
          if (title.isNotEmpty) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
