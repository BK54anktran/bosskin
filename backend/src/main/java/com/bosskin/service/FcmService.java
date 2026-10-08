package com.bosskin.service;

import com.bosskin.entity.FcmNotificationLog;
import com.bosskin.repository.FcmNotificationLogRepository;
import com.bosskin.repository.UserRepository;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.ApsAlert;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;

@Service
@Slf4j
@RequiredArgsConstructor
public class FcmService {

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final FcmNotificationLogRepository logRepository;
    private final UserRepository userRepository;

    /** FCM báo token không còn dùng được (gỡ app, đổi máy…) → gỡ khỏi DB để khỏi gửi mãi (F10). */
    private void dropIfDead(String fcmToken, FirebaseMessagingException e) {
        MessagingErrorCode code = e.getMessagingErrorCode();
        if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.SENDER_ID_MISMATCH) {
            int n = userRepository.clearFcmToken(fcmToken);
            log.info("FCM token hết hiệu lực ({}), đã gỡ khỏi {} tài khoản", code, n);
        }
    }

    public void sendCheckInOutNotif(String fcmToken, Long userId, String shiftName,
                                    LocalTime shiftTime, LocalDate workDate, boolean isCheckIn) {
        if (FirebaseApp.getApps().isEmpty()) return;

        String title = isCheckIn ? "Đến giờ check-in" : "Đến giờ check-out";
        String body  = isCheckIn
            ? shiftName + " bắt đầu lúc " + shiftTime.format(TIME_FMT) + " — hãy check-in ngay"
            : shiftName + " đã kết thúc lúc " + shiftTime.format(TIME_FMT) + " — đừng quên check-out";

        FcmNotificationLog.FcmNotificationLogBuilder entry = FcmNotificationLog.builder()
            .userId(userId)
            .fcmToken(fcmToken)
            .shiftName(shiftName)
            .shiftStart(shiftTime)
            .workDate(workDate)
            .minutesBefore(0)
            .sentAt(LocalDateTime.now());

        try {
            Message message = Message.builder()
                .setToken(fcmToken)
                .setAndroidConfig(AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setNotification(AndroidNotification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build())
                    .build())
                .setApnsConfig(ApnsConfig.builder()
                    .setAps(Aps.builder()
                        .setAlert(ApsAlert.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                        .setSound("default")
                        .build())
                    .build())
                .putData("type", isCheckIn ? "CHECK_IN_REMINDER" : "CHECK_OUT_REMINDER")
                .putData("title", title)
                .putData("body", body)
                .putData("workDate", workDate.toString())
                .putData("shiftTime", shiftTime.format(TIME_FMT))
                .build();
            FirebaseMessaging.getInstance().send(message);
            logRepository.save(entry.status("SUCCESS").build());
        } catch (FirebaseMessagingException e) {
            logRepository.save(entry.status("FAILED").errorMessage(e.getMessage()).build());
            dropIfDead(fcmToken, e);
        }
    }

    public void sendShiftReminder(String fcmToken, Long userId, String shiftName,
                                  LocalTime startTime, LocalDate workDate, int minutesBefore) {
        if (FirebaseApp.getApps().isEmpty()) return;

        FcmNotificationLog.FcmNotificationLogBuilder entry = FcmNotificationLog.builder()
            .userId(userId)
            .fcmToken(fcmToken)
            .shiftName(shiftName)
            .shiftStart(startTime)
            .workDate(workDate)
            .minutesBefore(minutesBefore)
            .sentAt(LocalDateTime.now());

        try {
            long actualMinutes = ChronoUnit.MINUTES.between(
                LocalTime.now().truncatedTo(ChronoUnit.MINUTES), startTime);
            String body = shiftName + " bắt đầu lúc " + startTime.format(TIME_FMT)
                + " — còn " + actualMinutes + " phút nữa";
            Message message = Message.builder()
                .setToken(fcmToken)
                .setAndroidConfig(AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setNotification(AndroidNotification.builder()
                        .setTitle("Nhắc nhở ca làm việc")
                        .setBody(body)
                        .build())
                    .build())
                .setApnsConfig(ApnsConfig.builder()
                    .setAps(Aps.builder()
                        .setAlert(ApsAlert.builder()
                            .setTitle("Nhắc nhở ca làm việc")
                            .setBody(body)
                            .build())
                        .setSound("default")
                        .build())
                    .build())
                .putData("type", "SHIFT_REMINDER")
                .putData("title", "Nhắc nhở ca làm việc")
                .putData("body", body)
                .putData("workDate", workDate.toString())
                .putData("startTime", startTime.format(TIME_FMT))
                .build();
            String msgId = FirebaseMessaging.getInstance().send(message);
            log.info("FCM sent → token={}... shift='{}' start={} msgId={}",
                fcmToken.substring(0, 10), shiftName, startTime.format(TIME_FMT), msgId);
            logRepository.save(entry.status("SUCCESS").build());
        } catch (FirebaseMessagingException e) {
            log.warn("FCM failed → token={}... shift='{}': {}",
                fcmToken.substring(0, 10), shiftName, e.getMessage());
            logRepository.save(entry.status("FAILED").errorMessage(e.getMessage()).build());
            dropIfDead(fcmToken, e);
        }
    }
}
