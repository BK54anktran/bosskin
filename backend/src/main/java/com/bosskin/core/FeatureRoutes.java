package com.bosskin.core;

import org.springframework.util.AntPathMatcher;

import java.util.List;

/**
 * Bảng đường dẫn API → tính năng (V26). Khớp theo thứ tự, mục cụ thể đứng trước mục chung; API không có trong bảng là phần
 * nền (luôn có) hoặc do nghiệp vụ tự kiểm ({@link CompanyFeatures#require}). {@code FeatureRouteInterceptor} dùng bảng này
 * để trả 403 cho công ty đã tắt tính năng — một chỗ duy nhất, không rải kiểm tra vào từng endpoint.
 */
public final class FeatureRoutes {

    private record Route(String method, String pattern, String feature) {}

    private static final AntPathMatcher MATCHER = new AntPathMatcher();

    private static Route any(String pattern, String feature) { return new Route(null, pattern, feature); }

    private static final List<Route> ROUTES = List.of(
        // Chấm công
        any("/api/v1/attendances/self/**", CompanyFeatures.ATT_SELF),
        any("/api/v1/attendance-requests/**", CompanyFeatures.ATT_REQUEST),
        any("/api/v1/attendance-periods/**", CompanyFeatures.ATT_SHEET),
        any("/api/v1/attendances/**", CompanyFeatures.ATT_SHEET),
        any("/api/v1/employees/*/locations/**", CompanyFeatures.ATT_GEOFENCE),
        any("/api/v1/map-tiles/**", CompanyFeatures.ATT_GEOFENCE),
        // Ca làm
        any("/api/v1/shift-rotations/**", CompanyFeatures.SHIFT_ROTATION),
        any("/api/v1/shift-swaps/**", CompanyFeatures.SHIFT_SWAP),
        any("/api/v1/shift-registration-rounds/**", CompanyFeatures.SHIFT_REGISTRATION),
        any("/api/v1/shift-registrations/**", CompanyFeatures.SHIFT_REGISTRATION),
        any("/api/v1/shifts/**", CompanyFeatures.SHIFT_BASIC),
        // Lịch & ngày lễ (xem lịch hiệu lực /work-calendars/view luôn đọc được: lưới ca, bảng công dùng để tô ngày nghỉ)
        any("/api/v1/work-calendars/view", null),
        any("/api/v1/work-calendars/**", CompanyFeatures.CAL_WORKCAL),
        any("/api/v1/holidays/**", CompanyFeatures.CAL_HOLIDAY),
        // Nghỉ phép
        any("/api/v1/leaves/accrual-rules/**", CompanyFeatures.LEAVE_ACCRUAL),
        any("/api/v1/leaves/grants/**", CompanyFeatures.LEAVE_BALANCE),
        any("/api/v1/leaves/ledger", CompanyFeatures.LEAVE_BALANCE),
        any("/api/v1/leaves/**", CompanyFeatures.LEAVE_BASIC),
        // Tính lương
        any("/api/v1/salary-formulas/**", CompanyFeatures.PAY_FORMULA),
        any("/api/v1/formula-variables/**", CompanyFeatures.PAY_FORMULA),
        any("/api/v1/dependents/**", CompanyFeatures.PAY_DEPENDENT),
        any("/api/v1/payrolls/**", CompanyFeatures.PAY_BASIC),
        any("/api/v1/payroll/**", CompanyFeatures.PAY_BASIC),
        any("/api/v1/salary-grades/**", CompanyFeatures.PAY_BASIC),
        any("/api/v1/salary-histories/**", CompanyFeatures.PAY_BASIC),
        // Nhân sự mở rộng
        any("/api/v1/contracts/**", CompanyFeatures.HR_CONTRACT),
        any("/api/v1/document-types/**", CompanyFeatures.HR_DOCUMENT),
        any("/api/v1/employee-documents/**", CompanyFeatures.HR_DOCUMENT),
        any("/api/v1/org-chart", CompanyFeatures.HR_ORGCHART),
        any("/api/v1/employees/*/job-histories", CompanyFeatures.HR_JOBHISTORY),
        any("/api/v1/employees/job-histories/**", CompanyFeatures.HR_JOBHISTORY),
        any("/api/v1/team-approvals/**", CompanyFeatures.HR_MANAGER_APPROVAL),
        // Báo cáo & dữ liệu
        any("/api/v1/reports/payroll-summary", CompanyFeatures.RPT_PAYROLL),
        any("/api/v1/reports/insured-employees", CompanyFeatures.RPT_INSURANCE),
        any("/api/v1/reports/dependents", CompanyFeatures.RPT_INSURANCE),
        any("/api/v1/reports/**", CompanyFeatures.RPT_OVERVIEW),
        any("/api/v1/excel/**", CompanyFeatures.DATA_EXCEL));

    private FeatureRoutes() {}

    /** Tính năng của API này; null = không thuộc tính năng nào (phần nền, hoặc mục chủ ý để trống). */
    public static String featureOf(String method, String path) {
        if (path == null) return null;
        for (Route r : ROUTES) {
            if (r.method() != null && !r.method().equalsIgnoreCase(method)) continue;
            if (MATCHER.match(r.pattern(), path)) return r.feature();
        }
        return null;
    }

    /** Dùng cho test: mọi đường dẫn mẫu của bảng, kèm tính năng. */
    static List<String[]> samples() {
        return ROUTES.stream().filter(r -> r.feature() != null)
            .map(r -> new String[]{r.pattern().replace("**", "x").replace("*", "1"), r.feature()}).toList();
    }
}
