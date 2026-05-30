package com.bosskin.repository;

import com.bosskin.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    List<Role> findByCompanyId(Long companyId);
    Optional<Role> findByCompanyIdAndName(Long companyId, String name);
    boolean existsByCompanyIdAndName(Long companyId, String name);
    Optional<Role> findFirstByCompanyIdAndIsDefaultTrue(Long companyId);
}
