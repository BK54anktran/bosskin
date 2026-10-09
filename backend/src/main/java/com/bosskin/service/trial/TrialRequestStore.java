package com.bosskin.service.trial;

import com.bosskin.entity.TrialRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Nơi lưu yêu cầu dùng thử. Mặc định bảng MySQL {@code trial_requests} (V12); khi đặt
 * {@code SUPABASE_URL} + {@code SUPABASE_SECRET_KEY} thì đọc/ghi bảng {@code trial_requests} trên Supabase
 * (trang giới thiệu trên Netlify ghi thẳng vào đó) — xem {@code TrialRequestStoreConfig}.
 */
public interface TrialRequestStore {
    String name();
    void insert(TrialRequest t);
    boolean phoneSubmittedAfter(String phone, LocalDateTime after);
    Page<TrialRequest> search(TrialRequest.Status status, String q, Pageable pageable);
    List<TrialRequest> findAllForExport(TrialRequest.Status status);
    long countNew();
    Optional<TrialRequest> find(Long id);
    /** Ghi trạng thái, ghi chú, người xử lý của một yêu cầu đã có. */
    TrialRequest saveHandling(TrialRequest t);
}
