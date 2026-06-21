package com.bosskin.service;

import com.bosskin.entity.FcmNotificationLog;
import com.bosskin.repository.FcmNotificationLogRepository;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

@Service
@Slf4j
@RequiredArgsConstructor
public class FcmService {

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final FcmNotificationLogRepository logRepository;

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
            String body = shiftName + " bắt đầu lúc " + startTime.format(TIME_FMT)
                + " — còn " + minutesBefore + " phút nữa";
            Message message = Message.builder()
                .setToken(fcmToken)
                .setAndroidConfig(AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .build())
                .putData("type", "SHIFT_REMINDER")
                .putData("title", "Nhắc nhở ca làm việc")
                .putData("body", body)
                .putData("workDate", workDate.toString())
                .build();
            String msgId = FirebaseMessaging.getInstance().send(message);
            log.info("FCM sent → token={}... shift='{}' start={} msgId={}",
                fcmToken.substring(0, 10), shiftName, startTime.format(TIME_FMT), msgId);
            logRepository.save(entry.status("SUCCESS").build());
        } catch (FirebaseMessagingException e) {
            log.warn("FCM failed → token={}... shift='{}': {}",
                fcmToken.substring(0, 10), shiftName, e.getMessage());
            logRepository.save(entry.status("FAILED").errorMessage(e.getMessage()).build());
        }
    }
}
