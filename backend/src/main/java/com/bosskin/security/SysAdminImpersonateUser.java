package com.bosskin.security;

import com.bosskin.entity.Company;
import com.bosskin.entity.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.Collection;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Đại diện sysadmin đang impersonate một company.
 * Toàn quyền, không gắn với bất kỳ employee nào.
 */
public class SysAdminImpersonateUser extends User {

    private final Long overrideCompanyId;
    private final Set<String> allPermissions;
    private final Company overrideCompany;

    public SysAdminImpersonateUser(String email, Long companyId, Company company, Set<String> allPermissions) {
        this.overrideCompanyId = companyId;
        this.overrideCompany = company;
        this.allPermissions = allPermissions;
        this.setEmail(email);
        this.setEnabled(true);
    }

    @Override
    public Long getCompanyId() {
        return overrideCompanyId;
    }

    @Override
    public Company getCompany() {
        return overrideCompany;
    }

    /** V24: toàn quyền trừ quyền thuộc gói chức năng công ty đang tắt. */
    private Set<String> disabledModules() {
        return overrideCompany != null ? overrideCompany.disabledModuleSet() : Set.of();
    }

    @Override
    public boolean isModuleDisabled(String module) {
        return disabledModules().contains(module);
    }

    @Override
    public Set<String> getPermissions() {
        return com.bosskin.core.CompanyModules.filter(allPermissions, disabledModules());
    }

    @Override
    public boolean can(String permissionCode) {
        return permissionCode != null && hasPermission(permissionCode.trim().toUpperCase().replace('.', '_'));
    }

    @Override
    public boolean hasPermission(String permissionCode) {
        String module = com.bosskin.core.CompanyModules.moduleOf(permissionCode);
        return module == null || !disabledModules().contains(module);
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return getPermissions().stream()
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toSet());
    }
}
