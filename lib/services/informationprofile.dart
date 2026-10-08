import 'package:flutter/material.dart';

import '../core/constants/dbsupabase.dart';
import 'editdata.dart';

class InformationProfileScreen extends StatefulWidget {
  const InformationProfileScreen({super.key});

  @override
  State<InformationProfileScreen> createState() =>
      _InformationProfileScreenState();
}

class _InformationProfileScreenState
    extends State<InformationProfileScreen> {
  bool _isLoading = true;

  String _fullName = '-';
  String _email = '-';
  String _nim = '-';
  String _prodi = '-';
  String _univ = '-';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Sesi akun tidak ditemukan. Silakan login kembali.',
        isError: true,
      );

      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select(
            'id, email, full_name, nim, prodi, univ, created_at',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        setState(() {
          final fullName =
              response['full_name']?.toString().trim() ?? '';
          final email =
              response['email']?.toString().trim() ?? '';
          final nim =
              response['nim']?.toString().trim() ?? '';
          final prodi =
              response['prodi']?.toString().trim() ?? '';
          final univ =
              response['univ']?.toString().trim() ?? '';

          _fullName =
              fullName.isNotEmpty ? fullName : '-';

          _email = email.isNotEmpty
              ? email
              : (user.email ?? '-');

          _nim = nim.isNotEmpty ? nim : '-';
          _prodi = prodi.isNotEmpty ? prodi : '-';
          _univ = univ.isNotEmpty ? univ : '-';

          _isLoading = false;
        });
      } else {
        setState(() {
          _email = user.email ?? '-';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Gagal mengambil informasi profil.',
        isError: true,
      );
    }
  }

  Future<void> _openEditData() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditDataScreen(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await _loadProfile();
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
              : const Color(0xFF16A34A),
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

  Widget _buildInformationItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF2563EB),
        strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16.0,
        12.0,
        16.0,
        65.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 380,
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 55,
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Data Profil Belum Tersedia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Informasi profil mahasiswa belum ditemukan. '
                  'Silakan tambahkan atau periksa kembali '
                  'data profil kamu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _openEditData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 25,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      'Tambah Data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8.0,
        bottom: 20.0,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.pop(context);
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              color: Colors.black87,
              size: 28,
            ),
            SizedBox(width: 20),
            Text(
              'Informasi Profil',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData =
        _fullName != '-' ||
        _email != '-' ||
        _nim != '-' ||
        _prodi != '-' ||
        _univ != '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : !hasData
                ? Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16.0,
                          10.0,
                          16.0,
                          0.0,
                        ),
                        child: _buildHeader(),
                      ),
                      Expanded(
                        child: _buildEmptyState(),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16.0,
                      10.0,
                      16.0,
                      65.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 380,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFEFF6FF),
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                                border: Border.all(
                                  color:
                                      const Color(
                                    0xFFBFDBFE,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons
                                        .info_outline_rounded,
                                    color:
                                        Color(0xFF2563EB),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Pastikan informasi profil kamu '
                                      'sudah sesuai agar data akademik '
                                      'dapat digunakan dengan benar.',
                                      style: TextStyle(
                                        color:
                                            Color(0xFF1E40AF),
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Data Mahasiswa',
                              style: TextStyle(
                                color:
                                    Color(0xFF111827),
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInformationItem(
                              icon: Icons
                                  .person_outline_rounded,
                              label: 'Nama Lengkap',
                              value: _fullName,
                            ),
                            const SizedBox(height: 12),
                            _buildInformationItem(
                              icon:
                                  Icons.email_outlined,
                              label: 'Email',
                              value: _email,
                            ),
                            const SizedBox(height: 12),
                            _buildInformationItem(
                              icon:
                                  Icons.badge_outlined,
                              label: 'NIM',
                              value: _nim,
                            ),
                            const SizedBox(height: 12),
                            _buildInformationItem(
                              icon:
                                  Icons.school_outlined,
                              label: 'Program Studi',
                              value: _prodi,
                            ),
                            const SizedBox(height: 12),
                            _buildInformationItem(
                              icon: Icons
                                  .account_balance_outlined,
                              label: 'Universitas',
                              value: _univ,
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child:
                                  ElevatedButton.icon(
                                onPressed:
                                    _openEditData,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 19,
                                ),
                                label: const Text(
                                  'Edit Data',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  backgroundColor:
                                      const Color(
                                    0xFF2563EB,
                                  ),
                                  foregroundColor:
                                      Colors.white,
                                  elevation: 0,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
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
}