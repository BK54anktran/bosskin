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

    @Query("SELECT a FROM Attendance a JOIN a.employee e WHERE a.id = :id AND e.company.id = :companyId AND a.deleted = false")
    java.util.Optional<Attendance> findByIdAndCompanyId(
        @org.springframework.data.repository.query.Param("id") Long id,
        @org.springframework.data.repository.query.Param("companyId") Long companyId
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE e.id = :employeeId AND a.date = :date AND a.deleted = false
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
        WHERE e.id = :employeeId AND a.date = :date AND a.deleted = false
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
          AND a.date = :date AND a.deleted = false
        ORDER BY e.fullName, a.id
        """)
    List<Attendance> findByCompanyAndDate(
        @Param("companyId") Long companyId,
        @Param("date") LocalDate date
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE e.company.id = :companyId
          AND a.date = :date AND a.deleted = false
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        ORDER BY e.fullName, a.id
        """)
    List<Attendance> findByCompanyAndDateAndDept(
        @Param("companyId") Long companyId,
        @Param("date") LocalDate date,
        @Param("departmentId") Long departmentId
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND e.company.id = :companyId
          AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND e.company.id = :companyId
          AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        """)
    Page<Attendance> findByMonthWithFilters(
        @Param("year") int year,
        @Param("month") int month,
        @Param("companyId") Long companyId,
        @Param("employeeId") Long employeeId,
        @Param("departmentId") Long departmentId,
        Pageable pageable
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND e.company.id = :companyId
          AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE YEAR(a.date) = :year AND MONTH(a.date) = :month
          AND e.company.id = :companyId
          AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        """)
    Page<Attendance> findByMonthWithDeptScope(
        @Param("year") int year,
        @Param("month") int month,
        @Param("companyId") Long companyId,
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
          AND a.deleted = false
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
          AND a.approved = true AND a.deleted = false
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
          AND a.deleted = false
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
          AND a.status = :status AND a.deleted = false
        """)
    long countByStatusAndMonth(
        @Param("employeeId") Long employeeId,
        @Param("year") int year,
        @Param("month") int month,
        @Param("status") Attendance.Status status
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE e.company.id = :companyId
          AND a.date BETWEEN :from AND :to
          AND a.deleted = false
        ORDER BY e.fullName, a.date
        """)
    List<Attendance> findByCompanyAndDateRange(
        @Param("companyId") Long companyId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to
    );

    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH e.salaryGrade sg
        WHERE e.company.id = :companyId
          AND a.date BETWEEN :from AND :to
          AND a.deleted = false
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        ORDER BY e.fullName, a.date
        """)
    List<Attendance> findByCompanyAndDateRangeAndDept(
        @Param("companyId") Long companyId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("departmentId") Long departmentId
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE a.date BETWEEN :from AND :to
          AND e.company.id = :companyId
          AND a.approved = true AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE a.date BETWEEN :from AND :to
          AND e.company.id = :companyId
          AND a.approved = true AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:departmentId IS NULL OR e.department.id = :departmentId)
        """)
    Page<Attendance> findByPeriodWithFilters(
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("companyId") Long companyId,
        @Param("employeeId") Long employeeId,
        @Param("departmentId") Long departmentId,
        Pageable pageable
    );

    @Query(value = """
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department
        WHERE a.date BETWEEN :from AND :to
          AND e.company.id = :companyId
          AND a.approved = true AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        ORDER BY a.date DESC
        """,
        countQuery = """
        SELECT COUNT(a) FROM Attendance a
        JOIN a.employee e
        WHERE a.date BETWEEN :from AND :to
          AND e.company.id = :companyId
          AND a.approved = true AND a.deleted = false
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND e.department.id IN :deptIds
        """)
    Page<Attendance> findByPeriodWithDeptScope(
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("companyId") Long companyId,
        @Param("employeeId") Long employeeId,
        @Param("deptIds") Collection<Long> deptIds,
        Pageable pageable
    );

    // Top nhân viên đi muộn — trả về [employeeId, employeeCode, fullName, deptName, lateCount]
    @Query("""
        SELECT e.id, e.employeeCode, e.fullName,
               COALESCE(d.name, ''),
               COUNT(a) as lateCount
        FROM Attendance a
        JOIN a.employee e
        LEFT JOIN e.department d
        WHERE e.company.id = :companyId
          AND a.date BETWEEN :from AND :to
          AND a.deleted = false
          AND a.approved = true
          AND a.status = com.bosskin.entity.Attendance.Status.LATE
          AND (:departmentId IS NULL OR d.id = :departmentId)
        GROUP BY e.id, e.employeeCode, e.fullName, d.name
        ORDER BY lateCount DESC
        """)
    List<Object[]> findTopLateEmployees(
        @Param("companyId") Long companyId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("departmentId") Long departmentId,
        Pageable pageable
    );

    // Nhân viên đã check-in hôm nay nhưng chưa check-out (risk: missing checkout)
    @Query("""
        SELECT a FROM Attendance a
        JOIN FETCH a.employee e
        JOIN FETCH e.department d
        WHERE e.company.id = :companyId
          AND a.date = :date
          AND a.checkIn IS NOT NULL
          AND a.checkOut IS NULL
          AND a.overrideCheckOutAt IS NULL
          AND a.deleted = false
          AND (:deptId IS NULL OR d.id = :deptId)
        ORDER BY a.checkIn
        """)
    List<Attendance> findMissingCheckout(@Param("companyId") Long companyId,
                                          @Param("date") LocalDate date,
                                          @Param("deptId") Long deptId);

    // Thống kê chấm công theo ngày — [date, presentCount, lateCount, absentCount, totalActualHours]
    @Query("""
        SELECT a.date,
               SUM(CASE WHEN a.status = com.bosskin.entity.Attendance.Status.PRESENT THEN 1 ELSE 0 END),
               SUM(CASE WHEN a.status = com.bosskin.entity.Attendance.Status.LATE    THEN 1 ELSE 0 END),
               SUM(CASE WHEN a.status = com.bosskin.entity.Attendance.Status.ABSENT  THEN 1 ELSE 0 END),
               COALESCE(SUM(a.snapActualHours), 0)
        FROM Attendance a
        JOIN a.employee e
        LEFT JOIN e.department d
        WHERE e.company.id = :companyId
          AND a.date BETWEEN :from AND :to
          AND a.deleted = false
          AND (:departmentId IS NULL OR d.id = :departmentId)
        GROUP BY a.date
        ORDER BY a.date
        """)
    List<Object[]> findDailyAttendanceSummary(
        @Param("companyId") Long companyId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to,
        @Param("departmentId") Long departmentId
    );
}
