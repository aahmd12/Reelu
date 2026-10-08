import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/dbsupabase.dart';
import 'informationprofile.dart';
import 'editpassword.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  String _name = 'Pengguna';
  String _email = '';
  String _initial = 'P';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      String displayName = '';
      String email = user.email ?? '';

      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name, email')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          displayName =
              profile['full_name']?.toString().trim() ?? '';

          final profileEmail =
              profile['email']?.toString().trim() ?? '';

          if (profileEmail.isNotEmpty) {
            email = profileEmail;
          }
        }
      } catch (e) {
        debugPrint(
          'Gagal mengambil data profiles: $e',
        );
      }

      if (displayName.isEmpty) {
        final metadata = user.userMetadata;

        displayName =
            metadata?['full_name']?.toString().trim() ??
            metadata?['name']?.toString().trim() ??
            '';
      }

      if (displayName.isEmpty) {
        if (email.isNotEmpty) {
          displayName = email.split('@').first;
        } else {
          displayName = 'Pengguna';
        }
      }

      if (!mounted) return;

      setState(() {
        _name = displayName;
        _email = email;
        _initial = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'P';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Gagal mengambil data profile: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Keluar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Apakah kamu yakin ingin keluar dari akun?',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Keluar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal keluar dari akun.',
        isError: true,
      );
    }
  }

  void _showAppearanceComingSoon() {
    _showMessage(
      'Fitur Mode Tampilan masih dalam tahap pengembangan.',
    );
  }

  Future<void> _openInformationProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const InformationProfileScreen(),
      ),
    );

    if (!mounted) return;

    await _loadProfile();
  }

  Future<void> _openEditPassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const EditPasswordScreen(),
      ),
    );
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
          duration: const Duration(
            seconds: 3,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                  strokeWidth: 2.5,
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF2563EB),
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
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
                          const Text(
                            'Profil',
                            style: TextStyle(
                              color: Color(0xFF202124),
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildProfileHeader(),
                          const SizedBox(height: 26),
                          _buildAccountSection(),
                          const SizedBox(height: 26),
                          _buildOtherSection(),
                          const SizedBox(height: 26),
                          _buildLogoutButton(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0FE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initial,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 17),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF202124),
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            _email.isNotEmpty
                ? _email
                : 'Email belum tersedia',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return _buildSection(
      title: 'Akun',
      children: [
        _buildMenuItem(
          icon: Icons.person_outline_rounded,
          title: 'Informasi Profil',
          subtitle: 'Lihat informasi mahasiswa',
          onTap: () => _openInformationProfile(),
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.lock_outline_rounded,
          title: 'Ubah Password',
          subtitle: 'Perbarui password akun',
          onTap: () => _openEditPassword(),
        ),
      ],
    );
  }

  Widget _buildOtherSection() {
    return _buildSection(
      title: 'Lainnya',
      children: [
        _buildMenuItem(
          icon: Icons.palette_outlined,
          title: 'Mode Tampilan',
          subtitle: 'Atur tampilan aplikasi',
          onTap: _showAppearanceComingSoon,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.info_outline_rounded,
          title: 'Tentang Aplikasi',
          subtitle: 'Informasi tentang Reelu',
          onTap: _showAboutDialog,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: 11,
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius:
                      BorderRadius.circular(14),
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
                      title,
                      style: const TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 80,
      endIndent: 16,
      color: Color(0xFFE5E7EB),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(
          Icons.logout_rounded,
          size: 19,
        ),
        label: const Text(
          'Keluar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              const Color(0xFFDC2626),
          side: const BorderSide(
            color: Color(0xFFFCA5A5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            8,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          title: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.school_rounded,
                  size: 32,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reelu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202124),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '1.0.0',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: const Text(
            'Aplikasi prediksi kelulusan mahasiswa '
            'berbasis data akademik.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                showLicensePage(
                  context: context,
                  applicationName: 'Reelu',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.school_rounded,
                    size: 40,
                    color: Color(0xFF2563EB),
                  ),
                );
              },
              child: const Text(
                'Tampilkan lisensi',
                style: TextStyle(
                  color: Color(0xFF336699),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Keluar',
                style: TextStyle(
                  color: Color(0xFF336699),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}