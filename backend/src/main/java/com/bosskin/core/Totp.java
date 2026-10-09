package com.bosskin.core;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.URLEncoder;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Instant;

/**
 * Bước C — TOTP theo RFC 6238 (HMAC-SHA1, 30 giây, 6 chữ số), tương thích Google Authenticator,
 * Microsoft Authenticator… Cho phép lệch ±1 bước (30 giây) do đồng hồ điện thoại.
 */
public final class Totp {

    private static final String BASE32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int STEP_SECONDS = 30;

    private Totp() {}

    /** Khoá ngẫu nhiên 160 bit, mã hoá base32 (32 ký tự). */
    public static String generateSecret() {
        byte[] b = new byte[20];
        RANDOM.nextBytes(b);
        return base32Encode(b);
    }

    /** URI cho mã QR: otpauth://totp/Issuer:account?secret=…&issuer=… */
    public static String uri(String issuer, String account, String secret) {
        String label = enc(issuer) + ":" + enc(account);
        return "otpauth://totp/" + label + "?secret=" + secret + "&issuer=" + enc(issuer)
            + "&algorithm=SHA1&digits=6&period=" + STEP_SECONDS;
    }

    public static boolean verify(String secret, String code, Instant now) {
        if (secret == null || code == null) return false;
        String c = code.replaceAll("\\s", "");
        if (!c.matches("\\d{6}")) return false;
        long step = now.getEpochSecond() / STEP_SECONDS;
        for (long s = step - 1; s <= step + 1; s++) {
            if (code(secret, s).equals(c)) return true;
        }
        return false;
    }

    /** Mã của bước thời gian {@code step} (dùng trong test). */
    public static String code(String secret, long step) {
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(base32Decode(secret), "HmacSHA1"));
            byte[] h = mac.doFinal(ByteBuffer.allocate(8).putLong(step).array());
            int o = h[h.length - 1] & 0x0f;
            int bin = ((h[o] & 0x7f) << 24) | ((h[o + 1] & 0xff) << 16) | ((h[o + 2] & 0xff) << 8) | (h[o + 3] & 0xff);
            return String.format("%06d", bin % 1_000_000);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    public static String codeAt(String secret, Instant now) {
        return code(secret, now.getEpochSecond() / STEP_SECONDS);
    }

    static String base32Encode(byte[] data) {
        StringBuilder sb = new StringBuilder();
        int buffer = 0, bits = 0;
        for (byte b : data) {
            buffer = (buffer << 8) | (b & 0xff);
            bits += 8;
            while (bits >= 5) {
                sb.append(BASE32.charAt((buffer >> (bits - 5)) & 31));
                bits -= 5;
            }
        }
        if (bits > 0) sb.append(BASE32.charAt((buffer << (5 - bits)) & 31));
        return sb.toString();
    }

    static byte[] base32Decode(String s) {
        String in = s.toUpperCase().replaceAll("[^A-Z2-7]", "");
        ByteBuffer out = ByteBuffer.allocate(in.length() * 5 / 8);
        int buffer = 0, bits = 0;
        for (char ch : in.toCharArray()) {
            buffer = (buffer << 5) | BASE32.indexOf(ch);
            bits += 5;
            if (bits >= 8) {
                out.put((byte) ((buffer >> (bits - 8)) & 0xff));
                bits -= 8;
            }
        }
        byte[] r = new byte[out.position()];
        out.flip();
        out.get(r);
        return r;
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
