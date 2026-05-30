package com.bosskin.repository;

import com.bosskin.entity.Position;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PositionRepository extends JpaRepository<Position, Long> {
    List<Position> findByDepartmentId(Long departmentId);
    List<Position> findByDepartmentCompanyId(Long companyId);
    List<Position> findByDepartmentIdAndDepartmentCompanyId(Long departmentId, Long companyId);
    Optional<Position> findByIdAndDepartmentCompanyId(Long id, Long companyId);
    boolean existsByCodeAndDepartmentCompanyId(String code, Long companyId);
    boolean existsByCodeAndDepartmentCompanyIdAndIdNot(String code, Long companyId, Long id);
    long countByDepartmentIdAndDepartmentCompanyId(Long departmentId, Long companyId);
}
