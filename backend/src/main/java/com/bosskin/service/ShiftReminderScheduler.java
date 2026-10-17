package com.bosskin.service;

import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.User;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class ShiftReminderScheduler {

    private final UserRepository userRepository;
    private final ShiftAssignmentRepository shiftAssignmentRepository;
    private final FcmService fcmService;

    @Scheduled(fixedDelay = 60_000)
    @Transactional
    public void sendShiftReminders() {
        List<User> users = userRepository.findAllByFcmTokenIsNotNullAndShiftReminderMinutesIsNotNull();
        if (users.isEmpty()) return;

        try {
        for (User user : users) {
            if (user.getEmployeeId() == null) continue;
            // V32: giờ nhắc theo múi giờ của công ty người nhận
            java.time.ZoneId zone = com.bosskin.core.CompanyZone.parseOrDefault(
                user.getCompany() != null ? user.getCompany().getTimezone() : null);
            java.time.Clock zoneClock = java.time.Clock.system(zone);
            com.bosskin.core.CompanyZone.set(zone); // FcmService tính số phút còn lại theo cùng múi giờ
            LocalDate today = LocalDate.now(zoneClock);
            LocalTime nowMinute = LocalTime.now(zoneClock).truncatedTo(ChronoUnit.MINUTES);
            if (user.getCompany() != null && !user.getCompany().hasFeature(com.bosskin.core.CompanyFeatures.SHIFT_REMINDER)) continue;
            int minutes = user.getShiftReminderMinutes();
            LocalTime targetShiftStart = nowMinute.plusMinutes(minutes);

            List<ShiftAssignment> assignments = shiftAssignmentRepository
                .findForReminder(user.getEmployeeId(), today, nowMinute, targetShiftStart);

            for (ShiftAssignment sa : assignments) {
                LocalTime effectiveStart = sa.getCustomStartTime() != null
                    ? sa.getCustomStartTime()
                    : sa.getSnapshotStartTime();
                if (effectiveStart == null) continue;

                String shiftName = sa.getSnapshotName() != null
                    ? sa.getSnapshotName()
                    : com.bosskin.i18n.AppText.msgIn(com.bosskin.i18n.AppText.localeOf(user.getLanguage()), "shift.customName");

                fcmService.sendShiftReminder(
                    user.getFcmToken(),
                    user.getId(),
                    user.getLanguage(),
                    shiftName,
                    effectiveStart,
                    today,
                    minutes
                );
                sa.setReminderSentAt(com.bosskin.core.CompanyZone.now());
                shiftAssignmentRepository.save(sa);
            }
        }
        } finally {
            com.bosskin.core.CompanyZone.clear();
        }
    }
}
