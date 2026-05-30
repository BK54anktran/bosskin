package com.bosskin.repository;

import com.bosskin.entity.LeaveType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface LeaveTypeRepository extends JpaRepository<LeaveType, Long> {
    List<LeaveType> findByCompanyIdAndDeletedFalseOrderByNameAsc(Long companyId);
    Optional<LeaveType> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);
    boolean existsByCompanyIdAndCodeIgnoreCase(Long companyId, String code);
    boolean existsByCompanyIdAndCodeIgnoreCaseAndIdNot(Long companyId, String code, Long id);
}
