package com.bosskin.core;

import com.bosskin.entity.Company;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Định danh theo công ty (V22): mã công ty là tiền tố của mọi mã nhân viên, đuôi email (domain)
 * là đuôi bắt buộc của mọi tài khoản trong công ty.
 *
 * <p>Mã công ty: 2–12 ký tự, chữ hoa + số, bắt đầu bằng chữ; không trùng và không là tiền tố của mã
 * công ty khác (kiểm ở {@code CompanyService}) → mã NV {@code <MÃ CTY><số>} không trùng giữa các công ty.
 * Mã công ty không đổi được sau khi tạo.
 */
public final class CompanyIdentity {

    public static final int CODE_MAX = 12;
    private static final Pattern CODE = Pattern.compile("^[A-Z][A-Z0-9]{1," + (CODE_MAX - 1) + "}$");
    private static final Pattern DOMAIN =
        Pattern.compile("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$");

    private CompanyIdentity() {}

    /** Chuẩn hoá + kiểm mã công ty (chữ hoa); sai → 400 error.company.code_invalid. */
    public static String normalizeCode(String code) {
        String c = code == null ? "" : code.trim().toUpperCase(Locale.ROOT);
        if (!CODE.matcher(c).matches()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.code_invalid");
        }
        return c;
    }

    /** Chuẩn hoá đuôi email: bỏ khoảng trắng, "@" đầu, chữ thường. Trống → null. Sai → 400 error.company.domain_invalid. */
    public static String normalizeDomain(String domain) {
        if (domain == null) return null;
        String d = domain.trim().toLowerCase(Locale.ROOT);
        while (d.startsWith("@")) d = d.substring(1);
        if (d.isEmpty()) return null;
        if (d.length() > 100 || !DOMAIN.matcher(d).matches()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.domain_invalid");
        }
        return d;
    }

    /** Email có đúng đuôi {@code @domain} không (công ty chưa đặt đuôi → luôn đúng). */
    public static boolean emailMatches(String domain, String email) {
        if (domain == null || domain.isBlank()) return true;
        if (email == null) return false;
        return email.trim().toLowerCase(Locale.ROOT).endsWith("@" + domain.toLowerCase(Locale.ROOT));
    }

    /** Email tài khoản phải theo đuôi công ty; sai → 400 error.email.domain_mismatch|domain. */
    public static void requireEmail(Company company, String email) {
        if (!emailMatches(company.getDomain(), email)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.email.domain_mismatch|" + company.getDomain());
        }
    }

    /** Mã NV phải bắt đầu bằng mã công ty và có thêm ít nhất 1 ký tự. */
    public static boolean codeMatches(String companyCode, String employeeCode) {
        if (employeeCode == null) return false;
        String c = employeeCode.trim().toUpperCase(Locale.ROOT);
        return c.length() > companyCode.length() && c.startsWith(companyCode.toUpperCase(Locale.ROOT));
    }

    /** Mã NV nhập tay (Excel) sai tiền tố → 400 error.employee.code_prefix|MÃ CTY|mã NV. */
    public static void requireEmployeeCode(Company company, String employeeCode) {
        if (!codeMatches(company.getCode(), employeeCode)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.employee.code_prefix|" + company.getCode() + "|" + employeeCode);
        }
    }
}
