/// Bước M — người phụ thuộc (giảm trừ gia cảnh). Tháng giảm trừ là ngày 01 của tháng.
class Dependent {
  final int id;
  final int employeeId;
  final String fullName;
  final String relationship; // CHILD | SPOUSE | PARENT | OTHER
  final DateTime? dateOfBirth;
  final String? taxCode;
  final String? identityNo;
  final DateTime deductionFrom;
  final DateTime? deductionTo;
  final String registrationStatus; // NOT_REGISTERED | PENDING | REGISTERED
  final String? note;
  final bool activeNow;

  const Dependent({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.relationship,
    this.dateOfBirth,
    this.taxCode,
    this.identityNo,
    required this.deductionFrom,
    this.deductionTo,
    required this.registrationStatus,
    this.note,
    this.activeNow = false,
  });

  factory Dependent.fromJson(Map<String, dynamic> j) => Dependent(
        id: (j['id'] as num).toInt(),
        employeeId: (j['employeeId'] as num).toInt(),
        fullName: j['fullName'] ?? '',
        relationship: j['relationship'] ?? 'OTHER',
        dateOfBirth: j['dateOfBirth'] != null ? DateTime.tryParse(j['dateOfBirth']) : null,
        taxCode: j['taxCode'] as String?,
        identityNo: j['identityNo'] as String?,
        deductionFrom: DateTime.parse(j['deductionFrom']),
        deductionTo: j['deductionTo'] != null ? DateTime.tryParse(j['deductionTo']) : null,
        registrationStatus: j['registrationStatus'] ?? 'PENDING',
        note: j['note'] as String?,
        activeNow: j['activeNow'] == true,
      );
}

const dependentRelationships = ['CHILD', 'SPOUSE', 'PARENT', 'OTHER'];
const dependentStatuses = ['NOT_REGISTERED', 'PENDING', 'REGISTERED'];
