package com.bosskin.support;

import com.bosskin.dto.CreateCompanyRequest;
import com.bosskin.repository.RoleRepository;
import com.bosskin.repository.UserRepository;
import com.bosskin.service.CompanyService;
import org.springframework.boot.test.context.TestComponent;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Dựng dữ liệu mẫu cho integration test.
 *
 * <ul>
 *   <li>{@link #newCompany()} — công ty trống, chỉ có tài khoản admin (dùng để test luồng onboarding).</li>
 *   <li>{@link #standardCompany()} — bộ dữ liệu chuẩn dùng chung cho test và demo:
 *     3 phòng ban, 10 nhân viên, 4 ca (hành chính, đêm, sáng, chiều), 3 vai trò, 2 loại phép.</li>
 * </ul>
 *
 * Mỗi lần gọi tạo một công ty mới với mã riêng, nên các test độc lập với nhau.
 * Dữ liệu được tạo qua REST API thật (trừ bước tạo công ty của system admin)
 * để đi đúng luồng người dùng.
 */
@TestComponent
public class Fixture {

    public static final String PASSWORD = "Test@12345";

    /** Quyền của vai trò mẫu. Giữ ở đây để test đọc được "ai có quyền gì". */
    public static final List<String> PERMS_NHAN_VIEN = List.copyOf(CompanyService.DEFAULT_EMPLOYEE_PERMISSIONS);
    public static final List<String> PERMS_QUAN_LY_CONG = List.of(
        "ATTENDANCE_VIEW", "ATTENDANCE_MANAGE", "ATTENDANCE_APPROVE", "ATTENDANCE_REQUEST_APPROVE",
        "SHIFT_VIEW", "SHIFT_MANAGE", "SHIFT_SWAP_APPROVE", "EMPLOYEE_VIEW", "DEPARTMENT_VIEW",
        "LEAVE_VIEW", "LEAVE_REQUEST_APPROVE");
    public static final List<String> PERMS_KE_TOAN = List.of(
        "PAYROLL_VIEW", "PAYROLL_CREATE", "PAYROLL_APPROVE", "PAYROLL_PAY",
        "EMPLOYEE_VIEW", "ATTENDANCE_VIEW", "DASHBOARD_VIEW");

    private static final AtomicInteger SEQ = new AtomicInteger();

    private final CompanyService companyService;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final Api api;

    public Fixture(CompanyService companyService, UserRepository userRepository,
                   RoleRepository roleRepository, Api api) {
        this.companyService = companyService;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.api = api;
    }

    // ------------------------------------------------------------------ model

    public record Emp(long id, long userId, String email, String code, long departmentId) {}

    public class TestCompany {
        public final long id;
        public final String code;
        public final String adminEmail;
        public final String adminToken;
        public final Map<String, Long> departments = new LinkedHashMap<>();
        public final List<Emp> employees = new ArrayList<>();
        public final Map<String, Long> shifts = new LinkedHashMap<>();
        public final Map<String, Long> roles = new LinkedHashMap<>();
        public final Map<String, Long> leaveTypes = new LinkedHashMap<>();
        public final Map<String, Long> salaryGrades = new LinkedHashMap<>();

        TestCompany(long id, String code, String adminEmail, String adminToken) {
            this.id = id;
            this.code = code;
            this.adminEmail = adminEmail;
            this.adminToken = adminToken;
        }

        public Emp emp(int index) { return employees.get(index); }

        public String tokenOf(Emp e) { return api.token(e.email(), PASSWORD); }

        /** Email theo đuôi công ty test ({@code <mã>.test}) — V22 bắt buộc cho mọi tài khoản. */
        public String email(String local) { return local + "@" + code.toLowerCase() + ".test"; }

        public long createDepartment(String code, String name, Long parentId) {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("code", code);
            body.put("name", name);
            body.put("parentId", parentId);
            long id = api.post(adminToken, "/api/v1/departments", body).expectOk().id();
            departments.put(code, id);
            return id;
        }

        public Emp createEmployee(String fullName, String deptCode) {
            int n = employees.size() + 1;
            String email = String.format("e%02d@%s.test", n, code.toLowerCase());
            long deptId = departments.get(deptCode);
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("fullName", fullName);
            body.put("email", email);
            body.put("password", PASSWORD);
            body.put("gender", "MALE");
            body.put("joinDate", LocalDate.of(2025, 1, 1).toString());
            body.put("departmentId", deptId);
            var res = api.post(adminToken, "/api/v1/employees", body).expectOk();
            long userId = clearMustChangePassword(email);
            Emp e = new Emp(res.id(), userId, email, res.text("employeeCode"), deptId);
            employees.add(e);
            return e;
        }

        public long createRole(String name, List<String> permissions) {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("name", name);
            body.put("description", "Vai trò test");
            body.put("permissions", permissions);
            body.put("roleViewAllCompany", true);
            long id = api.post(adminToken, "/api/v1/roles", body).expectOk().id();
            roles.put(name, id);
            return id;
        }

        /** Thay toàn bộ vai trò của nhân viên bằng một vai trò. */
        public void setRole(Emp e, String roleName) {
            api.put(adminToken, "/api/v1/users/" + e.userId() + "/roles",
                Map.of("roleIds", List.of(roles.get(roleName)))).expectOk();
        }

        public long createShift(String code, String name, String start, String end,
                                String breakStart, String breakEnd) {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("code", code);
            body.put("name", name);
            body.put("startTime", start);
            body.put("endTime", end);
            body.put("breakStart", breakStart);
            body.put("breakEnd", breakEnd);
            long id = api.post(adminToken, "/api/v1/shifts", body).expectOk().id();
            shifts.put(code, id);
            return id;
        }

        /** Xếp 1 ca cho 1 nhân viên vào 1 ngày, trả id phân ca. */
        public long assign(Emp e, String shiftCode, LocalDate date) {
            return api.post(adminToken, "/api/v1/shifts/assignments", Map.of(
                "employeeId", e.id(),
                "shiftId", shifts.get(shiftCode),
                "workDate", date.toString())).expectOk().id();
        }

        public long createLeaveType(String code, String name, boolean paid) {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("code", code);
            body.put("name", name);
            body.put("unit", "DAY");
            body.put("deductPerDay", 1);
            body.put("paid", paid);
            body.put("active", true);
            long id = api.post(adminToken, "/api/v1/leaves/types", body).expectOk().id();
            leaveTypes.put(code, id);
            return id;
        }

        /** Bậc lương theo ngày (DAILY) hoặc giờ (HOURLY). */
        public long createSalaryGrade(String code, String payType, long baseRate) {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("code", code);
            body.put("name", "Bậc " + code);
            body.put("payType", payType);
            body.put("baseRate", baseRate);
            long id = api.post(adminToken, "/api/v1/salary-grades", body).expectOk().id();
            salaryGrades.put(code, id);
            return id;
        }

        public void setSalaryGrade(Emp e, String gradeCode) {
            api.put(adminToken, "/api/v1/employees/" + e.id(),
                Map.of("salaryGradeId", salaryGrades.get(gradeCode))).expectOk();
        }

        public void grantLeaveDays(Emp e, String leaveTypeCode, int days) {
            api.post(adminToken, "/api/v1/leaves/grants/manual", Map.of(
                "employeeId", e.id(),
                "leaveTypeId", leaveTypes.get(leaveTypeCode),
                "grantDays", days,
                "validFrom", LocalDate.of(2020, 1, 1).toString(),
                "validTo", LocalDate.of(2099, 12, 31).toString(),
                "note", "Cấp phép cho test")).expectOk();
        }
    }

    // ---------------------------------------------------------------- builders

    /**
     * Tài khoản do admin tạo bị buộc đổi mật khẩu ở lần đầu (V7). Test nghiệp vụ dùng tài khoản
     * như đã đổi xong; luồng buộc đổi có test riêng (AuthTest.mustChangePassword_*).
     */
    public long clearMustChangePassword(String email) {
        var u = userRepository.findByEmail(email).orElseThrow();
        u.setMustChangePassword(false);
        userRepository.save(u);
        return u.getId();
    }

    /** Công ty mới tinh: chỉ có admin do system admin tạo, chưa có vai trò nào khác. */
    public TestCompany newCompany() {
        int n = SEQ.incrementAndGet();
        String code = "T" + Long.toString(System.nanoTime() % 1_000_000_000L, 36).toUpperCase() + n;
        String adminEmail = "admin@" + code.toLowerCase() + ".test";

        CreateCompanyRequest req = new CreateCompanyRequest();
        req.setName("Công ty test " + code);
        req.setCode(code);
        req.setDomain(code.toLowerCase() + ".test");
        req.setAdminEmail(adminEmail);
        req.setAdminPassword(PASSWORD);
        req.setAdminFullName("Admin " + code);
        long id = companyService.create(req).getId();
        clearMustChangePassword(adminEmail);

        return new TestCompany(id, code, adminEmail, api.token(adminEmail, PASSWORD));
    }

    /**
     * Bộ dữ liệu chuẩn:
     * <pre>
     * Phòng ban : BGD (Ban giám đốc), KT (Kế toán), SX (Sản xuất)
     * Nhân viên : e01–e02 BGD, e03–e05 KT, e06–e10 SX — tất cả vai trò "Nhân viên"
     *             e02 = "Quản lý chấm công", e03 = "Kế toán"
     * Ca        : HC 08:00–17:00 (nghỉ 12–13), DEM 22:00–06:00, SANG 06:00–10:00, CHIEU 13:00–17:00
     * Loại phép : PN (phép năm, có lương), KL (nghỉ không lương)
     * Bậc lương : NGAY300 (300.000đ/ngày) gán cho mọi nhân viên
     * </pre>
     */
    public TestCompany standardCompany() {
        TestCompany c = newCompany();

        c.createDepartment("BGD", "Ban giám đốc", null);
        c.createDepartment("KT", "Kế toán", null);
        c.createDepartment("SX", "Sản xuất", null);

        String[][] people = {
            {"Nguyễn Văn An", "BGD"}, {"Trần Thị Bình", "BGD"},
            {"Lê Văn Cường", "KT"}, {"Phạm Thị Dung", "KT"}, {"Hoàng Văn Em", "KT"},
            {"Vũ Thị Giang", "SX"}, {"Đặng Văn Hùng", "SX"}, {"Bùi Thị Lan", "SX"},
            {"Đỗ Văn Minh", "SX"}, {"Ngô Thị Nga", "SX"},
        };
        for (String[] p : people) c.createEmployee(p[0], p[1]);

        // "Nhân viên" là vai trò mặc định tạo sẵn khi onboarding công ty (CompanyService)
        c.roles.put("Nhân viên", roleRepository.findFirstByCompanyIdAndIsDefaultTrue(c.id).orElseThrow().getId());
        c.createRole("Quản lý chấm công", PERMS_QUAN_LY_CONG);
        c.createRole("Kế toán", PERMS_KE_TOAN);
        for (Emp e : c.employees) c.setRole(e, "Nhân viên");
        c.setRole(c.emp(1), "Quản lý chấm công");
        c.setRole(c.emp(2), "Kế toán");

        c.createShift("HC", "Hành chính", "08:00", "17:00", "12:00", "13:00");
        c.createShift("DEM", "Ca đêm", "22:00", "06:00", null, null);
        c.createShift("SANG", "Ca sáng", "06:00", "10:00", null, null);
        c.createShift("CHIEU", "Ca chiều", "13:00", "17:00", null, null);

        c.createLeaveType("PN", "Phép năm", true);
        c.createLeaveType("KL", "Nghỉ không lương", false);

        c.createSalaryGrade("NGAY300", "DAILY", 300_000);
        for (Emp e : c.employees) c.setSalaryGrade(e, "NGAY300");
        return c;
    }
}
