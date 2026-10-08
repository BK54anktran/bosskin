package com.bosskin.it;

import com.bosskin.entity.Attendance;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Quy tắc tính công phần còn lại của Mốc 2 (A15, A16, A17, đơn tự duyệt). */
class AttendanceRulesTest extends IntegrationTest {

    private static final LocalDate MON = LocalDate.of(2026, 11, 2);

    @Autowired AttendanceRepository attendanceRepository;

    private long createRequest(String token, Map<String, Object> body) {
        var res = api.post(token, "/api/v1/attendance-requests", body).expectOk();
        return res.body().isArray() ? res.body().get(0).path("id").asLong() : res.id();
    }

    @Test
    @DisplayName("A17 · Ca mẫu qua đêm 22:00–06:00 có 480 phút làm việc")
    void overnightShiftTemplate_hasPositiveWorkMinutes() {
        var c = fixture.standardCompany();

        var shifts = api.get(c.adminToken, "/api/v1/shifts").expectOk().body();
        int workMinutes = -1;
        for (var sh : shifts) if ("DEM".equals(sh.path("code").asText())) workMinutes = sh.path("workMinutes").asInt(-1);

        assertThat(workMinutes).isEqualTo(480);
    }

    @Test
    @DisplayName("A16 · Đơn sửa giờ vào đã duyệt thay thế giờ thực, kể cả khi sửa muộn hơn giờ thực")
    void correctionRequest_replacesActualCheckIn() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long saId = c.assign(e, "HC", MON);
        String token = c.tokenOf(e);
        clock.set(MON.atTime(7, 58));
        api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(MON.atTime(17, 5));
        api.post(token, "/api/v1/attendances/self/check-out", Map.of()).expectOk();

        // Thực tế bấm check-in hộ lúc 07:58 nhưng người đó tới lúc 09:00 → quản lý sửa giờ vào
        long reqId = createRequest(token, Map.of(
            "requestDate", MON.toString(), "requestType", "CHECK_IN",
            "requestedCheckIn", "09:00", "shiftAssignmentId", saId, "note", "Sửa giờ vào thực tế"));
        api.put(c.tokenOf(c.emp(1)), "/api/v1/attendance-requests/" + reqId + "/approve", Map.of()).expectOk();
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", MON.toString(), "shiftAssignmentId", saId)).expectOk();

        Attendance att = attendanceRepository.findByEmployeeIdAndDate(e.id(), MON).get(0);
        assertThat(att.getSnapActualHours()).isEqualTo(7.0);
    }

    @Test
    @DisplayName("Người duyệt không tự duyệt đơn chấm công của chính mình")
    void approverCannotApproveOwnRequest() {
        var c = fixture.standardCompany();
        var approver = c.emp(1);
        c.assign(approver, "HC", MON);
        long reqId = createRequest(c.tokenOf(approver), Map.of(
            "requestDate", MON.toString(), "requestType", "CHECK_IN",
            "requestedCheckIn", "08:00", "note", "Quên check-in"));

        var res = api.put(c.tokenOf(approver), "/api/v1/attendance-requests/" + reqId + "/approve", Map.of());

        assertThat(res.status()).isEqualTo(403);
    }
}
