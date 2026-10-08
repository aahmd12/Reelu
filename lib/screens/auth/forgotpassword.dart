import 'package:flutter/material.dart';
import '../../services/auth.dart';
import 'verify.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // =========================
  // CONTROLLER & FORM KEY
  // =========================
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // =========================
  // STATE
  // =========================
  bool _isLoading = false;

  // =========================
  // REGEX VALIDATION
  // =========================
  final RegExp _emailRegex = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  // =========================
  // KIRIM KODE RESET
  // =========================
  Future<void> _handleReset() async {
    // Validasi input form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    // =========================
    // MULAI LOADING
    // =========================
    setState(() {
      _isLoading = true;
    });

    try {
      // =========================
      // KIRIM KODE RESET
      // =========================
      await AuthService().sendPasswordReset(email);

      debugPrint('==============================');
      debugPrint('KODE RESET BERHASIL DIKIRIM');
      debugPrint('Email: $email');
      debugPrint('==============================');

      if (!mounted) return;

      // =========================
      // PESAN BERHASIL
      // =========================
      _showMessage(
        'Kode reset telah dikirim ke email kamu.',
      );

      // =========================
      // PINDAH KE HALAMAN VERIFIKASI
      // =========================
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyScreen(
            email: email,
          ),
        ),
      );
    } catch (e) {
      // =========================
      // JIKA GAGAL
      // =========================
      debugPrint('==============================');
      debugPrint('GAGAL MENGIRIM KODE RESET');
      debugPrint('Email: $email');
      debugPrint('Error: $e');
      debugPrint('==============================');

      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      // =========================
      // STOP LOADING
      // =========================
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================
  // SNACKBAR
  // =========================
  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
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

  // =========================
  // INPUT DECORATION
  // =========================
  InputDecoration _inputDecoration() {
    return InputDecoration(
      hintText: 'Masukkan email kamu',
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: Color(0xFF64748B),
        size: 21,
      ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE53935),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE53935),
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
    );
  }

  // =========================
  // DISPOSE
  // =========================
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // =========================
                      // BACK BUTTON
                      // =========================
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                          ),
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // =========================
                      // ICON
                      // =========================
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
                                color: const Color(0xFF2563EB)
                                    .withOpacity(0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // =========================
                      // TITLE
                      // =========================
                      const Text(
                        'Lupa Password? 🔐',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // =========================
                      // DESCRIPTION
                      // =========================
                      const Text(
                        'Masukkan email akun Reelu kamu.\n'
                        'Kami akan mengirimkan kode reset ke email kamu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // =========================
                      // INFO BOX
                      // =========================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFDBEAFE),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pastikan email yang dimasukkan sama '
                                'dengan email yang digunakan saat registrasi.',
                                style: TextStyle(
                                  color: Color(0xFF1E40AF),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // =========================
                      // EMAIL LABEL
                      // =========================
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // =========================
                      // EMAIL INPUT
                      // =========================
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _handleReset();
                          }
                        },
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Email wajib diisi.';
                          }
                          if (!_emailRegex.hasMatch(trimmed)) {
                            return 'Masukkan email yang valid.';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 24),

                      // =========================
                      // KIRIM KODE RESET
                      // =========================
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor:
                                const Color(0xFF93C5FD),
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
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 19,
                                    ),
                                    SizedBox(width: 9),
                                    Text(
                                      'Kirim Kode Reset',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // =========================
                      // DIVIDER
                      // =========================
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: Text(
                              'atau',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // =========================
                      // BACK TO LOGIN
                      // =========================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Ingat password?',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Kembali Login',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // =========================
                      // FOOTER
                      // =========================
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
      ),
    );
  }
}