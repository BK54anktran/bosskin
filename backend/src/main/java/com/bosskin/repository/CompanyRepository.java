package com.bosskin.repository;

import com.bosskin.entity.Company;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CompanyRepository extends JpaRepository<Company, Long> {
    Optional<Company> findByCode(String code);
    boolean existsByCode(String code);
    boolean existsByIdAndActiveTrue(Long id);
}
