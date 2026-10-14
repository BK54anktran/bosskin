/// Kiểm tra khung đăng ký lịch phía giao diện (cùng quy tắc với ShiftRegistrationService ở backend):
/// ≤ 2 khung / ngày, "rảnh cả ngày" đứng một mình, khung không chồng giờ, kết thúc trước bắt đầu = qua đêm.
const int maxRegSlotsPerDay = 2;

/// "HH:mm" → phút trong ngày; sai định dạng → null.
int? regTimeToMinutes(String? hhmm) {
  if (hhmm == null) return null;
  final p = hhmm.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

String regMinutesToTime(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// Độ dài khung (phút); kết thúc ≤ bắt đầu = qua đêm.
int regSlotMinutes(String start, String end) {
  final a = regTimeToMinutes(start) ?? 0;
  final b = regTimeToMinutes(end) ?? 0;
  final d = b - a;
  return d <= 0 ? d + 24 * 60 : d;
}

bool regSlotsOverlap(String s1, String e1, String s2, String e2) {
  final a1 = regTimeToMinutes(s1) ?? 0, b1 = a1 + regSlotMinutes(s1, e1);
  final a2 = regTimeToMinutes(s2) ?? 0, b2 = a2 + regSlotMinutes(s2, e2);
  return a1 < b2 && a2 < b1;
}

enum RegDayProblem { tooMany, anyAlone, overlap, invalidTime }

/// Một khung để kiểm tra: any = rảnh cả ngày (không có giờ).
typedef RegDaySlot = ({bool any, String? start, String? end});

RegDayProblem? validateRegDay(List<RegDaySlot> slots) {
  if (slots.length > maxRegSlotsPerDay) return RegDayProblem.tooMany;
  if (slots.length > 1 && slots.any((x) => x.any)) return RegDayProblem.anyAlone;
  for (final x in slots) {
    if (x.any) continue;
    final a = regTimeToMinutes(x.start), b = regTimeToMinutes(x.end);
    if (a == null || b == null || a == b) return RegDayProblem.invalidTime;
  }
  for (var i = 0; i < slots.length; i++) {
    for (var j = i + 1; j < slots.length; j++) {
      final a = slots[i], b = slots[j];
      if (a.any || b.any) continue;
      if (regSlotsOverlap(a.start!, a.end!, b.start!, b.end!)) return RegDayProblem.overlap;
    }
  }
  return null;
}

/// Giờ dạng "6" / "7,5" để hiện tổng giờ.
String formatRegHours(int minutes) {
  final h = minutes / 60;
  return h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1).replaceAll('.', ',');
}
