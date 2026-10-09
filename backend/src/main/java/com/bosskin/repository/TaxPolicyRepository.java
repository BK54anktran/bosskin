package com.bosskin.repository;

import com.bosskin.entity.TaxPolicy;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface TaxPolicyRepository extends JpaRepository<TaxPolicy, Long> {
    Optional<TaxPolicy> findTopByEffectiveFromLessThanEqualOrderByEffectiveFromDesc(LocalDate date);
    List<TaxPolicy> findAllByOrderByEffectiveFromDesc();
    boolean existsByEffectiveFrom(LocalDate date);
    boolean existsByEffectiveFromAndIdNot(LocalDate date, Long id);
}
