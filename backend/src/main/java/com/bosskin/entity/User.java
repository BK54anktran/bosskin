package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.Where;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;

@Entity
@Table(
    name = "users",
    uniqueConstraints = @UniqueConstraint(name = "uq_user_email_deleted", columnNames = {"email", "deleted"})
)
@SQLDelete(sql = "UPDATE users SET deleted = true WHERE id = ?")
@Where(clause = "deleted = false")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class User extends BaseEntity implements UserDetails, com.bosskin.core.TwoFactorHolder {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "email", nullable = false, unique = true, length = 100)
    private String email;

    @Column(name = "password", nullable = false)
    private String password;

    @Column(name = "company_id", insertable = false, updatable = false)
    private Long companyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id", nullable = false)
    private Company company;

    @Column(name = "employee_id", insertable = false, updatable = false)
    private Long employeeId;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id")
    private Employee employee;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    @Builder.Default
    private Set<Role> roles = new HashSet<>();

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "user_permissions",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    @Builder.Default
    private Set<Permission> directPermissions = new HashSet<>();

    @Column(name = "fcm_token", length = 512)
    private String fcmToken;

    /** Ngôn ngữ ưa dùng ("vi" | "en") theo header Accept-Language gần nhất; null = vi. Dùng cho thông báo đẩy. */
    @Column(name = "language", length = 5)
    private String language;

    @Column(name = "shift_reminder_minutes")
    private Integer shiftReminderMinutes;

    @Column(name = "check_in_out_notif_minutes")
    private Integer checkInOutNotifMinutes;

    @Column(name = "enabled", nullable = false)
    @Builder.Default
    private boolean enabled = true;

    /** Mật khẩu do người khác đặt → phải đổi ở lần đăng nhập đầu (V7). */
    @Column(name = "must_change_password", nullable = false)
    @Builder.Default
    private boolean mustChangePassword = false;

    /** Bước C — 2FA (TOTP). */
    @Column(name = "totp_secret", length = 64)
    private String totpSecret;

    @Column(name = "totp_enabled", nullable = false)
    @Builder.Default
    private boolean totpEnabled = false;

    /** JSON mảng mã dự phòng đã băm bcrypt. */
    @Column(name = "totp_recovery_codes", columnDefinition = "text")
    private String totpRecoveryCodes;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    public Set<String> getPermissions() {
        Set<String> directModules = directPermissions.stream()
            .map(Permission::getModule)
            .filter(m -> m != null && !m.isBlank())
            .collect(Collectors.toSet());

        Set<String> perms = roles.stream()
            .flatMap(r -> r.getPermissions().stream())
            .filter(p -> p.getModule() == null || !directModules.contains(p.getModule()))
            .map(Permission::getCode)
            .collect(Collectors.toSet());

        directPermissions.forEach(p -> perms.add(p.getCode()));
        // V24/V26: tính năng công ty đang tắt → bỏ quyền thuộc tính năng đó
        return com.bosskin.core.CompanyFeatures.filter(perms, companyDisabledFeatures());
    }

    /** V26: tính năng đang tắt, do JwtAuthFilter nạp sẵn (user được nạp ngoài phiên JPA, company là proxy lazy). */
    @Transient
    private java.util.Set<String> disabledFeaturesLoaded;

    /** V32: múi giờ công ty, JwtAuthFilter nạp sẵn (công ty là LAZY, ngoài phiên Hibernate không đọc được). */
    @Transient
    private String companyTimezoneLoaded;

    public void setCompanyTimezoneLoaded(String tz) { this.companyTimezoneLoaded = tz; }

    /** Múi giờ của công ty người dùng; chưa nạp được → mặc định Việt Nam. */
    public String companyTimezoneId() {
        if (companyTimezoneLoaded != null) return companyTimezoneLoaded;
        try {
            return company != null ? company.getTimezone() : null;
        } catch (org.hibernate.LazyInitializationException e) {
            return null;
        }
    }

    public void setDisabledFeaturesLoaded(java.util.Set<String> disabled) {
        this.disabledFeaturesLoaded = disabled;
    }

    /** V26: tính năng (core/CompanyFeatures) của công ty đang tắt. */
    public boolean isFeatureDisabled(String feature) {
        return companyDisabledFeatures().contains(feature);
    }

    /** V26: tập tính năng công ty đang tắt (tên không có tiền tố get để khỏi thành thuộc tính JSON). */
    public java.util.Set<String> disabledFeatureSet() {
        return companyDisabledFeatures();
    }

    /** V24 (tương thích): gói cũ coi là tắt khi tính năng gốc của nó tắt. */
    public boolean isModuleDisabled(String module) {
        String base = com.bosskin.core.CompanyFeatures.baseOf(module);
        return base != null && isFeatureDisabled(base);
    }

    /** Tính năng đang tắt của công ty; chưa nạp sẵn và công ty chưa nạp được → coi như bật hết. */
    protected java.util.Set<String> companyDisabledFeatures() {
        if (disabledFeaturesLoaded != null) return disabledFeaturesLoaded;
        try {
            return company != null ? company.disabledFeatureSet() : java.util.Set.of();
        } catch (org.hibernate.LazyInitializationException e) {
            return java.util.Set.of();
        }
    }

    public boolean hasPermission(String permissionCode) {
        return getPermissions().contains(permissionCode);
    }

    public boolean can(String permissionCode) {
        if (permissionCode == null) return false;
        return hasPermission(permissionCode.trim().toUpperCase().replace('.', '_'));
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return getPermissions().stream()
            .map(SimpleGrantedAuthority::new)
            .collect(Collectors.toSet());
    }

    @Override public String getUsername()                { return email; }
    @Override public boolean isAccountNonExpired()       { return true; }
    @Override public boolean isAccountNonLocked()        { return true; }
    @Override public boolean isCredentialsNonExpired()   { return true; }
}
