import 'package:flutter/material.dart';
import '../../../core/constants/dbsupabase.dart';

class DataAcademicScreen extends StatefulWidget {
  const DataAcademicScreen({super.key});

  @override
  State<DataAcademicScreen> createState() => _DataAcademicScreenState();
}

class _DataAcademicScreenState extends State<DataAcademicScreen> {
  String _fullName = '-';
  String _nim = '-';
  String _prodi = '-';
  String _univ = '-';

  String _ipk = '-';
  String _ips = '-';
  String _totalSks = '-';
  String _targetSks = '-';
  String _semester = '-';
  String _kehadiran = '-';
  String _mkBelumLulus = '-';
  String _mkMengulang = '-';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      setState(() {
        _fullName = '-';
        _nim = '-';
        _prodi = '-';
        _univ = '-';

        _ipk = '-';
        _ips = '-';
        _totalSks = '-';
        _targetSks = '-';
        _semester = '-';
        _kehadiran = '-';
        _mkBelumLulus = '-';
        _mkMengulang = '-';
      });

      final profileResponse = await supabase
          .from('profiles')
          .select(
            'id, email, full_name, nim, prodi, univ',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse != null) {
        final fullName =
            profileResponse['full_name']?.toString().trim() ?? '';

        final nim =
            profileResponse['nim']?.toString().trim() ?? '';

        final prodi =
            profileResponse['prodi']?.toString().trim() ?? '';

        final univ =
            profileResponse['univ']?.toString().trim() ?? '';

        if (fullName.isNotEmpty) {
          _fullName = fullName;
        }

        if (nim.isNotEmpty) {
          _nim = nim;
        }

        if (prodi.isNotEmpty) {
          _prodi = prodi;
        }

        if (univ.isNotEmpty) {
          _univ = univ;
        }
      }

      if (_fullName == '-' &&
          user.email != null &&
          user.email!.isNotEmpty) {
        _fullName = user.email!.split('@').first;
      }

      final metadata = user.userMetadata;

      if (metadata != null) {
        final kehadiran =
            metadata['kehadiran']?.toString().trim() ?? '';

        final mkBelumLulus =
            metadata['mk_belum_lulus']?.toString().trim() ?? '';

        final mkMengulang =
            metadata['mk_mengulang']?.toString().trim() ?? '';

        if (kehadiran.isNotEmpty) {
          _kehadiran = kehadiran;
        }

        if (mkBelumLulus.isNotEmpty) {
          _mkBelumLulus = mkBelumLulus;
        }

        if (mkMengulang.isNotEmpty) {
          _mkMengulang = mkMengulang;
        }
      }

      final academicResponse = await supabase
          .from('academic_records')
          .select(
            'id, user_id, semester, ips, ipk, total_sks, target_sks, created_at',
          )
          .eq('user_id', user.id)
          .order('semester', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (academicResponse != null) {
        final ipsValue = academicResponse['ips'];
        final ipkValue = academicResponse['ipk'];
        final totalSksValue = academicResponse['total_sks'];
        final targetSksValue = academicResponse['target_sks'];
        final semesterValue = academicResponse['semester'];

        if (ipkValue != null) {
          _ipk = ipkValue.toString();
        }

        if (ipsValue != null) {
          _ips = ipsValue.toString();
        }

        if (totalSksValue != null) {
          _totalSks = totalSksValue.toString();
        }

        if (targetSksValue != null) {
          _targetSks = targetSksValue.toString();
        }

        if (semesterValue != null) {
          _semester = semesterValue.toString();
        }
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Gagal mengambil data. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  Future<void> _openEditData() async {
    await Navigator.pushNamed(
      context,
      '/data-academic-edit',
    );

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await _loadUserData();
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
              : const Color(0xFF2563EB),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 450,
                  ),
                  child: RefreshIndicator(
                    color: const Color(0xFF2563EB),
                    onRefresh: _loadUserData,
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
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 20.0,
                              top: 8.0,
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(8),
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chevron_left,
                                    color: Colors.black,
                                    size: 30,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Data Akademik',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Informasi Mahasiswa',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(
                                    'Nama',
                                    _fullName,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'NPM',
                                    _nim,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Program Studi',
                                    _prodi,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Universitas',
                                    _univ,
                                    textColor:
                                        Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Data Akademik',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(
                                    'IPK',
                                    _ipk,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'IPS',
                                    _ips,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Total SKS',
                                    _totalSks,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Target SKS',
                                    _targetSks,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Semester',
                                    _semester,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Kehadiran',
                                    _kehadiran,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Mata Kuliah Belum Lulus',
                                    _mkBelumLulus,
                                    textColor:
                                        Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Mata Kuliah Mengulang',
                                    _mkMengulang,
                                    textColor:
                                        Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _openEditData,
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF1867E5),
                                foregroundColor:
                                    Colors.white,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Edit Data',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    String title,
    String value, {
    Color textColor = Colors.black87,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}