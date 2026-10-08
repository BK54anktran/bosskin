/// Trạng thái một kỳ công (tháng theo ngày chốt công của công ty).
class AttendancePeriod {
  final int year;
  final int month;
  final DateTime from;
  final DateTime to;
  final bool locked;
  final DateTime? lockedAt;
  final DateTime? unlockedAt;
  final String? unlockReason;

  const AttendancePeriod({
    required this.year,
    required this.month,
    required this.from,
    required this.to,
    required this.locked,
    this.lockedAt,
    this.unlockedAt,
    this.unlockReason,
  });

  factory AttendancePeriod.fromJson(Map<String, dynamic> j) => AttendancePeriod(
        year: j['year'] as int,
        month: j['month'] as int,
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        locked: j['locked'] as bool? ?? false,
        lockedAt: j['lockedAt'] != null ? DateTime.parse(j['lockedAt'] as String) : null,
        unlockedAt: j['unlockedAt'] != null ? DateTime.parse(j['unlockedAt'] as String) : null,
        unlockReason: j['unlockReason'] as String?,
      );
}
