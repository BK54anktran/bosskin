package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ScriptUtils;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bậc lương / chức vụ bị xoá mềm trong khi NV vẫn trỏ tới → nạp NV ném EntityNotFoundException,
 * danh sách nhân viên trả 500 (13/10/2026). Chặn xoá khi còn dùng + V20 gỡ dữ liệu hỏng sẵn có.
 */
class DanglingReferenceTest extends IntegrationTest {

    @Autowired JdbcTemplate jdbc;
    @Autowired DataSource dataSource;

    private void runV20() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            ScriptUtils.executeSqlScript(conn,
                new ClassPathResource("db/migration/V20__restore_referenced_grades_positions.sql"));
        }
    }

    private int listStatus(String token) {
        return api.get(token, "/api/v1/employees?page=0&size=20").status();
    }

    @Test
    @DisplayName("Không xoá được bậc lương còn nhân viên dùng (nút xoá) — danh sách NV vẫn tải được")
    void deleteGradeInUse_isRejected() {
        var c = fixture.standardCompany();
        long gid = c.salaryGrades.get("NGAY300");

        var del = api.delete(c.adminToken, "/api/v1/salary-grades/" + gid);
        assertThat(del.status()).isEqualTo(409);
        assertThat(del.raw()).contains("error.salary_grade.in_use");
        assertThat(listStatus(c.adminToken)).isEqualTo(200);

        // Bậc chưa ai dùng vẫn xoá được
        long unused = c.createSalaryGrade("GIO50", "HOURLY", 50_000);
        assertThat(api.delete(c.adminToken, "/api/v1/salary-grades/" + unused).status()).isEqualTo(204);
    }

    @Test
    @DisplayName("V20 khôi phục bậc lương / chức vụ đã xoá nhầm mà NV còn dùng → danh sách NV hết 500")
    void v20_restoresDeletedReferencedRows() throws Exception {
        var c = fixture.standardCompany();
        long gid = c.salaryGrades.get("NGAY300");
        var e = c.emp(2);
        long posId = api.post(c.adminToken, "/api/v1/positions", Map.of(
            "code", "TP", "name", "Trưởng phòng", "departmentId", e.departmentId())).expectOk().id();
        api.put(c.adminToken, "/api/v1/employees/" + e.id(), Map.of(
            "positionId", posId, "salaryGradeId", gid)).expectOk();

        // Dữ liệu hỏng như production: bị xoá mềm trong khi NV vẫn trỏ tới
        jdbc.update("UPDATE salary_grades SET deleted = 1 WHERE id = ?", gid);
        jdbc.update("UPDATE positions SET deleted = 1 WHERE id = ?", posId);
        assertThat(listStatus(c.adminToken)).isEqualTo(500);

        runV20();

        assertThat(listStatus(c.adminToken)).isEqualTo(200);
        assertThat(jdbc.queryForObject("SELECT deleted FROM salary_grades WHERE id = ?", Boolean.class, gid)).isFalse();
        assertThat(jdbc.queryForObject("SELECT deleted FROM positions WHERE id = ?", Boolean.class, posId)).isFalse();
        var emp = api.get(c.adminToken, "/api/v1/employees/" + e.id()).expectOk().body();
        assertThat(emp.path("salaryGradeId").asLong()).isEqualTo(gid);
        assertThat(emp.path("positionId").asLong()).isEqualTo(posId);
    }

    @Test
    @DisplayName("V20: đã tạo lại bậc cùng mã sau khi xoá → NV trỏ sang bậc đang dùng, không khôi phục bản trùng mã")
    void v20_repointsToRecreatedGrade() throws Exception {
        var c = fixture.standardCompany();
        long oldId = c.salaryGrades.get("NGAY300");
        jdbc.update("UPDATE salary_grades SET deleted = 1 WHERE id = ?", oldId);
        long newId = c.createSalaryGrade("NGAY300", "DAILY", 320_000);
        assertThat(listStatus(c.adminToken)).isEqualTo(500);

        runV20();

        assertThat(listStatus(c.adminToken)).isEqualTo(200);
        assertThat(jdbc.queryForObject("SELECT deleted FROM salary_grades WHERE id = ?", Boolean.class, oldId)).isTrue();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM employees WHERE salary_grade_id = ?", Integer.class, oldId)).isZero();
        var emp = api.get(c.adminToken, "/api/v1/employees/" + c.emp(1).id()).expectOk().body();
        assertThat(emp.path("salaryGradeId").asLong()).isEqualTo(newId);
    }
}
