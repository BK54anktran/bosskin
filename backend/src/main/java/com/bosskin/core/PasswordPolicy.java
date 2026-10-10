package com.bosskin.core;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Chính sách mật khẩu tối thiểu (Mốc 1): ≥ 8 ký tự, có chữ và có số. */
public final class PasswordPolicy {

    public static final int MIN_LENGTH = 8;

    private PasswordPolicy() {}

    public static boolean isStrong(String pw) {
        if (pw == null || pw.length() < MIN_LENGTH) return false;
        boolean letter = false, digit = false;
        for (char ch : pw.toCharArray()) {
            if (Character.isLetter(ch)) letter = true;
            else if (Character.isDigit(ch)) digit = true;
        }
        return letter && digit;
    }

    private static final java.security.SecureRandom RANDOM = new java.security.SecureRandom();
    private static final String LOWER = "abcdefghijkmnpqrstuvwxyz", UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ",
        DIGIT = "23456789", SYMBOL = "@#$%&*+-=?";

    /** Mật khẩu ngẫu nhiên đủ chữ thường/hoa/số/ký hiệu, bỏ ký tự dễ nhầm (l, 1, O, 0). */
    public static String generate(int length) {
        String all = LOWER + UPPER + DIGIT + SYMBOL;
        char[] c = new char[Math.max(length, MIN_LENGTH)];
        c[0] = pick(LOWER); c[1] = pick(UPPER); c[2] = pick(DIGIT); c[3] = pick(SYMBOL);
        for (int i = 4; i < c.length; i++) c[i] = pick(all);
        for (int i = c.length - 1; i > 0; i--) { int j = RANDOM.nextInt(i + 1); char t = c[i]; c[i] = c[j]; c[j] = t; }
        return new String(c);
    }

    private static char pick(String s) { return s.charAt(RANDOM.nextInt(s.length())); }

    /** Ném 400 error.password.weak nếu mật khẩu không đạt chính sách. */
    public static void require(String pw) {
        if (!isStrong(pw)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.password.weak");
    }
}
