package com.bosskin.repository;

import com.bosskin.entity.LeaveType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface LeaveTypeRepository extends JpaRepository<LeaveType, Long> {
    List<LeaveType> findByCompanyIdAndDeletedFalseOrderByNameAsc(Long companyId);
    Optional<LeaveType> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);
    boolean existsByCompanyIdAndCodeIgnoreCaseAndDeletedFalse(Long companyId, String code);
    boolean existsByCompanyIdAndCodeIgnoreCaseAndIdNotAndDeletedFalse(Long companyId, String code, Long id);

    java.util.Optional<LeaveType> findByCompanyIdAndCodeIgnoreCaseAndDeletedFalse(Long companyId, String code);
}
