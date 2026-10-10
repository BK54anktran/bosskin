/// Bước J — ngày lễ và lịch làm việc tuần.
class Holiday {
  final int? id;
  final DateTime date;
  final String name;
  /// HOLIDAY | COMPENSATORY | SWAP_WORKDAY
  final String type;
  final bool paid;
  /// TEMPLATE (mẫu hệ thống) | COMPANY (công ty tự chỉnh)
  final String source;

  const Holiday({
    this.id,
    required this.date,
    required this.name,
    required this.type,
    required this.paid,
    this.source = 'COMPANY',
  });

  /// Ngày làm bù không phải ngày nghỉ.
  bool get isDayOff => type != 'SWAP_WORKDAY';

  factory Holiday.fromJson(Map<String, dynamic> j) => Holiday(
        id: (j['id'] as num?)?.toInt(),
        date: DateTime.parse(j['date'] as String),
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'HOLIDAY',
        paid: j['paid'] != false,
        source: j['source'] as String? ?? 'COMPANY',
      );

  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'name': name,
        'type': type,
        'paid': paid,
      };
}

class WorkCalendar {
  /// null = lịch mặc định chưa lưu (FFFFFOO).
  final int? id;
  final String name;
  /// 7 ký tự T2→CN: F cả ngày, H nửa ngày, O nghỉ.
  final String weekPattern;
  final bool isDefault;
  final List<int> departmentIds;

  const WorkCalendar({
    this.id,
    required this.name,
    required this.weekPattern,
    required this.isDefault,
    this.departmentIds = const [],
  });

  factory WorkCalendar.fromJson(Map<String, dynamic> j) => WorkCalendar(
        id: (j['id'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        weekPattern: j['weekPattern'] as String? ?? defaultWeekPattern,
        isDefault: j['isDefault'] == true || j['default'] == true,
        departmentIds: ((j['departmentIds'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}

const defaultWeekPattern = 'FFFFFOO';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Lịch đã giải cho một khoảng ngày (GET /work-calendars/view) — tô màu lưới phân ca / bảng công.
class WorkCalendarView {
  final Map<String, Holiday> holidays;
  final String defaultPattern;
  final Map<int, String> departmentPatterns;

  const WorkCalendarView({
    this.holidays = const {},
    this.defaultPattern = defaultWeekPattern,
    this.departmentPatterns = const {},
  });

  static const empty = WorkCalendarView();

  factory WorkCalendarView.fromJson(Map<String, dynamic> j) {
    final hs = ((j['holidays'] as List?) ?? const [])
        .map((e) => Holiday.fromJson(e as Map<String, dynamic>));
    final dp = <int, String>{};
    ((j['departmentPatterns'] as Map?) ?? const {}).forEach((k, v) {
      final id = int.tryParse(k.toString());
      if (id != null) dp[id] = v.toString();
    });
    return WorkCalendarView(
      holidays: {for (final h in hs) dateKey(h.date): h},
      defaultPattern: j['defaultPattern'] as String? ?? defaultWeekPattern,
      departmentPatterns: dp,
    );
  }

  Holiday? holiday(DateTime d) => holidays[dateKey(d)];

  String patternOf(int? departmentId) =>
      (departmentId != null ? departmentPatterns[departmentId] : null) ?? defaultPattern;

  /// Ngày nghỉ: ngày lễ / nghỉ bù, hoặc ngày O trong lịch tuần (trừ ngày làm bù).
  bool isOff(int? departmentId, DateTime d) {
    final h = holiday(d);
    if (h != null) return h.isDayOff;
    return patternOf(departmentId)[d.weekday - 1] == 'O';
  }
}
