import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth.dart';

class VerifyScreen extends StatefulWidget {
  final String email;

  const VerifyScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  // =========================
  // STATE & CONTROLLERS
  // =========================
  bool _isLoading = false;
  bool _isResending = false;
  bool _isOtpVerified = false;

  int _resendCooldown = 0;
  int _resendCount = 0; // Menghitung berapa kali tombol "Kirim Ulang Email" ditekan
  Timer? _cooldownTimer;

  // Controllers & FocusNodes 6 digit OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Controllers untuk Form Password Baru
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // =========================
  // HELPER FORMAT WAKTU
  // =========================
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

  // =========================
  // HELPER EKSTRAKSI DETIK ERROR
  // =========================
  int _extractWaitSeconds(String errorMessage) {
    // Mencari pola angka sebelum kata "second" (contoh: "after 12 seconds")
    final regExp = RegExp(r'after\s+(\d+)\s+second', caseSensitive: false);
    final match = regExp.firstMatch(errorMessage);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!) ?? 60;
    }
    return 60; // Default cooldown jika angka tidak terdeteksi
  }

  // =========================
  // COOLDOWN TIMER
  // =========================
  void _startCooldownTimer(int seconds) {
    setState(() {
      _resendCooldown = seconds;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCooldown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      }
    });
  }

  // =========================
  // LOGIKA VERIFIKASI OTP
  // =========================
  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  Future<void> _handleVerifyOtp() async {
    final code = _otpCode;
    if (code.length < 6) {
      _showMessage('Harap masukkan 6 digit kode OTP dengan lengkap.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().verifyRecoveryOtp(
        email: widget.email,
        token: code,
      );

      if (!mounted) return;

      setState(() {
        _isOtpVerified = true;
      });
      _showMessage('Kode OTP berhasil diverifikasi!');
    } catch (e) {
      debugPrint('VERIFIKASI OTP GAGAL: $e');
      if (mounted) {
        _showMessage(
          'Kode OTP salah atau telah kadaluarsa. Silakan periksa kembali.',
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

  // =========================
  // LOGIKA RESET PASSWORD
  // =========================
  Future<void> _handleResetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Password tidak boleh kosong.', isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Password minimal terdiri dari 6 karakter.', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Konfirmasi password tidak cocok.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().updateUserPassword(newPassword);

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
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

  // =========================
  // KIRIM ULANG EMAIL / OTP
  // =========================
  Future<void> _handleResendEmail() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      await AuthService().sendResetPasswordEmail(widget.email);

      if (!mounted) return;

      _resendCount++;
      int cooldownSeconds = 0;

      if (_resendCount == 1) {
        cooldownSeconds = 0;
      } else if (_resendCount == 2) {
        cooldownSeconds = 60;
      } else if (_resendCount == 3) {
        cooldownSeconds = 900;
      } else {
        cooldownSeconds = 3600;
      }

      _showMessage('Kode OTP baru telah dikirim ke email kamu.');

      if (cooldownSeconds > 0) {
        _startCooldownTimer(cooldownSeconds);
      }
    } catch (e) {
      if (!mounted) return;

      final errStr = e.toString();

      // Cek apakah error merupakan Rate Limit (StatusCode 429 atau over mail send rate)
      if (errStr.contains('429') ||
          errStr.contains('over_email_send_rate') ||
          errStr.contains('rate limit') ||
          errStr.contains('after')) {
        final waitSeconds = _extractWaitSeconds(errStr);

        // Jalankan timer cooldown sesuai detik yang diminta server
        _startCooldownTimer(waitSeconds);

        _showMessage(
          'Harap tunggu ${_formatDuration(waitSeconds)} sebelum meminta kode baru.',
          isError: true,
        );
      } else {
        // Error umum lainnya
        _showMessage(
          errStr.replaceFirst('Exception: ', ''),
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

  // =========================
  // POP-UP DIALOG SUKSES
  // =========================
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
                'Password Berhasil Diubah!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Password Anda telah berhasil diperbarui. Silakan login kembali menggunakan password baru Anda.',
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
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Kembali ke Halaman Login',
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

  // =========================
  // SNACKBAR
  // =========================
  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
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
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
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
                    // BACK BUTTON
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () async {
                          await AuthService().signOut();
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: const Color(0xFF334155),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ICON
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
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isOtpVerified
                              ? Icons.lock_reset_rounded
                              : Icons.mark_email_unread_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // TITLE & SUBTITLE
                    Text(
                      _isOtpVerified ? 'Buat Password Baru 🔐' : 'Verifikasi OTP ✉️',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _isOtpVerified
                          ? 'Silakan masukkan password baru Anda.'
                          : 'Kami telah mengirimkan 6 digit kode OTP ke\n${widget.email}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // TAMPILAN 1: INPUT 6 KOTAK OTP
                    // ==========================================
                    if (!_isOtpVerified) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 46,
                            height: 56,
                            child: KeyboardListener(
                              focusNode: FocusNode(),
                              onKeyEvent: (event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.backspace) {
                                  if (_otpControllers[index].text.isEmpty && index > 0) {
                                    _otpFocusNodes[index - 1].requestFocus();
                                    _otpControllers[index - 1].clear();
                                  }
                                }
                              },
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _otpFocusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  counterText: "",
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2563EB),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                onChanged: (value) {
                                  // FITUR: Deteksi jika user paste 6 digit teks sekaligus
                                  if (value.length > 1) {
                                    final digits = value.replaceAll(RegExp(r'\D'), '');
                                    for (int i = 0; i < 6 && i < digits.length; i++) {
                                      _otpControllers[i].text = digits[i];
                                    }
                                    if (digits.length >= 6) {
                                      _otpFocusNodes[5].unfocus();
                                      _handleVerifyOtp(); // Otomatis verifikasi
                                    }
                                    return;
                                  }

                                  // Pindah fokus ke kotak berikutnya
                                  if (value.isNotEmpty && index < 5) {
                                    _otpFocusNodes[index + 1].requestFocus();
                                  }

                                  // Otomatis verifikasi jika digit terakhir telah diisi
                                  if (_otpCode.length == 6) {
                                    _handleVerifyOtp();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 32),

                      // TOMBOL VERIFIKASI KODE OTP
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      size: 19,
                                    ),
                                    SizedBox(width: 9),
                                    Text(
                                      'Kirim Kode',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // TOMBOL KIRIM ULANG EMAIL
                      SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: (_isResending || _resendCooldown > 0)
                              ? null
                              : _handleResendEmail,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: BorderSide(
                              color: _resendCooldown > 0
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF2563EB),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isResending
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2563EB),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.refresh_rounded,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      _resendCooldown > 0
                                          ? 'Tunggu ${_formatDuration(_resendCooldown)}'
                                          : 'Kirim Ulang Email',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    // ==========================================
                    // TAMPILAN 2: FORM ISI NEW & CONFIRM PASSWORD
                    // ==========================================
                    if (_isOtpVerified) ...[
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password Baru',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Simpan Password Baru',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // FOOTER
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