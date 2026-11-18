
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TargetScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TargetScreen({
    super.key,
    this.onBack,
  });

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _academicChannel;

  static const Color navy = Color(0xFF102A63);
  static const Color blue = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FB);
  static const Color green = Color(0xFF16A34A);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFDC2626);

  static const int _targetGraduationSemester = 8;

  bool _isLoading = true;
  String? _errorMessage;

  int _semester = 0;
  int _targetSks = 144;
  int _totalSks = 0;

  double _ipk = 0;
  double _ips = 0;
  double _kehadiran = 0;

  int _totalSemesterKehadiran = 0;

  int get _remainingSks {
    final remaining = _targetSks - _totalSks;
    return remaining > 0 ? remaining : 0;
  }

  double get _progress {
    if (_targetSks <= 0) return 0;
    return (_totalSks / _targetSks).clamp(0.0, 1.0);
  }

  double get _averageSksPerSemester {
    if (_semester <= 0 || _totalSks <= 0) return 0;
    return _totalSks / _semester;
  }

  int? get _estimatedRemainingSemesters {
    if (_remainingSks == 0 && _targetSks > 0) return 0;
    if (_averageSksPerSemester <= 0) return null;

    return (_remainingSks / _averageSksPerSemester).ceil();
  }

  int? get _estimatedGraduationSemester {
    final remaining = _estimatedRemainingSemesters;

    if (remaining == null || _semester <= 0) return null;

    return _semester + remaining;
  }

  String get _graduationEstimateLabel {
    final remaining = _estimatedRemainingSemesters;

    if (_targetSks <= 0) return 'Belum Tersedia';
    if (remaining == null) return 'Belum Tersedia';
    if (remaining == 0) return 'Target Tercapai';

    return '±$remaining semester';
  }

  String get _graduationStatus {
    if (_targetSks <= 0 || _semester <= 0) {
      return 'Belum Tersedia';
    }

    if (_remainingSks == 0) {
      return 'Target Tercapai';
    }

    final estimatedSemester = _estimatedGraduationSemester;

    if (estimatedSemester == null) {
      return 'Belum Tersedia';
    }

    if (estimatedSemester <= _targetGraduationSemester) {
      return 'Sesuai Rencana';
    }

    return 'Melebihi Target';
  }

  Color get _graduationStatusColor {
    switch (_graduationStatus) {
      case 'Sesuai Rencana':
      case 'Target Tercapai':
        return green;
      case 'Melebihi Target':
        return red;
      default:
        return orange;
    }
  }

  Color get _graduationStatusBackground {
    switch (_graduationStatus) {
      case 'Sesuai Rencana':
      case 'Target Tercapai':
        return const Color(0xFFECFDF5);
      case 'Melebihi Target':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFFFF7ED);
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _normalizeAttendance(dynamic value) {
    double attendance = _toDouble(value);

    if (attendance > 0 && attendance <= 1) {
      attendance *= 100;
    }

    return attendance.clamp(0.0, 100.0);
  }

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
    _setupRealtime();
  }

  // Memasang listener Realtime untuk perubahan data akademik.
  Future<void> _setupRealtime() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    _academicChannel = _supabase
        .channel('target_academic_records_${user.id}')
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
            // Ambil ulang data tanpa menampilkan loading penuh.
            _loadAcademicData(showLoading: false);
          },
        )
        .subscribe();
  }

  // Mengambil data akademik terbaru dari Supabase.
  Future<void> _loadAcademicData({
    bool showLoading = true,
  }) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Silakan login terlebih dahulu.');
      }

      final response = await _supabase
          .from('academic_records')
          .select(
            'semester, ips, ipk, total_sks, target_sks, '
            'kehadiran, created_at',
          )
          .eq('user_id', user.id)
          .order('semester', ascending: false)
          .order('created_at', ascending: false);

      if (!mounted) return;

      if (response.isEmpty) {
        setState(() {
          _semester = 0;
          _targetSks = 144;
          _totalSks = 0;
          _ipk = 0;
          _ips = 0;
          _kehadiran = 0;
          _totalSemesterKehadiran = 0;
          _errorMessage = null;
          _isLoading = false;
        });

        return;
      }

      final latestRecord = response.first;

      // Ambil satu data kehadiran terbaru untuk setiap semester.
      final Map<int, double> attendanceBySemester = {};

      for (final record in response) {
        final semester = _toInt(record['semester'], 0);

        if (semester <= 0) continue;

        if (!attendanceBySemester.containsKey(semester)) {
          attendanceBySemester[semester] =
              _normalizeAttendance(record['kehadiran']);
        }
      }

      // Menghitung rata-rata kehadiran seluruh semester.
      double totalAttendance = 0;

      for (final attendance in attendanceBySemester.values) {
        totalAttendance += attendance;
      }

      double averageAttendance = 0;

      if (attendanceBySemester.isNotEmpty) {
        averageAttendance =
            totalAttendance / attendanceBySemester.length;
      }

      setState(() {
        _semester = _toInt(latestRecord['semester'], 0);
        _targetSks = _toInt(latestRecord['target_sks'], 144);
        _totalSks = _toInt(latestRecord['total_sks'], 0);
        _ipk = _toDouble(latestRecord['ipk']);
        _ips = _toDouble(latestRecord['ips']);

        _kehadiran = averageAttendance;
        _totalSemesterKehadiran = attendanceBySemester.length;

        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Gagal mengambil data akademik: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_academicChannel != null) {
      _supabase.removeChannel(_academicChannel!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: navy),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    color: navy,
                    onRefresh: _loadAcademicData,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildProgressCard(),
                            const SizedBox(height: 24),
                            _buildSectionTitle(
                              'Ringkasan SKS',
                              'Informasi perkembangan SKS kamu',
                            ),
                            const SizedBox(height: 14),
                            _buildSksSummary(),
                            const SizedBox(height: 24),
                            _buildGraduationStatus(),
                            const SizedBox(height: 24),
                            _buildSectionTitle(
                              'Ringkasan Akademik',
                              'Ringkasan data akademik terbaru',
                            ),
                            const SizedBox(height: 14),
                            _buildAcademicInformation(),
                            const SizedBox(height: 16),
                            _buildAdditionalInformation(),
                            const SizedBox(height: 24),
                            _buildGraduationEstimate(),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: red,
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadAcademicData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Kelulusan',
          style: TextStyle(
            color: navy,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Pantau progres akademik kamu',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final percentage = (_progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF102A63),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                'Progres Kelulusan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Semester $_semester',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF86EFAC),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            '$_totalSks dari $_targetSks SKS telah diselesaikan',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
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
          style: const TextStyle(
            color: navy,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSksSummary() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 142,
      ),
      children: [
        _buildSksCard(
          title: 'Total SKS',
          value: '$_totalSks',
          description: 'SKS ditempuh',
          icon: Icons.menu_book_rounded,
          color: blue,
          backgroundColor: const Color(0xFFEFF6FF),
        ),
        _buildSksCard(
          title: 'Target SKS',
          value: '$_targetSks',
          description: 'SKS kelulusan',
          icon: Icons.flag_rounded,
          color: green,
          backgroundColor: const Color(0xFFECFDF5),
        ),
        _buildSksCard(
          title: 'Sisa SKS',
          value: '$_remainingSks',
          description: 'SKS yang harus ditempuh',
          icon: Icons.hourglass_bottom_rounded,
          color: orange,
          backgroundColor: const Color(0xFFFFF7ED),
        ),
        _buildSksCard(
          title: 'Semester',
          value: '$_semester',
          description: 'Semester berjalan',
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF8B5CF6),
          backgroundColor: const Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  Widget _buildSksCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEFF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 19,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: navy,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraduationStatus() {
    final bool completed = _remainingSks == 0 && _targetSks > 0;

    final Color statusColor = completed ? green : blue;
    final Color statusBackground =
        completed ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEFF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              completed
                  ? Icons.verified_rounded
                  : Icons.trending_up_rounded,
              color: statusColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Kelulusan',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  completed ? 'Target SKS Tercapai' : 'Dalam Proses',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  completed
                      ? 'Kamu telah mencapai target SKS.'
                      : 'Tetap semangat menyelesaikan sisa SKS.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInformation() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEFF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAcademicRow(
            icon: Icons.workspace_premium_rounded,
            title: 'Indeks Prestasi Kumulatif',
            subtitle: 'IPK',
            value: _ipk.toStringAsFixed(2),
            color: const Color(0xFF8B5CF6),
          ),
          const Divider(height: 25),
          _buildAcademicRow(
            icon: Icons.auto_graph_rounded,
            title: 'Indeks Prestasi Semester',
            subtitle: 'IPS',
            value: _ips.toStringAsFixed(2),
            color: blue,
          ),
          const Divider(height: 25),
          _buildAcademicRow(
            icon: Icons.fact_check_rounded,
            title: 'Tingkat Kehadiran',
            subtitle: _totalSemesterKehadiran > 0
                ? 'Kumulatif $_totalSemesterKehadiran semester'
                : 'Belum ada data kehadiran',
            value: '${_kehadiran.toStringAsFixed(1)}%',
            color: green,
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: navy,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInformation() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEFF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: navy,
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                'Informasi Tambahan',
                style: TextStyle(
                  color: navy,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAdditionalItem(
                  title: 'Estimasi Lulus',
                  value: _graduationEstimateLabel,
                  icon: Icons.school_rounded,
                  color: blue,
                  backgroundColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdditionalItem(
                  title: 'Status',
                  value: _graduationStatus,
                  icon: _graduationStatus == 'Sesuai Rencana' ||
                          _graduationStatus == 'Target Tercapai'
                      ? Icons.check_circle_rounded
                      : _graduationStatus == 'Melebihi Target'
                          ? Icons.warning_rounded
                          : Icons.info_outline_rounded,
                  color: _graduationStatusColor,
                  backgroundColor: _graduationStatusBackground,
                ),
              ),
            ],
          ),
          if (_estimatedGraduationSemester != null &&
              _remainingSks > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.black54,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perkiraan kelulusan pada semester '
                      '$_estimatedGraduationSemester berdasarkan rata-rata '
                      '${_averageSksPerSemester.toStringAsFixed(1)} SKS per semester.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraduationEstimate() {
    final String message;

    if (_remainingSks == 0 && _targetSks > 0) {
      message =
          'Target SKS sudah terpenuhi. Pastikan seluruh persyaratan akademik lainnya juga selesai.';
    } else if (_estimatedGraduationSemester == null) {
      message =
          'Data akademik belum cukup untuk memperkirakan waktu kelulusan. Lengkapi data semester dan SKS terlebih dahulu.';
    } else if (_graduationStatus == 'Sesuai Rencana') {
      message =
          'Berdasarkan progres SKS saat ini, kamu diperkirakan dapat menyelesaikan studi sesuai target 8 semester.';
    } else {
      message =
          'Berdasarkan progres SKS saat ini, perkiraan kelulusan melebihi target 8 semester. Tingkatkan jumlah SKS yang ditempuh setiap semester.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFD97706),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Target',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
