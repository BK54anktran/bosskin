package com.bosskin.i18n;

import java.util.Locale;

public final class MessageTranslator {
    private MessageTranslator() {}

    public static String translate(String message, Locale locale) {
        if (message == null || message.isBlank()) return message;
        if (!isEnglish(locale)) return message;

        return switch (message) {
            case "Email hoặc mật khẩu không đúng" -> "Email or password is incorrect";
            case "Tài khoản đã bị khóa" -> "The account has been locked";
            case "Refresh token đã hết hạn" -> "Refresh token has expired";
            case "Session không hợp lệ" -> "Invalid session";
            case "Session đã bị thu hồi" -> "Session has been revoked";
            case "Thiết bị không khớp" -> "Device does not match";
            case "Người dùng không tồn tại" -> "User not found";
            case "Mật khẩu khởi tạo phải có ít nhất 6 ký tự" -> "Initial password must be at least 6 characters";
            case "Mật khẩu mới phải có ít nhất 6 ký tự" -> "New password must be at least 6 characters";
            case "Mật khẩu xác nhận không khớp" -> "Password confirmation does not match";
            case "Mật khẩu hiện tại không đúng" -> "Current password is incorrect";
            case "Vui lòng điền ít nhất một thông tin muốn thay đổi" -> "Please enter at least one field to update";
            case "Vui lòng nhập đầy đủ mật khẩu" -> "Please fill in all password fields";
            case "Hôm nay chưa được xếp ca" -> "No shift has been assigned for today";
            case "Chức năng check-in/out đang tắt" -> "Check-in/out is disabled";
            case "Chưa tới hoặc đã quá giờ check-in" -> "It is not time to check in yet or the time has passed";
            case "Chưa tới hoặc đã quá giờ check-out" -> "It is not time to check out yet or the time has passed";
            case "Tài khoản chưa được liên kết với nhân viên nào" -> "This account is not linked to any employee";
            case "Chưa có dữ liệu check-in hôm nay" -> "No check-in data for today";
            case "Chưa có dữ liệu chấm công vào hôm nay" -> "No attendance check-in data for today";
            case "Không có quyền thao tác phòng ban này" -> "No permission to manage this department";
            case "Không có quyền thao tác nhân viên phòng ban này" -> "No permission to manage employees in this department";
            case "Không có quyền thao tác với người dùng này" -> "No permission to manage this user";
            case "Không có quyền sửa vai trò này" -> "No permission to edit this role";
            case "Không có quyền xóa vai trò này" -> "No permission to delete this role";
            case "Không có quyền: SHIFT_VIEW" -> "No permission: SHIFT_VIEW";
            case "Không có quyền: SHIFT_MANAGE" -> "No permission: SHIFT_MANAGE";
            case "Không có quyền: " -> "No permission: ";
            case "Phải chọn ca hoặc nhập giờ tùy chỉnh" -> "Please choose a shift or enter a custom time";
            case "Tối đa 2 ca mỗi ngày" -> "Maximum 2 shifts per day";
            case "Không tìm thấy phòng ban" -> "Department not found";
            case "Không tìm thấy ca làm" -> "Shift not found";
            case "Không tìm thấy nhân viên" -> "Employee not found";
            case "Không tìm thấy bảng lương" -> "Payroll not found";
            case "Không tìm thấy phân công" -> "Assignment not found";
            case "Không tìm thấy yêu cầu" -> "Request not found";
            case "Không tìm thấy vị trí" -> "Position not found";
            case "Không tìm thấy công ty" -> "Company not found";
            case "Công ty không tồn tại" -> "Company does not exist";
            case "Công ty chưa có user nào" -> "The company has no users yet";
            case "Phòng ban không tồn tại" -> "Department does not exist";
            case "Phòng ban cha không tồn tại" -> "Parent department does not exist";
            case "Phòng ban còn phòng con, không thể xóa" -> "Cannot delete department while child departments exist";
            case "Phòng ban còn chức vụ, không thể xóa" -> "Cannot delete department while positions exist";
            case "Phòng ban còn nhân viên, không thể xóa" -> "Cannot delete department while employees exist";
            case "Phòng ban không thể là cha của chính nó" -> "A department cannot be its own parent";
            case "Vai trò không tồn tại" -> "Role not found";
            case "Tên vai trò đã tồn tại trong công ty này" -> "Role name already exists in this company";
            case "Mã công ty đã tồn tại" -> "Company code already exists";
            case "Mã phòng ban đã tồn tại" -> "Department code already exists";
            case "Mã chức vụ đã tồn tại" -> "Position code already exists";
            case "Email admin đã được sử dụng" -> "Admin email has already been used";
            case "Email đã được sử dụng" -> "Email has already been used";
            case "email và password là bắt buộc" -> "Email and password are required";
            case "enabled là bắt buộc" -> "enabled is required";
            case "Vai trò không hợp lệ" -> "Invalid role";
            case "Vai trò không thuộc công ty này" -> "Role does not belong to this company";
            case "Chức vụ không tồn tại" -> "Position not found";
            case "Chức vụ còn nhân viên, không thể xóa" -> "Cannot delete position while employees exist";
            case "Bảng lương không tồn tại" -> "Payroll not found";
            case "Chỉ có thể phê duyệt bảng lương ở trạng thái DRAFT" -> "Payroll can only be approved when in DRAFT state";
            case "Chỉ có thể thanh toán bảng lương đã được phê duyệt" -> "Only approved payroll can be paid";
            case "Chỉ được hủy yêu cầu của chính mình" -> "You can only cancel your own request";
            case "Chỉ được thao tác trên yêu cầu đang chờ duyệt" -> "Can only operate on pending requests";
            case "Chỉ được thao tác trên yêu cầu đã duyệt" -> "Can only operate on approved requests";
            case "Chỉ được duyệt yêu cầu đang chờ duyệt" -> "Can only approve pending requests";
            case "Chỉ được từ chối yêu cầu đang chờ duyệt" -> "Can only reject pending requests";
            case "Chỉ được tạo phòng ban con trong phạm vi được phép" -> "Can only create sub-departments within your allowed scope";
            case "Phòng ban cha không nằm trong phạm vi được phép" -> "Parent department is outside the allowed scope";
            case "Không có quyền" -> "No permission";
            default -> translateDynamic(message);
        };
    }

    private static String translateDynamic(String message) {
        if (message.startsWith("Không có quyền: ")) {
            return "No permission: " + message.substring("Không có quyền: ".length());
        }
        if (message.startsWith("Không có quyền thao tác ")) {
            return "No permission to manage " + message.substring("Không có quyền thao tác ".length());
        }
        if (message.startsWith("Không tìm thấy ")) {
            return "Not found: " + message.substring("Không tìm thấy ".length());
        }
        if (message.startsWith("Permission không hợp lệ: ")) {
            return "Invalid permission: " + message.substring("Permission không hợp lệ: ".length());
        }
        if (message.startsWith("Vai trò không hợp lệ: ")) {
            return "Invalid role: " + message.substring("Vai trò không hợp lệ: ".length());
        }
        if (message.startsWith("Không có quyền thao tác với ")) {
            return "No permission to manage " + message.substring("Không có quyền thao tác với ".length());
        }
        return message;
    }

    private static boolean isEnglish(Locale locale) {
        return locale != null && "en".equalsIgnoreCase(locale.getLanguage());
    }
}
