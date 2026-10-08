package com.bosskin.repository;

import com.bosskin.entity.LeaveGrant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface LeaveGrantRepository extends JpaRepository<LeaveGrant, Long> {
    @Query("""
        SELECT g FROM LeaveGrant g
        JOIN FETCH g.employee e
        JOIN FETCH e.department d
        LEFT JOIN FETCH g.leaveType t
        WHERE g.company.id = :companyId
          AND (:employeeId IS NULL OR e.id = :employeeId)
          AND (:leaveTypeId IS NULL OR t.id = :leaveTypeId)
        ORDER BY g.grantedAt DESC, g.id DESC
        """)
    List<LeaveGrant> findForCompany(
        @Param("companyId") Long companyId,
        @Param("employeeId") Long employeeId,
        @Param("leaveTypeId") Long leaveTypeId
    );

    @Query("""
        SELECT g FROM LeaveGrant g
        WHERE g.employee.id = :employeeId
          AND (:leaveTypeId IS NULL OR g.leaveType.id = :leaveTypeId)
          AND (g.grantDays > g.usedDays OR g.grantHours > g.usedHours)
          AND (g.validFrom IS NULL OR g.validFrom <= :date)
          AND (g.validTo IS NULL OR g.validTo >= :date)
        ORDER BY CASE WHEN g.validTo IS NOT NULL AND g.validTo < CURRENT_DATE THEN 1 ELSE 0 END ASC,
                 CASE WHEN (COALESCE(g.grantDays, 0) - COALESCE(g.usedDays, 0) + COALESCE(g.grantHours, 0) - COALESCE(g.usedHours, 0)) <= 0 THEN 1 ELSE 0 END ASC,
                 CASE WHEN g.validTo IS NULL THEN 1 ELSE 0 END ASC,
                 g.validTo ASC,
                 g.validFrom ASC,
                 (COALESCE(g.grantDays, 0) - COALESCE(g.usedDays, 0) + COALESCE(g.grantHours, 0) - COALESCE(g.usedHours, 0)) ASC,
                 (COALESCE(g.usedDays, 0) + COALESCE(g.usedHours, 0)) ASC
        """)
    List<LeaveGrant> findUsableGrants(
        @Param("employeeId") Long employeeId,
        @Param("leaveTypeId") Long leaveTypeId,
        @Param("date") LocalDate date
    );

    /**
     * Quỹ dùng được cho một loại phép: quỹ riêng của loại đó trước, rồi quỹ chung (không gắn loại).
     * Thứ tự trong mỗi nhóm như {@link #findUsableGrants}.
     */
    @Query("""
        SELECT g FROM LeaveGrant g
        WHERE g.employee.id = :employeeId
          AND (g.leaveType IS NULL OR g.leaveType.id = :leaveTypeId)
          AND (g.grantDays > g.usedDays OR g.grantHours > g.usedHours)
          AND (g.validFrom IS NULL OR g.validFrom <= :date)
          AND (g.validTo IS NULL OR g.validTo >= :date)
        ORDER BY CASE WHEN g.leaveType IS NULL THEN 1 ELSE 0 END ASC,
                 CASE WHEN g.validTo IS NULL THEN 1 ELSE 0 END ASC,
                 g.validTo ASC,
                 g.validFrom ASC,
                 g.id ASC
        """)
    List<LeaveGrant> findUsableGrantsForType(
        @Param("employeeId") Long employeeId,
        @Param("leaveTypeId") Long leaveTypeId,
        @Param("date") LocalDate date
    );

    @Query("""
        SELECT g FROM LeaveGrant g
        WHERE g.employee.id = :employeeId
          AND (g.usedDays > 0 OR g.usedHours > 0)
          AND (g.validFrom IS NULL OR g.validFrom <= :date)
          AND (g.validTo IS NULL OR g.validTo >= :date)
        ORDER BY g.grantedAt DESC, g.id DESC
        """)
    List<LeaveGrant> findUsableGrantsForRefund(
        @Param("employeeId") Long employeeId,
        @Param("date") LocalDate date
    );

    /**
     * Kiểm tra đã tồn tại grant AUTO cho rule+employee trong kỳ chưa.
     * MONTHLY: cùng tháng/năm của grantedAt
     * YEARLY:  cùng năm của grantedAt
     */
    @Query("""
        SELECT COUNT(g) > 0 FROM LeaveGrant g
        WHERE g.accrualRule.id = :ruleId
          AND g.employee.id = :employeeId
          AND g.source = com.bosskin.entity.LeaveGrant.Source.AUTO
          AND (:frequency = 'MONTHLY'
               AND YEAR(g.grantedAt) = :year AND MONTH(g.grantedAt) = :month
               OR :frequency = 'YEARLY'
               AND YEAR(g.grantedAt) = :year)
        """)
    boolean existsAccrualGrantForPeriod(
        @Param("ruleId") Long ruleId,
        @Param("employeeId") Long employeeId,
        @Param("frequency") String frequency,
        @Param("year") int year,
        @Param("month") int month
    );
}
