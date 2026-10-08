import 'dart:async';

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

  List<_AcademicData> _records = [];

  RealtimeChannel? _academicChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadStatistics();
    _listenToAcademicChanges();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();

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

  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        if (!mounted) return;

        _loadStatistics(
          showLoading: false,
          silent: true,
        );
      },
    );
  }

  void _listenToAcademicChanges() {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    _academicChannel = supabase
        .channel(
          'statistik-academic-records-${user.id}-${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'academic_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) async {
            await _loadStatistics(
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

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _hasData = false;
          _records = [];
        });

        return;
      }

      final response = await supabase
          .from('academic_records')
          .select(
            'id, user_id, semester, ips, ipk, total_sks, target_sks, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final List<_AcademicData> loadedRecords = [];

      for (final item in response) {
        final semester = _toInt(item['semester']);

        if (semester == null || semester < 1) {
          continue;
        }

        loadedRecords.add(
          _AcademicData(
            id: item['id']?.toString(),
            semester: semester,
            ips: _toDouble(item['ips']),
            ipk: _toDouble(item['ipk']),
            totalSks: _toInt(item['total_sks']) ?? 0,
            targetSks: _toInt(item['target_sks']) ?? 0,
            createdAt: item['created_at']?.toString(),
          ),
        );
      }

      final Map<int, _AcademicData> semesterMap = {};

      for (final record in loadedRecords) {
        final existing = semesterMap[record.semester];

        if (existing == null) {
          semesterMap[record.semester] = record;
        } else {
          final existingDate =
              DateTime.tryParse(existing.createdAt ?? '');

          final currentDate =
              DateTime.tryParse(record.createdAt ?? '');

          if (currentDate != null &&
              (existingDate == null ||
                  currentDate.isAfter(existingDate))) {
            semesterMap[record.semester] = record;
          }
        }
      }

      final cleanedRecords = semesterMap.values.toList()
        ..sort(
          (a, b) => a.semester.compareTo(b.semester),
        );

      if (!mounted) return;

      final hasChanged = !_areRecordsEqual(
        _records,
        cleanedRecords,
      );

      if (hasChanged || showLoading) {
        setState(() {
          _isLoading = false;
          _records = cleanedRecords;
          _hasData = cleanedRecords.isNotEmpty;
        });
      } else if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('STATISTIK ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!silent && showLoading) {
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

    await _loadStatistics(
      showLoading: false,
    );
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

    await _loadStatistics(
      showLoading: false,
    );
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
      padding: EdgeInsets.only(
        top: 8,
      ),
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
        : _formatChange(
            latest.ipk,
            previous.ipk,
          );

    final ipsChange = previous == null
        ? '0.00'
        : _formatChange(
            latest.ips,
            previous.ips,
          );

    final ipkIncrease = previous != null &&
        _isIncrease(
          latest.ipk,
          previous.ipk,
        );

    final ipsIncrease = previous != null &&
        _isIncrease(
          latest.ips,
          previous.ips,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTopMetricCard(
            title: 'IPK Saat Ini',
            value: _formatNumber(latest.ipk),
            change: ipkChange,
            increase: ipkIncrease,
            description: previous == null
                ? 'semester ini'
                : 'dari semester lalu',
            icon: Icons.school_rounded,
            background: const Color(0xFFEAF4FF),
            iconBackground: const Color(0xFFD5E8FF),
            iconColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTopMetricCard(
            title: 'IPS Semester Terakhir',
            value: _formatNumber(latest.ips),
            change: ipsChange,
            increase: ipsIncrease,
            description: previous == null
                ? 'semester ini'
                : 'dari semester sebelumnya',
            icon: Icons.bar_chart_rounded,
            background: const Color(0xFFF2F0FF),
            iconBackground: const Color(0xFFE1DCFF),
            iconColor: const Color(0xFF4F46E5),
          ),
        ),
      ],
    );
  }

  Widget _buildTopMetricCard({
    required String title,
    required String value,
    required String change,
    required bool increase,
    required String description,
    required IconData icon,
    required Color background,
    required Color iconBackground,
    required Color iconColor,
  }) {
    final neutral = change == '0.00';

    return Container(
      constraints: const BoxConstraints(
        minHeight: 174,
      ),
      padding: const EdgeInsets.fromLTRB(
        14,
        16,
        14,
        15,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: iconBackground,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF536C96),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF102A63),
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      neutral
                          ? Icons.remove_rounded
                          : increase
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                      size: 15,
                      color: neutral
                          ? const Color(0xFF7B91B5)
                          : increase
                              ? const Color(0xFF16A765)
                              : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: change,
                              style: TextStyle(
                                color: neutral
                                    ? const Color(0xFF7B91B5)
                                    : increase
                                        ? const Color(0xFF16A765)
                                        : const Color(0xFFDC2626),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' $description',
                              style: const TextStyle(
                                color: Color(0xFF7187A9),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpkChartCard() {
    return _buildChartCard(
      title: 'Perkembangan IPK',
      subtitle: 'Grafik peningkatan IPK setiap semester.',
      dropdownText: 'IPK',
      child: SizedBox(
        height: 245,
        child: CustomPaint(
          painter: _AcademicLineChartPainter(
            records: _records,
            valueType: _ChartValueType.ipk,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildIpsChartCard() {
    return _buildChartCard(
      title: 'Perkembangan IPS',
      subtitle: 'Grafik peningkatan IPS setiap semester.',
      dropdownText: 'IPS',
      child: SizedBox(
        height: 245,
        child: CustomPaint(
          painter: _AcademicBarChartPainter(
            records: _records,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required String dropdownText,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        12,
      ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFE0EAF6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dropdownText,
                      style: const TextStyle(
                        color: Color(0xFF173B78),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF536C96),
                      size: 19,
                    ),
                  ],
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
        : _formatChange(
            latest.ipk,
            previous.ipk,
          );

    final ipsChange = previous == null
        ? '0.00'
        : _formatChange(
            latest.ips,
            previous.ips,
          );

    final targetSks = latest.targetSks;
    final totalSks = latest.totalSks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        17,
        16,
        17,
      ),
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
                  title: 'Semester Saat Ini',
                  value: '${latest.semester}',
                  suffix: '/ 8',
                ),
              ),
              _buildSummaryDivider(),
              Expanded(
                child: _buildSummaryColumn(
                  title: 'IPK',
                  value: _formatNumber(latest.ipk),
                  suffix: ipkChange == '0.00'
                      ? ''
                      : ipkChange,
                  suffixColor: const Color(0xFF16A765),
                ),
              ),
              _buildSummaryDivider(),
              Expanded(
                child: _buildSummaryColumn(
                  title: 'IPS',
                  value: _formatNumber(latest.ips),
                  suffix: ipsChange == '0.00'
                      ? ''
                      : ipsChange,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
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

  Widget _buildCompleteDataSection() {
    final semesters = _availableSemesters;

    if (semesters.isEmpty) {
      return const SizedBox.shrink();
    }

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
            'Pilih semester yang ingin kamu lengkapi atau perbarui datanya.',
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
              onPressed: () {
                setState(() {
                  _showSemesterButtons = !_showSemesterButtons;
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: semesters.map((semester) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _openInputStatistik(semester);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCFE1FF),
                      ),
                    ),
                    child: Text(
                      'Semester $semester',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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
  final String? createdAt;

  const _AcademicData({
    required this.id,
    required this.semester,
    required this.ips,
    required this.ipk,
    required this.totalSks,
    required this.targetSks,
    required this.createdAt,
  });
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
    const bottomPadding = 44.0;

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

      final y =
          topPadding +
          chartHeight -
          normalized * chartHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(
          leftPadding + chartWidth,
          y,
        ),
        gridPaint,
      );

      _drawText(
        canvas,
        value.toStringAsFixed(2),
        Offset(
          0,
          y - 6,
        ),
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
              (i / (records.length - 1)) *
                  chartWidth;

      final value = _getValue(record).clamp(
        2.0,
        4.0,
      );

      final normalized =
          (value - 2.0) / 2.0;

      final y =
          topPadding +
          chartHeight -
          normalized * chartHeight;

      points.add(
        Offset(x, y),
      );
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

      canvas.drawPath(
        path,
        linePaint,
      );
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
        'Semester ${record.semester}',
        Offset(
          point.dx - 45,
          topPadding +
              chartHeight +
              10,
        ),
        const TextStyle(
          color: Color(0xFF526D99),
          fontSize: 9.5,
        ),
        90,
        TextAlign.center,
      );
    }
  }

  void _drawLabelBubble(
    Canvas canvas,
    Offset point,
    String text,
    Size size,
  ) {
    const bubbleWidth = 52.0;
    const bubbleHeight = 27.0;

    double left =
        point.dx - bubbleWidth / 2;

    double top =
        point.dy - bubbleHeight - 10;

    if (left < 2) {
      left = 2;
    }

    if (left + bubbleWidth >
        size.width - 2) {
      left =
          size.width - bubbleWidth - 2;
    }

    if (top < 2) {
      top = point.dy + 10;
    }

    final rect =
        RRect.fromRectAndRadius(
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
      Paint()
        ..color = const Color(0xFFF0F6FF),
    );

    _drawText(
      canvas,
      text,
      Offset(
        left,
        top + 5,
      ),
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

    painter.paint(
      canvas,
      offset,
    );
  }

  @override
  bool shouldRepaint(
    covariant _AcademicLineChartPainter oldDelegate,
  ) {
    return oldDelegate.records != records ||
        oldDelegate.valueType != valueType;
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
    const bottomPadding = 44.0;

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

      final y =
          topPadding +
          chartHeight -
          normalized * chartHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(
          leftPadding + chartWidth,
          y,
        ),
        gridPaint,
      );

      _drawText(
        canvas,
        value.toStringAsFixed(2),
        Offset(
          0,
          y - 6,
        ),
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

      final value = record.ips.clamp(
        0.0,
        4.0,
      );

      final barHeight =
          (value / 4.0) * chartHeight;

      final barWidth =
          slotWidth * 0.48;

      final left =
          leftPadding +
          i * slotWidth +
          (slotWidth - barWidth) / 2;

      final top =
          topPadding +
          chartHeight -
          barHeight;

      final rect =
          RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          top,
          barWidth,
          barHeight,
        ),
        const Radius.circular(9),
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
        'Semester ${record.semester}',
        Offset(
          left - 20,
          topPadding +
              chartHeight +
              10,
        ),
        const TextStyle(
          color: Color(0xFF526D99),
          fontSize: 9.5,
        ),
        barWidth + 40,
        TextAlign.center,
      );
    }
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

    painter.paint(
      canvas,
      offset,
    );
  }

  @override
  bool shouldRepaint(
    covariant _AcademicBarChartPainter oldDelegate,
  ) {
    return oldDelegate.records != records;
  }
}