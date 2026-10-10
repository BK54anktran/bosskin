package com.bosskin.service;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * D6 — cấp mã nhân viên "EMP00001", "EMP00002"… theo bộ đếm riêng từng công ty
 * (bảng employee_code_counters, V19).
 *
 * <p>Dòng bộ đếm bị khoá (SELECT … FOR UPDATE) tới khi transaction của người gọi kết thúc,
 * nên hai yêu cầu tạo nhân viên cùng lúc không lấy trùng mã. Mã đã dùng (kể cả của NV đã xoá
 * hoặc nhập tay qua Excel) được bỏ qua, nên không bao giờ cấp lại.
 */
@Service
@RequiredArgsConstructor
public class EmployeeCodeService {

    public static final String PREFIX = "EMP";

    private final JdbcTemplate jdbc;

    @Transactional(propagation = Propagation.MANDATORY)
    public String next(Long companyId) {
        Integer current = lockCounter(companyId);
        if (current == null) {
            Integer seed = jdbc.queryForObject("""
                SELECT COALESCE(MAX(CAST(SUBSTRING(employee_code, 4) AS UNSIGNED)), 0)
                FROM employees WHERE company_id = ? AND employee_code REGEXP '^EMP[0-9]+$'
                """, Integer.class, companyId);
            jdbc.update("INSERT IGNORE INTO employee_code_counters (company_id, last_seq) VALUES (?, ?)",
                companyId, seed == null ? 0 : seed);
            current = lockCounter(companyId);
        }
        int value = current;
        String code;
        do {
            value++;
            code = format(value);
        } while (codeUsed(companyId, code));
        jdbc.update("UPDATE employee_code_counters SET last_seq = ? WHERE company_id = ?", value, companyId);
        return code;
    }

    public static String format(int value) {
        return String.format("%s%05d", PREFIX, value);
    }

    private Integer lockCounter(Long companyId) {
        List<Integer> rows = jdbc.queryForList(
            "SELECT last_seq FROM employee_code_counters WHERE company_id = ? FOR UPDATE", Integer.class, companyId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    /** Kể cả nhân viên đã xoá mềm — truy vấn thẳng bảng, không qua bộ lọc deleted của entity. */
    private boolean codeUsed(Long companyId, String code) {
        Integer n = jdbc.queryForObject(
            "SELECT COUNT(*) FROM employees WHERE company_id = ? AND employee_code = ?", Integer.class, companyId, code);
        return n != null && n > 0;
    }
}
