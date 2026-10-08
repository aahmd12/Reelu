import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/dbsupabase.dart';

class ViewDetailsScreen extends StatefulWidget {
  const ViewDetailsScreen({super.key});

  @override
  State<ViewDetailsScreen> createState() => _ViewDetailsScreenState();
}

class _ViewDetailsScreenState extends State<ViewDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _prediction;
  Map<String, dynamic>? _academic;

  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _darkBlue = Color(0xFF102A63);
  static const Color _textColor = Color(0xFF182B4D);
  static const Color _backgroundColor = Color(0xFFF6FAFF);
  static const Color _borderColor = Color(0xFFDCEBFC);
  static const Color _softBorderColor = Color(0xFFE1EAF5);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Sesi pengguna tidak ditemukan. Silakan login kembali.';
          });
        }
        return;
      }

      final predictionResponse = await supabase
          .from('predictions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (predictionResponse == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Belum ada hasil prediksi. Silakan lakukan prediksi terlebih dahulu untuk melihat detailnya.';
          });
        }
        return;
      }

      final academicResponse = await supabase
          .from('academic_records')
          .select(
            'id, semester, ips, ipk, total_sks, target_sks, created_at',
          )
          .eq('user_id', user.id)
          .order('semester', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _prediction = predictionResponse;
          _academic = academicResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal mengambil detail prediksi: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Data detail prediksi belum dapat ditampilkan. Silakan coba lagi.';
        });
      }
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '-';
    }

    final number = double.tryParse(
      value.toString().replaceAll(',', '.'),
    );

    if (number == null) {
      return value.toString();
    }

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(
        value.toString(),
      ).toLocal();

      const months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return value.toString();
    }
  }

  String _getStatus() {
    return _prediction?['status_lulus']?.toString() ??
        'Belum diketahui';
  }

  double? _getProbabilityValue() {
    final value = _prediction?['probabilitas'];

    if (value == null) {
      return null;
    }

    return double.tryParse(
      value.toString().replaceAll(',', '.'),
    );
  }

  String _getProbability() {
    final number = _getProbabilityValue();

    if (number == null) {
      return '-%';
    }

    return '${number.toStringAsFixed(0)}%';
  }

  String _getPredictionDate() {
    final tanggal = _prediction?['tanggal'];

    if (tanggal != null &&
        tanggal.toString().trim().isNotEmpty) {
      return _formatDate(tanggal);
    }

    return _formatDate(
      _prediction?['created_at'],
    );
  }

  IconData _getProbabilityIcon() {
    final probability = _getProbabilityValue();

    if (probability == null) {
      return Icons.help_outline_rounded;
    }

    if (probability >= 75) {
      return Icons.trending_up_rounded;
    }

    if (probability >= 50) {
      return Icons.trending_flat_rounded;
    }

    return Icons.trending_down_rounded;
  }

  Color _getProbabilityColor() {
    final probability = _getProbabilityValue();

    if (probability == null) {
      return const Color(0xFF7188A8);
    }

    if (probability >= 75) {
      return const Color(0xFF159A62);
    }

    if (probability >= 50) {
      return const Color(0xFFE09200);
    }

    return const Color(0xFFE05252);
  }

  Color _getProbabilityBackground() {
    final probability = _getProbabilityValue();

    if (probability == null) {
      return const Color(0xFFF1F5F9);
    }

    if (probability >= 75) {
      return const Color(0xFFE8F8F0);
    }

    if (probability >= 50) {
      return const Color(0xFFFFF4E5);
    }

    return const Color(0xFFFFECEC);
  }

  String _getProbabilityLabel() {
    final probability = _getProbabilityValue();

    if (probability == null) {
      return 'Belum tersedia';
    }

    if (probability >= 75) {
      return 'Tinggi';
    }

    if (probability >= 50) {
      return 'Relatif Aman';
    }

    return 'Rendah';
  }

  bool _isLulus() {
    final status = _getStatus().toLowerCase();

    return status.contains('lulus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Column(
              children: [
                _buildBackHeader(),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        4,
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                      color: _textColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Detail Prediksi',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageState();
    }

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          30,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPredictionCard(),

            const SizedBox(height: 20),

            const Text(
              'Data Akademik',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _darkBlue,
              ),
            ),

            const SizedBox(height: 12),

            _buildAcademicCard(),

            const SizedBox(height: 20),

            _buildInformationCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    final probabilityColor =
        _getProbabilityColor();

    final probabilityBackground =
        _getProbabilityBackground();

    final probabilityIcon =
        _getProbabilityIcon();

    final probabilityLabel =
        _getProbabilityLabel();

    final bool isLulus = _isLulus();

    final Color statusColor = isLulus
        ? const Color(0xFF159A62)
        : const Color(0xFFE09200);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _borderColor,
          width: 1.1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: probabilityBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              probabilityIcon,
              color: probabilityColor,
              size: 38,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _getStatus(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: statusColor,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _getPredictionDate(),
            style: const TextStyle(
              color: Color(0xFF91A0B5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            height: 1,
            color: _softBorderColor,
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                _getProbability(),
                style: TextStyle(
                  color: probabilityColor,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 3,
                ),
                child: Text(
                  probabilityLabel,
                  style: TextStyle(
                    color: probabilityColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            'Probabilitas Prediksi',
            style: TextStyle(
              color: Color(0xFF91A0B5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _softBorderColor,
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'IPS',
            _formatNumber(
              _academic?['ips'],
            ),
          ),
          _buildDivider(),
          _buildDetailRow(
            'IPK',
            _formatNumber(
              _academic?['ipk'],
            ),
          ),
          _buildDivider(),
          _buildDetailRow(
            'Total SKS',
            _formatNumber(
              _academic?['total_sks'],
            ),
          ),
          _buildDivider(),
          _buildDetailRow(
            'Target SKS',
            _formatNumber(
              _academic?['target_sks'],
            ),
          ),
          _buildDivider(),
          _buildDetailRow(
            'Semester',
            _formatNumber(
              _academic?['semester'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        15,
        16,
        15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD7E8FF),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: _primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Hasil prediksi dihitung berdasarkan data akademik yang dimasukkan pada saat melakukan prediksi.',
              style: TextStyle(
                color: _textColor,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState() {
    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          30,
        ),
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height -
                  150,
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: _softBorderColor,
                ),
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFEAF3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: _primaryColor,
                      size: 38,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Belum Ada Prediksi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _darkBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _errorMessage ??
                        'Belum ada hasil prediksi. Silakan lakukan prediksi terlebih dahulu.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7188A8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
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
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Kembali',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w700,
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
  }

  Widget _buildDetailRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF91A0B5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 20),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: _softBorderColor,
      height: 1,
      thickness: 1,
    );
  }
}