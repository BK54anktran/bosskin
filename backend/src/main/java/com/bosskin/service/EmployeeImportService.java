package com.bosskin.service;

import com.bosskin.core.SensitiveData;
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
    private final DeptScopeService      deptScopeService;
    private final JobHistoryService     jobHistoryService;
    private final com.bosskin.repository.LaborContractRepository laborContractRepo;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final String DEFAULT_PASSWORD = "Bosskin@123";

    /** Mật khẩu ban đầu của dòng import: rỗng → mặc định; tự đặt thì phải đạt chính sách. */
    private static String importPassword(EmployeeDTO.ImportRow row) {
        if (row.getDefaultPassword() == null || row.getDefaultPassword().isBlank()) return DEFAULT_PASSWORD;
        String pwd = row.getDefaultPassword().trim();
        if (!com.bosskin.core.PasswordPolicy.isStrong(pwd))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.import.weak_password|" + (row.getFullName() == null ? "" : row.getFullName()));
        return pwd;
    }

    // ─── LOAD FOR EXPORT ─────────────────────────────────────────────────────

    private static final java.time.format.DateTimeFormatter DATE_EXPORT_FMT =
        java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy");

    @Transactional(readOnly = true)
    public List<EmployeeDTO.ImportRow> loadAllForExport(Long companyId, Long userId) {
        return loadAllForExport(companyId, userId, Map.of());
    }

    @Transactional(readOnly = true)
    public List<EmployeeDTO.ImportRow> loadAllForExport(Long companyId, Long userId,
                                                         Map<String, String> filters) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");

        // Filter: departmentCodes (comma-separated, multi-select từ UI)
        String deptCodesRaw = filters.getOrDefault("departmentCodes",
            filters.getOrDefault("departmentCode", ""));
        if (!deptCodesRaw.isBlank()) {
            Set<Long> pickedIds = Arrays.stream(deptCodesRaw.split(","))
                .map(String::trim).filter(c -> !c.isEmpty())
                .map(code -> deptRepo.findByCodeAndCompanyId(code, companyId))
                .filter(Optional::isPresent).map(opt -> opt.get().getId())
                .collect(Collectors.toSet());
            if (pickedIds.isEmpty()) return List.of();
            final Set<Long> scope = scopeIds;
            scopeIds = scope.isEmpty() ? pickedIds
                : pickedIds.stream().filter(scope::contains).collect(Collectors.toSet());
            if (scopeIds.isEmpty()) return List.of();
        }

        List<com.bosskin.entity.Employee> employees = scopeIds.isEmpty()
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            : employeeRepo.findAllByCompanyIdAndDepartmentIdInFetchDepartment(companyId, scopeIds);

        // Filter: search (comma-separated employee codes từ pick)
        String searchRaw = filters.getOrDefault("search", "").trim();
        if (!searchRaw.isBlank()) {
            Set<String> codes = Arrays.stream(searchRaw.split(","))
                .map(String::trim).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
            employees = employees.stream()
                .filter(e -> e.getEmployeeCode() != null && codes.contains(e.getEmployeeCode()))
                .collect(Collectors.toList());
        }

        // Filter: status
        String statusFilter = filters.getOrDefault("status", "");
        if (!statusFilter.isBlank() && !statusFilter.equals("ALL")) {
            employees = employees.stream()
                .filter(e -> e.getStatus() != null && e.getStatus().name().equals(statusFilter))
                .collect(Collectors.toList());
        }

        // Filter: salaryGradeCode
        String gradeFilter = filters.getOrDefault("salaryGradeCode", "");
        if (!gradeFilter.isBlank()) {
            employees = employees.stream()
                .filter(e -> e.getSalaryGrade() != null && gradeFilter.equals(e.getSalaryGrade().getCode()))
                .collect(Collectors.toList());
        }

        // Filter: joinDateFrom / joinDateTo
        String joinFrom = filters.getOrDefault("joinDateFrom", "");
        String joinTo   = filters.getOrDefault("joinDateTo", "");
        if (!joinFrom.isBlank()) {
            LocalDate from = LocalDate.parse(joinFrom);
            employees = employees.stream()
                .filter(e -> e.getJoinDate() != null && !e.getJoinDate().isBefore(from))
                .collect(Collectors.toList());
        }
        if (!joinTo.isBlank()) {
            LocalDate to = LocalDate.parse(joinTo);
            employees = employees.stream()
                .filter(e -> e.getJoinDate() != null && !e.getJoinDate().isAfter(to))
                .collect(Collectors.toList());
        }

        return employees.stream().map(e -> {
            EmployeeDTO.ImportRow r = new EmployeeDTO.ImportRow();
            r.setEmployeeCode(e.getEmployeeCode());
            r.setFullName(e.getFullName());
            r.setEmail(e.getEmail());
            r.setPhone(e.getPhone());
            r.setGender(e.getGender() != null ? e.getGender().name() : "");
            r.setDateOfBirth(e.getDateOfBirth() != null ? e.getDateOfBirth().format(DATE_EXPORT_FMT) : "");
            r.setJoinDate(e.getJoinDate() != null ? e.getJoinDate().format(DATE_EXPORT_FMT) : "");
            r.setLeaveDate(e.getLeaveDate() != null ? e.getLeaveDate().format(DATE_EXPORT_FMT) : "");
            r.setDepartmentCode(e.getDepartment() != null ? e.getDepartment().getCode() : "");
            r.setDepartmentName(e.getDepartment() != null ? e.getDepartment().getName() : "");
            r.setPositionCode(safeCode(e.getPosition()));
            r.setPositionName(safeName(e.getPosition()));
            r.setSalaryGradeCode(e.getSalaryGrade() != null ? e.getSalaryGrade().getCode() : "");
            r.setStatus(e.getStatus() != null ? e.getStatus().name() : "");
            r.setIdentityCard(SensitiveData.forViewer(e.getIdentityCard()));
            r.setAddress(e.getAddress());
            r.setPersonalEmail(e.getPersonalEmail());
            r.setBankAccount(SensitiveData.forViewer(e.getBankAccount()));
            r.setTaxCode(SensitiveData.forViewer(e.getTaxCode()));
            r.setSocialInsuranceNo(SensitiveData.forViewer(e.getSocialInsuranceNo()));
            r.setHealthInsurancePlace(e.getHealthInsurancePlace());
            r.setInsuranceJoinDate(e.getInsuranceJoinDate() != null ? e.getInsuranceJoinDate().format(DATE_EXPORT_FMT) : "");
            r.setBankName(e.getBankName());
            r.setContractSalary(e.getContractSalary() != null
                ? e.getContractSalary().stripTrailingZeros().toPlainString() : "");
            return r;
        }).collect(java.util.stream.Collectors.toList());
    }

    // ─── PREVIEW ─────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<EmployeeDTO.ImportDiff> previewImport(Long companyId, Long userId,
                                                      List<EmployeeDTO.ImportRow> rows) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        Map<String, Department> deptByCode = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d));
        Map<String, Employee> existing = employeeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(Employee::getEmployeeCode, e -> e));

        List<EmployeeDTO.ImportDiff> result = new ArrayList<>();

        for (EmployeeDTO.ImportRow row : rows) {
            if (isBlank(row.getFullName()) && isBlank(row.getEmployeeCode())) continue;

            String code = row.getEmployeeCode() == null ? null : row.getEmployeeCode().trim();
            String name = row.getFullName()     == null ? "" : row.getFullName().trim();
            String deptCode = row.getDepartmentCode() == null ? null
                : row.getDepartmentCode().trim().toUpperCase();

            // Scope check: bỏ qua row thuộc dept ngoài phạm vi
            if (!scopeIds.isEmpty() && deptCode != null) {
                Department dept = deptByCode.get(deptCode);
                if (dept == null || !scopeIds.contains(dept.getId())) continue;
            }

            Employee emp = code == null ? null : existing.get(code);
            if (emp != null) unmask(emp, row);

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
                addChange(changes, "excel.col.employee.taxCode",           emp.getTaxCode(),           row.getTaxCode());
                addChange(changes, "excel.col.employee.socialInsuranceNo", emp.getSocialInsuranceNo(), row.getSocialInsuranceNo());
                addChange(changes, "excel.col.employee.healthInsurancePlace", emp.getHealthInsurancePlace(), row.getHealthInsurancePlace());
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
    @SuppressWarnings("null")
    public void importFromExcel(Long companyId, Long userId, List<EmployeeDTO.ImportRow> rows) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        Company company = companyRepo.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));

        Map<String, Employee>   existing   = employeeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(Employee::getEmployeeCode, e -> e));
        Map<String, Department> deptMap    = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(d -> d.getCode().toUpperCase(), d -> d));
        Map<String, Position>   posMap     = positionRepo.findByDepartmentCompanyId(companyId)
            .stream().collect(Collectors.toMap(p -> p.getCode().toUpperCase(), p -> p));
        Map<String, SalaryGrade>gradeMap   = salaryGradeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(g -> g.getCode().toUpperCase(), g -> g));

        Optional<Role> defaultRole = roleRepo.findFirstByCompanyIdAndIsDefaultTrue(companyId);

        List<Employee> toUpdate = new ArrayList<>();
        List<com.bosskin.entity.User> toCreateUsers = new ArrayList<>();
        Map<Employee, JobHistoryService.Snapshot> beforeMap = new LinkedHashMap<>();

        for (EmployeeDTO.ImportRow row : rows) {
            if (isBlank(row.getFullName()) && isBlank(row.getEmployeeCode())) continue;

            // Scope check
            if (!scopeIds.isEmpty() && row.getDepartmentCode() != null) {
                Department dept = deptMap.get(row.getDepartmentCode().trim().toUpperCase());
                if (dept == null || !scopeIds.contains(dept.getId())) continue;
            }

            String code = row.getEmployeeCode() == null ? null : row.getEmployeeCode().trim();
            Employee emp = code == null ? null : existing.get(code);
            if (emp != null) unmask(emp, row);

            if (emp == null) {
                // ── CREATE — cần save ngay để lấy ID gắn vào User ───────────
                if (isBlank(row.getEmail()))
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "error.import.email_missing|" + row.getFullName());

                String email = row.getEmail().trim();
                if (userRepo.existsByEmail(email) || employeeRepo.existsByEmailAndCompanyId(email, companyId))
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "error.import.email_in_use|" + email);

                Department dept = resolveDept(deptMap, row.getDepartmentCode(), code);
                Position   pos  = resolvePos(posMap, row.getPositionCode(), code);
                SalaryGrade grade = resolveGrade(gradeMap, row.getSalaryGradeCode());

                Employee newEmp = Employee.builder()
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
                    .department(dept).position(pos).salaryGrade(grade)
                    .address(row.getAddress())
                    .personalEmail(row.getPersonalEmail())
                    .identityCard(row.getIdentityCard())
                    .bankAccount(row.getBankAccount())
                    .bankName(row.getBankName())
                    .taxCode(trimOrNull(row.getTaxCode()))
                    .socialInsuranceNo(trimOrNull(row.getSocialInsuranceNo()))
                    .healthInsurancePlace(trimOrNull(row.getHealthInsurancePlace()))
                    .insuranceJoinDate(parseDate(row.getInsuranceJoinDate()))
                    .contractSalary(parseMoney(row.getContractSalary()))
                    .status(Employee.Status.ACTIVE)
                    .build();
                Employee savedEmp = employeeRepo.save(newEmp);
                jobHistoryService.recordHire(savedEmp, userId);

                String pwd = importPassword(row);
                var user = com.bosskin.entity.User.builder()
                    .email(email).password(passwordEncoder.encode(pwd)).mustChangePassword(true)
                    .company(company).employee(savedEmp).enabled(true).build();
                defaultRole.ifPresent(r -> user.getRoles().add(r));
                toCreateUsers.add(user);

            } else {
                // ── UPDATE — collect, batch save sau ────────────────────────
                beforeMap.put(emp, JobHistoryService.Snapshot.of(emp));
                if (!isBlank(row.getFullName()))     emp.setFullName(row.getFullName().trim());
                if (!isBlank(row.getPhone()))        emp.setPhone(row.getPhone().trim());
                if (!isBlank(row.getGender()))       emp.setGender(parseGender(row.getGender()));
                if (!isBlank(row.getDateOfBirth()))  emp.setDateOfBirth(parseDate(row.getDateOfBirth()));
                if (!isBlank(row.getJoinDate()))     emp.setJoinDate(parseDate(row.getJoinDate()));
                if (!isBlank(row.getLeaveDate()))    emp.setLeaveDate(parseDate(row.getLeaveDate()));
                if (!isBlank(row.getAddress()))      emp.setAddress(row.getAddress().trim());
                if (!isBlank(row.getPersonalEmail()))emp.setPersonalEmail(row.getPersonalEmail().trim());
                if (!isBlank(row.getIdentityCard())) emp.setIdentityCard(row.getIdentityCard().trim());
                if (!isBlank(row.getBankAccount()))  emp.setBankAccount(row.getBankAccount().trim());
                if (!isBlank(row.getBankName()))     emp.setBankName(row.getBankName().trim());
                if (!isBlank(row.getTaxCode()))      emp.setTaxCode(row.getTaxCode().trim());
                if (!isBlank(row.getSocialInsuranceNo())) emp.setSocialInsuranceNo(row.getSocialInsuranceNo().trim());
                if (!isBlank(row.getHealthInsurancePlace())) emp.setHealthInsurancePlace(row.getHealthInsurancePlace().trim());
                if (!isBlank(row.getInsuranceJoinDate())) emp.setInsuranceJoinDate(parseDate(row.getInsuranceJoinDate()));
                // Bước L: lương HĐ của NV đã có hợp đồng do hợp đồng quản lý — bỏ qua cột này
                if (!isBlank(row.getContractSalary()) && !laborContractRepo.managesSalary(emp.getId()))
                    emp.setContractSalary(parseMoney(row.getContractSalary()));
                if (!isBlank(row.getStatus()))       emp.setStatus(parseStatus(row.getStatus()));
                if (!isBlank(row.getDepartmentCode()))
                    emp.setDepartment(resolveDept(deptMap, row.getDepartmentCode(), code));
                if (!isBlank(row.getPositionCode()))
                    emp.setPosition(resolvePos(posMap, row.getPositionCode(), code));
                if (!isBlank(row.getSalaryGradeCode()))
                    emp.setSalaryGrade(resolveGrade(gradeMap, row.getSalaryGradeCode()));
                toUpdate.add(emp);
            }
        }

        employeeRepo.saveAll(toUpdate);
        userRepo.saveAll(toCreateUsers);
        beforeMap.forEach((e, before) -> jobHistoryService.recordIfChanged(e, before, userId));
    }

    // ─── PER-ROW IMPORT / PREVIEW ────────────────────────────────────────────

    /** Preview 1 row — không ghi DB. Trả về RowResult với rowNum = 0 (caller tự set). */
    @Transactional(readOnly = true)
    public com.bosskin.util.SheetImportResult.RowResult previewRow(
            Long companyId, Long userId,
            EmployeeDTO.ImportRow row,
            com.bosskin.util.ImportCommand command) {

        String code = row.getEmployeeCode() == null ? null : row.getEmployeeCode().trim();
        Employee emp = code == null ? null
            : employeeRepo.findByEmployeeCodeAndCompanyId(code, companyId).orElse(null);
        if (emp != null) unmask(emp, row);
        boolean exists = emp != null;

        // Enrich departmentName cho identifier display
        if (exists && emp.getDepartment() != null) {
            row.setDepartmentName(emp.getDepartment().getName());
        } else if (!isBlank(row.getDepartmentCode())) {
            deptRepo.findByCodeAndCompanyId(row.getDepartmentCode().trim().toUpperCase(), companyId)
                .ifPresent(d -> row.setDepartmentName(d.getName()));
        }

        // Bước E: dòng sẽ tạo mới — báo trước các lỗi doCreate sẽ gặp (thiếu / trùng email, phòng ban chưa có)
        if (!exists && (command == com.bosskin.util.ImportCommand.CREATE || command == com.bosskin.util.ImportCommand.MERGE)) {
            String problem = createProblem(companyId, code, row);
            if (problem != null) return com.bosskin.util.SheetImportResult.RowResult.error(0, problem);
        }

        return switch (command) {
            case CREATE -> exists
                ? com.bosskin.util.SheetImportResult.RowResult.warn(0, "warning.employee.already_exists")
                : com.bosskin.util.SheetImportResult.RowResult.of(0, "OK", buildCreateSummary(row));
            case UPDATE -> !exists
                ? com.bosskin.util.SheetImportResult.RowResult.error(0, "error.employee.not_found")
                : com.bosskin.util.SheetImportResult.RowResult.of(0, "OK", buildChangeSummary(emp, row));
            case MERGE  -> exists
                ? com.bosskin.util.SheetImportResult.RowResult.of(0, "OK", buildChangeSummary(emp, row))
                : com.bosskin.util.SheetImportResult.RowResult.of(0, "OK", buildCreateSummary(row));
            case DELETE -> !exists
                ? com.bosskin.util.SheetImportResult.RowResult.error(0, "error.employee.not_found")
                : com.bosskin.util.SheetImportResult.RowResult.of(0, "OK", "preview.delete:" + emp.getFullName());
        };
    }

    private String createProblem(Long companyId, String code, EmployeeDTO.ImportRow row) {
        if (isBlank(row.getEmail())) return "error.import.email_missing|" + row.getFullName();
        String email = row.getEmail().trim();
        if (userRepo.existsByEmail(email) || employeeRepo.existsByEmailAndCompanyId(email, companyId))
            return "error.import.email_in_use|" + email;
        if (!isBlank(row.getDepartmentCode())
                && deptRepo.findByCodeAndCompanyId(row.getDepartmentCode().trim().toUpperCase(), companyId).isEmpty())
            return "error.import.department_missing|" + row.getDepartmentCode() + "|" + code;
        return null;
    }

    private String buildCreateSummary(EmployeeDTO.ImportRow row) {
        List<String> parts = new ArrayList<>();
        if (!isBlank(row.getFullName())) parts.add(row.getFullName().trim());
        String dept = !isBlank(row.getDepartmentName()) ? row.getDepartmentName().trim()
                    : !isBlank(row.getDepartmentCode()) ? row.getDepartmentCode().trim() : "";
        if (!dept.isEmpty()) parts.add(dept);
        if (!isBlank(row.getEmail())) parts.add(row.getEmail().trim());
        return "preview.create:" + String.join("|", parts);
    }

    private String buildChangeSummary(Employee emp, EmployeeDTO.ImportRow row) {
        List<String> changes = new ArrayList<>();
        diffStr(changes, "excel.col.employee.fullName",      emp.getFullName(),     row.getFullName());
        diffStr(changes, "excel.col.employee.email",         emp.getEmail(),        row.getEmail());
        diffStr(changes, "excel.col.employee.phone",         emp.getPhone(),        row.getPhone());
        diffStr(changes, "excel.col.employee.gender",        str(emp.getGender()),  row.getGender());
        diffDate(changes, "excel.col.employee.dateOfBirth",  emp.getDateOfBirth(),  row.getDateOfBirth());
        diffDate(changes, "excel.col.employee.joinDate",     emp.getJoinDate(),     row.getJoinDate());
        diffDate(changes, "excel.col.employee.leaveDate",    emp.getLeaveDate(),    row.getLeaveDate());
        if (!isBlank(row.getStatus()) && !normalizeStatus(row.getStatus()).equals(normalizeStatus(str(emp.getStatus()))))
            changes.add("excel.col.employee.status:" + normalizeStatus(str(emp.getStatus())) + "→" + normalizeStatus(row.getStatus()));
        if (!isBlank(row.getDepartmentCode())) {
            String empCode = emp.getDepartment() != null ? emp.getDepartment().getCode() : "";
            if (!row.getDepartmentCode().trim().equalsIgnoreCase(empCode))
                changes.add("excel.col.employee.departmentCode:" + empCode + "→" + row.getDepartmentCode().trim());
        }
        if (!isBlank(row.getPositionCode())) {
            String empCode = safeCode(emp.getPosition());
            if (!row.getPositionCode().trim().equalsIgnoreCase(empCode))
                changes.add("excel.col.employee.positionCode:" + empCode + "→" + row.getPositionCode().trim());
        }
        if (!isBlank(row.getSalaryGradeCode())) {
            String empCode = emp.getSalaryGrade() != null ? emp.getSalaryGrade().getCode() : "";
            if (!row.getSalaryGradeCode().trim().equalsIgnoreCase(empCode))
                changes.add("excel.col.employee.salaryGradeCode:" + empCode + "→" + row.getSalaryGradeCode().trim());
        }
        if (!isBlank(row.getContractSalary()) && !laborContractRepo.managesSalary(emp.getId())) {
            BigDecimal newVal = parseMoney(row.getContractSalary());
            if (newVal != null && (emp.getContractSalary() == null
                    || emp.getContractSalary().compareTo(newVal) != 0))
                changes.add("excel.col.employee.contractSalary:" + newVal.stripTrailingZeros().toPlainString());
        }
        diffStr(changes, "excel.col.employee.identityCard",  emp.getIdentityCard(),  row.getIdentityCard());
        diffStr(changes, "excel.col.employee.address",       emp.getAddress(),       row.getAddress());
        diffStr(changes, "excel.col.employee.personalEmail", emp.getPersonalEmail(), row.getPersonalEmail());
        diffStr(changes, "excel.col.employee.bankAccount",   emp.getBankAccount(),   row.getBankAccount());
        diffStr(changes, "excel.col.employee.bankName",      emp.getBankName(),      row.getBankName());
        diffStr(changes, "excel.col.employee.taxCode",           emp.getTaxCode(),           row.getTaxCode());
        diffStr(changes, "excel.col.employee.socialInsuranceNo", emp.getSocialInsuranceNo(), row.getSocialInsuranceNo());
        diffStr(changes, "excel.col.employee.healthInsurancePlace", emp.getHealthInsurancePlace(), row.getHealthInsurancePlace());
        diffDate(changes, "excel.col.employee.insuranceJoinDate", emp.getInsuranceJoinDate(), row.getInsuranceJoinDate());
        return changes.isEmpty() ? "preview.noChange" : String.join(",", changes);
    }

    private void diffStr(List<String> out, String key, String empVal, String rowVal) {
        if (isBlank(rowVal)) return;
        String o = empVal == null ? "" : empVal.trim();
        String n = rowVal.trim();
        if (!n.equals(o)) out.add(key + ":" + o + "→" + n);
    }

    private void diffDate(List<String> out, String key, LocalDate empVal, String rowVal) {
        if (isBlank(rowVal)) return;
        LocalDate newDate = parseDate(rowVal);
        if (newDate != null && !newDate.equals(empVal))
            out.add(key + ":" + (empVal != null ? empVal.format(DATE_FMT) : "") + "→" + newDate.format(DATE_FMT));
    }

    /** Thực hiện import 1 row theo command. Trả về false nếu bị skip (CREATE đã tồn tại). */
    @Transactional
    public boolean importRow(Long companyId, Long userId,
                          EmployeeDTO.ImportRow row,
                          com.bosskin.util.ImportCommand command,
                          Set<String> presentColumns) {

        Company company = companyRepo.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));

        Map<String, Department> deptMap  = deptRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(d -> d.getCode().toUpperCase(), d -> d));
        Map<String, Position>   posMap   = positionRepo.findByDepartmentCompanyId(companyId)
            .stream().collect(Collectors.toMap(p -> p.getCode().toUpperCase(), p -> p));
        Map<String, SalaryGrade> gradeMap = salaryGradeRepo.findByCompanyId(companyId)
            .stream().collect(Collectors.toMap(g -> g.getCode().toUpperCase(), g -> g));

        String code = row.getEmployeeCode() == null ? null : row.getEmployeeCode().trim();
        Employee emp = code == null ? null
            : employeeRepo.findByEmployeeCodeAndCompanyId(code, companyId).orElse(null);
        if (emp != null) unmask(emp, row);

        switch (command) {
            case CREATE -> {
                if (emp != null) return false; // đã tồn tại → skip
                doCreate(row, code, company, deptMap, posMap, gradeMap, userId);
            }
            case UPDATE -> {
                if (emp == null)
                    throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found");
                doUpdate(emp, row, presentColumns, deptMap, posMap, gradeMap, userId);
            }
            case MERGE -> {
                if (emp == null) doCreate(row, code, company, deptMap, posMap, gradeMap, userId);
                else             doUpdate(emp, row, presentColumns, deptMap, posMap, gradeMap, userId);
            }
            case DELETE -> {
                if (emp == null)
                    throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found");
                employeeRepo.delete(emp);
            }
        }
        return true;
    }

    private void doCreate(EmployeeDTO.ImportRow row, String code, Company company,
                          Map<String, Department> deptMap,
                          Map<String, Position> posMap,
                          Map<String, SalaryGrade> gradeMap, Long userId) {
        if (isBlank(row.getEmail()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.import.email_missing|" + row.getFullName());
        String email = row.getEmail().trim();
        if (userRepo.existsByEmail(email) || employeeRepo.existsByEmailAndCompanyId(email, company.getId()))
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "error.import.email_in_use|" + email);

        Employee emp = Employee.builder()
            .company(company)
            .employeeCode(isBlank(code) ? generateCode(company.getId()) : code)
            .fullName(row.getFullName().trim())
            .email(email)
            .phone(row.getPhone())
            .gender(parseGender(row.getGender()))
            .dateOfBirth(parseDate(row.getDateOfBirth()))
            .joinDate(parseDate(row.getJoinDate()) != null ? parseDate(row.getJoinDate()) : LocalDate.now())
            .leaveDate(parseDate(row.getLeaveDate()))
            .department(resolveDept(deptMap, row.getDepartmentCode(), code))
            .position(resolvePos(posMap, row.getPositionCode(), code))
            .salaryGrade(resolveGrade(gradeMap, row.getSalaryGradeCode()))
            .address(row.getAddress())
            .personalEmail(row.getPersonalEmail())
            .identityCard(row.getIdentityCard())
            .bankAccount(row.getBankAccount())
            .bankName(row.getBankName())
            .taxCode(trimOrNull(row.getTaxCode()))
            .socialInsuranceNo(trimOrNull(row.getSocialInsuranceNo()))
            .healthInsurancePlace(trimOrNull(row.getHealthInsurancePlace()))
            .insuranceJoinDate(parseDate(row.getInsuranceJoinDate()))
            .contractSalary(parseMoney(row.getContractSalary()))
            .status(Employee.Status.ACTIVE)
            .build();
        emp = employeeRepo.save(emp);
        jobHistoryService.recordHire(emp, userId);

        Optional<Role> defaultRole = roleRepo.findFirstByCompanyIdAndIsDefaultTrue(company.getId());
        String pwd = importPassword(row);
        var user = com.bosskin.entity.User.builder()
            .email(email).password(passwordEncoder.encode(pwd)).mustChangePassword(true)
            .company(company).employee(emp).enabled(true).build();
        defaultRole.ifPresent(r -> user.getRoles().add(r));
        userRepo.save(user);
    }

    private void doUpdate(Employee emp, EmployeeDTO.ImportRow row,
                          Set<String> presentColumns,
                          Map<String, Department> deptMap,
                          Map<String, Position> posMap,
                          Map<String, SalaryGrade> gradeMap, Long userId) {
        JobHistoryService.Snapshot before = JobHistoryService.Snapshot.of(emp);
        // Chỉ update field nào có cột trong file (present).
        // Nếu present + trống → set null (user chủ ý xóa).
        // Nếu không present → giữ nguyên.
        if (presentColumns.contains("employee.fullName") && !isBlank(row.getFullName()))
            emp.setFullName(row.getFullName().trim());
        if (presentColumns.contains("employee.phone"))
            emp.setPhone(isBlank(row.getPhone()) ? null : row.getPhone().trim());
        // Cột gender NOT NULL: ô trống = giữ nguyên (trước đây set null → lỗi SQL khi nhập lại file thiếu giới tính)
        if (presentColumns.contains("employee.gender") && !isBlank(row.getGender()))
            emp.setGender(parseGender(row.getGender()));
        if (presentColumns.contains("employee.dateOfBirth"))
            emp.setDateOfBirth(parseDate(row.getDateOfBirth()));
        if (presentColumns.contains("employee.joinDate") && !isBlank(row.getJoinDate()))
            emp.setJoinDate(parseDate(row.getJoinDate()));
        if (presentColumns.contains("employee.leaveDate"))
            emp.setLeaveDate(parseDate(row.getLeaveDate()));
        if (presentColumns.contains("employee.status") && !isBlank(row.getStatus()))
            emp.setStatus(parseStatus(row.getStatus()));
        if (presentColumns.contains("employee.address"))
            emp.setAddress(isBlank(row.getAddress()) ? null : row.getAddress().trim());
        if (presentColumns.contains("employee.personalEmail"))
            emp.setPersonalEmail(isBlank(row.getPersonalEmail()) ? null : row.getPersonalEmail().trim());
        if (presentColumns.contains("employee.identityCard"))
            emp.setIdentityCard(isBlank(row.getIdentityCard()) ? null : row.getIdentityCard().trim());
        if (presentColumns.contains("employee.bankAccount"))
            emp.setBankAccount(isBlank(row.getBankAccount()) ? null : row.getBankAccount().trim());
        if (presentColumns.contains("employee.bankName"))
            emp.setBankName(isBlank(row.getBankName()) ? null : row.getBankName().trim());
        if (presentColumns.contains("employee.taxCode"))
            emp.setTaxCode(trimOrNull(row.getTaxCode()));
        if (presentColumns.contains("employee.socialInsuranceNo"))
            emp.setSocialInsuranceNo(trimOrNull(row.getSocialInsuranceNo()));
        if (presentColumns.contains("employee.healthInsurancePlace"))
            emp.setHealthInsurancePlace(trimOrNull(row.getHealthInsurancePlace()));
        if (presentColumns.contains("employee.insuranceJoinDate"))
            emp.setInsuranceJoinDate(parseDate(row.getInsuranceJoinDate()));
        if (presentColumns.contains("employee.contractSalary") && !laborContractRepo.managesSalary(emp.getId()))
            emp.setContractSalary(isBlank(row.getContractSalary()) ? null : parseMoney(row.getContractSalary()));
        if (presentColumns.contains("employee.departmentCode") && !isBlank(row.getDepartmentCode()))
            emp.setDepartment(resolveDept(deptMap, row.getDepartmentCode(), emp.getEmployeeCode()));
        if (presentColumns.contains("employee.positionCode"))
            emp.setPosition(isBlank(row.getPositionCode()) ? null : resolvePos(posMap, row.getPositionCode(), emp.getEmployeeCode()));
        if (presentColumns.contains("employee.salaryGradeCode") && !isBlank(row.getSalaryGradeCode()))
            emp.setSalaryGrade(resolveGrade(gradeMap, row.getSalaryGradeCode()));
        employeeRepo.save(emp);
        jobHistoryService.recordIfChanged(emp, before, userId);
    }

    // ─── HELPERS ─────────────────────────────────────────────────────────────

    private Department resolveDept(Map<String, Department> map, String code, String rowCode) {
        if (isBlank(code)) return null;
        Department d = map.get(code.trim().toUpperCase());
        if (d == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "error.import.department_missing|" + code + "|" + rowCode);
        return d;
    }

    private Position resolvePos(Map<String, Position> map, String code, String rowCode) {
        if (isBlank(code)) return null;
        Position p = map.get(code.trim().toUpperCase());
        if (p == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "error.import.position_missing|" + code + "|" + rowCode);
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
        // Strip thousand separators (. or ,) then parse — Vietnamese salaries are integer amounts
        try { return new BigDecimal(v.trim().replaceAll("[^0-9]", "")); }
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

    private static String trimOrNull(String v) { return v == null || v.isBlank() ? null : v.trim(); }

    /** Bước M: người không có quyền xem đủ xuất file đã che → ô còn nguyên bản che coi như không đổi. */
    private static void unmask(Employee emp, EmployeeDTO.ImportRow row) {
        row.setIdentityCard(SensitiveData.incoming(emp.getIdentityCard(), row.getIdentityCard()));
        row.setBankAccount(SensitiveData.incoming(emp.getBankAccount(), row.getBankAccount()));
        row.setTaxCode(SensitiveData.incoming(emp.getTaxCode(), row.getTaxCode()));
        row.setSocialInsuranceNo(SensitiveData.incoming(emp.getSocialInsuranceNo(), row.getSocialInsuranceNo()));
    }
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

    private static String safeName(com.bosskin.entity.Position p) {
        try { return p == null ? "" : p.getName(); } catch (Exception e) { return ""; }
    }

    private static String safeCode(com.bosskin.entity.SalaryGrade g) {
        try { return g == null ? "" : g.getCode(); } catch (Exception e) { return ""; }
    }
}
