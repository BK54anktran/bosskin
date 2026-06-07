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
  /// **'Mật khẩu mới phải có ít nhất 6 ký tự'**
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
