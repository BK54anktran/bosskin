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
public class User extends BaseEntity implements UserDetails {

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
        return perms;
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
