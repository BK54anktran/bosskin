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

    @Override
    public Set<String> getPermissions() {
        return allPermissions;
    }

    @Override
    public boolean can(String permissionCode) {
        return true;
    }

    @Override
    public boolean hasPermission(String permissionCode) {
        return true;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return allPermissions.stream()
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toSet());
    }
}
