import 'package:flutter/material.dart';
import '../core/constants/dbsupabase.dart';

class EditDataScreen extends StatefulWidget {
  const EditDataScreen({super.key});

  @override
  State<EditDataScreen> createState() => _EditDataScreenState();
}

class _EditDataScreenState extends State<EditDataScreen> {
  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _npmController =
      TextEditingController();

  final TextEditingController _studyProgramController =
      TextEditingController();

  final TextEditingController _universityController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _npmController.dispose();
    _studyProgramController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Sesi pengguna tidak ditemukan. Silakan login kembali.',
        isError: true,
      );

      return;
    }

    _userId = user.id;

    try {
      final response = await supabase
          .from('profiles')
          .select(
            'id, email, full_name, nim, prodi, univ',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _nameController.text =
            response['full_name']?.toString() ?? '';

        _npmController.text =
            response['nim']?.toString() ?? '';

        _studyProgramController.text =
            response['prodi']?.toString() ?? '';

        _universityController.text =
            response['univ']?.toString() ?? '';
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal mengambil data profil.',
        isError: true,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final npm = _npmController.text.trim();
    final studyProgram =
        _studyProgramController.text.trim();
    final university =
        _universityController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Nama mahasiswa wajib diisi.',
        isError: true,
      );
      return;
    }

    if (npm.isEmpty) {
      _showMessage(
        'NIM wajib diisi.',
        isError: true,
      );
      return;
    }

    if (studyProgram.isEmpty) {
      _showMessage(
        'Program studi wajib diisi.',
        isError: true,
      );
      return;
    }

    if (university.isEmpty) {
      _showMessage(
        'Universitas wajib diisi.',
        isError: true,
      );
      return;
    }

    _showConfirmationDialog(
      name: name,
      npm: npm,
      studyProgram: studyProgram,
      university: university,
    );
  }

  void _showConfirmationDialog({
    required String name,
    required String npm,
    required String studyProgram,
    required String university,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Periksa Data',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pastikan data yang kamu masukkan sudah benar sebelum menyimpan perubahan.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildConfirmationItem(
                  'Nama Lengkap',
                  name,
                ),
                _buildConfirmationItem(
                  'NIM',
                  npm,
                ),
                _buildConfirmationItem(
                  'Program Studi',
                  studyProgram,
                ),
                _buildConfirmationItem(
                  'Universitas',
                  university,
                ),
              ],
            ),
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(0xFF374151),
                side: const BorderSide(
                  color: Color(0xFFD1D5DB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Periksa kembali',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                _updateProfile(
                  name: name,
                  npm: npm,
                  studyProgram: studyProgram,
                  university: university,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
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

  Widget _buildConfirmationItem(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile({
    required String name,
    required String npm,
    required String studyProgram,
    required String university,
  }) async {
    final userId = _userId;

    if (userId == null) {
      _showMessage(
        'Sesi pengguna tidak ditemukan.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await supabase
          .from('profiles')
          .update({
        'full_name': name,
        'nim': npm,
        'prodi': studyProgram,
        'univ': university,
      }).eq('id', userId);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showSuccessMessage();

      await Future.delayed(
        const Duration(milliseconds: 900),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        'Gagal memperbarui data. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  void _showSuccessMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data profil berhasil diperbarui.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              const Color(0xFF16A34A),
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            80,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(
            milliseconds: 800,
          ),
        ),
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
          duration: const Duration(
            seconds: 3,
          ),
        ),
      );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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
          enabled: !_isSaving,
          keyboardType: keyboardType,
          textInputAction:
              TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF2563EB),
              size: 21,
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
        top: 8,
        bottom: 20,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: _isSaving
                ? null
                : () {
                    Navigator.pop(context);
                  },
            borderRadius: BorderRadius.circular(30),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.black87,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Edit Data Profil',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
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
      backgroundColor:
          const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                  strokeWidth: 2.5,
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                  ),
                  child: SingleChildScrollView(
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
                          child: const Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color:
                                    Color(0xFF2563EB),
                                size: 21,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Perbarui data profil kamu dengan informasi yang benar dan terbaru.',
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
                        _buildTextField(
                          controller:
                              _nameController,
                          label: 'Nama Lengkap',
                          hint:
                              'Masukkan nama lengkap',
                          icon:
                              Icons.person_outline_rounded,
                          keyboardType:
                              TextInputType.name,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller:
                              _npmController,
                          label: 'NIM',
                          hint: 'Masukkan NIM',
                          icon:
                              Icons.badge_outlined,
                          keyboardType:
                              TextInputType.number,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller:
                              _studyProgramController,
                          label: 'Program Studi',
                          hint:
                              'Masukkan program studi',
                          icon:
                              Icons.school_outlined,
                          keyboardType:
                              TextInputType.text,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller:
                              _universityController,
                          label: 'Universitas',
                          hint:
                              'Masukkan nama universitas',
                          icon:
                              Icons.account_balance_outlined,
                          keyboardType:
                              TextInputType.text,
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : _saveProfile,
                            style: ElevatedButton.styleFrom(
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
                                    BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
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
                                    'Simpan Perubahan',
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