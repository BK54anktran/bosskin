package com.bosskin.core;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** V26: kiểm danh mục tính năng và bảng đường dẫn (không cần DB). */
class CompanyFeaturesCatalogTest {

    @Test
    @DisplayName("Danh mục: mã duy nhất, 'cần' trỏ tới tính năng có thật và đứng trước, mỗi gói cũ có tính năng gốc")
    void catalogIsConsistent() {
        Set<String> seen = new HashSet<>();
        for (CompanyFeatures.Feature x : CompanyFeatures.CATALOG) {
            assertThat(seen.add(x.code())).as("trùng mã %s", x.code()).isTrue();
            for (String need : x.requires()) {
                assertThat(seen).as("%s cần %s phải đứng trước trong danh mục", x.code(), need).contains(need);
            }
        }
        for (String m : CompanyModules.ALL) {
            assertThat(CompanyFeatures.baseOf(m)).as("gói %s có tính năng gốc", m).isNotNull();
        }
        assertThat(CompanyFeatures.ALL).hasSize(33);
    }

    @Test
    @DisplayName("Bảng đường dẫn: mọi mục trỏ tới tính năng có thật và khớp đúng tính năng mong đợi")
    void routesMapToKnownFeatures() {
        for (String[] s : FeatureRoutes.samples()) {
            assertThat(CompanyFeatures.exists(s[1])).as("%s → %s", s[0], s[1]).isTrue();
        }
        assertThat(FeatureRoutes.featureOf("POST", "/api/v1/attendances/self/check-in")).isEqualTo(CompanyFeatures.ATT_SELF);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/attendances/timesheet")).isEqualTo(CompanyFeatures.ATT_SHEET);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/leaves/accrual-rules")).isEqualTo(CompanyFeatures.LEAVE_ACCRUAL);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/leaves/requests")).isEqualTo(CompanyFeatures.LEAVE_BASIC);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/reports/payroll-summary")).isEqualTo(CompanyFeatures.RPT_PAYROLL);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/reports/new-hires")).isEqualTo(CompanyFeatures.RPT_OVERVIEW);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/employees/12/job-histories")).isEqualTo(CompanyFeatures.HR_JOBHISTORY);
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/employees/12/locations")).isEqualTo(CompanyFeatures.ATT_GEOFENCE);
        // lịch hiệu lực luôn đọc được; phần nền không thuộc tính năng nào
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/work-calendars/view")).isNull();
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/employees")).isNull();
        assertThat(FeatureRoutes.featureOf("GET", "/api/v1/departments")).isNull();
    }

    @Test
    @DisplayName("Bật / tắt: kiểm 'cần', mã lạ, tự chấm công cần ca hoặc chấm không ca")
    void validation() {
        List<String> all = CompanyFeatures.ALL;
        assertThat(CompanyFeatures.disabledFromEnabled(all)).isEmpty();

        List<String> noSheet = all.stream().filter(c -> !c.equals(CompanyFeatures.ATT_SHEET)).toList();
        assertThatThrownBy(() -> CompanyFeatures.disabledFromEnabled(noSheet))
            .hasMessageContaining("error.company.feature_requires|ATT_SELF|ATT_SHEET");
        assertThatThrownBy(() -> CompanyFeatures.disabledFromEnabled(List.of("ABC")))
            .hasMessageContaining("error.company.feature_invalid|ABC");

        // tự chấm công không có ca cơ bản và không bật chấm-không-ca
        List<String> noShift = all.stream().filter(c -> !c.startsWith("SHIFT_") && !c.equals(CompanyFeatures.ATT_NOSHIFT)
            && !c.equals(CompanyFeatures.HR_MANAGER_APPROVAL) && !c.equals(CompanyFeatures.RPT_PAYROLL)
            && !c.equals(CompanyFeatures.RPT_INSURANCE)).toList();
        assertThat(noShift).contains(CompanyFeatures.ATT_SELF);
        assertThatThrownBy(() -> CompanyFeatures.disabledFromEnabled(noShift))
            .hasMessageContaining("error.company.feature_requires_any|ATT_SELF|SHIFT_BASIC|ATT_NOSHIFT");
    }

    @Test
    @DisplayName("Tương thích V24: gói cũ tắt ⇒ mọi tính năng con tắt; modules suy ra từ tính năng gốc")
    void legacyModules() {
        Set<String> off = CompanyFeatures.disabledFromModules(List.of("ATTENDANCE", "SHIFT", "LEAVE", "DOCUMENT", "REPORT"));
        assertThat(off).contains("PAY_BASIC", "PAY_FORMULA", "PAY_TAX_INS", "PAY_DEPENDENT", "PAY_EMPLOYER_COST",
            "HR_CONTRACT", "HR_CONTRACT_ALERT");
        assertThat(off).doesNotContain("ATT_SELF", "SHIFT_SWAP", "HR_ORGCHART", "CAL_HOLIDAY", "DATA_EXCEL");
        assertThat(CompanyFeatures.modulesOf(off)).containsExactly("ATTENDANCE", "SHIFT", "LEAVE", "DOCUMENT", "REPORT");
        assertThat(CompanyFeatures.parse(CompanyFeatures.format(off))).isEqualTo(off);
        assertThat(CompanyFeatures.format(Set.of())).isNull();
    }

    @Test
    @DisplayName("Quyền: ATTENDANCE_SELF thuộc tính năng gốc của gói (không bị mất khi chỉ tắt ATT_SELF)")
    void permissionMapping() {
        assertThat(CompanyFeatures.featureOfPermission("ATTENDANCE_SELF")).isEqualTo(CompanyFeatures.ATT_SHEET);
        assertThat(CompanyFeatures.featureOfPermission("ATTENDANCE_REQUEST_APPROVE")).isEqualTo(CompanyFeatures.ATT_REQUEST);
        assertThat(CompanyFeatures.featureOfPermission("SHIFT_REGISTRATION_SELF")).isEqualTo(CompanyFeatures.SHIFT_REGISTRATION);
        assertThat(CompanyFeatures.featureOfPermission("LEAVE_ACCRUAL_VIEW")).isEqualTo(CompanyFeatures.LEAVE_ACCRUAL);
        assertThat(CompanyFeatures.featureOfPermission("PAYROLL_VIEW")).isEqualTo(CompanyFeatures.PAY_BASIC);
        assertThat(CompanyFeatures.featureOfPermission("EMPLOYEE_VIEW")).isNull();
        assertThat(CompanyFeatures.featureOfPermission("CALENDAR_VIEW")).isNull();
    }
}
