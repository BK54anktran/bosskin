package com.bosskin.repository;

import com.bosskin.entity.AttendancePeriodLock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface AttendancePeriodLockRepository extends JpaRepository<AttendancePeriodLock, Long> {

    Optional<AttendancePeriodLock> findByCompanyIdAndYearAndMonth(Long companyId, int year, int month);

    List<AttendancePeriodLock> findByCompanyIdAndYearOrderByMonth(Long companyId, int year);

    /** Có kỳ đang khoá nào giao với khoảng [from, to] không. */
    @Query("""
        SELECT COUNT(l) > 0 FROM AttendancePeriodLock l
        WHERE l.companyId = :companyId AND l.locked = true
          AND l.periodFrom <= :to AND l.periodTo >= :from
        """)
    boolean existsLockedOverlapping(@Param("companyId") Long companyId,
                                    @Param("from") LocalDate from,
                                    @Param("to") LocalDate to);
}
