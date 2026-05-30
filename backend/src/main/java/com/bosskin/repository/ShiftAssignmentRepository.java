package com.bosskin.repository;

import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.WorkShift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface ShiftAssignmentRepository extends JpaRepository<ShiftAssignment, Long> {

    List<ShiftAssignment> findByEmployeeIdAndWorkDate(Long employeeId, LocalDate workDate);

    @Query(value = """
        SELECT *
        FROM shift_assignments
        WHERE employee_id = :employeeId
          AND work_date = :workDate
        ORDER BY id DESC
        """, nativeQuery = true)
    List<ShiftAssignment> findAllByEmployeeIdAndWorkDateIncludingDeleted(
        @org.springframework.data.repository.query.Param("employeeId") Long employeeId,
        @org.springframework.data.repository.query.Param("workDate") LocalDate workDate
    );

    @Modifying
    @Query(value = """
        UPDATE shift_assignments
        SET deleted = TRUE
        WHERE id = :id
        """, nativeQuery = true)
    int softDeleteById(@org.springframework.data.repository.query.Param("id") Long id);

    @Modifying
    @Query(value = """
        UPDATE shift_assignments
        SET deleted = TRUE
        WHERE employee_id = :employeeId
          AND work_date = :workDate
          AND deleted = FALSE
        """, nativeQuery = true)
    int softDeleteByEmployeeIdAndWorkDate(
        @org.springframework.data.repository.query.Param("employeeId") Long employeeId,
        @org.springframework.data.repository.query.Param("workDate") LocalDate workDate
    );

    @Query("""
        SELECT a FROM ShiftAssignment a
        LEFT JOIN FETCH a.shift
        WHERE a.employee.id = :employeeId
          AND a.workDate = :workDate
        ORDER BY a.id
        """)
    List<ShiftAssignment> findByEmployeeIdAndWorkDateWithShift(
        @org.springframework.data.repository.query.Param("employeeId") Long employeeId,
        @org.springframework.data.repository.query.Param("workDate") LocalDate workDate
    );

    @Query("""
        SELECT a FROM ShiftAssignment a
        JOIN a.employee e
        WHERE e.company.id = :companyId
          AND a.workDate BETWEEN :from AND :to
        ORDER BY a.workDate, e.fullName
        """)
    List<ShiftAssignment> findByCompanyAndDateRange(Long companyId, LocalDate from, LocalDate to);

    @Query("""
        SELECT a FROM ShiftAssignment a
        LEFT JOIN FETCH a.shift
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE e.company.id = :companyId
          AND a.workDate = :date
        ORDER BY e.fullName, a.id
        """)
    List<ShiftAssignment> findByCompanyAndDate(
        @org.springframework.data.repository.query.Param("companyId") Long companyId,
        @org.springframework.data.repository.query.Param("date") LocalDate date
    );

    @Query("""
        SELECT a FROM ShiftAssignment a
        LEFT JOIN FETCH a.shift
        WHERE a.employee.id = :employeeId
          AND a.workDate BETWEEN :from AND :to
        ORDER BY a.workDate
        """)
    List<ShiftAssignment> findByEmployeeAndDateRange(
        @org.springframework.data.repository.query.Param("employeeId") Long employeeId,
        @org.springframework.data.repository.query.Param("from") LocalDate from,
        @org.springframework.data.repository.query.Param("to") LocalDate to
    );

    @Query("""
        SELECT DISTINCT a.shift
        FROM ShiftAssignment a
        JOIN a.employee e
        WHERE e.id = :employeeId
          AND e.company.id = :companyId
          AND a.shift IS NOT NULL
          AND a.shift.active = true
        ORDER BY a.shift.name
        """)
    List<WorkShift> findDistinctActiveShiftsByEmployeeAndCompany(
        @org.springframework.data.repository.query.Param("employeeId") Long employeeId,
        @org.springframework.data.repository.query.Param("companyId") Long companyId
    );

}
