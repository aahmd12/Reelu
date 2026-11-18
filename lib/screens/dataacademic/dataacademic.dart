
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/dbsupabase.dart';

class DataAcademicScreen extends StatefulWidget {
  const DataAcademicScreen({super.key});

  @override
  State<DataAcademicScreen> createState() => _DataAcademicScreenState();
}

class _DataAcademicScreenState extends State<DataAcademicScreen>
    with WidgetsBindingObserver {
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

  bool _isLoading = true;

  RealtimeChannel? _realtimeChannel;
  Timer? _reloadDebounce;

  bool _isReloading = false;
  bool _reloadAgain = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadUserData().then((_) {
      if (mounted) {
        _setupRealtime();
      }
    });
  }

  void _setupRealtime() {
    final user = supabase.auth.currentUser;

    if (user == null || !mounted) return;

    if (_realtimeChannel != null) return;

    _realtimeChannel = supabase
        .channel('data-academic-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'academic_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint(
              'Realtime academic_records: ${payload.eventType}',
            );

            _scheduleReload();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint(
              'Realtime profiles: ${payload.eventType}',
            );

            _scheduleReload();
          },
        )
        .subscribe((status, error) {
          debugPrint('Realtime status: $status');

          if (error != null) {
            debugPrint('Realtime error: $error');
          }
        });
  }

  void _scheduleReload() {
    if (!mounted) return;

    _reloadDebounce?.cancel();

    _reloadDebounce = Timer(
      const Duration(milliseconds: 400),
      () {
        if (!mounted) return;

        if (_isReloading) {
          _reloadAgain = true;
          return;
        }

        _refreshData();
      },
    );
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    if (_isReloading) {
      _reloadAgain = true;
      return;
    }

    _isReloading = true;

    try {
      await _loadUserData();
    } finally {
      _isReloading = false;

      if (_reloadAgain && mounted) {
        _reloadAgain = false;
        _scheduleReload();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleReload();
    }
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

      String fullName = '-';
      String nim = '-';
      String prodi = '-';
      String univ = '-';

      String ipk = '-';
      String ips = '-';
      String totalSks = '-';
      String targetSks = '-';
      String semester = '-';
      String kehadiran = '-';

      final profileResponse = await supabase
          .from('profiles')
          .select(
            'id, email, full_name, nim, prodi, univ',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse != null) {
        final nameValue =
            profileResponse['full_name']?.toString().trim() ?? '';

        final nimValue =
            profileResponse['nim']?.toString().trim() ?? '';

        final prodiValue =
            profileResponse['prodi']?.toString().trim() ?? '';

        final univValue =
            profileResponse['univ']?.toString().trim() ?? '';

        if (nameValue.isNotEmpty) {
          fullName = nameValue;
        }

        if (nimValue.isNotEmpty) {
          nim = nimValue;
        }

        if (prodiValue.isNotEmpty) {
          prodi = prodiValue;
        }

        if (univValue.isNotEmpty) {
          univ = univValue;
        }
      }

      if (fullName == '-' &&
          user.email != null &&
          user.email!.isNotEmpty) {
        fullName = user.email!.split('@').first;
      }

      final academicResponse = await supabase
          .from('academic_records')
          .select(
            'id, user_id, semester, ips, ipk, total_sks, target_sks, kehadiran, created_at',
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
        final kehadiranValue = academicResponse['kehadiran'];

        if (ipkValue != null) {
          ipk = ipkValue.toString();
        }

        if (ipsValue != null) {
          ips = ipsValue.toString();
        }

        if (totalSksValue != null) {
          totalSks = totalSksValue.toString();
        }

        if (targetSksValue != null) {
          targetSks = targetSksValue.toString();
        }

        if (semesterValue != null) {
          semester = semesterValue.toString();
        }

        if (kehadiranValue != null &&
            kehadiranValue.toString().trim().isNotEmpty) {
          kehadiran = kehadiranValue.toString();
        }
      }

      if (!mounted) return;

      setState(() {
        _fullName = fullName;
        _nim = nim;
        _prodi = prodi;
        _univ = univ;

        _ipk = ipk;
        _ips = ips;
        _totalSks = totalSks;
        _targetSks = targetSks;
        _semester = semester;
        _kehadiran = kehadiran;

        _isLoading = false;
      });

      debugPrint('======================================');
      debugPrint('DATA AKADEMIK BERHASIL DIPERBARUI');
      debugPrint('Nama       : $_fullName');
      debugPrint('NIM        : $_nim');
      debugPrint('IPS        : $_ips');
      debugPrint('IPK        : $_ipk');
      debugPrint('Total SKS  : $_totalSks');
      debugPrint('Target SKS : $_targetSks');
      debugPrint('Semester   : $_semester');
      debugPrint('Kehadiran  : $_kehadiran');
      debugPrint('======================================');
    } catch (e, stackTrace) {
      debugPrint('GAGAL MEMUAT DATA AKADEMIK');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

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

    await _refreshData();
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _reloadDebounce?.cancel();

    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }

    super.dispose();
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
                    onRefresh: _refreshData,
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
                                    textColor: Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Universitas',
                                    _univ,
                                    textColor: Colors.black87,
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
                                    textColor: Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'IPS',
                                    _ips,
                                    textColor: Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Total SKS',
                                    _totalSks,
                                    textColor: Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Target SKS',
                                    _targetSks,
                                    textColor: Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Semester',
                                    _semester,
                                    textColor: Colors.black87,
                                  ),
                                  const Divider(
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  _buildInfoRow(
                                    'Kehadiran',
                                    _kehadiran,
                                    textColor: Colors.black87,
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
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
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
