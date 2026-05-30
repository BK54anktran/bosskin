package com.bosskin.repository;

import com.bosskin.entity.WorkShift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface WorkShiftRepository extends JpaRepository<WorkShift, Long> {

    List<WorkShift> findByCompanyIdAndActiveTrue(Long companyId);

    Optional<WorkShift> findByIdAndCompanyIdAndActiveTrue(Long id, Long companyId);

    boolean existsByCompanyIdAndCodeAndActiveTrue(Long companyId, String code);

    boolean existsByCompanyIdAndCodeAndActiveTrueAndIdNot(Long companyId, String code, Long id);

    @Query("SELECT s FROM WorkShift s JOIN s.departments d WHERE d.id = :deptId AND s.active = true")
    List<WorkShift> findByDepartmentId(Long deptId);
}
