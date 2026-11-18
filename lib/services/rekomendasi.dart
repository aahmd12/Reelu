
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/dbsupabase.dart';

class RekomendasiScreen extends StatefulWidget {
  const RekomendasiScreen({super.key});

  @override
  State<RekomendasiScreen> createState() => _RekomendasiScreenState();
}

class _RekomendasiScreenState extends State<RekomendasiScreen> {
  static const Color primary = Color(0xFF2563EB);
  static const Color dark = Color(0xFF142B59);
  static const Color secondary = Color(0xFF8493AB);
  static const Color background = Color(0xFFF6F8FC);

  bool _isLoading = true;
  bool _isFetching = false;
  bool _fetchAgain = false;
  bool _hasAcademicData = false;
  bool _hasError = false;

  String _fullName = '';
  String _predictionStatus = 'Belum Ada';

  double _ipk = 0;
  double _ips = 0;
  double? _predictionScore;

  int _totalSks = 0;
  int _targetSks = 144;
  int _semester = 0;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    _setupRealtime(user.id);
    await _loadRecommendationData();
  }

  void _setupRealtime(String userId) {
    _realtimeChannel = supabase.channel('rekomendasi_$userId');

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            _refreshData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'academic_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _refreshData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'predictions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _refreshData();
          },
        )
        .subscribe();
  }

  void _refreshData() {
    if (!mounted) return;
    _loadRecommendationData();
  }

  Future<void> _loadRecommendationData() async {
    if (_isFetching) {
      _fetchAgain = true;
      return;
    }

    _isFetching = true;

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return;
      }

      final results = await Future.wait<dynamic>([
        supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle(),
        supabase
            .from('academic_records')
            .select(
              'id,user_id,semester,ips,ipk,total_sks,target_sks,created_at',
            )
            .eq('user_id', user.id)
            .order('semester', ascending: false)
            .order('created_at', ascending: false)
            .limit(1),
        supabase
            .from('predictions')
            .select('status_lulus,probabilitas,created_at')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final academicRecords = results[1] as List;
      final predictions = results[2] as List;

      String fullName = '';

      if (profile != null && profile['full_name'] != null) {
        fullName = profile['full_name'].toString().trim();
      }

      double ipk = 0;
      double ips = 0;

      int totalSks = 0;
      int targetSks = 144;
      int semester = 0;

      final hasAcademicData = academicRecords.isNotEmpty;

      if (hasAcademicData) {
        final record = academicRecords.first;

        ipk = _toDouble(record['ipk']);
        ips = _toDouble(record['ips']);
        totalSks = _toDouble(record['total_sks']).round();

        if (record['target_sks'] != null) {
          targetSks = _toDouble(record['target_sks']).round();
        }

        semester = _toDouble(record['semester']).round();
      }

      String predictionStatus = 'Belum Ada';
      double? predictionScore;

      if (predictions.isNotEmpty) {
        final result = predictions.first;
        final rawScore = result['probabilitas'];

        if (rawScore != null) {
          double score = _toDouble(rawScore);

          if (score <= 1 && score >= 0) {
            score *= 100;
          }

          score = score.clamp(0.0, 100.0);
          predictionScore = score;
          predictionStatus = _getPredictionLabel(score);
        }
      }

      if (!mounted) return;

      setState(() {
        _fullName = fullName;
        _ipk = ipk;
        _ips = ips;
        _totalSks = totalSks;
        _targetSks = targetSks > 0 ? targetSks : 144;
        _semester = semester;
        _predictionScore = predictionScore;
        _predictionStatus = predictionStatus;
        _hasAcademicData = hasAcademicData;
        _hasError = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal mengambil data rekomendasi: $e');

      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;

      if (_fetchAgain && mounted) {
        _fetchAgain = false;
        _loadRecommendationData();
      }
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  String _getPredictionLabel(double score) {
    if (score >= 85) {
      return 'Sangat Berpotensi Lulus';
    } else if (score >= 70) {
      return 'Berpotensi Lulus';
    } else if (score >= 50) {
      return 'Perlu Peningkatan';
    } else {
      return 'Berisiko Terlambat Lulus';
    }
  }

  int get _remainingSks {
    return (_targetSks - _totalSks).clamp(0, _targetSks);
  }

  double get _sksProgress {
    if (_targetSks <= 0) return 0;
    return (_totalSks / _targetSks).clamp(0.0, 1.0);
  }

  Color get _predictionColor {
    switch (_predictionStatus) {
      case 'Sangat Berpotensi Lulus':
        return const Color(0xFF079669);
      case 'Berpotensi Lulus':
        return const Color(0xFF3278E8);
      case 'Perlu Peningkatan':
        return const Color(0xFFE58A26);
      case 'Berisiko Terlambat Lulus':
        return const Color(0xFFE04444);
      default:
        return const Color(0xFF98A2B3);
    }
  }

  Color get _predictionBackground {
    switch (_predictionStatus) {
      case 'Sangat Berpotensi Lulus':
        return const Color(0xFFEDFAF4);
      case 'Berpotensi Lulus':
        return const Color(0xFFEEF5FF);
      case 'Perlu Peningkatan':
        return const Color(0xFFFFF6EB);
      case 'Berisiko Terlambat Lulus':
        return const Color(0xFFFFEEEE);
      default:
        return const Color(0xFFF1F3F6);
    }
  }

  IconData get _predictionIcon {
    switch (_predictionStatus) {
      case 'Sangat Berpotensi Lulus':
        return Icons.check_circle_rounded;
      case 'Berpotensi Lulus':
        return Icons.trending_up_rounded;
      case 'Perlu Peningkatan':
        return Icons.warning_amber_rounded;
      case 'Berisiko Terlambat Lulus':
        return Icons.error_rounded;
      default:
        return Icons.track_changes_rounded;
    }
  }

  String get _predictionDescription {
    switch (_predictionStatus) {
      case 'Sangat Berpotensi Lulus':
        return 'Kondisi akademikmu sangat baik. Pertahankan prestasi dan konsistensi belajar agar target kelulusan dapat tercapai.';
      case 'Berpotensi Lulus':
        return 'Kondisi akademikmu cukup baik. Terus tingkatkan hasil belajar dan selesaikan sisa SKS sesuai rencana.';
      case 'Perlu Peningkatan':
        return 'Ada beberapa aspek akademik yang perlu ditingkatkan. Perhatikan IPK, IPS, kehadiran, dan penyelesaian mata kuliah.';
      case 'Berisiko Terlambat Lulus':
        return 'Kondisi akademik perlu mendapat perhatian lebih. Segera evaluasi perkembangan studi dan susun strategi perbaikan.';
      default:
        return 'Belum ditemukan hasil prediksi kelulusan. Lakukan prediksi terlebih dahulu untuk mengetahui perkiraan status kelulusanmu.';
    }
  }

  List<_RecommendationItem> get _recommendations {
    final recommendations = <_RecommendationItem>[];

    if (!_hasAcademicData) {
      recommendations.add(
        const _RecommendationItem(
          category: 'Data Akademik',
          title: 'Lengkapi data akademikmu',
          description:
              'Data akademik belum tersedia. Lengkapi IPK, IPS, semester, dan jumlah SKS agar rekomendasi dapat disesuaikan dengan perkembangan studimu.',
          icon: Icons.school_rounded,
          color: Color(0xFF079669),
          background: Color(0xFFEDFAF4),
        ),
      );
    } else {
      if (_ipk >= 3.50 && _ips >= 3.50) {
        recommendations.add(
          _RecommendationItem(
            category: 'IPK & IPS',
            title: 'Pertahankan prestasi akademik',
            description:
                'IPK kamu ${_ipk.toStringAsFixed(2)} dan IPS ${_ips.toStringAsFixed(2)}. Pertahankan konsistensi belajar dan prestasi akademikmu.',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF079669),
            background: const Color(0xFFEDFAF4),
          ),
        );
      } else if (_ipk < 3.00 || _ips < 3.00) {
        recommendations.add(
          _RecommendationItem(
            category: 'IPK & IPS',
            title: 'Tingkatkan pencapaian akademik',
            description:
                'IPK kamu ${_ipk.toStringAsFixed(2)} dan IPS ${_ips.toStringAsFixed(2)}. Evaluasi hasil belajar, perhatikan mata kuliah dengan nilai rendah, dan buat jadwal belajar yang lebih teratur.',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFFE58A26),
            background: const Color(0xFFFFF6EB),
          ),
        );
      } else {
        recommendations.add(
          _RecommendationItem(
            category: 'IPK & IPS',
            title: 'Pertahankan dan tingkatkan nilai',
            description:
                'IPK kamu ${_ipk.toStringAsFixed(2)} dan IPS ${_ips.toStringAsFixed(2)}. Pertahankan hasil belajar dan usahakan peningkatan nilai pada semester berikutnya.',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF3278E8),
            background: const Color(0xFFEEF5FF),
          ),
        );
      }
    }

    if (_targetSks > 0 && _remainingSks == 0) {
      recommendations.add(
        const _RecommendationItem(
          category: 'SKS',
          title: 'Target SKS telah tercapai',
          description:
              'Kamu telah mencapai target SKS. Pastikan seluruh persyaratan akademik lainnya juga sudah terpenuhi.',
          icon: Icons.menu_book_rounded,
          color: Color(0xFF3278E8),
          background: Color(0xFFEEF5FF),
        ),
      );
    } else {
      recommendations.add(
        _RecommendationItem(
          category: 'SKS',
          title: 'Selesaikan sisa SKS',
          description:
              'Kamu sudah menempuh $_totalSks dari target $_targetSks SKS. Masih ada $_remainingSks SKS yang perlu diselesaikan.',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF3278E8),
          background: const Color(0xFFEEF5FF),
        ),
      );
    }

    if (_semester > 0) {
      if (_semester >= 8 && _remainingSks > 0) {
        recommendations.add(
          _RecommendationItem(
            category: 'Semester',
            title: 'Perhatikan progres penyelesaian studi',
            description:
                'Kamu berada di semester $_semester dengan sisa $_remainingSks SKS. Susun rencana studi dengan cermat agar target kelulusan tetap terarah.',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF8755D9),
            background: const Color(0xFFF5F0FF),
          ),
        );
      } else {
        recommendations.add(
          _RecommendationItem(
            category: 'Semester',
            title: 'Rencanakan studi berikutnya',
            description:
                'Kamu sedang berada di semester $_semester. Susun rencana pengambilan mata kuliah sesuai dengan kebutuhan SKS yang masih tersisa.',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF8755D9),
            background: const Color(0xFFF5F0FF),
          ),
        );
      }
    }

    recommendations.add(
      _RecommendationItem(
        category: 'Prediksi Kelulusan',
        title: _predictionStatus == 'Belum Ada'
            ? 'Belum ada hasil prediksi'
            : '$_predictionStatus',
        description: _predictionScore == null
            ? _predictionDescription
            : 'Skor prediksi kelulusanmu ${_predictionScore!.toStringAsFixed(2)}%. $_predictionDescription',
        icon: _predictionIcon,
        color: _predictionColor,
        background: _predictionBackground,
      ),
    );

    return recommendations;
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;

    if (channel != null) {
      supabase.removeChannel(channel);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: RefreshIndicator(
              color: primary,
              onRefresh: _loadRecommendationData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 25),
                    if (_isLoading)
                      _buildWelcomeLoading()
                    else
                      _buildWelcomeCard(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Ringkasan Kondisi Akademik',
                      'Pantau perkembangan akademikmu secara singkat.',
                    ),
                    const SizedBox(height: 15),
                    _buildAcademicSummary(),
                    const SizedBox(height: 15),
                    if (_hasAcademicData) _buildSksProgress(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Rekomendasi Untukmu',
                      'Saran berdasarkan data akademik yang tersedia.',
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      _buildLoading()
                    else if (_hasError)
                      _buildErrorState()
                    else
                      _buildRecommendationList(),
                  ],
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
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                color: dark,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rekomendasi Akademik',
                style: GoogleFonts.inter(
                  color: dark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Panduan perjalanan akademikmu.',
                style: GoogleFonts.inter(
                  color: secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: primary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeLoading() {
    return Container(
      width: double.infinity,
      height: 155,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFDCE8FC)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F56C5),
            Color(0xFF3978EA),
            Color(0xFF6A9AF3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -35,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -65,
            child: Container(
              width: 115,
              height: 115,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 61,
                height: 61,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName.isNotEmpty
                          ? 'Hai, $_fullName!'
                          : 'Selamat datang!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kenali perkembangan akademikmu.',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Temukan saran untuk membantu perjalanan studimu menjadi lebih terarah.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: dark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: secondary,
            fontSize: 11.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicSummary() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.36,
      children: [
        _buildSummaryCard(
          title: 'IPK Saat Ini',
          value: _hasAcademicData ? _ipk.toStringAsFixed(2) : '-',
          icon: Icons.school_rounded,
          color: const Color(0xFF079669),
          iconBackground: const Color(0xFFE2F5ED),
          type: 'number',
        ),
        _buildSummaryCard(
          title: 'IPS Terakhir',
          value: _hasAcademicData ? _ips.toStringAsFixed(2) : '-',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF3278E8),
          iconBackground: const Color(0xFFE5EEFF),
          type: 'number',
        ),
        _buildSummaryCard(
          title: 'SKS Ditempuh',
          value: _hasAcademicData ? '$_totalSks / $_targetSks' : '-',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF8755D9),
          iconBackground: const Color(0xFFF0E8FF),
          type: 'sks',
        ),
        _buildSummaryCard(
          title: 'Prediksi Kelulusan',
          value: _predictionStatus,
          icon: _predictionIcon,
          color: _predictionColor,
          iconBackground: _predictionBackground,
          valueColor: _predictionColor,
          type: 'status',
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconBackground,
    required String type,
    Color? valueColor,
  }) {
    double fontSize = 23;

    if (type == 'sks') {
      fontSize = 18;
    } else if (type == 'status') {
      fontSize = value.length > 14 ? 12 : 16;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE9EEF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF243B64).withValues(alpha: 0.035),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: secondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: valueColor ?? dark,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSksProgress() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE9EEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: primary,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Progres Penyelesaian SKS',
                  style: GoogleFonts.inter(
                    color: dark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(_sksProgress * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  color: primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _sksProgress,
              minHeight: 9,
              backgroundColor: const Color(0xFFEDF1F7),
              color: primary,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_totalSks SKS ditempuh',
                style: GoogleFonts.inter(
                  color: secondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_remainingSks SKS tersisa',
                style: GoogleFonts.inter(
                  color: secondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationList() {
    final items = _recommendations;

    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: _buildRecommendationCard(item, index + 1),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendationCard(
    _RecommendationItem item,
    int number,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE9EEF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF243B64).withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: item.background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category,
                        style: GoogleFonts.inter(
                          color: item.color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '0$number',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB7C2D3),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    color: dark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF75869F),
                    fontSize: 11.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Memuat rekomendasi akademik...',
            style: GoogleFonts.inter(
              color: secondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE9EEF6)),
      ),
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFE58A26),
              size: 29,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Gagal memuat data',
            style: GoogleFonts.inter(
              color: dark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Periksa koneksi internetmu dan coba muat ulang data.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: secondary,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _loadRecommendationData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationItem {
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color background;

  const _RecommendationItem({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.background,
  });
}