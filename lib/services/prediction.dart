import '../models/academicrecord.dart';

class PredictionService {
  Map<String, dynamic> predictGraduation(List<AcademicRecord> records) {
    if (records.isEmpty) {
      return {
        'status': 'Belum Ada Data',
        'recommendation': 'Silakan masukkan data akademik Anda terlebih dahulu.',
        'percentage': 0,
      };
    }

    final latestRecord = records.last;
    final double latestIpk = latestRecord.ipk;
    final int totalSks = latestRecord.totalSks;

    if (latestIpk >= 3.5 && totalSks >= 120) {
      return {
        'status': 'Sangat Berpeluang Lulus Tepat Waktu (Cumlaude)',
        'recommendation': 'Pertahankan performa akademis kamu dan mulai persiapkan topik skripsi/TA.',
        'percentage': 95,
      };
    } else if (latestIpk >= 3.0) {
      return {
        'status': 'Berpeluang Lulus Tepat Waktu',
        'recommendation': 'Pertahankan IPK dan pastikan pengambilan SKS memenuhi syarat kelulusan.',
        'percentage': 80,
      };
    } else if (latestIpk >= 2.5) {
      return {
        'status': 'Perlu Peningkatan',
        'recommendation': 'Tingkatkan nilai mata kuliah remedial/perbaikan agar IPK meningkat.',
        'percentage': 60,
      };
    } else {
      return {
        'status': 'Bisa Terhambat (Bisa Berisiko Keterlambatan)',
        'recommendation': 'Segera konsultasikan rencana studi kamu ke Dosen Pembimbing Akademik.',
        'percentage': 35,
      };
    }
  }
}