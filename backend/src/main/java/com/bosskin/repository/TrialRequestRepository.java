package com.bosskin.repository;

import com.bosskin.entity.TrialRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface TrialRequestRepository extends JpaRepository<TrialRequest, Long> {

    @Query("""
        SELECT t FROM TrialRequest t
        WHERE (:status IS NULL OR t.status = :status)
          AND (:q IS NULL OR LOWER(t.fullName) LIKE :q OR LOWER(t.companyName) LIKE :q
               OR t.phone LIKE :q OR LOWER(t.email) LIKE :q)
        ORDER BY t.createdAt DESC
        """)
    Page<TrialRequest> search(@Param("status") TrialRequest.Status status, @Param("q") String q, Pageable pageable);

    @Query("""
        SELECT t FROM TrialRequest t
        WHERE (:status IS NULL OR t.status = :status)
        ORDER BY t.createdAt DESC
        """)
    List<TrialRequest> findAllForExport(@Param("status") TrialRequest.Status status);

    long countByStatus(TrialRequest.Status status);

    boolean existsByPhoneAndCreatedAtAfter(String phone, LocalDateTime after);
}
