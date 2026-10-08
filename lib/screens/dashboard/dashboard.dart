import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth.dart';
import '../prediction/prediction.dart';
import '../../services/history.dart';
import '../../services/viewdetails.dart';
import '../../core/constants/dbsupabase.dart';
import '../../services/statistik.dart';
import '../../services/target.dart';
import '../../services/rekomendasi.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();

  String _userName = 'Mahasiswa';
  String _initial = 'M';

  bool _isLoading = true;

  double? _ipk;
  double? _ips;
  int? _sks;
  int? _targetSks;
  int? _semester;
  double? _kehadiran;

  String? _statusPrediksi;
  DateTime? _tanggalPrediksi;
  double? _probabilitas;

  bool _hasPrediction = false;

  RealtimeChannel? _predictionChannel;
  Timer? _predictionTimer;

  String? _lastPredictionId;

  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _darkBlue = Color(0xFF102A63);
  static const Color _textColor = Color(0xFF182B4D);
  static const Color _backgroundColor = Color(0xFFF6FAFF);
  static const Color _borderColor = Color(0xFFDCEBFC);
  static const Color _softBorderColor = Color(0xFFE1EAF5);

  @override
  void initState() {
    super.initState();

    _loadDashboardData();
    _listenToPredictionChanges();
    _startPredictionChecker();
  }

  @override
  void dispose() {
    _predictionTimer?.cancel();

    if (_predictionChannel != null) {
      Supabase.instance.client.removeChannel(
        _predictionChannel!,
      );
    }

    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      String name = '';

      if (profileResponse != null) {
        name = (profileResponse['full_name'] ??
                profileResponse['name'] ??
                '')
            .toString()
            .trim();
      }

      if (name.isEmpty) {
        name = (user.userMetadata?['full_name'] ??
                user.userMetadata?['name'] ??
                '')
            .toString()
            .trim();
      }

      if (name.isEmpty) {
        final email = user.email ?? '';

        if (email.isNotEmpty) {
          name = email.split('@').first;
        }
      }

      if (name.isEmpty) {
        name = 'Mahasiswa';
      }

      final firstName = name.split(' ').first.trim();

      final academicResponse = await Supabase.instance.client
          .from('academic_records')
          .select()
          .eq('user_id', user.id)
          .order('semester', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      double? ipk;
      double? ips;
      int? sks;
      int? targetSks;
      int? semester;

      if (academicResponse != null) {
        final ipkValue = academicResponse['ipk'];
        final ipsValue = academicResponse['ips'];
        final sksValue = academicResponse['total_sks'];
        final targetSksValue = academicResponse['target_sks'];
        final semesterValue = academicResponse['semester'];

        if (ipkValue != null) {
          ipk = double.tryParse(
            ipkValue.toString(),
          );
        }

        if (ipsValue != null) {
          ips = double.tryParse(
            ipsValue.toString(),
          );
        }

        if (sksValue != null) {
          sks = int.tryParse(
            sksValue.toString(),
          );
        }

        if (targetSksValue != null) {
          targetSks = int.tryParse(
            targetSksValue.toString(),
          );
        }

        if (semesterValue != null) {
          semester = int.tryParse(
            semesterValue.toString(),
          );
        }
      }

      double? kehadiran;

      final metadata = user.userMetadata ?? {};
      final metadataKehadiran = metadata['kehadiran'];

      if (metadataKehadiran != null) {
        kehadiran = double.tryParse(
          metadataKehadiran.toString(),
        );
      }

      if (mounted) {
        setState(() {
          _userName = firstName.isEmpty
              ? 'Mahasiswa'
              : firstName;

          _initial = _userName
              .substring(0, 1)
              .toUpperCase();

          _ipk = ipk;
          _ips = ips;
          _sks = sks;
          _targetSks = targetSks;
          _semester = semester;
          _kehadiran = kehadiran;
          _isLoading = false;
        });
      }

      await _loadLatestPrediction();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLatestPrediction() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        return;
      }

      final response = await Supabase.instance.client
          .from('predictions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hasPrediction = false;
          _statusPrediksi = null;
          _tanggalPrediksi = null;
          _probabilitas = null;
          _lastPredictionId = null;
        });

        return;
      }

      final predictionId = response['id']?.toString();
      final status = response['status_lulus']?.toString();
      final createdAt = response['created_at']?.toString();
      final probabilityValue = response['probabilitas'];

      double? probability;

      if (probabilityValue != null) {
        probability = double.tryParse(
          probabilityValue.toString(),
        );
      }

      DateTime? createdDate;

      if (createdAt != null) {
        createdDate = DateTime.tryParse(
          createdAt,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPrediction = true;
        _statusPrediksi = status;
        _tanggalPrediksi = createdDate;
        _probabilitas = probability;
        _lastPredictionId = predictionId;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasPrediction = false;
      });
    }
  }

  Future<void> _checkPredictionChanges() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        return;
      }

      final response = await Supabase.instance.client
          .from('predictions')
          .select('id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final predictionId = response?['id']?.toString();

      if (predictionId != null &&
          predictionId != _lastPredictionId) {
        await _loadLatestPrediction();
      }
    } catch (e) {
      return;
    }
  }

  void _listenToPredictionChanges() {
    final user = _authService.currentUser;

    if (user == null) {
      return;
    }

    _predictionChannel = Supabase.instance.client
        .channel(
          'dashboard-predictions-${user.id}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'predictions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            _loadLatestPrediction();
          },
        )
        .subscribe();
  }

  void _startPredictionChecker() {
    _predictionTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        _checkPredictionChanges();
      },
    );
  }

  Future<void> _refreshPredictionAfterNavigation() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    await _loadLatestPrediction();
  }

  String _formatNumber(
    double? value, {
    int decimal = 2,
  }) {
    if (value == null) {
      return '-';
    }

    return value.toStringAsFixed(decimal);
  }

  String _formatPredictionPercentage(
    double? value,
  ) {
    if (value == null) {
      return '-';
    }

    double percentage = value;

    if (percentage <= 1) {
      percentage *= 100;
    }

    return '${percentage.toStringAsFixed(1)}%';
  }

  String _formatPredictionDate(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
    }

    final localDate = date.toLocal();

    final day = localDate.day
        .toString()
        .padLeft(2, '0');

    final month = localDate.month
        .toString()
        .padLeft(2, '0');

    final year = localDate.year.toString();

    final hour = localDate.hour
        .toString()
        .padLeft(2, '0');

    final minute = localDate.minute
        .toString()
        .padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  double _getProgressPercentage() {
    if (_sks == null ||
        _targetSks == null ||
        _targetSks == 0) {
      return 0;
    }

    final percentage = _sks! / _targetSks!;

    if (percentage < 0) {
      return 0;
    }

    if (percentage > 1) {
      return 1;
    }

    return percentage;
  }

  int? _getRemainingSks() {
    if (_sks == null ||
        _targetSks == null) {
      return null;
    }

    final remaining = _targetSks! - _sks!;

    return remaining < 0
        ? 0
        : remaining;
  }

  bool _hasAcademicData() {
    return _ipk != null ||
        _ips != null ||
        _sks != null ||
        _targetSks != null ||
        _semester != null ||
        _kehadiran != null;
  }

  Future<void> _openPrediction() async {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);

      await _refreshPredictionAfterNavigation();

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const PredictionScreen(),
      ),
    );

    await _loadLatestPrediction();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const HistoryScreen(),
      ),
    );

    await _loadLatestPrediction();
  }

  Future<void> _openStatistics() async {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const StatistikScreen(),
      ),
    );

    await _loadDashboardData();
  }

  Future<void> _openTarget() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const TargetScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardData();
  }

  Future<void> _openRecommendation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const RekomendasiScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme =
        Theme.of(context).textTheme;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(
          baseTextTheme,
        ),
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _primaryColor,
                ),
              )
            : SafeArea(
                child: RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: _loadDashboardData,
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 430,
                      ),
                      child: SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(
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
                            const SizedBox(height: 20),
                            _buildAcademicSummary(),
                            const SizedBox(height: 20),
                            _buildLatestPrediction(),
                            const SizedBox(height: 24),
                            const Text(
                              'Aksi Cepat',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.w700,
                                color: _darkBlue,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildQuickActions(),
                            const SizedBox(height: 24),
                            _buildAcademicProgress(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Selamat datang,',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6D8ABD),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: _darkBlue,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    _primaryColor.withOpacity(0.20),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicSummary() {
    final hasData = _hasAcademicData();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF8AA9D6).withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ringkasan Akademik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _darkBlue,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasData
                      ? const Color(0xFFEAF8EF)
                      : const Color(0xFFFFF4E5),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  hasData
                      ? 'Data Tersedia'
                      : 'Belum Ada Data',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasData
                        ? const Color(0xFF218838)
                        : const Color(0xFFC57A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.school_outlined,
                  label: 'IPK',
                  value: _formatNumber(_ipk),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.auto_graph_outlined,
                  label: 'IPS',
                  value: _formatNumber(_ips),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.credit_score_outlined,
                  label: 'Total SKS',
                  value: _sks?.toString() ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.menu_book_outlined,
                  label: 'Semester',
                  value:
                      _semester?.toString() ?? '-',
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Target SKS',
                  value:
                      _targetSks?.toString() ?? '-',
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon:
                      Icons.event_available_outlined,
                  label: 'Kehadiran',
                  value: _kehadiran == null
                      ? '-'
                      : '${_formatNumber(_kehadiran, decimal: 0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius:
                BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: _primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6D8ABD),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _darkBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildLatestPrediction() {
    if (!_hasPrediction) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediksi Kelulusan Terakhir',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _darkBlue,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belum ada hasil prediksi.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6D8ABD),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _openPrediction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Buat Prediksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool isLulus =
        (_statusPrediksi ?? '')
            .toLowerCase()
            .contains('lulus');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF8AA9D6).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Prediksi Kelulusan Terakhir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _darkBlue,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isLulus
                      ? const Color(0xFFEAF8EF)
                      : const Color(0xFFFFF4E5),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  _statusPrediksi ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isLulus
                        ? const Color(0xFF218838)
                        : const Color(0xFFC57A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isLulus
                      ? const Color(0xFFEAF8EF)
                      : const Color(0xFFFFF4E5),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isLulus
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: isLulus
                      ? Colors.green
                      : const Color(0xFFC57A00),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPredictionPercentage(
                        _probabilitas,
                      ),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: _darkBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tanggalPrediksi == null
                          ? '-'
                          : _formatPredictionDate(
                              _tanggalPrediksi,
                            ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6D8ABD),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ViewDetailsScreen(),
                  ),
                );

                await _loadLatestPrediction();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(
                  color: _primaryColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Lihat Detail',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildQuickActionItem(
          icon: Icons.trending_up_rounded,
          title: 'Prediksi Sekarang',
          onTap: _openPrediction,
        ),
        _buildQuickActionItem(
          icon: Icons.history_rounded,
          title: 'Riwayat Prediksi',
          onTap: _openHistory,
        ),
        _buildQuickActionItem(
          icon: Icons.school_outlined,
          title: 'Data Akademik',
          onTap: () async {
            await Navigator.pushNamed(
              context,
              '/data-academic',
            );

            await _loadDashboardData();
          },
        ),
        _buildQuickActionItem(
          icon: Icons.bar_chart_rounded,
          title: 'Statistik Akademik',
          onTap: _openStatistics,
        ),
        _buildQuickActionItem(
          icon: Icons.track_changes_rounded,
          title: 'Target Kelulusan',
          onTap: _openTarget,
        ),
        _buildQuickActionItem(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Rekomendasi Akademik',
          onTap: _openRecommendation,
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: _softBorderColor,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: _primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicProgress() {
    final progressPercentage =
        _getProgressPercentage();

    final remainingSks =
        _getRemainingSks();

    final progressValue =
        (progressPercentage * 100)
            .toStringAsFixed(0);

    final sksDisplay =
        '${_sks ?? '-'} | ${_targetSks ?? '-'} SKS';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _softBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Progres Akademik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _darkBlue,
                  ),
                ),
              ),
              Text(
                _hasAcademicData()
                    ? '$progressValue%'
                    : '-',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sksDisplay,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6D8ABD),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressPercentage,
              minHeight: 8,
              backgroundColor:
                  const Color(0xFFEAF0F6),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                _primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  remainingSks != null &&
                          remainingSks <= 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: remainingSks != null &&
                          remainingSks <= 0
                      ? Colors.green
                      : const Color(0xFF6D8ABD),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !_hasAcademicData()
                        ? 'Belum ada data untuk ditampilkan.'
                        : remainingSks != null &&
                                remainingSks > 0
                            ? '$remainingSks SKS tersisa untuk menyelesaikan studi.'
                            : 'Target SKS untuk menyelesaikan studi sudah tercapai.',
                    style: TextStyle(
                      color: remainingSks != null &&
                              remainingSks <= 0 &&
                              _hasAcademicData()
                          ? Colors.green.shade700
                          : const Color(0xFF6D8ABD),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  '/data-academic',
                );

                await _loadDashboardData();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(
                  color: _primaryColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Lihat Data Akademik',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}