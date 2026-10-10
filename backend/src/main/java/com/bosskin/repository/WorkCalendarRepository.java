package com.bosskin.repository;

import com.bosskin.entity.WorkCalendar;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WorkCalendarRepository extends JpaRepository<WorkCalendar, Long> {
    List<WorkCalendar> findByCompanyIdAndDeletedFalseOrderByIsDefaultDescNameAsc(Long companyId);
    Optional<WorkCalendar> findByCompanyIdAndIsDefaultTrueAndDeletedFalse(Long companyId);
    Optional<WorkCalendar> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);
}
