import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/dbsupabase.dart';

class InputStatistikScreen extends StatefulWidget {
  final int? semester;
  final Map<String, dynamic>? existingData;

  const InputStatistikScreen({
    super.key,
    this.semester,
    this.existingData,
  });

  @override
  State<InputStatistikScreen> createState() => _InputStatistikScreenState();
}

class _InputStatistikScreenState extends State<InputStatistikScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _semesterController;
  late final TextEditingController _ipkController;
  late final TextEditingController _ipsController;
  late final TextEditingController _totalSksController;
  late final TextEditingController _targetSksController;

  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _darkBlue = const Color(0xFF102A63);
  final Color _textColor = const Color(0xFF182B4D);
  final Color _backgroundColor = const Color(0xFFF6FAFF);
  final Color _borderColor = const Color(0xFFDCEBFC);

  @override
  void initState() {
    super.initState();

    _semesterController = TextEditingController(
      text: widget.existingData?['semester']?.toString() ??
          widget.semester?.toString() ??
          '',
    );

    _ipkController = TextEditingController(
      text: _formatInitialValue(widget.existingData?['ipk']),
    );

    _ipsController = TextEditingController(
      text: _formatInitialValue(widget.existingData?['ips']),
    );

    _totalSksController = TextEditingController(
      text: widget.existingData?['total_sks']?.toString() ?? '',
    );

    _targetSksController = TextEditingController(
      text: widget.existingData?['target_sks']?.toString() ?? '',
    );
  }

  String _formatInitialValue(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      return value.toStringAsFixed(2);
    }

    return value.toString();
  }

  @override
  void dispose() {
    _semesterController.dispose();
    _ipkController.dispose();
    _ipsController.dispose();
    _totalSksController.dispose();
    _targetSksController.dispose();
    super.dispose();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'Sesi pengguna tidak ditemukan. Silakan masuk kembali.',
        isError: true,
      );
      return;
    }

    final int? semester = int.tryParse(
      _semesterController.text.trim(),
    );

    final double? ipk = double.tryParse(
      _ipkController.text.trim().replaceAll(',', '.'),
    );

    final double? ips = double.tryParse(
      _ipsController.text.trim().replaceAll(',', '.'),
    );

    final int? totalSks = int.tryParse(
      _totalSksController.text.trim(),
    );

    final int? targetSks = int.tryParse(
      _targetSksController.text.trim(),
    );

    if (semester == null ||
        ipk == null ||
        ips == null ||
        totalSks == null ||
        targetSks == null) {
      _showMessage(
        'Pastikan semua data diisi dengan benar.',
        isError: true,
      );
      return;
    }

    if (semester < 1) {
      _showMessage(
        'Semester harus dimulai dari semester 1.',
        isError: true,
      );
      return;
    }

    if (semester > 20) {
      _showMessage(
        'Semester tidak boleh lebih dari 20.',
        isError: true,
      );
      return;
    }

    if (ipk < 0 || ipk > 4) {
      _showMessage(
        'IPK harus berada di antara 0.00 sampai 4.00.',
        isError: true,
      );
      return;
    }

    if (ips < 0 || ips > 4) {
      _showMessage(
        'IPS harus berada di antara 0.00 sampai 4.00.',
        isError: true,
      );
      return;
    }

    if (totalSks < 0) {
      _showMessage(
        'Total SKS tidak boleh kurang dari 0.',
        isError: true,
      );
      return;
    }

    if (targetSks <= 0) {
      _showMessage(
        'Target SKS harus lebih dari 0.',
        isError: true,
      );
      return;
    }

    if (totalSks > targetSks) {
      _showMessage(
        'Total SKS tidak boleh lebih besar dari target SKS.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final existingId = widget.existingData?['id'];

      final data = {
        'user_id': user.id,
        'semester': semester,
        'ips': ips,
        'ipk': ipk,
        'total_sks': totalSks,
        'target_sks': targetSks,
      };

      if (existingId != null && existingId.toString().isNotEmpty) {
        await _supabase
            .from('academic_records')
            .update(data)
            .eq('id', existingId)
            .eq('user_id', user.id);
      } else {
        final existingRecord = await _supabase
            .from('academic_records')
            .select('id')
            .eq('user_id', user.id)
            .eq('semester', semester)
            .maybeSingle();

        if (existingRecord != null &&
            existingRecord['id'] != null) {
          await _supabase
              .from('academic_records')
              .update(data)
              .eq('id', existingRecord['id'])
              .eq('user_id', user.id);
        } else {
          await _supabase
              .from('academic_records')
              .insert(data);
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Data statistik berhasil disimpan.',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            80,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        e.message.isNotEmpty
            ? e.message
            : 'Gagal menyimpan data statistik.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Terjadi kesalahan saat menyimpan data.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          80,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String? _validateSemester(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Semester wajib diisi';
    }

    final semester = int.tryParse(value.trim());

    if (semester == null) {
      return 'Semester harus berupa angka';
    }

    if (semester < 1 || semester > 20) {
      return 'Semester harus antara 1 sampai 20';
    }

    return null;
  }

  String? _validateIpk(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IPK wajib diisi';
    }

    final ipk = double.tryParse(
      value.trim().replaceAll(',', '.'),
    );

    if (ipk == null) {
      return 'IPK harus berupa angka';
    }

    if (ipk < 0 || ipk > 4) {
      return 'IPK harus antara 0.00 sampai 4.00';
    }

    return null;
  }

  String? _validateIps(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IPS wajib diisi';
    }

    final ips = double.tryParse(
      value.trim().replaceAll(',', '.'),
    );

    if (ips == null) {
      return 'IPS harus berupa angka';
    }

    if (ips < 0 || ips > 4) {
      return 'IPS harus antara 0.00 sampai 4.00';
    }

    return null;
  }

  String? _validateSks(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Total SKS wajib diisi';
    }

    final sks = int.tryParse(value.trim());

    if (sks == null) {
      return 'SKS harus berupa angka';
    }

    if (sks < 0) {
      return 'SKS tidak boleh kurang dari 0';
    }

    return null;
  }

  String? _validateTargetSks(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Target SKS wajib diisi';
    }

    final sks = int.tryParse(value.trim());

    if (sks == null) {
      return 'Target SKS harus berupa angka';
    }

    if (sks <= 0) {
      return 'Target SKS harus lebih dari 0';
    }

    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
            prefixIcon: Icon(
              icon,
              color: _primaryColor,
              size: 21,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.red.shade300,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.red.shade400,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD6E8FF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: _primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Data yang kamu masukkan akan tersimpan berdasarkan semester dan digunakan untuk menampilkan perkembangan akademik pada Statistik Akademik.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isEdit = widget.existingData != null;

    return Row(
      children: [
        GestureDetector(
          onTap: _isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _darkBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit
                    ? 'Edit Statistik'
                    : 'Input Statistik',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _darkBlue,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isEdit
                    ? 'Perbarui data akademik semester ini'
                    : 'Masukkan data akademik per semester',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveData,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
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
                    Icons.save_rounded,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Simpan Data',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  16.0,
                  12.0,
                  16.0,
                  65.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 22),
                    _buildInfoCard(),
                    const SizedBox(height: 22),
                    _buildTextField(
                      controller: _semesterController,
                      label: 'Semester',
                      hint: 'Contoh: 1',
                      icon: Icons.school_rounded,
                      validator: _validateSemester,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _ipkController,
                      label: 'IPK',
                      hint: 'Contoh: 3.60',
                      icon: Icons.workspace_premium_rounded,
                      validator: _validateIpk,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _ipsController,
                      label: 'IPS',
                      hint: 'Contoh: 3.75',
                      icon: Icons.trending_up_rounded,
                      validator: _validateIps,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _totalSksController,
                      label: 'Total SKS',
                      hint: 'Contoh: 84',
                      icon: Icons.menu_book_rounded,
                      validator: _validateSks,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _targetSksController,
                      label: 'Target SKS',
                      hint: 'Contoh: 144',
                      icon: Icons.flag_rounded,
                      validator: _validateTargetSks,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _darkBlue,
                          side: BorderSide(
                            color: _borderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}