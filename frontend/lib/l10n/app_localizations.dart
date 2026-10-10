import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('vi'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In vi, this message translates to:
  /// **'BossKin'**
  String get appName;

  /// No description provided for @menu.
  ///
  /// In vi, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @notifications.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get notifications;

  /// No description provided for @dashboard.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get dashboard;

  /// No description provided for @employees.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get employees;

  /// No description provided for @departments.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get departments;

  /// No description provided for @shifts.
  ///
  /// In vi, this message translates to:
  /// **'Ca làm'**
  String get shifts;

  /// No description provided for @roles.
  ///
  /// In vi, this message translates to:
  /// **'Phân quyền'**
  String get roles;

  /// No description provided for @attendance.
  ///
  /// In vi, this message translates to:
  /// **'Chấm công'**
  String get attendance;

  /// No description provided for @checkInOut.
  ///
  /// In vi, this message translates to:
  /// **'Check-in / Check-out'**
  String get checkInOut;

  /// No description provided for @attendanceRequests.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu chấm công'**
  String get attendanceRequests;

  /// No description provided for @leaves.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ phép'**
  String get leaves;

  /// No description provided for @payroll.
  ///
  /// In vi, this message translates to:
  /// **'Bảng lương'**
  String get payroll;

  /// No description provided for @profile.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân'**
  String get profile;

  /// No description provided for @editRequests.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu chỉnh sửa'**
  String get editRequests;

  /// No description provided for @personalInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân'**
  String get personalInfo;

  /// No description provided for @logout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @vietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @selectLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get selectLanguage;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get close;

  /// No description provided for @loading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải...'**
  String get loading;

  /// No description provided for @sendRequest.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu chỉnh sửa'**
  String get sendRequest;

  /// No description provided for @saveChanges.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get saveChanges;

  /// No description provided for @editInfoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu chỉnh sửa thông tin cá nhân'**
  String get editInfoTitle;

  /// No description provided for @editInfoAdminTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa thông tin cá nhân'**
  String get editInfoAdminTitle;

  /// No description provided for @editInfoSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi sẽ được gửi cho admin duyệt'**
  String get editInfoSubtitle;

  /// No description provided for @workInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin công việc'**
  String get workInfo;

  /// No description provided for @employeeCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã nhân viên'**
  String get employeeCode;

  /// No description provided for @department.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get department;

  /// No description provided for @position.
  ///
  /// In vi, this message translates to:
  /// **'Chức vụ'**
  String get position;

  /// No description provided for @address.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get address;

  /// No description provided for @workEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email công việc'**
  String get workEmail;

  /// No description provided for @joinDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày vào làm'**
  String get joinDate;

  /// No description provided for @fullName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get fullName;

  /// No description provided for @gender.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get genderOther;

  /// No description provided for @dateOfBirth.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get dateOfBirth;

  /// No description provided for @phone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get phone;

  /// No description provided for @personalEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email cá nhân'**
  String get personalEmail;

  /// No description provided for @avatarUrl.
  ///
  /// In vi, this message translates to:
  /// **'URL ảnh đại diện'**
  String get avatarUrl;

  /// No description provided for @updateAvatarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật ảnh đại diện'**
  String get updateAvatarTitle;

  /// No description provided for @avatarUrlLabel.
  ///
  /// In vi, this message translates to:
  /// **'URL ảnh đại diện'**
  String get avatarUrlLabel;

  /// No description provided for @avatarUrlHint.
  ///
  /// In vi, this message translates to:
  /// **'https://...'**
  String get avatarUrlHint;

  /// No description provided for @currentPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu hiện tại'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu mới'**
  String get confirmPassword;

  /// No description provided for @changePassword.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get changePassword;

  /// No description provided for @passwordNote.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới sẽ có hiệu lực cho lần đăng nhập tiếp theo'**
  String get passwordNote;

  /// No description provided for @noChanges.
  ///
  /// In vi, this message translates to:
  /// **'Không có thông tin nào thay đổi'**
  String get noChanges;

  /// No description provided for @chooseDate.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày'**
  String get chooseDate;

  /// No description provided for @dateCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get dateCancel;

  /// No description provided for @dateOk.
  ///
  /// In vi, this message translates to:
  /// **'OK'**
  String get dateOk;

  /// No description provided for @chooseLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get chooseLanguage;

  /// No description provided for @vietnameseShort.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnameseShort;

  /// No description provided for @englishShort.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get englishShort;

  /// No description provided for @user.
  ///
  /// In vi, this message translates to:
  /// **'Người dùng'**
  String get user;

  /// No description provided for @admin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị viên'**
  String get admin;

  /// No description provided for @employee.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get employee;

  /// No description provided for @profileLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải thông tin'**
  String get profileLoadError;

  /// No description provided for @avatarUpdatedSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật ảnh đại diện thành công'**
  String get avatarUpdatedSuccess;

  /// No description provided for @saveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thành công'**
  String get saveSuccess;

  /// No description provided for @requestSentSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu mới, đơn chờ cũ (nếu có) đã được hủy tự động'**
  String get requestSentSuccess;

  /// No description provided for @companyManagementTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý công ty'**
  String get companyManagementTitle;

  /// No description provided for @companyManagementSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý tất cả công ty trên nền tảng BossKin'**
  String get companyManagementSubtitle;

  /// No description provided for @createCompany.
  ///
  /// In vi, this message translates to:
  /// **'Tạo công ty'**
  String get createCompany;

  /// No description provided for @createCompanyNew.
  ///
  /// In vi, this message translates to:
  /// **'Tạo công ty mới'**
  String get createCompanyNew;

  /// No description provided for @companyInfoSection.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin công ty'**
  String get companyInfoSection;

  /// No description provided for @adminAccountSection.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản Admin công ty'**
  String get adminAccountSection;

  /// No description provided for @accountUsedToLoginSystem.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản dùng để đăng nhập vào hệ thống'**
  String get accountUsedToLoginSystem;

  /// No description provided for @companyName.
  ///
  /// In vi, this message translates to:
  /// **'Tên công ty *'**
  String get companyName;

  /// No description provided for @companyCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã công ty * (VD: ACME)'**
  String get companyCode;

  /// No description provided for @companyCodeHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết hoa, không dấu'**
  String get companyCodeHint;

  /// No description provided for @phoneNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get phoneNumber;

  /// No description provided for @domain.
  ///
  /// In vi, this message translates to:
  /// **'Domain'**
  String get domain;

  /// No description provided for @contactEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email liên hệ'**
  String get contactEmail;

  /// No description provided for @adminEmailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Email admin *'**
  String get adminEmailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu *'**
  String get passwordLabel;

  /// No description provided for @invalidEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get invalidEmail;

  /// No description provided for @atLeast6Chars.
  ///
  /// In vi, this message translates to:
  /// **'Ít nhất 6 ký tự'**
  String get atLeast6Chars;

  /// No description provided for @genericError.
  ///
  /// In vi, this message translates to:
  /// **'Đã có lỗi xảy ra'**
  String get genericError;

  /// No description provided for @companyLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải danh sách công ty'**
  String get companyLoadError;

  /// No description provided for @companyLoginError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể đăng nhập vào công ty'**
  String get companyLoginError;

  /// No description provided for @requiredField.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc'**
  String get requiredField;

  /// No description provided for @noCompaniesYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có công ty nào'**
  String get noCompaniesYet;

  /// No description provided for @signIn.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get signIn;

  /// No description provided for @welcomeBack.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng trở lại! Vui lòng đăng nhập.'**
  String get welcomeBack;

  /// No description provided for @serverSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt server'**
  String get serverSettings;

  /// No description provided for @serverAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ server'**
  String get serverAddress;

  /// No description provided for @enterServerAddress.
  ///
  /// In vi, this message translates to:
  /// **'Nhập IP hoặc domain của server:'**
  String get enterServerAddress;

  /// No description provided for @serverHint.
  ///
  /// In vi, this message translates to:
  /// **'http://192.168.x.x:8080'**
  String get serverHint;

  /// No description provided for @loginFailed.
  ///
  /// In vi, this message translates to:
  /// **'Email hoặc mật khẩu không đúng'**
  String get loginFailed;

  /// No description provided for @loginCompanyInactive.
  ///
  /// In vi, this message translates to:
  /// **'Công ty đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.'**
  String get loginCompanyInactive;

  /// No description provided for @impersonatingCompanyNotice.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang đăng nhập với vai trò quản trị viên hệ thống.\nMàn hình này chỉ dành cho nhân viên của công ty.'**
  String get impersonatingCompanyNotice;

  /// No description provided for @passwordMinLength.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu ít nhất 6 ký tự'**
  String get passwordMinLength;

  /// No description provided for @todayAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Chấm công hôm nay'**
  String get todayAttendance;

  /// No description provided for @viewAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get viewAll;

  /// No description provided for @recentPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Bảng lương gần đây'**
  String get recentPayroll;

  /// No description provided for @viewDetails.
  ///
  /// In vi, this message translates to:
  /// **'Xem chi tiết'**
  String get viewDetails;

  /// No description provided for @totalSalary.
  ///
  /// In vi, this message translates to:
  /// **'Tổng chi lương'**
  String get totalSalary;

  /// No description provided for @employeeCount.
  ///
  /// In vi, this message translates to:
  /// **'Số nhân viên'**
  String get employeeCount;

  /// No description provided for @paidStatus.
  ///
  /// In vi, this message translates to:
  /// **'Đã thanh toán'**
  String get paidStatus;

  /// No description provided for @present.
  ///
  /// In vi, this message translates to:
  /// **'Có mặt'**
  String get present;

  /// No description provided for @leave.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ phép'**
  String get leave;

  /// No description provided for @absent.
  ///
  /// In vi, this message translates to:
  /// **'Vắng mặt'**
  String get absent;

  /// No description provided for @late.
  ///
  /// In vi, this message translates to:
  /// **'Đi muộn'**
  String get late;

  /// No description provided for @onTime.
  ///
  /// In vi, this message translates to:
  /// **'Đúng giờ'**
  String get onTime;

  /// No description provided for @workStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get workStatus;

  /// No description provided for @earlyIn.
  ///
  /// In vi, this message translates to:
  /// **'Vào sớm'**
  String get earlyIn;

  /// No description provided for @lateIn.
  ///
  /// In vi, this message translates to:
  /// **'Vào muộn'**
  String get lateIn;

  /// No description provided for @earlyOut.
  ///
  /// In vi, this message translates to:
  /// **'Về sớm'**
  String get earlyOut;

  /// No description provided for @lateOut.
  ///
  /// In vi, this message translates to:
  /// **'Về muộn'**
  String get lateOut;

  /// No description provided for @overtime.
  ///
  /// In vi, this message translates to:
  /// **'Tăng ca'**
  String get overtime;

  /// No description provided for @statistics.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê'**
  String get statistics;

  /// No description provided for @email.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @adminLoginTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập quản trị'**
  String get adminLoginTitle;

  /// No description provided for @systemAdministrator.
  ///
  /// In vi, this message translates to:
  /// **'SYSTEM ADMINISTRATOR'**
  String get systemAdministrator;

  /// No description provided for @adminLoginSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ dành cho quản trị viên hệ thống BossKin.'**
  String get adminLoginSubtitle;

  /// No description provided for @backToCompanyLogin.
  ///
  /// In vi, this message translates to:
  /// **'← Quay lại đăng nhập công ty'**
  String get backToCompanyLogin;

  /// No description provided for @loadRequestsError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải danh sách'**
  String get loadRequestsError;

  /// No description provided for @approveRequestFor.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt yêu cầu của {name}'**
  String approveRequestFor(Object name);

  /// No description provided for @rejectRequestFor.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối yêu cầu của {name}'**
  String rejectRequestFor(Object name);

  /// No description provided for @rejectRequestTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối yêu cầu của {name}'**
  String rejectRequestTitle(Object name);

  /// No description provided for @rejectionReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lý do từ chối'**
  String get rejectionReasonLabel;

  /// No description provided for @enterReason.
  ///
  /// In vi, this message translates to:
  /// **'Nhập lý do...'**
  String get enterReason;

  /// No description provided for @noPendingRequests.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu nào đang chờ'**
  String get noPendingRequests;

  /// No description provided for @noProcessedRequests.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu nào được xử lý'**
  String get noProcessedRequests;

  /// No description provided for @chooseTime.
  ///
  /// In vi, this message translates to:
  /// **'Chọn giờ'**
  String get chooseTime;

  /// No description provided for @shiftAssignmentsTab.
  ///
  /// In vi, this message translates to:
  /// **'Phân công ca'**
  String get shiftAssignmentsTab;

  /// No description provided for @shiftListTab.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách ca'**
  String get shiftListTab;

  /// No description provided for @createShiftTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo ca làm mới'**
  String get createShiftTitle;

  /// No description provided for @editShiftTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ca làm'**
  String get editShiftTitle;

  /// No description provided for @createShift.
  ///
  /// In vi, this message translates to:
  /// **'Tạo ca mới'**
  String get createShift;

  /// No description provided for @deleteShiftAssignmentWarning.
  ///
  /// In vi, this message translates to:
  /// **'Ca này có thể đã có dữ liệu chấm công và yêu cầu sửa giờ liên quan. Xóa ca sẽ xóa toàn bộ dữ liệu đó. Bạn có chắc muốn xóa?'**
  String get deleteShiftAssignmentWarning;

  /// No description provided for @deleteShiftTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa ca làm'**
  String get deleteShiftTitle;

  /// No description provided for @deleteShiftPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Xóa ca \"{name}\"?'**
  String deleteShiftPrompt(Object name);

  /// No description provided for @shiftNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên ca *'**
  String get shiftNameLabel;

  /// No description provided for @shiftNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên ca'**
  String get shiftNameRequired;

  /// No description provided for @enterShiftName.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên ca'**
  String get enterShiftName;

  /// No description provided for @shiftCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã ca *'**
  String get shiftCodeLabel;

  /// No description provided for @shiftCodeRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã ca'**
  String get shiftCodeRequired;

  /// No description provided for @enterShiftCode.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã ca'**
  String get enterShiftCode;

  /// No description provided for @shiftTypeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Loại ca'**
  String get shiftTypeLabel;

  /// No description provided for @shiftStartLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giờ bắt đầu'**
  String get shiftStartLabel;

  /// No description provided for @shiftEndLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giờ kết thúc'**
  String get shiftEndLabel;

  /// No description provided for @shiftBreakStartLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ giải lao từ'**
  String get shiftBreakStartLabel;

  /// No description provided for @shiftBreakEndLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ giải lao đến'**
  String get shiftBreakEndLabel;

  /// No description provided for @displayColor.
  ///
  /// In vi, this message translates to:
  /// **'Màu hiển thị'**
  String get displayColor;

  /// No description provided for @applyToDepartments.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng cho phòng ban'**
  String get applyToDepartments;

  /// No description provided for @noDepartments.
  ///
  /// In vi, this message translates to:
  /// **'Không có phòng ban'**
  String get noDepartments;

  /// No description provided for @workingHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ làm'**
  String get workingHours;

  /// No description provided for @shiftEditTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Sửa'**
  String get shiftEditTooltip;

  /// No description provided for @shiftDeleteTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get shiftDeleteTooltip;

  /// No description provided for @noShiftsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ca làm nào. Tạo ca mới để bắt đầu.'**
  String get noShiftsYet;

  /// No description provided for @shift.
  ///
  /// In vi, this message translates to:
  /// **'Ca làm'**
  String get shift;

  /// No description provided for @breakTime.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian giải lao'**
  String get breakTime;

  /// No description provided for @totalTime.
  ///
  /// In vi, this message translates to:
  /// **'Tổng thời gian'**
  String get totalTime;

  /// No description provided for @dayHours.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian ngày'**
  String get dayHours;

  /// No description provided for @dayOT.
  ///
  /// In vi, this message translates to:
  /// **'Tăng ca ngày'**
  String get dayOT;

  /// No description provided for @nightHours.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian đêm'**
  String get nightHours;

  /// No description provided for @nightOT.
  ///
  /// In vi, this message translates to:
  /// **'Tăng ca đêm'**
  String get nightOT;

  /// No description provided for @action.
  ///
  /// In vi, this message translates to:
  /// **'Hành động'**
  String get action;

  /// No description provided for @date.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get date;

  /// No description provided for @createdAt.
  ///
  /// In vi, this message translates to:
  /// **'Tạo lúc'**
  String get createdAt;

  /// No description provided for @note.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get note;

  /// No description provided for @response.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi'**
  String get response;

  /// No description provided for @chooseMonth.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tháng'**
  String get chooseMonth;

  /// No description provided for @year.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get year;

  /// No description provided for @month.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get month;

  /// No description provided for @refresh.
  ///
  /// In vi, this message translates to:
  /// **'Làm mới'**
  String get refresh;

  /// No description provided for @edit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get delete;

  /// No description provided for @rowsPerPage.
  ///
  /// In vi, this message translates to:
  /// **'Số hàng / trang'**
  String get rowsPerPage;

  /// No description provided for @previousPage.
  ///
  /// In vi, this message translates to:
  /// **'Trang trước'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In vi, this message translates to:
  /// **'Trang sau'**
  String get nextPage;

  /// No description provided for @departmentShort.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get departmentShort;

  /// No description provided for @all.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get all;

  /// No description provided for @employeeShort.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get employeeShort;

  /// No description provided for @selectEmployeeToViewTimesheet.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nhân viên để xem bảng chấm công'**
  String get selectEmployeeToViewTimesheet;

  /// No description provided for @checkIn.
  ///
  /// In vi, this message translates to:
  /// **'Check-in'**
  String get checkIn;

  /// No description provided for @checkOut.
  ///
  /// In vi, this message translates to:
  /// **'Check-out'**
  String get checkOut;

  /// No description provided for @request.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu'**
  String get request;

  /// No description provided for @extraHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ làm thêm (không OT)'**
  String get extraHours;

  /// No description provided for @extraHoursDayNight.
  ///
  /// In vi, this message translates to:
  /// **'Ngày / đêm'**
  String get extraHoursDayNight;

  /// No description provided for @extraHoursDuration.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng giờ làm thêm'**
  String get extraHoursDuration;

  /// No description provided for @processingBy.
  ///
  /// In vi, this message translates to:
  /// **'Xử lý bởi'**
  String get processingBy;

  /// No description provided for @approvedBy.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt bởi'**
  String get approvedBy;

  /// No description provided for @rejectedBy.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối bởi'**
  String get rejectedBy;

  /// No description provided for @cancelledBy.
  ///
  /// In vi, this message translates to:
  /// **'Hủy bởi'**
  String get cancelledBy;

  /// No description provided for @insideShift.
  ///
  /// In vi, this message translates to:
  /// **'Trong ca'**
  String get insideShift;

  /// No description provided for @outsideShift.
  ///
  /// In vi, this message translates to:
  /// **'Ngoài ca'**
  String get outsideShift;

  /// No description provided for @day.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get day;

  /// No description provided for @night.
  ///
  /// In vi, this message translates to:
  /// **'Đêm'**
  String get night;

  /// No description provided for @unknown.
  ///
  /// In vi, this message translates to:
  /// **'Không rõ'**
  String get unknown;

  /// No description provided for @noAttendanceDataForThisDay.
  ///
  /// In vi, this message translates to:
  /// **'Không có dữ liệu chấm công trong ngày này'**
  String get noAttendanceDataForThisDay;

  /// No description provided for @checkInRequest.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu check-in'**
  String get checkInRequest;

  /// No description provided for @checkOutRequest.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu check-out'**
  String get checkOutRequest;

  /// No description provided for @requestedTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ yêu cầu'**
  String get requestedTime;

  /// No description provided for @status.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get status;

  /// No description provided for @addEmployee.
  ///
  /// In vi, this message translates to:
  /// **'Thêm nhân viên'**
  String get addEmployee;

  /// No description provided for @syncEmployeeAccounts.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ tài khoản'**
  String get syncEmployeeAccounts;

  /// No description provided for @syncEmployeeAccountsDesc.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống sẽ tạo tài khoản cho các nhân viên chưa có user, hoặc nối lại tài khoản cùng email nếu có.'**
  String get syncEmployeeAccountsDesc;

  /// No description provided for @sync.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ'**
  String get sync;

  /// No description provided for @syncEmployeeAccountsSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo {created} tài khoản, nối {linked} tài khoản, bỏ qua {skipped} nhân viên.'**
  String syncEmployeeAccountsSuccess(
      Object created, Object linked, Object skipped);

  /// No description provided for @initialPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu khởi tạo *'**
  String get initialPassword;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu *'**
  String get confirmPasswordLabel;

  /// No description provided for @employeeSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tên, email, mã NV...'**
  String get employeeSearchHint;

  /// No description provided for @noEmployeesFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy nhân viên'**
  String get noEmployeesFound;

  /// No description provided for @employeeDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ việc nhân viên'**
  String get employeeDeleteTitle;

  /// No description provided for @employeeDeletePrompt.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu \"{name}\" là không còn làm việc?'**
  String employeeDeletePrompt(Object name);

  /// No description provided for @employeeStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang làm'**
  String get employeeStatusActive;

  /// No description provided for @employeeStatusInactive.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ việc'**
  String get employeeStatusInactive;

  /// No description provided for @employeeStatusOnLeave.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ phép'**
  String get employeeStatusOnLeave;

  /// No description provided for @chooseTimeRange.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khoảng thời gian'**
  String get chooseTimeRange;

  /// No description provided for @viewRange.
  ///
  /// In vi, this message translates to:
  /// **'Xem theo'**
  String get viewRange;

  /// No description provided for @viewRangePayroll.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ lương'**
  String get viewRangePayroll;

  /// No description provided for @viewRangeWeek.
  ///
  /// In vi, this message translates to:
  /// **'Tuần'**
  String get viewRangeWeek;

  /// No description provided for @viewRangeCustom.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng thời gian'**
  String get viewRangeCustom;

  /// No description provided for @fromDate.
  ///
  /// In vi, this message translates to:
  /// **'Từ ngày'**
  String get fromDate;

  /// No description provided for @toDate.
  ///
  /// In vi, this message translates to:
  /// **'Đến ngày'**
  String get toDate;

  /// No description provided for @parentDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban cha'**
  String get parentDepartment;

  /// No description provided for @noParentDepartment.
  ///
  /// In vi, this message translates to:
  /// **'— Không có (cấp cao nhất) —'**
  String get noParentDepartment;

  /// No description provided for @dayOvertime.
  ///
  /// In vi, this message translates to:
  /// **'Tăng ca ngày'**
  String get dayOvertime;

  /// No description provided for @nightOvertime.
  ///
  /// In vi, this message translates to:
  /// **'Tăng ca đêm'**
  String get nightOvertime;

  /// No description provided for @otTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ OT'**
  String get otTime;

  /// No description provided for @noApprovedRequests.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu đã duyệt'**
  String get noApprovedRequests;

  /// No description provided for @createAttendanceRequestTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo yêu cầu chấm công / OT'**
  String get createAttendanceRequestTitle;

  /// No description provided for @chooseShiftApply.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ca áp dụng'**
  String get chooseShiftApply;

  /// No description provided for @requestType.
  ///
  /// In vi, this message translates to:
  /// **'Loại yêu cầu'**
  String get requestType;

  /// No description provided for @leaveAllDay.
  ///
  /// In vi, this message translates to:
  /// **'Cả ngày'**
  String get leaveAllDay;

  /// No description provided for @search.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên, phòng ban, ghi chú...'**
  String get searchHint;

  /// No description provided for @filterType.
  ///
  /// In vi, this message translates to:
  /// **'Loại'**
  String get filterType;

  /// No description provided for @clearFilters.
  ///
  /// In vi, this message translates to:
  /// **'Xóa lọc'**
  String get clearFilters;

  /// No description provided for @approve.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get approve;

  /// No description provided for @unapprove.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ duyệt'**
  String get unapprove;

  /// No description provided for @selectAll.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tất cả'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chọn tất cả'**
  String get deselectAll;

  /// No description provided for @selectedCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} đã chọn'**
  String selectedCount(int count);

  /// No description provided for @bulkApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt hàng loạt'**
  String get bulkApprove;

  /// No description provided for @bulkUnapprove.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ duyệt hàng loạt'**
  String get bulkUnapprove;

  /// No description provided for @bulkEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hàng loạt'**
  String get bulkEdit;

  /// No description provided for @bulkActionDone.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành {success}/{total}'**
  String bulkActionDone(int success, int total);

  /// No description provided for @dayShifts.
  ///
  /// In vi, this message translates to:
  /// **'Ca làm trong ngày'**
  String get dayShifts;

  /// No description provided for @otDayNight.
  ///
  /// In vi, this message translates to:
  /// **'OT ngày / đêm'**
  String get otDayNight;

  /// No description provided for @otScope.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi OT'**
  String get otScope;

  /// No description provided for @overtimeDuration.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng OT'**
  String get overtimeDuration;

  /// No description provided for @timeFormatHint.
  ///
  /// In vi, this message translates to:
  /// **'HH:mm'**
  String get timeFormatHint;

  /// No description provided for @pleaseChooseShift.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn ca'**
  String get pleaseChooseShift;

  /// No description provided for @pleaseEnterCheckInTime.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập giờ check-in'**
  String get pleaseEnterCheckInTime;

  /// No description provided for @pleaseEnterCheckOutTime.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập giờ check-out'**
  String get pleaseEnterCheckOutTime;

  /// No description provided for @pleaseEnterOvertimeDuration.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập thời lượng OT'**
  String get pleaseEnterOvertimeDuration;

  /// No description provided for @validHhmmFormat.
  ///
  /// In vi, this message translates to:
  /// **'Dạng hợp lệ: HH:mm'**
  String get validHhmmFormat;

  /// No description provided for @requestSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu'**
  String get requestSent;

  /// No description provided for @approved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get rejected;

  /// No description provided for @cancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get cancelled;

  /// No description provided for @rejectRequest.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối yêu cầu'**
  String get rejectRequest;

  /// No description provided for @reason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do'**
  String get reason;

  /// No description provided for @enterRejectionReason.
  ///
  /// In vi, this message translates to:
  /// **'Nhập lý do từ chối'**
  String get enterRejectionReason;

  /// No description provided for @reject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get reject;

  /// No description provided for @durationMustBeHHmm.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng phải ở dạng HH:mm'**
  String get durationMustBeHHmm;

  /// No description provided for @invalidDuration.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng không hợp lệ'**
  String get invalidDuration;

  /// No description provided for @chooseShift.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ca'**
  String get chooseShift;

  /// No description provided for @noShiftsToday.
  ///
  /// In vi, this message translates to:
  /// **'Ngày này chưa được xếp ca'**
  String get noShiftsToday;

  /// No description provided for @attendanceAccountNotLinked.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản chưa được liên kết với nhân viên nào'**
  String get attendanceAccountNotLinked;

  /// No description provided for @attendanceCheckInOutDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Chức năng check-in/out đang tắt'**
  String get attendanceCheckInOutDisabled;

  /// No description provided for @attendanceNoShiftsOnDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày này chưa được xếp ca'**
  String get attendanceNoShiftsOnDate;

  /// No description provided for @loggedInEmployee.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên đang đăng nhập'**
  String get loggedInEmployee;

  /// No description provided for @todayShift.
  ///
  /// In vi, this message translates to:
  /// **'Ca hôm nay'**
  String get todayShift;

  /// No description provided for @checkInSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Check-in thành công'**
  String get checkInSuccess;

  /// No description provided for @checkOutSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Check-out thành công'**
  String get checkOutSuccess;

  /// No description provided for @locationUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được vị trí'**
  String get locationUnavailable;

  /// No description provided for @outsideAllowedZone.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang nằm ngoài khu vực được phép check-in'**
  String get outsideAllowedZone;

  /// No description provided for @locationCheckEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Bật kiểm tra vị trí check-in'**
  String get locationCheckEnabled;

  /// No description provided for @useCurrentLocation.
  ///
  /// In vi, this message translates to:
  /// **'Lấy vị trí hiện tại'**
  String get useCurrentLocation;

  /// No description provided for @latitude.
  ///
  /// In vi, this message translates to:
  /// **'Vĩ độ'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In vi, this message translates to:
  /// **'Kinh độ'**
  String get longitude;

  /// No description provided for @radius.
  ///
  /// In vi, this message translates to:
  /// **'Bán kính'**
  String get radius;

  /// No description provided for @clearLocation.
  ///
  /// In vi, this message translates to:
  /// **'Xóa vị trí'**
  String get clearLocation;

  /// No description provided for @add.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get add;

  /// No description provided for @noLocations.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có vị trí làm việc'**
  String get noLocations;

  /// No description provided for @addLocation.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vị trí'**
  String get addLocation;

  /// No description provided for @editLocation.
  ///
  /// In vi, this message translates to:
  /// **'Sửa vị trí'**
  String get editLocation;

  /// No description provided for @locationName.
  ///
  /// In vi, this message translates to:
  /// **'Tên vị trí'**
  String get locationName;

  /// No description provided for @locationRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn vị trí trên bản đồ'**
  String get locationRequired;

  /// No description provided for @deleteLocationConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xóa vị trí'**
  String get deleteLocationConfirm;

  /// No description provided for @checkInRadius.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí check-in'**
  String get checkInRadius;

  /// No description provided for @checkInTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ vào'**
  String get checkInTime;

  /// No description provided for @checkOutTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ ra'**
  String get checkOutTime;

  /// No description provided for @workedHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ công'**
  String get workedHours;

  /// No description provided for @historyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử chấm công'**
  String get historyTitle;

  /// No description provided for @noHistoryThisMonth.
  ///
  /// In vi, this message translates to:
  /// **'Không có lịch sử chấm công trong tháng này'**
  String get noHistoryThisMonth;

  /// No description provided for @createRequest.
  ///
  /// In vi, this message translates to:
  /// **'Tạo yêu cầu'**
  String get createRequest;

  /// No description provided for @pendingTab.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get pendingTab;

  /// No description provided for @pending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get pending;

  /// No description provided for @apply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get apply;

  /// No description provided for @byDay.
  ///
  /// In vi, this message translates to:
  /// **'Theo ngày'**
  String get byDay;

  /// No description provided for @byMonth.
  ///
  /// In vi, this message translates to:
  /// **'Theo tháng'**
  String get byMonth;

  /// No description provided for @processedTab.
  ///
  /// In vi, this message translates to:
  /// **'Đã xử lý'**
  String get processedTab;

  /// No description provided for @checkInRequestTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ check-in yêu cầu'**
  String get checkInRequestTime;

  /// No description provided for @checkOutRequestTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ check-out yêu cầu'**
  String get checkOutRequestTime;

  /// No description provided for @updatePasswordSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu. Vui lòng đăng nhập lại'**
  String get updatePasswordSuccess;

  /// No description provided for @fillAllPasswordFields.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập đầy đủ mật khẩu'**
  String get fillAllPasswordFields;

  /// No description provided for @newPasswordMinLength.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới phải có ít nhất 8 ký tự, gồm cả chữ và số'**
  String get newPasswordMinLength;

  /// No description provided for @passwordMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận không khớp'**
  String get passwordMismatch;

  /// No description provided for @errorPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi'**
  String get errorPrefix;

  /// No description provided for @deleteDepartmentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa phòng ban'**
  String get deleteDepartmentTitle;

  /// No description provided for @deleteDepartmentPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Xóa \"{name}\"? Phòng ban không được có phòng con hoặc nhân viên.'**
  String deleteDepartmentPrompt(String name);

  /// No description provided for @addDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phòng ban'**
  String get addDepartment;

  /// No description provided for @noDepartmentsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có phòng ban nào'**
  String get noDepartmentsYet;

  /// No description provided for @createFirstDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Tạo phòng ban đầu tiên'**
  String get createFirstDepartment;

  /// No description provided for @managePositions.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý chức vụ'**
  String get managePositions;

  /// No description provided for @addSubDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phòng con'**
  String get addSubDepartment;

  /// No description provided for @editDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa phòng ban'**
  String get editDepartment;

  /// No description provided for @departmentNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên phòng ban *'**
  String get departmentNameLabel;

  /// No description provided for @departmentCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã phòng ban *'**
  String get departmentCodeLabel;

  /// No description provided for @departmentCodeHintAlt.
  ///
  /// In vi, this message translates to:
  /// **'VD: IT, HR'**
  String get departmentCodeHintAlt;

  /// No description provided for @descriptionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get descriptionLabel;

  /// No description provided for @create.
  ///
  /// In vi, this message translates to:
  /// **'Tạo'**
  String get create;

  /// No description provided for @deletePositionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa chức vụ'**
  String get deletePositionTitle;

  /// No description provided for @deletePositionPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Xóa chức vụ \"{name}\"?'**
  String deletePositionPrompt(String name);

  /// No description provided for @positionsOfDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Chức vụ — {name}'**
  String positionsOfDepartment(String name);

  /// No description provided for @addPosition.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chức vụ'**
  String get addPosition;

  /// No description provided for @noPositionsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có chức vụ nào'**
  String get noPositionsYet;

  /// No description provided for @editPosition.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa chức vụ'**
  String get editPosition;

  /// No description provided for @positionNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên chức vụ *'**
  String get positionNameLabel;

  /// No description provided for @positionCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã chức vụ *'**
  String get positionCodeLabel;

  /// No description provided for @positionCodeHintText.
  ///
  /// In vi, this message translates to:
  /// **'VD: CEO, SE_SR'**
  String get positionCodeHintText;

  /// No description provided for @employeeCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'{count} nhân viên'**
  String employeeCountLabel(int count);

  /// No description provided for @pleaseChooseDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn phòng ban'**
  String get pleaseChooseDepartment;

  /// No description provided for @pleaseChoosePosition.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn chức vụ'**
  String get pleaseChoosePosition;

  /// No description provided for @deleteRoleTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa vai trò'**
  String get deleteRoleTitle;

  /// No description provided for @deleteRolePrompt.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn xóa vai trò \"{name}\"?'**
  String deleteRolePrompt(String name);

  /// No description provided for @addRole.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vai trò'**
  String get addRole;

  /// No description provided for @editRole.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa vai trò'**
  String get editRole;

  /// No description provided for @noRolesYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có vai trò nào'**
  String get noRolesYet;

  /// No description provided for @roleNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên vai trò'**
  String get roleNameLabel;

  /// No description provided for @roleNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Tên vai trò không được để trống'**
  String get roleNameRequired;

  /// No description provided for @permissionsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Quyền hạn'**
  String get permissionsLabel;

  /// No description provided for @roleGroupsTab.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm quyền'**
  String get roleGroupsTab;

  /// No description provided for @directPermissionsTab.
  ///
  /// In vi, this message translates to:
  /// **'Quyền riêng'**
  String get directPermissionsTab;

  /// No description provided for @company.
  ///
  /// In vi, this message translates to:
  /// **'Công ty'**
  String get company;

  /// No description provided for @noUsersYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có người dùng nào'**
  String get noUsersYet;

  /// No description provided for @noResults.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết quả phù hợp'**
  String get noResults;

  /// No description provided for @scopeDepartmentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi phòng ban'**
  String get scopeDepartmentLabel;

  /// No description provided for @scopeCompanyLabel.
  ///
  /// In vi, this message translates to:
  /// **'Toàn công ty'**
  String get scopeCompanyLabel;

  /// No description provided for @scopeCompanyDesc.
  ///
  /// In vi, this message translates to:
  /// **'Không giới hạn phòng ban'**
  String get scopeCompanyDesc;

  /// No description provided for @scopeSelfLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ mình tôi'**
  String get scopeSelfLabel;

  /// No description provided for @scopeSelfDesc.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ xem dữ liệu của tài khoản hiện tại'**
  String get scopeSelfDesc;

  /// No description provided for @scopeMyDepartmentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ phòng ban của tôi'**
  String get scopeMyDepartmentLabel;

  /// No description provided for @scopeMyDepartmentDesc.
  ///
  /// In vi, this message translates to:
  /// **'Giới hạn trong đúng phòng ban mà tài khoản thuộc về'**
  String get scopeMyDepartmentDesc;

  /// No description provided for @scopeMyDepartmentAndBelowLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban của tôi và cấp dưới'**
  String get scopeMyDepartmentAndBelowLabel;

  /// No description provided for @scopeMyDepartmentAndBelowDesc.
  ///
  /// In vi, this message translates to:
  /// **'Bao gồm phòng ban của tôi và toàn bộ phòng ban con'**
  String get scopeMyDepartmentAndBelowDesc;

  /// No description provided for @scopeSelfPlusDepartments.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ mình tôi + {count} phòng ban'**
  String scopeSelfPlusDepartments(int count);

  /// No description provided for @scopeOneDepartment.
  ///
  /// In vi, this message translates to:
  /// **'1 phòng ban'**
  String get scopeOneDepartment;

  /// No description provided for @scopeDepartments.
  ///
  /// In vi, this message translates to:
  /// **'{count} phòng ban'**
  String scopeDepartments(int count);

  /// No description provided for @orSelectSpecificDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Hoặc chọn phòng ban cụ thể:'**
  String get orSelectSpecificDepartment;

  /// No description provided for @permUiDashboardView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Tổng quan trên menu'**
  String get permUiDashboardView;

  /// No description provided for @permUiEmployeeView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Nhân viên trên menu'**
  String get permUiEmployeeView;

  /// No description provided for @permUiEmployeeCreate.
  ///
  /// In vi, this message translates to:
  /// **'Nút Thêm nhân viên'**
  String get permUiEmployeeCreate;

  /// No description provided for @permUiEmployeeUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Nút Chỉnh sửa nhân viên'**
  String get permUiEmployeeUpdate;

  /// No description provided for @permUiEmployeeDelete.
  ///
  /// In vi, this message translates to:
  /// **'Nút Nghỉ việc nhân viên'**
  String get permUiEmployeeDelete;

  /// No description provided for @permUiDepartmentView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Phòng ban trên menu'**
  String get permUiDepartmentView;

  /// No description provided for @permUiDepartmentManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút Thêm/sửa/xóa phòng ban'**
  String get permUiDepartmentManage;

  /// No description provided for @permUiPositionManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút Thêm/sửa/xóa chức vụ'**
  String get permUiPositionManage;

  /// No description provided for @permUiAttendanceView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Chấm công trên menu'**
  String get permUiAttendanceView;

  /// No description provided for @permUiAttendanceManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút quản lý chấm công'**
  String get permUiAttendanceManage;

  /// No description provided for @permUiAttendanceSelf.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Chấm công cá nhân'**
  String get permUiAttendanceSelf;

  /// No description provided for @permUiAttendanceApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt yêu cầu chấm công'**
  String get permUiAttendanceApprove;

  /// No description provided for @permUiShiftView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Ca làm trên menu'**
  String get permUiShiftView;

  /// No description provided for @permUiShiftManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút Thêm/sửa/xóa ca làm'**
  String get permUiShiftManage;

  /// No description provided for @permUiPayrollView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Bảng lương trên menu'**
  String get permUiPayrollView;

  /// No description provided for @permUiPayrollCreate.
  ///
  /// In vi, this message translates to:
  /// **'Nút tạo bảng lương'**
  String get permUiPayrollCreate;

  /// No description provided for @permUiPayrollApprove.
  ///
  /// In vi, this message translates to:
  /// **'Nút duyệt bảng lương'**
  String get permUiPayrollApprove;

  /// No description provided for @permUiPayrollPay.
  ///
  /// In vi, this message translates to:
  /// **'Nút chi trả bảng lương'**
  String get permUiPayrollPay;

  /// No description provided for @permUiRoleView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Phân quyền trên menu'**
  String get permUiRoleView;

  /// No description provided for @permUiRoleManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút Thêm/sửa/xóa vai trò'**
  String get permUiRoleManage;

  /// No description provided for @permUiUserManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút Thêm/sửa/xóa tài khoản'**
  String get permUiUserManage;

  /// No description provided for @permUiCompanyManage.
  ///
  /// In vi, this message translates to:
  /// **'Nút Quản lý công ty'**
  String get permUiCompanyManage;

  /// No description provided for @permUiLeaveCreateForOthers.
  ///
  /// In vi, this message translates to:
  /// **'Tạo đơn nghỉ phép hộ nhân viên'**
  String get permUiLeaveCreateForOthers;

  /// No description provided for @permUiLeaveView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Nghỉ phép trên menu'**
  String get permUiLeaveView;

  /// No description provided for @permUiLeaveRequestCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo đơn nghỉ phép'**
  String get permUiLeaveRequestCreate;

  /// No description provided for @permUiLeaveRequestApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt/từ chối đơn nghỉ phép'**
  String get permUiLeaveRequestApprove;

  /// No description provided for @permUiLeaveGrantManual.
  ///
  /// In vi, this message translates to:
  /// **'Cấp phép thủ công'**
  String get permUiLeaveGrantManual;

  /// No description provided for @permUiLeaveTypeView.
  ///
  /// In vi, this message translates to:
  /// **'Xem danh sách loại nghỉ phép'**
  String get permUiLeaveTypeView;

  /// No description provided for @permUiLeaveTypeManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý loại nghỉ phép'**
  String get permUiLeaveTypeManage;

  /// No description provided for @permUiLeaveAccrualView.
  ///
  /// In vi, this message translates to:
  /// **'Xem rule cộng phép'**
  String get permUiLeaveAccrualView;

  /// No description provided for @permUiLeaveAccrualManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý rule cộng phép'**
  String get permUiLeaveAccrualManage;

  /// No description provided for @permUiCompanySettingView.
  ///
  /// In vi, this message translates to:
  /// **'Xem cài đặt chung công ty'**
  String get permUiCompanySettingView;

  /// No description provided for @permUiCompanySettingManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý cài đặt chung công ty'**
  String get permUiCompanySettingManage;

  /// No description provided for @permDescEmployeeView.
  ///
  /// In vi, this message translates to:
  /// **'Xem danh sách nhân viên'**
  String get permDescEmployeeView;

  /// No description provided for @permDescEmployeeCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm nhân viên mới'**
  String get permDescEmployeeCreate;

  /// No description provided for @permDescEmployeeUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật thông tin nhân viên'**
  String get permDescEmployeeUpdate;

  /// No description provided for @permDescEmployeeDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa/vô hiệu hóa nhân viên'**
  String get permDescEmployeeDelete;

  /// No description provided for @permDescDepartmentView.
  ///
  /// In vi, this message translates to:
  /// **'Xem cơ cấu phòng ban'**
  String get permDescDepartmentView;

  /// No description provided for @permDescDepartmentManage.
  ///
  /// In vi, this message translates to:
  /// **'Tạo/sửa/xóa phòng ban'**
  String get permDescDepartmentManage;

  /// No description provided for @permDescPositionManage.
  ///
  /// In vi, this message translates to:
  /// **'Tạo/sửa/xóa chức vụ'**
  String get permDescPositionManage;

  /// No description provided for @permDescAttendanceView.
  ///
  /// In vi, this message translates to:
  /// **'Xem dữ liệu chấm công'**
  String get permDescAttendanceView;

  /// No description provided for @permDescAttendanceManage.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa chấm công'**
  String get permDescAttendanceManage;

  /// No description provided for @permDescAttendanceSelf.
  ///
  /// In vi, this message translates to:
  /// **'Tự check-in/check-out'**
  String get permDescAttendanceSelf;

  /// No description provided for @permDescAttendanceApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt yêu cầu chấm công'**
  String get permDescAttendanceApprove;

  /// No description provided for @permDescShiftView.
  ///
  /// In vi, this message translates to:
  /// **'Xem ca làm'**
  String get permDescShiftView;

  /// No description provided for @permDescShiftManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý ca làm'**
  String get permDescShiftManage;

  /// No description provided for @permDescPayrollView.
  ///
  /// In vi, this message translates to:
  /// **'Xem bảng lương'**
  String get permDescPayrollView;

  /// No description provided for @permDescPayrollCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo phiếu lương'**
  String get permDescPayrollCreate;

  /// No description provided for @permDescPayrollApprove.
  ///
  /// In vi, this message translates to:
  /// **'Phê duyệt bảng lương'**
  String get permDescPayrollApprove;

  /// No description provided for @permDescPayrollPay.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu đã thanh toán lương'**
  String get permDescPayrollPay;

  /// No description provided for @permDescRoleView.
  ///
  /// In vi, this message translates to:
  /// **'Xem danh sách vai trò'**
  String get permDescRoleView;

  /// No description provided for @permDescRoleManage.
  ///
  /// In vi, this message translates to:
  /// **'Tạo/sửa/xóa vai trò'**
  String get permDescRoleManage;

  /// No description provided for @permDescUserManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý tài khoản người dùng'**
  String get permDescUserManage;

  /// No description provided for @permDescCompanyManage.
  ///
  /// In vi, this message translates to:
  /// **'Toàn quyền quản trị công ty'**
  String get permDescCompanyManage;

  /// No description provided for @permDescLeaveCreateForOthers.
  ///
  /// In vi, this message translates to:
  /// **'Tạo đơn nghỉ phép thay mặt nhân viên khác trong phạm vi được cấp'**
  String get permDescLeaveCreateForOthers;

  /// No description provided for @permDescLeaveView.
  ///
  /// In vi, this message translates to:
  /// **'Xem đơn nghỉ và số phép'**
  String get permDescLeaveView;

  /// No description provided for @permDescLeaveRequestCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo đơn nghỉ phép'**
  String get permDescLeaveRequestCreate;

  /// No description provided for @permDescLeaveRequestApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt hoặc từ chối đơn nghỉ phép'**
  String get permDescLeaveRequestApprove;

  /// No description provided for @permDescLeaveGrantManual.
  ///
  /// In vi, this message translates to:
  /// **'Cấp phép thủ công cho nhân viên'**
  String get permDescLeaveGrantManual;

  /// No description provided for @permDescLeaveTypeView.
  ///
  /// In vi, this message translates to:
  /// **'Xem danh sách loại nghỉ phép'**
  String get permDescLeaveTypeView;

  /// No description provided for @permDescLeaveTypeManage.
  ///
  /// In vi, this message translates to:
  /// **'Tạo/sửa/xóa loại nghỉ phép'**
  String get permDescLeaveTypeManage;

  /// No description provided for @permDescLeaveAccrualView.
  ///
  /// In vi, this message translates to:
  /// **'Xem cấu hình rule cộng phép'**
  String get permDescLeaveAccrualView;

  /// No description provided for @permDescLeaveAccrualManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý rule cộng phép tự động'**
  String get permDescLeaveAccrualManage;

  /// No description provided for @permDescCompanySettingView.
  ///
  /// In vi, this message translates to:
  /// **'Xem cài đặt chung của công ty'**
  String get permDescCompanySettingView;

  /// No description provided for @permDescCompanySettingManage.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật cài đặt chung của công ty'**
  String get permDescCompanySettingManage;

  /// No description provided for @permDescDashboardView.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị mục Tổng quan trên menu'**
  String get permDescDashboardView;

  /// No description provided for @assignedShifts.
  ///
  /// In vi, this message translates to:
  /// **'Ca đã phân công'**
  String get assignedShifts;

  /// No description provided for @maxShiftsPerDay.
  ///
  /// In vi, this message translates to:
  /// **'Đã đạt tối đa 2 ca/ngày'**
  String get maxShiftsPerDay;

  /// No description provided for @addSecondShift.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ca thứ 2'**
  String get addSecondShift;

  /// No description provided for @customHoursLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giờ tùy chỉnh'**
  String get customHoursLabel;

  /// No description provided for @shiftTemplatesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ca mẫu'**
  String get shiftTemplatesLabel;

  /// No description provided for @noShiftsAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ca nào'**
  String get noShiftsAvailable;

  /// No description provided for @editShiftAssignment.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa ca'**
  String get editShiftAssignment;

  /// No description provided for @startLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get startLabel;

  /// No description provided for @endLabel.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get endLabel;

  /// No description provided for @adminNoteReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do: {note}'**
  String adminNoteReason(String note);

  /// No description provided for @noChangesContent.
  ///
  /// In vi, this message translates to:
  /// **'Không có thay đổi nào'**
  String get noChangesContent;

  /// No description provided for @sentAtLabel.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lúc:'**
  String get sentAtLabel;

  /// No description provided for @goBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get goBack;

  /// No description provided for @processedTabLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã xử lý'**
  String get processedTabLabel;

  /// No description provided for @defaultLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mặc định'**
  String get defaultLabel;

  /// No description provided for @loginToCompany.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập vào công ty'**
  String get loginToCompany;

  /// No description provided for @activate.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt'**
  String get activate;

  /// No description provided for @deactivate.
  ///
  /// In vi, this message translates to:
  /// **'Vô hiệu hoá'**
  String get deactivate;

  /// No description provided for @stopped.
  ///
  /// In vi, this message translates to:
  /// **'Dừng'**
  String get stopped;

  /// No description provided for @basicInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cơ bản'**
  String get basicInfo;

  /// No description provided for @departmentAndPosition.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban & Chức vụ'**
  String get departmentAndPosition;

  /// No description provided for @additionalInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin bổ sung'**
  String get additionalInfo;

  /// No description provided for @bankInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin ngân hàng'**
  String get bankInfo;

  /// No description provided for @identityCardLabel.
  ///
  /// In vi, this message translates to:
  /// **'CCCD / CMND'**
  String get identityCardLabel;

  /// No description provided for @bankAccountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản'**
  String get bankAccountLabel;

  /// No description provided for @bankNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng'**
  String get bankNameLabel;

  /// No description provided for @monday.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 2'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 3'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 4'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 5'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 6'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 7'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhật'**
  String get sunday;

  /// No description provided for @applyTimeRange.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng {from} – {to}'**
  String applyTimeRange(String from, String to);

  /// No description provided for @invalidData.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu không hợp lệ'**
  String get invalidData;

  /// No description provided for @sessionExpired.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại'**
  String get sessionExpired;

  /// No description provided for @noPermissionForAction.
  ///
  /// In vi, this message translates to:
  /// **'Không có quyền thực hiện thao tác này'**
  String get noPermissionForAction;

  /// No description provided for @dataNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy dữ liệu'**
  String get dataNotFound;

  /// No description provided for @dataConflict.
  ///
  /// In vi, this message translates to:
  /// **'Xung đột dữ liệu, vui lòng kiểm tra lại'**
  String get dataConflict;

  /// No description provided for @serverErrorTryLater.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi server, vui lòng thử lại sau'**
  String get serverErrorTryLater;

  /// No description provided for @cannotConnectServerCode.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kết nối server (mã lỗi {code})'**
  String cannotConnectServerCode(String code);

  /// No description provided for @leaveApplyDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban áp dụng'**
  String get leaveApplyDepartment;

  /// No description provided for @leaveAllCompany.
  ///
  /// In vi, this message translates to:
  /// **'Toàn công ty'**
  String get leaveAllCompany;

  /// No description provided for @leaveTypeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Loại nghỉ phép'**
  String get leaveTypeLabel;

  /// No description provided for @leaveTypeCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã loại phép'**
  String get leaveTypeCode;

  /// No description provided for @leaveTypeName.
  ///
  /// In vi, this message translates to:
  /// **'Tên loại phép'**
  String get leaveTypeName;

  /// No description provided for @leaveCreateRequest.
  ///
  /// In vi, this message translates to:
  /// **'Tạo đơn nghỉ phép'**
  String get leaveCreateRequest;

  /// No description provided for @leaveManualGrant.
  ///
  /// In vi, this message translates to:
  /// **'Cấp phép thủ công'**
  String get leaveManualGrant;

  /// No description provided for @leaveRequestsTab.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu phép'**
  String get leaveRequestsTab;

  /// No description provided for @leaveTypesTab.
  ///
  /// In vi, this message translates to:
  /// **'Loại nghỉ phép'**
  String get leaveTypesTab;

  /// No description provided for @leaveRulesTab.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập cộng phép'**
  String get leaveRulesTab;

  /// No description provided for @leaveRequestHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử yêu cầu'**
  String get leaveRequestHistory;

  /// No description provided for @leaveCurrentBalance.
  ///
  /// In vi, this message translates to:
  /// **'Số dư phép hiện tại'**
  String get leaveCurrentBalance;

  /// No description provided for @leaveRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn'**
  String get leaveRemaining;

  /// No description provided for @leaveValidity.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu lực'**
  String get leaveValidity;

  /// No description provided for @leaveAddType.
  ///
  /// In vi, this message translates to:
  /// **'Thêm loại phép'**
  String get leaveAddType;

  /// No description provided for @leaveEditType.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật loại phép'**
  String get leaveEditType;

  /// No description provided for @leaveUnit.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get leaveUnit;

  /// No description provided for @leaveDeductPerDay.
  ///
  /// In vi, this message translates to:
  /// **'Trừ mỗi ngày'**
  String get leaveDeductPerDay;

  /// No description provided for @leavePaid.
  ///
  /// In vi, this message translates to:
  /// **'Có lương'**
  String get leavePaid;

  /// No description provided for @leaveUnpaid.
  ///
  /// In vi, this message translates to:
  /// **'Không lương'**
  String get leaveUnpaid;

  /// No description provided for @leaveAddRule.
  ///
  /// In vi, this message translates to:
  /// **'Thêm rule cộng phép'**
  String get leaveAddRule;

  /// No description provided for @leaveEditRule.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật rule cộng phép'**
  String get leaveEditRule;

  /// No description provided for @leaveRunNow.
  ///
  /// In vi, this message translates to:
  /// **'Chạy ngay'**
  String get leaveRunNow;

  /// No description provided for @leaveUnitDay.
  ///
  /// In vi, this message translates to:
  /// **'ngày'**
  String get leaveUnitDay;

  /// No description provided for @leaveUnitHour.
  ///
  /// In vi, this message translates to:
  /// **'tiếng'**
  String get leaveUnitHour;

  /// No description provided for @leaveGrantAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng cộng'**
  String get leaveGrantAmount;

  /// No description provided for @leaveFrequency.
  ///
  /// In vi, this message translates to:
  /// **'Chu kỳ'**
  String get leaveFrequency;

  /// No description provided for @leaveDayOfMonth.
  ///
  /// In vi, this message translates to:
  /// **'Ngày trong tháng'**
  String get leaveDayOfMonth;

  /// No description provided for @leaveMonthOfYear.
  ///
  /// In vi, this message translates to:
  /// **'Tháng trong năm'**
  String get leaveMonthOfYear;

  /// No description provided for @leaveMinTenure.
  ///
  /// In vi, this message translates to:
  /// **'Số năm kinh nghiệm tối thiểu'**
  String get leaveMinTenure;

  /// No description provided for @leaveExpireAfterDays.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn sau X ngày (tùy chọn)'**
  String get leaveExpireAfterDays;

  /// No description provided for @leaveUnlimited.
  ///
  /// In vi, this message translates to:
  /// **'Không giới hạn'**
  String get leaveUnlimited;

  /// No description provided for @leaveValidFrom.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu lực từ'**
  String get leaveValidFrom;

  /// No description provided for @leaveValidTo.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu lực đến'**
  String get leaveValidTo;

  /// No description provided for @leaveByDay.
  ///
  /// In vi, this message translates to:
  /// **'Theo ngày'**
  String get leaveByDay;

  /// No description provided for @leaveByHour.
  ///
  /// In vi, this message translates to:
  /// **'Theo giờ'**
  String get leaveByHour;

  /// No description provided for @leaveFromTime.
  ///
  /// In vi, this message translates to:
  /// **'Từ giờ'**
  String get leaveFromTime;

  /// No description provided for @leaveToTime.
  ///
  /// In vi, this message translates to:
  /// **'Đến giờ'**
  String get leaveToTime;

  /// No description provided for @leaveRequestMode.
  ///
  /// In vi, this message translates to:
  /// **'Kiểu đơn'**
  String get leaveRequestMode;

  /// No description provided for @leaveAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng'**
  String get leaveAmount;

  /// No description provided for @leaveAmountGtZero.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng phải > 0'**
  String get leaveAmountGtZero;

  /// No description provided for @leaveRuleName.
  ///
  /// In vi, this message translates to:
  /// **'Tên rule'**
  String get leaveRuleName;

  /// No description provided for @leaveRequestCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo đơn nghỉ phép'**
  String get leaveRequestCreated;

  /// No description provided for @leaveManualGrantCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cấp phép thủ công'**
  String get leaveManualGrantCreated;

  /// No description provided for @leaveRequestApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt đơn'**
  String get leaveRequestApproved;

  /// No description provided for @leaveRejectRequest.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối đơn'**
  String get leaveRejectRequest;

  /// No description provided for @leaveRequestRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối đơn'**
  String get leaveRequestRejected;

  /// No description provided for @leaveTypeCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm loại phép'**
  String get leaveTypeCreated;

  /// No description provided for @leaveTypeUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật loại phép'**
  String get leaveTypeUpdated;

  /// No description provided for @leaveTypeDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa loại phép'**
  String get leaveTypeDeleted;

  /// No description provided for @leaveRuleCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm rule'**
  String get leaveRuleCreated;

  /// No description provided for @leaveRuleUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật rule'**
  String get leaveRuleUpdated;

  /// No description provided for @leaveRuleDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa rule'**
  String get leaveRuleDeleted;

  /// No description provided for @leaveDeleteTypeConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn xóa loại phép này?'**
  String get leaveDeleteTypeConfirm;

  /// No description provided for @leaveDeleteRuleConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn xóa rule này?'**
  String get leaveDeleteRuleConfirm;

  /// No description provided for @leaveAccrualRunDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã chạy cộng phép tự động'**
  String get leaveAccrualRunDone;

  /// No description provided for @leaveCompanySettingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập công ty cho phép'**
  String get leaveCompanySettingTitle;

  /// No description provided for @leaveHoursPerDay.
  ///
  /// In vi, this message translates to:
  /// **'1 ngày = bao nhiêu giờ'**
  String get leaveHoursPerDay;

  /// No description provided for @payrollSettings.
  ///
  /// In vi, this message translates to:
  /// **'Lương'**
  String get payrollSettings;

  /// No description provided for @standardWorkDaysLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số ngày công tiêu chuẩn / tháng'**
  String get standardWorkDaysLabel;

  /// No description provided for @payrollCutoffDayLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày chốt lương (bắt đầu kỳ)'**
  String get payrollCutoffDayLabel;

  /// No description provided for @daysSuffix.
  ///
  /// In vi, this message translates to:
  /// **'ngày'**
  String get daysSuffix;

  /// No description provided for @hourSuffix.
  ///
  /// In vi, this message translates to:
  /// **'giờ'**
  String get hourSuffix;

  /// No description provided for @companySettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt công ty'**
  String get companySettings;

  /// No description provided for @companySettingAttendanceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập chấm công'**
  String get companySettingAttendanceTitle;

  /// No description provided for @companySettingDayNightMode.
  ///
  /// In vi, this message translates to:
  /// **'Phân biệt ngày/đêm'**
  String get companySettingDayNightMode;

  /// No description provided for @companySettingOtMode.
  ///
  /// In vi, this message translates to:
  /// **'Bật chế độ OT'**
  String get companySettingOtMode;

  /// No description provided for @companySettingDayFrom.
  ///
  /// In vi, this message translates to:
  /// **'Ban ngày từ'**
  String get companySettingDayFrom;

  /// No description provided for @companySettingDayTo.
  ///
  /// In vi, this message translates to:
  /// **'Ban ngày đến'**
  String get companySettingDayTo;

  /// No description provided for @companySettingNightSummary.
  ///
  /// In vi, this message translates to:
  /// **'Ban đêm: {end} ~ {start}'**
  String companySettingNightSummary(String end, String start);

  /// No description provided for @companySettingAttendanceWindowTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi giờ check-in/out'**
  String get companySettingAttendanceWindowTitle;

  /// No description provided for @companySettingCheckInBefore.
  ///
  /// In vi, this message translates to:
  /// **'Check-in trước ca'**
  String get companySettingCheckInBefore;

  /// No description provided for @companySettingCheckInAfter.
  ///
  /// In vi, this message translates to:
  /// **'Check-in sau ca'**
  String get companySettingCheckInAfter;

  /// No description provided for @companySettingCheckOutBefore.
  ///
  /// In vi, this message translates to:
  /// **'Check-out trước ca'**
  String get companySettingCheckOutBefore;

  /// No description provided for @companySettingCheckOutAfter.
  ///
  /// In vi, this message translates to:
  /// **'Check-out sau ca'**
  String get companySettingCheckOutAfter;

  /// No description provided for @invalidTimeFormat.
  ///
  /// In vi, this message translates to:
  /// **'Định dạng thời gian không hợp lệ (dùng HH:mm)'**
  String get invalidTimeFormat;

  /// No description provided for @companySettingLeaveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập phép'**
  String get companySettingLeaveTitle;

  /// No description provided for @leaveRemainingDays.
  ///
  /// In vi, this message translates to:
  /// **'Số ngày phép còn lại'**
  String get leaveRemainingDays;

  /// No description provided for @leaveRemainingBalance.
  ///
  /// In vi, this message translates to:
  /// **'Số dư phép'**
  String get leaveRemainingBalance;

  /// No description provided for @leaveCancelRequest.
  ///
  /// In vi, this message translates to:
  /// **'Hủy yêu cầu'**
  String get leaveCancelRequest;

  /// No description provided for @leaveCancelConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn hủy yêu cầu phép này? Số dư sẽ được hoàn lại.'**
  String get leaveCancelConfirm;

  /// No description provided for @leaveCancelledSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy yêu cầu phép'**
  String get leaveCancelledSuccess;

  /// No description provided for @cannotConnectServer.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kết nối server, kiểm tra kết nối mạng'**
  String get cannotConnectServer;

  /// No description provided for @leaveDepleted.
  ///
  /// In vi, this message translates to:
  /// **'Hết ngày'**
  String get leaveDepleted;

  /// No description provided for @leaveExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get leaveExpired;

  /// No description provided for @payrollList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách bảng lương'**
  String get payrollList;

  /// No description provided for @payrollGenerate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo phiếu lương'**
  String get payrollGenerate;

  /// No description provided for @payrollGenerateBtn.
  ///
  /// In vi, this message translates to:
  /// **'Tạo phiếu lương'**
  String get payrollGenerateBtn;

  /// No description provided for @exportPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Xuất lương Excel'**
  String get exportPayroll;

  /// No description provided for @exportPayrollSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Xuất bảng lương thành công'**
  String get exportPayrollSuccess;

  /// No description provided for @exportPayslips.
  ///
  /// In vi, this message translates to:
  /// **'Xuất phiếu lương'**
  String get exportPayslips;

  /// No description provided for @exportPayslipsSelected.
  ///
  /// In vi, this message translates to:
  /// **'Xuất phiếu lương ({count})'**
  String exportPayslipsSelected(int count);

  /// No description provided for @exportPayslipsSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Xuất phiếu lương thành công'**
  String get exportPayslipsSuccess;

  /// No description provided for @monthLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}'**
  String monthLabel(int month);

  /// No description provided for @searchEmployeeHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhân viên để thêm...'**
  String get searchEmployeeHint;

  /// No description provided for @incomeSection.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập'**
  String get incomeSection;

  /// No description provided for @allowanceSection.
  ///
  /// In vi, this message translates to:
  /// **'Trợ cấp'**
  String get allowanceSection;

  /// No description provided for @deductionSection.
  ///
  /// In vi, this message translates to:
  /// **'Khấu trừ'**
  String get deductionSection;

  /// No description provided for @payrollDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xóa bảng lương tháng {month}/{year} của \"{employee}\"?'**
  String payrollDeleteConfirm(int month, int year, String employee);

  /// No description provided for @payrollDeleteAction.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get payrollDeleteAction;

  /// No description provided for @payrollRecalculateDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã tính lại bảng lương'**
  String get payrollRecalculateDone;

  /// No description provided for @payrollRecalculateTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Tính lại theo công thức'**
  String get payrollRecalculateTooltip;

  /// No description provided for @payrollPickFormulaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn công thức tính lương'**
  String get payrollPickFormulaTitle;

  /// No description provided for @payrollPickFormulaCustomSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Công thức đã chỉnh sửa · chỉ áp dụng cho bảng lương này'**
  String get payrollPickFormulaCustomSubtitle;

  /// No description provided for @payrollPickFormulaDateSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu lực: {date}'**
  String payrollPickFormulaDateSubtitle(String date);

  /// No description provided for @payrollPickFormulaRecentNote.
  ///
  /// In vi, this message translates to:
  /// **'Gần nhất với tháng được chọn'**
  String get payrollPickFormulaRecentNote;

  /// No description provided for @payrollRecalculateAction.
  ///
  /// In vi, this message translates to:
  /// **'Tính lại'**
  String get payrollRecalculateAction;

  /// No description provided for @payslip.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu lương'**
  String get payslip;

  /// No description provided for @payrollStatusDraft.
  ///
  /// In vi, this message translates to:
  /// **'Nháp'**
  String get payrollStatusDraft;

  /// No description provided for @payrollStatusApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get payrollStatusApproved;

  /// No description provided for @payrollStatusPaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã thanh toán'**
  String get payrollStatusPaid;

  /// No description provided for @payrollApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get payrollApprove;

  /// No description provided for @payrollPay.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get payrollPay;

  /// No description provided for @payrollEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get payrollEdit;

  /// No description provided for @baseSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương cơ bản'**
  String get baseSalary;

  /// No description provided for @baseSalaryMonthly.
  ///
  /// In vi, this message translates to:
  /// **'Lương bậc / tháng'**
  String get baseSalaryMonthly;

  /// No description provided for @baseSalaryPerDay.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá / ngày'**
  String get baseSalaryPerDay;

  /// No description provided for @baseSalaryPerHour.
  ///
  /// In vi, this message translates to:
  /// **'Lương bậc / giờ'**
  String get baseSalaryPerHour;

  /// No description provided for @actualWorkDays.
  ///
  /// In vi, this message translates to:
  /// **'Ngày làm thực tế'**
  String get actualWorkDays;

  /// No description provided for @actualWorkHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ làm thực tế'**
  String get actualWorkHours;

  /// No description provided for @grossSalary.
  ///
  /// In vi, this message translates to:
  /// **'Tổng lương gộp'**
  String get grossSalary;

  /// No description provided for @netSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương thực nhận'**
  String get netSalary;

  /// No description provided for @allowance.
  ///
  /// In vi, this message translates to:
  /// **'Phụ cấp'**
  String get allowance;

  /// No description provided for @bonus.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng'**
  String get bonus;

  /// No description provided for @overtimePay.
  ///
  /// In vi, this message translates to:
  /// **'Lương OT'**
  String get overtimePay;

  /// No description provided for @socialInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BHXH (8%)'**
  String get socialInsurance;

  /// No description provided for @healthInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BHYT (1.5%)'**
  String get healthInsurance;

  /// No description provided for @unemploymentInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BHTN (1%)'**
  String get unemploymentInsurance;

  /// No description provided for @personalIncomeTax.
  ///
  /// In vi, this message translates to:
  /// **'Thuế TNCN'**
  String get personalIncomeTax;

  /// No description provided for @otherDeductions.
  ///
  /// In vi, this message translates to:
  /// **'Khấu trừ khác'**
  String get otherDeductions;

  /// No description provided for @presentDays.
  ///
  /// In vi, this message translates to:
  /// **'Ngày công'**
  String get presentDays;

  /// No description provided for @overtimeHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ OT'**
  String get overtimeHours;

  /// No description provided for @dayShiftHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ ca ngày'**
  String get dayShiftHours;

  /// No description provided for @nightShiftHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ ca đêm'**
  String get nightShiftHours;

  /// No description provided for @otDayShift.
  ///
  /// In vi, this message translates to:
  /// **'OT ca ngày'**
  String get otDayShift;

  /// No description provided for @otNightShift.
  ///
  /// In vi, this message translates to:
  /// **'OT ca đêm'**
  String get otNightShift;

  /// No description provided for @salaryHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử lương'**
  String get salaryHistory;

  /// No description provided for @salaryHistoryAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm mức lương'**
  String get salaryHistoryAdd;

  /// No description provided for @effectiveDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày hiệu lực'**
  String get effectiveDate;

  /// No description provided for @payrollMonthlyHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử bảng lương'**
  String get payrollMonthlyHistory;

  /// No description provided for @salaryGradeHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử bậc lương'**
  String get salaryGradeHistory;

  /// No description provided for @actualSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương thực tế'**
  String get actualSalary;

  /// No description provided for @totalDeductions.
  ///
  /// In vi, this message translates to:
  /// **'Tổng khấu trừ'**
  String get totalDeductions;

  /// No description provided for @payrollNoSalaryConfig.
  ///
  /// In vi, this message translates to:
  /// **'Chưa cấu hình lương cho nhân viên này'**
  String get payrollNoSalaryConfig;

  /// No description provided for @payrollConfirmApprove.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận duyệt bảng lương?'**
  String get payrollConfirmApprove;

  /// No description provided for @payrollConfirmPay.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đã thanh toán?'**
  String get payrollConfirmPay;

  /// No description provided for @selfPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu lương của tôi'**
  String get selfPayroll;

  /// No description provided for @salaryGrade.
  ///
  /// In vi, this message translates to:
  /// **'Bậc lương'**
  String get salaryGrade;

  /// No description provided for @salaryGradeAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm bậc lương'**
  String get salaryGradeAdd;

  /// No description provided for @salaryGradeEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa bậc lương'**
  String get salaryGradeEdit;

  /// No description provided for @salaryGradeCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã bậc'**
  String get salaryGradeCode;

  /// No description provided for @salaryGradeName.
  ///
  /// In vi, this message translates to:
  /// **'Tên bậc'**
  String get salaryGradeName;

  /// No description provided for @payTypeDaily.
  ///
  /// In vi, this message translates to:
  /// **'Ngày công'**
  String get payTypeDaily;

  /// No description provided for @payTypeHourly.
  ///
  /// In vi, this message translates to:
  /// **'Giờ công'**
  String get payTypeHourly;

  /// No description provided for @baseRate.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá cơ bản'**
  String get baseRate;

  /// No description provided for @salaryFormula.
  ///
  /// In vi, this message translates to:
  /// **'Công thức lương'**
  String get salaryFormula;

  /// No description provided for @formulaGross.
  ///
  /// In vi, this message translates to:
  /// **'Công thức lương gộp'**
  String get formulaGross;

  /// No description provided for @formulaNet.
  ///
  /// In vi, this message translates to:
  /// **'Công thức lương thực nhận'**
  String get formulaNet;

  /// No description provided for @formulaVariables.
  ///
  /// In vi, this message translates to:
  /// **'Biến số'**
  String get formulaVariables;

  /// No description provided for @formulaValidate.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra'**
  String get formulaValidate;

  /// No description provided for @formulaValid.
  ///
  /// In vi, this message translates to:
  /// **'Công thức hợp lệ'**
  String get formulaValid;

  /// No description provided for @formulaInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Công thức có lỗi'**
  String get formulaInvalid;

  /// No description provided for @formulaTabGrade.
  ///
  /// In vi, this message translates to:
  /// **'Bậc lương'**
  String get formulaTabGrade;

  /// No description provided for @formulaTabFormula.
  ///
  /// In vi, this message translates to:
  /// **'Công thức lương'**
  String get formulaTabFormula;

  /// No description provided for @formulaTabPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Bảng lương'**
  String get formulaTabPayroll;

  /// No description provided for @formulaTabVariables.
  ///
  /// In vi, this message translates to:
  /// **'Biến số'**
  String get formulaTabVariables;

  /// No description provided for @varColName.
  ///
  /// In vi, this message translates to:
  /// **'Tên biến'**
  String get varColName;

  /// No description provided for @varColDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get varColDesc;

  /// No description provided for @varColExpr.
  ///
  /// In vi, this message translates to:
  /// **'Biểu thức'**
  String get varColExpr;

  /// No description provided for @varColScope.
  ///
  /// In vi, this message translates to:
  /// **'Scope'**
  String get varColScope;

  /// No description provided for @varColActions.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác'**
  String get varColActions;

  /// No description provided for @varAddGlobal.
  ///
  /// In vi, this message translates to:
  /// **'Thêm biến Global'**
  String get varAddGlobal;

  /// No description provided for @varScopeSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống'**
  String get varScopeSystem;

  /// No description provided for @varScopeGlobal.
  ///
  /// In vi, this message translates to:
  /// **'Toàn công ty'**
  String get varScopeGlobal;

  /// No description provided for @varEditGlobal.
  ///
  /// In vi, this message translates to:
  /// **'Sửa biến Global'**
  String get varEditGlobal;

  /// No description provided for @varAddGlobalTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm biến Global'**
  String get varAddGlobalTitle;

  /// No description provided for @varNameHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: THUONG_LE'**
  String get varNameHint;

  /// No description provided for @varNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên biến (A-Z, 0-9, _)'**
  String get varNameLabel;

  /// No description provided for @varDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả (tuỳ chọn)'**
  String get varDescLabel;

  /// No description provided for @varExprLabel.
  ///
  /// In vi, this message translates to:
  /// **'Biểu thức'**
  String get varExprLabel;

  /// No description provided for @varExprHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: BASE_RATE * 0.5'**
  String get varExprHint;

  /// No description provided for @varExprValid.
  ///
  /// In vi, this message translates to:
  /// **'Biểu thức hợp lệ'**
  String get varExprValid;

  /// No description provided for @varChipInsertHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn chip để chèn vào biểu thức'**
  String get varChipInsertHint;

  /// No description provided for @varCannotDelete.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xoá'**
  String get varCannotDelete;

  /// No description provided for @varUsedInFormulas.
  ///
  /// In vi, this message translates to:
  /// **'đang được dùng trong {count} công thức'**
  String varUsedInFormulas(Object count);

  /// No description provided for @varFixFormulasFirst.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng xoá biến này khỏi các công thức trên trước.'**
  String get varFixFormulasFirst;

  /// No description provided for @varPrivateSection.
  ///
  /// In vi, this message translates to:
  /// **'Biến Private (công thức này)'**
  String get varPrivateSection;

  /// No description provided for @varGlobalSection.
  ///
  /// In vi, this message translates to:
  /// **'Biến Global (toàn công ty)'**
  String get varGlobalSection;

  /// No description provided for @varNoPrivate.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có biến private'**
  String get varNoPrivate;

  /// No description provided for @varNoGlobal.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có biến global'**
  String get varNoGlobal;

  /// No description provided for @varAddPrivate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm biến private'**
  String get varAddPrivate;

  /// No description provided for @varEditPrivate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa biến private'**
  String get varEditPrivate;

  /// No description provided for @rememberMe.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhớ đăng nhập'**
  String get rememberMe;

  /// No description provided for @disableUserTitle.
  ///
  /// In vi, this message translates to:
  /// **'Vô hiệu hóa tài khoản'**
  String get disableUserTitle;

  /// No description provided for @disableUserPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn vô hiệu hóa tài khoản của {name}?'**
  String disableUserPrompt(Object name);

  /// No description provided for @disable.
  ///
  /// In vi, this message translates to:
  /// **'Vô hiệu hóa'**
  String get disable;

  /// No description provided for @quickFillPanel.
  ///
  /// In vi, this message translates to:
  /// **'Điền nhanh ca'**
  String get quickFillPanel;

  /// No description provided for @quickFillHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ca bên dưới rồi nhấn vào ô để gán'**
  String get quickFillHint;

  /// No description provided for @quickFillClearSelection.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chọn'**
  String get quickFillClearSelection;

  /// No description provided for @quickFillCustomHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ tùy chỉnh'**
  String get quickFillCustomHours;

  /// No description provided for @quickFillNoShifts.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ca nào'**
  String get quickFillNoShifts;

  /// No description provided for @shiftGroup.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm ca'**
  String get shiftGroup;

  /// No description provided for @shiftGroupHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Ca hành chính, Ca kỹ thuật...'**
  String get shiftGroupHint;

  /// No description provided for @shiftGroupUngrouped.
  ///
  /// In vi, this message translates to:
  /// **'Chưa phân nhóm'**
  String get shiftGroupUngrouped;

  /// No description provided for @adminOverrideTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa toàn quyền'**
  String get adminOverrideTitle;

  /// No description provided for @adminOverrideHint.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ trống để dùng dữ liệu thực tế'**
  String get adminOverrideHint;

  /// No description provided for @adminOverrideOtDay.
  ///
  /// In vi, this message translates to:
  /// **'OT ngày (phút)'**
  String get adminOverrideOtDay;

  /// No description provided for @adminOverrideOtNight.
  ///
  /// In vi, this message translates to:
  /// **'OT đêm (phút)'**
  String get adminOverrideOtNight;

  /// No description provided for @adminOverrideBreak.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ giải lao (phút)'**
  String get adminOverrideBreak;

  /// No description provided for @adminOverrideNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú override'**
  String get adminOverrideNote;

  /// No description provided for @adminOverrideClear.
  ///
  /// In vi, this message translates to:
  /// **'Xóa override'**
  String get adminOverrideClear;

  /// No description provided for @adminOverrideActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang override'**
  String get adminOverrideActive;

  /// No description provided for @shiftAssignmentApproved.
  ///
  /// In vi, this message translates to:
  /// **'Ca đã được duyệt'**
  String get shiftAssignmentApproved;

  /// No description provided for @shiftAssignmentApprovedCannotDelete.
  ///
  /// In vi, this message translates to:
  /// **'Ca này đã được duyệt. Vui lòng bỏ duyệt trước khi xóa.'**
  String get shiftAssignmentApprovedCannotDelete;

  /// No description provided for @exportExcel.
  ///
  /// In vi, this message translates to:
  /// **'Xuất Excel'**
  String get exportExcel;

  /// No description provided for @exportSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Xuất file thành công'**
  String get exportSuccess;

  /// No description provided for @importExcel.
  ///
  /// In vi, this message translates to:
  /// **'Nhập Excel'**
  String get importExcel;

  /// No description provided for @importSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Nhập dữ liệu thành công'**
  String get importSuccess;

  /// No description provided for @importPreviewRow.
  ///
  /// In vi, this message translates to:
  /// **'Dòng'**
  String get importPreviewRow;

  /// No description provided for @importPreviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước thay đổi'**
  String get importPreviewTitle;

  /// No description provided for @importPreviewCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo mới'**
  String get importPreviewCreate;

  /// No description provided for @importPreviewUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get importPreviewUpdate;

  /// No description provided for @importPreviewMerge.
  ///
  /// In vi, this message translates to:
  /// **'Hợp nhất'**
  String get importPreviewMerge;

  /// No description provided for @importPreviewWarn.
  ///
  /// In vi, this message translates to:
  /// **'Cảnh báo'**
  String get importPreviewWarn;

  /// No description provided for @importPreviewNoChange.
  ///
  /// In vi, this message translates to:
  /// **'Không đổi'**
  String get importPreviewNoChange;

  /// No description provided for @importPreviewEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có thay đổi nào'**
  String get importPreviewEmpty;

  /// No description provided for @importConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận nhập'**
  String get importConfirm;

  /// No description provided for @importPreviewOld.
  ///
  /// In vi, this message translates to:
  /// **'Cũ'**
  String get importPreviewOld;

  /// No description provided for @importPreviewNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get importPreviewNew;

  /// No description provided for @importPreviewDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get importPreviewDelete;

  /// No description provided for @importPreviewDeleteWarning.
  ///
  /// In vi, this message translates to:
  /// **'Cảnh báo liên đới'**
  String get importPreviewDeleteWarning;

  /// No description provided for @exportAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Xuất chấm công Excel'**
  String get exportAttendance;

  /// No description provided for @importAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Nhập chấm công Excel'**
  String get importAttendance;

  /// No description provided for @importAttendanceSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Nhập chấm công thành công'**
  String get importAttendanceSuccess;

  /// No description provided for @excelScreenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Import / Export dữ liệu'**
  String get excelScreenTitle;

  /// No description provided for @excelExportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xuất dữ liệu'**
  String get excelExportTitle;

  /// No description provided for @excelExportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn module muốn xuất. Bỏ trống để xuất toàn bộ.'**
  String get excelExportSubtitle;

  /// No description provided for @excelExportButton.
  ///
  /// In vi, this message translates to:
  /// **'Chọn & Xuất'**
  String get excelExportButton;

  /// No description provided for @excelExportButtonN.
  ///
  /// In vi, this message translates to:
  /// **'Chọn & Xuất ({n})'**
  String excelExportButtonN(int n);

  /// No description provided for @excelExportHint.
  ///
  /// In vi, this message translates to:
  /// **'File Excel xuất ra có cột \"Lệnh\" (hoặc \"Command\"). Điền CREATE / UPDATE / MERGE / DELETE vào cột đó rồi import lại để thực hiện thay đổi hàng loạt.'**
  String get excelExportHint;

  /// No description provided for @excelModuleEmployee.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get excelModuleEmployee;

  /// No description provided for @excelModuleDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get excelModuleDepartment;

  /// No description provided for @excelModulePosition.
  ///
  /// In vi, this message translates to:
  /// **'Chức vụ'**
  String get excelModulePosition;

  /// No description provided for @excelModuleShift.
  ///
  /// In vi, this message translates to:
  /// **'Ca làm việc'**
  String get excelModuleShift;

  /// No description provided for @excelModuleShiftAssignment.
  ///
  /// In vi, this message translates to:
  /// **'Phân công ca'**
  String get excelModuleShiftAssignment;

  /// No description provided for @excelImportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập dữ liệu'**
  String get excelImportTitle;

  /// No description provided for @excelImportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn file Excel (đã điền cột Lệnh) để xem trước và nhập.'**
  String get excelImportSubtitle;

  /// No description provided for @excelImportDropzone.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn để chọn file .xlsx'**
  String get excelImportDropzone;

  /// No description provided for @excelImportPreviewBtn.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước & Nhập'**
  String get excelImportPreviewBtn;

  /// No description provided for @excelImportClearFile.
  ///
  /// In vi, this message translates to:
  /// **'Xóa file'**
  String get excelImportClearFile;

  /// No description provided for @excelImportResultDownload.
  ///
  /// In vi, this message translates to:
  /// **'Tải file kết quả'**
  String get excelImportResultDownload;

  /// No description provided for @excelImportResultOk.
  ///
  /// In vi, this message translates to:
  /// **'{n} thành công'**
  String excelImportResultOk(int n);

  /// No description provided for @excelImportResultError.
  ///
  /// In vi, this message translates to:
  /// **'{n} lỗi'**
  String excelImportResultError(int n);

  /// No description provided for @excelImportResultSkip.
  ///
  /// In vi, this message translates to:
  /// **'{n} bỏ qua'**
  String excelImportResultSkip(int n);

  /// No description provided for @excelStepExport.
  ///
  /// In vi, this message translates to:
  /// **'Xuất file mẫu ở trên'**
  String get excelStepExport;

  /// No description provided for @excelStepFill.
  ///
  /// In vi, this message translates to:
  /// **'Điền cột Lệnh:\nCREATE / UPDATE /\nMERGE / DELETE'**
  String get excelStepFill;

  /// No description provided for @excelStepPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn file đã điền'**
  String get excelStepPick;

  /// No description provided for @excelStepPreview.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước thay đổi'**
  String get excelStepPreview;

  /// No description provided for @excelStepConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận → nhận file kết quả'**
  String get excelStepConfirm;

  /// No description provided for @excelHistoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử'**
  String get excelHistoryTitle;

  /// No description provided for @excelHistoryEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lịch sử.'**
  String get excelHistoryEmpty;

  /// No description provided for @excelHistoryTypeExport.
  ///
  /// In vi, this message translates to:
  /// **'Xuất'**
  String get excelHistoryTypeExport;

  /// No description provided for @excelHistoryTypeImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập'**
  String get excelHistoryTypeImport;

  /// No description provided for @excelHistoryFilterType.
  ///
  /// In vi, this message translates to:
  /// **'Loại'**
  String get excelHistoryFilterType;

  /// No description provided for @excelHistoryFilterModule.
  ///
  /// In vi, this message translates to:
  /// **'Module'**
  String get excelHistoryFilterModule;

  /// No description provided for @excelHistoryFilterFrom.
  ///
  /// In vi, this message translates to:
  /// **'Từ ngày'**
  String get excelHistoryFilterFrom;

  /// No description provided for @excelHistoryFilterTo.
  ///
  /// In vi, this message translates to:
  /// **'Đến ngày'**
  String get excelHistoryFilterTo;

  /// No description provided for @excelHistoryModuleAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get excelHistoryModuleAll;

  /// No description provided for @excelHistoryModuleEmployee.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get excelHistoryModuleEmployee;

  /// No description provided for @excelHistoryModuleDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get excelHistoryModuleDepartment;

  /// No description provided for @excelHistoryModulePosition.
  ///
  /// In vi, this message translates to:
  /// **'Chức vụ'**
  String get excelHistoryModulePosition;

  /// No description provided for @excelHistoryModuleShift.
  ///
  /// In vi, this message translates to:
  /// **'Ca làm việc'**
  String get excelHistoryModuleShift;

  /// No description provided for @excelHistoryModuleAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Chấm công'**
  String get excelHistoryModuleAttendance;

  /// No description provided for @excelHistoryModulePayroll.
  ///
  /// In vi, this message translates to:
  /// **'Bảng lương'**
  String get excelHistoryModulePayroll;

  /// No description provided for @excelHistoryDownload.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại'**
  String get excelHistoryDownload;

  /// No description provided for @excelHistoryOk.
  ///
  /// In vi, this message translates to:
  /// **'{n} thành công'**
  String excelHistoryOk(int n);

  /// No description provided for @excelHistoryError.
  ///
  /// In vi, this message translates to:
  /// **'{n} lỗi'**
  String excelHistoryError(int n);

  /// No description provided for @excelHistorySkip.
  ///
  /// In vi, this message translates to:
  /// **'{n} bỏ qua'**
  String excelHistorySkip(int n);

  /// No description provided for @excelHistoryTypeReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get excelHistoryTypeReport;

  /// No description provided for @excelModulePayroll.
  ///
  /// In vi, this message translates to:
  /// **'Bảng lương'**
  String get excelModulePayroll;

  /// No description provided for @excelModuleAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Chấm công'**
  String get excelModuleAttendance;

  /// No description provided for @excelModuleUniversal.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu'**
  String get excelModuleUniversal;

  /// No description provided for @excelModuleSalaryGrade.
  ///
  /// In vi, this message translates to:
  /// **'Bậc lương'**
  String get excelModuleSalaryGrade;

  /// No description provided for @excelModuleSalaryFormula.
  ///
  /// In vi, this message translates to:
  /// **'Công thức lương'**
  String get excelModuleSalaryFormula;

  /// No description provided for @excelModuleFormulaVariable.
  ///
  /// In vi, this message translates to:
  /// **'Biến công thức'**
  String get excelModuleFormulaVariable;

  /// No description provided for @excelModuleLeaveType.
  ///
  /// In vi, this message translates to:
  /// **'Loại nghỉ phép'**
  String get excelModuleLeaveType;

  /// No description provided for @excelModuleLeaveGrant.
  ///
  /// In vi, this message translates to:
  /// **'Số dư phép'**
  String get excelModuleLeaveGrant;

  /// No description provided for @reportScreenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get reportScreenTitle;

  /// No description provided for @reportScreenSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xuất báo cáo kinh doanh ra Excel'**
  String get reportScreenSubtitle;

  /// No description provided for @reportGroupEmployee.
  ///
  /// In vi, this message translates to:
  /// **'Nhân sự'**
  String get reportGroupEmployee;

  /// No description provided for @reportGroupAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo chấm công'**
  String get reportGroupAttendance;

  /// No description provided for @reportGroupPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo lương'**
  String get reportGroupPayroll;

  /// No description provided for @reportGroupLeave.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo nghỉ phép'**
  String get reportGroupLeave;

  /// No description provided for @reportEmployee.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê nhân sự'**
  String get reportEmployee;

  /// No description provided for @reportEmployeeDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên đang làm / đã nghỉ theo phòng ban'**
  String get reportEmployeeDesc;

  /// No description provided for @reportNewHires.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên mới'**
  String get reportNewHires;

  /// No description provided for @reportNewHiresDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên vào làm trong kỳ được chọn'**
  String get reportNewHiresDesc;

  /// No description provided for @reportResigned.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên nghỉ việc'**
  String get reportResigned;

  /// No description provided for @reportResignedDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên đã nghỉ trong kỳ được chọn'**
  String get reportResignedDesc;

  /// No description provided for @reportAttendanceSummary.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hợp chấm công'**
  String get reportAttendanceSummary;

  /// No description provided for @reportAttendanceSummaryDesc.
  ///
  /// In vi, this message translates to:
  /// **'Số ngày có mặt, vắng mặt, trễ theo từng nhân viên mỗi tháng'**
  String get reportAttendanceSummaryDesc;

  /// No description provided for @reportLateCheckin.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo đi trễ'**
  String get reportLateCheckin;

  /// No description provided for @reportLateCheckinDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên có tần suất đi trễ cao'**
  String get reportLateCheckinDesc;

  /// No description provided for @reportOvertimeSummary.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hợp tăng ca'**
  String get reportOvertimeSummary;

  /// No description provided for @reportOvertimeSummaryDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tổng giờ OT của từng nhân viên trong tháng'**
  String get reportOvertimeSummaryDesc;

  /// No description provided for @reportPayrollSummary.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hợp chi phí lương'**
  String get reportPayrollSummary;

  /// No description provided for @reportPayrollSummaryDesc.
  ///
  /// In vi, this message translates to:
  /// **'Chi phí lương tháng phân theo phòng ban'**
  String get reportPayrollSummaryDesc;

  /// No description provided for @reportPayrollDetail.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết bảng lương'**
  String get reportPayrollDetail;

  /// No description provided for @reportPayrollDetailDesc.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết lương của tất cả nhân viên trong tháng được chọn'**
  String get reportPayrollDetailDesc;

  /// No description provided for @reportLeaveBalance.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hợp số dư phép'**
  String get reportLeaveBalance;

  /// No description provided for @reportLeaveBalanceDesc.
  ///
  /// In vi, this message translates to:
  /// **'Số ngày phép còn lại của từng nhân viên theo loại phép'**
  String get reportLeaveBalanceDesc;

  /// No description provided for @reportLeaveUsage.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê sử dụng phép'**
  String get reportLeaveUsage;

  /// No description provided for @reportLeaveUsageDesc.
  ///
  /// In vi, this message translates to:
  /// **'Các đơn nghỉ phép và số ngày đã dùng trong kỳ'**
  String get reportLeaveUsageDesc;

  /// No description provided for @reportFilterYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get reportFilterYear;

  /// No description provided for @reportFilterMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get reportFilterMonth;

  /// No description provided for @reportFilterDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get reportFilterDepartment;

  /// No description provided for @reportFilterAllDepts.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả phòng ban'**
  String get reportFilterAllDepts;

  /// No description provided for @reportExportBtn.
  ///
  /// In vi, this message translates to:
  /// **'Xuất Excel'**
  String get reportExportBtn;

  /// No description provided for @reportExporting.
  ///
  /// In vi, this message translates to:
  /// **'Đang xuất...'**
  String get reportExporting;

  /// No description provided for @reportExportSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Xuất báo cáo thành công'**
  String get reportExportSuccess;

  /// No description provided for @reportExportOptions.
  ///
  /// In vi, this message translates to:
  /// **'Tùy chọn xuất'**
  String get reportExportOptions;

  /// No description provided for @reportGroupYearly.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo năm'**
  String get reportGroupYearly;

  /// No description provided for @reportYearlyOverview.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo tổng quan năm'**
  String get reportYearlyOverview;

  /// No description provided for @reportYearlyOverviewDesc.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo quản lý cả năm — lương, nhân sự, chấm công, nghỉ phép kèm biểu đồ xu hướng'**
  String get reportYearlyOverviewDesc;

  /// No description provided for @dashboardErrorLoad.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải dữ liệu tổng quan'**
  String get dashboardErrorLoad;

  /// No description provided for @dashboardOnLeave.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ phép'**
  String get dashboardOnLeave;

  /// No description provided for @dashboardPayrollDraft.
  ///
  /// In vi, this message translates to:
  /// **'Nháp'**
  String get dashboardPayrollDraft;

  /// No description provided for @dashboardPayrollApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get dashboardPayrollApproved;

  /// No description provided for @dashboardPayrollPaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã thanh toán'**
  String get dashboardPayrollPaid;

  /// No description provided for @dashboardNoPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bảng lương'**
  String get dashboardNoPayroll;

  /// No description provided for @dashboardNoAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu chấm công hôm nay'**
  String get dashboardNoAttendance;

  /// No description provided for @dashboardCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Vào: {time}'**
  String dashboardCheckIn(String time);

  /// No description provided for @dashboardCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Ra: {time}'**
  String dashboardCheckOut(String time);

  /// No description provided for @dashboardNotCheckedIn.
  ///
  /// In vi, this message translates to:
  /// **'Chưa check-in'**
  String get dashboardNotCheckedIn;

  /// No description provided for @dashboardFilterDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Lọc theo phòng ban'**
  String get dashboardFilterDepartment;

  /// No description provided for @today.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get today;

  /// No description provided for @dashboardTabAnalytics.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích'**
  String get dashboardTabAnalytics;

  /// No description provided for @dashboardAnalyticsSalaryTrend.
  ///
  /// In vi, this message translates to:
  /// **'Chi lương theo tháng'**
  String get dashboardAnalyticsSalaryTrend;

  /// No description provided for @dashboardAnalyticsAttendanceTrend.
  ///
  /// In vi, this message translates to:
  /// **'Xu hướng chấm công (90 ngày)'**
  String get dashboardAnalyticsAttendanceTrend;

  /// No description provided for @dashboardAnalyticsTopLate.
  ///
  /// In vi, this message translates to:
  /// **'Đi muộn nhiều nhất'**
  String get dashboardAnalyticsTopLate;

  /// No description provided for @dashboardAnalyticsOverall.
  ///
  /// In vi, this message translates to:
  /// **'Tổng kết năm'**
  String get dashboardAnalyticsOverall;

  /// No description provided for @dashboardAnalyticsLateDays.
  ///
  /// In vi, this message translates to:
  /// **'ngày muộn'**
  String get dashboardAnalyticsLateDays;

  /// No description provided for @dashboardAnalyticsNoData.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu phân tích'**
  String get dashboardAnalyticsNoData;

  /// No description provided for @dashboardAnalyticsDailyTimeline.
  ///
  /// In vi, this message translates to:
  /// **'Xu hướng giờ công & chi phí theo ngày'**
  String get dashboardAnalyticsDailyTimeline;

  /// No description provided for @dashboardAnalyticsDailyTimelineSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đường liền: giờ công — Đường đứt: chi phí ước tính'**
  String get dashboardAnalyticsDailyTimelineSubtitle;

  /// No description provided for @dashboardAnalyticsHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ công'**
  String get dashboardAnalyticsHours;

  /// No description provided for @dashboardTabDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get dashboardTabDay;

  /// No description provided for @dashboardTabMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get dashboardTabMonth;

  /// No description provided for @dashboardTabRange.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng'**
  String get dashboardTabRange;

  /// No description provided for @dashboardRangeTotalWorkDays.
  ///
  /// In vi, this message translates to:
  /// **'Tổng ngày công'**
  String get dashboardRangeTotalWorkDays;

  /// No description provided for @dashboardRangeTotalLate.
  ///
  /// In vi, this message translates to:
  /// **'Đi muộn'**
  String get dashboardRangeTotalLate;

  /// No description provided for @dashboardRangeTotalAbsent.
  ///
  /// In vi, this message translates to:
  /// **'Vắng mặt'**
  String get dashboardRangeTotalAbsent;

  /// No description provided for @dashboardRangeTotalLeave.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ phép'**
  String get dashboardRangeTotalLeave;

  /// No description provided for @dashboardRangePresent.
  ///
  /// In vi, this message translates to:
  /// **'Có mặt'**
  String get dashboardRangePresent;

  /// No description provided for @dashboardRangeFrom.
  ///
  /// In vi, this message translates to:
  /// **'Từ ngày'**
  String get dashboardRangeFrom;

  /// No description provided for @dashboardRangeTo.
  ///
  /// In vi, this message translates to:
  /// **'Đến ngày'**
  String get dashboardRangeTo;

  /// No description provided for @dashboardRangeNoData.
  ///
  /// In vi, this message translates to:
  /// **'Không có dữ liệu trong khoảng này'**
  String get dashboardRangeNoData;

  /// No description provided for @dashboardTooltipGrade.
  ///
  /// In vi, this message translates to:
  /// **'Cấp'**
  String get dashboardTooltipGrade;

  /// No description provided for @dashboardTooltipHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ'**
  String get dashboardTooltipHours;

  /// No description provided for @dashboardTooltipAmount.
  ///
  /// In vi, this message translates to:
  /// **'Tiền'**
  String get dashboardTooltipAmount;

  /// No description provided for @dashboardTooltipTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng'**
  String get dashboardTooltipTotal;

  /// No description provided for @dashboardTabOverview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get dashboardTabOverview;

  /// No description provided for @dashboardTabAttendance.
  ///
  /// In vi, this message translates to:
  /// **'Chấm công'**
  String get dashboardTabAttendance;

  /// No description provided for @dashboardKpiNewHires.
  ///
  /// In vi, this message translates to:
  /// **'Tuyển mới'**
  String get dashboardKpiNewHires;

  /// No description provided for @dashboardKpiResigned.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ việc'**
  String get dashboardKpiResigned;

  /// No description provided for @dashboardKpiAttendanceRate.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ đi làm'**
  String get dashboardKpiAttendanceRate;

  /// No description provided for @dashboardKpiAttritionRate.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ nghỉ việc'**
  String get dashboardKpiAttritionRate;

  /// No description provided for @dashboardKpiCurrentPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Lương kỳ gần nhất'**
  String get dashboardKpiCurrentPayroll;

  /// No description provided for @dashboardKpiThisMonth.
  ///
  /// In vi, this message translates to:
  /// **'tháng này'**
  String get dashboardKpiThisMonth;

  /// No description provided for @dashboardKpiVsLastMonth.
  ///
  /// In vi, this message translates to:
  /// **'so tháng trước'**
  String get dashboardKpiVsLastMonth;

  /// No description provided for @dashboardKpiNoChange.
  ///
  /// In vi, this message translates to:
  /// **'không đổi'**
  String get dashboardKpiNoChange;

  /// No description provided for @dashboardRisks.
  ///
  /// In vi, this message translates to:
  /// **'Cảnh báo & Rủi ro'**
  String get dashboardRisks;

  /// No description provided for @dashboardRisksRepeatedLate.
  ///
  /// In vi, this message translates to:
  /// **'Đi trễ nhiều lần'**
  String get dashboardRisksRepeatedLate;

  /// No description provided for @dashboardRisksMissingCheckout.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chấm ra'**
  String get dashboardRisksMissingCheckout;

  /// No description provided for @dashboardRisksProbationEnding.
  ///
  /// In vi, this message translates to:
  /// **'Sắp hết thử việc'**
  String get dashboardRisksProbationEnding;

  /// No description provided for @dashboardRisksNoSalaryGrade.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bậc lương'**
  String get dashboardRisksNoSalaryGrade;

  /// No description provided for @dashboardRisksNoWarnings.
  ///
  /// In vi, this message translates to:
  /// **'Không có cảnh báo'**
  String get dashboardRisksNoWarnings;

  /// No description provided for @dashboardRisksTimeThisMonth.
  ///
  /// In vi, this message translates to:
  /// **'{n}× tháng này'**
  String dashboardRisksTimeThisMonth(int n);

  /// No description provided for @dashboardRisksDaysLeft.
  ///
  /// In vi, this message translates to:
  /// **'còn {n} ngày'**
  String dashboardRisksDaysLeft(int n);

  /// No description provided for @dashboardRisksCheckedInAt.
  ///
  /// In vi, this message translates to:
  /// **'Vào: {time}'**
  String dashboardRisksCheckedInAt(String time);

  /// No description provided for @dashboardRisksJoinedOn.
  ///
  /// In vi, this message translates to:
  /// **'Ngày vào: {date}'**
  String dashboardRisksJoinedOn(String date);

  /// No description provided for @dashboardAttendancePeriodWeek.
  ///
  /// In vi, this message translates to:
  /// **'7 ngày qua'**
  String get dashboardAttendancePeriodWeek;

  /// No description provided for @dashboardAttendancePeriodMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng này'**
  String get dashboardAttendancePeriodMonth;

  /// No description provided for @dashboardAttendancePeriodCustom.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng tùy chọn'**
  String get dashboardAttendancePeriodCustom;

  /// No description provided for @unitHour.
  ///
  /// In vi, this message translates to:
  /// **'giờ'**
  String get unitHour;

  /// No description provided for @unitDay.
  ///
  /// In vi, this message translates to:
  /// **'ngày'**
  String get unitDay;

  /// No description provided for @adminTabCompanies.
  ///
  /// In vi, this message translates to:
  /// **'Công ty'**
  String get adminTabCompanies;

  /// No description provided for @adminTabOverview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get adminTabOverview;

  /// No description provided for @adminStatsTotalCompanies.
  ///
  /// In vi, this message translates to:
  /// **'Tổng công ty'**
  String get adminStatsTotalCompanies;

  /// No description provided for @adminStatsActiveCompanies.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoạt động'**
  String get adminStatsActiveCompanies;

  /// No description provided for @adminStatsInactiveCompanies.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt'**
  String get adminStatsInactiveCompanies;

  /// No description provided for @adminStatsTotalEmployees.
  ///
  /// In vi, this message translates to:
  /// **'Tổng nhân viên'**
  String get adminStatsTotalEmployees;

  /// No description provided for @adminStatsTotalUsers.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tài khoản'**
  String get adminStatsTotalUsers;

  /// No description provided for @adminStatsPayrollThisMonth.
  ///
  /// In vi, this message translates to:
  /// **'Bảng lương tháng {month}/{year}'**
  String adminStatsPayrollThisMonth(int month, int year);

  /// No description provided for @adminStatsCompanyGrowth.
  ///
  /// In vi, this message translates to:
  /// **'Tăng trưởng công ty'**
  String get adminStatsCompanyGrowth;

  /// No description provided for @adminStatsPayrollByCompany.
  ///
  /// In vi, this message translates to:
  /// **'Lương theo công ty'**
  String get adminStatsPayrollByCompany;

  /// No description provided for @adminStatsPickMonth.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tháng xem'**
  String get adminStatsPickMonth;

  /// No description provided for @adminStatsNoPayroll.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu lương tháng này'**
  String get adminStatsNoPayroll;

  /// No description provided for @adminStatsMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}/{year}'**
  String adminStatsMonth(int month, int year);

  /// No description provided for @adminStatsEmployees.
  ///
  /// In vi, this message translates to:
  /// **'{count} nhân viên'**
  String adminStatsEmployees(int count);

  /// No description provided for @adminStatsPayrolls.
  ///
  /// In vi, this message translates to:
  /// **'{count} phiếu lương'**
  String adminStatsPayrolls(int count);

  /// No description provided for @adminStatsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải thống kê hệ thống'**
  String get adminStatsLoadError;

  /// No description provided for @adminCompanyCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} công ty'**
  String adminCompanyCount(int count);

  /// No description provided for @excelColEmployeeCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã NV'**
  String get excelColEmployeeCode;

  /// No description provided for @excelColEmployeeFullName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get excelColEmployeeFullName;

  /// No description provided for @excelColEmployeeEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get excelColEmployeeEmail;

  /// No description provided for @excelColEmployeePhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get excelColEmployeePhone;

  /// No description provided for @excelColEmployeeGender.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính'**
  String get excelColEmployeeGender;

  /// No description provided for @excelColEmployeeDateOfBirth.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get excelColEmployeeDateOfBirth;

  /// No description provided for @excelColEmployeeJoinDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày vào làm'**
  String get excelColEmployeeJoinDate;

  /// No description provided for @excelColEmployeeLeaveDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày nghỉ'**
  String get excelColEmployeeLeaveDate;

  /// No description provided for @excelColEmployeeStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get excelColEmployeeStatus;

  /// No description provided for @excelColEmployeeDepartmentCode.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get excelColEmployeeDepartmentCode;

  /// No description provided for @excelColEmployeePositionCode.
  ///
  /// In vi, this message translates to:
  /// **'Chức vụ'**
  String get excelColEmployeePositionCode;

  /// No description provided for @excelColEmployeeSalaryGradeCode.
  ///
  /// In vi, this message translates to:
  /// **'Bậc lương'**
  String get excelColEmployeeSalaryGradeCode;

  /// No description provided for @excelColEmployeeContractSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương hợp đồng'**
  String get excelColEmployeeContractSalary;

  /// No description provided for @excelColEmployeeIdentityCard.
  ///
  /// In vi, this message translates to:
  /// **'CCCD/CMND'**
  String get excelColEmployeeIdentityCard;

  /// No description provided for @excelColEmployeeAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get excelColEmployeeAddress;

  /// No description provided for @excelColEmployeePersonalEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email cá nhân'**
  String get excelColEmployeePersonalEmail;

  /// No description provided for @excelColEmployeeBankAccount.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản NH'**
  String get excelColEmployeeBankAccount;

  /// No description provided for @excelColEmployeeBankName.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng'**
  String get excelColEmployeeBankName;

  /// No description provided for @excelColAttendanceDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày (*)'**
  String get excelColAttendanceDate;

  /// No description provided for @excelColAttendanceEmployeeCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã NV (*)'**
  String get excelColAttendanceEmployeeCode;

  /// No description provided for @excelColAttendanceEmployeeName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get excelColAttendanceEmployeeName;

  /// No description provided for @excelColAttendanceDepartmentName.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get excelColAttendanceDepartmentName;

  /// No description provided for @excelColAttendanceStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get excelColAttendanceStatus;

  /// No description provided for @excelColAttendanceCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Check-in'**
  String get excelColAttendanceCheckIn;

  /// No description provided for @excelColAttendanceCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Check-out'**
  String get excelColAttendanceCheckOut;

  /// No description provided for @excelColAttendanceNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get excelColAttendanceNote;

  /// No description provided for @excelColAttendanceSnapActualHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ thực tế'**
  String get excelColAttendanceSnapActualHours;

  /// No description provided for @excelColAttendanceSnapDayOt.
  ///
  /// In vi, this message translates to:
  /// **'OT ngày'**
  String get excelColAttendanceSnapDayOt;

  /// No description provided for @excelColAttendanceSnapNightOt.
  ///
  /// In vi, this message translates to:
  /// **'OT đêm'**
  String get excelColAttendanceSnapNightOt;

  /// No description provided for @excelColAttendanceApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get excelColAttendanceApproved;

  /// No description provided for @excelColAttendanceOverrideCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Override Check-in'**
  String get excelColAttendanceOverrideCheckIn;

  /// No description provided for @excelColAttendanceOverrideCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Override Check-out'**
  String get excelColAttendanceOverrideCheckOut;

  /// No description provided for @excelColAttendanceOverrideBreakMinutes.
  ///
  /// In vi, this message translates to:
  /// **'Override nghỉ (phút)'**
  String get excelColAttendanceOverrideBreakMinutes;

  /// No description provided for @excelColAttendanceOverrideOtDayMinutes.
  ///
  /// In vi, this message translates to:
  /// **'Override OT ngày (phút)'**
  String get excelColAttendanceOverrideOtDayMinutes;

  /// No description provided for @excelColAttendanceOverrideOtNightMinutes.
  ///
  /// In vi, this message translates to:
  /// **'Override OT đêm (phút)'**
  String get excelColAttendanceOverrideOtNightMinutes;

  /// No description provided for @excelColPayrollYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get excelColPayrollYear;

  /// No description provided for @excelColPayrollMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get excelColPayrollMonth;

  /// No description provided for @excelColPayrollEmployeeCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã NV'**
  String get excelColPayrollEmployeeCode;

  /// No description provided for @excelColPayrollEmployeeName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get excelColPayrollEmployeeName;

  /// No description provided for @excelColPayrollDepartmentName.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get excelColPayrollDepartmentName;

  /// No description provided for @excelColPayrollPositionName.
  ///
  /// In vi, this message translates to:
  /// **'Chức vụ'**
  String get excelColPayrollPositionName;

  /// No description provided for @excelColPayrollSalaryGradeCode.
  ///
  /// In vi, this message translates to:
  /// **'Bậc lương'**
  String get excelColPayrollSalaryGradeCode;

  /// No description provided for @excelColPayrollPayType.
  ///
  /// In vi, this message translates to:
  /// **'Loại tính'**
  String get excelColPayrollPayType;

  /// No description provided for @excelColPayrollBaseSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương cơ bản'**
  String get excelColPayrollBaseSalary;

  /// No description provided for @excelColPayrollAllowance.
  ///
  /// In vi, this message translates to:
  /// **'Trợ cấp'**
  String get excelColPayrollAllowance;

  /// No description provided for @excelColPayrollBonus.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng'**
  String get excelColPayrollBonus;

  /// No description provided for @excelColPayrollOvertimePay.
  ///
  /// In vi, this message translates to:
  /// **'Lương OT'**
  String get excelColPayrollOvertimePay;

  /// No description provided for @excelColPayrollGrossSalary.
  ///
  /// In vi, this message translates to:
  /// **'Gross'**
  String get excelColPayrollGrossSalary;

  /// No description provided for @excelColPayrollSocialInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BHXH'**
  String get excelColPayrollSocialInsurance;

  /// No description provided for @excelColPayrollHealthInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BHYT'**
  String get excelColPayrollHealthInsurance;

  /// No description provided for @excelColPayrollUnemploymentInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BHTN'**
  String get excelColPayrollUnemploymentInsurance;

  /// No description provided for @excelColPayrollPersonalIncomeTax.
  ///
  /// In vi, this message translates to:
  /// **'Thuế TNCN'**
  String get excelColPayrollPersonalIncomeTax;

  /// No description provided for @excelColPayrollOtherDeductions.
  ///
  /// In vi, this message translates to:
  /// **'Khấu trừ khác'**
  String get excelColPayrollOtherDeductions;

  /// No description provided for @excelColPayrollNetSalary.
  ///
  /// In vi, this message translates to:
  /// **'Net (thực lãnh)'**
  String get excelColPayrollNetSalary;

  /// No description provided for @excelColPayrollStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get excelColPayrollStatus;

  /// No description provided for @excelColPayrollNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get excelColPayrollNote;

  /// No description provided for @excelColPayrollPeriodFrom.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ từ ngày'**
  String get excelColPayrollPeriodFrom;

  /// No description provided for @excelColPayrollPeriodTo.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ đến ngày'**
  String get excelColPayrollPeriodTo;

  /// No description provided for @excelColPayrollStandardWorkDays.
  ///
  /// In vi, this message translates to:
  /// **'Ngày công chuẩn'**
  String get excelColPayrollStandardWorkDays;

  /// No description provided for @excelColPayrollPresentDays.
  ///
  /// In vi, this message translates to:
  /// **'Ngày công thực tế'**
  String get excelColPayrollPresentDays;

  /// No description provided for @excelColPayrollDayHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ ngày'**
  String get excelColPayrollDayHours;

  /// No description provided for @excelColPayrollNightHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ đêm'**
  String get excelColPayrollNightHours;

  /// No description provided for @excelColPayrollDayOt.
  ///
  /// In vi, this message translates to:
  /// **'OT ngày'**
  String get excelColPayrollDayOt;

  /// No description provided for @excelColPayrollNightOt.
  ///
  /// In vi, this message translates to:
  /// **'OT đêm'**
  String get excelColPayrollNightOt;

  /// No description provided for @excelFilterDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get excelFilterDepartment;

  /// No description provided for @excelFilterYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get excelFilterYear;

  /// No description provided for @excelFilterMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get excelFilterMonth;

  /// No description provided for @excelFilterStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get excelFilterStatus;

  /// No description provided for @excelFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get excelFilterAll;

  /// No description provided for @notificationSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt thông báo'**
  String get notificationSettings;

  /// No description provided for @shiftReminderTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc nhở ca làm'**
  String get shiftReminderTitle;

  /// No description provided for @shiftReminderDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhận thông báo trước khi ca bắt đầu'**
  String get shiftReminderDesc;

  /// No description provided for @shiftReminderMinutesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc trước (phút)'**
  String get shiftReminderMinutesLabel;

  /// No description provided for @notificationSaveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu cài đặt thông báo'**
  String get notificationSaveSuccess;

  /// No description provided for @errorAttendanceLocationRequired.
  ///
  /// In vi, this message translates to:
  /// **'Công ty yêu cầu GPS để check-in — vui lòng mở app'**
  String get errorAttendanceLocationRequired;

  /// No description provided for @checkInOutNotifTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo check-in / check-out nhanh'**
  String get checkInOutNotifTitle;

  /// No description provided for @checkInOutNotifDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhận nút check-in trước ca và check-out sau ca'**
  String get checkInOutNotifDesc;

  /// No description provided for @checkInOutNotifMinutesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng thời gian (phút)'**
  String get checkInOutNotifMinutesLabel;

  /// No description provided for @minutesBefore.
  ///
  /// In vi, this message translates to:
  /// **'{minutes} phút trước'**
  String minutesBefore(int minutes);

  /// No description provided for @markAllAsRead.
  ///
  /// In vi, this message translates to:
  /// **'Đọc hết'**
  String get markAllAsRead;

  /// No description provided for @noNotificationsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thông báo'**
  String get noNotificationsYet;

  /// No description provided for @impersonationBanner.
  ///
  /// In vi, this message translates to:
  /// **'Đang xem công ty {company} với quyền quản trị hệ thống'**
  String impersonationBanner(String company);

  /// No description provided for @impersonationExit.
  ///
  /// In vi, this message translates to:
  /// **'Thoát'**
  String get impersonationExit;

  /// No description provided for @periodLockButton.
  ///
  /// In vi, this message translates to:
  /// **'Khoá kỳ công'**
  String get periodLockButton;

  /// No description provided for @periodLockTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khoá kỳ công năm {year}'**
  String periodLockTitle(String year);

  /// No description provided for @periodLabel.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ {month}/{year}'**
  String periodLabel(String month, String year);

  /// No description provided for @periodLocked.
  ///
  /// In vi, this message translates to:
  /// **'Đã khoá'**
  String get periodLocked;

  /// No description provided for @periodOpen.
  ///
  /// In vi, this message translates to:
  /// **'Đang mở'**
  String get periodOpen;

  /// No description provided for @periodLockAction.
  ///
  /// In vi, this message translates to:
  /// **'Khoá'**
  String get periodLockAction;

  /// No description provided for @periodUnlockAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở lại'**
  String get periodUnlockAction;

  /// No description provided for @periodLockConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Khoá kỳ {period} ({from} – {to})? Sau khi khoá sẽ không ai sửa được chấm công, đơn từ, nghỉ phép và phân ca trong khoảng này.'**
  String periodLockConfirm(String period, String from, String to);

  /// No description provided for @periodUnlockReasonHint.
  ///
  /// In vi, this message translates to:
  /// **'Lý do mở lại kỳ (bắt buộc)'**
  String get periodUnlockReasonHint;

  /// No description provided for @periodLockedAt.
  ///
  /// In vi, this message translates to:
  /// **'Khoá lúc {time}'**
  String periodLockedAt(String time);

  /// No description provided for @periodReopened.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở lại: {reason}'**
  String periodReopened(String reason);

  /// No description provided for @periodLockDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã khoá kỳ công'**
  String get periodLockDone;

  /// No description provided for @periodUnlockDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở lại kỳ công'**
  String get periodUnlockDone;

  /// No description provided for @leaveRequiresBalance.
  ///
  /// In vi, this message translates to:
  /// **'Trừ vào quỹ phép'**
  String get leaveRequiresBalance;

  /// No description provided for @leaveRequiresBalanceHint.
  ///
  /// In vi, this message translates to:
  /// **'Tắt cho loại nghỉ không giới hạn (nghỉ không lương, ốm, chế độ…): không cần cấp quỹ, không trừ phép'**
  String get leaveRequiresBalanceHint;

  /// No description provided for @leaveNoBalance.
  ///
  /// In vi, this message translates to:
  /// **'Không trừ quỹ'**
  String get leaveNoBalance;

  /// No description provided for @permModuleExcel.
  ///
  /// In vi, this message translates to:
  /// **'Excel tổng hợp'**
  String get permModuleExcel;

  /// No description provided for @permUiAttendanceRecordApprove.
  ///
  /// In vi, this message translates to:
  /// **'Nút duyệt / bỏ duyệt trên bảng công'**
  String get permUiAttendanceRecordApprove;

  /// No description provided for @permDescAttendanceRecordApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt / bỏ duyệt bảng công'**
  String get permDescAttendanceRecordApprove;

  /// No description provided for @permUiAttendancePeriodLock.
  ///
  /// In vi, this message translates to:
  /// **'Nút Khoá kỳ công trên màn Chấm công'**
  String get permUiAttendancePeriodLock;

  /// No description provided for @permDescAttendancePeriodLock.
  ///
  /// In vi, this message translates to:
  /// **'Khoá / mở lại kỳ công'**
  String get permDescAttendancePeriodLock;

  /// No description provided for @permUiExcelExport.
  ///
  /// In vi, this message translates to:
  /// **'Xuất file Excel tổng hợp (chỉ các sheet thuộc module có quyền)'**
  String get permUiExcelExport;

  /// No description provided for @permDescExcelExport.
  ///
  /// In vi, this message translates to:
  /// **'Xuất Excel tổng hợp'**
  String get permDescExcelExport;

  /// No description provided for @permUiExcelImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập file Excel tổng hợp (chỉ các sheet thuộc module có quyền)'**
  String get permUiExcelImport;

  /// No description provided for @permDescExcelImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập Excel tổng hợp'**
  String get permDescExcelImport;

  /// No description provided for @payAddItemTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm {item}'**
  String payAddItemTitle(String item);

  /// No description provided for @payEditItemTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa {item}'**
  String payEditItemTitle(String item);

  /// No description provided for @payAmountExprHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 500000   hoặc   ABSENT_DAYS * 50000'**
  String get payAmountExprHint;

  /// No description provided for @payAmountExprLabel.
  ///
  /// In vi, this message translates to:
  /// **'Biểu thức (số tiền hoặc công thức)'**
  String get payAmountExprLabel;

  /// No description provided for @payCustomVarAddTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm biến tùy chỉnh'**
  String get payCustomVarAddTitle;

  /// No description provided for @payCustomVarEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa biến tùy chỉnh'**
  String get payCustomVarEditTitle;

  /// No description provided for @payHourShort.
  ///
  /// In vi, this message translates to:
  /// **'Giờ'**
  String get payHourShort;

  /// No description provided for @payDayShort.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get payDayShort;

  /// No description provided for @payDeductionDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá khoản khấu trừ \"{name}\"?'**
  String payDeductionDeleteConfirm(String name);

  /// No description provided for @payDeductionItemsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khoản khấu trừ'**
  String get payDeductionItemsTitle;

  /// No description provided for @payDeductionKeyHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: ADVANCE_DEDUCT'**
  String get payDeductionKeyHint;

  /// No description provided for @payDeleteNamed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá {name}'**
  String payDeleteNamed(String name);

  /// No description provided for @payEditNamed.
  ///
  /// In vi, this message translates to:
  /// **'Sửa {name}'**
  String payEditNamed(String name);

  /// No description provided for @payDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Nhân bản'**
  String get payDuplicate;

  /// No description provided for @payExprRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập biểu thức'**
  String get payExprRequired;

  /// No description provided for @payFillAllFields.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng điền đầy đủ'**
  String get payFillAllFields;

  /// No description provided for @payFillAllInfo.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng điền đầy đủ thông tin'**
  String get payFillAllInfo;

  /// No description provided for @payFormulaAddTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm công thức lương'**
  String get payFormulaAddTitle;

  /// No description provided for @payFormulaCustomizeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa công thức lương'**
  String get payFormulaCustomizeTitle;

  /// No description provided for @payFormulaEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa công thức lương'**
  String get payFormulaEditTitle;

  /// No description provided for @payFormulaDuplicateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhân bản công thức lương'**
  String get payFormulaDuplicateTitle;

  /// No description provided for @payFormulaDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá công thức lương \"{name}\"?'**
  String payFormulaDeleteConfirm(String name);

  /// No description provided for @payFormulaEditedName.
  ///
  /// In vi, this message translates to:
  /// **'{name} (đã chỉnh sửa)'**
  String payFormulaEditedName(String name);

  /// No description provided for @payFormulaIncomplete.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập đầy đủ công thức'**
  String get payFormulaIncomplete;

  /// No description provided for @payFormulaInlineNote.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi chỉ áp dụng cho bảng lương này. Công thức gốc không bị ảnh hưởng.'**
  String get payFormulaInlineNote;

  /// No description provided for @payFormulaNameHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Lương tháng — ca ngày'**
  String get payFormulaNameHint;

  /// No description provided for @payFormulaNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên công thức'**
  String get payFormulaNameLabel;

  /// No description provided for @payFormulaNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên công thức'**
  String get payFormulaNameRequired;

  /// No description provided for @payFormulaVarsChipHint.
  ///
  /// In vi, this message translates to:
  /// **'{label} — nhấn chip để chèn vào công thức đang focus'**
  String payFormulaVarsChipHint(String label);

  /// No description provided for @payFromDate.
  ///
  /// In vi, this message translates to:
  /// **'Từ {date}'**
  String payFromDate(String date);

  /// No description provided for @payGlobalVarGroup.
  ///
  /// In vi, this message translates to:
  /// **'Biến Global'**
  String get payGlobalVarGroup;

  /// No description provided for @payGradeDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bậc lương \"{name}\"?'**
  String payGradeDeleteConfirm(String name);

  /// No description provided for @payGradeRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn bậc lương'**
  String get payGradeRequired;

  /// No description provided for @payGrossFormulaHint.
  ///
  /// In vi, this message translates to:
  /// **'Vd: BASE_RATE / 22 * PRESENT_DAYS + DAY_OT * BASE_RATE / 8 * 1.5'**
  String get payGrossFormulaHint;

  /// No description provided for @payNetFormulaHint.
  ///
  /// In vi, this message translates to:
  /// **'Vd: GROSS - GROSS * SOCIAL_INS_RATE - GROSS * HEALTH_INS_RATE'**
  String get payNetFormulaHint;

  /// No description provided for @payGrossVarsHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng tên biến trong công thức Gross để cộng, hiển thị riêng trên phiếu lương'**
  String get payGrossVarsHint;

  /// No description provided for @payNetVarsHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng tên biến trong công thức Net để trừ, hiển thị riêng trên phiếu lương'**
  String get payNetVarsHint;

  /// No description provided for @payHideFromFormula.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn khỏi công thức'**
  String get payHideFromFormula;

  /// No description provided for @payShowInFormula.
  ///
  /// In vi, this message translates to:
  /// **'Hiện trong công thức'**
  String get payShowInFormula;

  /// No description provided for @payInvalidRate.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá không hợp lệ'**
  String get payInvalidRate;

  /// No description provided for @payNameFormatError.
  ///
  /// In vi, this message translates to:
  /// **'Tên phải bắt đầu bằng chữ hoa, chỉ dùng A-Z, 0-9, _'**
  String get payNameFormatError;

  /// No description provided for @payVarNameFormatError.
  ///
  /// In vi, this message translates to:
  /// **'Tên biến phải bắt đầu bằng chữ hoa, chỉ gồm A-Z, 0-9, _'**
  String get payVarNameFormatError;

  /// No description provided for @payNoItems.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có mục nào'**
  String get payNoItems;

  /// No description provided for @payPayslipLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị trên phiếu lương'**
  String get payPayslipLabel;

  /// No description provided for @payPayslipLabelHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Tạm ứng tháng 5'**
  String get payPayslipLabelHint;

  /// No description provided for @payPrivateVarNameHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: HOA_HONG'**
  String get payPrivateVarNameHint;

  /// No description provided for @payPrivateVarExprHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: BASE_RATE * 0.1'**
  String get payPrivateVarExprHint;

  /// No description provided for @payUnderstood.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get payUnderstood;

  /// No description provided for @payUpdateAction.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get payUpdateAction;

  /// No description provided for @payVarCategoryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm / Module (tuỳ chọn)'**
  String get payVarCategoryLabel;

  /// No description provided for @payVarCategoryHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Bảo hiểm, Phụ cấp, Thuế...'**
  String get payVarCategoryHint;

  /// No description provided for @payVarCategoryOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get payVarCategoryOther;

  /// No description provided for @payVarDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá biến \"{name}\"?'**
  String payVarDeleteConfirm(String name);

  /// No description provided for @payVarGroup.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm'**
  String get payVarGroup;

  /// No description provided for @payVarNameExists.
  ///
  /// In vi, this message translates to:
  /// **'Tên biến \"{name}\" đã tồn tại'**
  String payVarNameExists(String name);

  /// No description provided for @payVarNameExistsPlain.
  ///
  /// In vi, this message translates to:
  /// **'Tên biến đã tồn tại'**
  String get payVarNameExistsPlain;

  /// No description provided for @payVarNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên biến'**
  String get payVarNameRequired;

  /// No description provided for @payVarSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm tên, mô tả, biểu thức...'**
  String get payVarSearchHint;

  /// No description provided for @payVarUsedInFormulas.
  ///
  /// In vi, this message translates to:
  /// **'Biến \"{name}\" đang được dùng trong {count} công thức:'**
  String payVarUsedInFormulas(String name, String count);

  /// No description provided for @xlColumnsOfType.
  ///
  /// In vi, this message translates to:
  /// **'{count} cột {type}'**
  String xlColumnsOfType(String count, String type);

  /// No description provided for @xlSelectExportColumns.
  ///
  /// In vi, this message translates to:
  /// **'Chọn cột xuất'**
  String get xlSelectExportColumns;

  /// No description provided for @xlRequiredForReimport.
  ///
  /// In vi, this message translates to:
  /// **'(*) Bắt buộc để import lại được'**
  String get xlRequiredForReimport;

  /// No description provided for @xlNoFilters.
  ///
  /// In vi, this message translates to:
  /// **'Không có bộ lọc'**
  String get xlNoFilters;

  /// No description provided for @xlFilters.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc'**
  String get xlFilters;

  /// No description provided for @xlExportOnlyTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ export, không import'**
  String get xlExportOnlyTooltip;

  /// No description provided for @xlGroupContractSalary.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng & Lương'**
  String get xlGroupContractSalary;

  /// No description provided for @xlGroupComputed.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu tổng hợp'**
  String get xlGroupComputed;

  /// No description provided for @xlGroupOverride.
  ///
  /// In vi, this message translates to:
  /// **'Ghi đè thủ công'**
  String get xlGroupOverride;

  /// No description provided for @xlGroupIdentification.
  ///
  /// In vi, this message translates to:
  /// **'Định danh'**
  String get xlGroupIdentification;

  /// No description provided for @xlGroupDeductions.
  ///
  /// In vi, this message translates to:
  /// **'Khấu trừ & Net'**
  String get xlGroupDeductions;

  /// No description provided for @xlGroupPeriodHours.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ lương & Giờ công'**
  String get xlGroupPeriodHours;

  /// No description provided for @xlFilterStatusInactive.
  ///
  /// In vi, this message translates to:
  /// **'Đã nghỉ'**
  String get xlFilterStatusInactive;

  /// No description provided for @xlFilterHalfDay.
  ///
  /// In vi, this message translates to:
  /// **'Nửa ngày'**
  String get xlFilterHalfDay;

  /// No description provided for @xlFilterPayType.
  ///
  /// In vi, this message translates to:
  /// **'Loại tính lương'**
  String get xlFilterPayType;

  /// No description provided for @xlFilterVariableCategory.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm biến'**
  String get xlFilterVariableCategory;

  /// No description provided for @xlSearchNameOrCode.
  ///
  /// In vi, this message translates to:
  /// **'Tìm tên hoặc mã...'**
  String get xlSearchNameOrCode;

  /// No description provided for @xlErrorsCount.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi ({count})'**
  String xlErrorsCount(String count);

  /// No description provided for @xlWarnEmployeeExistsSkipped.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên đã tồn tại — bỏ qua'**
  String get xlWarnEmployeeExistsSkipped;

  /// No description provided for @xlErrEmployeeNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy nhân viên'**
  String get xlErrEmployeeNotFound;

  /// No description provided for @xlErrEmployeeAlreadyExists.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên đã tồn tại'**
  String get xlErrEmployeeAlreadyExists;

  /// No description provided for @xlChangesCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} thay đổi'**
  String xlChangesCount(String count);

  /// No description provided for @empDeleteSalaryConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá mức lương này?'**
  String get empDeleteSalaryConfirm;

  /// No description provided for @empSalaryMustBePositive.
  ///
  /// In vi, this message translates to:
  /// **'Lương phải > 0'**
  String get empSalaryMustBePositive;

  /// No description provided for @empContractSalaryVnd.
  ///
  /// In vi, this message translates to:
  /// **'Lương hợp đồng (VNĐ)'**
  String get empContractSalaryVnd;

  /// No description provided for @empContractSalaryHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 20000000'**
  String get empContractSalaryHint;

  /// No description provided for @dashDateFromLabel.
  ///
  /// In vi, this message translates to:
  /// **'Từ: {date}'**
  String dashDateFromLabel(String date);

  /// No description provided for @dashDateToLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đến: {date}'**
  String dashDateToLabel(String date);

  /// No description provided for @dashMonthShort.
  ///
  /// In vi, this message translates to:
  /// **'T{month}'**
  String dashMonthShort(String month);

  /// No description provided for @dashMonthYearShort.
  ///
  /// In vi, this message translates to:
  /// **'T{month}/{year}'**
  String dashMonthYearShort(String month, String year);

  /// No description provided for @uiJustNow.
  ///
  /// In vi, this message translates to:
  /// **'Vừa xong'**
  String get uiJustNow;

  /// No description provided for @uiMinutesAgo.
  ///
  /// In vi, this message translates to:
  /// **'{minutes} phút trước'**
  String uiMinutesAgo(String minutes);

  /// No description provided for @uiHoursAgo.
  ///
  /// In vi, this message translates to:
  /// **'{hours} giờ trước'**
  String uiHoursAgo(String hours);

  /// No description provided for @uiDaysAgo.
  ///
  /// In vi, this message translates to:
  /// **'{days} ngày trước'**
  String uiDaysAgo(String days);

  /// No description provided for @uiRowsEditing.
  ///
  /// In vi, this message translates to:
  /// **'{count} hàng đang sửa'**
  String uiRowsEditing(String count);

  /// No description provided for @uiApproveAttendanceConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Phê duyệt chấm công {name} ngày {date}?'**
  String uiApproveAttendanceConfirm(String name, String date);

  /// No description provided for @uiUnapproveAttendanceConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ phê duyệt chấm công {name} ngày {date}? Dữ liệu sẽ được tính toán lại.'**
  String uiUnapproveAttendanceConfirm(String name, String date);

  /// No description provided for @uiToleranceMustBeNonNegative.
  ///
  /// In vi, this message translates to:
  /// **'Dung sai phải là số >= 0'**
  String get uiToleranceMustBeNonNegative;

  /// No description provided for @uiPayrollCutoffDayHelper.
  ///
  /// In vi, this message translates to:
  /// **'1–28. VD: 25 → kỳ tháng 5 = 25/4–24/5'**
  String get uiPayrollCutoffDayHelper;

  /// No description provided for @uiCheckInToleranceMinutes.
  ///
  /// In vi, this message translates to:
  /// **'Dung sai check-in (phút)'**
  String get uiCheckInToleranceMinutes;

  /// No description provided for @uiCheckOutToleranceMinutes.
  ///
  /// In vi, this message translates to:
  /// **'Dung sai check-out (phút)'**
  String get uiCheckOutToleranceMinutes;

  /// No description provided for @uiRoundCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Làm tròn check-in'**
  String get uiRoundCheckIn;

  /// No description provided for @uiRoundCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Làm tròn check-out'**
  String get uiRoundCheckOut;

  /// No description provided for @uiRoundWorkHours.
  ///
  /// In vi, this message translates to:
  /// **'Làm tròn giờ ngày/đêm/OT'**
  String get uiRoundWorkHours;

  /// No description provided for @uiNotApplied.
  ///
  /// In vi, this message translates to:
  /// **'Không áp dụng'**
  String get uiNotApplied;

  /// No description provided for @uiMinutesValue.
  ///
  /// In vi, this message translates to:
  /// **'{minutes} phút'**
  String uiMinutesValue(String minutes);

  /// No description provided for @uiLeaveHistoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử phép — {name}'**
  String uiLeaveHistoryTitle(String name);

  /// No description provided for @uiGrantDate.
  ///
  /// In vi, this message translates to:
  /// **'Cấp ngày'**
  String get uiGrantDate;

  /// No description provided for @uiSource.
  ///
  /// In vi, this message translates to:
  /// **'Nguồn'**
  String get uiSource;

  /// No description provided for @uiGranted.
  ///
  /// In vi, this message translates to:
  /// **'Cấp'**
  String get uiGranted;

  /// No description provided for @uiUsed.
  ///
  /// In vi, this message translates to:
  /// **'Đã dùng'**
  String get uiUsed;

  /// No description provided for @uiRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn lại'**
  String get uiRemaining;

  /// No description provided for @uiManual.
  ///
  /// In vi, this message translates to:
  /// **'Thủ công'**
  String get uiManual;

  /// No description provided for @uiAutomatic.
  ///
  /// In vi, this message translates to:
  /// **'Tự động'**
  String get uiAutomatic;

  /// No description provided for @uiHoursMinutesShort.
  ///
  /// In vi, this message translates to:
  /// **'{hours}h{minutes}p'**
  String uiHoursMinutesShort(String hours, String minutes);

  /// No description provided for @uiCheckResultChannelName.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả check-in/out'**
  String get uiCheckResultChannelName;

  /// No description provided for @uiNotifSessionExpired.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập hết hạn — vui lòng mở app'**
  String get uiNotifSessionExpired;

  /// No description provided for @uiNotifCheckInSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Check-in thành công!'**
  String get uiNotifCheckInSuccess;

  /// No description provided for @uiNotifCheckOutSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Check-out thành công!'**
  String get uiNotifCheckOutSuccess;

  /// No description provided for @uiNotifConnectionError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi kết nối — vui lòng kiểm tra trong app'**
  String get uiNotifConnectionError;

  /// No description provided for @uiNotifOpenAndCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Mở & Check-in'**
  String get uiNotifOpenAndCheckIn;

  /// No description provided for @uiNotifOpenAndCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Mở & Check-out'**
  String get uiNotifOpenAndCheckOut;

  /// No description provided for @uiNotifGpsRequiredCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Công ty yêu cầu GPS — nhấn để check-in ngay khi mở app'**
  String get uiNotifGpsRequiredCheckIn;

  /// No description provided for @uiNotifGpsRequiredCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Công ty yêu cầu GPS — nhấn để check-out ngay khi mở app'**
  String get uiNotifGpsRequiredCheckOut;

  /// No description provided for @uiNotifCheckInFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể check-in'**
  String get uiNotifCheckInFailed;

  /// No description provided for @uiNotifCheckOutFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể check-out'**
  String get uiNotifCheckOutFailed;

  /// No description provided for @shiftTypeFixed.
  ///
  /// In vi, this message translates to:
  /// **'Giờ cố định'**
  String get shiftTypeFixed;

  /// No description provided for @shiftTypeFlexible.
  ///
  /// In vi, this message translates to:
  /// **'Linh hoạt'**
  String get shiftTypeFlexible;

  /// No description provided for @shiftFlexibleHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên vào/ra lúc nào cũng được trong khung giờ bên dưới, chỉ cần làm đủ số giờ. Làm thiếu giờ được tính là đi muộn.'**
  String get shiftFlexibleHint;

  /// No description provided for @shiftRequiredHoursLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số giờ phải làm'**
  String get shiftRequiredHoursLabel;

  /// No description provided for @shiftRequiredHoursInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số giờ từ 0 đến 24'**
  String get shiftRequiredHoursInvalid;

  /// No description provided for @shiftFlexibleWindow.
  ///
  /// In vi, this message translates to:
  /// **'Linh hoạt trong khung {window}'**
  String shiftFlexibleWindow(String window);

  /// No description provided for @rotationTab.
  ///
  /// In vi, this message translates to:
  /// **'Xoay ca'**
  String get rotationTab;

  /// No description provided for @rotationIntro.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu xoay ca: chu kỳ các ngày, mỗi ngày một hoặc nhiều ca hoặc nghỉ. Áp dụng để tự sinh phân ca cho nhiều nhân viên.'**
  String get rotationIntro;

  /// No description provided for @rotationAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm mẫu xoay'**
  String get rotationAdd;

  /// No description provided for @rotationEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa mẫu xoay'**
  String get rotationEdit;

  /// No description provided for @rotationEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có mẫu xoay ca'**
  String get rotationEmpty;

  /// No description provided for @rotationName.
  ///
  /// In vi, this message translates to:
  /// **'Tên mẫu'**
  String get rotationName;

  /// No description provided for @rotationDaysHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ca cho từng ngày trong chu kỳ; không chọn ca nào = ngày nghỉ.'**
  String get rotationDaysHint;

  /// No description provided for @rotationDayN.
  ///
  /// In vi, this message translates to:
  /// **'Ngày {n}'**
  String rotationDayN(String n);

  /// No description provided for @rotationDayOff.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ'**
  String get rotationDayOff;

  /// No description provided for @rotationAddDay.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ngày'**
  String get rotationAddDay;

  /// No description provided for @rotationCycleDays.
  ///
  /// In vi, this message translates to:
  /// **'Chu kỳ {n} ngày'**
  String rotationCycleDays(String n);

  /// No description provided for @rotationNeedNameAndShift.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên và chọn ít nhất một ca'**
  String get rotationNeedNameAndShift;

  /// No description provided for @rotationDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá mẫu xoay ca'**
  String get rotationDeleteTitle;

  /// No description provided for @rotationDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá mẫu \"{name}\"? Phân ca đã sinh không bị ảnh hưởng.'**
  String rotationDeleteConfirm(String name);

  /// No description provided for @rotationApply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng cho nhân viên'**
  String get rotationApply;

  /// No description provided for @rotationApplyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng mẫu \"{name}\"'**
  String rotationApplyTitle(String name);

  /// No description provided for @rotationStartAt.
  ///
  /// In vi, this message translates to:
  /// **'Ngày bắt đầu ứng với'**
  String get rotationStartAt;

  /// No description provided for @rotationStagger.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi người sau lệch'**
  String get rotationStagger;

  /// No description provided for @rotationStaggerNone.
  ///
  /// In vi, this message translates to:
  /// **'Không lệch'**
  String get rotationStaggerNone;

  /// No description provided for @rotationStaggerDays.
  ///
  /// In vi, this message translates to:
  /// **'{n} ngày'**
  String rotationStaggerDays(String n);

  /// No description provided for @rotationSelectedCount.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn {n} người'**
  String rotationSelectedCount(String n);

  /// No description provided for @rotationOrderHint.
  ///
  /// In vi, this message translates to:
  /// **'Thứ tự chọn quyết định độ lệch: người chọn trước lệch ít hơn. Ngày đã có chấm công được giữ nguyên.'**
  String get rotationOrderHint;

  /// No description provided for @rotationResultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả áp dụng mẫu'**
  String get rotationResultTitle;

  /// No description provided for @rotationResultSummary.
  ///
  /// In vi, this message translates to:
  /// **'Đã xếp {assigned} ngày, bỏ ca {cleared} ngày nghỉ, giữ nguyên {unchanged} ngày.'**
  String rotationResultSummary(
      String assigned, String cleared, String unchanged);

  /// No description provided for @rotationResultConflicts.
  ///
  /// In vi, this message translates to:
  /// **'{n} ngày không xếp được:'**
  String rotationResultConflicts(String n);

  /// No description provided for @swapMenu.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ca'**
  String get swapMenu;

  /// No description provided for @swapCreate.
  ///
  /// In vi, this message translates to:
  /// **'Xin đổi / nhường ca'**
  String get swapCreate;

  /// No description provided for @swapEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu đổi ca'**
  String get swapEmpty;

  /// No description provided for @swapMyShift.
  ///
  /// In vi, this message translates to:
  /// **'Ca của tôi'**
  String get swapMyShift;

  /// No description provided for @swapNoUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không có ca sắp tới nào có thể đổi'**
  String get swapNoUpcoming;

  /// No description provided for @swapPickColleague.
  ///
  /// In vi, this message translates to:
  /// **'Chọn đồng nghiệp'**
  String get swapPickColleague;

  /// No description provided for @swapGiveOption.
  ///
  /// In vi, this message translates to:
  /// **'Nhường ca này cho người này'**
  String get swapGiveOption;

  /// No description provided for @swapWithShift.
  ///
  /// In vi, this message translates to:
  /// **'Đổi lấy ca {shift}'**
  String swapWithShift(String shift);

  /// No description provided for @swapSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu'**
  String get swapSend;

  /// No description provided for @swapSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu, chờ quản lý duyệt'**
  String get swapSent;

  /// No description provided for @swapGiveTitle.
  ///
  /// In vi, this message translates to:
  /// **'{from} nhường ca cho {to}'**
  String swapGiveTitle(String from, String to);

  /// No description provided for @swapSwapTitle.
  ///
  /// In vi, this message translates to:
  /// **'{from} đổi ca với {to}'**
  String swapSwapTitle(String from, String to);

  /// No description provided for @swapReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get swapReject;

  /// No description provided for @swapRejectTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối yêu cầu đổi ca'**
  String get swapRejectTitle;

  /// No description provided for @swapApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt, phân ca đã được đổi'**
  String get swapApproved;

  /// No description provided for @swapRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get swapRejected;

  /// No description provided for @swapCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ yêu cầu'**
  String get swapCancelled;

  /// No description provided for @permUiShiftSwapApprove.
  ///
  /// In vi, this message translates to:
  /// **'Nút duyệt / từ chối trên màn Đổi ca'**
  String get permUiShiftSwapApprove;

  /// No description provided for @permDescShiftSwapApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt yêu cầu đổi ca / nhường ca'**
  String get permDescShiftSwapApprove;

  /// No description provided for @deviceBindingEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ chấm công trên thiết bị đã gắn'**
  String get deviceBindingEnabled;

  /// No description provided for @deviceBindingHint.
  ///
  /// In vi, this message translates to:
  /// **'Lần chấm công đầu tiên tự gắn điện thoại đang dùng; đổi máy thì quản lý gỡ gắn trong hồ sơ nhân viên.'**
  String get deviceBindingHint;

  /// No description provided for @deviceBoundLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã gắn thiết bị chấm công'**
  String get deviceBoundLabel;

  /// No description provided for @deviceNotBoundLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chưa gắn thiết bị chấm công'**
  String get deviceNotBoundLabel;

  /// No description provided for @deviceBoundSince.
  ///
  /// In vi, this message translates to:
  /// **'Gắn lúc {time}'**
  String deviceBoundSince(String time);

  /// No description provided for @deviceUnbind.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ thiết bị'**
  String get deviceUnbind;

  /// No description provided for @deviceUnbound.
  ///
  /// In vi, this message translates to:
  /// **'Đã gỡ thiết bị, lần chấm công sau sẽ gắn máy mới'**
  String get deviceUnbound;

  /// No description provided for @forceChangePasswordTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu lần đầu'**
  String get forceChangePasswordTitle;

  /// No description provided for @forceChangePasswordDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu của bạn do quản trị viên đặt. Vui lòng đặt mật khẩu mới để tiếp tục sử dụng.'**
  String get forceChangePasswordDesc;

  /// No description provided for @passwordPolicyHint.
  ///
  /// In vi, this message translates to:
  /// **'Ít nhất 8 ký tự, gồm cả chữ và số'**
  String get passwordPolicyHint;

  /// No description provided for @passwordSameAsCurrent.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới phải khác mật khẩu hiện tại'**
  String get passwordSameAsCurrent;

  /// No description provided for @leaveCommonPool.
  ///
  /// In vi, this message translates to:
  /// **'Quỹ chung'**
  String get leaveCommonPool;

  /// No description provided for @leaveGrantTypeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Quỹ cho loại phép'**
  String get leaveGrantTypeLabel;

  /// No description provided for @leaveCommonPoolHint.
  ///
  /// In vi, this message translates to:
  /// **'Quỹ chung (dùng cho mọi loại trừ quỹ)'**
  String get leaveCommonPoolHint;

  /// No description provided for @leaveLedgerTab.
  ///
  /// In vi, this message translates to:
  /// **'Sổ trừ/hoàn'**
  String get leaveLedgerTab;

  /// No description provided for @leaveGrantsTab.
  ///
  /// In vi, this message translates to:
  /// **'Các đợt cấp'**
  String get leaveGrantsTab;

  /// No description provided for @leaveLedgerDeduct.
  ///
  /// In vi, this message translates to:
  /// **'Trừ'**
  String get leaveLedgerDeduct;

  /// No description provided for @leaveLedgerRefund.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn'**
  String get leaveLedgerRefund;

  /// No description provided for @leaveLedgerRequest.
  ///
  /// In vi, this message translates to:
  /// **'Đơn {type} {range}'**
  String leaveLedgerRequest(String type, String range);

  /// No description provided for @leaveLedgerPool.
  ///
  /// In vi, this message translates to:
  /// **'Quỹ: {pool} (cấp {date})'**
  String leaveLedgerPool(String pool, String date);

  /// No description provided for @formulaDeductionRest.
  ///
  /// In vi, this message translates to:
  /// **'Bảo hiểm, thuế & khoản trừ theo công thức'**
  String get formulaDeductionRest;

  /// No description provided for @auditActAttendanceApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt công'**
  String get auditActAttendanceApprove;

  /// No description provided for @auditActAttendanceUnapprove.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ duyệt công'**
  String get auditActAttendanceUnapprove;

  /// No description provided for @auditActAttendanceOverride.
  ///
  /// In vi, this message translates to:
  /// **'Sửa giờ công'**
  String get auditActAttendanceOverride;

  /// No description provided for @auditActAttendanceDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bản ghi công'**
  String get auditActAttendanceDelete;

  /// No description provided for @auditActAttendanceManualCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Chấm vào hộ'**
  String get auditActAttendanceManualCheckIn;

  /// No description provided for @auditActAttendanceManualCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Chấm ra hộ'**
  String get auditActAttendanceManualCheckOut;

  /// No description provided for @auditActAttendanceImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập chấm công từ Excel'**
  String get auditActAttendanceImport;

  /// No description provided for @auditActAttendanceImportTimesheet.
  ///
  /// In vi, this message translates to:
  /// **'Nhập bảng công từ Excel'**
  String get auditActAttendanceImportTimesheet;

  /// No description provided for @auditActAttendanceRequestApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt đơn sửa giờ'**
  String get auditActAttendanceRequestApprove;

  /// No description provided for @auditActAttendanceRequestReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối đơn sửa giờ'**
  String get auditActAttendanceRequestReject;

  /// No description provided for @auditActPeriodLock.
  ///
  /// In vi, this message translates to:
  /// **'Khoá kỳ công'**
  String get auditActPeriodLock;

  /// No description provided for @auditActPeriodUnlock.
  ///
  /// In vi, this message translates to:
  /// **'Mở lại kỳ công'**
  String get auditActPeriodUnlock;

  /// No description provided for @auditActPayrollGenerate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo bảng lương'**
  String get auditActPayrollGenerate;

  /// No description provided for @auditActPayrollUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa bảng lương nháp'**
  String get auditActPayrollUpdate;

  /// No description provided for @auditActPayrollRecalculate.
  ///
  /// In vi, this message translates to:
  /// **'Tính lại lương'**
  String get auditActPayrollRecalculate;

  /// No description provided for @auditActPayrollApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt lương'**
  String get auditActPayrollApprove;

  /// No description provided for @auditActPayrollPay.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu đã trả lương'**
  String get auditActPayrollPay;

  /// No description provided for @auditActPayrollDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bảng lương nháp'**
  String get auditActPayrollDelete;

  /// No description provided for @auditActRoleCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo vai trò'**
  String get auditActRoleCreate;

  /// No description provided for @auditActRoleUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa vai trò'**
  String get auditActRoleUpdate;

  /// No description provided for @auditActRolePermissions.
  ///
  /// In vi, this message translates to:
  /// **'Đổi quyền vai trò'**
  String get auditActRolePermissions;

  /// No description provided for @auditActRoleDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá vai trò'**
  String get auditActRoleDelete;

  /// No description provided for @auditActUserCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get auditActUserCreate;

  /// No description provided for @auditActUserSyncFromEmployees.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản hàng loạt'**
  String get auditActUserSyncFromEmployees;

  /// No description provided for @auditActUserRoles.
  ///
  /// In vi, this message translates to:
  /// **'Đổi vai trò tài khoản'**
  String get auditActUserRoles;

  /// No description provided for @auditActUserPermissions.
  ///
  /// In vi, this message translates to:
  /// **'Đổi quyền riêng tài khoản'**
  String get auditActUserPermissions;

  /// No description provided for @auditActUserDeptScopes.
  ///
  /// In vi, this message translates to:
  /// **'Đổi phạm vi quyền'**
  String get auditActUserDeptScopes;

  /// No description provided for @auditActUserEnable.
  ///
  /// In vi, this message translates to:
  /// **'Mở khoá tài khoản'**
  String get auditActUserEnable;

  /// No description provided for @auditActUserDisable.
  ///
  /// In vi, this message translates to:
  /// **'Khoá tài khoản'**
  String get auditActUserDisable;

  /// No description provided for @auditActDeviceUnbind.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ thiết bị chấm công'**
  String get auditActDeviceUnbind;

  /// No description provided for @auditActImpersonateStart.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị hệ thống truy cập công ty'**
  String get auditActImpersonateStart;

  /// No description provided for @auditActCompanyCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo công ty'**
  String get auditActCompanyCreate;

  /// No description provided for @auditActCompanyUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa công ty'**
  String get auditActCompanyUpdate;

  /// No description provided for @auditActCompanyToggleActive.
  ///
  /// In vi, this message translates to:
  /// **'Bật/tắt công ty'**
  String get auditActCompanyToggleActive;

  /// No description provided for @auditLogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhật ký thao tác'**
  String get auditLogTitle;

  /// No description provided for @auditAllActions.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả thao tác'**
  String get auditAllActions;

  /// No description provided for @auditActorFilter.
  ///
  /// In vi, this message translates to:
  /// **'Người thực hiện (email)'**
  String get auditActorFilter;

  /// No description provided for @auditImpersonated.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị hệ thống'**
  String get auditImpersonated;

  /// No description provided for @auditDetail.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết'**
  String get auditDetail;

  /// No description provided for @auditRequestId.
  ///
  /// In vi, this message translates to:
  /// **'Mã request: {id}'**
  String auditRequestId(String id);

  /// No description provided for @auditIp.
  ///
  /// In vi, this message translates to:
  /// **'IP: {ip}'**
  String auditIp(String ip);

  /// No description provided for @auditLoadMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm'**
  String get auditLoadMore;

  /// No description provided for @auditEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thao tác nào trong khoảng này'**
  String get auditEmpty;

  /// No description provided for @permUiAuditView.
  ///
  /// In vi, this message translates to:
  /// **'Mở màn Nhật ký thao tác'**
  String get permUiAuditView;

  /// No description provided for @permDescAuditView.
  ///
  /// In vi, this message translates to:
  /// **'Xem nhật ký thao tác (ai sửa công, duyệt lương, đổi quyền…)'**
  String get permDescAuditView;

  /// No description provided for @bulkApproveMonthButton.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt cả kỳ'**
  String get bulkApproveMonthButton;

  /// No description provided for @bulkApproveMonthTitle.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt công cả kỳ'**
  String get bulkApproveMonthTitle;

  /// No description provided for @bulkApproveMonthDesc.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt mọi ca chưa duyệt của các ngày đã qua trong kỳ, theo phòng ban đã chọn. Bỏ qua hôm nay và các ngày sau, dòng chấm thiếu giờ ra/vào (duyệt từng dòng sau khi kiểm tra), công của chính bạn, kỳ đã khoá và ngày không có ca.'**
  String get bulkApproveMonthDesc;

  /// No description provided for @bulkApprovePeriod.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ công'**
  String get bulkApprovePeriod;

  /// No description provided for @bulkApproveAllDepartments.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả phòng ban trong phạm vi'**
  String get bulkApproveAllDepartments;

  /// No description provided for @bulkApproveRun.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get bulkApproveRun;

  /// No description provided for @bulkApproveRunning.
  ///
  /// In vi, this message translates to:
  /// **'Đang duyệt… (có thể mất tới 1 phút)'**
  String get bulkApproveRunning;

  /// No description provided for @bulkApproveResult.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt {approved} · đã duyệt trước {already} · chưa hết ngày {notEnded} · chấm thiếu giờ ra/vào {incomplete} · kỳ khoá {locked} · lỗi {failed}'**
  String bulkApproveResult(String approved, String already, String locked,
      String failed, String notEnded, String incomplete);

  /// No description provided for @bulkApproveErrors.
  ///
  /// In vi, this message translates to:
  /// **'Các dòng lỗi'**
  String get bulkApproveErrors;

  /// No description provided for @auditActAttendanceBulkApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt công hàng loạt'**
  String get auditActAttendanceBulkApprove;

  /// No description provided for @twoFactorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác thực 2 lớp'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorSetupDesc.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã QR bằng ứng dụng xác thực (Google Authenticator, Microsoft Authenticator…), rồi nhập mã 6 số đang hiện.'**
  String get twoFactorSetupDesc;

  /// No description provided for @twoFactorVerifyDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã 6 số trong ứng dụng xác thực.'**
  String get twoFactorVerifyDesc;

  /// No description provided for @twoFactorManualKey.
  ///
  /// In vi, this message translates to:
  /// **'Không quét được? Nhập khoá này vào ứng dụng:'**
  String get twoFactorManualKey;

  /// No description provided for @twoFactorCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã xác thực'**
  String get twoFactorCodeLabel;

  /// No description provided for @twoFactorRecoveryHint.
  ///
  /// In vi, this message translates to:
  /// **'Mất điện thoại? Nhập một mã dự phòng'**
  String get twoFactorRecoveryHint;

  /// No description provided for @twoFactorEnableButton.
  ///
  /// In vi, this message translates to:
  /// **'Bật xác thực 2 lớp'**
  String get twoFactorEnableButton;

  /// No description provided for @twoFactorVerifyButton.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get twoFactorVerifyButton;

  /// No description provided for @twoFactorDisableButton.
  ///
  /// In vi, this message translates to:
  /// **'Tắt xác thực 2 lớp'**
  String get twoFactorDisableButton;

  /// No description provided for @twoFactorRecoveryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu mã dự phòng'**
  String get twoFactorRecoveryTitle;

  /// No description provided for @twoFactorRecoveryDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi mã dùng được một lần khi mất điện thoại. Mã chỉ hiện lúc này — hãy chép lại và cất ở nơi an toàn.'**
  String get twoFactorRecoveryDesc;

  /// No description provided for @twoFactorCopyCodes.
  ///
  /// In vi, this message translates to:
  /// **'Chép mã'**
  String get twoFactorCopyCodes;

  /// No description provided for @twoFactorSavedContinue.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu, tiếp tục'**
  String get twoFactorSavedContinue;

  /// No description provided for @twoFactorOn.
  ///
  /// In vi, this message translates to:
  /// **'Đang bật'**
  String get twoFactorOn;

  /// No description provided for @twoFactorOff.
  ///
  /// In vi, this message translates to:
  /// **'Đang tắt'**
  String get twoFactorOff;

  /// No description provided for @twoFactorProfileDesc.
  ///
  /// In vi, this message translates to:
  /// **'Khi bật, đăng nhập cần thêm mã từ ứng dụng xác thực trên điện thoại.'**
  String get twoFactorProfileDesc;

  /// No description provided for @twoFactorCodesLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {count} mã dự phòng'**
  String twoFactorCodesLeft(String count);

  /// No description provided for @twoFactorRequiredByCompany.
  ///
  /// In vi, this message translates to:
  /// **'Công ty bắt buộc quản trị dùng xác thực 2 lớp.'**
  String get twoFactorRequiredByCompany;

  /// No description provided for @twoFactorDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt xác thực 2 lớp'**
  String get twoFactorDisabled;

  /// No description provided for @twoFactorResetTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ xác thực 2 lớp'**
  String get twoFactorResetTooltip;

  /// No description provided for @twoFactorResetConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ xác thực 2 lớp của {name}? Lần đăng nhập tới chỉ cần mật khẩu; họ có thể bật lại trong Hồ sơ.'**
  String twoFactorResetConfirm(String name);

  /// No description provided for @twoFactorCompanyRequiredOn.
  ///
  /// In vi, this message translates to:
  /// **'Đang bắt buộc quản trị dùng 2FA — bấm để bỏ'**
  String get twoFactorCompanyRequiredOn;

  /// No description provided for @twoFactorCompanyRequiredOff.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc quản trị dùng 2FA'**
  String get twoFactorCompanyRequiredOff;

  /// No description provided for @auditAct2faEnable.
  ///
  /// In vi, this message translates to:
  /// **'Bật xác thực 2 lớp'**
  String get auditAct2faEnable;

  /// No description provided for @auditAct2faDisable.
  ///
  /// In vi, this message translates to:
  /// **'Tắt xác thực 2 lớp'**
  String get auditAct2faDisable;

  /// No description provided for @auditAct2faReset.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ xác thực 2 lớp của người khác'**
  String get auditAct2faReset;

  /// No description provided for @auditActCompanyRequire2fa.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc 2FA cho quản trị'**
  String get auditActCompanyRequire2fa;

  /// No description provided for @adminTabTrialRequests.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu dùng thử'**
  String get adminTabTrialRequests;

  /// No description provided for @trialStatusNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get trialStatusNew;

  /// No description provided for @trialStatusContacted.
  ///
  /// In vi, this message translates to:
  /// **'Đã liên hệ'**
  String get trialStatusContacted;

  /// No description provided for @trialStatusTrial.
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng thử'**
  String get trialStatusTrial;

  /// No description provided for @trialStatusRejected.
  ///
  /// In vi, this message translates to:
  /// **'Không phù hợp'**
  String get trialStatusRejected;

  /// No description provided for @trialSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tên, công ty, điện thoại, email'**
  String get trialSearchHint;

  /// No description provided for @trialEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu dùng thử nào'**
  String get trialEmpty;

  /// No description provided for @trialEmployees.
  ///
  /// In vi, this message translates to:
  /// **'{size} nhân viên'**
  String trialEmployees(String size);

  /// No description provided for @trialNoteLine.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú: {note} — {by}'**
  String trialNoteLine(String note, String by);

  /// No description provided for @trialStatusLabel.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get trialStatusLabel;

  /// No description provided for @trialNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú xử lý'**
  String get trialNote;

  /// No description provided for @auditActTrialRequestUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Xử lý yêu cầu dùng thử'**
  String get auditActTrialRequestUpdate;

  /// No description provided for @adminTabSystemAdmins.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị viên'**
  String get adminTabSystemAdmins;

  /// No description provided for @sysAdminIntro.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản quản trị hệ thống (trang /admin). Mật khẩu do hệ thống tạo và chỉ hiện một lần; lần đăng nhập đầu phải cài xác thực 2 lớp.'**
  String get sysAdminIntro;

  /// No description provided for @sysAdminAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm quản trị viên'**
  String get sysAdminAdd;

  /// No description provided for @sysAdminAddNote.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu sẽ được tạo tự động và hiện một lần sau khi tạo.'**
  String get sysAdminAddNote;

  /// No description provided for @sysAdminCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get sysAdminCreate;

  /// No description provided for @sysAdminPasswordTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu đăng nhập'**
  String get sysAdminPasswordTitle;

  /// No description provided for @sysAdminPasswordDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu cho {email}. Chép lại và gửi riêng cho người dùng — mật khẩu chỉ hiện lần này.'**
  String sysAdminPasswordDesc(String email);

  /// No description provided for @sysAdminCopyPassword.
  ///
  /// In vi, this message translates to:
  /// **'Chép mật khẩu'**
  String get sysAdminCopyPassword;

  /// No description provided for @sysAdminYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get sysAdminYou;

  /// No description provided for @sysAdmin2faOn.
  ///
  /// In vi, this message translates to:
  /// **'Đã cài 2FA'**
  String get sysAdmin2faOn;

  /// No description provided for @sysAdmin2faPending.
  ///
  /// In vi, this message translates to:
  /// **'Chưa cài 2FA'**
  String get sysAdmin2faPending;

  /// No description provided for @sysAdminResetPassword.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại mật khẩu'**
  String get sysAdminResetPassword;

  /// No description provided for @sysAdminDisableConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Khoá tài khoản {email}? Người này sẽ không đăng nhập được nữa.'**
  String sysAdminDisableConfirm(String email);

  /// No description provided for @sysAdminResetPasswordConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Tạo mật khẩu mới cho {email}? Mật khẩu cũ sẽ không dùng được.'**
  String sysAdminResetPasswordConfirm(String email);

  /// No description provided for @sysAdminReset2faConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ xác thực 2 lớp của {email}? Lần đăng nhập tới họ phải cài lại.'**
  String sysAdminReset2faConfirm(String email);

  /// No description provided for @auditActSysadminCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm quản trị viên hệ thống'**
  String get auditActSysadminCreate;

  /// No description provided for @auditActSysadminEnable.
  ///
  /// In vi, this message translates to:
  /// **'Mở khoá quản trị viên hệ thống'**
  String get auditActSysadminEnable;

  /// No description provided for @auditActSysadminDisable.
  ///
  /// In vi, this message translates to:
  /// **'Khoá quản trị viên hệ thống'**
  String get auditActSysadminDisable;

  /// No description provided for @auditActSysadminResetPassword.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại mật khẩu quản trị viên'**
  String get auditActSysadminResetPassword;

  /// No description provided for @auditActSysadminReset2fa.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ 2FA quản trị viên'**
  String get auditActSysadminReset2fa;

  /// No description provided for @profileAccountTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get profileAccountTitle;

  /// No description provided for @profileNoEmployeeNote.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản quản trị không gắn với hồ sơ nhân viên — chỉ có phần bảo mật đăng nhập.'**
  String get profileNoEmployeeNote;

  /// No description provided for @adminTabTaxPolicies.
  ///
  /// In vi, this message translates to:
  /// **'Thuế & BH'**
  String get adminTabTaxPolicies;

  /// No description provided for @taxPolicyIntro.
  ///
  /// In vi, this message translates to:
  /// **'Thông số thuế TNCN và bảo hiểm dùng chung cho mọi công ty. Bảng lương mỗi kỳ dùng chính sách có ngày hiệu lực gần nhất trước ngày cuối kỳ; phiếu đã duyệt không đổi.'**
  String get taxPolicyIntro;

  /// No description provided for @taxPolicyAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chính sách'**
  String get taxPolicyAdd;

  /// No description provided for @taxPolicyEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa chính sách'**
  String get taxPolicyEdit;

  /// No description provided for @taxPolicyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có chính sách thuế nào — bảng lương sẽ không tính được.'**
  String get taxPolicyEmpty;

  /// No description provided for @taxPolicyCurrent.
  ///
  /// In vi, this message translates to:
  /// **'Đang áp dụng'**
  String get taxPolicyCurrent;

  /// No description provided for @taxPolicyFrom.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu lực từ {date}'**
  String taxPolicyFrom(String date);

  /// No description provided for @taxPolicyDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá chính sách hiệu lực từ {date}? Các kỳ lương sau ngày này sẽ dùng chính sách trước đó khi tính lại.'**
  String taxPolicyDeleteConfirm(String date);

  /// No description provided for @taxPolicyUpdatedBy.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật bởi {by}'**
  String taxPolicyUpdatedBy(String by);

  /// No description provided for @taxPersonalDeduction.
  ///
  /// In vi, this message translates to:
  /// **'Giảm trừ bản thân / tháng'**
  String get taxPersonalDeduction;

  /// No description provided for @taxDependentDeduction.
  ///
  /// In vi, this message translates to:
  /// **'Giảm trừ mỗi người phụ thuộc / tháng'**
  String get taxDependentDeduction;

  /// No description provided for @taxBrackets.
  ///
  /// In vi, this message translates to:
  /// **'Biểu thuế lũy tiến'**
  String get taxBrackets;

  /// No description provided for @taxBracketsHint.
  ///
  /// In vi, this message translates to:
  /// **'Theo thu nhập tính thuế mỗi tháng; bậc cuối áp cho phần còn lại.'**
  String get taxBracketsHint;

  /// No description provided for @taxBracketUpTo.
  ///
  /// In vi, this message translates to:
  /// **'đến {amount}: {rate}'**
  String taxBracketUpTo(String amount, String rate);

  /// No description provided for @taxBracketAbove.
  ///
  /// In vi, this message translates to:
  /// **'trên {amount}: {rate}'**
  String taxBracketAbove(String amount, String rate);

  /// No description provided for @taxBracketUpToLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đến (thu nhập tính thuế)'**
  String get taxBracketUpToLabel;

  /// No description provided for @taxBracketRest.
  ///
  /// In vi, this message translates to:
  /// **'Phần còn lại'**
  String get taxBracketRest;

  /// No description provided for @taxBracketRate.
  ///
  /// In vi, this message translates to:
  /// **'Thuế suất'**
  String get taxBracketRate;

  /// No description provided for @taxBracketAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm bậc'**
  String get taxBracketAdd;

  /// No description provided for @taxReferenceWage.
  ///
  /// In vi, this message translates to:
  /// **'Mức tham chiếu (lương cơ sở)'**
  String get taxReferenceWage;

  /// No description provided for @taxInsuranceCap.
  ///
  /// In vi, this message translates to:
  /// **'trần BHXH/BHYT {amount} ({multiplier} ×)'**
  String taxInsuranceCap(String amount, String multiplier);

  /// No description provided for @taxCapMultiplier.
  ///
  /// In vi, this message translates to:
  /// **'Trần BHXH/BHYT'**
  String get taxCapMultiplier;

  /// No description provided for @taxMinWages.
  ///
  /// In vi, this message translates to:
  /// **'Lương tối thiểu vùng'**
  String get taxMinWages;

  /// No description provided for @taxUnemploymentCap.
  ///
  /// In vi, this message translates to:
  /// **'Trần BHTN'**
  String get taxUnemploymentCap;

  /// No description provided for @taxUnemploymentCapValue.
  ///
  /// In vi, this message translates to:
  /// **'{multiplier} × lương tối thiểu vùng của công ty'**
  String taxUnemploymentCapValue(String multiplier);

  /// No description provided for @taxUnemploymentCapMultiplier.
  ///
  /// In vi, this message translates to:
  /// **'Trần BHTN (× lương tối thiểu vùng)'**
  String get taxUnemploymentCapMultiplier;

  /// No description provided for @taxPolicyNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú / căn cứ pháp lý'**
  String get taxPolicyNote;

  /// No description provided for @taxPolicyFormInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập đủ các số tiền, hệ số và thuế suất.'**
  String get taxPolicyFormInvalid;

  /// No description provided for @minWageRegionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Vùng lương tối thiểu'**
  String get minWageRegionLabel;

  /// No description provided for @minWageRegionOption.
  ///
  /// In vi, this message translates to:
  /// **'Vùng {region}'**
  String minWageRegionOption(int region);

  /// No description provided for @minWageRegionShort.
  ///
  /// In vi, this message translates to:
  /// **'Vùng {region}'**
  String minWageRegionShort(int region);

  /// No description provided for @minWageRegionHelper.
  ///
  /// In vi, this message translates to:
  /// **'Dùng để tính trần lương đóng BHTN (20 × lương tối thiểu vùng). Thông số do quản trị hệ thống cập nhật.'**
  String get minWageRegionHelper;

  /// No description provided for @payslipInsuranceBase.
  ///
  /// In vi, this message translates to:
  /// **'Lương đóng BHXH/BHYT'**
  String get payslipInsuranceBase;

  /// No description provided for @payslipFamilyDeduction.
  ///
  /// In vi, this message translates to:
  /// **'Giảm trừ gia cảnh'**
  String get payslipFamilyDeduction;

  /// No description provided for @auditActTaxPolicyCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chính sách thuế / BH'**
  String get auditActTaxPolicyCreate;

  /// No description provided for @auditActTaxPolicyUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa chính sách thuế / BH'**
  String get auditActTaxPolicyUpdate;

  /// No description provided for @auditActTaxPolicyDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá chính sách thuế / BH'**
  String get auditActTaxPolicyDelete;

  /// No description provided for @currencyVndSuffix.
  ///
  /// In vi, this message translates to:
  /// **'đ'**
  String get currencyVndSuffix;

  /// No description provided for @multiplierSuffix.
  ///
  /// In vi, this message translates to:
  /// **'×'**
  String get multiplierSuffix;

  /// No description provided for @adminTabHolidays.
  ///
  /// In vi, this message translates to:
  /// **'Ngày lễ mẫu'**
  String get adminTabHolidays;

  /// No description provided for @auditActHolidayCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ngày lễ'**
  String get auditActHolidayCreate;

  /// No description provided for @auditActHolidayUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ngày lễ'**
  String get auditActHolidayUpdate;

  /// No description provided for @auditActHolidayDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ngày lễ'**
  String get auditActHolidayDelete;

  /// No description provided for @auditActHolidayImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ngày lễ từ Excel'**
  String get auditActHolidayImport;

  /// No description provided for @auditActHolidayTemplateCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ngày lễ mẫu'**
  String get auditActHolidayTemplateCreate;

  /// No description provided for @auditActHolidayTemplateUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ngày lễ mẫu'**
  String get auditActHolidayTemplateUpdate;

  /// No description provided for @auditActHolidayTemplateDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ngày lễ mẫu'**
  String get auditActHolidayTemplateDelete;

  /// No description provided for @auditActWorkCalendarCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm lịch làm việc'**
  String get auditActWorkCalendarCreate;

  /// No description provided for @auditActWorkCalendarUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa lịch làm việc'**
  String get auditActWorkCalendarUpdate;

  /// No description provided for @auditActWorkCalendarDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá lịch làm việc'**
  String get auditActWorkCalendarDelete;

  /// No description provided for @calPrevYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm trước'**
  String get calPrevYear;

  /// No description provided for @calNextYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm sau'**
  String get calNextYear;

  /// No description provided for @companySettingsGeneralTab.
  ///
  /// In vi, this message translates to:
  /// **'Chung'**
  String get companySettingsGeneralTab;

  /// No description provided for @workCalendarTab.
  ///
  /// In vi, this message translates to:
  /// **'Lịch làm việc'**
  String get workCalendarTab;

  /// No description provided for @dowMon.
  ///
  /// In vi, this message translates to:
  /// **'T2'**
  String get dowMon;

  /// No description provided for @dowTue.
  ///
  /// In vi, this message translates to:
  /// **'T3'**
  String get dowTue;

  /// No description provided for @dowWed.
  ///
  /// In vi, this message translates to:
  /// **'T4'**
  String get dowWed;

  /// No description provided for @dowThu.
  ///
  /// In vi, this message translates to:
  /// **'T5'**
  String get dowThu;

  /// No description provided for @dowFri.
  ///
  /// In vi, this message translates to:
  /// **'T6'**
  String get dowFri;

  /// No description provided for @dowSat.
  ///
  /// In vi, this message translates to:
  /// **'T7'**
  String get dowSat;

  /// No description provided for @dowSun.
  ///
  /// In vi, this message translates to:
  /// **'CN'**
  String get dowSun;

  /// No description provided for @workDayFull.
  ///
  /// In vi, this message translates to:
  /// **'Làm cả ngày'**
  String get workDayFull;

  /// No description provided for @workDayHalf.
  ///
  /// In vi, this message translates to:
  /// **'Làm nửa ngày'**
  String get workDayHalf;

  /// No description provided for @workDayOff.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ'**
  String get workDayOff;

  /// No description provided for @holidayTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngày lễ'**
  String get holidayTitle;

  /// No description provided for @holidayAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ngày lễ'**
  String get holidayAdd;

  /// No description provided for @holidayEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ngày lễ'**
  String get holidayEdit;

  /// No description provided for @holidayDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get holidayDate;

  /// No description provided for @holidayName.
  ///
  /// In vi, this message translates to:
  /// **'Tên ngày lễ'**
  String get holidayName;

  /// No description provided for @holidayNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Cần nhập tên ngày lễ'**
  String get holidayNameRequired;

  /// No description provided for @holidayType.
  ///
  /// In vi, this message translates to:
  /// **'Loại'**
  String get holidayType;

  /// No description provided for @holidayTypeHoliday.
  ///
  /// In vi, this message translates to:
  /// **'Ngày lễ'**
  String get holidayTypeHoliday;

  /// No description provided for @holidayTypeCompensatory.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ bù'**
  String get holidayTypeCompensatory;

  /// No description provided for @holidayTypeSwapWorkday.
  ///
  /// In vi, this message translates to:
  /// **'Làm bù'**
  String get holidayTypeSwapWorkday;

  /// No description provided for @holidayTypeHolidayHint.
  ///
  /// In vi, this message translates to:
  /// **'Ngày nghỉ lễ / Tết. Tắt \"có lương\" để nhập ngày nghỉ hoán đổi.'**
  String get holidayTypeHolidayHint;

  /// No description provided for @holidayTypeCompensatoryHint.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ bù khi ngày lễ trùng ngày nghỉ hằng tuần.'**
  String get holidayTypeCompensatoryHint;

  /// No description provided for @holidayTypeSwapWorkdayHint.
  ///
  /// In vi, this message translates to:
  /// **'Ngày nghỉ hằng tuần chuyển thành ngày làm cả ngày (đổi lấy ngày nghỉ hoán đổi).'**
  String get holidayTypeSwapWorkdayHint;

  /// No description provided for @holidayPaid.
  ///
  /// In vi, this message translates to:
  /// **'Có lương'**
  String get holidayPaid;

  /// No description provided for @holidayUnpaid.
  ///
  /// In vi, this message translates to:
  /// **'Không lương'**
  String get holidayUnpaid;

  /// No description provided for @holidayPaidLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hưởng lương'**
  String get holidayPaidLabel;

  /// No description provided for @holidayPaidHint.
  ///
  /// In vi, this message translates to:
  /// **'Ngày có lương vẫn tính vào công chuẩn và biến HOLIDAY_DAYS.'**
  String get holidayPaidHint;

  /// No description provided for @holidayUsingTemplate.
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng mẫu hệ thống'**
  String get holidayUsingTemplate;

  /// No description provided for @holidayCustomized.
  ///
  /// In vi, this message translates to:
  /// **'Công ty đã chỉnh'**
  String get holidayCustomized;

  /// No description provided for @holidayTemplateHint.
  ///
  /// In vi, this message translates to:
  /// **'Năm này đang theo danh sách mẫu của hệ thống. Thêm, sửa hoặc xoá một ngày sẽ chép mẫu sang công ty, từ đó công ty tự quản lý năm này.'**
  String get holidayTemplateHint;

  /// No description provided for @holidayCustomizedHint.
  ///
  /// In vi, this message translates to:
  /// **'Công ty tự quản lý danh sách năm này; thay đổi ở mẫu hệ thống không còn áp dụng.'**
  String get holidayCustomizedHint;

  /// No description provided for @holidayTemplateAdminHint.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách mặc định cho mọi công ty. Công ty đã tự chỉnh năm nào thì giữ bản riêng của năm đó.'**
  String get holidayTemplateAdminHint;

  /// No description provided for @holidayEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ngày lễ trong năm này'**
  String get holidayEmpty;

  /// No description provided for @rotationSkipHolidays.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua ngày lễ (không xếp ca vào ngày nghỉ lễ)'**
  String get rotationSkipHolidays;

  /// No description provided for @standardDaysFromCalendar.
  ///
  /// In vi, this message translates to:
  /// **'Công chuẩn theo lịch làm việc'**
  String get standardDaysFromCalendar;

  /// No description provided for @standardDaysFromCalendarHint.
  ///
  /// In vi, this message translates to:
  /// **'Đếm ngày làm trong kỳ theo lịch tuần của phòng ban (nửa ngày = 0,5), ngày lễ có lương vẫn tính. Tắt để dùng số cố định.'**
  String get standardDaysFromCalendarHint;

  /// No description provided for @workCalendarWeekTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch làm việc trong tuần'**
  String get workCalendarWeekTitle;

  /// No description provided for @workCalendarWeekHint.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban chưa gán lịch dùng lịch của phòng cha, rồi đến lịch mặc định.'**
  String get workCalendarWeekHint;

  /// No description provided for @workCalendarDefaultName.
  ///
  /// In vi, this message translates to:
  /// **'Lịch mặc định'**
  String get workCalendarDefaultName;

  /// No description provided for @workCalendarDefaultHint.
  ///
  /// In vi, this message translates to:
  /// **'Áp cho mọi phòng ban chưa gán lịch riêng'**
  String get workCalendarDefaultHint;

  /// No description provided for @workCalendarNoDepartments.
  ///
  /// In vi, this message translates to:
  /// **'Chưa gán phòng ban nào'**
  String get workCalendarNoDepartments;

  /// No description provided for @workCalendarAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm lịch'**
  String get workCalendarAdd;

  /// No description provided for @workCalendarEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa lịch'**
  String get workCalendarEdit;

  /// No description provided for @workCalendarName.
  ///
  /// In vi, this message translates to:
  /// **'Tên lịch'**
  String get workCalendarName;

  /// No description provided for @workCalendarNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Cần nhập tên lịch'**
  String get workCalendarNameRequired;

  /// No description provided for @workCalendarPatternHint.
  ///
  /// In vi, this message translates to:
  /// **'Bấm vào từng ngày để đổi: cả ngày → nửa ngày → nghỉ.'**
  String get workCalendarPatternHint;

  /// No description provided for @workCalendarDepartments.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban áp dụng'**
  String get workCalendarDepartments;

  /// No description provided for @workCalendarDepartmentsHint.
  ///
  /// In vi, this message translates to:
  /// **'Phòng con chưa gán lịch sẽ dùng theo.'**
  String get workCalendarDepartmentsHint;

  /// No description provided for @workCalendarDeptHasOther.
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng lịch khác — chọn sẽ chuyển sang lịch này'**
  String get workCalendarDeptHasOther;

  /// No description provided for @permModuleCalendar.
  ///
  /// In vi, this message translates to:
  /// **'Lịch làm việc'**
  String get permModuleCalendar;

  /// No description provided for @permUiCalendarView.
  ///
  /// In vi, this message translates to:
  /// **'Mở tab Lịch làm việc trong Cài đặt công ty'**
  String get permUiCalendarView;

  /// No description provided for @permUiCalendarManage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm / sửa ngày lễ và lịch tuần'**
  String get permUiCalendarManage;

  /// No description provided for @permDescCalendarView.
  ///
  /// In vi, this message translates to:
  /// **'Xem ngày lễ và lịch làm việc tuần'**
  String get permDescCalendarView;

  /// No description provided for @permDescCalendarManage.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ngày lễ, nhập Excel, sửa lịch tuần của công ty và phòng ban'**
  String get permDescCalendarManage;

  /// No description provided for @holidayDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ngày lễ \"{name}\" ({date})?'**
  String holidayDeleteConfirm(String name, String date);

  /// No description provided for @workCalendarDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá lịch \"{name}\"? Phòng ban đang dùng sẽ quay về lịch của phòng cha / mặc định.'**
  String workCalendarDeleteConfirm(String name);

  /// No description provided for @workCalendarWeekDays.
  ///
  /// In vi, this message translates to:
  /// **'{days} công / tuần'**
  String workCalendarWeekDays(String days);

  /// No description provided for @orgChartTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sơ đồ tổ chức'**
  String get orgChartTitle;

  /// No description provided for @orgChartByPerson.
  ///
  /// In vi, this message translates to:
  /// **'Theo người'**
  String get orgChartByPerson;

  /// No description provided for @orgChartByDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Theo phòng ban'**
  String get orgChartByDepartment;

  /// No description provided for @orgChartSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tên hoặc mã NV'**
  String get orgChartSearch;

  /// No description provided for @orgChartPeopleCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} người'**
  String orgChartPeopleCount(int count);

  /// No description provided for @orgChartManagerOf.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý: {name}'**
  String orgChartManagerOf(String name);

  /// No description provided for @orgChartReports.
  ///
  /// In vi, this message translates to:
  /// **'{count} cấp dưới'**
  String orgChartReports(int count);

  /// No description provided for @orgChartDepartmentHead.
  ///
  /// In vi, this message translates to:
  /// **'Trưởng phòng'**
  String get orgChartDepartmentHead;

  /// No description provided for @teamApprovalsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt cho nhóm'**
  String get teamApprovalsTitle;

  /// No description provided for @teamApprovalsHint.
  ///
  /// In vi, this message translates to:
  /// **'Đơn của nhân viên bạn quản lý trực tiếp. Bạn duyệt trước, sau đó HR duyệt cuối; từ chối thì đơn kết thúc luôn.'**
  String get teamApprovalsHint;

  /// No description provided for @teamApprovalsApproveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt đơn (bước quản lý)'**
  String get teamApprovalsApproveTitle;

  /// No description provided for @teamApprovalsRejectTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối đơn'**
  String get teamApprovalsRejectTitle;

  /// No description provided for @teamApprovalsApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt, đơn chuyển cho HR'**
  String get teamApprovalsApproved;

  /// No description provided for @teamApprovalsRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối đơn'**
  String get teamApprovalsRejected;

  /// No description provided for @teamApprovalsDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Công ty đang duyệt theo quyền, không có bước quản lý trực tiếp.'**
  String get teamApprovalsDisabled;

  /// No description provided for @teamApprovalsNoReports.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa là quản lý trực tiếp của ai.'**
  String get teamApprovalsNoReports;

  /// No description provided for @teamApprovalsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có đơn nào chờ bạn ({count} người dưới quyền).'**
  String teamApprovalsEmpty(int count);

  /// No description provided for @teamApprovalsMinutes.
  ///
  /// In vi, this message translates to:
  /// **'{minutes} phút'**
  String teamApprovalsMinutes(int minutes);

  /// No description provided for @approvalAwaitingManager.
  ///
  /// In vi, this message translates to:
  /// **'Chờ quản lý: {name}'**
  String approvalAwaitingManager(String name);

  /// No description provided for @approvalManagerApproved.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý đã duyệt: {name}'**
  String approvalManagerApproved(String name);

  /// No description provided for @approvalModeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Người duyệt đơn'**
  String get approvalModeTitle;

  /// No description provided for @approvalModeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đơn nghỉ, đơn sửa công, đổi ca do ai duyệt'**
  String get approvalModeLabel;

  /// No description provided for @approvalModePermission.
  ///
  /// In vi, this message translates to:
  /// **'Người có quyền duyệt (theo phạm vi phòng ban)'**
  String get approvalModePermission;

  /// No description provided for @approvalModeManagerThenHr.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý trực tiếp duyệt trước, rồi HR'**
  String get approvalModeManagerThenHr;

  /// No description provided for @approvalModeHelper.
  ///
  /// In vi, this message translates to:
  /// **'Khi bật, nhân viên có quản lý trực tiếp thì quản lý duyệt trước ở màn \"Duyệt cho nhóm\"; HR chỉ duyệt cuối được sau đó. Nhân viên chưa có quản lý vẫn duyệt như cũ.'**
  String get approvalModeHelper;

  /// No description provided for @directManager.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý trực tiếp'**
  String get directManager;

  /// No description provided for @directManagerNone.
  ///
  /// In vi, this message translates to:
  /// **'Không có'**
  String get directManagerNone;

  /// No description provided for @jobChangeHire.
  ///
  /// In vi, this message translates to:
  /// **'Tuyển mới'**
  String get jobChangeHire;

  /// No description provided for @jobChangeTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển phòng ban'**
  String get jobChangeTransfer;

  /// No description provided for @jobChangePromotion.
  ///
  /// In vi, this message translates to:
  /// **'Đổi chức vụ'**
  String get jobChangePromotion;

  /// No description provided for @jobChangeSalary.
  ///
  /// In vi, this message translates to:
  /// **'Đổi bậc lương'**
  String get jobChangeSalary;

  /// No description provided for @jobChangeManager.
  ///
  /// In vi, this message translates to:
  /// **'Đổi quản lý'**
  String get jobChangeManager;

  /// No description provided for @jobChangeOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get jobChangeOther;

  /// No description provided for @jobHistoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quá trình công tác'**
  String get jobHistoryTitle;

  /// No description provided for @jobHistoryAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm mốc'**
  String get jobHistoryAdd;

  /// No description provided for @jobHistoryHint.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi mốc là phòng ban, chức vụ, bậc lương và quản lý áp dụng từ ngày hiệu lực. Mốc ngày tương lai tự áp dụng khi tới ngày; bảng lương dùng mốc hiệu lực ở cuối kỳ.'**
  String get jobHistoryHint;

  /// No description provided for @jobHistoryDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá mốc chưa tới ngày này?'**
  String get jobHistoryDeleteConfirm;

  /// No description provided for @jobHistoryCurrent.
  ///
  /// In vi, this message translates to:
  /// **'Hiện tại'**
  String get jobHistoryCurrent;

  /// No description provided for @jobHistoryUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Sắp áp dụng'**
  String get jobHistoryUpcoming;

  /// No description provided for @jobHistoryBy.
  ///
  /// In vi, this message translates to:
  /// **'Người ghi: {name}'**
  String jobHistoryBy(String name);

  /// No description provided for @jobHistoryChangeType.
  ///
  /// In vi, this message translates to:
  /// **'Loại thay đổi'**
  String get jobHistoryChangeType;

  /// No description provided for @auditActJobHistoryCreate.
  ///
  /// In vi, this message translates to:
  /// **'Ghi quá trình công tác'**
  String get auditActJobHistoryCreate;

  /// No description provided for @auditActJobHistoryDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá mốc công tác'**
  String get auditActJobHistoryDelete;

  /// No description provided for @auditActManagerApprove.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý trực tiếp duyệt'**
  String get auditActManagerApprove;

  /// No description provided for @auditActManagerReject.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý trực tiếp từ chối'**
  String get auditActManagerReject;

  /// No description provided for @contractsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng lao động'**
  String get contractsTitle;

  /// No description provided for @contractNo.
  ///
  /// In vi, this message translates to:
  /// **'Số hợp đồng'**
  String get contractNo;

  /// No description provided for @contractType.
  ///
  /// In vi, this message translates to:
  /// **'Loại hợp đồng'**
  String get contractType;

  /// No description provided for @contractTypeProbation.
  ///
  /// In vi, this message translates to:
  /// **'Thử việc'**
  String get contractTypeProbation;

  /// No description provided for @contractTypeFixedTerm.
  ///
  /// In vi, this message translates to:
  /// **'Xác định thời hạn'**
  String get contractTypeFixedTerm;

  /// No description provided for @contractTypeIndefinite.
  ///
  /// In vi, this message translates to:
  /// **'Không xác định thời hạn'**
  String get contractTypeIndefinite;

  /// No description provided for @contractTypeSeasonal.
  ///
  /// In vi, this message translates to:
  /// **'Thời vụ'**
  String get contractTypeSeasonal;

  /// No description provided for @contractTypeService.
  ///
  /// In vi, this message translates to:
  /// **'Cộng tác / dịch vụ'**
  String get contractTypeService;

  /// No description provided for @contractStatusDraft.
  ///
  /// In vi, this message translates to:
  /// **'Nháp'**
  String get contractStatusDraft;

  /// No description provided for @contractStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu lực'**
  String get contractStatusActive;

  /// No description provided for @contractStatusExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get contractStatusExpired;

  /// No description provided for @contractStatusTerminated.
  ///
  /// In vi, this message translates to:
  /// **'Chấm dứt'**
  String get contractStatusTerminated;

  /// No description provided for @contractNeedsRenewal.
  ///
  /// In vi, this message translates to:
  /// **'Cần gia hạn'**
  String get contractNeedsRenewal;

  /// No description provided for @contractRenewalBanner.
  ///
  /// In vi, this message translates to:
  /// **'{count} hợp đồng sắp hết hạn hoặc đã quá hạn mà chưa có hợp đồng nối tiếp — bấm để xem'**
  String contractRenewalBanner(int count);

  /// No description provided for @contractSignDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày ký'**
  String get contractSignDate;

  /// No description provided for @contractStartDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày hiệu lực'**
  String get contractStartDate;

  /// No description provided for @contractEndDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày kết thúc'**
  String get contractEndDate;

  /// No description provided for @contractBaseSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương cơ bản'**
  String get contractBaseSalary;

  /// No description provided for @contractInsuranceSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương đóng BH'**
  String get contractInsuranceSalary;

  /// No description provided for @contractInsuranceSalaryHint.
  ///
  /// In vi, this message translates to:
  /// **'Trống = lương + phụ cấp đóng BH'**
  String get contractInsuranceSalaryHint;

  /// No description provided for @contractPositionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chức danh'**
  String get contractPositionTitle;

  /// No description provided for @contractCurrentSalary.
  ///
  /// In vi, this message translates to:
  /// **'Lương đang áp dụng'**
  String get contractCurrentSalary;

  /// No description provided for @contractAllowances.
  ///
  /// In vi, this message translates to:
  /// **'Phụ cấp'**
  String get contractAllowances;

  /// No description provided for @contractAllowanceAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phụ cấp'**
  String get contractAllowanceAdd;

  /// No description provided for @contractAllowanceCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã'**
  String get contractAllowanceCode;

  /// No description provided for @contractAllowanceName.
  ///
  /// In vi, this message translates to:
  /// **'Tên phụ cấp'**
  String get contractAllowanceName;

  /// No description provided for @contractAllowanceAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền'**
  String get contractAllowanceAmount;

  /// No description provided for @contractAllowanceInsurable.
  ///
  /// In vi, this message translates to:
  /// **'Đóng BH'**
  String get contractAllowanceInsurable;

  /// No description provided for @contractAllowanceTaxable.
  ///
  /// In vi, this message translates to:
  /// **'Chịu thuế'**
  String get contractAllowanceTaxable;

  /// No description provided for @contractAllowanceNonTaxable.
  ///
  /// In vi, this message translates to:
  /// **'Không chịu thuế'**
  String get contractAllowanceNonTaxable;

  /// No description provided for @contractAllowanceCodeHint.
  ///
  /// In vi, this message translates to:
  /// **'Mã gồm A–Z, 0–9, _ — dùng trong công thức lương là ALLOWANCE_<mã>'**
  String get contractAllowanceCodeHint;

  /// No description provided for @contractAppendices.
  ///
  /// In vi, this message translates to:
  /// **'Phụ lục'**
  String get contractAppendices;

  /// No description provided for @contractAppendixAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phụ lục'**
  String get contractAppendixAdd;

  /// No description provided for @contractAppendixEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa phụ lục'**
  String get contractAppendixEdit;

  /// No description provided for @contractAppendixNo.
  ///
  /// In vi, this message translates to:
  /// **'Số phụ lục'**
  String get contractAppendixNo;

  /// No description provided for @contractAppendixCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} phụ lục'**
  String contractAppendixCount(int count);

  /// No description provided for @contractAppendixKeepHint.
  ///
  /// In vi, this message translates to:
  /// **'Ô để trống giữ nguyên giá trị trước đó. Lương mới áp dụng từ ngày hiệu lực; kỳ lương có ngày đổi được tính bình quân theo công chuẩn.'**
  String get contractAppendixKeepHint;

  /// No description provided for @contractAppendixOverridesAllowances.
  ///
  /// In vi, this message translates to:
  /// **'Thay bộ phụ cấp từ ngày này'**
  String get contractAppendixOverridesAllowances;

  /// No description provided for @contractEffectiveFrom.
  ///
  /// In vi, this message translates to:
  /// **'từ {date}'**
  String contractEffectiveFrom(String date);

  /// No description provided for @contractAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm hợp đồng'**
  String get contractAdd;

  /// No description provided for @contractEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hợp đồng'**
  String get contractEdit;

  /// No description provided for @contractActivate.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt'**
  String get contractActivate;

  /// No description provided for @contractActivateConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt hợp đồng {no}? Lương HĐ của nhân viên sẽ theo hợp đồng này.'**
  String contractActivateConfirm(String no);

  /// No description provided for @contractTerminate.
  ///
  /// In vi, this message translates to:
  /// **'Chấm dứt'**
  String get contractTerminate;

  /// No description provided for @contractTerminateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chấm dứt hợp đồng {no}'**
  String contractTerminateTitle(String no);

  /// No description provided for @contractTerminationDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày chấm dứt (ngày làm việc cuối)'**
  String get contractTerminationDate;

  /// No description provided for @contractDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá hợp đồng {no}? Kỳ lương chưa duyệt sẽ không còn tính theo hợp đồng này.'**
  String contractDeleteConfirm(String no);

  /// No description provided for @contractAppendixDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá phụ lục {no}?'**
  String contractAppendixDeleteConfirm(String no);

  /// No description provided for @contractDaysLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {days} ngày'**
  String contractDaysLeft(int days);

  /// No description provided for @contractOverdue.
  ///
  /// In vi, this message translates to:
  /// **'Quá hạn {days} ngày'**
  String contractOverdue(int days);

  /// No description provided for @contractNoEnd.
  ///
  /// In vi, this message translates to:
  /// **'Không thời hạn'**
  String get contractNoEnd;

  /// No description provided for @contractEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hợp đồng nào'**
  String get contractEmpty;

  /// No description provided for @contractSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm số HĐ, tên, mã NV, phòng ban'**
  String get contractSearchHint;

  /// No description provided for @contractSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu hợp đồng'**
  String get contractSaved;

  /// No description provided for @contractRequiredFields.
  ///
  /// In vi, this message translates to:
  /// **'Điền đủ các ô có dấu *'**
  String get contractRequiredFields;

  /// No description provided for @dashboardRisksContractExpiring.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng cần gia hạn'**
  String get dashboardRisksContractExpiring;

  /// No description provided for @companyContractWarningDays.
  ///
  /// In vi, this message translates to:
  /// **'Báo trước hợp đồng hết hạn (ngày)'**
  String get companyContractWarningDays;

  /// No description provided for @companyContractWarningDaysHelper.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng còn ít ngày hơn số này hiện ở \"Cần gia hạn\" và Tổng quan; HR nhận thông báo khi còn đúng số ngày này, 7 ngày và ngày cuối.'**
  String get companyContractWarningDaysHelper;

  /// No description provided for @permModuleContract.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng lao động'**
  String get permModuleContract;

  /// No description provided for @permUiContractView.
  ///
  /// In vi, this message translates to:
  /// **'Mở màn Hợp đồng, thấy cảnh báo hợp đồng hết hạn ở Tổng quan'**
  String get permUiContractView;

  /// No description provided for @permUiContractEdit.
  ///
  /// In vi, this message translates to:
  /// **'Thêm / sửa / kích hoạt / chấm dứt hợp đồng, phụ lục, nhập Excel'**
  String get permUiContractEdit;

  /// No description provided for @permUiContractDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá hợp đồng'**
  String get permUiContractDelete;

  /// No description provided for @permDescContractView.
  ///
  /// In vi, this message translates to:
  /// **'Xem hợp đồng lao động, phụ lục, phụ cấp (theo phạm vi phòng ban)'**
  String get permDescContractView;

  /// No description provided for @permDescContractEdit.
  ///
  /// In vi, this message translates to:
  /// **'Tạo / sửa hợp đồng và phụ lục; lương hợp đồng dùng cho bảng lương'**
  String get permDescContractEdit;

  /// No description provided for @permDescContractDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá hợp đồng lao động'**
  String get permDescContractDelete;

  /// No description provided for @auditActContractCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hợp đồng'**
  String get auditActContractCreate;

  /// No description provided for @auditActContractUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hợp đồng'**
  String get auditActContractUpdate;

  /// No description provided for @auditActContractActivate.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt hợp đồng'**
  String get auditActContractActivate;

  /// No description provided for @auditActContractTerminate.
  ///
  /// In vi, this message translates to:
  /// **'Chấm dứt hợp đồng'**
  String get auditActContractTerminate;

  /// No description provided for @auditActContractDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá hợp đồng'**
  String get auditActContractDelete;

  /// No description provided for @auditActContractAppendixCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phụ lục hợp đồng'**
  String get auditActContractAppendixCreate;

  /// No description provided for @auditActContractAppendixUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa phụ lục hợp đồng'**
  String get auditActContractAppendixUpdate;

  /// No description provided for @auditActContractAppendixDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá phụ lục hợp đồng'**
  String get auditActContractAppendixDelete;

  /// No description provided for @auditActContractImport.
  ///
  /// In vi, this message translates to:
  /// **'Nhập hợp đồng từ Excel'**
  String get auditActContractImport;

  /// No description provided for @permUiEmployeeSensitiveView.
  ///
  /// In vi, this message translates to:
  /// **'Xem đủ CCCD, số tài khoản, MST, số sổ BHXH (không có thì hiện dạng ****1234)'**
  String get permUiEmployeeSensitiveView;

  /// No description provided for @permDescEmployeeSensitiveView.
  ///
  /// In vi, this message translates to:
  /// **'Xem dữ liệu nhạy cảm của nhân viên'**
  String get permDescEmployeeSensitiveView;

  /// No description provided for @taxInsuranceInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thuế & bảo hiểm'**
  String get taxInsuranceInfo;

  /// No description provided for @empTaxCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế cá nhân'**
  String get empTaxCode;

  /// No description provided for @empSocialInsuranceNo.
  ///
  /// In vi, this message translates to:
  /// **'Số sổ BHXH'**
  String get empSocialInsuranceNo;

  /// No description provided for @empHealthInsurancePlace.
  ///
  /// In vi, this message translates to:
  /// **'Nơi đăng ký KCB ban đầu'**
  String get empHealthInsurancePlace;

  /// No description provided for @empInsuranceJoinDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày tham gia bảo hiểm'**
  String get empInsuranceJoinDate;

  /// No description provided for @sensitiveMaskedHint.
  ///
  /// In vi, this message translates to:
  /// **'Một số trường đang che vì bạn không có quyền xem dữ liệu nhạy cảm. Để nguyên thì giữ giá trị cũ, nhập số mới thì ghi đè.'**
  String get sensitiveMaskedHint;

  /// No description provided for @dependentsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Người phụ thuộc'**
  String get dependentsTitle;

  /// No description provided for @dependentsHint.
  ///
  /// In vi, this message translates to:
  /// **'Giảm trừ gia cảnh tính theo tháng của kỳ lương. Người \"Chưa đăng ký\" không được giảm trừ.'**
  String get dependentsHint;

  /// No description provided for @dependentAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm người phụ thuộc'**
  String get dependentAdd;

  /// No description provided for @dependentEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa người phụ thuộc'**
  String get dependentEdit;

  /// No description provided for @dependentEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có người phụ thuộc'**
  String get dependentEmpty;

  /// No description provided for @dependentName.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên người phụ thuộc'**
  String get dependentName;

  /// No description provided for @dependentRelationship.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ'**
  String get dependentRelationship;

  /// No description provided for @dependentRelChild.
  ///
  /// In vi, this message translates to:
  /// **'Con'**
  String get dependentRelChild;

  /// No description provided for @dependentRelSpouse.
  ///
  /// In vi, this message translates to:
  /// **'Vợ / chồng'**
  String get dependentRelSpouse;

  /// No description provided for @dependentRelParent.
  ///
  /// In vi, this message translates to:
  /// **'Cha / mẹ'**
  String get dependentRelParent;

  /// No description provided for @dependentRelOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get dependentRelOther;

  /// No description provided for @dependentTaxCode.
  ///
  /// In vi, this message translates to:
  /// **'MST người phụ thuộc'**
  String get dependentTaxCode;

  /// No description provided for @dependentIdentityNo.
  ///
  /// In vi, this message translates to:
  /// **'CCCD / số định danh'**
  String get dependentIdentityNo;

  /// No description provided for @dependentFrom.
  ///
  /// In vi, this message translates to:
  /// **'Giảm trừ từ tháng'**
  String get dependentFrom;

  /// No description provided for @dependentTo.
  ///
  /// In vi, this message translates to:
  /// **'Đến tháng'**
  String get dependentTo;

  /// No description provided for @dependentNoEnd.
  ///
  /// In vi, this message translates to:
  /// **'chưa kết thúc'**
  String get dependentNoEnd;

  /// No description provided for @dependentPeriod.
  ///
  /// In vi, this message translates to:
  /// **'Giảm trừ'**
  String get dependentPeriod;

  /// No description provided for @dependentMonthHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày bất kỳ trong tháng; hệ thống tính theo cả tháng. Để trống \"Đến tháng\" nếu chưa kết thúc.'**
  String get dependentMonthHint;

  /// No description provided for @dependentStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái đăng ký'**
  String get dependentStatus;

  /// No description provided for @dependentStatusNotRegistered.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đăng ký'**
  String get dependentStatusNotRegistered;

  /// No description provided for @dependentStatusPending.
  ///
  /// In vi, this message translates to:
  /// **'Đã nộp, chờ MST'**
  String get dependentStatusPending;

  /// No description provided for @dependentStatusRegistered.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng ký'**
  String get dependentStatusRegistered;

  /// No description provided for @dependentActiveNow.
  ///
  /// In vi, this message translates to:
  /// **'Đang giảm trừ'**
  String get dependentActiveNow;

  /// No description provided for @payslipEmployerInsurance.
  ///
  /// In vi, this message translates to:
  /// **'BH công ty đóng (BHXH / BHYT / BHTN)'**
  String get payslipEmployerInsurance;

  /// No description provided for @employerInsuranceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ bảo hiểm công ty đóng'**
  String get employerInsuranceTitle;

  /// No description provided for @employerSocialPercent.
  ///
  /// In vi, this message translates to:
  /// **'BHXH (gồm TNLĐ-BNN)'**
  String get employerSocialPercent;

  /// No description provided for @employerHealthPercent.
  ///
  /// In vi, this message translates to:
  /// **'BHYT'**
  String get employerHealthPercent;

  /// No description provided for @employerUnemploymentPercent.
  ///
  /// In vi, this message translates to:
  /// **'BHTN'**
  String get employerUnemploymentPercent;

  /// No description provided for @employerInsuranceHelper.
  ///
  /// In vi, this message translates to:
  /// **'Mặc định 17,5% / 3% / 1%. Tính trên lương đóng BH của phiếu lương, ra cột chi phí công ty ở báo cáo lương; không trừ vào lương nhân viên.'**
  String get employerInsuranceHelper;

  /// No description provided for @reportInsured.
  ///
  /// In vi, this message translates to:
  /// **'NV tham gia bảo hiểm'**
  String get reportInsured;

  /// No description provided for @reportInsuredDesc.
  ///
  /// In vi, this message translates to:
  /// **'MST, số sổ BHXH, nơi KCB, ngày tham gia và lương đóng BH hiện hành'**
  String get reportInsuredDesc;

  /// No description provided for @reportDependents.
  ///
  /// In vi, this message translates to:
  /// **'Người phụ thuộc'**
  String get reportDependents;

  /// No description provided for @reportDependentsDesc.
  ///
  /// In vi, this message translates to:
  /// **'Người phụ thuộc giảm trừ gia cảnh, tháng bắt đầu / kết thúc, trạng thái đăng ký'**
  String get reportDependentsDesc;

  /// No description provided for @auditActDependentCreate.
  ///
  /// In vi, this message translates to:
  /// **'Thêm người phụ thuộc'**
  String get auditActDependentCreate;

  /// No description provided for @auditActDependentUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Sửa người phụ thuộc'**
  String get auditActDependentUpdate;

  /// No description provided for @auditActDependentDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá người phụ thuộc'**
  String get auditActDependentDelete;

  /// No description provided for @payslipDependents.
  ///
  /// In vi, this message translates to:
  /// **'{count} người phụ thuộc'**
  String payslipDependents(int count);

  /// No description provided for @dependentDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá người phụ thuộc {name}? Kỳ lương tính lại sau đó sẽ không còn giảm trừ cho người này.'**
  String dependentDeleteConfirm(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
