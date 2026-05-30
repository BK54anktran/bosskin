package com.bosskin.repository;

import com.bosskin.entity.Department;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface DepartmentRepository extends JpaRepository<Department, Long> {

    List<Department> findByCompanyIdAndParentIsNullOrderByName(Long companyId);
    List<Department> findByCompanyIdOrderByLevelAscNameAsc(Long companyId);
    List<Department> findByParentIdIn(Collection<Long> parentIds);
    Optional<Department> findByIdAndCompanyId(Long id, Long companyId);
    boolean existsByCodeAndCompanyId(String code, Long companyId);
    boolean existsByCodeAndCompanyIdAndIdNot(String code, Long companyId, Long id);
    long countByParentIdAndCompanyId(Long parentId, Long companyId);
}
