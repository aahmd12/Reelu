import '../core/constants/dbsupabase.dart';
import '../models/academicrecord.dart';

class AcademicService {

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

  Future<void> deleteAcademicRecord(String id) async {
    await supabase.from('academic_records').delete().eq('id', id);
  }
}