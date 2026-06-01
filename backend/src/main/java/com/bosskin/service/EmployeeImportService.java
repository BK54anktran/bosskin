package com.bosskin.service;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.dto.EmployeeDTO;
import com.bosskin.entity.*;
import com.bosskin.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EmployeeImportService {

    private final EmployeeRepository    employeeRepo;
    private final DepartmentRepository  deptRepo;
    private final PositionRepository    positionRepo;
    private final SalaryGradeRepository salaryGradeRepo;
    private final CompanyRepository     companyRepo;
    private final UserRepository        userRepo;
    private final RoleRepository        roleRepo;
    private final PasswordEncoder       passwordEncoder;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final String DEFAULT_PASSWORD = "Bosskin@123";

    // ─── PREVIEW ─────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<EmployeeDTO.ImportDiff> previewImport(Long companyId,
                                                      List<EmployeeDTO.ImportRow> rows) {
        Map<String, Employee> existing = employeeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(Employee::getEmployeeCode, e -> e));

        List<EmployeeDTO.ImportDiff> result = new ArrayList<>();

        for (EmployeeDTO.ImportRow row : rows) {
            if (isBlank(row.getFullName()) && isBlank(row.getEmployeeCode())) continue;

            String code = row.getEmployeeCode() == null ? null : row.getEmployeeCode().trim();
            String name = row.getFullName()     == null ? "" : row.getFullName().trim();
            String deptCode = row.getDepartmentCode() == null ? null
                : row.getDepartmentCode().trim().toUpperCase();

            Employee emp = code == null ? null : existing.get(code);

            if (emp == null) {
                // CREATE
                List<String> warnings = new ArrayList<>();
                if (isBlank(row.getEmail()))
                    warnings.add("Thiếu email — bắt buộc khi tạo mới");
                if (isBlank(row.getJoinDate()))
                    warnings.add("Thiếu ngày vào làm");
                result.add(EmployeeDTO.ImportDiff.builder()
                    .action("CREATE").employeeCode(code).fullName(name)
                    .email(row.getEmail()).departmentCode(deptCode)
                    .changes(List.of()).warnings(warnings).build());
            } else {
                // UPDATE / NO_CHANGE
                List<DepartmentDTO.FieldChange> changes = new ArrayList<>();
                addChange(changes, "Họ và tên",  emp.getFullName(),  name);
                addChange(changes, "Phòng ban",  emp.getDepartment().getCode(), deptCode);
                addChange(changes, "Chức vụ",   safeCode(emp.getPosition()),   row.getPositionCode());
                addChange(changes, "Bậc lương", safeCode(emp.getSalaryGrade()), row.getSalaryGradeCode());
                addChange(changes, "SĐT",        emp.getPhone(),                  row.getPhone());
                addChange(changes, "Trạng thái", normalizeStatus(str(emp.getStatus())), normalizeStatus(row.getStatus()));
                addChange(changes, "CCCD",       emp.getIdentityCard(), row.getIdentityCard());
                addChange(changes, "Địa chỉ",   emp.getAddress(),      row.getAddress());
                addChange(changes, "Tài khoản NH",emp.getBankAccount(), row.getBankAccount());
                addChange(changes, "Ngân hàng",  emp.getBankName(),     row.getBankName());
                addChangeMoney(changes, "Lương HĐ",
                    emp.getContractSalary() == null ? null : emp.getContractSalary().stripTrailingZeros().toPlainString(),
                    row.getContractSalary());

                result.add(EmployeeDTO.ImportDiff.builder()
                    .action(changes.isEmpty() ? "NO_CHANGE" : "UPDATE")
                    .employeeCode(code).fullName(name)
                    .email(emp.getEmail()).departmentCode(deptCode)
                    .changes(changes).warnings(List.of()).build());
            }
        }
        return result;
    }

    // ─── IMPORT ──────────────────────────────────────────────────────────────

    @Transactional
    public void importFromExcel(Long companyId, List<EmployeeDTO.ImportRow> rows) {
        Company company = companyRepo.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));

        Map<String, Employee>   existing   = employeeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(Employee::getEmployeeCode, e -> e));
        Map<String, Department> deptMap    = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d));
        Map<String, Position>   posMap     = positionRepo.findByDepartmentCompanyId(companyId)
            .stream().collect(Collectors.toMap(Position::getCode, p -> p));
        Map<String, SalaryGrade>gradeMap   = salaryGradeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(SalaryGrade::getCode, g -> g));

        Optional<Role> defaultRole = roleRepo.findByCompanyId(companyId).stream()
            .filter(r -> r.getName().equalsIgnoreCase("employee"))
            .findFirst();

        for (EmployeeDTO.ImportRow row : rows) {
            if (isBlank(row.getFullName()) && isBlank(row.getEmployeeCode())) continue;

            String code = row.getEmployeeCode() == null ? null : row.getEmployeeCode().trim();
            Employee emp = code == null ? null : existing.get(code);

            if (emp == null) {
                // ── CREATE ──────────────────────────────────────────────────
                if (isBlank(row.getEmail()))
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Nhân viên \"" + row.getFullName() + "\" thiếu email");

                String email = row.getEmail().trim();
                if (userRepo.existsByEmail(email) || employeeRepo.existsByEmailAndCompanyId(email, companyId))
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "Email \"" + email + "\" đã được sử dụng");

                Department dept = resolveDept(deptMap, row.getDepartmentCode(), code);
                Position   pos  = resolvePos(posMap, row.getPositionCode(), code);
                SalaryGrade grade = resolveGrade(gradeMap, row.getSalaryGradeCode());

                emp = Employee.builder()
                    .company(company)
                    .employeeCode(code != null ? code : generateCode(companyId))
                    .fullName(row.getFullName().trim())
                    .email(email)
                    .phone(row.getPhone())
                    .gender(parseGender(row.getGender()))
                    .dateOfBirth(parseDate(row.getDateOfBirth()))
                    .joinDate(parseDate(row.getJoinDate()) != null
                        ? parseDate(row.getJoinDate()) : LocalDate.now())
                    .leaveDate(parseDate(row.getLeaveDate()))
                    .department(dept)
                    .position(pos)
                    .salaryGrade(grade)
                    .address(row.getAddress())
                    .personalEmail(row.getPersonalEmail())
                    .identityCard(row.getIdentityCard())
                    .bankAccount(row.getBankAccount())
                    .bankName(row.getBankName())
                    .contractSalary(parseMoney(row.getContractSalary()))
                    .status(Employee.Status.ACTIVE)
                    .build();
                emp = employeeRepo.save(emp);

                // Tạo user account
                String pwd = isBlank(row.getDefaultPassword())
                    ? DEFAULT_PASSWORD : row.getDefaultPassword().trim();
                var user = com.bosskin.entity.User.builder()
                    .email(email).password(passwordEncoder.encode(pwd))
                    .company(company).employee(emp).enabled(true).build();
                defaultRole.ifPresent(r -> user.getRoles().add(r));
                userRepo.save(user);

            } else {
                // ── UPDATE ──────────────────────────────────────────────────
                if (!isBlank(row.getFullName()))    emp.setFullName(row.getFullName().trim());
                if (!isBlank(row.getPhone()))       emp.setPhone(row.getPhone().trim());
                if (!isBlank(row.getGender()))      emp.setGender(parseGender(row.getGender()));
                if (!isBlank(row.getDateOfBirth())) emp.setDateOfBirth(parseDate(row.getDateOfBirth()));
                if (!isBlank(row.getJoinDate()))    emp.setJoinDate(parseDate(row.getJoinDate()));
                if (!isBlank(row.getLeaveDate()))   emp.setLeaveDate(parseDate(row.getLeaveDate()));
                if (!isBlank(row.getAddress()))     emp.setAddress(row.getAddress().trim());
                if (!isBlank(row.getPersonalEmail()))emp.setPersonalEmail(row.getPersonalEmail().trim());
                if (!isBlank(row.getIdentityCard())) emp.setIdentityCard(row.getIdentityCard().trim());
                if (!isBlank(row.getBankAccount()))  emp.setBankAccount(row.getBankAccount().trim());
                if (!isBlank(row.getBankName()))     emp.setBankName(row.getBankName().trim());
                if (!isBlank(row.getContractSalary()))emp.setContractSalary(parseMoney(row.getContractSalary()));
                if (!isBlank(row.getStatus()))       emp.setStatus(parseStatus(row.getStatus()));

                if (!isBlank(row.getDepartmentCode())) {
                    emp.setDepartment(resolveDept(deptMap, row.getDepartmentCode(), code));
                }
                if (!isBlank(row.getPositionCode())) {
                    emp.setPosition(resolvePos(posMap, row.getPositionCode(), code));
                }
                if (!isBlank(row.getSalaryGradeCode())) {
                    emp.setSalaryGrade(resolveGrade(gradeMap, row.getSalaryGradeCode()));
                }
                employeeRepo.save(emp);
            }
        }
    }

    // ─── HELPERS ─────────────────────────────────────────────────────────────

    private Department resolveDept(Map<String, Department> map, String code, String rowCode) {
        if (isBlank(code)) return null;
        Department d = map.get(code.trim().toUpperCase());
        if (d == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Mã phòng ban \"" + code + "\" không tồn tại (nhân viên: " + rowCode + ")");
        return d;
    }

    private Position resolvePos(Map<String, Position> map, String code, String rowCode) {
        if (isBlank(code)) return null;
        Position p = map.get(code.trim().toUpperCase());
        if (p == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Mã chức vụ \"" + code + "\" không tồn tại (nhân viên: " + rowCode + ")");
        return p;
    }

    private SalaryGrade resolveGrade(Map<String, SalaryGrade> map, String code) {
        if (isBlank(code)) return null;
        return map.get(code.trim().toUpperCase());
    }

    private String generateCode(Long companyId) {
        long count = employeeRepo.countByCompanyId(companyId) + 1;
        return "EMP" + String.format("%04d", count);
    }

    private Employee.Gender parseGender(String v) {
        if (isBlank(v)) return Employee.Gender.MALE;
        return switch (v.trim().toLowerCase()) {
            case "nữ", "nu", "female" -> Employee.Gender.FEMALE;
            case "khác", "khac", "other" -> Employee.Gender.OTHER;
            default -> Employee.Gender.MALE;
        };
    }

    private Employee.Status parseStatus(String v) {
        if (isBlank(v)) return Employee.Status.ACTIVE;
        return switch (v.trim().toLowerCase()) {
            case "nghỉ việc", "nghi viec", "inactive" -> Employee.Status.INACTIVE;
            case "nghỉ phép", "nghi phep", "on_leave" -> Employee.Status.ON_LEAVE;
            default -> Employee.Status.ACTIVE;
        };
    }

    private LocalDate parseDate(String v) {
        if (isBlank(v)) return null;
        try { return LocalDate.parse(v.trim(), DATE_FMT); } catch (DateTimeParseException e) {
            try { return LocalDate.parse(v.trim()); } catch (DateTimeParseException e2) {
                return null;
            }
        }
    }

    private BigDecimal parseMoney(String v) {
        if (isBlank(v)) return null;
        try { return new BigDecimal(v.trim().replace(",", "").replace(".", "")); }
        catch (NumberFormatException e) { return null; }
    }

    /** So sánh tiền — normalize về BigDecimal để tránh "10000000" vs "10000000.00". */
    private void addChangeMoney(List<DepartmentDTO.FieldChange> list, String field,
                                String oldVal, String newVal) {
        if (newVal == null || newVal.isBlank()) return;
        try {
            java.math.BigDecimal o = oldVal == null || oldVal.isBlank()
                ? java.math.BigDecimal.ZERO
                : new java.math.BigDecimal(oldVal.trim().replace(",", ""));
            java.math.BigDecimal n = new java.math.BigDecimal(newVal.trim().replace(",", ""));
            if (o.compareTo(n) != 0)
                list.add(DepartmentDTO.FieldChange.builder()
                    .field(field)
                    .oldValue(oldVal == null ? "" : oldVal.trim())
                    .newValue(n.stripTrailingZeros().toPlainString())
                    .build());
        } catch (NumberFormatException ignored) {}
    }

    private void addChange(List<DepartmentDTO.FieldChange> list, String field,
                           String oldVal, String newVal) {
        String o = oldVal == null ? "" : oldVal.trim();
        String n = newVal == null ? "" : newVal.trim();
        // Bỏ qua khi cả hai đều rỗng, hoặc khi newValue rỗng (file không điền = không muốn thay đổi)
        if (n.isEmpty()) return;
        if (!o.equals(n))
            list.add(DepartmentDTO.FieldChange.builder().field(field).oldValue(o).newValue(n).build());
    }

    private String str(Object v) { return v == null ? "" : v.toString(); }
    private boolean isBlank(String v) { return v == null || v.isBlank(); }

    /** Lấy code từ entity có lazy proxy — trả "" nếu đã bị soft-delete. */
    /** Chuẩn hóa trạng thái về ACTIVE/INACTIVE/ON_LEAVE để so sánh nhất quán. */
    private static String normalizeStatus(String v) {
        if (v == null || v.isBlank()) return "";
        return switch (v.trim().toLowerCase()) {
            case "active",   "đang làm",  "dang lam"  -> "ACTIVE";
            case "inactive", "nghỉ việc", "nghi viec" -> "INACTIVE";
            case "on_leave", "nghỉ phép", "nghi phep" -> "ON_LEAVE";
            default -> v.trim().toUpperCase();
        };
    }

    private static String safeCode(com.bosskin.entity.Position p) {
        try { return p == null ? "" : p.getCode(); } catch (Exception e) { return ""; }
    }

    private static String safeCode(com.bosskin.entity.SalaryGrade g) {
        try { return g == null ? "" : g.getCode(); } catch (Exception e) { return ""; }
    }
}
