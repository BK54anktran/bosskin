package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Hồi quy cho các ràng buộc unique viết lại trong V1 baseline (D2, D3):
 * unique chỉ áp cho bản ghi còn hiệu lực và đúng phạm vi công ty.
 */
class SchemaConstraintsTest extends IntegrationTest {

    @Test
    @DisplayName("D2 · Xoá mềm, tạo lại, xoá lần nữa cùng mã phòng ban không lỗi trùng")
    void d2_departmentCode_canBeDeletedAndRecreatedRepeatedly() {
        var c = fixture.newCompany();

        for (int i = 0; i < 3; i++) {
            long id = c.createDepartment("KHO", "Kho vận", null);
            assertThat(api.delete(c.adminToken, "/api/v1/departments/" + id).ok()).isTrue();
        }
        assertThat(c.createDepartment("KHO", "Kho vận", null)).isPositive();
    }

    @Test
    @DisplayName("D2 · Hai phòng ban còn hiệu lực trùng mã trong cùng công ty bị chặn")
    void d2_duplicateActiveDepartmentCode_isRejected() {
        var c = fixture.newCompany();
        c.createDepartment("KHO", "Kho vận", null);

        var res = api.post(c.adminToken, "/api/v1/departments", Map.of("code", "KHO", "name", "Kho 2"));

        assertThat(res.status()).isIn(400, 409);
    }

    @Test
    @DisplayName("D3 · Hai công ty dùng cùng mã chức vụ được")
    void d3_positionCode_isScopedPerCompany() {
        var a = fixture.newCompany();
        var b = fixture.newCompany();
        long deptA = a.createDepartment("SX", "Sản xuất", null);
        long deptB = b.createDepartment("SX", "Sản xuất", null);

        var resA = api.post(a.adminToken, "/api/v1/positions",
            Map.of("code", "TT", "name", "Tổ trưởng", "departmentId", deptA));
        var resB = api.post(b.adminToken, "/api/v1/positions",
            Map.of("code", "TT", "name", "Tổ trưởng", "departmentId", deptB));

        assertThat(resA.status()).as(resA.raw()).isEqualTo(201);
        assertThat(resB.status()).as(resB.raw()).isEqualTo(201);
    }

    @Test
    @DisplayName("Loại phép đã xoá tạo lại được với cùng mã")
    void leaveTypeCode_canBeRecreatedAfterDelete() {
        var c = fixture.newCompany();
        long id = c.createLeaveType("PN", "Phép năm", true);
        assertThat(api.delete(c.adminToken, "/api/v1/leaves/types/" + id).ok()).isTrue();

        assertThat(c.createLeaveType("PN", "Phép năm", true)).isPositive();
    }
}
