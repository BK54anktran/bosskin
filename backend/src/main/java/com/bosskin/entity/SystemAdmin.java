package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

@Entity
@Table(name = "system_admins")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SystemAdmin extends BaseEntity implements UserDetails, com.bosskin.core.TwoFactorHolder {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "email", nullable = false, unique = true, length = 100)
    private String email;

    @Column(name = "password", nullable = false)
    private String password;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "enabled", nullable = false)
    @Builder.Default
    private boolean enabled = true;

    /** Bước C — 2FA (TOTP). */
    @Column(name = "totp_secret", length = 64)
    private String totpSecret;

    @Column(name = "totp_enabled", nullable = false)
    @Builder.Default
    private boolean totpEnabled = false;

    /** JSON mảng mã dự phòng đã băm bcrypt. */
    @Column(name = "totp_recovery_codes", columnDefinition = "text")
    private String totpRecoveryCodes;

    @Override public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_SYSTEM_ADMIN"));
    }
    @Override public String getUsername() { return email; }
    @Override public boolean isAccountNonExpired()     { return true; }
    @Override public boolean isAccountNonLocked()      { return true; }
    @Override public boolean isCredentialsNonExpired() { return true; }
}
