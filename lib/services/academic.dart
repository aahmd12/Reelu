import '../core/constants/dbsupabase.dart';
import '../models/academicrecord.dart';

class AcademicService {
  /// Mengambil daftar riwayat akademik pengguna berdasarkan user_id
  Future<List<AcademicRecord>> getAcademicRecords(String userId) async {
    final response = await supabase
        .from('academic_records')
        .select()
        .eq('user_id', userId)
        .order('semester', ascending: true);

    return (response as List)
        .map((record) => AcademicRecord.fromJson(record))
        .toList();
  }

  /// Mengambil catatan akademik terbaru/terakhir milik pengguna
  Future<AcademicRecord?> getLatestAcademicRecord(String userId) async {
    final response = await supabase
        .from('academic_records')
        .select()
        .eq('user_id', userId)
        .order('semester', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return AcademicRecord.fromJson(response);
  }

  /// Menyimpan data (Insert baru jika ID kosong, atau Update jika ID ada)
  Future<void> saveAcademicRecord(AcademicRecord record) async {
    if (record.id != null && record.id!.isNotEmpty) {
      await supabase
          .from('academic_records')
          .update(record.toJson())
          .eq('id', record.id!);
    } else {
      await supabase.from('academic_records').insert(record.toJson());
    }
  }

  /// Menghapus data akademik berdasarkan ID
  Future<void> deleteAcademicRecord(String id) async {
    await supabase.from('academic_records').delete().eq('id', id);
  }
}