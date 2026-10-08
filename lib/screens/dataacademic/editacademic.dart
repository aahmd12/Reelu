import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/dbsupabase.dart';
import '../../models/academicrecord.dart';
import '../../services/academic.dart';
import '../../services/auth.dart';

class EditAcademicScreen extends StatefulWidget {
  const EditAcademicScreen({super.key});

  @override
  State<EditAcademicScreen> createState() => _EditAcademicScreenState();
}

class _EditAcademicScreenState extends State<EditAcademicScreen> {
  final _prodiController = TextEditingController();
  final _univController = TextEditingController();
  final _ipsController = TextEditingController();
  final _ipkController = TextEditingController();
  final _sksController = TextEditingController();
  final _targetSksController = TextEditingController();
  final _semesterController = TextEditingController();
  final _kehadiranController = TextEditingController();
  final _belumLulusController = TextEditingController();
  final _mengulangController = TextEditingController();

  AcademicRecord? _existingRecord;

  bool _isInit = false;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInit) {
      _isInit = true;
      _loadExistingData();
    }
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadExistingData() async {
    if (mounted) {
      setState(() {
        _isLoadingData = true;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Pengguna belum login.');
      }

      final metadata = user.userMetadata;

      String ipkMetadata = '';
      String sksMetadata = '';
      String targetSksMetadata = '';
      String semesterMetadata = '';
      String kehadiran = '';
      String belumLulus = '';
      String mengulang = '';

      if (metadata != null) {
        ipkMetadata = metadata['ipk']?.toString() ?? '';

        sksMetadata =
            metadata['total_sks']?.toString() ?? '';

        targetSksMetadata =
            metadata['target_sks']?.toString() ?? '';

        semesterMetadata =
            metadata['semester']?.toString() ?? '';

        kehadiran =
            metadata['kehadiran']?.toString() ?? '';

        belumLulus =
            metadata['mk_belum_lulus']?.toString() ?? '';

        mengulang =
            metadata['mk_mengulang']?.toString() ?? '';
      }

      // ========================================================
      // AMBIL PRODI & UNIVERSITAS DARI TABLE PROFILES
      // ========================================================

      String prodi = '';
      String univ = '';

      final profileResponse = await supabase
          .from('profiles')
          .select('prodi, univ')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse != null) {
        prodi =
            profileResponse['prodi']?.toString() ?? '';

        univ =
            profileResponse['univ']?.toString() ?? '';

        debugPrint(
          '======================================',
        );
        debugPrint(
          'DATA PROFILE UNTUK EDIT',
        );
        debugPrint(
          'User ID : ${user.id}',
        );
        debugPrint(
          'Prodi   : $prodi',
        );
        debugPrint(
          'Univ    : $univ',
        );
        debugPrint(
          '======================================',
        );
      } else {
        debugPrint(
          'Belum ada data profile untuk user ini.',
        );

        if (metadata != null) {
          prodi =
              metadata['prodi']?.toString() ?? '';

          univ =
              metadata['univ']?.toString() ?? '';
        }
      }

      // ========================================================
      // AMBIL DATA AKADEMIK TERAKHIR
      // ========================================================

      final response = await supabase
          .from('academic_records')
          .select(
            'id, user_id, semester, ips, ipk, total_sks, target_sks, created_at',
          )
          .eq('user_id', user.id)
          .order('semester', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      AcademicRecord? record;

      if (response != null) {
        record = AcademicRecord.fromJson(response);

        debugPrint(
          '======================================',
        );
        debugPrint(
          'DATA AKADEMIK UNTUK EDIT',
        );
        debugPrint(
          'ID         : ${record.id}',
        );
        debugPrint(
          'Semester   : ${record.semester}',
        );
        debugPrint(
          'IPS        : ${record.ips}',
        );
        debugPrint(
          'IPK        : ${record.ipk}',
        );
        debugPrint(
          'Total SKS  : ${record.totalSks}',
        );
        debugPrint(
          'Target SKS : ${record.targetSks}',
        );
        debugPrint(
          '======================================',
        );
      } else {
        debugPrint(
          'Belum ada data academic_records.',
        );
      }

      // ========================================================
      // MASUKKAN DATA KE CONTROLLER
      // ========================================================

      if (record != null) {
        _existingRecord = record;

        _prodiController.text = prodi;
        _univController.text = univ;

        _ipsController.text =
            _formatNumber(record.ips);

        _ipkController.text =
            _formatNumber(record.ipk);

        _sksController.text =
            record.totalSks.toString();

        _targetSksController.text =
            record.targetSks.toString();

        _semesterController.text =
            record.semester.toString();

        _kehadiranController.text =
            kehadiran;

        _belumLulusController.text =
            belumLulus;

        _mengulangController.text =
            mengulang;
      } else {
        _prodiController.text = prodi;
        _univController.text = univ;

        _ipsController.text = '';

        _ipkController.text =
            ipkMetadata;

        _sksController.text =
            sksMetadata;

        _targetSksController.text =
            targetSksMetadata;

        _semesterController.text =
            semesterMetadata;

        _kehadiranController.text =
            kehadiran;

        _belumLulusController.text =
            belumLulus;

        _mengulangController.text =
            mengulang;
      }

      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint(
        '======================================',
      );
      debugPrint(
        'ERROR LOAD DATA AKADEMIK',
      );
      debugPrint('$e');
      debugPrint(
        '======================================',
      );

      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengambil data: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // FORMAT ANGKA
  // ============================================================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _prodiController.dispose();
    _univController.dispose();
    _ipsController.dispose();
    _ipkController.dispose();
    _sksController.dispose();
    _targetSksController.dispose();
    _semesterController.dispose();
    _kehadiranController.dispose();
    _belumLulusController.dispose();
    _mengulangController.dispose();

    super.dispose();
  }

  // ============================================================
  // PARSE DOUBLE
  // ============================================================

  double? _parseDouble(String value) {
    final cleanedValue =
        value.trim().replaceAll(',', '.');

    if (cleanedValue.isEmpty) {
      return null;
    }

    return double.tryParse(cleanedValue);
  }

  // ============================================================
  // SAVE DATA
  // ============================================================

  Future<void> _save() async {
    final ips = _parseDouble(
      _ipsController.text,
    );

    final ipk = _parseDouble(
      _ipkController.text,
    );

    // ========================================================
    // VALIDASI IPS
    // ========================================================

    if (ips == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'IPS harus diisi dengan angka yang valid.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (ips < 0 || ips > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'IPS harus berada di antara 0 sampai 4.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ========================================================
    // VALIDASI IPK
    // ========================================================

    if (ipk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'IPK harus diisi dengan angka yang valid.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (ipk < 0 || ipk > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'IPK harus berada di antara 0 sampai 4.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ========================================================
    // VALIDASI PRODI
    // ========================================================

    final prodi =
        _prodiController.text.trim();

    if (prodi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Program Studi harus diisi.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ========================================================
    // VALIDASI UNIVERSITAS
    // ========================================================

    final univ =
        _univController.text.trim();

    if (univ.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Universitas harus diisi.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ========================================================
    // VALIDASI SEMESTER
    // ========================================================

    final semester =
        int.tryParse(
      _semesterController.text.trim(),
    );

    if (semester == null ||
        semester < 1 ||
        semester > 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Semester harus dipilih antara Semester 1 sampai Semester 14.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // ======================================================
      // AMBIL USER LOGIN
      // ======================================================

      final currentUser =
          AuthService().currentUser;

      if (currentUser == null) {
        throw Exception(
          'Pengguna belum login.',
        );
      }

      final userId =
          currentUser.id;

      final userEmail =
          currentUser.email;

      debugPrint(
        '======================================',
      );
      debugPrint(
        'MENYIMPAN DATA PROFILE',
      );
      debugPrint(
        'User ID : $userId',
      );
      debugPrint(
        'Email   : $userEmail',
      );
      debugPrint(
        'Prodi   : $prodi',
      );
      debugPrint(
        'Univ    : $univ',
      );
      debugPrint(
        'Semester: $semester',
      );
      debugPrint(
        '======================================',
      );

      // ======================================================
      // SIMPAN PRODI & UNIVERSITAS KE TABLE PROFILES
      // ======================================================

      final profileData = await supabase
          .from('profiles')
          .upsert({
            'id': userId,
            'email': userEmail,
            'prodi': prodi,
            'univ': univ,
          })
          .select(
            'id, email, prodi, univ',
          )
          .single();

      debugPrint(
        '======================================',
      );
      debugPrint(
        'PROFILE BERHASIL DISIMPAN',
      );
      debugPrint(
        'ID    : ${profileData['id']}',
      );
      debugPrint(
        'Email : ${profileData['email']}',
      );
      debugPrint(
        'Prodi : ${profileData['prodi']}',
      );
      debugPrint(
        'Univ  : ${profileData['univ']}',
      );
      debugPrint(
        '======================================',
      );

      // ======================================================
      // BUAT OBJECT DATA AKADEMIK
      // ======================================================

      final record = AcademicRecord(
        id: _existingRecord?.id,
        userId: userId,
        semester: semester,
        ips: ips,
        ipk: ipk,
        totalSks: int.tryParse(
              _sksController.text.trim(),
            ) ??
            0,
        targetSks: int.tryParse(
              _targetSksController.text.trim(),
            ) ??
            0,
      );

      // ======================================================
      // DEBUG DATA AKADEMIK
      // ======================================================

      debugPrint(
        '======================================',
      );
      debugPrint(
        'DATA AKADEMIK YANG AKAN DISIMPAN',
      );
      debugPrint(
        'User ID    : ${record.userId}',
      );
      debugPrint(
        'ID         : ${record.id}',
      );
      debugPrint(
        'Semester   : ${record.semester}',
      );
      debugPrint(
        'IPS        : ${record.ips}',
      );
      debugPrint(
        'IPK        : ${record.ipk}',
      );
      debugPrint(
        'Total SKS  : ${record.totalSks}',
      );
      debugPrint(
        'Target SKS : ${record.targetSks}',
      );
      debugPrint(
        '======================================',
      );

      // ======================================================
      // SIMPAN DATA AKADEMIK
      // ======================================================

      await AcademicService()
          .saveAcademicRecord(record);

      // ======================================================
      // SIMPAN JUGA KE AUTH METADATA
      // ======================================================

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'prodi': prodi,
            'univ': univ,
            'ipk': ipk.toString(),
            'total_sks':
                _sksController.text.trim(),
            'target_sks':
                _targetSksController.text.trim(),
            'semester':
                semester.toString(),
            'kehadiran':
                _kehadiranController.text.trim(),
            'mk_belum_lulus':
                _belumLulusController.text.trim(),
            'mk_mengulang':
                _mengulangController.text.trim(),
          },
        ),
      );

      // ======================================================
      // BERHASIL
      // ======================================================

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data akademik berhasil disimpan!',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(
          const Duration(
            milliseconds: 1500,
          ),
        );

        if (mounted) {
          Navigator.pop(
            context,
            true,
          );
        }
      }
    } catch (e) {
      debugPrint(
        '======================================',
      );
      debugPrint(
        'ERROR MENYIMPAN DATA AKADEMIK',
      );
      debugPrint('$e');
      debugPrint(
        '======================================',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan data: $e',
            ),
            backgroundColor: Colors.red,
          ),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 3,
                        color:
                            Color(0xFF1867E5),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Memuat data...',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 450,
                  ),
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // ==================================================
                        // HEADER
                        // ==================================================

                        Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom: 20.0,
                            top: 8.0,
                          ),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                            onTap: () =>
                                Navigator.pop(
                              context,
                            ),
                            child: const Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_left,
                                  color:
                                      Colors.black,
                                  size: 30,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  'Edit Data Mahasiswa',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.black,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize:
                                        20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ==================================================
                        // INFORMASI MAHASISWA
                        // ==================================================

                        Card(
                          elevation: 0,
                          color:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                            side: BorderSide(
                              color: Colors
                                  .grey
                                  .shade200,
                            ),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              16.0,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'Informasi Mahasiswa',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color: Colors
                                        .black87,
                                  ),
                                ),

                                const SizedBox(
                                  height: 16,
                                ),

                                _buildTextField(
                                  'Program Studi',
                                  _prodiController,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                _buildTextField(
                                  'Universitas',
                                  _univController,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // ==================================================
                        // DATA AKADEMIK
                        // ==================================================

                        Card(
                          elevation: 0,
                          color:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                            side: BorderSide(
                              color: Colors
                                  .grey
                                  .shade200,
                            ),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              16.0,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'Data Akademik',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color: Colors
                                        .black87,
                                  ),
                                ),

                                const SizedBox(
                                  height: 16,
                                ),

                                // IPS
                                _buildTextField(
                                  'IPS',
                                  _ipsController,
                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                    decimal:
                                        true,
                                  ),
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // IPK
                                _buildTextField(
                                  'IPK',
                                  _ipkController,
                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                    decimal:
                                        true,
                                  ),
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // TOTAL SKS
                                _buildTextField(
                                  'Total SKS',
                                  _sksController,
                                  keyboardType:
                                      TextInputType
                                          .number,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // TARGET SKS
                                _buildTextField(
                                  'Target SKS',
                                  _targetSksController,
                                  keyboardType:
                                      TextInputType
                                          .number,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // SEMESTER
                                _buildSemesterDropdown(),

                                const SizedBox(
                                  height: 12,
                                ),

                                // KEHADIRAN
                                _buildTextField(
                                  'Kehadiran',
                                  _kehadiranController,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // MATA KULIAH BELUM LULUS
                                _buildTextField(
                                  'Mata Kuliah Belum Lulus',
                                  _belumLulusController,
                                  keyboardType:
                                      TextInputType
                                          .number,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // MATA KULIAH MENGULANG
                                _buildTextField(
                                  'Mata Kuliah Mengulang',
                                  _mengulangController,
                                  keyboardType:
                                      TextInputType
                                          .number,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        // ==================================================
                        // TOMBOL SIMPAN
                        // ==================================================

                        SizedBox(
                          width:
                              double.infinity,
                          height: 48,
                          child:
                              ElevatedButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : _save,
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF1867E5,
                              ),
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
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors
                                          .white,
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Text(
                                    'Simpan',
                                    style:
                                        TextStyle(
                                      color: Colors
                                          .white,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // ==================================================
                        // TOMBOL BATAL
                        // ==================================================

                        SizedBox(
                          width:
                              double.infinity,
                          height: 48,
                          child:
                              OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(
                              context,
                            ),
                            style:
                                OutlinedButton
                                    .styleFrom(
                              backgroundColor:
                                  Colors.white,
                              side: BorderSide(
                                color: Colors
                                    .grey
                                    .shade300,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Batal',
                              style:
                                  TextStyle(
                                color: Colors
                                    .black87,
                                fontSize: 15,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // SEMESTER DROPDOWN
  // ============================================================

  Widget _buildSemesterDropdown() {
    final currentSemester =
        int.tryParse(
      _semesterController.text.trim(),
    );

    final selectedSemester =
        currentSemester != null &&
                currentSemester >= 1 &&
                currentSemester <= 14
            ? currentSemester
            : null;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Semester',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        DropdownButtonFormField<int>(
          value: selectedSemester,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide:
                  const BorderSide(
                color: Color(0xFF1867E5),
              ),
            ),
          ),
          hint: const Text(
            'Pilih semester',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          items: List.generate(
            14,
            (index) {
              final semester = index + 1;

              return DropdownMenuItem<int>(
                value: semester,
                child: Text(
                  'Semester $semester',
                ),
              );
            },
          ),
          onChanged: _isLoading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _semesterController.text =
                          value.toString();
                    });
                  }
                },
        ),
      ],
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
                Colors.grey.shade700,
            fontSize: 13,
            fontWeight:
                FontWeight.w500,
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        TextField(
          controller: controller,
          keyboardType:
              keyboardType,
          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.bold,
          ),
          decoration:
              InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  BorderSide(
                color: Colors
                    .grey.shade300,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  BorderSide(
                color: Colors
                    .grey.shade300,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFF1867E5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}