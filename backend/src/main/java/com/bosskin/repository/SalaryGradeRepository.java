package com.bosskin.repository;

import com.bosskin.entity.SalaryGrade;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface SalaryGradeRepository extends JpaRepository<SalaryGrade, Long> {

    List<SalaryGrade> findByDepartmentId(Long departmentId);

    // Grades thuộc subtree phòng ban + grades toàn công ty (dept IS NULL) của cùng company
    @Query(value = """
        SELECT g.* FROM salary_grades g
        WHERE g.deleted = 0
          AND g.company_id = :companyId
          AND (g.department_id IN (:deptIds) OR g.department_id IS NULL)
        """, nativeQuery = true)
    List<SalaryGrade> findByDepartmentIdInOrDepartmentIsNull(
        @Param("deptIds") Collection<Long> deptIds,
        @Param("companyId") Long companyId
    );

    // Tất cả grades của 1 company
    @Query(value = """
        SELECT g.* FROM salary_grades g
        WHERE g.deleted = 0 AND g.company_id = :companyId
        """, nativeQuery = true)
    List<SalaryGrade> findByCompanyId(@Param("companyId") Long companyId);

    Optional<SalaryGrade> findByDepartmentIdAndCode(Long departmentId, String code);

    Optional<SalaryGrade> findByCompanyIdAndDepartmentIsNullAndCode(Long companyId, String code);

    boolean existsByDepartmentIdAndCodeAndIdNot(Long departmentId, String code, Long excludeId);

    boolean existsByCompanyIdAndDepartmentIsNullAndCodeAndIdNot(Long companyId, String code, Long excludeId);
}
