package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.core.PayrollPeriod;
import com.bosskin.dto.ContractDTO;
import com.bosskin.dto.DepartmentDTO;
import com.bosskin.entity.*;
import com.bosskin.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Bước L — hợp đồng lao động, phụ lục, phụ cấp; lương theo hợp đồng hiệu lực trong kỳ; cảnh báo sắp hết hạn.
 * <p>
 * Điều khoản hiệu lực ở ngày d = hợp đồng không nháp phủ d, áp lần lượt các phụ lục có effectiveFrom ≤ d
 * (trường null giữ giá trị trước, overridesAllowances thay cả bộ phụ cấp). {@code employees.contract_salary}
 * được đồng bộ theo lương hiệu lực hôm nay để các màn cũ hiển thị đúng, và chỉ còn là dự phòng cho nhân viên
 * chưa có hợp đồng.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ContractService {

    /** Hợp đồng xác định thời hạn tối đa 36 tháng (BLLĐ 2019 điều 20). */
    public static final int FIXED_TERM_MAX_MONTHS = 36;
    private static final Pattern ALLOWANCE_CODE = Pattern.compile("[A-Z0-9_]{1,30}");
    /** ALLOWANCE_MANUAL là khoản chỉnh tay trên bảng lương nháp. */
    private static final Set<String> RESERVED_ALLOWANCE_CODES = Set.of("MANUAL");

    private final LaborContractRepository repository;
    private final ContractAppendixRepository appendixRepository;
    private final ContractAllowanceRepository allowanceRepository;
    private final EmployeeRepository employeeRepository;
    private final CompanyRepository companyRepository;
    private final UserRepository userRepository;
    private final DeptScopeService deptScopeService;
    private final FcmService fcmService;
    private final AuditService audit;
    private final Clock clock;

    private LocalDate today() {
        return LocalDate.now(clock);
    }

    // ── Đọc ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ContractDTO.Response> list(Long companyId, Long userId, Long employeeId) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "CONTRACT_VIEW");
        List<LaborContract> all = repository.findByCompany(companyId).stream()
            .filter(c -> employeeId == null || c.getEmployee().getId().equals(employeeId))
            .filter(c -> scope.isEmpty() || scope.contains(c.getEmployee().getDepartment().getId()))
            .toList();
        return toResponses(all, all);
    }

    /** Bước M: lương đóng BH hiện hành theo nhân viên (hợp đồng đang hiệu lực hôm nay). */
    @Transactional(readOnly = true)
    public Map<Long, BigDecimal> currentInsuranceSalaries(Long companyId) {
        List<LaborContract> all = repository.findByCompany(companyId);
        Map<Long, BigDecimal> out = new java.util.HashMap<>();
        for (ContractDTO.Response r : toResponses(all, all)) {
            if ("ACTIVE".equals(r.getDisplayStatus()) && r.getCurrentInsuranceSalary() != null) {
                out.put(r.getEmployeeId(), r.getCurrentInsuranceSalary());
            }
        }
        return out;
    }

    @Transactional(readOnly = true)
    public ContractDTO.Response get(Long companyId, Long userId, Long id) {
        LaborContract c = getOrThrow(companyId, id);
        requireScope(userId, c.getEmployee());
        return toResponses(List.of(c), repository.findByEmployee(c.getEmployee().getId())).get(0);
    }

    /**
     * Hợp đồng cần gia hạn: đang hiệu lực, kết thúc trong {@code days} ngày tới (hoặc đã quá hạn), nhân viên còn làm
     * và chưa có hợp đồng nối tiếp. {@code days} null = cấu hình của công ty.
     */
    @Transactional(readOnly = true)
    public List<ContractDTO.Response> expiring(Long companyId, Long userId, Integer days) {
        int d = days != null ? Math.max(0, Math.min(days, 366)) : warningDays(companyId);
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "CONTRACT_VIEW");
        List<LaborContract> ending = repository.findActiveEndingBy(companyId, today().plusDays(d)).stream()
            .filter(c -> c.getEmployee().getStatus() != Employee.Status.INACTIVE)
            .filter(c -> scope.isEmpty() || scope.contains(c.getEmployee().getDepartment().getId()))
            .toList();
        if (ending.isEmpty()) return List.of();
        List<LaborContract> siblings = repository.findByCompany(companyId);
        return toResponses(ending, siblings).stream().filter(r -> !r.isRenewed()).toList();
    }

    public int warningDays(Long companyId) {
        return companyRepository.findById(companyId).map(Company::getContractExpiryWarningDays).orElse(30);
    }

    // ── Ghi ─────────────────────────────────────────────────────────────────

    @Transactional
    public ContractDTO.Response create(Long companyId, User user, ContractDTO.Upsert req) {
        Employee e = employeeOf(companyId, req.getEmployeeId());
        requireScope(user.getId(), e);
        LaborContract c = LaborContract.builder().companyId(companyId).employee(e).createdBy(user.getId()).build();
        c.setStatus(parseStatus(req.getStatus(), LaborContract.Status.DRAFT));
        apply(c, req);
        validate(c);
        requireUniqueNo(companyId, c.getContractNo(), null);
        c = repository.saveAndFlush(c);
        replaceContractAllowances(c, req.getAllowances() != null ? req.getAllowances() : List.of());
        syncEmployeeSalary(e);
        audit.log("CONTRACT_CREATE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " — " + e.getEmployeeCode() + " " + e.getFullName())
            .detail(AuditService.map("type", c.getContractType().name(), "status", c.getStatus().name(),
                "start", c.getStartDate(), "end", c.getEndDate(), "baseSalary", c.getBaseSalary()))
            .save();
        return get(companyId, null, c.getId());
    }

    @Transactional
    public ContractDTO.Response update(Long companyId, User user, Long id, ContractDTO.Upsert req) {
        LaborContract c = getOrThrow(companyId, id);
        requireScope(user.getId(), c.getEmployee());
        Map<String, Object> before = snapshot(c);
        if (!c.getEmployee().getId().equals(req.getEmployeeId())) {
            if (c.getStatus() != LaborContract.Status.DRAFT) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.employee_locked");
            }
            Employee e = employeeOf(companyId, req.getEmployeeId());
            requireScope(user.getId(), e);
            c.setEmployee(e);
        }
        if (req.getStatus() != null) {
            LaborContract.Status next = parseStatus(req.getStatus(), c.getStatus());
            if (next != c.getStatus() && !(c.getStatus() == LaborContract.Status.DRAFT && next == LaborContract.Status.ACTIVE)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.status_change_invalid");
            }
            c.setStatus(next);
        }
        apply(c, req);
        validate(c);
        requireUniqueNo(companyId, c.getContractNo(), c.getId());
        c = repository.saveAndFlush(c);
        if (req.getAllowances() != null) replaceContractAllowances(c, req.getAllowances());
        validateAppendicesInRange(c);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_UPDATE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " — " + c.getEmployee().getEmployeeCode())
            .detail(AuditService.map("before", before, "after", snapshot(c)))
            .save();
        return get(companyId, null, c.getId());
    }

    @Transactional
    public ContractDTO.Response activate(Long companyId, User user, Long id) {
        LaborContract c = getOrThrow(companyId, id);
        requireScope(user.getId(), c.getEmployee());
        if (c.getStatus() != LaborContract.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.status_change_invalid");
        }
        c.setStatus(LaborContract.Status.ACTIVE);
        validate(c);
        repository.saveAndFlush(c);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_ACTIVATE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " — " + c.getEmployee().getEmployeeCode()).save();
        return get(companyId, null, c.getId());
    }

    @Transactional
    public ContractDTO.Response terminate(Long companyId, User user, Long id, ContractDTO.TerminateRequest req) {
        LaborContract c = getOrThrow(companyId, id);
        requireScope(user.getId(), c.getEmployee());
        if (c.getStatus() != LaborContract.Status.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.status_change_invalid");
        }
        LocalDate d = req.getTerminationDate();
        if (d.isBefore(c.getStartDate()) || (c.getEndDate() != null && d.isAfter(c.getEndDate()))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.termination_date_invalid");
        }
        c.setStatus(LaborContract.Status.TERMINATED);
        c.setTerminationDate(d);
        c.setTerminationReason(trimToNull(req.getReason()));
        repository.saveAndFlush(c);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_TERMINATE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " — " + c.getEmployee().getEmployeeCode())
            .detail(AuditService.map("terminationDate", d, "reason", c.getTerminationReason()))
            .save();
        return get(companyId, null, c.getId());
    }

    @Transactional
    public void delete(Long companyId, User user, Long id) {
        LaborContract c = getOrThrow(companyId, id);
        requireScope(user.getId(), c.getEmployee());
        c.setDeleted(true);
        repository.saveAndFlush(c);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_DELETE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " — " + c.getEmployee().getEmployeeCode())
            .detail(snapshot(c)).save();
    }

    // ── Phụ lục ─────────────────────────────────────────────────────────────

    @Transactional
    public ContractDTO.Response addAppendix(Long companyId, User user, Long contractId, ContractDTO.AppendixUpsert req) {
        LaborContract c = getOrThrow(companyId, contractId);
        requireScope(user.getId(), c.getEmployee());
        requireNotTerminated(c);
        ContractAppendix a = ContractAppendix.builder().contractId(c.getId()).build();
        applyAppendix(c, a, req);
        a = appendixRepository.saveAndFlush(a);
        replaceAppendixAllowances(c, a, req);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_APPENDIX_CREATE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " / " + a.getAppendixNo() + " — " + c.getEmployee().getEmployeeCode())
            .detail(appendixSnapshot(a)).save();
        return get(companyId, null, c.getId());
    }

    @Transactional
    public ContractDTO.Response updateAppendix(Long companyId, User user, Long appendixId, ContractDTO.AppendixUpsert req) {
        ContractAppendix a = appendixRepository.findByIdAndDeletedFalse(appendixId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.contract.appendix_not_found"));
        LaborContract c = getOrThrow(companyId, a.getContractId());
        requireScope(user.getId(), c.getEmployee());
        requireNotTerminated(c);
        Map<String, Object> before = appendixSnapshot(a);
        applyAppendix(c, a, req);
        appendixRepository.saveAndFlush(a);
        replaceAppendixAllowances(c, a, req);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_APPENDIX_UPDATE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " / " + a.getAppendixNo() + " — " + c.getEmployee().getEmployeeCode())
            .detail(AuditService.map("before", before, "after", appendixSnapshot(a))).save();
        return get(companyId, null, c.getId());
    }

    @Transactional
    public ContractDTO.Response deleteAppendix(Long companyId, User user, Long appendixId) {
        ContractAppendix a = appendixRepository.findByIdAndDeletedFalse(appendixId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.contract.appendix_not_found"));
        LaborContract c = getOrThrow(companyId, a.getContractId());
        requireScope(user.getId(), c.getEmployee());
        a.setDeleted(true);
        appendixRepository.saveAndFlush(a);
        syncEmployeeSalary(c.getEmployee());
        audit.log("CONTRACT_APPENDIX_DELETE").entity("CONTRACT", c.getId())
            .summary(c.getContractNo() + " / " + a.getAppendixNo() + " — " + c.getEmployee().getEmployeeCode())
            .detail(appendixSnapshot(a)).save();
        return get(companyId, null, c.getId());
    }

    // ── Lương ───────────────────────────────────────────────────────────────

    /**
     * Điều khoản lương của kỳ. Rỗng = nhân viên không có hợp đồng nào phủ kỳ → bảng lương dùng
     * {@code employees.contract_salary} như trước.
     *
     * @param contractSalary lương HĐ bình quân của kỳ: lương từng đoạn (đổi theo phụ lục / hợp đồng mới) có trọng số
     *                       là công chuẩn của đoạn theo lịch làm việc; ngày không có hợp đồng không tính
     * @param insuranceSalary lương đóng BH ở ngày cuối kỳ có hợp đồng: mức ghi riêng, không có thì lương + phụ cấp đóng BH
     * @param allowances      phụ cấp ở ngày cuối kỳ có hợp đồng, theo mã
     */
    public record PayTerms(BigDecimal contractSalary, BigDecimal insuranceSalary, Map<String, BigDecimal> allowances,
                           BigDecimal allowanceTotal, BigDecimal taxableAllowance, BigDecimal nonTaxableAllowance) {}

    @Transactional(readOnly = true)
    public Optional<PayTerms> payTerms(Employee employee, PayrollPeriod period,
                                       WorkCalendarService.CalendarView calendar, Long deptId) {
        List<Bundle> bundles = bundlesOf(repository.findNonDraftStartingBefore(employee.getId(), period.to()).stream()
            .filter(c -> c.effectiveEnd() == null || !c.effectiveEnd().isBefore(period.from()))
            .toList());
        if (bundles.isEmpty()) return Optional.empty();

        BigDecimal weightedStd = BigDecimal.ZERO, totalStd = BigDecimal.ZERO;
        BigDecimal weightedDays = BigDecimal.ZERO, totalDays = BigDecimal.ZERO;
        LocalDate runFrom = null, lastCovered = null;
        BigDecimal runSalary = null;
        Bundle lastBundle = null;
        for (LocalDate d = period.from(); !d.isAfter(period.to().plusDays(1)); d = d.plusDays(1)) {
            BigDecimal salary = null;
            if (!d.isAfter(period.to())) {
                for (Bundle b : bundles) {
                    if (b.contract().covers(d)) {
                        salary = b.termsOn(d).baseSalary();
                        lastCovered = d;
                        lastBundle = b;
                        break;
                    }
                }
            }
            boolean same = Objects.equals(salary, runSalary) || (salary != null && runSalary != null && salary.compareTo(runSalary) == 0);
            if (!same || salary == null) {
                if (runSalary != null) {
                    LocalDate runTo = d.minusDays(1);
                    BigDecimal std = calendar.periodDays(deptId, runFrom, runTo).standardDays();
                    BigDecimal days = BigDecimal.valueOf(ChronoUnit.DAYS.between(runFrom, runTo) + 1);
                    weightedStd = weightedStd.add(runSalary.multiply(std));
                    totalStd = totalStd.add(std);
                    weightedDays = weightedDays.add(runSalary.multiply(days));
                    totalDays = totalDays.add(days);
                }
                runSalary = salary;
                runFrom = salary != null ? d : null;
            }
        }
        if (lastBundle == null) return Optional.empty();
        BigDecimal contractSalary = totalStd.signum() > 0
            ? weightedStd.divide(totalStd, 2, RoundingMode.HALF_UP)
            : weightedDays.divide(totalDays, 2, RoundingMode.HALF_UP);

        Terms end = lastBundle.termsOn(lastCovered);
        Map<String, BigDecimal> allowances = new LinkedHashMap<>();
        BigDecimal total = BigDecimal.ZERO, taxable = BigDecimal.ZERO, nonTaxable = BigDecimal.ZERO;
        for (ContractAllowance a : end.allowances()) {
            allowances.merge(a.getCode(), a.getAmount(), BigDecimal::add);
            total = total.add(a.getAmount());
            if (a.isTaxable()) taxable = taxable.add(a.getAmount()); else nonTaxable = nonTaxable.add(a.getAmount());
        }
        return Optional.of(new PayTerms(contractSalary, end.insuranceSalary(), allowances, total, taxable, nonTaxable));
    }

    /** Đặt {@code employees.contract_salary} = lương hợp đồng hiệu lực hôm nay (không có hợp đồng phủ hôm nay → giữ). */
    @Transactional
    public void syncEmployeeSalary(Employee e) {
        LocalDate t = today();
        Optional<Bundle> current = bundlesOf(repository.findNonDraftStartingBefore(e.getId(), t)).stream()
            .filter(b -> b.contract().covers(t)).findFirst();
        if (current.isEmpty()) return;
        BigDecimal salary = current.get().termsOn(t).baseSalary();
        if (e.getContractSalary() == null || e.getContractSalary().compareTo(salary) != 0) {
            e.setContractSalary(salary);
            employeeRepository.save(e);
        }
    }

    /** Lương HĐ của nhân viên do hợp đồng quản lý (đã có hợp đồng không nháp) — form / import nhân viên không sửa được. */
    public boolean managesSalary(Long employeeId) {
        return employeeId != null && repository.managesSalary(employeeId);
    }

    // ── Lịch hằng ngày ──────────────────────────────────────────────────────

    /** 07:30 giờ VN: đồng bộ lương HĐ theo phụ lục tới ngày + báo HR hợp đồng sắp hết hạn. */
    @Scheduled(cron = "0 30 7 * * *", zone = "Asia/Ho_Chi_Minh")
    @Transactional
    public void dailyJob() {
        for (Long employeeId : repository.findManagedEmployeeIds()) {
            try {
                employeeRepository.findById(employeeId).filter(e -> !e.isDeleted()).ifPresent(this::syncEmployeeSalary);
            } catch (RuntimeException ex) {
                log.warn("Không đồng bộ được lương HĐ NV {}: {}", employeeId, ex.getMessage());
            }
        }
        for (Long companyId : repository.findCompaniesWithEndingContracts()) {
            try {
                notifyExpiring(companyId);
            } catch (RuntimeException ex) {
                log.warn("Không gửi được cảnh báo hợp đồng công ty {}: {}", companyId, ex.getMessage());
            }
        }
    }

    /** Gửi thông báo cho tài khoản có CONTRACT_VIEW khi có hợp đồng còn đúng 0 / 7 / {@code warningDays} ngày. */
    void notifyExpiring(Long companyId) {
        // V26: tính năng cảnh báo hợp đồng tắt → không gửi thông báo
        if (!companyRepository.findById(companyId).map(c -> c.hasFeature(com.bosskin.core.CompanyFeatures.HR_CONTRACT_ALERT)).orElse(false)) return;
        int days = warningDays(companyId);
        LocalDate t = today();
        Set<Long> marks = new HashSet<>(List.of(0L, 7L, (long) days));
        List<LaborContract> due = repository.findActiveEndingBy(companyId, t.plusDays(days)).stream()
            .filter(c -> marks.contains(ChronoUnit.DAYS.between(t, c.getEndDate())))
            .filter(c -> c.getEmployee().getStatus() != Employee.Status.INACTIVE)
            .toList();
        if (due.isEmpty()) return;
        String body = due.size() == 1
            ? due.get(0).getEmployee().getFullName() + " — " + due.get(0).getContractNo() + " hết hạn " + due.get(0).getEndDate()
            : due.size() + " hợp đồng sắp hết hạn";
        for (User u : userRepository.findByCompanyId(companyId)) {
            if (u.getFcmToken() == null || !u.isEnabled() || !u.hasPermission("CONTRACT_VIEW")) continue;
            fcmService.sendSimple(u.getFcmToken(), "Hợp đồng cần gia hạn", body, Map.of("type", "CONTRACT_EXPIRING"));
        }
    }

    // ── Excel ───────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ContractDTO.AllowanceExportRow> allowanceRows(List<ContractDTO.Response> contracts) {
        List<ContractDTO.AllowanceExportRow> out = new ArrayList<>();
        for (ContractDTO.Response c : contracts) {
            for (ContractDTO.Allowance a : c.getAllowances()) out.add(new ContractDTO.AllowanceExportRow(c.getContractNo(), a));
        }
        return out;
    }

    /** {@code allowanceRows} null = file không có sheet phụ cấp → giữ nguyên phụ cấp. */
    @Transactional(readOnly = true)
    public List<ContractDTO.ImportDiff> previewImport(Long companyId, Long userId, List<ContractDTO.ImportRow> rows,
                                                      List<ContractDTO.AllowanceImportRow> allowanceRows) {
        Parsed parsed = parse(companyId, userId, rows, allowanceRows);
        List<ContractDTO.ImportDiff> out = new ArrayList<>();
        for (ParsedRow p : parsed.rows()) {
            Optional<LaborContract> existing = repository.findByCompanyIdAndContractNoAndDeletedFalse(companyId, p.contractNo());
            List<ContractDTO.Allowance> newAllowances = parsed.allowances().get(p.contractNo());
            String name = p.employee().getEmployeeCode() + " — " + p.employee().getFullName();
            if (existing.isEmpty()) {
                List<DepartmentDTO.FieldChange> changes = new ArrayList<>();
                addChange(changes, "contractType", "", p.type().name());
                addChange(changes, "status", "", p.status().name());
                addChange(changes, "startDate", "", str(p.startDate()));
                addChange(changes, "endDate", "", str(p.endDate()));
                addChange(changes, "baseSalary", "", money(p.baseSalary()));
                if (newAllowances != null) addChange(changes, "allowances", "", allowanceText(newAllowances));
                out.add(ContractDTO.ImportDiff.builder().action("CREATE").code(p.contractNo()).name(name)
                    .changes(changes).warnings(List.of()).build());
                continue;
            }
            LaborContract c = existing.get();
            List<DepartmentDTO.FieldChange> changes = new ArrayList<>();
            addChange(changes, "employeeCode", c.getEmployee().getEmployeeCode(), p.employee().getEmployeeCode());
            addChange(changes, "contractType", c.getContractType().name(), p.type().name());
            addChange(changes, "status", c.getStatus().name(), p.status().name());
            addChange(changes, "signDate", str(c.getSignDate()), str(p.signDate()));
            addChange(changes, "startDate", str(c.getStartDate()), str(p.startDate()));
            addChange(changes, "endDate", str(c.getEndDate()), str(p.endDate()));
            addChange(changes, "baseSalary", money(c.getBaseSalary()), money(p.baseSalary()));
            addChange(changes, "insuranceSalary", money(c.getInsuranceSalary()), money(p.insuranceSalary()));
            addChange(changes, "positionTitle", nz(c.getPositionTitle()), nz(p.positionTitle()));
            addChange(changes, "note", nz(c.getNote()), nz(p.note()));
            if (newAllowances != null) {
                addChange(changes, "allowances", allowanceText(toAllowanceDtos(contractLevel(c.getId()))), allowanceText(newAllowances));
            }
            out.add(ContractDTO.ImportDiff.builder().action(changes.isEmpty() ? "NO_CHANGE" : "UPDATE")
                .code(p.contractNo()).name(name).changes(changes).warnings(List.of()).build());
        }
        return out;
    }

    @Transactional
    public Map<String, Integer> importFromExcel(Long companyId, User user, List<ContractDTO.ImportRow> rows,
                                               List<ContractDTO.AllowanceImportRow> allowanceRows) {
        Parsed parsed = parse(companyId, user.getId(), rows, allowanceRows);
        int created = 0, updated = 0;
        for (ParsedRow p : parsed.rows()) {
            Optional<LaborContract> existing = repository.findByCompanyIdAndContractNoAndDeletedFalse(companyId, p.contractNo());
            List<ContractDTO.Allowance> newAllowances = parsed.allowances().get(p.contractNo());
            LaborContract c;
            boolean changed;
            if (existing.isEmpty()) {
                c = LaborContract.builder().companyId(companyId).employee(p.employee()).createdBy(user.getId())
                    .contractNo(p.contractNo()).status(p.status()).build();
                changed = true;
            } else {
                c = existing.get();
                changed = !c.getEmployee().getId().equals(p.employee().getId()) || c.getStatus() != p.status()
                    || c.getContractType() != p.type() || !Objects.equals(c.getSignDate(), p.signDate())
                    || !c.getStartDate().equals(p.startDate()) || !Objects.equals(c.getEndDate(), p.endDate())
                    || !sameMoney(c.getBaseSalary(), p.baseSalary()) || !sameMoney(c.getInsuranceSalary(), p.insuranceSalary())
                    || !nz(c.getPositionTitle()).equals(nz(p.positionTitle())) || !nz(c.getNote()).equals(nz(p.note()));
                c.setEmployee(p.employee());
                c.setStatus(p.status());
            }
            c.setContractType(p.type());
            c.setSignDate(p.signDate());
            c.setStartDate(p.startDate());
            c.setEndDate(p.endDate());
            c.setBaseSalary(p.baseSalary());
            c.setInsuranceSalary(p.insuranceSalary());
            c.setPositionTitle(p.positionTitle());
            c.setNote(p.note());
            try {
                validate(c);
            } catch (ResponseStatusException ex) {
                throw new ResponseStatusException(ex.getStatusCode(), "error.contract.import_row|" + p.contractNo() + "|" + ex.getReason());
            }
            c = repository.saveAndFlush(c);
            if (newAllowances != null) {
                String before = allowanceText(toAllowanceDtos(contractLevel(c.getId())));
                if (!before.equals(allowanceText(newAllowances))) {
                    replaceContractAllowances(c, newAllowances);
                    changed = true;
                }
            }
            if (existing.isEmpty()) created++; else if (changed) updated++;
            syncEmployeeSalary(c.getEmployee());
        }
        Map<String, Integer> result = Map.of("created", created, "updated", updated);
        audit.log("CONTRACT_IMPORT").entity("CONTRACT", null).summary("+" + created + " ~" + updated).detail(result).save();
        return result;
    }

    private record ParsedRow(String contractNo, Employee employee, LaborContract.Type type, LaborContract.Status status,
                             LocalDate signDate, LocalDate startDate, LocalDate endDate, BigDecimal baseSalary,
                             BigDecimal insuranceSalary, String positionTitle, String note) {}

    private record Parsed(List<ParsedRow> rows, Map<String, List<ContractDTO.Allowance>> allowances) {}

    private Parsed parse(Long companyId, Long userId, List<ContractDTO.ImportRow> rows,
                         List<ContractDTO.AllowanceImportRow> allowanceRows) {
        List<ParsedRow> out = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        Map<String, Employee> employees = new HashMap<>();
        for (ContractDTO.ImportRow r : rows) {
            String no = trimToNull(r.getContractNo());
            if (no == null) continue;
            if (!seen.add(no)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_duplicate|" + no);
            String code = trimToNull(r.getEmployeeCode());
            if (code == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_employee_required|" + no);
            Employee e = employees.computeIfAbsent(code, k -> employeeRepository.findByEmployeeCodeAndCompanyId(k, companyId)
                .filter(x -> !x.isDeleted())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_employee_not_found|" + k)));
            requireScope(userId, e);
            LaborContract.Type type = parseType(r.getContractType(), no);
            LaborContract.Status status = parseStatus(r.getStatus(), LaborContract.Status.DRAFT);
            Optional<LaborContract> existing = repository.findByCompanyIdAndContractNoAndDeletedFalse(companyId, no);
            LaborContract.Status from = existing.map(LaborContract::getStatus).orElse(null);
            boolean statusOk = from == null ? status != LaborContract.Status.TERMINATED
                : status == from || (from == LaborContract.Status.DRAFT && status == LaborContract.Status.ACTIVE);
            if (!statusOk) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_status|" + no);
            if (existing.isPresent() && from != LaborContract.Status.DRAFT
                    && !existing.get().getEmployee().getId().equals(e.getId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_row|" + no + "|error.contract.employee_locked");
            }
            LocalDate start = parseDate(r.getStartDate(), no);
            if (start == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_start_required|" + no);
            BigDecimal base = parseMoney(r.getBaseSalary(), no);
            if (base == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_salary_required|" + no);
            out.add(new ParsedRow(no, e, type, status, parseDate(r.getSignDate(), no), start, parseDate(r.getEndDate(), no),
                base, parseMoney(r.getInsuranceSalary(), no), trimToNull(r.getPositionTitle()), trimToNull(r.getNote())));
        }
        Map<String, List<ContractDTO.Allowance>> allowances = new LinkedHashMap<>();
        if (allowanceRows != null) {
            for (ParsedRow p : out) allowances.put(p.contractNo(), new ArrayList<>());
            for (ContractDTO.AllowanceImportRow r : allowanceRows) {
                String no = trimToNull(r.getContractNo());
                if (no == null) continue;
                if (!allowances.containsKey(no)) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_allowance_unknown|" + no);
                }
                BigDecimal amount = parseMoney(r.getAmount(), no);
                allowances.get(no).add(ContractDTO.Allowance.builder()
                    .code(nz(r.getCode()).trim().toUpperCase(Locale.ROOT)).name(nz(r.getName()).trim())
                    .amount(amount != null ? amount : BigDecimal.ZERO)
                    .insurable(parseBool(r.getInsurable(), false)).taxable(parseBool(r.getTaxable(), true)).build());
            }
            allowances.forEach((no, list) -> {
                try {
                    validateAllowances(list);
                } catch (ResponseStatusException ex) {
                    throw new ResponseStatusException(ex.getStatusCode(), "error.contract.import_row|" + no + "|" + ex.getReason());
                }
            });
        }
        return new Parsed(out, allowances);
    }

    // ── Nội bộ ──────────────────────────────────────────────────────────────

    /** Điều khoản ở một ngày; insuranceSalary đã giải (mức riêng hoặc lương + phụ cấp đóng BH). */
    public record Terms(BigDecimal baseSalary, BigDecimal insuranceSalary, String positionTitle,
                        List<ContractAllowance> allowances) {}

    private record Bundle(LaborContract contract, List<ContractAppendix> appendices,
                          List<ContractAllowance> contractAllowances, Map<Long, List<ContractAllowance>> appendixAllowances) {
        Terms termsOn(LocalDate d) {
            BigDecimal base = contract.getBaseSalary();
            BigDecimal ins = contract.getInsuranceSalary();
            String title = contract.getPositionTitle();
            List<ContractAllowance> allowances = contractAllowances;
            for (ContractAppendix a : appendices) {
                if (a.getEffectiveFrom().isAfter(d)) break;
                if (a.getBaseSalary() != null) base = a.getBaseSalary();
                if (a.getInsuranceSalary() != null) ins = a.getInsuranceSalary();
                if (a.getPositionTitle() != null) title = a.getPositionTitle();
                if (a.isOverridesAllowances()) allowances = appendixAllowances.getOrDefault(a.getId(), List.of());
            }
            BigDecimal resolvedIns = ins;
            if (resolvedIns == null) {
                resolvedIns = base;
                for (ContractAllowance x : allowances) if (x.isInsurable()) resolvedIns = resolvedIns.add(x.getAmount());
            }
            return new Terms(base, resolvedIns, title, allowances);
        }
    }

    private List<Bundle> bundlesOf(List<LaborContract> contracts) {
        if (contracts.isEmpty()) return List.of();
        List<Long> ids = contracts.stream().map(LaborContract::getId).toList();
        Map<Long, List<ContractAppendix>> apps = appendixRepository.findByContractIdInAndDeletedFalseOrderByEffectiveFromAscIdAsc(ids)
            .stream().collect(Collectors.groupingBy(ContractAppendix::getContractId, LinkedHashMap::new, Collectors.toList()));
        Set<Long> liveAppendixIds = apps.values().stream().flatMap(List::stream).map(ContractAppendix::getId).collect(Collectors.toSet());
        Map<Long, List<ContractAllowance>> contractLevel = new HashMap<>();
        Map<Long, List<ContractAllowance>> byAppendix = new HashMap<>();
        for (ContractAllowance a : allowanceRepository.findByContractIdInOrderByIdAsc(ids)) {
            if (a.getAppendixId() == null) contractLevel.computeIfAbsent(a.getContractId(), k -> new ArrayList<>()).add(a);
            else if (liveAppendixIds.contains(a.getAppendixId())) byAppendix.computeIfAbsent(a.getAppendixId(), k -> new ArrayList<>()).add(a);
        }
        return contracts.stream().map(c -> new Bundle(c, apps.getOrDefault(c.getId(), List.of()),
            contractLevel.getOrDefault(c.getId(), List.of()), byAppendix)).toList();
    }

    /** {@code siblings}: các hợp đồng dùng để xét "đã có hợp đồng nối tiếp". */
    private List<ContractDTO.Response> toResponses(List<LaborContract> contracts, List<LaborContract> siblings) {
        LocalDate t = today();
        Map<Long, List<LaborContract>> byEmployee = siblings.stream()
            .filter(c -> c.getStatus() != LaborContract.Status.DRAFT && !c.isDeleted())
            .collect(Collectors.groupingBy(c -> c.getEmployee().getId()));
        List<ContractDTO.Response> out = new ArrayList<>();
        for (Bundle b : bundlesOf(contracts)) {
            LaborContract c = b.contract();
            Employee e = c.getEmployee();
            LocalDate refDate = t.isBefore(c.getStartDate()) ? c.getStartDate()
                : (c.effectiveEnd() != null && t.isAfter(c.effectiveEnd()) ? c.effectiveEnd() : t);
            Terms now = b.termsOn(refDate);
            boolean renewed = c.getEndDate() != null && byEmployee.getOrDefault(e.getId(), List.of()).stream()
                .anyMatch(o -> !o.getId().equals(c.getId()) && o.getStartDate().isAfter(c.getEndDate()));
            String display = c.isExpired(t) ? "EXPIRED" : c.getStatus().name();
            out.add(ContractDTO.Response.builder()
                .id(c.getId()).employeeId(e.getId()).employeeCode(e.getEmployeeCode()).employeeName(e.getFullName())
                .departmentId(e.getDepartment() != null ? e.getDepartment().getId() : null)
                .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
                .contractNo(c.getContractNo()).contractType(c.getContractType().name())
                .status(c.getStatus().name()).displayStatus(display)
                .signDate(c.getSignDate()).startDate(c.getStartDate()).endDate(c.getEndDate())
                .baseSalary(c.getBaseSalary()).insuranceSalary(c.getInsuranceSalary())
                .positionTitle(c.getPositionTitle()).note(c.getNote())
                .terminationDate(c.getTerminationDate()).terminationReason(c.getTerminationReason())
                .currentBaseSalary(now.baseSalary()).currentInsuranceSalary(now.insuranceSalary())
                .currentAllowanceTotal(now.allowances().stream().map(ContractAllowance::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add))
                .daysToEnd(c.getEndDate() != null ? (int) ChronoUnit.DAYS.between(t, c.getEndDate()) : null)
                .renewed(renewed)
                .allowances(toAllowanceDtos(b.contractAllowances()))
                .appendices(b.appendices().stream().map(a -> ContractDTO.AppendixResponse.builder()
                    .id(a.getId()).appendixNo(a.getAppendixNo()).effectiveFrom(a.getEffectiveFrom())
                    .baseSalary(a.getBaseSalary()).insuranceSalary(a.getInsuranceSalary())
                    .positionTitle(a.getPositionTitle()).overridesAllowances(a.isOverridesAllowances()).note(a.getNote())
                    .allowances(toAllowanceDtos(b.appendixAllowances().getOrDefault(a.getId(), List.of())))
                    .build()).toList())
                .build());
        }
        return out;
    }

    private static List<ContractDTO.Allowance> toAllowanceDtos(List<ContractAllowance> list) {
        return list.stream().map(a -> ContractDTO.Allowance.builder().id(a.getId()).code(a.getCode()).name(a.getName())
            .amount(a.getAmount()).insurable(a.isInsurable()).taxable(a.isTaxable()).build()).toList();
    }

    private List<ContractAllowance> contractLevel(Long contractId) {
        return allowanceRepository.findByContractIdOrderByIdAsc(contractId).stream().filter(a -> a.getAppendixId() == null).toList();
    }

    private void apply(LaborContract c, ContractDTO.Upsert req) {
        c.setContractNo(req.getContractNo().trim());
        c.setContractType(parseType(req.getContractType(), null));
        c.setSignDate(req.getSignDate());
        c.setStartDate(req.getStartDate());
        c.setEndDate(req.getEndDate());
        c.setBaseSalary(req.getBaseSalary());
        c.setInsuranceSalary(req.getInsuranceSalary());
        c.setPositionTitle(trimToNull(req.getPositionTitle()));
        c.setNote(trimToNull(req.getNote()));
        if (req.getAllowances() != null) validateAllowances(req.getAllowances());
    }

    /** Ngày theo loại hợp đồng, mức lương, không chồng với hợp đồng khác của cùng nhân viên. */
    private void validate(LaborContract c) {
        LocalDate start = c.getStartDate(), end = c.getEndDate();
        if (end != null && end.isBefore(start)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.end_before_start");
        }
        switch (c.getContractType()) {
            case INDEFINITE -> {
                if (end != null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.indefinite_has_end");
            }
            case FIXED_TERM -> {
                if (end == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.end_required");
                if (end.isAfter(start.plusMonths(FIXED_TERM_MAX_MONTHS).minusDays(1))) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.fixed_term_too_long");
                }
            }
            case PROBATION, SEASONAL -> {
                if (end == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.end_required");
            }
            case SERVICE -> { }
        }
        if (c.getBaseSalary() == null || c.getBaseSalary().signum() <= 0
                || (c.getInsuranceSalary() != null && c.getInsuranceSalary().signum() < 0)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.salary_invalid");
        }
        if (c.getStatus() == LaborContract.Status.DRAFT) return;
        LocalDate cEnd = c.effectiveEnd();
        for (LaborContract o : repository.findByEmployee(c.getEmployee().getId())) {
            if (o.getId().equals(c.getId()) || o.getStatus() == LaborContract.Status.DRAFT) continue;
            LocalDate oEnd = o.effectiveEnd();
            boolean overlap = (oEnd == null || !start.isAfter(oEnd)) && (cEnd == null || !o.getStartDate().isAfter(cEnd));
            if (overlap) throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.overlap|" + o.getContractNo());
        }
    }

    private void validateAppendicesInRange(LaborContract c) {
        for (ContractAppendix a : appendixRepository.findByContractIdAndDeletedFalseOrderByEffectiveFromAscIdAsc(c.getId())) {
            requireInRange(c, a.getEffectiveFrom());
        }
    }

    private static void requireInRange(LaborContract c, LocalDate d) {
        LocalDate end = c.effectiveEnd();
        if (!d.isAfter(c.getStartDate()) || (end != null && d.isAfter(end))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.appendix_out_of_range");
        }
    }

    private static void requireNotTerminated(LaborContract c) {
        if (c.getStatus() == LaborContract.Status.TERMINATED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.terminated");
        }
    }

    private void applyAppendix(LaborContract c, ContractAppendix a, ContractDTO.AppendixUpsert req) {
        requireInRange(c, req.getEffectiveFrom());
        if ((req.getBaseSalary() != null && req.getBaseSalary().signum() <= 0)
                || (req.getInsuranceSalary() != null && req.getInsuranceSalary().signum() < 0)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.salary_invalid");
        }
        if (req.isOverridesAllowances()) validateAllowances(req.getAllowances() != null ? req.getAllowances() : List.of());
        for (ContractAppendix o : appendixRepository.findByContractIdAndDeletedFalseOrderByEffectiveFromAscIdAsc(c.getId())) {
            if (!o.getId().equals(a.getId()) && o.getAppendixNo().equalsIgnoreCase(req.getAppendixNo().trim())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.appendix_no_exists");
            }
        }
        a.setAppendixNo(req.getAppendixNo().trim());
        a.setEffectiveFrom(req.getEffectiveFrom());
        a.setBaseSalary(req.getBaseSalary());
        a.setInsuranceSalary(req.getInsuranceSalary());
        a.setPositionTitle(trimToNull(req.getPositionTitle()));
        a.setOverridesAllowances(req.isOverridesAllowances());
        a.setNote(trimToNull(req.getNote()));
    }

    private void replaceContractAllowances(LaborContract c, List<ContractDTO.Allowance> list) {
        validateAllowances(list);
        allowanceRepository.deleteContractLevel(c.getId());
        allowanceRepository.flush();
        for (ContractDTO.Allowance a : list) allowanceRepository.save(toEntity(c.getId(), null, a));
    }

    private void replaceAppendixAllowances(LaborContract c, ContractAppendix a, ContractDTO.AppendixUpsert req) {
        allowanceRepository.deleteByAppendix(a.getId());
        allowanceRepository.flush();
        if (!a.isOverridesAllowances() || req.getAllowances() == null) return;
        for (ContractDTO.Allowance x : req.getAllowances()) allowanceRepository.save(toEntity(c.getId(), a.getId(), x));
    }

    private static ContractAllowance toEntity(Long contractId, Long appendixId, ContractDTO.Allowance a) {
        return ContractAllowance.builder().contractId(contractId).appendixId(appendixId)
            .code(a.getCode().trim().toUpperCase(Locale.ROOT)).name(a.getName().trim())
            .amount(a.getAmount()).insurable(a.isInsurable()).taxable(a.isTaxable()).build();
    }

    private static void validateAllowances(List<ContractDTO.Allowance> list) {
        Set<String> codes = new HashSet<>();
        for (ContractDTO.Allowance a : list) {
            String code = a.getCode() == null ? "" : a.getCode().trim().toUpperCase(Locale.ROOT);
            if (!ALLOWANCE_CODE.matcher(code).matches() || RESERVED_ALLOWANCE_CODES.contains(code)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.allowance_code_invalid|" + code);
            }
            if (!codes.add(code)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.allowance_code_duplicate|" + code);
            }
            if (a.getName() == null || a.getName().isBlank()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.allowance_name_required|" + code);
            }
            if (a.getAmount() == null || a.getAmount().signum() < 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.allowance_amount_invalid|" + code);
            }
        }
    }

    private void requireUniqueNo(Long companyId, String no, Long selfId) {
        repository.findByCompanyIdAndContractNoAndDeletedFalse(companyId, no)
            .filter(o -> !o.getId().equals(selfId))
            .ifPresent(o -> { throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.no_exists|" + no); });
    }

    private LaborContract getOrThrow(Long companyId, Long id) {
        return repository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.contract.not_found"));
    }

    private Employee employeeOf(Long companyId, Long employeeId) {
        return employeeRepository.findByIdAndCompanyId(employeeId, companyId).filter(e -> !e.isDeleted())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    /** userId null = gọi nội bộ sau khi đã kiểm phạm vi. */
    private void requireScope(Long userId, Employee e) {
        if (userId == null) return;
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "CONTRACT_VIEW");
        if (!scope.isEmpty() && (e.getDepartment() == null || !scope.contains(e.getDepartment().getId()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
        }
    }

    private static Map<String, Object> snapshot(LaborContract c) {
        return AuditService.map("contractNo", c.getContractNo(), "employeeId", c.getEmployee().getId(),
            "type", c.getContractType().name(), "status", c.getStatus().name(), "sign", c.getSignDate(),
            "start", c.getStartDate(), "end", c.getEndDate(), "baseSalary", c.getBaseSalary(),
            "insuranceSalary", c.getInsuranceSalary(), "positionTitle", c.getPositionTitle());
    }

    private static Map<String, Object> appendixSnapshot(ContractAppendix a) {
        return AuditService.map("appendixNo", a.getAppendixNo(), "effectiveFrom", a.getEffectiveFrom(),
            "baseSalary", a.getBaseSalary(), "insuranceSalary", a.getInsuranceSalary(),
            "positionTitle", a.getPositionTitle(), "overridesAllowances", a.isOverridesAllowances());
    }

    private static LaborContract.Type parseType(String v, String contractNo) {
        String s = v == null ? "" : v.trim().toUpperCase(Locale.ROOT);
        for (LaborContract.Type t : LaborContract.Type.values()) if (t.name().equals(s)) return t;
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
            contractNo == null ? "error.contract.type_invalid" : "error.contract.import_type|" + contractNo + "|" + v);
    }

    private static LaborContract.Status parseStatus(String v, LaborContract.Status fallback) {
        if (v == null || v.isBlank()) return fallback;
        String s = v.trim().toUpperCase(Locale.ROOT);
        for (LaborContract.Status t : LaborContract.Status.values()) if (t.name().equals(s)) return t;
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.status_invalid|" + v);
    }

    private static final List<DateTimeFormatter> DATE_FORMATS = List.of(
        DateTimeFormatter.ISO_LOCAL_DATE, DateTimeFormatter.ofPattern("d/M/yyyy"), DateTimeFormatter.ofPattern("d-M-yyyy"));

    private static LocalDate parseDate(String raw, String contractNo) {
        String v = trimToNull(raw);
        if (v == null) return null;
        if (v.matches("\\d{5}(\\.0+)?")) return LocalDate.of(1899, 12, 30).plusDays(Long.parseLong(v.replaceAll("\\..*", "")));
        for (DateTimeFormatter f : DATE_FORMATS) {
            try { return LocalDate.parse(v, f); } catch (DateTimeParseException ignored) { }
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_date|" + contractNo + "|" + v);
    }

    private static BigDecimal parseMoney(String raw, String contractNo) {
        String v = trimToNull(raw);
        if (v == null) return null;
        try {
            return new BigDecimal(v);
        } catch (NumberFormatException ex) {
            String digits = v.replaceAll("[^0-9]", "");
            if (digits.isEmpty()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.contract.import_money|" + contractNo + "|" + v);
            }
            return new BigDecimal(digits);
        }
    }

    private static boolean parseBool(String raw, boolean fallback) {
        String v = trimToNull(raw);
        if (v == null) return fallback;
        v = v.toLowerCase(Locale.ROOT);
        return v.equals("1") || v.equals("x") || v.equals("true") || v.equals("yes") || v.equals("có") || v.equals("co");
    }

    private static boolean sameMoney(BigDecimal a, BigDecimal b) {
        return a == null ? b == null : b != null && a.compareTo(b) == 0;
    }

    private static String money(BigDecimal v) {
        return v == null ? "" : v.stripTrailingZeros().toPlainString();
    }

    private static String str(LocalDate d) {
        return d == null ? "" : d.toString();
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private static String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private static String allowanceText(List<ContractDTO.Allowance> list) {
        return list.stream()
            .map(a -> a.getCode().trim().toUpperCase(Locale.ROOT) + "=" + money(a.getAmount())
                + (a.isInsurable() ? " +INS" : "") + (a.isTaxable() ? "" : " -TAX"))
            .sorted().collect(Collectors.joining("; "));
    }

    private static void addChange(List<DepartmentDTO.FieldChange> list, String field, String oldV, String newV) {
        if (Objects.equals(oldV, newV)) return;
        list.add(DepartmentDTO.FieldChange.builder().field(field).oldValue(oldV).newValue(newV).build());
    }
}
