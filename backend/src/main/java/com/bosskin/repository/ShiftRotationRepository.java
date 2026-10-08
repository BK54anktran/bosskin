package com.bosskin.repository;

import com.bosskin.entity.ShiftRotation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ShiftRotationRepository extends JpaRepository<ShiftRotation, Long> {
    List<ShiftRotation> findByCompanyIdAndActiveTrueOrderByName(Long companyId);
    Optional<ShiftRotation> findByIdAndCompanyIdAndActiveTrue(Long id, Long companyId);
}
