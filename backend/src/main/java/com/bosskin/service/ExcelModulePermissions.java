package com.bosskin.service;

import com.bosskin.entity.User;

import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Universal Excel (S8): ngoài quyền chung EXCEL_EXPORT / EXCEL_IMPORT, mỗi module
 * cần đúng quyền của module đó. Trước đây ai có EXCEL_EXPORT là xuất được cả bảng lương.
 *
 * Module chưa khai báo ở đây coi như không ai được xuất/nhập (đóng mặc định).
 */
public final class ExcelModulePermissions {

    private record Rule(String exportPerm, String importPerm) {}

    private static final Map<String, Rule> RULES = Map.ofEntries(
        Map.entry("employee",         new Rule("EMPLOYEE_VIEW",   "EMPLOYEE_CREATE")),
        Map.entry("department",       new Rule("DEPARTMENT_VIEW", "DEPARTMENT_MANAGE")),
        Map.entry("position",         new Rule("DEPARTMENT_VIEW", "POSITION_MANAGE")),
        Map.entry("shift",            new Rule("SHIFT_VIEW",      "SHIFT_MANAGE")),
        Map.entry("shift_assignment", new Rule("SHIFT_VIEW",      "SHIFT_MANAGE")),
        Map.entry("attendance",       new Rule("ATTENDANCE_VIEW", "ATTENDANCE_MANAGE")),
        Map.entry("leave_type",       new Rule("LEAVE_TYPE_VIEW", "LEAVE_TYPE_MANAGE")),
        Map.entry("leave_grant",      new Rule("LEAVE_VIEW",      "LEAVE_GRANT_MANUAL")),
        Map.entry("payroll",          new Rule("PAYROLL_VIEW",    null)),
        Map.entry("salary_grade",     new Rule("PAYROLL_VIEW",    "PAYROLL_CREATE")),
        Map.entry("salary_formula",   new Rule("PAYROLL_VIEW",    "PAYROLL_CREATE")),
        Map.entry("formula_variable", new Rule("PAYROLL_VIEW",    "PAYROLL_CREATE"))
    );

    private ExcelModulePermissions() {}

    public static boolean canExport(User user, String type) {
        Rule r = RULES.get(type);
        return r != null && r.exportPerm() != null && user.hasPermission(r.exportPerm());
    }

    public static boolean canImport(User user, String type) {
        Rule r = RULES.get(type);
        return r != null && r.importPerm() != null && user.hasPermission(r.importPerm());
    }

    public static Set<String> exportableTypes(User user) {
        return RULES.keySet().stream().filter(t -> canExport(user, t)).collect(Collectors.toSet());
    }

    public static Set<String> importableTypes(User user) {
        return RULES.keySet().stream().filter(t -> canImport(user, t)).collect(Collectors.toSet());
    }
}
