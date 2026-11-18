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
  late final TextEditingController _kehadiranController;

  bool _isLoading = false;
  bool _isInitializing = true;

  Map<String, dynamic>? _existingRecord;

  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _darkBlue = const Color(0xFF102A63);
  final Color _textColor = const Color(0xFF182B4D);
  final Color _backgroundColor = const Color(0xFFF6FAFF);
  final Color _borderColor = const Color(0xFFDCEBFC);

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    _semesterController = TextEditingController(
      text: widget.semester?.toString() ??
          widget.existingData?['semester']?.toString() ??
          '',
    );

    _ipkController = TextEditingController();
    _ipsController = TextEditingController();
    _totalSksController = TextEditingController();
    _targetSksController = TextEditingController();
    _kehadiranController = TextEditingController();

    _loadExistingData();
  }

  String _formatInitialValue(dynamic value) {
    if (value == null) return '';

    if (value is num) {
      return value.toStringAsFixed(2);
    }

    return value.toString();
  }

  void _clearForm() {
    _ipkController.clear();
    _ipsController.clear();
    _totalSksController.clear();
    _targetSksController.clear();
    _kehadiranController.clear();
    _existingRecord = null;
  }

  Future<void> _loadExistingData() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _clearForm();
        _isInitializing = false;
      });
      return;
    }

    try {
      final int? selectedSemester = int.tryParse(
        _semesterController.text.trim(),
      );

      Map<String, dynamic>? record;

      if (selectedSemester != null) {
        final response = await _supabase
            .from('academic_records')
            .select(
              'id, user_id, semester, ips, ipk, total_sks, target_sks, kehadiran, created_at',
            )
            .eq('user_id', user.id)
            .eq('semester', selectedSemester)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        record = response;
      } else {
        final existingId = widget.existingData?['id'];

        if (existingId != null) {
          record = await _supabase
              .from('academic_records')
              .select(
                'id, user_id, semester, ips, ipk, total_sks, target_sks, kehadiran, created_at',
              )
              .eq('id', existingId)
              .eq('user_id', user.id)
              .maybeSingle();
        }
      }

      if (!mounted) return;

      setState(() {
        if (record == null) {
          // Jika data sudah dihapus, seluruh kolom harus kosong.
          _clearForm();
        } else {
          _existingRecord = record;

          _ipkController.text = _formatInitialValue(record['ipk']);
          _ipsController.text = _formatInitialValue(record['ips']);

          _totalSksController.text =
              record['total_sks']?.toString() ?? '';

          _targetSksController.text =
              record['target_sks']?.toString() ?? '';

          _kehadiranController.text =
              _formatInitialValue(record['kehadiran']);

          _semesterController.text =
              record['semester']?.toString() ?? '';
        }
      });
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Gagal mengambil data statistik: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _semesterController.dispose();
    _ipkController.dispose();
    _ipsController.dispose();
    _totalSksController.dispose();
    _targetSksController.dispose();
    _kehadiranController.dispose();

    super.dispose();
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
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF16A765),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

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

    final double? kehadiran = double.tryParse(
      _kehadiranController.text.trim().replaceAll(',', '.'),
    );

    if (semester == null ||
        ipk == null ||
        ips == null ||
        totalSks == null ||
        targetSks == null ||
        kehadiran == null) {
      _showMessage(
        'Pastikan semua data diisi dengan benar.',
        isError: true,
      );
      return;
    }

    if (semester < 1 || semester > 20) {
      _showMessage(
        'Semester harus berada di antara 1 sampai 20.',
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

    if (kehadiran < 0 || kehadiran > 100) {
      _showMessage(
        'Kehadiran harus berada di antara 0 sampai 100%.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'user_id': user.id,
        'semester': semester,
        'ips': ips,
        'ipk': ipk,
        'total_sks': totalSks,
        'target_sks': targetSks,
        'kehadiran': kehadiran,
      };

      // Ambil satu record terbaru untuk semester yang dipilih.
      final existingRecord = await _supabase
          .from('academic_records')
          .select('id')
          .eq('user_id', user.id)
          .eq('semester', semester)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingRecord != null && existingRecord['id'] != null) {
        // Perbarui record terbaru jika masih tersedia.
        await _supabase
            .from('academic_records')
            .update(data)
            .eq('id', existingRecord['id'])
            .eq('user_id', user.id);
      } else {
        // Jika record sudah tidak ada, buat record baru.
        await _supabase
            .from('academic_records')
            .insert(data);
      }

      if (!mounted) return;

      _showMessage('Data statistik berhasil disimpan.');

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      _showMessage(
        'Gagal menyimpan data: $e',
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

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: label == 'Kehadiran' ? '%' : null,
      prefixIcon: Icon(
        icon,
        color: _primaryColor,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
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
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.number,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: TextStyle(
        color: _textColor,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
      ),
      validator: validator,
    );
  }

  Widget _buildNavigationHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Data Statistik',
        style: TextStyle(
          color: _darkBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isEditing = _existingRecord != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'Edit Data Statistik'
                      : 'Lengkapi Data Statistik',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isEditing
                      ? 'Perbarui data akademik semester kamu.'
                      : 'Masukkan data akademik setiap semester.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _darkBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.blueGrey.shade400,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    final bool isEditing = _existingRecord != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 26),

          _buildSectionTitle(
            'Informasi Semester',
            'Tentukan semester dari data akademik yang ingin disimpan.',
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Semester',
            hint: 'Contoh: 1',
            icon: Icons.calendar_month_rounded,
            controller: _semesterController,
            readOnly: widget.semester != null ||
                _existingRecord != null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Semester wajib diisi.';
              }

              final semester = int.tryParse(value.trim());

              if (semester == null ||
                  semester < 1 ||
                  semester > 20) {
                return 'Masukkan semester antara 1 sampai 20.';
              }

              return null;
            },
          ),

          const SizedBox(height: 22),

          _buildSectionTitle(
            'Nilai Akademik',
            'Masukkan nilai IPK dan IPS sesuai hasil akademik.',
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'IPK',
            hint: 'Contoh: 3.75',
            icon: Icons.school_rounded,
            controller: _ipkController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'IPK wajib diisi.';
              }

              final number = double.tryParse(
                value.trim().replaceAll(',', '.'),
              );

              if (number == null || number < 0 || number > 4) {
                return 'IPK harus berada di antara 0.00 sampai 4.00.';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildInputField(
            label: 'IPS',
            hint: 'Contoh: 3.80',
            icon: Icons.bar_chart_rounded,
            controller: _ipsController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'IPS wajib diisi.';
              }

              final number = double.tryParse(
                value.trim().replaceAll(',', '.'),
              );

              if (number == null || number < 0 || number > 4) {
                return 'IPS harus berada di antara 0.00 sampai 4.00.';
              }

              return null;
            },
          ),

          const SizedBox(height: 22),

          _buildSectionTitle(
            'Informasi SKS',
            'Lengkapi jumlah SKS yang sudah dan akan ditempuh.',
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Total SKS yang Ditempuh',
            hint: 'Contoh: 80',
            icon: Icons.menu_book_rounded,
            controller: _totalSksController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Total SKS wajib diisi.';
              }

              final number = int.tryParse(value.trim());

              if (number == null || number < 0) {
                return 'Masukkan total SKS yang valid.';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildInputField(
            label: 'Target Total SKS',
            hint: 'Contoh: 144',
            icon: Icons.flag_rounded,
            controller: _targetSksController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Target SKS wajib diisi.';
              }

              final number = int.tryParse(value.trim());

              if (number == null || number <= 0) {
                return 'Target SKS harus lebih dari 0.';
              }

              return null;
            },
          ),

          const SizedBox(height: 22),

          _buildSectionTitle(
            'Informasi Kehadiran',
            'Masukkan persentase kehadiran selama semester berlangsung.',
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Kehadiran',
            hint: 'Contoh: 90',
            icon: Icons.event_available_rounded,
            controller: _kehadiranController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Kehadiran wajib diisi.';
              }

              final number = double.tryParse(
                value.trim().replaceAll(',', '.'),
              );

              if (number == null || number < 0 || number > 100) {
                return 'Kehadiran harus berada di antara 0 sampai 100%.';
              }

              return null;
            },
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isEditing
                              ? Icons.save_rounded
                              : Icons.check_circle_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          isEditing
                              ? 'Simpan Perubahan'
                              : 'Simpan Data',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkBlue,
                side: BorderSide(color: _borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Kembali',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16.0,
                    12.0,
                    16.0,
                    0,
                  ),
                  child: _buildNavigationHeader(),
                ),
                Expanded(
                  child: _isInitializing
                      ? Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            12.0,
                            16.0,
                            65.0,
                          ),
                          child: _buildFormContent(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}