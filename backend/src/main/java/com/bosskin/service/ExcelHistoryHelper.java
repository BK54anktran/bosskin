package com.bosskin.service;

import com.bosskin.config.S3Properties;
import com.bosskin.entity.ExcelHistory;
import com.bosskin.entity.ExcelHistory.HistoryType;
import com.bosskin.repository.ExcelHistoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Component
@RequiredArgsConstructor
public class ExcelHistoryHelper {

    private static final String EXCEL_CONTENT_TYPE =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    private final ExcelHistoryRepository historyRepo;
    private final S3Service s3Service;
    private final S3Properties s3Properties;

    /**
     * Lưu lịch sử file Excel (export/import/report) vào DB và upload S3 nếu có config.
     * Chạy trong transaction độc lập để không bị ảnh hưởng bởi readOnly transaction của caller.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void save(Long companyId, Long userId,
                     HistoryType type, String module,
                     String filename, byte[] bytes,
                     Integer ok, Integer error, Integer skip) {
        // Upload S3 trước — nếu fail thì fileUrl = null, vẫn lưu DB
        String fileUrl = null;
        if (bytes != null && bytes.length > 0 && isS3Configured()) {
            try {
                fileUrl = s3Service.uploadRaw(bytes, "excel-history", filename, EXCEL_CONTENT_TYPE);
            } catch (Exception e) {
                log.warn("ExcelHistory S3 upload failed for '{}': {}", filename, e.getMessage(), e);
            }
        }

        var entry = ExcelHistory.builder()
                .companyId(companyId)
                .userId(userId)
                .type(type)
                .module(module)
                .filename(filename)
                .fileUrl(fileUrl)
                .okCount(ok)
                .errorCount(error)
                .skipCount(skip)
                .build();
        historyRepo.save(entry);
    }

    private boolean isS3Configured() {
        String bucket = s3Properties.getBucket();
        return bucket != null && !bucket.isBlank();
    }
}
