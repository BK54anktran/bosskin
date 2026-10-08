package com.bosskin.it;

import com.bosskin.entity.Attendance;
import com.bosskin.entity.ShiftAssignment;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/** Ca đa năng (Mốc 2b): linh hoạt, chia đôi, nhiều ca/ngày, xoay vòng, đổi ca. */
class ShiftTypesTest extends IntegrationTest {

    @Autowired AttendanceRepository attendanceRepository;
    @Autowired ShiftAssignmentRepository assignRepo;

    private static final LocalDate MON = LocalDate.of(2026, 11, 2);

    private long createShift(Fixture.TestCompany c, Map<String, Object> body) {
        long id = api.post(c.adminToken, "/api/v1/shifts", body).expectOk().id();
        c.shifts.put((String) body.get("code"), id);
        return id;
    }

    private void work(Fixture.TestCompany c, Fixture.Emp e, LocalDateTime in, LocalDateTime out) {
        String token = c.tokenOf(e);
        clock.set(in);
        assertThat(api.post(token, "/api/v1/attendances/self/check-in", Map.of()).status()).as("check-in %s", in).isEqualTo(201);
        clock.set(out);
        assertThat(api.post(token, "/api/v1/attendances/self/check-out", Map.of()).status()).as("check-out %s", out).isEqualTo(200);
    }

    private Attendance approve(Fixture.TestCompany c, Fixture.Emp e, LocalDate day, long saId) {
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", day.toString(), "shiftAssignmentId", saId)).expectOk();
        return attendanceRepository.findByEmployeeIdAndDate(e.id(), day).stream()
            .filter(a -> a.getShiftAssignment() != null && a.getShiftAssignment().getId() == saId)
            .findFirst().orElseThrow();
    }

    private static double regular(Attendance a) {
        return (a.getSnapDayHours() != null ? a.getSnapDayHours() : 0) + (a.getSnapNightHours() != null ? a.getSnapNightHours() : 0);
    }

    @Test
    @DisplayName("Ca linh hoạt: vào 10:00 không bị muộn; đủ 8 tiếng → đúng giờ, giờ công tối đa 8; thiếu giờ → đi muộn")
    void flexibleShift() {
        var c = fixture.standardCompany();
        createShift(c, new HashMap<>(Map.of("code", "FLEX", "name", "Linh hoạt", "startTime", "07:00", "endTime", "19:00",
            "shiftType", "FLEXIBLE", "requiredMinutes", 480)));
        var full = c.emp(6);
        var shortDay = c.emp(7);
        long sa1 = c.assign(full, "FLEX", MON);
        long sa2 = c.assign(shortDay, "FLEX", MON);

        work(c, full, MON.atTime(10, 0), MON.atTime(18, 30));
        assertThat(attendanceRepository.findByEmployeeIdAndDate(full.id(), MON).get(0).getStatus())
            .as("vào 10:00 trong khung linh hoạt không tính muộn").isEqualTo(Attendance.Status.PRESENT);
        work(c, shortDay, MON.atTime(10, 0), MON.atTime(16, 0));

        Attendance a1 = approve(c, full, MON, sa1);
        assertThat(a1.getStatus()).isEqualTo(Attendance.Status.PRESENT);
        assertThat(regular(a1)).as("giờ công chặn ở 8 tiếng").isCloseTo(8.0, within(0.01));

        Attendance a2 = approve(c, shortDay, MON, sa2);
        assertThat(a2.getStatus()).as("làm 6/8 tiếng → thiếu giờ").isEqualTo(Attendance.Status.LATE);
        assertThat(regular(a2)).isCloseTo(6.0, within(0.01));
    }

    @Test
    @DisplayName("Ca chia đôi 07:00–19:00 nghỉ 11:00–15:00: làm đủ cả ngày được 8 tiếng công")
    void splitShift() {
        var c = fixture.standardCompany();
        createShift(c, new HashMap<>(Map.of("code", "CHIA", "name", "Chia đôi", "startTime", "07:00", "endTime", "19:00",
            "breakStart", "11:00", "breakEnd", "15:00")));
        var e = c.emp(6);
        long sa = c.assign(e, "CHIA", MON);
        work(c, e, MON.atTime(6, 58), MON.atTime(19, 2));

        Attendance a = approve(c, e, MON, sa);
        assertThat(a.getStatus()).isEqualTo(Attendance.Status.PRESENT);
        assertThat(regular(a)).isCloseTo(8.0, within(0.01));
    }

    @Test
    @DisplayName("3 ca trong một ngày (sáng, chiều, tối): phân được, chấm công đúng từng ca")
    void threeShiftsInOneDay() {
        var c = fixture.standardCompany();
        c.createShift("TOI", "Ca tối", "18:00", "21:00", null, null);
        var e = c.emp(6);
        long s1 = c.assign(e, "SANG", MON);
        long s2 = c.assign(e, "CHIEU", MON);
        long s3 = c.assign(e, "TOI", MON);

        work(c, e, MON.atTime(5, 58), MON.atTime(10, 1));
        work(c, e, MON.atTime(12, 59), MON.atTime(17, 0));
        work(c, e, MON.atTime(17, 58), MON.atTime(21, 2));

        Map<Long, Integer> hourOfCheckIn = new HashMap<>();
        for (Attendance a : attendanceRepository.findByEmployeeIdAndDate(e.id(), MON)) {
            hourOfCheckIn.put(a.getShiftAssignment().getId(), a.getCheckIn().getHour());
        }
        assertThat(hourOfCheckIn).containsEntry(s1, 5).containsEntry(s2, 12).containsEntry(s3, 17);
    }

