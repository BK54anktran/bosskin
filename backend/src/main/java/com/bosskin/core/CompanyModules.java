package com.bosskin.core;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;
import java.util.stream.Collectors;

/**
 * 7 gói chức năng của V24 — từ V26 chỉ còn là lớp tương thích: mỗi gói = tính năng gốc của nó ({@link CompanyFeatures#baseOf}),
 * app điện thoại đã cài vẫn đọc {@code modules}. Việc bật / tắt thật sự nằm ở {@link CompanyFeatures}.
 */
public final class CompanyModules {

    public static final String ATTENDANCE = "ATTENDANCE";
    public static final String SHIFT = "SHIFT";
    public static final String LEAVE = "LEAVE";
    public static final String PAYROLL = "PAYROLL";
    public static final String CONTRACT = "CONTRACT";
    public static final String DOCUMENT = "DOCUMENT";
    public static final String REPORT = "REPORT";

    /** Thứ tự hiển thị. */
    public static final List<String> ALL = List.of(ATTENDANCE, SHIFT, LEAVE, PAYROLL, CONTRACT, DOCUMENT, REPORT);

    /** Gói → gói bắt buộc phải bật kèm (chấm công dựa trên phân ca). */
    public static final Map<String, String> REQUIRES = Map.of(ATTENDANCE, SHIFT);

    private CompanyModules() {}

    /** Mã quyền thuộc gói nào (null = phần lõi, luôn có). */
    public static String moduleOf(String permissionCode) {
        if (permissionCode == null) return null;
        if (permissionCode.startsWith("EMPLOYEE_DOCUMENT_")) return DOCUMENT;
        if (permissionCode.startsWith("ATTENDANCE_")) return ATTENDANCE;
        if (permissionCode.startsWith("SHIFT_")) return SHIFT;
        if (permissionCode.startsWith("LEAVE_")) return LEAVE;
        if (permissionCode.startsWith("PAYROLL_")) return PAYROLL;
        if (permissionCode.startsWith("CONTRACT_")) return CONTRACT;
        if (permissionCode.startsWith("REPORT_")) return REPORT;
        return null;
    }

    /**
     * Kiểm danh sách gói BẬT gửi lên → tập gói TẮT. Mã lạ → error.company.module_invalid|mã; bật gói mà tắt gói nó cần →
     * error.company.module_requires|gói|gói cần.
     */
    public static Set<String> disabledFromEnabled(Collection<String> enabled) {
        Set<String> on = new HashSet<>();
        for (String m : enabled) {
            String k = m == null ? "" : m.trim().toUpperCase();
            if (!ALL.contains(k)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.module_invalid|" + m);
            on.add(k);
        }
        REQUIRES.forEach((module, needs) -> {
            if (on.contains(module) && !on.contains(needs)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.module_requires|" + module + "|" + needs);
            }
        });
        return ALL.stream().filter(m -> !on.contains(m)).collect(Collectors.toSet());
    }

    /** API thuộc gói nhưng chỉ kiểm quyền lõi / quyền gói khác (vd. phiếu lương của tôi) → 403 khi gói tắt. */
    public static void requireEnabled(com.bosskin.entity.Company company, String module) {
        if (company != null && company.disabledFeatureSet().contains(CompanyFeatures.baseOf(module))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.module_disabled");
        }
    }

    public static void requireEnabled(com.bosskin.entity.User user, String module) {
        if (user != null && user.isModuleDisabled(module)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.company.module_disabled");
        }
    }
}
