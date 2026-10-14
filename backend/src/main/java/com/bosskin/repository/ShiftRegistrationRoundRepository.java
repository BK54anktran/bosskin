package com.bosskin.repository;

import com.bosskin.entity.ShiftRegistrationRound;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface ShiftRegistrationRoundRepository extends JpaRepository<ShiftRegistrationRound, Long> {
    List<ShiftRegistrationRound> findByCompanyIdOrderByFromDateDescIdDesc(Long companyId);
    Optional<ShiftRegistrationRound> findByIdAndCompanyId(Long id, Long companyId);
    List<ShiftRegistrationRound> findByStatusAndClosesAtLessThanEqual(ShiftRegistrationRound.Status status, LocalDateTime now);
}
