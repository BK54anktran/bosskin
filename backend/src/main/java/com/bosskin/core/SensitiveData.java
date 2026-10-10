package com.bosskin.core;

import com.bosskin.entity.User;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * Bước M (đóng D5) — che CCCD, số tài khoản, MST, số sổ BHXH với người không có quyền
 * {@code EMPLOYEE_SENSITIVE_VIEW}: chỉ để lộ 4 ký tự cuối.
 */
public final class SensitiveData {

    public static final String PERMISSION = "EMPLOYEE_SENSITIVE_VIEW";
    private static final char MASK = '*';

    private SensitiveData() {}

    /** Người dùng của request hiện tại được xem đủ? Không có người dùng (job nền) → được. */
    public static boolean canView() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof User u)) return true;
        return u.hasPermission(PERMISSION);
    }

    public static String mask(String v) {
        if (v == null || v.isEmpty()) return v;
        int keep = v.length() > 4 ? 4 : 0;
        return String.valueOf(MASK).repeat(v.length() - keep) + v.substring(v.length() - keep);
    }

    /** Che nếu người dùng hiện tại không có quyền. */
    public static String forViewer(String v) {
        return canView() ? v : mask(v);
    }

    /**
     * Giá trị gửi lên khi sửa: người không có quyền gửi lại đúng bản đã che (form giữ nguyên) → giữ giá trị cũ.
     * Trả {@code current} khi không đổi, ngược lại trả giá trị mới.
     */
    public static String incoming(String current, String sent) {
        if (sent == null || canView()) return sent;
        if (current != null && sent.equals(mask(current))) return current;
        return sent;
    }
}
