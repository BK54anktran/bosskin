package com.bosskin.it;

import com.bosskin.entity.Attendance;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;

/** Import phân ca dạng đối chiếu – cập nhật, không xoá đi tạo lại (Mốc 2, A6). */
class ShiftImportTest extends IntegrationTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired AttendanceRepository attendanceRepository;
    @Autowired ShiftAssignmentRepository assignRepo;

    private static final LocalDate NOV_3 = LocalDate.of(2026, 11, 3);

    @Test
    @DisplayName("A6 · Import lại đúng file vừa xuất: giữ nguyên phân ca, công đã duyệt vẫn gắn đúng ca")
    void reimportSameFile_keepsAssignmentsAndAttendance() throws Exception {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long saId = c.assign(e, "HC", NOV_3);
        c.assign(e, "HC", NOV_3.plusDays(1));
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", NOV_3.toString(), "shiftAssignmentId", saId)).expectOk();

        byte[] file = mvc.perform(get("/api/v1/shifts/export").param("year", "2026").param("month", "11")
                .header("Authorization", "Bearer " + c.adminToken))
            .andReturn().getResponse().getContentAsByteArray();

        var res = mvc.perform(multipart("/api/v1/shifts/import-assignments")
                .file(new MockMultipartFile("file", "phan-cong.xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", file))
                .header("Authorization", "Bearer " + c.adminToken))
            .andReturn().getResponse();
        assertThat(res.getStatus()).as(res.getContentAsString()).isEqualTo(200);
        JsonNode summary = json.readTree(res.getContentAsString());

        assertThat(summary.path("assigned").asInt()).as("không tạo phân ca mới").isZero();
        assertThat(summary.path("deleted").asInt()).as("không xoá phân ca nào").isZero();
        assertThat(assignRepo.findById(saId)).get().matches(sa -> !sa.isDeleted(), "phân ca cũ còn hiệu lực");
        Attendance att = attendanceRepository.findByEmployeeIdAndDate(e.id(), NOV_3).get(0);
        assertThat(att.getShiftAssignment().getId()).isEqualTo(saId);
        assertThat(att.isApproved()).isTrue();
    }
}
