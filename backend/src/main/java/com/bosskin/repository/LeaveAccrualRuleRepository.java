package com.bosskin.repository;

import com.bosskin.entity.LeaveAccrualRule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface LeaveAccrualRuleRepository extends JpaRepository<LeaveAccrualRule, Long> {
    List<LeaveAccrualRule> findByCompanyIdAndDeletedFalseOrderByCreatedAtDesc(Long companyId);
    Optional<LeaveAccrualRule> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);
}
