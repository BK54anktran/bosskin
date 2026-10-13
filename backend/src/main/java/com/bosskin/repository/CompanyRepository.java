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

    /** V22: kiểm mã công ty mới không trùng / không là tiền tố của mã khác (mã NV không trùng giữa công ty). */
    @org.springframework.data.jpa.repository.Query("SELECT c.code FROM Company c")
    java.util.List<String> findAllCodes();

    boolean existsByDomainIgnoreCase(String domain);
    boolean existsByDomainIgnoreCaseAndIdNot(String domain, Long id);
}
