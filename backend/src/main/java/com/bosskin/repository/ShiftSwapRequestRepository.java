package com.bosskin.repository;

import com.bosskin.entity.ShiftSwapRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ShiftSwapRequestRepository extends JpaRepository<ShiftSwapRequest, Long> {

    @Query("""
        SELECT r FROM ShiftSwapRequest r
        WHERE r.companyId = :companyId
          AND (:status IS NULL OR r.status = :status)
          AND (:employeeId IS NULL OR r.requester.id = :employeeId OR r.targetEmployee.id = :employeeId)
        ORDER BY r.createdAt DESC, r.id DESC
        """)
    List<ShiftSwapRequest> search(@Param("companyId") Long companyId,
                                  @Param("status") ShiftSwapRequest.Status status,
                                  @Param("employeeId") Long employeeId);

    @Query("""
        SELECT COUNT(r) FROM ShiftSwapRequest r
        WHERE r.status = com.bosskin.entity.ShiftSwapRequest.Status.PENDING
          AND (r.requesterAssignment.id = :assignmentId OR r.targetAssignment.id = :assignmentId)
        """)
    long countPendingForAssignment(@Param("assignmentId") Long assignmentId);

    /** Bước K: yêu cầu đổi ca đang chờ do nhân viên dưới quyền gửi. */
    @Query("""
        SELECT r FROM ShiftSwapRequest r
        JOIN FETCH r.requester e
        WHERE e.id IN :employeeIds
          AND r.status = com.bosskin.entity.ShiftSwapRequest.Status.PENDING
        ORDER BY r.createdAt
        """)
    List<ShiftSwapRequest> findPendingForEmployees(@Param("employeeIds") java.util.Collection<Long> employeeIds);
}
