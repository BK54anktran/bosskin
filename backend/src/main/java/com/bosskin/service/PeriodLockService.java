package com.bosskin.service;

import com.bosskin.core.PayrollPeriod;
import com.bosskin.entity.AttendancePeriodLock;
import com.bosskin.entity.Company;
import com.bosskin.repository.AttendancePeriodLockRepository;
import com.bosskin.repository.CompanyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Khoá kỳ công (A12). Kỳ tháng T tính theo ngày chốt công của công ty
 * ({@link PayrollPeriod}). Kỳ đã khoá thì mọi thao tác ghi có ngày nằm trong kỳ
 * bị từ chối với 409 {@code error.period.locked}.
 */
@Service
@RequiredArgsConstructor
public class PeriodLockService {

    private final AttendancePeriodLockRepository lockRepository;
    private final CompanyRepository companyRepository;
    private final Clock clock;

    public record PeriodStatus(int year, int month, LocalDate from, LocalDate to, boolean locked,
                               LocalDateTime lockedAt, Long lockedById,
                               LocalDateTime unlockedAt, Long unlockedById, String unlockReason) {}

    /** Ném 409 nếu ngày nằm trong một kỳ đã khoá. */
    public void requireOpen(Long companyId, LocalDate date) {
        if (date != null) requireOpen(companyId, date, date);
    }

    /** Ném 409 nếu khoảng [from, to] giao với một kỳ đã khoá. */
    public void requireOpen(Long companyId, LocalDate from, LocalDate to) {
        if (companyId == null || from == null) return;
        LocalDate end = to != null ? to : from;
        if (lockRepository.existsLockedOverlapping(companyId, from, end)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.period.locked");
        }
    }

    public boolean isLocked(Long companyId, LocalDate date) {
        return lockRepository.existsLockedOverlapping(companyId, date, date);
    }

    @Transactional
    public PeriodStatus lock(Long companyId, Long userId, int year, int month) {
        PayrollPeriod period = periodOf(companyId, year, month);
        AttendancePeriodLock l = lockRepository.findByCompanyIdAndYearAndMonth(companyId, year, month)
            .orElseGet(() -> AttendancePeriodLock.builder().companyId(companyId).year(year).month(month).build());
        if (l.getId() != null && l.isLocked()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.period.already_locked");
        }
        l.setPeriodFrom(period.from());
        l.setPeriodTo(period.to());
        l.setLocked(true);
        l.setLockedAt(LocalDateTime.now(clock));
        l.setLockedById(userId);
        return toStatus(lockRepository.save(l));
    }

    @Transactional
    public PeriodStatus unlock(Long companyId, Long userId, int year, int month, String reason) {
        if (reason == null || reason.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.period.unlock_reason_required");
        }
        AttendancePeriodLock l = lockRepository.findByCompanyIdAndYearAndMonth(companyId, year, month)
            .filter(AttendancePeriodLock::isLocked)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT, "error.period.not_locked"));
        l.setLocked(false);
        l.setUnlockedAt(LocalDateTime.now(clock));
        l.setUnlockedById(userId);
        l.setUnlockReason(reason.trim());
        return toStatus(lockRepository.save(l));
    }

    /** Trạng thái 12 kỳ của một năm (kỳ chưa từng khoá trả locked = false). */
    @Transactional(readOnly = true)
    public List<PeriodStatus> listYear(Long companyId, int year) {
        Map<Integer, AttendancePeriodLock> byMonth = lockRepository.findByCompanyIdAndYearOrderByMonth(companyId, year)
            .stream().collect(Collectors.toMap(AttendancePeriodLock::getMonth, Function.identity()));
        List<PeriodStatus> result = new ArrayList<>();
        for (int m = 1; m <= 12; m++) {
            AttendancePeriodLock l = byMonth.get(m);
            if (l != null) {
                result.add(toStatus(l));
            } else {
                PayrollPeriod p = periodOf(companyId, year, m);
                result.add(new PeriodStatus(year, m, p.from(), p.to(), false, null, null, null, null, null));
            }
        }
        return result;
    }

    private PayrollPeriod periodOf(Long companyId, int year, int month) {
        if (month < 1 || month > 12) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.bad_request");
        }
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        return PayrollPeriod.of(year, month, company.getPayrollCutoffDay());
    }

    private static PeriodStatus toStatus(AttendancePeriodLock l) {
        return new PeriodStatus(l.getYear(), l.getMonth(), l.getPeriodFrom(), l.getPeriodTo(), l.isLocked(),
            l.getLockedAt(), l.getLockedById(), l.getUnlockedAt(), l.getUnlockedById(), l.getUnlockReason());
    }
}
