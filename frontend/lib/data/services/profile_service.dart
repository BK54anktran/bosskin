import 'package:dio/dio.dart';
import 'api_service.dart';

/// Profile của user hiện tại
class ProfileData {
  final int id;
  final String employeeCode;
  final String fullName;
  final String workEmail;
  final String? personalEmail;
  final String? phone;
  final String? avatar;
  final String gender;
  final String? dateOfBirth;
  final String? joinDate;
  final String departmentName;
  final String positionName;
  final String status;
  final bool canEdit;

  const ProfileData({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.workEmail,
    this.personalEmail,
    this.phone,
    this.avatar,
    required this.gender,
    this.dateOfBirth,
    this.joinDate,
    required this.departmentName,
    required this.positionName,
    required this.status,
    required this.canEdit,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) => ProfileData(
        id: j['id'] as int,
        employeeCode: j['employeeCode'] as String,
        fullName: j['fullName'] as String,
        workEmail: j['workEmail'] as String,
        personalEmail: j['personalEmail'] as String?,
        phone: j['phone'] as String?,
        avatar: j['avatar'] as String?,
        gender: j['gender'] as String? ?? 'MALE',
        dateOfBirth: j['dateOfBirth'] as String?,
        joinDate: j['joinDate'] as String?,
        departmentName: j['departmentName'] as String? ?? '',
        // Chức vụ là tuỳ chọn — NV chưa có chức vụ thì BE trả null (trước đây làm hỏng màn hồ sơ)
        positionName: j['positionName'] as String? ?? '',
        status: j['status'] as String? ?? 'ACTIVE',
        canEdit: j['canEdit'] as bool? ?? false,
      );
}

/// Yêu cầu chỉnh sửa thông tin
class EditRequest {
  final int id;
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final int? departmentId;
  final String departmentName;
  final String? currentFullName;
  final String? currentGender;
  final String? currentDateOfBirth;
  final String? currentPhone;
  final String? currentPersonalEmail;
  final String? requestedFullName;
  final String? requestedGender;
  final String? requestedDateOfBirth;
  final String? requestedPhone;
  final String? requestedPersonalEmail;
  final String status;
  final String? adminNote;
  final String? createdAt;

  const EditRequest({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentId,
    required this.departmentName,
    this.currentFullName,
    this.currentGender,
    this.currentDateOfBirth,
    this.currentPhone,
    this.currentPersonalEmail,
    this.requestedFullName,
    this.requestedGender,
    this.requestedDateOfBirth,
    this.requestedPhone,
    this.requestedPersonalEmail,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory EditRequest.fromJson(Map<String, dynamic> j) => EditRequest(
        id: j['id'] as int,
        employeeId: j['employeeId'] as int,
        employeeCode: j['employeeCode'] as String,
        employeeName: j['employeeName'] as String,
        departmentId: (j['departmentId'] as num?)?.toInt(),
        departmentName: j['departmentName'] as String? ?? '',
        currentFullName: j['currentFullName'] as String?,
        currentGender: j['currentGender'] as String?,
        currentDateOfBirth: j['currentDateOfBirth'] as String?,
        currentPhone: j['currentPhone'] as String?,
        currentPersonalEmail: j['currentPersonalEmail'] as String?,
        requestedFullName: j['requestedFullName'] as String?,
        requestedGender: j['requestedGender'] as String?,
        requestedDateOfBirth: j['requestedDateOfBirth'] as String?,
        requestedPhone: j['requestedPhone'] as String?,
        requestedPersonalEmail: j['requestedPersonalEmail'] as String?,
        status: j['status'] as String,
        adminNote: j['adminNote'] as String?,
        createdAt: j['createdAt'] as String?,
      );
}

class ProfileService {
  static final ProfileService instance = ProfileService._();
  ProfileService._();

  Dio get _dio => ApiService.instance.dio;

  Future<ProfileData> getMyProfile() async {
    final res = await _dio.get('/profile');
    return ProfileData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProfileData> adminUpdateProfile({
    String? fullName,
    String? gender,
    String? dateOfBirth,
    String? phone,
    String? personalEmail,
    String? avatar,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null)      body['fullName']      = fullName;
    if (gender != null)        body['gender']        = gender;
    if (dateOfBirth != null)   body['dateOfBirth']   = dateOfBirth;
    if (phone != null)         body['phone']         = phone;
    if (personalEmail != null) body['personalEmail'] = personalEmail;
    if (avatar != null)        body['avatar']        = avatar;

    final res = await _dio.put('/profile', data: body);
    return ProfileData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProfileData> updateAvatar(String avatarUrl) async {
    final res = await _dio.patch('/profile/avatar',
        data: {'avatarUrl': avatarUrl});
    return ProfileData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _dio.patch(
      '/profile/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<EditRequest> submitEditRequest({
    String? fullName,
    String? gender,
    String? dateOfBirth,
    String? phone,
    String? personalEmail,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null)      body['fullName']      = fullName;
    if (gender != null)        body['gender']        = gender;
    if (dateOfBirth != null)   body['dateOfBirth']   = dateOfBirth;
    if (phone != null)         body['phone']         = phone;
    if (personalEmail != null) body['personalEmail'] = personalEmail;

    final res = await _dio.post('/profile/edit-requests', data: body);
    return EditRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<EditRequest>> getEditRequests({String? status, int? departmentId}) async {
    final res = await _dio.get('/profile/edit-requests',
        queryParameters: {
          if (status != null) 'status': status,
          if (departmentId != null) 'departmentId': departmentId,
        });
    return (res.data as List)
        .map((e) => EditRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getPendingCount() async {
    try {
      final res = await _dio.get('/profile/edit-requests/pending-count');
      return (res.data['count'] as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  Future<EditRequest> approveRequest(int id) async {
    final res = await _dio.put('/profile/edit-requests/$id/approve');
    return EditRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EditRequest> rejectRequest(int id, {String? note}) async {
    final res = await _dio.put('/profile/edit-requests/$id/reject',
        data: {'adminNote': note});
    return EditRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateNotificationSettings({
    required String? fcmToken,
    required int? shiftReminderMinutes,
    int? checkInOutNotifMinutes,
  }) async {
    await _dio.patch('/profile/notification-settings', data: {
      'fcmToken': fcmToken,
      'shiftReminderMinutes': shiftReminderMinutes,
      'checkInOutNotifMinutes': checkInOutNotifMinutes,
    });
  }

  /// Gửi một thông báo thử tới thiết bị đang gắn với tài khoản (token backend đã lưu).
  Future<void> sendTestNotification({required String title, required String body}) async {
    await _dio.post('/profile/notification-settings/test', data: {'title': title, 'body': body});
  }

  Future<NotificationSettings> getNotificationSettings() async {
    final res = await _dio.get('/profile/notification-settings');
    return NotificationSettings.fromJson(res.data as Map<String, dynamic>);
  }
}

class NotificationSettings {
  final bool enabled;
  final int? shiftReminderMinutes;
  final int? checkInOutNotifMinutes;

  const NotificationSettings({
    required this.enabled,
    this.shiftReminderMinutes,
    this.checkInOutNotifMinutes,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        enabled: j['enabled'] as bool? ?? false,
        shiftReminderMinutes: (j['shiftReminderMinutes'] as num?)?.toInt(),
        checkInOutNotifMinutes: (j['checkInOutNotifMinutes'] as num?)?.toInt(),
      );
}
