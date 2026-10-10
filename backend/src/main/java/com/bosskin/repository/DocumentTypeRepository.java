package com.bosskin.repository;

import com.bosskin.entity.DocumentType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DocumentTypeRepository extends JpaRepository<DocumentType, Long> {

    List<DocumentType> findByCompanyIdAndDeletedFalseOrderBySortOrderAscNameAsc(Long companyId);

    Optional<DocumentType> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);

    boolean existsByCompanyIdAndCodeAndDeletedFalse(Long companyId, String code);
}
