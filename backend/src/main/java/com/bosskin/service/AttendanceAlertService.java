package com.bosskin.service;

import com.bosskin.entity.Employee;
import com.bosskin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

/**
 * Báo quản lý trực tiếp khi nhân viên check-in trễ / check-out sớm (V33). Quản lý tự bật ở Thông báo → Cài đặt
 * (users.notif_late_alert / notif_early_leave_alert). Lỗi gửi không làm hỏng việc chấm công.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceAlertService {

    private static final DateTimeFormatter HM = DateTimeFormatter.ofPattern("HH:mm");

    private final UserRepository userRepository;
    private final PushService pushService;

    public void lateCheckIn(Employee employee, LocalDateTime at, LocalDateTime shiftStart) {
        long minutes = Duration.between(shiftStart, at).toMinutes();
        alert(employee, true, "ATTENDANCE_LATE", "push.late.title", "push.late.body",
            employee.getFullName(), at.format(HM), shiftStart.format(HM), String.valueOf(Math.max(minutes, 1)));
    }

    public void earlyCheckOut(Employee employee, LocalDateTime at, LocalDateTime shiftEnd) {
        long minutes = Duration.between(at, shiftEnd).toMinutes();
        alert(employee, false, "ATTENDANCE_EARLY", "push.early.title", "push.early.body",
            employee.getFullName(), at.format(HM), shiftEnd.format(HM), String.valueOf(Math.max(minutes, 1)));
    }

    private void alert(Employee employee, boolean late, String type, String titleKey, String bodyKey, Object... args) {
        try {
            Employee manager = employee.getManager();
            if (manager == null || manager.getStatus() == Employee.Status.INACTIVE) return;
            userRepository.findByEmployeeId(manager.getId())
                .filter(u -> u.isEnabled() && (late ? u.isNotifLateAlert() : u.isNotifEarlyLeaveAlert()))
                .ifPresent(u -> {
                    var loc = com.bosskin.i18n.AppText.localeOf(u.getLanguage());
                    pushService.notifyUser(u, type, com.bosskin.i18n.AppText.msgIn(loc, titleKey),
                        com.bosskin.i18n.AppText.msgIn(loc, bodyKey, args),
                        Map.of("employeeId", String.valueOf(employee.getId())));
                });
        } catch (RuntimeException ex) {
            log.warn("Không gửi được báo {} cho quản lý của NV {}: {}", type, employee.getId(), ex.getMessage());
        }
    }
}
