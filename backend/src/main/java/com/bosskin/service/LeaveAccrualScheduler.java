package com.bosskin.service;

import com.bosskin.entity.Company;
import com.bosskin.repository.CompanyRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.LocalDate;

/**
 * Cộng phép tự động hằng ngày lúc 00:15 giờ Việt Nam cho mọi công ty đang hoạt động (L10).
 * Trước đây quy tắc chỉ chạy khi HR bấm đúng ngày cấu hình.
 * Chạy lại an toàn: LeaveService bỏ qua nhân viên đã được cộng trong kỳ.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class LeaveAccrualScheduler {

    private final CompanyRepository companyRepository;
    private final LeaveService leaveService;
    private final Clock clock;

    @Scheduled(cron = "0 15 0 * * *", zone = "Asia/Ho_Chi_Minh")
    public void runDaily() {
        LocalDate today = LocalDate.now(clock);
        for (Company company : companyRepository.findAll()) {
            if (!company.isActive() || !company.hasFeature(com.bosskin.core.CompanyFeatures.LEAVE_ACCRUAL)) continue;
            try {
                var result = leaveService.runAccrualForCompany(company.getId(), today);
                if (result.getOrDefault("created", 0) > 0) {
                    log.info("Cộng phép tự động công ty {}: {} lượt", company.getId(), result.get("created"));
                }
            } catch (Exception e) {
                log.error("Cộng phép tự động lỗi ở công ty {}", company.getId(), e);
            }
        }
    }
}
