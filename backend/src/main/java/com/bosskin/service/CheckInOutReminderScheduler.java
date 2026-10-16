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

    private final java.time.Clock clock;

    /** Nhắc check-out tối đa trong khoảng này sau mốc nhắc (tránh gửi bù hàng loạt khi khởi động lại). */
    private static final long CHECK_OUT_GRACE_MINUTES = 30;

    /**
     * Nhắc check-in trước giờ vào ca và nhắc check-out sau giờ ra ca (O2).
     * So theo KHOẢNG thời gian tuyệt đối thay vì so khớp đúng phút — vòng chạy trễ hay
     * bị bỏ lỡ một phút vẫn gửi được; ca qua đêm tính giờ ra ca vào ngày hôm sau.
     * Mỗi phân ca chỉ nhắc một lần nhờ checkIn/OutNotifSentAt.
     */
    @Scheduled(fixedDelay = 60_000)
    @Transactional
    public void sendCheckInOutReminders() {
        List<User> users = userRepository
                .findAllByFcmTokenIsNotNullAndCheckInOutNotifMinutesIsNotNull();
        if (users.isEmpty()) return;

        LocalDateTime now = LocalDateTime.now(clock);
        LocalDate today = now.toLocalDate();

        for (User user : users) {
            if (user.getEmployeeId() == null) continue;
            if (user.getCompany() != null && !user.getCompany().hasFeature(com.bosskin.core.CompanyFeatures.SHIFT_REMINDER)) continue;
            int minutes = user.getCheckInOutNotifMinutes();

            for (LocalDate day : List.of(today.minusDays(1), today, today.plusDays(1))) {
                for (ShiftAssignment sa : shiftAssignmentRepository.findByEmployeeIdAndWorkDate(user.getEmployeeId(), day)) {
                    if (sa.isDeleted()) continue;
                    LocalTime startT = sa.effectiveStartTime();
                    LocalTime endT = sa.effectiveEndTime();
                    if (startT == null || endT == null) continue;
                    LocalDateTime start = day.atTime(startT);
                    LocalDateTime end = endT.isAfter(startT) ? day.atTime(endT) : day.plusDays(1).atTime(endT);
                    String name = sa.getSnapshotName() != null ? sa.getSnapshotName() : com.bosskin.i18n.AppText.msgIn(com.bosskin.i18n.AppText.localeOf(user.getLanguage()), "shift.defaultName");

                    if (sa.getCheckInNotifSentAt() == null
                            && !now.isBefore(start.minusMinutes(minutes)) && now.isBefore(start)) {
                        fcmService.sendCheckInOutNotif(user.getFcmToken(), user.getId(), user.getLanguage(), name, startT, day, true);
                        sa.setCheckInNotifSentAt(now);
                        shiftAssignmentRepository.save(sa);
                    }
                    LocalDateTime remindOut = end.plusMinutes(minutes);
                    if (sa.getCheckOutNotifSentAt() == null
                            && !now.isBefore(remindOut) && now.isBefore(remindOut.plusMinutes(CHECK_OUT_GRACE_MINUTES))) {
                        fcmService.sendCheckInOutNotif(user.getFcmToken(), user.getId(), user.getLanguage(), name, endT, day, false);
                        sa.setCheckOutNotifSentAt(now);
                        shiftAssignmentRepository.save(sa);
                    }
                }
            }
        }
    }
}