    @Test
    @DisplayName("Xoay vòng 2 sáng – 2 chiều – 2 đêm – 2 nghỉ: sinh 1 tháng cho 10 người đúng mẫu, lệch 1 ngày/người")
    void rotationForTenEmployeesOneMonth() {
        var c = fixture.standardCompany();
        long sang = c.shifts.get("SANG"), chieu = c.shifts.get("CHIEU"), dem = c.shifts.get("DEM");
        List<List<Long>> days = List.of(List.of(sang), List.of(sang), List.of(chieu), List.of(chieu),
            List.of(dem), List.of(dem), List.of(), List.of());
        long rotId = api.post(c.adminToken, "/api/v1/shift-rotations", Map.of("name", "4 kíp", "days", days)).expectOk().id();

        List<Long> empIds = c.employees.stream().map(Fixture.Emp::id).toList();
        LocalDate from = LocalDate.of(2026, 11, 1), to = LocalDate.of(2026, 11, 30);
        var res = api.post(c.adminToken, "/api/v1/shift-rotations/" + rotId + "/generate", Map.of(
            "employeeIds", empIds, "from", from.toString(), "to", to.toString(),
            "startOffset", 0, "staggerPerEmployee", 1)).expectOk().body();
        assertThat(res.path("conflicts").size()).as(res.toString()).isZero();

        for (int i = 0; i < empIds.size(); i++) {
            for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
                int k = (int) Math.floorMod(java.time.temporal.ChronoUnit.DAYS.between(from, d) + i, 8);
                List<Long> expected = days.get(k);
                List<Long> actual = assignRepo.findByEmployeeIdAndWorkDate(empIds.get(i), d).stream()
                    .map(a -> a.getShift().getId()).toList();
                assertThat(actual).as("NV %d ngày %s", i, d).isEqualTo(expected);
            }
        }

        // Sinh lại cùng mẫu: không đổi gì
        var again = api.post(c.adminToken, "/api/v1/shift-rotations/" + rotId + "/generate", Map.of(
            "employeeIds", empIds, "from", from.toString(), "to", to.toString(),
            "startOffset", 0, "staggerPerEmployee", 1)).expectOk().body();
        assertThat(again.path("assignedDays").asInt()).isZero();
        assertThat(again.path("clearedDays").asInt()).isZero();
    }

    @Test
    @DisplayName("Đổi ca được duyệt cập nhật đúng cả 2 người; nhường ca chuyển ca sang người nhận")
    void swapAndGiveAway() {
        var c = fixture.standardCompany();
        clock.set(MON.minusDays(3).atTime(9, 0));
        var a = c.emp(6);
        var b = c.emp(7);
        long aHc = c.assign(a, "HC", MON);
        long bDem = c.assign(b, "DEM", MON);
        long aTue = c.assign(a, "HC", MON.plusDays(1));
        String manager = c.tokenOf(c.emp(1));

        var myShifts = api.get(c.tokenOf(a), "/api/v1/shift-swaps/my-shifts").expectOk().body();
        assertThat(myShifts.size()).isEqualTo(2);
        var colleagues = api.get(c.tokenOf(a), "/api/v1/shift-swaps/colleagues?assignmentId=" + aHc).expectOk().body();
        boolean seesB = false;
        for (var col : colleagues) if (col.path("employeeId").asLong() == b.id()) {
            seesB = true;
            assertThat(col.path("shifts").get(0).path("assignmentId").asLong()).isEqualTo(bDem);
        }
        assertThat(seesB).as("thấy đồng nghiệp cùng phòng và ca của họ").isTrue();

        long swapId = api.post(c.tokenOf(a), "/api/v1/shift-swaps", Map.of(
            "requesterAssignmentId", aHc, "targetEmployeeId", b.id(), "targetAssignmentId", bDem,
            "reason", "Bận việc buổi sáng")).expectOk().id();
        assertThat(api.put(c.tokenOf(a), "/api/v1/shift-swaps/" + swapId + "/approve", Map.of()).status())
            .as("người gửi không tự duyệt").isEqualTo(403);
        api.put(manager, "/api/v1/shift-swaps/" + swapId + "/approve", Map.of()).expectOk();

        assertThat(assignRepo.findByEmployeeIdAndWorkDateWithShift(a.id(), MON)).extracting(sa -> sa.getShift().getCode()).containsExactly("DEM");
        assertThat(assignRepo.findByEmployeeIdAndWorkDateWithShift(b.id(), MON)).extracting(sa -> sa.getShift().getCode()).containsExactly("HC");

        long giveId = api.post(c.tokenOf(a), "/api/v1/shift-swaps", Map.of(
            "requesterAssignmentId", aTue, "targetEmployeeId", b.id())).expectOk().id();
        // b đã có ca DEM? Không — DEM 02/11 đã chuyển cho a; ngày 03/11 b trống nên nhận được
        api.put(manager, "/api/v1/shift-swaps/" + giveId + "/approve", Map.of()).expectOk();
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(a.id(), MON.plusDays(1))).isEmpty();
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(b.id(), MON.plusDays(1))).extracting(ShiftAssignment::getId).containsExactly(aTue);
    }

    @Test
    @DisplayName("Đổi ca bị từ chối khi người nhận đã có ca trùng giờ")
    void swapRejectedWhenOverlapping() {
        var c = fixture.standardCompany();
        clock.set(MON.minusDays(3).atTime(9, 0));
        var a = c.emp(6);
        var b = c.emp(7);
        long aHc = c.assign(a, "HC", MON);
        c.assign(b, "HC", MON);

        var res = api.post(c.tokenOf(a), "/api/v1/shift-swaps", Map.of(
            "requesterAssignmentId", aHc, "targetEmployeeId", b.id()));
        assertThat(res.status()).isEqualTo(409);
    }
}
