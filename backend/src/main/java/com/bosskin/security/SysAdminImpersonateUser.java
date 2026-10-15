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

    /** V26: toàn quyền trừ quyền thuộc tính năng công ty đang tắt. */
    @Override
    protected Set<String> companyDisabledFeatures() {
        return overrideCompany != null ? overrideCompany.disabledFeatureSet() : Set.of();
    }

    @Override
    public Set<String> getPermissions() {
        return com.bosskin.core.CompanyFeatures.filter(allPermissions, companyDisabledFeatures());
    }

    @Override
    public boolean can(String permissionCode) {
        return permissionCode != null && hasPermission(permissionCode.trim().toUpperCase().replace('.', '_'));
    }

    @Override
    public boolean hasPermission(String permissionCode) {
        String feature = com.bosskin.core.CompanyFeatures.featureOfPermission(permissionCode);
        return feature == null || !companyDisabledFeatures().contains(feature);
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return getPermissions().stream()
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toSet());
    }
}
