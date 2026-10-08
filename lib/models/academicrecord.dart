class AcademicRecord {
  final String? id;
  final String userId;
  final int semester;
  final double ips;
  final double ipk;
  final int totalSks;
  final int targetSks;

  AcademicRecord({
    this.id,
    required this.userId,
    required this.semester,
    required this.ips,
    required this.ipk,
    required this.totalSks,
    required this.targetSks,
  });

  factory AcademicRecord.fromJson(Map<String, dynamic> json) {
    return AcademicRecord(
      id: json['id']?.toString(),
      userId: json['user_id'] ?? '',
      semester: json['semester'] ?? 1,
      ips: (json['ips'] as num?)?.toDouble() ?? 0.0,
      ipk: (json['ipk'] as num?)?.toDouble() ?? 0.0,
      totalSks: json['total_sks'] ?? 0,
      targetSks: json['target_sks'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'semester': semester,
      'ips': ips,
      'ipk': ipk,
      'total_sks': totalSks,
      'target_sks': targetSks,
    };
  }
}