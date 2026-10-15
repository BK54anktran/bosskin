package com.bosskin.core;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Tính năng của công ty (V26): system admin bật / tắt từng tính năng, mịn hơn 7 gói của V24 ({@link CompanyModules}).
 * Lưu danh sách tính năng TẮT ở companies.disabled_features (NULL = bật hết). Phần nền (nhân viên, phòng ban, phân quyền,
 * cài đặt, tổng quan, nhật ký, bảo mật) luôn có và không nằm trong danh mục.
 *
 * <p>Chặn theo ba lớp: (1) {@link #filter} bỏ mã quyền gắn riêng với tính năng tắt; (2) {@link FeatureRoutes} + interceptor trả
 * 403 {@code error.company.feature_disabled} cho API của tính năng; (3) hành vi trong nghiệp vụ / job nền kiểm {@link #require}
 * hoặc {@code User.isFeatureDisabled}. FE nhận {@code features} lúc đăng nhập / làm mới token.
 *
 * <p>Tương thích V24: mỗi tính năng thuộc tối đa một gói cũ ({@link Feature#module()}); gói cũ coi là bật khi tính năng gốc
 * của nó bật ({@link #modulesOf}), để app điện thoại đã cài (chỉ đọc {@code modules}) tiếp tục chạy.
 */
public final class CompanyFeatures {

    /** @param group nhóm hiển thị; @param module gói V24 tương ứng (null = trước đây thuộc phần lõi); @param requires phải bật kèm. */
    public record Feature(String code, String group, String module, List<String> requires) {}

    private static Feature f(String code, String group, String module, String... requires) {
        return new Feature(code, group, module, List.of(requires));
    }

    public static final String ATT_SHEET = "ATT_SHEET", ATT_SELF = "ATT_SELF", ATT_GEOFENCE = "ATT_GEOFENCE",
        ATT_DEVICE = "ATT_DEVICE", ATT_NOSHIFT = "ATT_NOSHIFT", ATT_REQUEST = "ATT_REQUEST",
        SHIFT_BASIC = "SHIFT_BASIC", SHIFT_ADVANCED = "SHIFT_ADVANCED", SHIFT_ROTATION = "SHIFT_ROTATION",
        SHIFT_SWAP = "SHIFT_SWAP", SHIFT_REGISTRATION = "SHIFT_REGISTRATION", SHIFT_REMINDER = "SHIFT_REMINDER",
        CAL_WORKCAL = "CAL_WORKCAL", CAL_HOLIDAY = "CAL_HOLIDAY",
        LEAVE_BASIC = "LEAVE_BASIC", LEAVE_BALANCE = "LEAVE_BALANCE", LEAVE_ACCRUAL = "LEAVE_ACCRUAL",
        PAY_BASIC = "PAY_BASIC", PAY_FORMULA = "PAY_FORMULA", PAY_TAX_INS = "PAY_TAX_INS",
        PAY_DEPENDENT = "PAY_DEPENDENT", PAY_EMPLOYER_COST = "PAY_EMPLOYER_COST",
        HR_CONTRACT = "HR_CONTRACT", HR_CONTRACT_ALERT = "HR_CONTRACT_ALERT", HR_DOCUMENT = "HR_DOCUMENT",
        HR_DOCUMENT_ALERT = "HR_DOCUMENT_ALERT", HR_ORGCHART = "HR_ORGCHART", HR_JOBHISTORY = "HR_JOBHISTORY",
        HR_MANAGER_APPROVAL = "HR_MANAGER_APPROVAL",
        RPT_OVERVIEW = "RPT_OVERVIEW", RPT_PAYROLL = "RPT_PAYROLL", RPT_INSURANCE = "RPT_INSURANCE", DATA_EXCEL = "DATA_EXCEL";

    /** Thứ tự = thứ tự hiển thị; tính năng đầu tiên của mỗi gói cũ là tính năng gốc của gói đó. */
    public static final List<Feature> CATALOG = List.of(
        f(ATT_SHEET, "ATTENDANCE", CompanyModules.ATTENDANCE),
        f(ATT_SELF, "ATTENDANCE", CompanyModules.ATTENDANCE, ATT_SHEET),
        f(ATT_GEOFENCE, "ATTENDANCE", CompanyModules.ATTENDANCE, ATT_SELF),
        f(ATT_DEVICE, "ATTENDANCE", CompanyModules.ATTENDANCE, ATT_SELF),
        f(ATT_NOSHIFT, "ATTENDANCE", CompanyModules.ATTENDANCE, ATT_SELF),
        f(ATT_REQUEST, "ATTENDANCE", CompanyModules.ATTENDANCE, ATT_SHEET),
        f(SHIFT_BASIC, "SHIFT", CompanyModules.SHIFT),
        f(SHIFT_ADVANCED, "SHIFT", CompanyModules.SHIFT, SHIFT_BASIC),
        f(SHIFT_ROTATION, "SHIFT", CompanyModules.SHIFT, SHIFT_BASIC),
        f(SHIFT_SWAP, "SHIFT", CompanyModules.SHIFT, SHIFT_BASIC),
        f(SHIFT_REGISTRATION, "SHIFT", CompanyModules.SHIFT, SHIFT_BASIC),
        f(SHIFT_REMINDER, "SHIFT", CompanyModules.SHIFT, SHIFT_BASIC),
        f(CAL_WORKCAL, "CALENDAR", null),
        f(CAL_HOLIDAY, "CALENDAR", null),
        f(LEAVE_BASIC, "LEAVE", CompanyModules.LEAVE),
        f(LEAVE_BALANCE, "LEAVE", CompanyModules.LEAVE, LEAVE_BASIC),
        f(LEAVE_ACCRUAL, "LEAVE", CompanyModules.LEAVE, LEAVE_BALANCE),
        f(PAY_BASIC, "PAYROLL", CompanyModules.PAYROLL),
        f(PAY_FORMULA, "PAYROLL", CompanyModules.PAYROLL, PAY_BASIC),
        f(PAY_TAX_INS, "PAYROLL", CompanyModules.PAYROLL, PAY_BASIC),
        f(PAY_DEPENDENT, "PAYROLL", CompanyModules.PAYROLL, PAY_TAX_INS),
        f(PAY_EMPLOYER_COST, "PAYROLL", CompanyModules.PAYROLL, PAY_TAX_INS),
        f(HR_CONTRACT, "HR", CompanyModules.CONTRACT),
        f(HR_CONTRACT_ALERT, "HR", CompanyModules.CONTRACT, HR_CONTRACT),
        f(HR_DOCUMENT, "HR", CompanyModules.DOCUMENT),
        f(HR_DOCUMENT_ALERT, "HR", CompanyModules.DOCUMENT, HR_DOCUMENT),
        f(HR_ORGCHART, "HR", null),
        f(HR_JOBHISTORY, "HR", null),
        f(HR_MANAGER_APPROVAL, "HR", null, HR_ORGCHART),
        f(RPT_OVERVIEW, "REPORT", CompanyModules.REPORT),
        f(RPT_PAYROLL, "REPORT", CompanyModules.REPORT, PAY_BASIC),
        f(RPT_INSURANCE, "REPORT", CompanyModules.REPORT, PAY_DEPENDENT),
        f(DATA_EXCEL, "REPORT", null));

    public static final List<String> ALL = CATALOG.stream().map(Feature::code).toList();

    private static final Map<String, Feature> BY_CODE = CATALOG.stream()
        .collect(Collectors.toUnmodifiableMap(Feature::code, x -> x));

    private CompanyFeatures() {}

    public static boolean exists(String code) { return code != null && BY_CODE.containsKey(code); }

    /** Tính năng gốc của gói cũ (ATTENDANCE → ATT_SHEET…); null nếu không phải gói cũ. */
    public static String baseOf(String module) {
        for (Feature x : CATALOG) if (Objects.equals(x.module(), module)) return x.code();
        return null;
    }

    /**
     * Mã quyền → tính năng sở hữu riêng mã đó (null = phần lõi / dùng chung nhiều tính năng). Quyền chung kiểu "tôi là nhân viên"
     * (ATTENDANCE_SELF, dùng cả cho phiếu lương và đổi ca) thuộc tính năng gốc của gói, không thuộc ATT_SELF.
     */
    public static String featureOfPermission(String code) {
        if (code == null) return null;
        if (code.startsWith("EMPLOYEE_DOCUMENT_")) return HR_DOCUMENT;
        if (code.startsWith("SHIFT_REGISTRATION_")) return SHIFT_REGISTRATION;
        if (code.equals("SHIFT_SWAP_APPROVE")) return SHIFT_SWAP;
        if (code.equals("ATTENDANCE_REQUEST_APPROVE")) return ATT_REQUEST;
        if (code.startsWith("LEAVE_ACCRUAL_")) return LEAVE_ACCRUAL;
        if (code.equals("LEAVE_GRANT_MANUAL")) return LEAVE_BALANCE;
        String module = CompanyModules.moduleOf(code);
        return module == null ? null : baseOf(module);
    }

    /** Chuỗi lưu DB → tập tính năng đang tắt (mã lạ bị bỏ). */
    public static Set<String> parse(String stored) {
        if (stored == null || stored.isBlank()) return Set.of();
        return Arrays.stream(stored.split(",")).map(String::trim).filter(BY_CODE::containsKey)
            .collect(Collectors.toUnmodifiableSet());
    }

    /** Tập tính năng tắt → chuỗi lưu DB theo thứ tự danh mục (rỗng → NULL = bật hết). */
    public static String format(Collection<String> disabled) {
        String s = ALL.stream().filter(disabled::contains).collect(Collectors.joining(","));
        return s.isEmpty() ? null : s;
    }

    /** Bỏ các quyền thuộc tính năng đang tắt. */
    public static Set<String> filter(Set<String> permissionCodes, Set<String> disabled) {
        if (disabled.isEmpty()) return permissionCodes;
        return permissionCodes.stream()
            .filter(code -> { String x = featureOfPermission(code); return x == null || !disabled.contains(x); })
            .collect(Collectors.toSet());
    }

    /**
     * Danh sách tính năng BẬT gửi lên → tập tính năng TẮT. Mã lạ → error.company.feature_invalid|mã; bật tính năng mà tắt
     * tính năng nó cần → error.company.feature_requires|tính năng|cần; tự chấm công cần Ca làm cơ bản hoặc chấm khi không có ca
     * → error.company.feature_requires_any|ATT_SELF|SHIFT_BASIC|ATT_NOSHIFT.
     */
    public static Set<String> disabledFromEnabled(Collection<String> enabled) {
        Set<String> on = new HashSet<>();
        for (String code : enabled) {
            String k = code == null ? "" : code.trim().toUpperCase();
            if (!BY_CODE.containsKey(k)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.feature_invalid|" + code);
            }
            on.add(k);
        }
        for (Feature x : CATALOG) {
            if (!on.contains(x.code())) continue;
            for (String need : x.requires()) {
                if (!on.contains(need)) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "error.company.feature_requires|" + x.code() + "|" + need);
                }
            }
        }
        if (on.contains(ATT_SELF) && !on.contains(SHIFT_BASIC) && !on.contains(ATT_NOSHIFT)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.company.feature_requires_any|" + ATT_SELF + "|" + SHIFT_BASIC + "|" + ATT_NOSHIFT);
        }
        return ALL.stream().filter(c -> !on.contains(c)).collect(Collectors.toSet());
    }

    /** Tương thích: danh sách gói cũ BẬT gửi lên → tập tính năng TẮT (gói cũ tắt ⇒ mọi tính năng con tắt; phần lõi cũ giữ bật). */
    public static Set<String> disabledFromModules(Collection<String> enabledModules) {
        Set<String> disabledModules = new HashSet<>(CompanyModules.disabledFromEnabled(enabledModules));
        return CATALOG.stream().filter(x -> x.module() != null && disabledModules.contains(x.module()))
            .map(Feature::code).collect(Collectors.toSet());
    }

    public static List<String> enabledOf(Set<String> disabled) {
        return ALL.stream().filter(c -> !disabled.contains(c)).toList();
    }

    /** Gói cũ đang bật = tính năng gốc của gói còn bật (cho app đã cài chỉ đọc {@code modules}). */
    public static List<String> modulesOf(Set<String> disabled) {
        return CompanyModules.ALL.stream().filter(m -> !disabled.contains(baseOf(m))).toList();
    }

    public static void require(com.bosskin.entity.Company company, String feature) {
        if (company != null && company.disabledFeatureSet().contains(feature)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.feature_disabled");
        }
    }

    public static void require(com.bosskin.entity.User user, String feature) {
        if (user != null && user.isFeatureDisabled(feature)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.feature_disabled");
        }
    }
}
