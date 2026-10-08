import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard.dart';
import 'screens/prediction/prediction.dart';
import 'services/statistik.dart';
import 'services/target.dart';
import 'services/rekomendasi.dart';
import 'services/profile.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({
    super.key,
  });

  @override
  State<BottomNavigation> createState() =>
      _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  static const Color _backgroundColor = Color(0xFFF6FAFF);

  static const Color _primaryColor = Color(0xFF2563EB);

  static const Color _inactiveColor = Color(0xFF8298BB);

  static const Color _activeBackgroundColor = Color(0xFFEAF3FF);

  static const double _navigationHeight = 76;

  static const double _navigationHorizontalMargin = 12;

  static const double _navigationBottomMargin = 16;

  static const double _contentBottomSpace = 108;

  @override
  void initState() {
    super.initState();

    _pages = [
      DashboardScreen(
        onNavigateTab: _onNavigateTab,
      ),
      const PredictionScreen(),
      const StatistikScreen(),
      const TargetScreen(),
      ProfileScreen(),
    ];
  }

  void _onNavigateTab(int index) {
    if (!mounted) {
      return;
    }

    if (index < 0 || index >= _pages.length) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        top: true,
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: _contentBottomSpace,
                    ),
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _pages,
                    ),
                  ),
                ),

                Positioned(
                  left: _navigationHorizontalMargin,
                  right: _navigationHorizontalMargin,
                  bottom: _navigationBottomMargin,
                  child: _buildBottomNavigation(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: _navigationHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D9BC4).withOpacity(0.16),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Beranda',
              ),

              _buildNavItem(
                index: 1,
                icon: Icons.trending_up_outlined,
                activeIcon: Icons.trending_up_rounded,
                label: 'Prediksi',
              ),

              _buildNavItem(
                index: 2,
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Statistik',
              ),

              _buildNavItem(
                index: 3,
                icon: Icons.track_changes_outlined,
                activeIcon: Icons.track_changes_rounded,
                label: 'Target',
              ),

              _buildNavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            _onNavigateTab(index);
          },
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: isActive ? 46 : 38,
                  height: isActive ? 38 : 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _activeBackgroundColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: isActive ? 24 : 23,
                    color: isActive
                        ? _primaryColor
                        : _inactiveColor,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isActive
                        ? _primaryColor
                        : _inactiveColor,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}