package com.bosskin.core;

/** Bước C — tài khoản có 2FA (User, SystemAdmin). Lombok sinh sẵn các getter/setter này. */
public interface TwoFactorHolder {
    String getEmail();
    String getTotpSecret();
    void setTotpSecret(String secret);
    boolean isTotpEnabled();
    void setTotpEnabled(boolean enabled);
    String getTotpRecoveryCodes();
    void setTotpRecoveryCodes(String json);
}
