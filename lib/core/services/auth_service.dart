import 'package:flutter/foundation.dart';

/// A signed-in KrishiNetra user. Populated by whichever auth method
/// succeeded — phone OTP, Google, or offline guest mode.
@immutable
final class AuthUser {
  const AuthUser({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.email,
    this.photoUrl,
    this.isGuest = false,
  });

  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isGuest;

  // NOTE: no `greetingName` getter here anymore — a display-name fallback
  // ("Guest Farmer" / "Farmer") is UI copy, not domain data, and needs to
  // be localized. Screens compute it from `isGuest` / `displayName` /
  // `phoneNumber` directly using AppLocalizations.guestFarmerName /
  // .farmerNameFallback (see DashboardShell's `_greetingName`).
}

sealed class AuthState {
  const AuthState();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthPhoneOtpSent extends AuthState {
  const AuthPhoneOtpSent(this.phoneNumber);
  final String phoneNumber;
}

final class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

/// What went wrong, as data rather than an English sentence — so the UI
/// layer (which has access to AppLocalizations) decides how to phrase it
/// in the farmer's selected language. The service layer stays
/// locale-agnostic, same as it's backend-agnostic.
enum AuthErrorCode {
  otpSendFailed,
  otpIncomplete,
  verificationFailed,
  googleUnavailable,
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.code);
  final AuthErrorCode code;
}

/// Thin abstraction over authentication so screens never talk to a specific
/// backend directly. Backed today by a realistic in-memory simulation;
/// swapping the method bodies for real `firebase_auth` / `google_sign_in`
/// calls is a self-contained change once Firebase is provisioned.
final class AuthService {
  AuthUser? _cachedUser;

  AuthUser? get cachedUser => _cachedUser;

  bool get isAuthenticated => _cachedUser != null;

  Future<AuthState> signInWithPhone(String phoneNumber) async {
    try {
      await Future.delayed(const Duration(milliseconds: 900));
      return AuthPhoneOtpSent(phoneNumber);
    } catch (_) {
      return const AuthFailure(AuthErrorCode.otpSendFailed);
    }
  }

  Future<AuthState> verifyOTP({
    required String phoneNumber,
    required String smsCode,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 900));

      if (smsCode.length != 6) {
        return const AuthFailure(AuthErrorCode.otpIncomplete);
      }

      final AuthUser user = AuthUser(
        uid: 'phone_${phoneNumber.hashCode}',
        phoneNumber: phoneNumber,
      );
      _cachedUser = user;
      return AuthAuthenticated(user);
    } catch (_) {
      return const AuthFailure(AuthErrorCode.verificationFailed);
    }
  }

  Future<AuthState> signInWithGoogle() async {
    try {
      await Future.delayed(const Duration(milliseconds: 900));

      final AuthUser user = const AuthUser(
        uid: 'google_demo_user',
        displayName: 'Farmer Account',
        email: 'farmer@example.com',
      );
      _cachedUser = user;
      return AuthAuthenticated(user);
    } catch (_) {
      return const AuthFailure(AuthErrorCode.googleUnavailable);
    }
  }

  AuthState continueAsGuest() {
    final AuthUser guest = AuthUser(
      uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      isGuest: true,
    );
    _cachedUser = guest;
    return AuthAuthenticated(guest);
  }

  Future<void> signOut() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      _cachedUser = null;
    }
  }
}

/// App-wide singleton — every screen shares this one instance.
final AuthService authService = AuthService();

