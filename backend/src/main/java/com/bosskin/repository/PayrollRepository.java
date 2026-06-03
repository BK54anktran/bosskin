package com.bosskin.repository;

import com.bosskin.entity.Payroll;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface PayrollRepository extends JpaRepository<Payroll, Long> {

    Optional<Payroll> findByEmployeeIdAndYearAndMonth(Long employeeId, int year, int month);

    @Query("""
        SELECT DISTINCT p FROM Payroll p
        JOIN FETCH p.employee e
        LEFT JOIN FETCH e.company c
        LEFT JOIN FETCH e.department d
        LEFT JOIN FETCH e.position pos
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE p.year = :year AND p.month = :month
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
          AND (:status IS NULL OR p.status = :status)
        """)
    Page<Payroll> findByMonthWithFilters(
        @Param("year") int year,
        @Param("month") int month,
        @Param("departmentId") Long departmentId,
        @Param("status") Payroll.Status status,
        Pageable pageable
    );

    @Query("""
        SELECT DISTINCT p FROM Payroll p
        JOIN FETCH p.employee e
        LEFT JOIN FETCH e.company c
        LEFT JOIN FETCH e.department d
        LEFT JOIN FETCH e.position pos
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE p.year = :year AND p.month = :month
          AND e.department.id IN :deptIds
          AND (:status IS NULL OR p.status = :status)
        """)
    Page<Payroll> findByMonthWithDeptScope(
        @Param("year") int year,
        @Param("month") int month,
        @Param("deptIds") Collection<Long> deptIds,
        @Param("status") Payroll.Status status,
        Pageable pageable
    );

    @Query("""
        SELECT p FROM Payroll p
        JOIN FETCH p.employee e
        LEFT JOIN FETCH e.department d
        LEFT JOIN FETCH e.position pos
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE p.id IN :ids
          AND e.company.id = :companyId
        ORDER BY e.employeeCode ASC, e.fullName ASC
        """)
    List<Payroll> findPayslipsByIds(
        @Param("ids") Collection<Long> ids,
        @Param("companyId") Long companyId
    );

    @Query("""
        SELECT p FROM Payroll p
        JOIN FETCH p.employee e
        LEFT JOIN FETCH e.department d
        LEFT JOIN FETCH e.position pos
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE p.year = :year AND p.month = :month
          AND e.company.id = :companyId
        ORDER BY e.employeeCode ASC, e.fullName ASC
        """)
    List<Payroll> findExportByMonth(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("month") int month
    );

    @Query("""
        SELECT p FROM Payroll p
        JOIN FETCH p.employee e
        LEFT JOIN FETCH e.department d
        LEFT JOIN FETCH e.position pos
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE p.year = :year AND p.month = :month
          AND e.company.id = :companyId
          AND d.id IN :deptIds
        ORDER BY d.name ASC, e.employeeCode ASC, e.fullName ASC
        """)
    List<Payroll> findExportByMonthAndDeptScope(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("month") int month,
        @Param("deptIds") Collection<Long> deptIds
    );

    @Query("SELECT SUM(p.netSalary) FROM Payroll p WHERE p.year = :year AND p.month = :month AND p.status = 'PAID'")
    BigDecimal sumNetSalaryByMonth(@Param("year") int year, @Param("month") int month);

    @Query("""
        SELECT DISTINCT p FROM Payroll p
        JOIN FETCH p.employee e
        LEFT JOIN FETCH e.company c
        LEFT JOIN FETCH e.department d
        LEFT JOIN FETCH e.position pos
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE e.id = :employeeId
          AND (:year IS NULL OR p.year = :year)
        ORDER BY p.year DESC, p.month DESC
        """)
    java.util.List<Payroll> findSelfPayrolls(
        @Param("employeeId") Long employeeId,
        @Param("year") Integer year
    );
}
