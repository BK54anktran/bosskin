package com.bosskin.service.trial;

import com.bosskin.entity.TrialRequest;
import com.bosskin.repository.TrialRequestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/** Lưu trong MySQL của BossKin (bảng V12). */
@RequiredArgsConstructor
public class JpaTrialRequestStore implements TrialRequestStore {
    private final TrialRequestRepository repository;

    @Override public String name() { return "local"; }
    @Override public void insert(TrialRequest t) { repository.save(t); }
    @Override public boolean phoneSubmittedAfter(String phone, LocalDateTime after) { return repository.existsByPhoneAndCreatedAtAfter(phone, after); }
    @Override public Page<TrialRequest> search(TrialRequest.Status status, String q, Pageable pageable) {
        String like = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase(Locale.ROOT) + "%";
        return repository.search(status, like, pageable);
    }
    @Override public List<TrialRequest> findAllForExport(TrialRequest.Status status) { return repository.findAllForExport(status); }
    @Override public long countNew() { return repository.countByStatus(TrialRequest.Status.NEW); }
    @Override public Optional<TrialRequest> find(Long id) { return repository.findById(id); }
    @Override public TrialRequest saveHandling(TrialRequest t) { return repository.save(t); }
}
