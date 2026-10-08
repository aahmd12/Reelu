import 'package:flutter/material.dart';

class TargetScreen extends StatelessWidget {
  const TargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16.0,
                12.0,
                16.0,
                65.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(
                      top: 8,
                    ),
                    child: Text(
                      'Target Kelulusan',
                      style: TextStyle(
                        color: Color(0xFF102A63),
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tentukan target kelulusan berdasarkan perkembangan akademikmu.',
                    style: TextStyle(
                      color: Color(0xFF7B91B5),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFFE0EAF6),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Maaf sedang dalam tahap pengembang',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF102A63),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
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