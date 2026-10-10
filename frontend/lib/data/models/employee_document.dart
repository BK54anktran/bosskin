/// Bước N — loại tài liệu nhân sự do công ty cấu hình.
class DocumentType {
  final int id;
  final String code;
  final String name;
  final bool required;
  final bool hasExpiry;
  final int sortOrder;

  const DocumentType({
    required this.id,
    required this.code,
    required this.name,
    this.required = false,
    this.hasExpiry = false,
    this.sortOrder = 0,
  });

  factory DocumentType.fromJson(Map<String, dynamic> j) => DocumentType(
        id: (j['id'] as num).toInt(),
        code: j['code'] ?? '',
        name: j['name'] ?? '',
        required: j['required'] == true,
        hasExpiry: j['hasExpiry'] == true,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

/// Bước N — tài liệu của nhân viên (file riêng tư, xem qua link ký tạm).
class EmployeeDocument {
  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final int typeId;
  final String typeCode;
  final String typeName;
  final String? title;
  final String fileName;
  final String contentType;
  final int fileSize;
  final DateTime? issuedOn;
  final DateTime? expiresOn;
  final int? daysToExpiry;
  final int? contractId;
  final String? contractNo;
  final String status; // PENDING | APPROVED | REJECTED
  final String? reviewNote;
  final String? note;
  final DateTime? createdAt;

  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    required this.typeId,
    required this.typeCode,
    required this.typeName,
    this.title,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    this.issuedOn,
    this.expiresOn,
    this.daysToExpiry,
    this.contractId,
    this.contractNo,
    required this.status,
    this.reviewNote,
    this.note,
    this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isExpired => daysToExpiry != null && daysToExpiry! < 0;

  factory EmployeeDocument.fromJson(Map<String, dynamic> j) => EmployeeDocument(
        id: (j['id'] as num).toInt(),
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'] as String?,
        typeId: (j['typeId'] as num).toInt(),
        typeCode: j['typeCode'] ?? '',
        typeName: j['typeName'] ?? '',
        title: j['title'] as String?,
        fileName: j['fileName'] ?? '',
        contentType: j['contentType'] ?? '',
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        issuedOn: j['issuedOn'] != null ? DateTime.tryParse(j['issuedOn']) : null,
        expiresOn: j['expiresOn'] != null ? DateTime.tryParse(j['expiresOn']) : null,
        daysToExpiry: (j['daysToExpiry'] as num?)?.toInt(),
        contractId: (j['contractId'] as num?)?.toInt(),
        contractNo: j['contractNo'] as String?,
        status: j['status'] ?? 'APPROVED',
        reviewNote: j['reviewNote'] as String?,
        note: j['note'] as String?,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      );
}

/// Nhân viên còn thiếu tài liệu bắt buộc.
class MissingDocuments {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final List<String> missingTypes;

  const MissingDocuments({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    this.missingTypes = const [],
  });

  factory MissingDocuments.fromJson(Map<String, dynamic> j) => MissingDocuments(
        employeeId: (j['employeeId'] as num).toInt(),
        employeeCode: j['employeeCode'] ?? '',
        employeeName: j['employeeName'] ?? '',
        departmentName: j['departmentName'] as String?,
        missingTypes: ((j['missingTypes'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

/// Link ký tạm; [url] bắt đầu bằng "/" là đường dẫn trên chính backend.
class DocumentLink {
  final String url;
  final String fileName;

  const DocumentLink({required this.url, required this.fileName});

  factory DocumentLink.fromJson(Map<String, dynamic> j) =>
      DocumentLink(url: j['url'] ?? '', fileName: j['fileName'] ?? 'document');
}
