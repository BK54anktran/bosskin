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
          AND e.company.id = :companyId
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
          AND (:status IS NULL OR p.status = :status)
        """)
    Page<Payroll> findByMonthWithFilters(
        @Param("year") int year,
        @Param("month") int month,
        @Param("companyId") Long companyId,
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
          AND e.company.id = :companyId
          AND e.department.id IN :deptIds
          AND (:status IS NULL OR p.status = :status)
        """)
    Page<Payroll> findByMonthWithDeptScope(
        @Param("year") int year,
        @Param("month") int month,
        @Param("companyId") Long companyId,
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

    @Query("SELECT SUM(p.netSalary) FROM Payroll p JOIN p.employee e WHERE p.year = :year AND p.month = :month AND p.status = 'PAID' AND e.company.id = :companyId")
    BigDecimal sumNetSalaryByMonth(@Param("companyId") Long companyId, @Param("year") int year, @Param("month") int month);

    @Query("""
        SELECT SUM(p.netSalary) FROM Payroll p
        JOIN p.employee e
        WHERE p.year = :year AND p.month = :month
          AND e.company.id = :companyId
        """)
    BigDecimal sumNetSalaryByCompanyAndMonth(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("month") int month
    );

    @Query("""
        SELECT COUNT(p) FROM Payroll p
        JOIN p.employee e
        WHERE p.year = :year AND p.month = :month
          AND e.company.id = :companyId
        """)
    long countByCompanyAndMonth(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("month") int month
    );

    @Query("""
        SELECT p.status, COUNT(p) FROM Payroll p
        JOIN p.employee e
        WHERE p.year = :year AND p.month = :month
          AND e.company.id = :companyId
        GROUP BY p.status
        ORDER BY COUNT(p) DESC
        """)
    List<Object[]> findStatusSummaryByCompanyAndMonth(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("month") int month
    );

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

    // Lương/ngày ước tính: SUM(netSalary / presentDays) theo từng tháng — dùng để tính chi phí ngày
    @Query("""
        SELECT p.year, p.month, SUM(p.netSalary), SUM(p.presentDays)
        FROM Payroll p
        JOIN p.employee e
        WHERE e.company.id = :companyId
          AND ((p.year = :fromYear AND p.month >= :fromMonth)
            OR (p.year = :toYear   AND p.month <= :toMonth)
            OR  (p.year > :fromYear AND p.year < :toYear))
        GROUP BY p.year, p.month
        ORDER BY p.year, p.month
        """)
    List<Object[]> findMonthlyPayrollSummaryInRange(
        @Param("companyId") Long companyId,
        @Param("fromYear") int fromYear,
        @Param("fromMonth") int fromMonth,
        @Param("toYear") int toYear,
        @Param("toMonth") int toMonth
    );

    // Tổng lương theo từng tháng trong năm (cho biểu đồ trend)
    @Query("""
        SELECT p.month, SUM(p.netSalary), COUNT(p)
        FROM Payroll p
        JOIN p.employee e
        WHERE e.company.id = :companyId AND p.year = :year
        GROUP BY p.month
        ORDER BY p.month
        """)
    List<Object[]> findMonthlySalaryTrend(
        @Param("companyId") Long companyId,
        @Param("year") int year
    );

    @Query("""
        SELECT p.month, SUM(p.netSalary), COUNT(p)
        FROM Payroll p
        JOIN p.employee e
        WHERE e.company.id = :companyId AND p.year = :year
          AND e.department.id = :departmentId
        GROUP BY p.month
        ORDER BY p.month
        """)
    List<Object[]> findMonthlySalaryTrendByDept(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("departmentId") Long departmentId
    );
}
