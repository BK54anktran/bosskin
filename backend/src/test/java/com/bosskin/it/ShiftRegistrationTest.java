package com.bosskin.it;

import com.bosskin.entity.ShiftAssignment;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.service.ShiftRegistrationService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;

/** Đăng ký lịch làm việc (V23): đợt mở / đóng, nhân viên đăng ký theo ca / giờ / rảnh cả ngày, duyệt theo ngày → phân ca. */
class ShiftRegistrationTest extends IntegrationTest {

    @Autowired CompanyRepository companyRepository;
    @Autowired ShiftAssignmentRepository assignRepo;
    @Autowired ShiftRegistrationService service;

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 2, 9, 0);
    private static final LocalDate MON = LocalDate.of(2026, 11, 9);

    private Fixture.TestCompany company(boolean enabled) {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var co = companyRepository.findById(c.id).orElseThrow();
        co.setShiftRegistrationEnabled(enabled);
        companyRepository.save(co);
        return c;
    }

    private Map<String, Object> round(Fixture.TestCompany c, String name, LocalDate from, LocalDate to, boolean open, String... depts) {
        Map<String, Object> b = new LinkedHashMap<>();
        b.put("name", name);
        b.put("fromDate", from.toString());
        b.put("toDate", to.toString());
        b.put("departmentIds", Arrays.stream(depts).map(c.departments::get).toList());
        b.put("open", open);
        return b;
    }

    private static Map<String, Object> custom(LocalDate d, String start, String end) {
        return Map.of("workDate", d.toString(), "kind", "CUSTOM", "startTime", start, "endTime", end);
    }

    private static Map<String, Object> shift(LocalDate d, long shiftId) {
        return Map.of("workDate", d.toString(), "kind", "SHIFT", "shiftId", shiftId);
    }

    private static Map<String, Object> any(LocalDate d) {
        return Map.of("workDate", d.toString(), "kind", "ANY");
    }

    private com.bosskin.support.Api.Res save(String token, long roundId, List<Map<String, Object>> slots) {
        return api.put(token, "/api/v1/shift-registrations/self/rounds/" + roundId, Map.of("slots", slots));
    }

    @Test
    @DisplayName("Công ty tắt chức năng → API 403 disabled; vai trò Nhân viên mặc định có quyền tự đăng ký")
    void disabledCompany() {
        var c = company(false);
        var r = api.get(c.adminToken, "/api/v1/shift-registration-rounds");
        assertThat(r.status()).isEqualTo(403);
        assertThat(r.raw()).contains("error.shift_registration.disabled");
        var self = api.get(c.tokenOf(c.emp(6)), "/api/v1/shift-registrations/self/rounds");
        assertThat(self.status()).isEqualTo(403);
        assertThat(self.raw()).contains("error.shift_registration.disabled");
    }

    @Test
    @DisplayName("Đợt Nháp không hiện cho NV; mở → NV thuộc phòng ban đăng ký được; đóng → not_open; NV phòng khác → not_in_scope")
    void openCloseAndScope() {
        var c = company(true);
        long id = api.post(c.adminToken, "/api/v1/shift-registration-rounds",
            round(c, "Tuần 46", MON, MON.plusDays(6), false, "SX")).expectOk().id();
        String sx = c.tokenOf(c.emp(6));
        String kt = c.tokenOf(c.emp(3));

        assertThat(api.get(sx, "/api/v1/shift-registrations/self/rounds").expectOk().body().size()).isZero();
        assertThat(save(sx, id, List.of(custom(MON, "08:00", "14:00"))).raw()).contains("error.shift_registration.not_open");

        api.post(c.adminToken, "/api/v1/shift-registration-rounds/" + id + "/open", Map.of()).expectOk();
        assertThat(api.get(sx, "/api/v1/shift-registrations/self/rounds").expectOk().body().size()).isEqualTo(1);
        JsonNode mine = save(sx, id, List.of(custom(MON, "08:00", "14:00"), shift(MON.plusDays(1), c.shifts.get("CHIEU")),
            any(MON.plusDays(2)))).expectOk().body();
        assertThat(mine.path("registrations").size()).isEqualTo(3);
        assertThat(mine.path("registrations").get(1).path("startTime").asText()).as("giờ chụp từ ca").isEqualTo("13:00");
        assertThat(mine.path("shifts").size()).isEqualTo(4);

        var other = save(kt, id, List.of(custom(MON, "08:00", "14:00")));
        assertThat(other.status()).isEqualTo(403);
        assertThat(other.raw()).contains("error.shift_registration.not_in_scope");

        api.post(c.adminToken, "/api/v1/shift-registration-rounds/" + id + "/close", Map.of()).expectOk();
        assertThat(save(sx, id, List.of()).raw()).contains("error.shift_registration.not_open");
        assertThat(api.get(sx, "/api/v1/shift-registrations/self/rounds/" + id).expectOk().body().path("editable").asBoolean()).isFalse();

        JsonNode list = api.get(c.adminToken, "/api/v1/shift-registration-rounds").expectOk().body();
        assertThat(list.get(0).path("registeredCount").asInt()).isEqualTo(1);
        assertThat(list.get(0).path("employeeCount").asInt()).isEqualTo(5);
    }

    @Test
    @DisplayName("Kiểm tra khung: quá 2 khung, chồng giờ, rảnh cả ngày đi kèm khung khác, ngoài khung giờ / quá dài, ngày đã qua, số ngày tối thiểu")
    void slotValidation() {
        var c = company(true);
        Map<String, Object> b = round(c, "Tuần 46", MON, MON.plusDays(6), true, "SX");
        b.put("earliestTime", "06:00");
        b.put("latestTime", "23:00");
        b.put("maxHours", 10);
        b.put("minDays", 2);
        long id = api.post(c.adminToken, "/api/v1/shift-registration-rounds", b).expectOk().id();
        String t = c.tokenOf(c.emp(6));
        LocalDate tue = MON.plusDays(1);

        assertThat(save(t, id, List.of(custom(MON, "06:00", "08:00"), custom(MON, "09:00", "11:00"), custom(MON, "12:00", "14:00"),
            custom(tue, "08:00", "12:00"))).raw()).contains("error.shift_registration.too_many_slots");
        assertThat(save(t, id, List.of(custom(MON, "08:00", "12:00"), custom(MON, "11:00", "14:00"), custom(tue, "08:00", "12:00")))
            .raw()).contains("error.shift_registration.overlap_slot");
        assertThat(save(t, id, List.of(any(MON), custom(MON, "08:00", "12:00"), custom(tue, "08:00", "12:00")))
            .raw()).contains("error.shift_registration.any_alone");
        assertThat(save(t, id, List.of(custom(MON, "05:00", "12:00"), custom(tue, "08:00", "12:00")))
            .raw()).contains("error.shift_registration.outside_window|06:00|23:00");
        assertThat(save(t, id, List.of(custom(MON, "08:00", "22:00"), custom(tue, "08:00", "12:00")))
            .raw()).contains("error.shift_registration.too_long|10");
        assertThat(save(t, id, List.of(custom(MON, "08:00", "12:00"))).raw()).contains("error.shift_registration.min_days|2");
        assertThat(save(t, id, List.of(custom(MON.minusDays(1), "08:00", "12:00"), custom(tue, "08:00", "12:00")))
            .raw()).contains("error.shift_registration.outside_round");
        save(t, id, List.of(custom(MON, "08:00", "12:00"), custom(MON, "17:00", "22:00"), custom(tue, "08:00", "12:00"))).expectOk();

        // Hôm sau đợt bắt đầu: ngày đã qua giữ nguyên, không thêm được
        clock.set(tue.atTime(10, 0));
        assertThat(save(t, id, List.of(custom(MON, "08:00", "12:00"), custom(MON, "17:00", "22:00"), custom(MON.plusDays(2), "08:00", "12:00"),
            custom(MON.plusDays(3), "08:00", "12:00"))).status()).isEqualTo(200);
        assertThat(save(t, id, List.of(custom(MON, "13:00", "15:00"), custom(MON.plusDays(2), "08:00", "12:00")))
            .raw()).contains("error.shift_registration.past_date");
    }

    @Test
    @DisplayName("Duyệt theo ngày → phân ca đúng giờ / đúng ca; rảnh cả ngày cần chọn ca; trùng phân ca có sẵn bị bỏ qua; không tự duyệt của mình")
    void approveDay() {
        var c = company(true);
        long id = api.post(c.adminToken, "/api/v1/shift-registration-rounds",
            round(c, "Tuần 46", MON, MON.plusDays(6), true, "SX")).expectOk().id();
        var a = c.emp(5);
        var b = c.emp(6);
        var d = c.emp(7);
        var e = c.emp(8);
        save(c.tokenOf(a), id, List.of(custom(MON, "08:00", "14:00"))).expectOk();
        save(c.tokenOf(b), id, List.of(shift(MON, c.shifts.get("HC")))).expectOk();
        save(c.tokenOf(d), id, List.of(any(MON))).expectOk();
        save(c.tokenOf(e), id, List.of(custom(MON, "08:00", "12:00"))).expectOk();
        c.assign(e, "SANG", MON); // 06:00–10:00 chồng giờ đăng ký

        JsonNode res = api.post(c.adminToken, "/api/v1/shift-registration-rounds/" + id + "/days/" + MON + "/approve", Map.of())
            .expectOk().body();
        assertThat(res.path("approved").asInt()).isEqualTo(2);
        assertThat(res.path("skipped").size()).isEqualTo(2);
        assertThat(res.path("skipped").toString()).contains("error.shift_registration.any_needs_shift").contains("error.shift.overlap_same_day");

        List<ShiftAssignment> sa = assignRepo.findByEmployeeIdAndWorkDate(a.id(), MON);
        assertThat(sa).hasSize(1);
        assertThat(sa.get(0).effectiveStartTime()).isEqualTo(LocalTime.of(8, 0));
        assertThat(sa.get(0).effectiveEndTime()).isEqualTo(LocalTime.of(14, 0));
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(b.id(), MON).get(0).getShift().getId()).isEqualTo(c.shifts.get("HC"));

        // Lần 2 kèm ca cho người rảnh cả ngày: chỉ còn người trùng giờ
        JsonNode res2 = api.post(c.adminToken, "/api/v1/shift-registration-rounds/" + id + "/days/" + MON + "/approve",
            Map.of("anyShiftId", c.shifts.get("CHIEU"))).expectOk().body();
        assertThat(res2.path("approved").asInt()).isEqualTo(1);
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(d.id(), MON).get(0).getShift().getId()).isEqualTo(c.shifts.get("CHIEU"));

        // Ô còn lại: duyệt đổi giờ
        JsonNode board = api.get(c.adminToken, "/api/v1/shift-registration-rounds/" + id + "/board").expectOk().body();
        long pending = 0;
        for (JsonNode emp : board.path("employees")) {
            for (JsonNode r : emp.path("registrations")) if ("PENDING".equals(r.path("status").asText())) pending = r.path("id").asLong();
        }
        assertThat(pending).isPositive();
        api.post(c.adminToken, "/api/v1/shift-registrations/" + pending + "/approve", Map.of("startTime", "10:00", "endTime", "12:00")).expectOk();
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(e.id(), MON)).hasSize(2);

        // Đã duyệt: NV gửi lại không đổi được ngày đó, đợt không xoá được
        save(c.tokenOf(a), id, List.of(custom(MON, "15:00", "18:00"), custom(MON.plusDays(1), "08:00", "12:00"))).expectOk();
        JsonNode mine = api.get(c.tokenOf(a), "/api/v1/shift-registrations/self/rounds/" + id).expectOk().body();
        assertThat(mine.path("registrations").get(0).path("startTime").asText()).isEqualTo("08:00");
        assertThat(mine.path("registrations").size()).isEqualTo(2);
        assertThat(api.delete(c.adminToken, "/api/v1/shift-registration-rounds/" + id).raw()).contains("error.shift_registration.has_approved");
    }

    @Test
    @DisplayName("Quản lý không tự duyệt / từ chối đăng ký của mình; người phạm vi phòng khác không thấy đợt")
    void ownAndScope() {
        var c = company(true);
        long roleId = api.post(c.adminToken, "/api/v1/roles", Map.of(
            "name", "QL đăng ký SX", "description", "test", "roleViewAllCompany", true,
            "permissions", List.of("SHIFT_VIEW", "SHIFT_MANAGE", "SHIFT_REGISTRATION_MANAGE", "SHIFT_REGISTRATION_SELF"),
            "deptScopes", Map.of("SHIFT_VIEW", List.of(c.departments.get("SX"))))).expectOk().id();
        c.roles.put("QL đăng ký SX", roleId);
        var mgr = c.emp(5);
        c.setRole(mgr, "QL đăng ký SX");
        long id = api.post(c.adminToken, "/api/v1/shift-registration-rounds",
            round(c, "Tuần 46", MON, MON.plusDays(6), true, "SX")).expectOk().id();
        save(c.tokenOf(mgr), id, List.of(custom(MON, "08:00", "12:00"))).expectOk();
        JsonNode res = api.post(c.tokenOf(mgr), "/api/v1/shift-registration-rounds/" + id + "/days/" + MON + "/approve", Map.of())
            .expectOk().body();
        assertThat(res.path("approved").asInt()).isZero();
        assertThat(res.path("skipped").toString()).contains("error.shift_registration.cannot_process_own");

        // Đợt chỉ của phòng KT: quản lý giới hạn SHIFT_VIEW ở SX không thấy, không mở được, không tạo được cho KT
        long kt = api.post(c.adminToken, "/api/v1/shift-registration-rounds",
            round(c, "KT", MON, MON.plusDays(6), false, "KT")).expectOk().id();
        JsonNode list = api.get(c.tokenOf(mgr), "/api/v1/shift-registration-rounds").expectOk().body();
        assertThat(list.size()).isEqualTo(1);
        assertThat(api.get(c.tokenOf(mgr), "/api/v1/shift-registration-rounds/" + kt + "/board").status()).isEqualTo(404);
        assertThat(api.post(c.tokenOf(mgr), "/api/v1/shift-registration-rounds",
            round(c, "KT2", MON.plusDays(7), MON.plusDays(13), false, "KT")).status()).isEqualTo(403);
        // Nhân viên thường không có quyền quản lý
        assertThat(api.get(c.tokenOf(c.emp(7)), "/api/v1/shift-registration-rounds").status()).isEqualTo(403);
    }

    @Test
    @DisplayName("Hai đợt cùng phòng ban chồng ngày bị chặn; hạn chót qua → tự đóng")
    void overlapAndAutoClose() {
        var c = company(true);
        Map<String, Object> b = round(c, "Tuần 46", MON, MON.plusDays(6), true, "SX");
        b.put("closesAt", "2026-11-05T18:00:00");
        long id = api.post(c.adminToken, "/api/v1/shift-registration-rounds", b).expectOk().id();
        assertThat(api.post(c.adminToken, "/api/v1/shift-registration-rounds",
            round(c, "Chồng", MON.plusDays(3), MON.plusDays(9), false, "SX")).raw()).contains("error.shift_registration.overlap|Tuần 46");
        api.post(c.adminToken, "/api/v1/shift-registration-rounds",
            round(c, "Phòng khác", MON, MON.plusDays(6), false, "KT")).expectOk();

        clock.set(LocalDateTime.of(2026, 11, 5, 18, 1));
        service.autoClose();
        JsonNode list = api.get(c.adminToken, "/api/v1/shift-registration-rounds").expectOk().body();
        String status = null;
        for (JsonNode r : list) if (r.path("id").asLong() == id) status = r.path("status").asText();
        assertThat(status).isEqualTo("CLOSED");
    }

    @Test
    @DisplayName("Cài đặt công ty bật / tắt chức năng")
    void settingToggle() {
        var c = company(false);
        JsonNode s = api.get(c.adminToken, "/api/v1/company-settings").expectOk().body();
        assertThat(s.path("shiftRegistration").path("enabled").asBoolean()).isFalse();
        ((com.fasterxml.jackson.databind.node.ObjectNode) s).set("shiftRegistration",
            new com.fasterxml.jackson.databind.ObjectMapper().valueToTree(Map.of("enabled", true)));
        JsonNode after = api.put(c.adminToken, "/api/v1/company-settings", s).expectOk().body();
        assertThat(after.path("shiftRegistration").path("enabled").asBoolean()).isTrue();
        assertThat(api.get(c.adminToken, "/api/v1/shift-registration-rounds").status()).isEqualTo(200);
    }
}
