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
public class CheckInOutReminderScheduler {

    private final UserRepository userRepository;
    private final ShiftAssignmentRepository shiftAssignmentRepository;
    private final FcmService fcmService;

    @Scheduled(fixedDelay = 60_000)
    @Transactional
    public void sendCheckInOutReminders() {
        List<User> users = userRepository
                .findAllByFcmTokenIsNotNullAndCheckInOutNotifMinutesIsNotNull();
        if (users.isEmpty()) return;

        LocalDate today = LocalDate.now();
        LocalTime nowMinute = LocalTime.now().truncatedTo(ChronoUnit.MINUTES);

        for (User user : users) {
            if (user.getEmployeeId() == null) continue;
            int minutes = user.getCheckInOutNotifMinutes();

            // Check-in: tìm ca có effectiveStart = now + minutes
            // Nếu targetStart vượt qua 00:00 (wrap) → ca thuộc ngày mai
            LocalTime targetStart = nowMinute.plusMinutes(minutes);
            LocalDate checkInDate = targetStart.isBefore(nowMinute) ? today.plusDays(1) : today;
            List<ShiftAssignment> checkIns = shiftAssignmentRepository
                    .findForCheckInNotif(user.getEmployeeId(), checkInDate, targetStart);
            for (ShiftAssignment sa : checkIns) {
                LocalTime effectiveStart = sa.getCustomStartTime() != null
                        ? sa.getCustomStartTime() : sa.getSnapshotStartTime();
                if (effectiveStart == null) continue;
                String name = sa.getSnapshotName() != null ? sa.getSnapshotName() : "Ca làm việc";
                fcmService.sendCheckInOutNotif(
                        user.getFcmToken(), user.getId(), name, effectiveStart, checkInDate, true);
                sa.setCheckInNotifSentAt(LocalDateTime.now());
                shiftAssignmentRepository.save(sa);
            }

            // Check-out: tìm ca có effectiveEnd = now - minutes
            // Nếu targetEnd vượt qua 00:00 ngược lại (wrap) → ca thuộc ngày hôm qua
            LocalTime targetEnd = nowMinute.minusMinutes(minutes);
            LocalDate checkOutDate = targetEnd.isAfter(nowMinute) ? today.minusDays(1) : today;
            List<ShiftAssignment> checkOuts = shiftAssignmentRepository
                    .findForCheckOutNotif(user.getEmployeeId(), checkOutDate, targetEnd);
            for (ShiftAssignment sa : checkOuts) {
                LocalTime effectiveEnd = sa.getCustomEndTime() != null
                        ? sa.getCustomEndTime() : sa.getSnapshotEndTime();
                if (effectiveEnd == null) continue;
                String name = sa.getSnapshotName() != null ? sa.getSnapshotName() : "Ca làm việc";
                fcmService.sendCheckInOutNotif(
                        user.getFcmToken(), user.getId(), name, effectiveEnd, checkOutDate, false);
                sa.setCheckOutNotifSentAt(LocalDateTime.now());
                shiftAssignmentRepository.save(sa);
            }
        }
    }
}
