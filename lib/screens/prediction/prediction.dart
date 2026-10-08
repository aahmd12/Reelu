import 'package:flutter/material.dart';

import '../../models/academicrecord.dart';
import '../../services/academic.dart';
import '../../services/auth.dart';
import '../../core/constants/dbsupabase.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _ipkController =
      TextEditingController();

  final TextEditingController _sksController =
      TextEditingController();

  final TextEditingController _targetSksController =
      TextEditingController();

  final TextEditingController _kehadiranController =
      TextEditingController();

  final TextEditingController _belumLulusController =
      TextEditingController();

  final TextEditingController _mengulangController =
      TextEditingController();

  String _semester = 'Semester 1';

  List<AcademicRecord> _records = [];

  bool _isLoading = true;
  bool _isPredicting = false;
  bool _dataLoaded = false;

  String? _errorMessage;

  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _darkColor = Color(0xFF071D49);
  static const Color _secondaryTextColor = Color(0xFF667085);
  static const Color _backgroundColor = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
  }

  @override
  void dispose() {
    _ipkController.dispose();
    _sksController.dispose();
    _targetSksController.dispose();
    _kehadiranController.dispose();
    _belumLulusController.dispose();
    _mengulangController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicData() async {
    final user = _authService.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _dataLoaded = false;
          _errorMessage =
              'User tidak ditemukan. Silakan login kembali.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final records =
          await AcademicService().getAcademicRecords(user.id);

      if (mounted) {
        setState(() {
          _records = records;
          _dataLoaded = true;
          _isLoading = false;
          _semester = 'Semester 1';
        });
      }
    } catch (e) {
      debugPrint(
        'Gagal mengambil data akademik: $e',
      );

      if (mounted) {
        setState(() {
          _records = [];
          _dataLoaded = true;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    }
  }

  void _clearPredictionForm() {
    _ipkController.clear();
    _sksController.clear();
    _targetSksController.clear();
    _kehadiranController.clear();
    _belumLulusController.clear();
    _mengulangController.clear();

    setState(() {
      _semester = 'Semester 1';
    });
  }

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '';
    }

    final number = double.tryParse(
      value.toString().replaceAll(',', '.'),
    );

    if (number == null) {
      return value.toString();
    }

    return number.toStringAsFixed(2);
  }

  double? _parseDouble(String value) {
    final cleaned =
        value.trim().replaceAll(',', '.');

    if (cleaned.isEmpty) {
      return null;
    }

    return double.tryParse(cleaned);
  }

  int? _parseInt(String value) {
    return int.tryParse(value.trim());
  }

  int _getSemesterNumber() {
    return int.tryParse(
          _semester.replaceAll(
            'Semester ',
            '',
          ),
        ) ??
        1;
  }

  bool _validateData() {
    final ipk = _parseDouble(
      _ipkController.text,
    );

    final sks = _parseInt(
      _sksController.text,
    );

    final targetSks = _parseInt(
      _targetSksController.text,
    );

    final kehadiran = _parseDouble(
      _kehadiranController.text,
    );

    final belumLulus = _parseInt(
      _belumLulusController.text,
    );

    final mengulang = _parseInt(
      _mengulangController.text,
    );

    if (ipk == null) {
      _showMessage(
        'IPK harus diisi dengan angka yang valid.',
      );
      return false;
    }

    if (ipk < 0 || ipk > 4) {
      _showMessage(
        'IPK harus berada di antara 0.00 sampai 4.00.',
      );
      return false;
    }

    if (sks == null) {
      _showMessage(
        'Total SKS harus diisi dengan angka yang valid.',
      );
      return false;
    }

    if (sks < 0) {
      _showMessage(
        'Total SKS tidak boleh kurang dari 0.',
      );
      return false;
    }

    if (targetSks == null) {
      _showMessage(
        'Target SKS harus diisi dengan angka yang valid.',
      );
      return false;
    }

    if (targetSks <= 0) {
      _showMessage(
        'Target SKS harus lebih dari 0.',
      );
      return false;
    }

    if (sks > targetSks) {
      _showMessage(
        'Total SKS tidak boleh lebih besar dari Target SKS.',
      );
      return false;
    }

    if (kehadiran == null) {
      _showMessage(
        'Persentase kehadiran harus diisi dengan angka yang valid.',
      );
      return false;
    }

    if (kehadiran < 0 || kehadiran > 100) {
      _showMessage(
        'Persentase kehadiran harus berada di antara 0 sampai 100.',
      );
      return false;
    }

    if (belumLulus == null) {
      _showMessage(
        'Mata kuliah belum lulus harus diisi dengan angka yang valid.',
      );
      return false;
    }

    if (belumLulus < 0) {
      _showMessage(
        'Mata kuliah belum lulus tidak boleh kurang dari 0.',
      );
      return false;
    }

    if (mengulang == null) {
      _showMessage(
        'Mata kuliah mengulang harus diisi dengan angka yang valid.',
      );
      return false;
    }

    if (mengulang < 0) {
      _showMessage(
        'Mata kuliah mengulang tidak boleh kurang dari 0.',
      );
      return false;
    }

    return true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculatePrediction() {
    final double ipk =
        _parseDouble(_ipkController.text) ?? 0;

    final int sks =
        _parseInt(_sksController.text) ?? 0;

    final int targetSks =
        _parseInt(_targetSksController.text) ?? 1;

    final double kehadiran =
        _parseDouble(_kehadiranController.text) ?? 0;

    final int belumLulus =
        _parseInt(_belumLulusController.text) ?? 0;

    final int mengulang =
        _parseInt(_mengulangController.text) ?? 0;

    final int semester = _getSemesterNumber();

    final double ipkScore =
        (ipk / 4.0) * 40.0;

    double sksProgress =
        (sks / targetSks) * 100;

    sksProgress =
        sksProgress.clamp(0.0, 100.0);

    final double sksScore =
        (sksProgress / 100.0) * 25.0;

    final double attendanceScore =
        (kehadiran / 100.0) * 15.0;

    final double failedScore =
        (10.0 - (belumLulus * 2.0))
            .clamp(0.0, 10.0);

    final double repeatScore =
        (5.0 - mengulang)
            .clamp(0.0, 5.0);

    final double semesterScore =
        ((semester / 8.0) * 5.0)
            .clamp(0.0, 5.0);

    double probability =
        ipkScore +
        sksScore +
        attendanceScore +
        failedScore +
        repeatScore +
        semesterScore;

    if (ipk < 2.00) {
      probability -= 12;
    } else if (ipk < 2.50) {
      probability -= 6;
    }

    if (kehadiran < 60) {
      probability -= 8;
    } else if (kehadiran < 75) {
      probability -= 4;
    }

    if (belumLulus >= 5) {
      probability -= 8;
    } else if (belumLulus >= 3) {
      probability -= 4;
    }

    if (mengulang >= 5) {
      probability -= 5;
    } else if (mengulang >= 3) {
      probability -= 2;
    }

    if (sksProgress < 40) {
      probability -= 8;
    } else if (sksProgress < 60) {
      probability -= 4;
    }

    probability =
        probability.clamp(0.0, 100.0);

    probability =
        double.parse(
      probability.toStringAsFixed(2),
    );

    String status;
    String recommendation;

    if (probability >= 80) {
      status = 'Sangat Berpotensi Lulus';

      recommendation =
          'Kondisi akademik menunjukkan peluang kelulusan '
          'yang sangat baik. Pertahankan IPK, kehadiran, '
          'dan terus selesaikan sisa SKS sesuai target.';
    } else if (probability >= 65) {
      status = 'Berpotensi Lulus';

      recommendation =
          'Peluang kelulusan cukup baik. Pertahankan '
          'performa akademik dan fokus menyelesaikan '
          'mata kuliah yang belum lulus.';
    } else if (probability >= 50) {
      status = 'Perlu Perhatian';

      recommendation =
          'Peluang kelulusan masih berada pada tingkat '
          'sedang. Tingkatkan IPK dan kehadiran serta '
          'kurangi jumlah mata kuliah yang belum lulus '
          'dan mengulang.';
    } else if (probability >= 35) {
      status = 'Risiko Terlambat';

      recommendation =
          'Terdapat beberapa faktor yang dapat menghambat '
          'kelulusan. Fokus memperbaiki IPK, meningkatkan '
          'kehadiran, dan menyelesaikan mata kuliah yang '
          'belum lulus.';
    } else {
      status = 'Risiko Tinggi';

      recommendation =
          'Kondisi akademik menunjukkan risiko kelulusan '
          'yang cukup tinggi. Disarankan meningkatkan '
          'performa akademik, kehadiran, dan segera '
          'menyelesaikan mata kuliah yang bermasalah.';
    }

    debugPrint(
      'PERHITUNGAN PREDIKSI',
    );

    debugPrint(
      'IPK              : $ipk',
    );

    debugPrint(
      'Total SKS        : $sks',
    );

    debugPrint(
      'Target SKS       : $targetSks',
    );

    debugPrint(
      'Progress SKS     : $sksProgress%',
    );

    debugPrint(
      'Semester         : $semester',
    );

    debugPrint(
      'Kehadiran        : $kehadiran%',
    );

    debugPrint(
      'MK Belum Lulus   : $belumLulus',
    );

    debugPrint(
      'MK Mengulang     : $mengulang',
    );

    debugPrint(
      'Score IPK        : $ipkScore',
    );

    debugPrint(
      'Score SKS        : $sksScore',
    );

    debugPrint(
      'Score Kehadiran  : $attendanceScore',
    );

    debugPrint(
      'Score Belum Lulus: $failedScore',
    );

    debugPrint(
      'Score Mengulang  : $repeatScore',
    );

    debugPrint(
      'Score Semester   : $semesterScore',
    );

    debugPrint(
      'PROBABILITAS     : $probability%',
    );

    debugPrint(
      'STATUS           : $status',
    );

    return {
      'percentage': probability,
      'status': status,
      'recommendation': recommendation,
    };
  }

  Future<void> _showConfirmationDialog() async {
    FocusScope.of(context).unfocus();

    if (!_validateData()) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 380,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  16.0,
                  12.0,
                  16.0,
                  65.0,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfirmasi Data',
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pastikan data akademik yang dimasukkan sudah benar.',
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildConfirmationItem(
                        'IPK',
                        _ipkController.text,
                      ),
                      _buildConfirmationItem(
                        'Total SKS',
                        _sksController.text,
                      ),
                      _buildConfirmationItem(
                        'Target SKS',
                        _targetSksController.text,
                      ),
                      _buildConfirmationItem(
                        'Semester',
                        _semester,
                      ),
                      _buildConfirmationItem(
                        'Kehadiran',
                        '${_kehadiranController.text}%',
                      ),
                      _buildConfirmationItem(
                        'MK Belum Lulus',
                        _belumLulusController.text,
                      ),
                      _buildConfirmationItem(
                        'MK Mengulang',
                        _mengulangController.text,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isPredicting
                              ? null
                              : () async {
                                  Navigator.pop(
                                    dialogContext,
                                  );

                                  await _runPrediction();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _primaryColor,
                            disabledBackgroundColor:
                                _primaryColor,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: _isPredicting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Lanjutkan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(
                              dialogContext,
                            );
                          },
                          style:
                              OutlinedButton.styleFrom(
                            backgroundColor:
                                Colors.white,
                            side: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Periksa Lagi',
                            style: TextStyle(
                              color: _darkColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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
      },
    );
  }

  Widget _buildConfirmationItem(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _darkColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runPrediction() async {
    final user = _authService.currentUser;

    if (user == null) {
      _showMessage(
        'User tidak ditemukan. Silakan login kembali.',
      );
      return;
    }

    if (!_validateData()) {
      return;
    }

    if (mounted) {
      setState(() {
        _isPredicting = true;
      });
    }

    try {
      final result =
          _calculatePrediction();

      final percentage =
          result['percentage']?.toString() ?? '0';

      final status =
          result['status']?.toString() ??
              'Tidak Ada Status';

      final recommendation =
          result['recommendation']?.toString() ??
              'Tidak ada rekomendasi.';

      final probability =
          double.tryParse(
        percentage.replaceAll(',', '.'),
      );

      if (probability == null) {
        throw Exception(
          'Nilai probabilitas tidak valid: $percentage',
        );
      }

      if (probability < 0 ||
          probability > 100) {
        throw Exception(
          'Probabilitas harus berada di antara 0 sampai 100.',
        );
      }

      final predictionData = {
        'user_id': user.id,
        'status_lulus': status,
        'probabilitas': probability,
      };

      debugPrint(
        'DATA PREDIKSI YANG AKAN DISIMPAN: '
        '$predictionData',
      );

      final insertedData = await supabase
          .from('predictions')
          .insert(predictionData)
          .select()
          .single();

      debugPrint(
        'PREDIKSI BERHASIL DISIMPAN: $insertedData',
      );

      if (!mounted) {
        return;
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration:
                            BoxDecoration(
                          color: _primaryColor
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: _primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Hasil Prediksi',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$percentage%',
                        style:
                            const TextStyle(
                          color:
                              _primaryColor,
                          fontSize: 38,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          color: _darkColor,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          color: const Color(
                            0xFFE8F3FF,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(12),
                        ),
                        child: Text(
                          recommendation,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Color(0xFF344054),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width:
                            double.infinity,
                        height: 48,
                        child:
                            ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              dialogContext,
                            );

                            _clearPredictionForm();
                          },
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                _primaryColor,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child:
                              const Text(
                            'Selesai',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Gagal melakukan prediksi atau menyimpan data: $e',
      );

      if (mounted) {
        _showMessage(
          'Gagal menyimpan hasil prediksi: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPredicting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color: _primaryColor,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _buildPredictionForm(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 450,
        ),
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loadAcademicData,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        _primaryColor,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionForm() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 450,
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
              const Text(
                'Prediksi Kelulusan',
                style: TextStyle(
                  color: _darkColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Masukkan data akademik untuk mendapatkan prediksi.',
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      label: 'IPK',
                      controller:
                          _ipkController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      helperText:
                          'Rentang 0.00 – 4.00',
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      label: 'Total SKS',
                      controller:
                          _sksController,
                      keyboardType:
                          TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      label: 'Target SKS',
                      controller:
                          _targetSksController,
                      keyboardType:
                          TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    _buildSemesterField(),
                    const SizedBox(height: 18),
                    _buildField(
                      label:
                          'Persentase Kehadiran (%)',
                      controller:
                          _kehadiranController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      label:
                          'Mata Kuliah Belum Lulus',
                      controller:
                          _belumLulusController,
                      keyboardType:
                          TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      label:
                          'Mata Kuliah Mengulang',
                      controller:
                          _mengulangController,
                      keyboardType:
                          TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE8F3FF),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        const Color(0xFFD5E9FF),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: _primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Data yang kamu masukkan akan digunakan sebagai faktor dalam menghitung prediksi kelulusan.',
                        style:
                            const TextStyle(
                          color:
                              _primaryColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isPredicting ||
                          !_dataLoaded
                      ? null
                      : _showConfirmationDialog,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        _primaryColor,
                    disabledBackgroundColor:
                        _primaryColor.withOpacity(
                      0.55,
                    ),
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPredicting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Prediksi Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _darkColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: 1,
          style: const TextStyle(
            color: _darkColor,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor:
                const Color(0xFFF8F9FA),
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide:
                  const BorderSide(
                color: _primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              color: _secondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSemesterField() {
    final semesterNumber =
        int.tryParse(
              _semester.replaceAll(
                'Semester ',
                '',
              ),
            ) ??
            1;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Semester Saat Ini',
          style: TextStyle(
            color: _darkColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                const Color(0xFFF8F9FA),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          child:
              DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: semesterNumber.clamp(1, 14),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _darkColor,
                size: 22,
              ),
              style: const TextStyle(
                color: _darkColor,
                fontSize: 14,
              ),
              items: List.generate(
                14,
                (index) {
                  final semester =
                      index + 1;

                  return DropdownMenuItem<int>(
                    value: semester,
                    child: Text(
                      'Semester $semester',
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _semester =
                      'Semester $value';
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}