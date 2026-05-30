package com.bosskin.repository;

import com.bosskin.entity.AttendanceRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface AttendanceRequestRepository extends JpaRepository<AttendanceRequest, Long> {

    @Query("""
        SELECT r FROM AttendanceRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH r.shiftAssignment sa
        LEFT JOIN FETCH sa.shift
        LEFT JOIN FETCH r.processedBy pb
        LEFT JOIN FETCH pb.employee pbe
        WHERE e.company.id = :companyId
          AND (:status IS NULL OR r.status = :status)
          AND (:type IS NULL OR r.requestType = :type)
        ORDER BY r.requestDate DESC, r.id DESC
        """)
    List<AttendanceRequest> findByCompanyId(
        @Param("companyId") Long companyId,
        @Param("status") AttendanceRequest.Status status,
        @Param("type") AttendanceRequest.Type type
    );

    @Query("""
        SELECT r FROM AttendanceRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH r.shiftAssignment sa
        LEFT JOIN FETCH sa.shift
        LEFT JOIN FETCH r.processedBy pb
        LEFT JOIN FETCH pb.employee pbe
        WHERE e.company.id = :companyId AND r.id = :id
        """)
    Optional<AttendanceRequest> findByIdAndCompanyId(
        @Param("id") Long id,
        @Param("companyId") Long companyId
    );

    @Query("""
        SELECT r FROM AttendanceRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH r.shiftAssignment sa
        LEFT JOIN FETCH sa.shift
        LEFT JOIN FETCH r.processedBy pb
        LEFT JOIN FETCH pb.employee pbe
        WHERE r.employee.id = :employeeId
        ORDER BY r.requestDate DESC, r.id DESC
        """)
    List<AttendanceRequest> findByEmployeeId(@Param("employeeId") Long employeeId);

    @Query("""
        SELECT r FROM AttendanceRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH r.shiftAssignment sa
        LEFT JOIN FETCH sa.shift
        LEFT JOIN FETCH r.processedBy pb
        LEFT JOIN FETCH pb.employee pbe
        WHERE r.employee.id = :employeeId
          AND r.requestDate BETWEEN :from AND :to
        ORDER BY r.requestDate DESC, r.id DESC
        """)
    List<AttendanceRequest> findByEmployeeAndDateRange(
        @Param("employeeId") Long employeeId,
        @Param("from") LocalDate from,
        @Param("to") LocalDate to
    );

    @Query("""
        SELECT r FROM AttendanceRequest r
        WHERE r.employee.id = :employeeId
          AND r.requestDate = :requestDate
          AND r.requestType = :requestType
          AND r.status = 'APPROVED'
          AND r.applied = true
          AND r.id <> :excludeId
          AND (
                :requestedOvertimeScope IS NULL
                OR r.requestedOvertimeScope = :requestedOvertimeScope
          )
          AND (
                :requestedOvertimePeriod IS NULL
                OR r.requestedOvertimePeriod = :requestedOvertimePeriod
          )
        """)
    List<AttendanceRequest> findAppliedConflicts(
        @Param("employeeId") Long employeeId,
        @Param("requestDate") LocalDate requestDate,
        @Param("requestType") AttendanceRequest.Type requestType,
        @Param("requestedOvertimeScope") AttendanceRequest.OvertimeScope requestedOvertimeScope,
        @Param("requestedOvertimePeriod") AttendanceRequest.OvertimePeriod requestedOvertimePeriod,
        @Param("excludeId") Long excludeId
    );

    @Query("""
        SELECT r FROM AttendanceRequest r
        WHERE r.employee.id = :employeeId
          AND r.requestDate = :requestDate
          AND r.requestType = :requestType
          AND r.status = 'APPROVED'
          AND r.applied = true
          AND r.id <> :excludeId
          AND (
            (:shiftAssignmentId IS NULL AND r.shiftAssignment IS NULL)
            OR (r.shiftAssignment.id = :shiftAssignmentId)
          )
        """)
    List<AttendanceRequest> findAppliedSameTypeSameDateExcluding(
        @Param("employeeId") Long employeeId,
        @Param("requestDate") LocalDate requestDate,
        @Param("requestType") AttendanceRequest.Type requestType,
        @Param("excludeId") Long excludeId,
        @Param("shiftAssignmentId") Long shiftAssignmentId
    );

    @Query("""
        SELECT r FROM AttendanceRequest r
        JOIN FETCH r.employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH r.shiftAssignment sa
        LEFT JOIN FETCH sa.shift
        LEFT JOIN FETCH r.processedBy pb
        LEFT JOIN FETCH pb.employee pbe
        WHERE e.company.id = :companyId
          AND r.requestDate = :requestDate
        ORDER BY e.fullName, r.id DESC
        """)
    List<AttendanceRequest> findByCompanyAndRequestDate(
        @Param("companyId") Long companyId,
        @Param("requestDate") LocalDate requestDate
    );

    long countByEmployee_Company_IdAndStatus(Long companyId, AttendanceRequest.Status status);

    List<AttendanceRequest> findByShiftAssignment_Id(Long shiftAssignmentId);
}
