import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _nimController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  bool _obscurePassword = true;
  bool _showOtpStep = false;

  int _resendCooldown = 0;
  int _resendCount = 0;

  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();

    _nameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 60) {
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = remainingSeconds.toString().padLeft(2, '0');

    return '$minStr:$secStr';
  }

  int _extractWaitSeconds(String errorMessage) {
    final regExp = RegExp(
      r'after\s+(\d+)\s+second',
      caseSensitive: false,
    );

    final match = regExp.firstMatch(errorMessage);

    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 60;
    }

    return 60;
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _resendCooldown = seconds;
    });

    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_resendCooldown <= 1) {
          timer.cancel();

          setState(() {
            _resendCooldown = 0;
          });
        } else {
          setState(() {
            _resendCooldown--;
          });
        }
      },
    );
  }

  String _getReadableError(Object error) {
    final errorText = error.toString();

    debugPrint('================================');
    debugPrint('ERROR REGISTER');
    debugPrint(errorText);
    debugPrint('================================');

    if (errorText.contains('over_email_send_rate') ||
        errorText.contains('rate limit') ||
        errorText.contains('too many requests') ||
        errorText.contains('429')) {
      return 'Terlalu banyak permintaan email. '
          'Silakan tunggu beberapa saat sebelum mencoba lagi.';
    }

    if (errorText.contains('Error sending confirmation email') ||
        errorText.contains('unexpected_failure') ||
        errorText.contains('AuthRetryableFetchException')) {
      return 'Kode OTP gagal dikirim ke email. '
          'Silakan periksa konfigurasi email Supabase '
          'atau coba gunakan email lain.';
    }

    if (errorText.contains('User already registered') ||
        errorText.contains('user_already_exists')) {
      return 'Email tersebut sudah terdaftar. '
          'Silakan gunakan email lain atau masuk ke akun yang sudah ada.';
    }

    if (errorText.contains('Password should be at least')) {
      return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
    }

    if (errorText.contains('invalid') &&
        errorText.contains('email')) {
      return 'Format email tidak valid.';
    }

    return errorText
        .replaceFirst('Exception: ', '')
        .replaceFirst('AuthException: ', '')
        .trim();
  }

  Future<void> _handleRegisterSubmit() async {
    final name = _nameController.text.trim();
    final nim = _nimController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      _showMessage(
        'Nama lengkap wajib diisi.',
        isError: true,
      );
      return;
    }

    if (nim.isEmpty) {
      _showMessage(
        'NIM wajib diisi.',
        isError: true,
      );
      return;
    }

    if (email.isEmpty ||
        !RegExp(
          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
        ).hasMatch(email)) {
      _showMessage(
        'Masukkan email yang valid.',
        isError: true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password minimal 6 karakter.',
        isError: true,
      );
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthService().signUp(
        email: email,
        password: password,
        name: name,
        nim: nim,
      );

      debugPrint('================================');
      debugPrint('REGISTER BERHASIL');
      debugPrint('User ID: ${response?.user?.id}');
      debugPrint('Email: ${response?.user?.email}');
      debugPrint('OTP SIGNUP TELAH DIMINTA');
      debugPrint('================================');

      if (!mounted) return;

      setState(() {
        _showOtpStep = true;
        _resendCount = 0;
        _resendCooldown = 0;
      });

      _showMessage(
        'Kode OTP telah dikirim ke $email',
      );

      Future.delayed(
        const Duration(milliseconds: 300),
        () {
          if (mounted) {
            _otpFocusNodes.first.requestFocus();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      final message = _getReadableError(e);
      final errorText = e.toString();

      if (errorText.contains('429') ||
          errorText.contains('over_email_send_rate') ||
          errorText.contains('rate limit') ||
          errorText.contains('after')) {
        final waitSeconds = _extractWaitSeconds(errorText);

        _startCooldownTimer(waitSeconds);

        _showMessage(
          'Silakan tunggu ${_formatDuration(waitSeconds)} sebelum meminta kode lagi.',
          isError: true,
        );
      } else {
        _showMessage(
          message,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _otpCode {
    return _otpControllers
        .map((controller) => controller.text)
        .join();
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpCode;
    final email = _emailController.text.trim();

    if (code.length != 6) {
      _showMessage(
        'Harap masukkan 6 digit kode OTP secara lengkap.',
        isError: true,
      );
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().verifySignupOtp(
        email: email,
        token: code,
      );

      if (!mounted) return;

      _showSuccessDialog();
    } catch (e) {
      debugPrint(
        'VERIFIKASI OTP REGISTRASI GAGAL: $e',
      );

      if (mounted) {
        _showMessage(
          'Kode OTP salah atau telah kedaluwarsa. '
          'Silakan periksa kembali.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendEmail() async {
    if (_resendCooldown > 0) return;
    if (_isResending) return;

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Email tidak ditemukan.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await AuthService().resendSignupOtp(email);

      if (!mounted) return;

      _resendCount++;

      int cooldownSeconds;

      if (_resendCount == 1) {
        cooldownSeconds = 0;
      } else if (_resendCount == 2) {
        cooldownSeconds = 60;
      } else if (_resendCount == 3) {
        cooldownSeconds = 900;
      } else {
        cooldownSeconds = 3600;
      }

      _showMessage(
        'Kode OTP baru telah dikirim ke $email',
      );

      if (cooldownSeconds > 0) {
        _startCooldownTimer(cooldownSeconds);
      }
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();
      final message = _getReadableError(e);

      if (errorText.contains('429') ||
          errorText.contains('over_email_send_rate') ||
          errorText.contains('rate limit') ||
          errorText.contains('after')) {
        final waitSeconds = _extractWaitSeconds(errorText);

        _startCooldownTimer(
          waitSeconds,
        );

        _showMessage(
          'Silakan tunggu ${_formatDuration(waitSeconds)} sebelum meminta kode baru.',
          isError: true,
        );
      } else {
        _showMessage(
          message,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Registrasi Berhasil! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun Anda telah terverifikasi. '
                'Silakan masuk menggunakan akun baru Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Masuk Sekarang',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    final messenger =
        ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF64748B),
        size: 21,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          if (_showOtpStep) {
                            setState(() {
                              _showOtpStep = false;
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                        ),
                        color: const Color(0xFF334155),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFF4F46E5),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB)
                                  .withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _showOtpStep
                              ? Icons
                                  .mark_email_unread_rounded
                              : Icons.school_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _showOtpStep
                          ? 'Verifikasi OTP ✉️'
                          : 'Buat Akun Baru 🚀',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _showOtpStep
                          ? 'Kami telah mengirimkan 6 digit kode OTP ke\n${_emailController.text}'
                          : 'Daftar untuk mulai menggunakan\nReelu.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (!_showOtpStep) ...[
                      const Text(
                        'Nama Lengkap',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _nameController,
                        textInputAction:
                            TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: 'Masukkan nama lengkap',
                          icon:
                              Icons.person_outline_rounded,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'NIM',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _nimController,
                        keyboardType:
                            TextInputType.number,
                        textInputAction:
                            TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly,
                        ],
                        decoration: _inputDecoration(
                          hint: 'Masukkan NIM',
                          icon: Icons.badge_outlined,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: 'Masukkan email kamu',
                          icon: Icons.email_outlined,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller:
                            _passwordController,
                        obscureText:
                            _obscurePassword,
                        textInputAction:
                            TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isLoading) {
                            _handleRegisterSubmit();
                          }
                        },
                        decoration: _inputDecoration(
                          hint: 'Minimal 6 karakter',
                          icon:
                              Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                              color: const Color(
                                0xFF64748B,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : _handleRegisterSubmit,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF2563EB),
                            disabledBackgroundColor:
                                const Color(0xFF93C5FD),
                            foregroundColor:
                                Colors.white,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Text(
                                      'Kirim Kode OTP',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons
                                          .arrow_forward_rounded,
                                      size: 19,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    if (_showOtpStep) ...[
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children:
                            List.generate(
                          6,
                          (index) {
                            return SizedBox(
                              width: 46,
                              height: 56,
                              child: TextField(
                                controller:
                                    _otpControllers[
                                        index],
                                focusNode:
                                    _otpFocusNodes[
                                        index],
                                keyboardType:
                                    TextInputType.number,
                                textAlign:
                                    TextAlign.center,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                ],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Color(0xFF0F172A),
                                ),
                                decoration:
                                    InputDecoration(
                                  counterText: '',
                                  contentPadding:
                                      EdgeInsets.zero,
                                  enabledBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(12),
                                    borderSide:
                                        const BorderSide(
                                      color:
                                          Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(12),
                                    borderSide:
                                        const BorderSide(
                                      color:
                                          Color(0xFF2563EB),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor:
                                      const Color(
                                    0xFFF8FAFC,
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty &&
                                      index < 5) {
                                    _otpFocusNodes[
                                            index + 1]
                                        .requestFocus();
                                  }

                                  if (_otpCode.length == 6) {
                                    _otpFocusNodes[5]
                                        .unfocus();

                                    _handleVerifyOtp();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : _handleVerifyOtp,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF2563EB),
                            disabledBackgroundColor:
                                const Color(0xFF93C5FD),
                            foregroundColor:
                                Colors.white,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Icon(
                                      Icons
                                          .verified_user_rounded,
                                      size: 19,
                                    ),
                                    SizedBox(width: 9),
                                    Text(
                                      'Verifikasi & Buat Akun',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed:
                              (_isResending ||
                                      _resendCooldown > 0)
                                  ? null
                                  : _handleResendEmail,
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF2563EB),
                            side: BorderSide(
                              color: _resendCooldown > 0
                                  ? const Color(
                                      0xFF94A3B8,
                                    )
                                  : const Color(
                                      0xFF2563EB,
                                    ),
                              width: 1.5,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                            ),
                          ),
                          child: _isResending
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      Color(0xFF2563EB),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    const Icon(
                                      Icons
                                          .refresh_rounded,
                                      size: 19,
                                    ),
                                    const SizedBox(
                                      width: 9,
                                    ),
                                    Text(
                                      _resendCooldown > 0
                                          ? 'Tunggu ${_formatDuration(_resendCooldown)}'
                                          : 'Kirim Ulang Email',
                                      style:
                                          const TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    if (!_showOtpStep) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color:
                                  Color(0xFFE2E8F0),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: Text(
                              'atau',
                              style: TextStyle(
                                color:
                                    Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color:
                                  Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sudah punya akun?',
                            style: TextStyle(
                              color:
                                  Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                              );
                            },
                            child: const Text(
                              'Masuk sekarang',
                              style: TextStyle(
                                color:
                                    Color(0xFF2563EB),
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                    ],

                    const Text(
                      '© 2026 Reelu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}