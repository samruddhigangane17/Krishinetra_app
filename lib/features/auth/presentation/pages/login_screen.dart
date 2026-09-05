import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:krishinetra/core/services/auth_service.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/core/widgets/app_common_widgets.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onAuthenticated, super.key});

  final ValueChanged<AuthUser> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _resendHoldSeconds = 30;

  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  AuthState _state = const AuthUnauthenticated();
  AuthErrorCode? _errorCode;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;

  bool get _isPhoneValid => _phoneController.text.trim().length == 10;
  String get _fullPhoneNumber => '+91${_phoneController.text.trim()}';
  String get _enteredOtp => _otpControllers.map((c) => c.text).join();
  bool get _isBusy => _state is AuthAuthenticating;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = _resendHoldSeconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  Future<void> _submitPhoneNumber() async {
    if (!_isPhoneValid || _isBusy) return;

    setState(() {
      _state = const AuthAuthenticating();
      _errorCode = null;
    });

    final AuthState result = await authService.signInWithPhone(_fullPhoneNumber);
    if (!mounted) return;

    setState(() => _state = result);

    if (result is AuthPhoneOtpSent) {
      _startResendCountdown();
    } else if (result is AuthFailure) {
      setState(() => _errorCode = result.code);
    }
  }

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length != 6 || _isBusy) return;

    setState(() {
      _state = const AuthAuthenticating();
      _errorCode = null;
    });

    final AuthState result = await authService.verifyOTP(
      phoneNumber: _fullPhoneNumber,
      smsCode: _enteredOtp,
    );

    if (!mounted) return;

    if (result is AuthAuthenticated) {
      widget.onAuthenticated(result.user);
      return;
    }

    setState(() {
      _state = result;
      if (result is AuthFailure) _errorCode = result.code;
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) return;

    setState(() {
      _state = const AuthAuthenticating();
      _errorCode = null;
    });

    final AuthState result = await authService.signInWithGoogle();
    if (!mounted) return;

    if (result is AuthAuthenticated) {
      widget.onAuthenticated(result.user);
      return;
    }

    setState(() {
      _state = result;
      if (result is AuthFailure) _errorCode = result.code;
    });
  }

  void _continueAsGuest() {
    final AuthState result = authService.continueAsGuest();
    if (result is AuthAuthenticated) {
      widget.onAuthenticated(result.user);
    }
  }

  void _editPhoneNumber() {
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _state = const AuthUnauthenticated();
      _errorCode = null;
    });
  }

  /// Maps a locale-agnostic [AuthErrorCode] from the service layer to the
  /// farmer's currently selected language.
  String _errorText(AppLocalizations l10n, AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.otpSendFailed:
        return l10n.errorOtpSendFailed;
      case AuthErrorCode.otpIncomplete:
        return l10n.errorOtpIncomplete;
      case AuthErrorCode.verificationFailed:
        return l10n.errorVerificationFailed;
      case AuthErrorCode.googleUnavailable:
        return l10n.errorGoogleUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otpStage = _state is AuthPhoneOtpSent;

    Widget logo() => Row(children: [
      Image.asset('assets/logo.png', width: 40, height: 40,
        errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: AppColors.primary, size: 38)),
      const SizedBox(width: 10),
      const Text('KrishiNetra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
    ]);

    Widget form() => Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(otpStage ? l10n.enterOtp : 'Welcome Back',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(otpStage ? l10n.codeSentTo(_fullPhoneNumber) : 'Sign in to continue to your dashboard.',
          style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        if (_errorCode != null) ...[AppErrorBanner(message: _errorText(l10n, _errorCode!)), const SizedBox(height: 16)],
        if (!otpStage) ...[
          Text(l10n.phoneNumberLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _PhoneInputField(controller: _phoneController, onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _isPhoneValid && !_isBusy ? _submitPhoneNumber : null,
            child: _isBusy ? const AppButtonSpinner() : Text(l10n.getOtp),
          )),
        ] else ...[
          _OtpInputRow(controllers: _otpControllers, focusNodes: _otpFocusNodes,
            enabled: !_isBusy, onCompleted: _verifyOtp, onChanged: () => setState(() {})),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _enteredOtp.length == 6 && !_isBusy ? _verifyOtp : null,
            child: _isBusy ? const AppButtonSpinner() : Text(l10n.verifyAndProceed),
          )),
          Center(child: TextButton(
            onPressed: _isBusy ? null : _editPhoneNumber,
            child: Text(l10n.edit),
          )),
        ],
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(child: Divider(color: AppColors.outlineVariant)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l10n.orDivider)),
          const Expanded(child: Divider(color: AppColors.outlineVariant)),
        ]),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _isBusy ? null : _signInWithGoogle,
          icon: const _GoogleGlyph(), label: Text(l10n.signInWithGoogle),
        )),
        const SizedBox(height: 8),
        Center(child: TextButton(onPressed: _isBusy ? null : _continueAsGuest, child: Text(l10n.skipGuestMode))),
      ]),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (MediaQuery.sizeOf(context).width >= 850)
                Expanded(child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: const BoxDecoration(color: AppColors.primary),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    logo(),
                    const SizedBox(height: 180),
                    Text('See Your Soil.\nGrow Better.',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    const Text('Empowering your farm with AI-driven insights for healthier crops and better yields.',
                      style: TextStyle(color: Color(0xFFA8F3BD), fontSize: 17, height: 1.55)),
                    const SizedBox(height: 20),
                    Container(height: 3, width: 70, color: AppColors.accent),
                  ]),
                )),
              Expanded(child: Padding(padding: const EdgeInsets.all(32), child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: form()),
              ))),
              ]),
            ),
          ),
        ),
      ))),
    );
  }}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.colorScheme, required this.textTheme, required this.l10n});

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withOpacity(0.12)),
          child: Icon(Icons.eco_rounded, color: colorScheme.primary, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('KrishiNetra', style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          l10n.welcomeFarmer,
          style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
        ),
      ],
    );
  }
}

class _PhoneInputField extends StatelessWidget {
  const _PhoneInputField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.buttonRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇮🇳', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text('+91', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.outline),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                hintText: '98765 43210',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpSentBanner extends StatelessWidget {
  const _OtpSentBanner({
    required this.onEdit,
    required this.editLabel,
    required this.codeSentToText,
  });

  final VoidCallback? onEdit;
  final String editLabel;
  final String codeSentToText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.chip)),
      child: Row(
        children: [
          Icon(Icons.sms_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              codeSentToText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (onEdit != null) TextButton(onPressed: onEdit, child: Text(editLabel)),
        ],
      ),
    );
  }
}

class _OtpInputRow extends StatelessWidget {
  const _OtpInputRow({
    required this.controllers,
    required this.focusNodes,
    required this.enabled,
    required this.onCompleted,
    required this.onChanged,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool enabled;
  final VoidCallback onCompleted;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(controllers.length, (index) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.chip), borderSide: const BorderSide(color: AppColors.outline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.chip), borderSide: const BorderSide(color: AppColors.outline)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.chip), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
            onChanged: (value) {
              onChanged();
              if (value.isNotEmpty && index < controllers.length - 1) {
                focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                focusNodes[index - 1].requestFocus();
              }

              final bool allFilled = controllers.every((c) => c.text.isNotEmpty);
              if (allFilled) {
                FocusScope.of(context).unfocus();
                onCompleted();
              }
            },
          ),
        );
      }),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.outline)),
      child: const Text('G', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
    );
  }
}
