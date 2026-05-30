package com.bosskin.repository;

import com.bosskin.entity.SalaryGrade;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface SalaryGradeRepository extends JpaRepository<SalaryGrade, Long> {

    List<SalaryGrade> findByDepartmentId(Long departmentId);

    // Lấy grades của nhiều phòng ban (subtree) + grades toàn công ty (dept IS NULL)
    @Query(value = """
        SELECT g.* FROM salary_grades g
        WHERE g.department_id IN (:deptIds) OR g.department_id IS NULL
        """, nativeQuery = true)
    List<SalaryGrade> findByDepartmentIdInOrDepartmentIsNull(@org.springframework.data.repository.query.Param("deptIds") java.util.Collection<Long> deptIds);

    // null dept = toàn công ty (department IS NULL)
    List<SalaryGrade> findByDepartmentIsNull();

    // Tất cả grades của 1 company (qua department hoặc null dept)
    @Query(value = """
        SELECT g.* FROM salary_grades g
        LEFT JOIN departments d ON g.department_id = d.id
        WHERE g.department_id IS NULL OR d.company_id = :companyId
        """, nativeQuery = true)
    List<SalaryGrade> findByCompanyId(Long companyId);

    Optional<SalaryGrade> findByDepartmentIdAndCode(Long departmentId, String code);

    Optional<SalaryGrade> findByDepartmentIsNullAndCode(String code);

    boolean existsByDepartmentIdAndCodeAndIdNot(Long departmentId, String code, Long excludeId);

    boolean existsByDepartmentIsNullAndCodeAndIdNot(String code, Long excludeId);
}
