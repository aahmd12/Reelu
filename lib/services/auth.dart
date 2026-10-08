import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {

  final SupabaseClient _supabase =
      Supabase.instance.client;

  Stream<AuthState> get userStatus =>
      _supabase.auth.onAuthStateChange;

  User? get currentUser =>
      _supabase.auth.currentUser;

  String? get currentUserId =>
      _supabase.auth.currentUser?.id;

  Session? get currentSession =>
      _supabase.auth.currentSession;

  bool get isLoggedIn =>
      _supabase.auth.currentSession != null;

  Future<AuthResponse?> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException {
      // Jangan ubah AuthException menjadi Exception biasa.
      // Supaya login.dart bisa membaca error dari Supabase
      // dan mengubahnya menjadi notifikasi bahasa Indonesia.
      rethrow;
    } catch (e) {
      throw Exception(
        'Gagal melakukan login.',
      );
    }
  }

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String name,
    required String nim,
  }) async {
    try {

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'nim': nim,
        },
      );

      if (response.user != null) {
        try {
          await _supabase.from('users').upsert({
            'id': response.user!.id,
            'name': name,
            'nim': nim,
            'email': email,
            'created_at':
                DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint(
            'Catatan: Gagal menyimpan profil ke tabel users: $e',
          );
        }
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal melakukan registrasi.',
      );
    }
  }

  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response =
          await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Kode OTP registrasi tidak valid atau sudah kedaluwarsa.',
      );
    }
  }

  Future<void> resendSignupOtp(
    String email,
  ) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal mengirim ulang kode OTP.',
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final email =
          _supabase.auth.currentUser?.email;

      if (email == null || email.isEmpty) {
        throw Exception(
          'Email pengguna tidak ditemukan.',
        );
      }

      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Gagal mengirim email verifikasi.',
      );
    }
  }

  Future<void> sendResetPasswordEmail(
    String email,
  ) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal mengirim kode reset password.',
      );
    }
  }

  Future<void> sendPasswordReset(
    String email,
  ) async {
    await sendResetPasswordEmail(email);
  }

  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response =
          await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Kode OTP reset password tidak valid atau sudah kedaluwarsa.',
      );
    }
  }

  Future<AuthResponse> verifyResetCode(
    String email,
    String code,
  ) async {
    return await verifyRecoveryOtp(
      email: email,
      token: code,
    );
  }

  Future<UserResponse> updateUserPassword(
    String newPassword,
  ) async {
    if (_supabase.auth.currentUser == null) {
      throw Exception(
        'Sesi tidak ditemukan atau sudah kedaluwarsa. '
        'Silakan verifikasi kode OTP kembali.',
      );
    }

    try {
      return await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal memperbarui password.',
      );
    }
  }

  Future<UserResponse> updatePassword(
    String newPassword,
  ) async {
    return await updateUserPassword(
      newPassword,
    );
  }

  Future<void> updatePasswordWithCode({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    if (_supabase.auth.currentSession == null) {
      throw Exception(
        'Sesi reset password tidak ditemukan. '
        'Silakan verifikasi kode OTP kembali.',
      );
    }

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal memperbarui password.',
      );
    }
  }

  Future<void> sendPasswordResetOTP({
    required String phoneNumber,
    required Function(
      String verificationId,
      int? resendToken,
    ) codeSent,
    required Function(Object e) verificationFailed,
  }) async {
    try {
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );

      codeSent(
        phoneNumber,
        null,
      );
    } catch (e) {
      verificationFailed(e);
    }
  }

  Future<AuthResponse> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      return await _supabase.auth.verifyOTP(
        phone: verificationId,
        token: smsCode,
        type: OtpType.sms,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Kode OTP tidak valid.',
      );
    }
  }

  Future<User?> reloadUser() async {
    try {
      final response =
          await _supabase.auth.getUser();

      return response.user;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal mengambil data pengguna.',
      );
    }
  }

  bool isEmailVerified() {
    return _supabase
            .auth
            .currentUser
            ?.emailConfirmedAt !=
        null;
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'Gagal keluar dari akun.',
      );
    }
  }
}

extension SupabaseUserExtension on User {
  String get uid => id;
}