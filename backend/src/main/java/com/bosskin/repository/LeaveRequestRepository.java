package com.bosskin.repository;

import com.bosskin.entity.LeaveRequest;
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
}
