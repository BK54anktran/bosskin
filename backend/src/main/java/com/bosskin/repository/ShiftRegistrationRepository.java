package com.bosskin.repository;

import com.bosskin.entity.ShiftRegistration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface ShiftRegistrationRepository extends JpaRepository<ShiftRegistration, Long> {

    @Query("SELECT r FROM ShiftRegistration r JOIN FETCH r.employee e WHERE r.roundId = :roundId ORDER BY r.workDate, r.startTime")
    List<ShiftRegistration> findByRoundFetch(@Param("roundId") Long roundId);

    List<ShiftRegistration> findByRoundIdAndEmployeeIdOrderByWorkDateAscStartTimeAsc(Long roundId, Long employeeId);

    @Query("SELECT r FROM ShiftRegistration r JOIN FETCH r.employee e WHERE r.roundId = :roundId AND r.workDate = :date")
    List<ShiftRegistration> findByRoundAndDateFetch(@Param("roundId") Long roundId, @Param("date") LocalDate date);

    @Query("SELECT r.roundId, COUNT(DISTINCT r.employee.id) FROM ShiftRegistration r WHERE r.roundId IN :roundIds GROUP BY r.roundId")
    List<Object[]> countEmployeesByRound(@Param("roundIds") List<Long> roundIds);
}
