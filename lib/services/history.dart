import 'package:flutter/material.dart';

import '../core/constants/dbsupabase.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isSelectMode = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _history = [];
  final Set<String> _selectedIds = {};

  static const Color _primaryColor =
      Color(0xFF2563EB);

  static const Color _darkColor =
      Color(0xFF071D49);

  static const Color _secondaryTextColor =
      Color(0xFF667085);

  static const Color _backgroundColor =
      Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> refreshHistory() async {
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
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
                'User tidak ditemukan. Silakan login kembali.';
          });
        }
        return;
      }

      final response = await supabase
          .from('predictions')
          .select(
            'id, user_id, status_lulus, probabilitas, created_at',
          )
          .eq('user_id', user.id)
          .order(
            'created_at',
            ascending: false,
          );

      if (mounted) {
        setState(() {
          _history =
              List<Map<String, dynamic>>.from(
            response,
          );

          _selectedIds.clear();
          _isSelectMode = false;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint(
        'Gagal mengambil riwayat prediksi: $e',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Terjadi kesalahan saat mengambil riwayat prediksi.';
        });
      }
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '0';
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

      return '${date.day} '
          '${months[date.month - 1]} '
          '${date.year}';
    } catch (e) {
      return value.toString();
    }
  }

  String _getDate(
    Map<String, dynamic> prediction,
  ) {
    return _formatDate(
      prediction['created_at'],
    );
  }

  String _getTime(
    Map<String, dynamic> prediction,
  ) {
    final value =
        prediction['created_at'];

    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(
        value.toString(),
      ).toLocal();

      final hour = date.hour
          .toString()
          .padLeft(2, '0');

      final minute = date.minute
          .toString()
          .padLeft(2, '0');

      return '$hour:$minute WIB';
    } catch (e) {
      return '-';
    }
  }

  String _getStatus(
    Map<String, dynamic> prediction,
  ) {
    final status =
        prediction['status_lulus']?.toString();

    if (status == null ||
        status.trim().isEmpty) {
      return 'Status Tidak Diketahui';
    }

    return status;
  }

  String _getProbability(
    Map<String, dynamic> prediction,
  ) {
    return '${_formatNumber(
      prediction['probabilitas'],
    )}%';
  }

  String _getPredictionId(
    Map<String, dynamic> prediction,
  ) {
    return prediction['id']?.toString() ?? '';
  }

  Color _getStatusColor(
    Map<String, dynamic> prediction,
  ) {
    final status =
        _getStatus(prediction).toLowerCase();

    if (status.contains('risiko tinggi') ||
        status.contains('terlambat') ||
        status.contains('gagal') ||
        status.contains('tidak berpotensi')) {
      return Colors.red;
    }

    if (status.contains('perlu perhatian') ||
        status.contains('risiko')) {
      return Colors.orange;
    }

    return Colors.green;
  }

  IconData _getStatusIcon(
    Color statusColor,
  ) {
    if (statusColor == Colors.green) {
      return Icons.check_circle_rounded;
    }

    if (statusColor == Colors.orange) {
      return Icons.info_rounded;
    }

    return Icons.cancel_rounded;
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _history.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();

        for (final prediction in _history) {
          final id = _getPredictionId(
            prediction,
          );

          if (id.isNotEmpty) {
            _selectedIds.add(id);
          }
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _confirmDeleteSingle(
    Map<String, dynamic> prediction,
  ) async {
    final status = _getStatus(prediction);
    final probability =
        _getProbability(prediction);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          title: const Text(
            'Hapus Riwayat?',
            style: TextStyle(
              color: _darkColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Riwayat prediksi "$status" '
            'dengan probabilitas $probability '
            'akan dihapus secara permanen.',
            style: const TextStyle(
              color: _secondaryTextColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: _secondaryTextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Hapus',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteSingle(prediction);
    }
  }

  Future<void> _deleteSingle(
    Map<String, dynamic> prediction,
  ) async {
    final id = _getPredictionId(prediction);

    if (id.isEmpty) {
      _showMessage(
        'ID riwayat tidak ditemukan.',
      );
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'User tidak ditemukan. Silakan login kembali.',
      );
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await supabase
          .from('predictions')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _history.removeWhere(
          (item) =>
              _getPredictionId(item) == id,
        );

        _selectedIds.remove(id);
        _isDeleting = false;
      });

      _showMessage(
        'Riwayat prediksi berhasil dihapus.',
      );
    } catch (e) {
      debugPrint(
        'Gagal menghapus riwayat prediksi: $e',
      );

      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        _showMessage(
          'Gagal menghapus riwayat prediksi.',
        );
      }
    }
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) {
      _showMessage(
        'Pilih riwayat yang ingin dihapus terlebih dahulu.',
      );
      return;
    }

    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          title: const Text(
            'Hapus Riwayat Terpilih?',
            style: TextStyle(
              color: _darkColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$count riwayat prediksi yang dipilih '
            'akan dihapus secara permanen.',
            style: const TextStyle(
              color: _secondaryTextColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: _secondaryTextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Hapus',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteSelected();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'User tidak ditemukan. Silakan login kembali.',
      );
      return;
    }

    final ids = List<String>.from(
      _selectedIds,
    );

    setState(() {
      _isDeleting = true;
    });

    try {
      await supabase
          .from('predictions')
          .delete()
          .eq('user_id', user.id)
          .inFilter('id', ids);

      if (!mounted) {
        return;
      }

      setState(() {
        _history.removeWhere(
          (prediction) =>
              ids.contains(
            _getPredictionId(prediction),
          ),
        );

        _selectedIds.clear();
        _isSelectMode = false;
        _isDeleting = false;
      });

      _showMessage(
        '${ids.length} riwayat prediksi berhasil dihapus.',
      );
    } catch (e) {
      debugPrint(
        'Gagal menghapus riwayat terpilih: $e',
      );

      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        _showMessage(
          'Gagal menghapus riwayat prediksi.',
        );
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _goBackToDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/dashboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 380,
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
        16.0,
        10.0,
        16.0,
        0.0,
      ),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: _isDeleting
                ? null
                : _goBackToDashboard,
            borderRadius:
                BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: _darkColor,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Riwayat',
                    style: TextStyle(
                      color: _darkColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_history.isEmpty) {
      return _buildEmptyState();
    }

    return _buildHistoryList();
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(
          16.0,
          12.0,
          16.0,
          65.0,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _secondaryTextColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loadHistory,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      _primaryColor,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 24,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
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
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: _loadHistory,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              16.0,
              12.0,
              16.0,
              65.0,
            ),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(
                minHeight:
                    constraints.maxHeight - 77.0,
              ),
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, 35),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color:
                            Colors.grey.shade400,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      const Text(
                        'Belum ada riwayat prediksi.',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: _darkColor,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      const Text(
                        'Lakukan prediksi terlebih dahulu\n'
                        'untuk melihat riwayat',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              _secondaryTextColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      children: [
        _buildActionBar(),
        Expanded(
          child: RefreshIndicator(
            color: _primaryColor,
            onRefresh: _loadHistory,
            child: ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                16.0,
                12.0,
                16.0,
                65.0,
              ),
              itemCount: _history.length,
              itemBuilder:
                  (context, index) {
                final prediction =
                    _history[index];

                final statusColor =
                    _getStatusColor(
                  prediction,
                );

                return _buildHistoryCard(
                  prediction,
                  statusColor,
                  index,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    if (!_isSelectMode) {
      return Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16.0,
          12.0,
          16.0,
          0.0,
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Riwayat Prediksi',
                style: TextStyle(
                  color: _darkColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _toggleSelectMode,
              icon: const Icon(
                Icons.checklist_rounded,
                size: 20,
              ),
              label: const Text(
                'Pilih',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor:
                    _primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    final allSelected =
        _history.isNotEmpty &&
            _selectedIds.length ==
                _history.length;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16.0,
        12.0,
        16.0,
        0.0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isDeleting
                ? null
                : _toggleSelectMode,
            icon: const Icon(
              Icons.close_rounded,
            ),
            color: _darkColor,
            tooltip: 'Batal',
          ),
          Expanded(
            child: Text(
              '${_selectedIds.length} dipilih',
              style: const TextStyle(
                color: _darkColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: _isDeleting
                ? null
                : _selectAll,
            child: Text(
              allSelected
                  ? 'Batal Semua'
                  : 'Pilih Semua',
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed:
                _selectedIds.isEmpty ||
                        _isDeleting
                    ? null
                    : _confirmDeleteSelected,
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : const Icon(
                    Icons.delete_outline_rounded,
                  ),
            color: Colors.red,
            tooltip: 'Hapus Terpilih',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    Map<String, dynamic> prediction,
    Color statusColor,
    int index,
  ) {
    final id = _getPredictionId(
      prediction,
    );

    final isSelected =
        _selectedIds.contains(id);

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: isSelected
            ? const Color(0xFFEFF6FF)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? _primaryColor
              : Colors.grey.shade200,
          width:
              isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (_isSelectMode)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    right: 10,
                  ),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: _isDeleting
                        ? null
                        : (_) {
                            _toggleSelection(
                              id,
                            );
                          },
                    activeColor:
                        _primaryColor,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        5,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: statusColor
                      .withOpacity(0.1),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(
                    statusColor,
                  ),
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Prediksi #${_history.length - index}',
                            style:
                                const TextStyle(
                              color:
                                  _secondaryTextColor,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          _getTime(
                            prediction,
                          ),
                          style:
                              const TextStyle(
                            color:
                                _secondaryTextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      _getStatus(
                        prediction,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                        color: statusColor,
                      ),
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!_isSelectMode)
                IconButton(
                  onPressed: _isDeleting
                      ? null
                      : () {
                          _confirmDeleteSingle(
                            prediction,
                          );
                        },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 21,
                  ),
                  color: Colors.red,
                  tooltip: 'Hapus',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF8F9FA),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Probabilitas',
                        style:
                            TextStyle(
                          color:
                              _secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _getProbability(
                          prediction,
                        ),
                        style:
                            TextStyle(
                          color:
                              statusColor,
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color:
                      Colors.grey.shade200,
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tanggal Prediksi',
                        style:
                            TextStyle(
                          color:
                              _secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _getDate(
                          prediction,
                        ),
                        style:
                            const TextStyle(
                          color:
                              _darkColor,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
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