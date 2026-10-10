package com.bosskin.repository;

import com.bosskin.entity.LeaveRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, Long> {

    @Query("""
        SELECT r FROM LeaveRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department d
        JOIN FETCH r.leaveType t
        LEFT JOIN FETCH r.processedBy p
        LEFT JOIN FETCH p.employee pe
        WHERE r.company.id = :companyId
          AND (:status IS NULL OR r.status = :status)
        ORDER BY r.createdAt DESC, r.id DESC
        """)
    List<LeaveRequest> findByCompanyAndStatus(
        @Param("companyId") Long companyId,
        @Param("status") LeaveRequest.Status status
    );

    List<LeaveRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    /**
     * Danh sách đơn (chỉ đơn cha / đơn lẻ) có lọc + phân trang ở DB (F9).
     * anyDept = true → không lọc phòng ban; ngược lại chỉ phòng ban trong deptIds.
     * q đã ở dạng '%từ khoá%' chữ thường (collation utf8mb4_unicode_ci bỏ qua dấu).
     */
    @Query(value = """
        SELECT r FROM LeaveRequest r
        JOIN r.employee e
        LEFT JOIN e.department d
        JOIN r.leaveType t
        WHERE r.company.id = :companyId
          AND r.parent IS NULL
          AND (:status IS NULL OR r.status = :status)
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:anyDept = TRUE OR d.id IN :deptIds)
          AND (:q IS NULL OR LOWER(e.fullName) LIKE :q OR LOWER(e.employeeCode) LIKE :q
               OR LOWER(t.name) LIKE :q OR LOWER(d.name) LIKE :q)
        ORDER BY r.createdAt DESC, r.id DESC
        """,
        countQuery = """
        SELECT COUNT(r) FROM LeaveRequest r
        JOIN r.employee e
        LEFT JOIN e.department d
        JOIN r.leaveType t
        WHERE r.company.id = :companyId
          AND r.parent IS NULL
          AND (:status IS NULL OR r.status = :status)
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:anyDept = TRUE OR d.id IN :deptIds)
          AND (:q IS NULL OR LOWER(e.fullName) LIKE :q OR LOWER(e.employeeCode) LIKE :q
               OR LOWER(t.name) LIKE :q OR LOWER(d.name) LIKE :q)
        """)
    Page<LeaveRequest> searchPage(
        @Param("companyId") Long companyId,
        @Param("status") LeaveRequest.Status status,
        @Param("employeeId") Long employeeId,
        @Param("anyDept") boolean anyDept,
        @Param("deptIds") java.util.Collection<Long> deptIds,
        @Param("q") String q,
        Pageable pageable
    );

    @Query("""
        SELECT r FROM LeaveRequest r
        JOIN FETCH r.leaveType t
        WHERE r.employee.id = :employeeId
          AND r.status = com.bosskin.entity.LeaveRequest.Status.APPROVED
          AND r.fromDate <= :to
          AND r.toDate >= :from
          AND (r.parent IS NOT NULL OR r.children IS EMPTY)
        ORDER BY r.fromDate
        """)
    List<LeaveRequest> findApprovedByEmployeeAndDateRange(
        @Param("employeeId") Long employeeId,
        @Param("from") java.time.LocalDate from,
        @Param("to") java.time.LocalDate to
    );

    @Query("""
        SELECT r FROM LeaveRequest r
        JOIN FETCH r.leaveType t
        JOIN FETCH r.employee e
        WHERE r.company.id = :companyId
          AND r.status = com.bosskin.entity.LeaveRequest.Status.APPROVED
          AND r.fromDate <= :date
          AND r.toDate >= :date
          AND (r.parent IS NOT NULL OR r.children IS EMPTY)
        """)
    List<LeaveRequest> findApprovedByCompanyAndDate(
        @Param("companyId") Long companyId,
        @Param("date") java.time.LocalDate date
    );

    @Query("""
        SELECT r FROM LeaveRequest r
        JOIN FETCH r.leaveType t
        JOIN FETCH r.employee e
        JOIN FETCH e.department d
        WHERE r.company.id = :companyId
          AND r.status = com.bosskin.entity.LeaveRequest.Status.APPROVED
          AND r.fromDate <= :date
          AND r.toDate >= :date
          AND (r.parent IS NOT NULL OR r.children IS EMPTY)
          AND (:departmentId IS NULL OR d.id = :departmentId)
        """)
    List<LeaveRequest> findApprovedByCompanyAndDateAndDept(
        @Param("companyId") Long companyId,
        @Param("date") java.time.LocalDate date,
        @Param("departmentId") Long departmentId
    );

    @Query("""
        SELECT r FROM LeaveRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department d
        JOIN FETCH r.leaveType t
        LEFT JOIN FETCH r.processedBy p
        LEFT JOIN FETCH p.employee pe
        WHERE r.id = :id
          AND r.company.id = :companyId
        """)
    Optional<LeaveRequest> findByIdAndCompanyId(
        @Param("id") Long id,
        @Param("companyId") Long companyId
    );

    // Tổng hợp ngày phép đã dùng theo tháng trong năm (cho báo cáo tổng quan năm)
    @Query("""
        SELECT MONTH(lr.fromDate), SUM(lr.requestedAmount), COUNT(lr)
        FROM LeaveRequest lr
        WHERE lr.company.id = :companyId
          AND YEAR(lr.fromDate) = :year
          AND lr.status = :status
          AND (:deptId IS NULL OR lr.employee.department.id = :deptId)
        GROUP BY MONTH(lr.fromDate) ORDER BY MONTH(lr.fromDate)
        """)
    List<Object[]> findMonthlyLeaveUsageByYear(
        @Param("companyId") Long companyId,
        @Param("year") int year,
        @Param("deptId") Long deptId,
        @Param("status") LeaveRequest.Status status
    );

    /** Bước K: đơn đang chờ của các nhân viên dưới quyền (chỉ đơn gốc). */
    @Query("""
        SELECT r FROM LeaveRequest r
        JOIN FETCH r.employee e
        JOIN FETCH r.leaveType t
        WHERE e.id IN :employeeIds AND r.parent IS NULL
          AND r.status = com.bosskin.entity.LeaveRequest.Status.PENDING
        ORDER BY r.createdAt
        """)
    List<LeaveRequest> findPendingForEmployees(@Param("employeeIds") java.util.Collection<Long> employeeIds);
}
