package com.bosskin.repository;

import com.bosskin.entity.Attendance;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE e.id = :employeeId AND a.date = :date
        ORDER BY a.id
        """)
    List<Attendance> findByEmployeeIdAndDate(
        @Param("employeeId") Long employeeId,
        @Param("date") LocalDate date
    );

    boolean existsByShiftAssignment_Id(Long shiftAssignmentId);

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE e.id = :employeeId AND a.date = :date
          AND (:shiftAssignmentId IS NULL AND a.shiftAssignment IS NULL
               OR a.shiftAssignment.id = :shiftAssignmentId)
        """)
    Optional<Attendance> findByEmployeeIdAndDateAndShift(
        @Param("employeeId") Long employeeId,
        @Param("date") LocalDate date,
        @Param("shiftAssignmentId") Long shiftAssignmentId
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE e.company.id = :companyId
          AND a.date = :date
        ORDER BY e.fullName, a.id
        """)
    List<Attendance> findByCompanyAndDate(
        @Param("companyId") Long companyId,
        @Param("date") LocalDate date
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        """)
    Page<Attendance> findByMonthWithFilters(
        @Param("year") int year,
        @Param("month") int month,
        @Param("employeeId") Long employeeId,
        @Param("departmentId") Long departmentId,
        Pageable pageable
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        """)
    Page<Attendance> findByMonthWithDeptScope(
        @Param("year") int year,
        @Param("month") int month,
        @Param("employeeId") Long employeeId,
        @Param("deptIds") Collection<Long> deptIds,
        Pageable pageable
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE a.employee.id = :employeeId
          AND a.date BETWEEN :from AND :to
        ORDER BY a.date, a.id
        """)
    List<Attendance> findByEmployeeAndDateRange(
        @Param("employeeId") Long employeeId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE a.employee.id = :employeeId
          AND a.date BETWEEN :from AND :to
          AND a.approved = true
        ORDER BY a.date, a.id
        """)
    List<Attendance> findApprovedByEmployeeAndDateRange(
        @Param("employeeId") Long employeeId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to
    );

    @Query("""
        SELECT a FROM Attendance a
        WHERE a.employee.id = :employeeId
          AND YEAR(a.date) = :year AND MONTH(a.date) = :month
        ORDER BY a.date, a.id
        """)
    List<Attendance> findByEmployeeAndMonth(
        @Param("employeeId") Long employeeId,
        @Param("year") int year,
        @Param("month") int month
    );

    @Query("""
        SELECT COUNT(a) FROM Attendance a
        WHERE a.employee.id = :employeeId
          AND YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND a.status = :status
        """)
    long countByStatusAndMonth(
        @Param("employeeId") Long employeeId,
        @Param("year") int year,
        @Param("month") int month,
        @Param("status") Attendance.Status status
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE a.date BETWEEN :from AND :to
          AND a.approved = true
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE a.date BETWEEN :from AND :to
          AND a.approved = true
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        """)
    Page<Attendance> findByPeriodWithFilters(
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("employeeId") Long employeeId,
        @Param("departmentId") Long departmentId,
        Pageable pageable
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE a.date BETWEEN :from AND :to
          AND a.approved = true
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE a.date BETWEEN :from AND :to
          AND a.approved = true
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        """)
    Page<Attendance> findByPeriodWithDeptScope(
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("employeeId") Long employeeId,
        @Param("deptIds") Collection<Long> deptIds,
        Pageable pageable
    );
}
