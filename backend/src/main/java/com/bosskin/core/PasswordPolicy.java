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

    /** Ném 400 error.password.weak nếu mật khẩu không đạt chính sách. */
    public static void require(String pw) {
        if (!isStrong(pw)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.password.weak");
    }
}
