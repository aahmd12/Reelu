import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPasswordScreen extends StatefulWidget {
  const EditPasswordScreen({super.key});

  @override
  State<EditPasswordScreen> createState() =>
      _EditPasswordScreenState();
}

class _EditPasswordScreenState
    extends State<EditPasswordScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final TextEditingController _oldPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final oldPassword =
        _oldPasswordController.text.trim();

    final newPassword =
        _newPasswordController.text.trim();

    final confirmPassword =
        _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty) {
      _showMessage(
        'Password lama wajib diisi.',
        isError: true,
      );
      return;
    }

    if (newPassword.isEmpty) {
      _showMessage(
        'Password baru wajib diisi.',
        isError: true,
      );
      return;
    }

    if (newPassword.length < 6) {
      _showMessage(
        'Password baru minimal 6 karakter.',
        isError: true,
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      _showMessage(
        'Konfirmasi password baru wajib diisi.',
        isError: true,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage(
        'Password baru dan konfirmasi password tidak sama.',
        isError: true,
      );
      return;
    }

    if (oldPassword == newPassword) {
      _showMessage(
        'Password baru harus berbeda dari password lama.',
        isError: true,
      );
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null || user.email == null) {
      _showMessage(
        'Sesi akun tidak ditemukan. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: oldPassword,
      );

      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSuccessDialog();
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final message = e.message.toLowerCase();

      if (message.contains('invalid login credentials')) {
        _showMessage(
          'Password lama tidak sesuai.',
          isError: true,
        );
      } else {
        _showMessage(
          'Gagal mengubah password. Silakan coba lagi.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Terjadi kesalahan. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Password Berhasil Diubah',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Password akun kamu telah berhasil diperbarui.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Lanjutkan',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF16A34A),
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            80,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          enabled: !_isLoading,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF2563EB),
              size: 21,
            ),
            suffixIcon: IconButton(
              onPressed:
                  _isLoading ? null : onToggle,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
                size: 21,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            focusedBorder:
                const OutlineInputBorder(
              borderRadius:
                  BorderRadius.all(
                Radius.circular(12),
              ),
              borderSide: BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
            disabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                  },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.black87,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Ubah Password',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 380,
            ),
            child: _isLoading
                ? Column(
                    children: [
                      _buildHeader(),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16.0,
                      12.0,
                      16.0,
                      65.0,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEFF6FF),
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color:
                                    Color(0xFF2563EB),
                                size: 21,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Gunakan password baru yang mudah '
                                  'diingat tetapi tetap aman.',
                                  style: TextStyle(
                                    color:
                                        Color(0xFF1E40AF),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPasswordField(
                          controller:
                              _oldPasswordController,
                          label: 'Password Lama',
                          hint:
                              'Masukkan password lama',
                          obscureText:
                              _obscureOldPassword,
                          onToggle: () {
                            setState(() {
                              _obscureOldPassword =
                                  !_obscureOldPassword;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildPasswordField(
                          controller:
                              _newPasswordController,
                          label: 'Password Baru',
                          hint:
                              'Masukkan password baru',
                          obscureText:
                              _obscureNewPassword,
                          onToggle: () {
                            setState(() {
                              _obscureNewPassword =
                                  !_obscureNewPassword;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildPasswordField(
                          controller:
                              _confirmPasswordController,
                          label:
                              'Konfirmasi Password Baru',
                          hint:
                              'Masukkan kembali password baru',
                          obscureText:
                              _obscureConfirmPassword,
                          onToggle: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding:
                              EdgeInsets.only(left: 2),
                          child: Text(
                            'Password minimal 6 karakter.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : _updatePassword,
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF2563EB),
                              foregroundColor:
                                  Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF93C5FD),
                              elevation: 0,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Simpan Password',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}