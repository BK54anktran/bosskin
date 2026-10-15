package com.bosskin.it;

import com.bosskin.core.CompanyFeatures;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.Company;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.service.PayrollService;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * V26: cài đặt của tính năng đã tắt bị ẩn ở màn Cài đặt nên backend phải coi như TẮT (không kẹt giá trị cũ, không hưởng tính năng chưa đăng ký).
 */
class CompanyFeatureBehaviorTest extends IntegrationTest {

    private static final LocalDate MON = LocalDate.of(2026, 11, 2);

    @Autowired CompanyRepository companyRepository;
    @Autowired AttendanceRepository attendanceRepository;
    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;

    private String sys() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    private void setFeaturesOff(Fixture.TestCompany c, String... off) {
        List<String> skip = List.of(off);
        api.put(sys(), "/admin/companies/" + c.id, Map.of("features",
            CompanyFeatures.ALL.stream().filter(x -> !skip.contains(x)).toList())).expectOk();
    }

    private void company(Fixture.TestCompany c, java.util.function.Consumer<Company> edit) {
        Company co = companyRepository.findById(c.id).orElseThrow();
        edit.accept(co);
        companyRepository.save(co);
    }

    private Map<String, Object> dayLeave(long typeId, String date) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("leaveTypeId", typeId);
        m.put("mode", "DAY_RANGE");
        m.put("fromDate", date);
        m.put("toDate", date);
        m.put("reason", "Việc riêng");
        return m;
    }

    @Test
    @DisplayName("Duyệt 2 cấp: đang MANAGER_THEN_HR mà tắt tính năng → HR duyệt thẳng được (không kẹt chờ quản lý), /team-approvals 403")
    void managerApprovalOff_doesNotDeadlock() {
        var c = fixture.standardCompany();
        var staff = c.emp(7);
        var lead = c.emp(5);
        String hr = c.tokenOf(c.emp(1));
        c.grantLeaveDays(staff, "PN", 5);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("managerId", lead.id());
        api.put(c.adminToken, "/api/v1/employees/" + staff.id(), body).expectOk();
        company(c, co -> co.setApprovalMode(Company.ApprovalMode.MANAGER_THEN_HR));

        long blockedId = api.post(c.tokenOf(staff), "/api/v1/leaves/requests", dayLeave(c.leaveTypes.get("PN"), "2026-11-10")).expectOk().id();
        assertThat(api.put(hr, "/api/v1/leaves/requests/" + blockedId + "/approve", Map.of()).status()).isEqualTo(409);

        setFeaturesOff(c, "HR_MANAGER_APPROVAL");
        assertThat(api.get(c.tokenOf(lead), "/api/v1/team-approvals").status()).isEqualTo(403);
        assertThat(api.put(hr, "/api/v1/leaves/requests/" + blockedId + "/approve", Map.of()).status()).isEqualTo(200);
        long next = api.post(c.tokenOf(staff), "/api/v1/leaves/requests", dayLeave(c.leaveTypes.get("PN"), "2026-11-11")).expectOk().id();
        assertThat(api.put(hr, "/api/v1/leaves/requests/" + next + "/approve", Map.of()).status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Chấm không ca: cài đặt đang bật mà tắt tính năng ATT_NOSHIFT → ngày không ca không chấm được")
    void noShiftOff_ignoresStoredSetting() {
        var c = fixture.standardCompany();
        company(c, co -> co.setCheckInWithoutShift(true));
        String token = c.tokenOf(c.emp(6));
        clock.set(MON.atTime(9, 0));
        assertThat(api.post(token, "/api/v1/attendances/self/check-in", Map.of()).status()).isEqualTo(201);

        setFeaturesOff(c, "ATT_NOSHIFT");
        var e7 = c.emp(7);
        clock.set(MON.atTime(9, 0));
        var r = api.post(c.tokenOf(e7), "/api/v1/attendances/self/check-in", Map.of());
        assertThat(r.status()).isEqualTo(400);
        assertThat(r.raw()).contains("error.attendance.no_shift_today");
        assertThat(attendanceRepository.findByEmployeeIdAndDate(e7.id(), MON)).isEmpty();
    }

    @Test
    @DisplayName("GPS / thiết bị: cài đặt bật mà tắt tính năng → không còn kiểm vị trí / thiết bị")
    void geofenceAndDeviceOff_ignoreStoredSettings() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", MON);
        company(c, co -> {
            co.setLocationCheckEnabled(true);
            co.setCheckInLatitude(10.0);
            co.setCheckInLongitude(106.0);
            co.setCheckInRadiusMeters(50);
            co.setDeviceBindingEnabled(true);
        });
        String token = c.tokenOf(e);
        clock.set(MON.atTime(8, 0));
        // Còn bật: thiếu thiết bị / toạ độ → bị chặn
        assertThat(api.post(token, "/api/v1/attendances/self/check-in", Map.of()).status()).isEqualTo(403);

        setFeaturesOff(c, "ATT_GEOFENCE", "ATT_DEVICE");
        assertThat(api.post(token, "/api/v1/attendances/self/check-in", Map.of()).status()).isEqualTo(201);
    }

    @Test
    @DisplayName("Ca đặc biệt: tắt SHIFT_ADVANCED → không tạo ca linh hoạt / qua đêm, ca thường vẫn tạo được")
    void advancedShiftsOff() {
        var c = fixture.standardCompany();
        setFeaturesOff(c, "SHIFT_ADVANCED");
        Map<String, Object> overnight = new LinkedHashMap<>();
        overnight.put("name", "Đêm 2"); overnight.put("code", "DEM2"); overnight.put("startTime", "22:00"); overnight.put("endTime", "06:00");
        var r = api.post(c.adminToken, "/api/v1/shifts", overnight);
        assertThat(r.status()).isEqualTo(403);
        assertThat(r.raw()).contains("error.company.feature_disabled");
        Map<String, Object> normal = new LinkedHashMap<>();
        normal.put("name", "Chiều 2"); normal.put("code", "CHIEU2"); normal.put("startTime", "13:00"); normal.put("endTime", "17:00");
        assertThat(api.post(c.adminToken, "/api/v1/shifts", normal).status()).isIn(200, 201);
    }

    @Test
    @DisplayName("Công ty chưa đăng ký tính năng: bảng công của ngày không ca đã duyệt trước đó vẫn đọc được (dữ liệu cũ giữ)")
    void existingNoShiftDataKeptWhenFeatureOff() {
        var c = fixture.standardCompany();
        company(c, co -> co.setCheckInWithoutShift(true));
        var e = c.emp(6);
        String token = c.tokenOf(e);
        clock.set(MON.atTime(9, 0));
        api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(MON.atTime(13, 0));
        api.post(token, "/api/v1/attendances/self/check-out", Map.of()).expectOk();
        setFeaturesOff(c, "ATT_NOSHIFT");
        List<Attendance> rows = attendanceRepository.findByEmployeeIdAndDate(e.id(), MON);
        assertThat(rows).hasSize(1);
        assertThat(rows.get(0).getCheckOut()).isEqualTo(LocalDateTime.of(MON, java.time.LocalTime.of(13, 0)));
    }

    private void workThreeDays(Fixture.TestCompany c, Fixture.Emp e) {
        var emp = employeeRepository.findById(e.id()).orElseThrow();
        emp.setContractSalary(java.math.BigDecimal.valueOf(22_000_000));
        employeeRepository.save(emp);
        for (int i = 0; i < 3; i++) {
            LocalDate day = MON.plusDays(i);
            long sa = c.assign(e, "HC", day);
            String token = c.tokenOf(e);
            clock.set(day.atTime(7, 55));
            api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
            clock.set(day.atTime(17, 2));
            api.post(token, "/api/v1/attendances/self/check-out", Map.of()).expectOk();
            api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
                "employeeId", e.id(), "date", day.toString(), "shiftAssignmentId", sa)).expectOk();
        }
    }

    @Test
    @DisplayName("Lương: tắt PAY_TAX_INS → không trừ thuế / BH; tắt PAY_EMPLOYER_COST → phần công ty đóng = 0; còn bật → như cũ")
    void payrollTaxInsuranceAndEmployerCostOff() {
        var c = fixture.standardCompany();
        var withFeatures = c.emp(6);
        var without = c.emp(7);
        workThreeDays(c, withFeatures);
        workThreeDays(c, without);
        SalaryFormula f = SalaryFormula.builder().name("T")
            .expressionGross("ROUND(CONTRACT_SALARY / STANDARD_WORK_DAYS * PRESENT_DAYS)")
            .expressionNet("GROSS - TOTAL_INSURANCE - PIT").build();

        Payroll on = payrollService.generatePayrollWithFormula(withFeatures.id(), 2026, 11, f);
        assertThat(on.getSocialInsurance()).isGreaterThan(java.math.BigDecimal.ZERO);
        assertThat(on.getEmployerSocialIns()).isGreaterThan(java.math.BigDecimal.ZERO);

        setFeaturesOff(c, "PAY_TAX_INS", "PAY_DEPENDENT", "PAY_EMPLOYER_COST", "RPT_INSURANCE");
        Payroll off = payrollService.generatePayrollWithFormula(without.id(), 2026, 11, f);
        assertThat(off.getSocialInsurance()).isEqualByComparingTo("0");
        assertThat(off.getHealthInsurance()).isEqualByComparingTo("0");
        assertThat(off.getUnemploymentInsurance()).isEqualByComparingTo("0");
        assertThat(off.getPersonalIncomeTax()).isEqualByComparingTo("0");
        assertThat(off.getEmployerSocialIns()).isEqualByComparingTo("0");
        assertThat(off.getEmployerHealthIns()).isEqualByComparingTo("0");
        assertThat(off.getNetSalary()).isEqualByComparingTo(off.getGrossSalary());
    }
}
