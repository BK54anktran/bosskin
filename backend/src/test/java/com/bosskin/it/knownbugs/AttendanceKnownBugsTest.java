package com.bosskin.it.knownbugs;

import com.bosskin.entity.Attendance;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Tái hiện lỗi chấm công đã biết (Mốc 1 phần quyền duyệt, Mốc 2 phần còn lại).
 * Mỗi test khẳng định hành vi ĐÚNG nên hiện đang đỏ.
 *
 * Chưa có test cho ca đêm (A3/A4): logic check-in đọc LocalDateTime.now() trực tiếp,
 * cần đưa Clock vào trước (việc đầu tiên của Mốc 2) mới giả lập được giờ.
 */
@Tag("known-bug")
class AttendanceKnownBugsTest extends IntegrationTest {

    private static final LocalDate DAY = LocalDate.of(2026, 11, 3); // thứ Ba

    @Autowired AttendanceRepository attendanceRepository;
    @Autowired JdbcTemplate jdbc;

    @Test
    @DisplayName("A1 · Nhân viên chỉ có quyền xem chấm công không tự duyệt công của mình được")
    void a1_viewOnlyEmployeeCannotApproveOwnAttendance() {
        var c = fixture.standardCompany();
        c.createRole("Xem công", List.of("ATTENDANCE_SELF", "ATTENDANCE_VIEW"));
        var e = c.emp(7);
        c.setRole(e, "Xem công");
        long saId = c.assign(e, "HC", DAY);

        var res = api.post(c.tokenOf(e), "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", DAY.toString(), "shiftAssignmentId", saId));

        assertThat(res.status()).isEqualTo(403);
    }

    @Test
    @DisplayName("A2 · Không gắn được phân ca của công ty khác khi duyệt công (IDOR)")
    void a2_approveWithOtherCompanyShiftAssignment_isRejected() {
        var a = fixture.standardCompany();
        var b = fixture.standardCompany();
        long foreignSa = b.assign(b.emp(0), "HC", DAY);

        var res = api.post(a.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", a.emp(0).id(), "date", DAY.toString(), "shiftAssignmentId", foreignSa));

        assertThat(res.status()).isIn(400, 403, 404);
        assertThat(attendanceRepository.findByEmployeeIdAndDate(a.emp(0).id(), DAY))
            .noneMatch(att -> att.getShiftAssignment() != null
                && att.getShiftAssignment().getId() == foreignSa);
    }

    @Test
    @DisplayName("A5 · Bỏ duyệt không làm trạng thái công thành rỗng")
    void a5_unapproveKeepsStatus() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long saId = c.assign(e, "HC", DAY);
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", DAY.toString(), "shiftAssignmentId", saId)).expectOk();
        Attendance att = attendanceRepository.findByEmployeeIdAndDate(e.id(), DAY).get(0);

        api.post(c.adminToken, "/api/v1/attendances/unapprove", Map.of("attendanceId", att.getId())).expectOk();

        Attendance after = attendanceRepository.findById(att.getId()).orElseThrow();
        assertThat(after.getStatus()).as("trạng thái sau khi bỏ duyệt").isNotNull();
    }

    @Test
    @DisplayName("A7 · Xoá phân ca không xoá mất bản ghi công đã duyệt")
    void a7_deleteShiftAssignment_keepsApprovedAttendance() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long saId = c.assign(e, "HC", DAY);
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", DAY.toString(), "shiftAssignmentId", saId)).expectOk();
        long attId = attendanceRepository.findByEmployeeIdAndDate(e.id(), DAY).get(0).getId();

        var res = api.delete(c.adminToken, "/api/v1/shifts/assignments/" + saId);

        boolean refused = res.status() == 409;
        boolean kept = attendanceRepository.findById(attId).isPresent();
        assertThat(refused || kept)
            .as("phải từ chối xoá (409) hoặc giữ lại bản ghi công; thực tế HTTP %s, còn bản ghi: %s",
                res.status(), kept)
            .isTrue();
    }

    @Test
    @DisplayName("A9 · Không có 2 dòng công cho cùng nhân viên, cùng ngày khi không gắn phân ca")
    void a9_duplicateAttendanceWithoutShift_isBlockedByDatabase() {
        var c = fixture.newCompany();
        c.createDepartment("SX", "Sản xuất", null);
        var e = c.createEmployee("Nhân viên", "SX");
        String sql = "INSERT INTO attendances (employee_id, shift_assignment_id, date, status, approved, created_at, updated_at) "
            + "VALUES (?, NULL, ?, 'PRESENT', 0, NOW(), NOW())";

        jdbc.update(sql, e.id(), DAY);

        assertThatThrownBy(() -> jdbc.update(sql, e.id(), DAY))
            .as("unique (employee_id, date, shift_assignment_id) không chặn được vì NULL")
            .isInstanceOf(DataIntegrityViolationException.class);
    }
}
