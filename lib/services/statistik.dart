
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/dbsupabase.dart';
import '../screens/dataacademic/dataacademic.dart';
import 'inputstatistik.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasData = false;
  bool _showSemesterButtons = false;
  bool _isDeleting = false;

  String? _semesterActionMode;

  final Set<int> _selectedSemesters = {};

  final ScrollController _ipsChartScrollController =
      ScrollController();

  List<_AcademicData> _records = [];

  RealtimeChannel? _academicChannel;

  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadStatistics();
    _listenToAcademicChanges();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _ipsChartScrollController.dispose();

    if (_academicChannel != null) {
      supabase.removeChannel(_academicChannel!);
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatistics(showLoading: false);
    }
  }

  void _listenToAcademicChanges() {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    _academicChannel = supabase
        .channel('statistik-academic-records-${user.id}')
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
            _loadStatistics(
              showLoading: false,
              silent: true,
            );
          },
        )
        .subscribe();
  }

  Future<void> _loadStatistics({
    bool showLoading = true,
    bool silent = false,
  }) async {
    if (!mounted) return;

    final currentRequestId = ++_loadRequestId;

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted || currentRequestId != _loadRequestId) {
          return;
        }

        setState(() {
          _isLoading = false;
          _hasData = false;
          _records = [];
          _selectedSemesters.clear();
        });

        return;
      }

      final response = await supabase
          .from('academic_records')
          .select(
            'id, user_id, semester, ips, ipk, total_sks, target_sks, kehadiran, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted || currentRequestId != _loadRequestId) {
        return;
      }

      final Map<int, _AcademicData> semesterMap = {};

      for (final item in response) {
        final semester = _toInt(item['semester']);

        if (semester == null || semester < 1) {
          continue;
        }

        if (semesterMap.containsKey(semester)) {
          continue;
        }

        semesterMap[semester] = _AcademicData(
          id: item['id']?.toString(),
          semester: semester,
          ips: _toDouble(item['ips']),
          ipk: _toDouble(item['ipk']),
          totalSks: _toInt(item['total_sks']) ?? 0,
          targetSks: _toInt(item['target_sks']) ?? 0,
          kehadiran: _toDouble(item['kehadiran']),
          createdAt: item['created_at']?.toString(),
        );
      }

      final cleanedRecords = semesterMap.values.toList()
        ..sort(
          (a, b) => a.semester.compareTo(b.semester),
        );

      if (!mounted || currentRequestId != _loadRequestId) {
        return;
      }

      final hasChanged = !_areRecordsEqual(
        _records,
        cleanedRecords,
      );

      setState(() {
        _isLoading = false;
        _records = cleanedRecords;
        _hasData = cleanedRecords.isNotEmpty;

        _selectedSemesters.removeWhere(
          (semester) => !cleanedRecords.any(
            (record) => record.semester == semester,
          ),
        );

        if (cleanedRecords.isEmpty) {
          _selectedSemesters.clear();
          _semesterActionMode = null;
          _showSemesterButtons = false;
        }
      });

      if (hasChanged) {
        debugPrint('STATISTIK: Data akademik berhasil diperbarui.');
      }
    } catch (e) {
      debugPrint('STATISTIK ERROR: $e');

      if (!mounted || currentRequestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (!silent) {
        _showMessage(
          'Gagal mengambil data statistik.',
          isError: true,
        );
      }
    }
  }

  bool _areRecordsEqual(
    List<_AcademicData> oldRecords,
    List<_AcademicData> newRecords,
  ) {
    if (oldRecords.length != newRecords.length) {
      return false;
    }

    for (int i = 0; i < oldRecords.length; i++) {
      final oldRecord = oldRecords[i];
      final newRecord = newRecords[i];

      if (oldRecord.id != newRecord.id ||
          oldRecord.semester != newRecord.semester ||
          oldRecord.ips != newRecord.ips ||
          oldRecord.ipk != newRecord.ipk ||
          oldRecord.totalSks != newRecord.totalSks ||
          oldRecord.targetSks != newRecord.targetSks ||
          oldRecord.kehadiran != newRecord.kehadiran ||
          oldRecord.createdAt != newRecord.createdAt) {
        return false;
      }
    }

    return true;
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString().replaceAll(',', '.'),
        ) ??
        0;
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
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
          backgroundColor: isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF2563EB),
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

  Future<void> _openDataAcademic() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DataAcademicScreen(),
      ),
    );

    if (!mounted) return;

    await _loadStatistics(showLoading: false);
  }

  Future<void> _openInputStatistik(int semester) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InputStatistikScreen(
          semester: semester,
        ),
      ),
    );

    if (!mounted) return;

    await _loadStatistics(showLoading: false);
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatChange(
    double current,
    double previous,
  ) {
    final difference = current - previous;

    if (difference.abs() < 0.005) {
      return '0.00';
    }

    return '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)}';
  }

  bool _isIncrease(
    double current,
    double previous,
  ) {
    return current > previous;
  }

  List<int> get _availableSemesters {
    if (_records.isEmpty) {
      return [];
    }

    final maxSemester = _records
        .map((record) => record.semester)
        .reduce(
          (a, b) => a > b ? a : b,
        );

    return List.generate(
      maxSemester,
      (index) => index + 1,
    );
  }

  _AcademicData? get _latestRecord {
    if (_records.isEmpty) {
      return null;
    }

    return _records.last;
  }

  _AcademicData? _getPreviousRecord(
    _AcademicData record,
  ) {
    final index = _records.indexWhere(
      (item) => item.semester == record.semester,
    );

    if (index <= 0) {
      return null;
    }

    return _records[index - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF2563EB),
                onRefresh: () => _loadStatistics(
                  showLoading: false,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 450,
                    ),
                    child: _hasData
                        ? _buildStatisticsContent()
                        : _buildEmptyState(),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatisticsContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        65,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildTopMetricCards(),
          const SizedBox(height: 24),
          _buildIpkChartCard(),
          const SizedBox(height: 24),
          _buildIpsChartCard(),
          const SizedBox(height: 24),
          _buildAcademicSummary(),
          const SizedBox(height: 22),
          _buildCompleteDataSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        28,
        30,
        28,
        65,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 90),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 44,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum Ada Data',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF102A63),
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada data akademik yang dapat ditampilkan. Silakan lengkapi data akademik terlebih dahulu untuk melihat statistik perkembangan akademikmu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7187A9),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openDataAcademic,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.edit_note_rounded,
                size: 21,
              ),
              label: const Text(
                'Lengkapi Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistik Akademik',
            style: TextStyle(
              color: Color(0xFF102A63),
              fontSize: 27,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Lihat perkembangan nilai dan performa akademikmu dari waktu ke waktu.',
            style: TextStyle(
              color: Color(0xFF7B91B5),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetricCards() {
    final latest = _latestRecord;

    if (latest == null) {
      return const SizedBox.shrink();
    }

    final previous = _getPreviousRecord(latest);

    final ipkChange = previous == null
        ? '0.00'
        : _formatChange(latest.ipk, previous.ipk);

    final ipsChange = previous == null
        ? '0.00'
        : _formatChange(latest.ips, previous.ips);

    final ipkIncrease = previous != null &&
        _isIncrease(latest.ipk, previous.ipk);

    final ipsIncrease = previous != null &&
        _isIncrease(latest.ips, previous.ips);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTopMetricCard(
            title: 'Indeks Prestasi Kumulatif',
            shortTitle: 'IPK',
            value: _formatNumber(latest.ipk),
            change: ipkChange,
            increase: ipkIncrease,
            description: previous == null
                ? 'Belum ada perbandingan'
                : 'dari semester sebelumnya',
            semester: latest.semester,
            icon: Icons.school_rounded,
            gradientColors: const [
              Color(0xFF2563EB),
              Color(0xFF1745A5),
            ],
            iconBackground: const Color(0x33FFFFFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTopMetricCard(
            title: 'Indeks Prestasi Semester',
            shortTitle: 'IPS',
            value: _formatNumber(latest.ips),
            change: ipsChange,
            increase: ipsIncrease,
            description: previous == null
                ? 'Belum ada perbandingan'
                : 'dari semester sebelumnya',
            semester: latest.semester,
            icon: Icons.auto_graph_rounded,
            gradientColors: const [
              Color(0xFF6555D9),
              Color(0xFF4332A8),
            ],
            iconBackground: const Color(0x33FFFFFF),
          ),
        ),
      ],
    );
  }

  Widget _buildTopMetricCard({
    required String title,
    required String shortTitle,
    required String value,
    required String change,
    required bool increase,
    required String description,
    required int semester,
    required IconData icon,
    required List<Color> gradientColors,
    required Color iconBackground,
  }) {
    final numericValue = double.tryParse(value) ?? 0;
    final progress = (numericValue / 4).clamp(0.0, 1.0);
    final neutral = change == '0.00';

    final changeColor = neutral
        ? const Color(0xFFE2E8F0)
        : increase
            ? const Color(0xFFBBF7D0)
            : const Color(0xFFFECACA);

    final changeBackground = neutral
        ? const Color(0x22FFFFFF)
        : increase
            ? const Color(0xFF166534).withOpacity(0.28)
            : const Color(0xFF991B1B).withOpacity(0.28);

    return Container(
      constraints: const BoxConstraints(
        minHeight: 224,
      ),
      padding: const EdgeInsets.fromLTRB(
        13,
        14,
        13,
        14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.20),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0x44FFFFFF),
                  ),
                ),
                child: const Text(
                  'TERAKHIR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            shortTitle,
            style: const TextStyle(
              color: Color(0xFFDCE8FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFDCE8FF),
              fontSize: 9.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  bottom: 3,
                ),
                child: Text(
                  '/ 4.00',
                  style: TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0x44FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: changeBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      neutral
                          ? Icons.remove_rounded
                          : increase
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                      color: changeColor,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      change,
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Semester $semester',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIpkChartCard() {
    return _buildChartCard(
      title: 'Perkembangan IPK',
      subtitle: 'Grafik perkembangan IPK setiap semester.',
      label: 'IPK',
      child: _buildScrollableChart(
        painter: _AcademicLineChartPainter(
          records: _records,
          valueType: _ChartValueType.ipk,
        ),
      ),
    );
  }

  Widget _buildIpsChartCard() {
    return _buildChartCard(
      title: 'Perkembangan IPS',
      subtitle: 'Grafik perkembangan IPS setiap semester.',
      label: 'IPS',
      child: _buildScrollableChart(
        painter: _AcademicBarChartPainter(records: _records),
        scrollController: _ipsChartScrollController,
      ),
    );
  }

  Widget _buildScrollableChart({
    required CustomPainter painter,
    ScrollController? scrollController,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = (57.0 + _records.length * 90.0)
            .clamp(constraints.maxWidth, 100000.0)
            .toDouble();

        return Scrollbar(
          controller: scrollController,
          thumbVisibility: scrollController != null,
          interactive: true,
          thickness: 4,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: SizedBox(
              width: chartWidth,
              height: 265,
              child: CustomPaint(
                painter: painter,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF102A63),
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: 66,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE0EAF6)),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF173B78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF7B91B5),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildAcademicSummary() {
    final latest = _latestRecord;

    if (latest == null) {
      return const SizedBox.shrink();
    }

    final previous = _getPreviousRecord(latest);

    final ipkChange = previous == null
        ? '0.00'
        : _formatChange(latest.ipk, previous.ipk);

    final ipsChange = previous == null
        ? '0.00'
        : _formatChange(latest.ips, previous.ips);

    final targetSks = latest.targetSks;
    final totalSks = latest.totalSks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFCFE3FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Akademik',
            style: TextStyle(
              color: Color(0xFF102A63),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E9FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF2563EB),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryColumn(
                  title: 'Total SKS',
                  value: '$totalSks',
                  suffix: targetSks > 0
                      ? '/ $targetSks SKS'
                      : 'SKS',
                ),
              ),
              _buildSummaryDivider(),
              Expanded(
                child: _buildSummaryColumn(
                  title: 'Semester',
                  value: '${latest.semester}',
                  suffix: '/ 8',
                ),
              ),
              _buildSummaryDivider(),
              Expanded(
                child: _buildSummaryColumn(
                  title: 'IPK',
                  value: _formatNumber(latest.ipk),
                  suffix: ipkChange == '0.00' ? '' : ipkChange,
                  suffixColor: const Color(0xFF16A765),
                ),
              ),
              _buildSummaryDivider(),
              Expanded(
                child: _buildSummaryColumn(
                  title: 'IPS',
                  value: _formatNumber(latest.ips),
                  suffix: ipsChange == '0.00' ? '' : ipsChange,
                  suffixColor: const Color(0xFF16A765),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn({
    required String title,
    required String value,
    required String suffix,
    Color suffixColor = const Color(0xFF7B91B5),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF60789F),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF102A63),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (suffix.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              suffix,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: suffixColor,
                fontSize: 10,
                fontWeight:
                    suffixColor == const Color(0xFF16A765)
                        ? FontWeight.w600
                        : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 58,
      color: const Color(0xFFBCD5F5),
    );
  }

  Future<void> _openEditStatistik(_AcademicData record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InputStatistikScreen(
          semester: record.semester,
          existingData: record.toMap(),
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _semesterActionMode = null;
      _selectedSemesters.clear();
    });

    await _loadStatistics(showLoading: false);
  }

  void _cancelDeleteMode() {
    setState(() {
      _semesterActionMode = null;
      _selectedSemesters.clear();
    });

    _showMessage('Mode hapus berhasil dibatalkan.');
  }

  Future<void> _deleteSelectedSemesters() async {
    if (_isDeleting) return;

    if (_selectedSemesters.isEmpty) {
      _showMessage(
        'Pilih minimal satu semester terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final selectedRecords = _records
        .where(
          (record) => _selectedSemesters.contains(record.semester),
        )
        .toList();

    if (selectedRecords.isEmpty) {
      _showMessage(
        'Tidak ada data pada semester yang dipilih.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data Statistik?'),
        content: Text(
          selectedRecords.length == _records.length
              ? 'Semua data statistik yang tersimpan akan dihapus. Tindakan ini tidak dapat dibatalkan.'
              : 'Data ${selectedRecords.map((e) => 'semester ${e.semester}').join(', ')} akan dihapus. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Sesi pengguna tidak ditemukan.');
      }

      final semestersToDelete = selectedRecords
          .map((record) => record.semester)
          .toList();

      final deletedRows = await supabase
          .from('academic_records')
          .delete()
          .eq('user_id', user.id)
          .inFilter('semester', semestersToDelete)
          .select('id, semester');

      if (deletedRows.isEmpty) {
        throw Exception(
          'Tidak ada data yang berhasil dihapus. Periksa kembali izin akses database.',
        );
      }

      if (!mounted) return;

      setState(() {
        _selectedSemesters.clear();
        _semesterActionMode = null;
        _isDeleting = false;
      });

      _showMessage(
        '${deletedRows.length} data statistik berhasil dihapus.',
      );

      await _loadStatistics(showLoading: false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      _showMessage(
        'Gagal menghapus data statistik: $e',
        isError: true,
      );
    }
  }

  Widget _buildCompleteDataSection() {
    final semesters = _availableSemesters;

    if (semesters.isEmpty) {
      return const SizedBox.shrink();
    }

    final recordSemesters = _records
        .map((e) => e.semester)
        .toSet();

    final allSelected = recordSemesters.isNotEmpty &&
        _selectedSemesters.containsAll(recordSemesters);

    final isDeleteMode = _semesterActionMode == 'delete';
    final isEditMode = _semesterActionMode == 'edit';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE0EAF6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lengkapi Data Statistik',
            style: TextStyle(
              color: Color(0xFF102A63),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih semester untuk menambahkan, mengubah, atau menghapus data.',
            style: TextStyle(
              color: Color(0xFF7B91B5),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isDeleting
                  ? null
                  : () {
                      setState(() {
                        _showSemesterButtons = !_showSemesterButtons;
                        _semesterActionMode = null;
                        _selectedSemesters.clear();
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: Icon(
                _showSemesterButtons
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.edit_note_rounded,
              ),
              label: Text(
                _showSemesterButtons
                    ? 'Sembunyikan Semester'
                    : 'Lengkapi Data',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_showSemesterButtons) ...[
            const SizedBox(height: 15),

            if (isDeleteMode)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: allSelected,
                activeColor: const Color(0xFF2563EB),
                title: const Text(
                  'Pilih semua semester',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onChanged: _isDeleting
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedSemesters.addAll(recordSemesters);
                          } else {
                            _selectedSemesters.clear();
                          }
                        });
                      },
              ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: semesters.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 2.65,
              ),
              itemBuilder: (context, index) {
                final semester = semesters[index];

                final matchingRecords = _records.where(
                  (e) => e.semester == semester,
                );

                final _AcademicData? record =
                    matchingRecords.isEmpty
                        ? null
                        : matchingRecords.first;

                final hasRecord = record != null;

                final isSelected =
                    _selectedSemesters.contains(semester);

                final bool canTap = isDeleteMode
                    ? hasRecord
                    : isEditMode
                        ? hasRecord
                        : !hasRecord;

                final bool isDisabled = !canTap || _isDeleting;

                final Color backgroundColor = isSelected
                    ? const Color(0xFFDCEBFF)
                    : isDisabled
                        ? const Color(0xFFF1F4F8)
                        : hasRecord
                            ? const Color(0xFFEAF2FF)
                            : const Color(0xFFF8FBFF);

                final Color borderColor = isSelected
                    ? const Color(0xFF2563EB)
                    : isDisabled
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFCFE1FF);

                final Color textColor = isDisabled
                    ? const Color(0xFFA0AEC0)
                    : hasRecord
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF7187A9);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: canTap && !_isDeleting
                      ? () async {
                          if (isDeleteMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedSemesters.remove(semester);
                              } else {
                                _selectedSemesters.add(semester);
                              }
                            });
                          } else if (isEditMode) {
                            if (record != null) {
                              await _openEditStatistik(record);
                            }
                          } else {
                            await _openInputStatistik(semester);
                          }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isDeleteMode) ...[
                          Checkbox(
                            value: isSelected,
                            onChanged: hasRecord && !_isDeleting
                                ? (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedSemesters.add(semester);
                                      } else {
                                        _selectedSemesters.remove(semester);
                                      }
                                    });
                                  }
                                : null,
                            activeColor: const Color(0xFF2563EB),
                            visualDensity: VisualDensity.compact,
                          ),
                        ] else if (isEditMode) ...[
                          Icon(
                            hasRecord
                                ? Icons.edit_rounded
                                : Icons.lock_outline_rounded,
                            size: 17,
                            color: textColor,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Expanded(
                          child: Text(
                            'Semester $semester',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isDeleteMode &&
                            !isEditMode &&
                            hasRecord)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 17,
                          ),
                        if (!isDeleteMode &&
                            !isEditMode &&
                            !hasRecord)
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Color(0xFF2563EB),
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            if (isDeleteMode) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isDeleting
                          ? null
                          : _cancelDeleteMode,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                      label: const Text('Batal Hapus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(
                          color: Color(0xFFCBD5E1),
                        ),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedSemesters.isEmpty || _isDeleting
                          ? null
                          : _deleteSelectedSemesters,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.delete_forever_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _isDeleting
                            ? 'Menghapus...'
                            : 'Hapus Terpilih',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFFCA5A5),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _semesterActionMode =
                              isEditMode ? null : 'edit';

                          _selectedSemesters.clear();
                        });
                      },
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 17,
                      ),
                      label: const Text('Edit Data'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(
                          color: Color(0xFF2563EB),
                        ),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _semesterActionMode = 'delete';
                          _selectedSemesters.clear();
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Hapus Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (_semesterActionMode != null) ...[
              const SizedBox(height: 10),
              Text(
                isEditMode
                    ? 'Pilih semester yang sudah terisi untuk mengubah datanya.'
                    : 'Centang semester yang ingin dihapus, kemudian tekan Hapus Terpilih. Tekan Batal Hapus jika ingin membatalkan.',
                style: const TextStyle(
                  color: Color(0xFF7187A9),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

enum _ChartValueType {
  ipk,
  ips,
}

class _AcademicData {
  final String? id;
  final int semester;
  final double ips;
  final double ipk;
  final int totalSks;
  final int targetSks;
  final double kehadiran;
  final String? createdAt;

  const _AcademicData({
    required this.id,
    required this.semester,
    required this.ips,
    required this.ipk,
    required this.totalSks,
    required this.targetSks,
    required this.kehadiran,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'semester': semester,
        'ips': ips,
        'ipk': ipk,
        'total_sks': totalSks,
        'target_sks': targetSks,
        'kehadiran': kehadiran,
        'created_at': createdAt,
      };
}

class _AcademicLineChartPainter extends CustomPainter {
  final List<_AcademicData> records;
  final _ChartValueType valueType;

  _AcademicLineChartPainter({
    required this.records,
    required this.valueType,
  });

  double _getValue(_AcademicData record) {
    return valueType == _ChartValueType.ipk
        ? record.ipk
        : record.ips;
  }

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (records.isEmpty) {
      return;
    }

    const leftPadding = 45.0;
    const rightPadding = 12.0;
    const topPadding = 32.0;
    const bottomPadding = 55.0;

    final chartWidth =
        size.width - leftPadding - rightPadding;

    final chartHeight =
        size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE1EAF5)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const gridValues = [
      4.0,
      3.5,
      3.0,
      2.5,
      2.0,
    ];

    for (final value in gridValues) {
      final normalized = (value - 2.0) / 2.0;

      final y = topPadding +
          chartHeight -
          normalized * chartHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      _drawText(
        canvas,
        value.toStringAsFixed(2),
        Offset(0, y - 6),
        const TextStyle(
          color: Color(0xFF526D99),
          fontSize: 10,
        ),
        leftPadding - 9,
        TextAlign.right,
      );
    }

    final points = <Offset>[];

    for (int i = 0; i < records.length; i++) {
      final record = records[i];

      final x = records.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding +
              (i / (records.length - 1)) * chartWidth;

      final value = _getValue(record).clamp(2.0, 4.0);

      final normalized = (value - 2.0) / 2.0;

      final y = topPadding +
          chartHeight -
          normalized * chartHeight;

      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final path = Path()
        ..moveTo(
          points.first.dx,
          points.first.dy,
        );

      for (int i = 1; i < points.length; i++) {
        path.lineTo(
          points[i].dx,
          points[i].dy,
        );
      }

      canvas.drawPath(path, linePaint);
    }

    final pointPaint = Paint()
      ..color = const Color(0xFF2563EB);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final record = records[i];

      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        point,
        4,
        pointPaint,
      );

      _drawLabelBubble(
        canvas,
        point,
        _getValue(record).toStringAsFixed(2),
        size,
      );

      _drawText(
        canvas,
        '${record.semester}',
        Offset(
          point.dx - 45,
          topPadding + chartHeight + 10,
        ),
        const TextStyle(
          color: Color(0xFF526D99),
          fontSize: 9.5,
        ),
        90,
        TextAlign.center,
      );
    }

    _drawText(
      canvas,
      'Semester',
      Offset(leftPadding, size.height - 16),
      const TextStyle(
        color: Color(0xFF526D99),
        fontSize: 10,
      ),
      chartWidth,
      TextAlign.center,
    );
  }

  void _drawLabelBubble(
    Canvas canvas,
    Offset point,
    String text,
    Size size,
  ) {
    const bubbleWidth = 52.0;
    const bubbleHeight = 27.0;

    double left = point.dx - bubbleWidth / 2;
    double top = point.dy - bubbleHeight - 10;

    if (left < 2) {
      left = 2;
    }

    if (left + bubbleWidth > size.width - 2) {
      left = size.width - bubbleWidth - 2;
    }

    if (top < 2) {
      top = point.dy + 10;
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left,
        top,
        bubbleWidth,
        bubbleHeight,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFFF0F6FF),
    );

    _drawText(
      canvas,
      text,
      Offset(left, top + 5),
      const TextStyle(
        color: Color(0xFF102A63),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      bubbleWidth,
      TextAlign.center,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
    double width,
    TextAlign align,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(
        minWidth: width,
        maxWidth: width,
      );

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(
    covariant _AcademicLineChartPainter oldDelegate,
  ) {
    if (oldDelegate.valueType != valueType ||
        oldDelegate.records.length != records.length) {
      return true;
    }

    for (int i = 0; i < records.length; i++) {
      if (oldDelegate.records[i].semester != records[i].semester ||
          oldDelegate.records[i].ipk != records[i].ipk ||
          oldDelegate.records[i].ips != records[i].ips) {
        return true;
      }
    }

    return false;
  }
}

class _AcademicBarChartPainter extends CustomPainter {
  final List<_AcademicData> records;

  _AcademicBarChartPainter({
    required this.records,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (records.isEmpty) {
      return;
    }

    const leftPadding = 45.0;
    const rightPadding = 10.0;
    const topPadding = 32.0;
    const bottomPadding = 55.0;

    final chartWidth =
        size.width - leftPadding - rightPadding;

    final chartHeight =
        size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE1EAF5)
      ..strokeWidth = 1;

    const gridValues = [
      4.0,
      3.0,
      2.0,
      1.0,
      0.0,
    ];

    for (final value in gridValues) {
      final normalized = value / 4.0;

      final y = topPadding +
          chartHeight -
          normalized * chartHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      _drawText(
        canvas,
        value.toStringAsFixed(2),
        Offset(0, y - 6),
        const TextStyle(
          color: Color(0xFF526D99),
          fontSize: 10,
        ),
        leftPadding - 9,
        TextAlign.right,
      );
    }

    final count = records.length;
    final slotWidth = chartWidth / count;

    for (int i = 0; i < count; i++) {
      final record = records[i];

      final value = record.ips.clamp(0.0, 4.0);

      final barHeight =
          (value / 4.0) * chartHeight;

      final barWidth = slotWidth * 0.28;

      final left = leftPadding +
          i * slotWidth +
          (slotWidth - barWidth) / 2;

      final top = topPadding +
          chartHeight -
          barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          top,
          barWidth,
          barHeight,
        ),
        const Radius.circular(7),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = i == count - 1
              ? const Color(0xFF2563EB)
              : const Color(0xFF82ABF2),
      );

      _drawText(
        canvas,
        value.toStringAsFixed(2),
        Offset(
          left - 12,
          top - 18,
        ),
        const TextStyle(
          color: Color(0xFF102A63),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        barWidth + 24,
        TextAlign.center,
      );

      _drawText(
        canvas,
        '${record.semester}',
        Offset(
          left - 20,
          topPadding + chartHeight + 10,
        ),
        const TextStyle(
          color: Color(0xFF526D99),
          fontSize: 9.5,
        ),
        barWidth + 40,
        TextAlign.center,
      );
    }

    _drawText(
      canvas,
      'Semester',
      Offset(
        leftPadding,
        size.height - 16,
      ),
      const TextStyle(
        color: Color(0xFF526D99),
        fontSize: 10,
      ),
      chartWidth,
      TextAlign.center,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
    double width,
    TextAlign align,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(
        minWidth: width,
        maxWidth: width,
      );

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(
    covariant _AcademicBarChartPainter oldDelegate,
  ) {
    if (oldDelegate.records.length != records.length) {
      return true;
    }

    for (int i = 0; i < records.length; i++) {
      if (oldDelegate.records[i].semester != records[i].semester ||
          oldDelegate.records[i].ips != records[i].ips) {
        return true;
      }
    }

    return false;
  }
}