package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.JobHistoryDTO;
import com.bosskin.entity.*;
import com.bosskin.entity.EmployeeJobHistory.ChangeType;
import com.bosskin.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Bước K — lịch sử công tác. Mỗi thay đổi phòng ban / chức vụ / bậc lương / quản lý trực tiếp là một dòng có ngày hiệu lực;
 * {@code employees.*} luôn giữ bản hiện hành (dòng mới nhất có ngày hiệu lực ≤ hôm nay). Dòng tương lai tự áp dụng mỗi sáng.
 * Bảng lương lấy phòng ban / bậc lương theo dòng hiệu lực ở ngày cuối kỳ ({@link #effectiveOn}).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class JobHistoryService {

    private final EmployeeJobHistoryRepository repository;
    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final SalaryGradeRepository salaryGradeRepository;
    private final UserRepository userRepository;
    private final DeptScopeService deptScopeService;
    private final AuditService audit;
    private final Clock clock;

    /** Bốn thông tin theo dõi trong lịch sử. */
    public record Snapshot(Long departmentId, Long positionId, Long salaryGradeId, Long managerId) {
        public static Snapshot of(Employee e) {
            return new Snapshot(e.getDepartment() != null ? e.getDepartment().getId() : null,
                e.getPosition() != null ? e.getPosition().getId() : null,
                e.getSalaryGrade() != null ? e.getSalaryGrade().getId() : null,
                e.getManager() != null ? e.getManager().getId() : null);
        }
    }

    /** Phòng ban + bậc lương hiệu lực ở một ngày (bảng lương). */
    public record Effective(Department department, SalaryGrade salaryGrade) {}

    private LocalDate today() {
        return LocalDate.now(clock);
    }

    // ── Đọc ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<JobHistoryDTO.Response> list(Long companyId, Long userId, Long employeeId) {
        Employee e = employee(employeeId, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        List<EmployeeJobHistory> rows = repository.findByEmployee(employeeId);
        Long currentId = rows.stream().filter(h -> !h.getEffectiveFrom().isAfter(today()))
            .findFirst().map(EmployeeJobHistory::getId).orElse(null);
        Map<Long, String> creators = new HashMap<>();
        rows.stream().map(EmployeeJobHistory::getCreatedBy).filter(Objects::nonNull).distinct()
            .forEach(id -> userRepository.findById(id).ifPresent(u -> creators.put(id, displayName(u))));
        return rows.stream().map(h -> toResponse(h, h.getId().equals(currentId), creators.get(h.getCreatedBy()))).toList();
    }

    /**
     * Phòng ban / bậc lương hiệu lực ở ngày {@code date}; chưa có lịch sử thì lấy hồ sơ hiện tại.
     * Mốc chưa có bậc lương (bậc được gán lần đầu sau này) → dùng bậc hiện tại, như trước Bước K.
     */
    @Transactional(readOnly = true)
    public Effective effectiveOn(Employee e, LocalDate date) {
        return repository.effectiveOn(e.getId(), date)
            .map(h -> new Effective(h.getDepartment(),
                h.getSalaryGrade() != null ? h.getSalaryGrade() : e.getSalaryGrade()))
            .orElseGet(() -> new Effective(e.getDepartment(), e.getSalaryGrade()));
    }

    /** Sơ đồ tổ chức: nhân viên đang làm trong phạm vi xem nhân viên của người gọi. */
    @Transactional(readOnly = true)
    public List<JobHistoryDTO.OrgNode> orgChart(Long companyId, Long userId) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        Set<Long> heads = departmentRepository.findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getManager() != null).map(d -> d.getManager().getId()).collect(Collectors.toSet());
        return employeeRepository.findAllByCompanyIdFetchDepartment(companyId).stream()
            .filter(e -> e.getStatus() != Employee.Status.INACTIVE)
            .filter(e -> scope.isEmpty() || scope.contains(e.getDepartment().getId()))
            .sorted(Comparator.comparing(Employee::getFullName))
            .map(e -> JobHistoryDTO.OrgNode.builder()
                .id(e.getId()).employeeCode(e.getEmployeeCode()).fullName(e.getFullName()).avatar(e.getAvatar())
                .departmentId(e.getDepartment().getId()).departmentName(e.getDepartment().getName())
                .positionName(e.getPosition() != null ? e.getPosition().getName() : null)
                .managerId(e.getManager() != null ? e.getManager().getId() : null)
                .departmentHead(heads.contains(e.getId()))
                .build())
            .toList();
    }

    // ── Ghi ──────────────────────────────────────────────────────────────────

    @Transactional
    public JobHistoryDTO.Response create(Long companyId, User user, Long employeeId, JobHistoryDTO.Upsert req) {
        Employee e = employee(employeeId, companyId);
        requireViewScope(user.getId(), e.getDepartment().getId());
        Department dept = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        requireViewScope(user.getId(), dept.getId());
        Position pos = null;
        if (req.getPositionId() != null) {
            pos = positionRepository.findByIdAndDepartmentCompanyId(req.getPositionId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.position.not_found"));
            if (!pos.getDepartment().getId().equals(dept.getId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.position.not_in_department");
            }
        }
        SalaryGrade grade = null;
        if (req.getSalaryGradeId() != null) {
            grade = salaryGradeRepository.findById(req.getSalaryGradeId())
                .filter(g -> g.getCompany() != null && g.getCompany().getId().equals(companyId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.salary_grade.not_found"));
        }
        Employee manager = req.getManagerId() != null ? resolveManager(e, req.getManagerId(), companyId) : null;
        if (req.getEffectiveFrom().isBefore(e.getJoinDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.job_history.before_join_date");
        }

        EmployeeJobHistory h = repository.save(EmployeeJobHistory.builder()
            .companyId(companyId).employee(e).effectiveFrom(req.getEffectiveFrom()).changeType(req.getChangeType())
            .department(dept).position(pos).salaryGrade(grade).manager(manager)
            .note(blankToNull(req.getNote())).createdBy(user.getId())
            .build());
        sync(e);
        audit.log("JOB_HISTORY_CREATE").entity("EMPLOYEE", e.getId())
            .summary(e.getFullName() + " · " + req.getChangeType() + " · " + req.getEffectiveFrom())
            .detail(AuditService.map("historyId", h.getId(), "effectiveFrom", req.getEffectiveFrom(),
                "changeType", req.getChangeType(), "department", dept.getName(),
                "position", pos != null ? pos.getName() : null, "salaryGrade", grade != null ? grade.getCode() : null,
                "manager", manager != null ? manager.getFullName() : null, "note", h.getNote()))
            .save();
        return toResponse(h, false, displayName(user));
    }

    /** Chỉ xoá được mốc chưa tới ngày — mốc đã áp dụng là lịch sử. */
    @Transactional
    public void delete(Long companyId, User user, Long id) {
        EmployeeJobHistory h = repository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.job_history.not_found"));
        Employee e = h.getEmployee();
        requireViewScope(user.getId(), e.getDepartment().getId());
        if (!h.getEffectiveFrom().isAfter(today())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.job_history.past_readonly");
        }
        h.setDeleted(true);
        repository.save(h);
        audit.log("JOB_HISTORY_DELETE").entity("EMPLOYEE", e.getId())
            .summary(e.getFullName() + " · " + h.getChangeType() + " · " + h.getEffectiveFrom())
            .detail(AuditService.map("historyId", h.getId(), "effectiveFrom", h.getEffectiveFrom()))
            .save();
    }

    /** Nhân viên mới: mốc "Tuyển mới" từ ngày vào làm theo dữ liệu vừa tạo. */
    @Transactional
    public void recordHire(Employee e, Long userId) {
        repository.save(EmployeeJobHistory.builder()
            .companyId(e.getCompany().getId()).employee(e).effectiveFrom(e.getJoinDate()).changeType(ChangeType.HIRE)
            .department(e.getDepartment()).position(e.getPosition()).salaryGrade(e.getSalaryGrade())
            .manager(e.getManager()).applied(true).createdBy(userId)
            .build());
    }

    /**
     * Sửa hồ sơ trực tiếp (form, import): nếu 4 thông tin đổi thì ghi mốc hiệu lực hôm nay — hết cập nhật đè không dấu vết.
     */
    @Transactional
    public void recordIfChanged(Employee e, Snapshot before, Long userId) {
        Snapshot after = Snapshot.of(e);
        if (after.equals(before)) return;
        ChangeType type = !Objects.equals(before.departmentId(), after.departmentId()) ? ChangeType.TRANSFER
            : !Objects.equals(before.positionId(), after.positionId()) ? ChangeType.PROMOTION
            : !Objects.equals(before.salaryGradeId(), after.salaryGradeId()) ? ChangeType.SALARY_CHANGE
            : ChangeType.MANAGER_CHANGE;
        LocalDate from = today().isBefore(e.getJoinDate()) ? e.getJoinDate() : today();
        repository.save(EmployeeJobHistory.builder()
            .companyId(e.getCompany().getId()).employee(e).effectiveFrom(from).changeType(type)
            .department(e.getDepartment()).position(e.getPosition()).salaryGrade(e.getSalaryGrade())
            .manager(e.getManager()).applied(true).createdBy(userId)
            .build());
    }

    /** Quản lý trực tiếp hợp lệ: cùng công ty, không phải chính mình, không tạo vòng. */
    @Transactional(readOnly = true)
    public Employee resolveManager(Employee e, Long managerId, Long companyId) {
        if (managerId.equals(e.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.employee.manager_self");
        }
        Employee manager = employeeRepository.findByIdAndCompanyId(managerId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.manager_not_found"));
        Set<Long> seen = new HashSet<>();
        for (Employee m = manager; m != null && seen.add(m.getId()); m = m.getManager()) {
            if (m.getId().equals(e.getId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.employee.manager_cycle");
            }
        }
        return manager;
    }

    // ── Áp dụng ──────────────────────────────────────────────────────────────

    /** Đưa bản hiệu lực hôm nay vào hồ sơ và đánh dấu các mốc đã tới ngày. */
    @Transactional
    public void sync(Employee e) {
        List<EmployeeJobHistory> due = repository.findEffective(e.getId(), today());
        if (due.isEmpty()) return;
        EmployeeJobHistory cur = due.get(0);
        e.setDepartment(cur.getDepartment());
        e.setPosition(cur.getPosition());
        e.setSalaryGrade(cur.getSalaryGrade());
        e.setManager(cur.getManager());
        employeeRepository.save(e);
        for (EmployeeJobHistory h : due) {
            if (!h.isApplied()) {
                h.setApplied(true);
                repository.save(h);
            }
        }
    }

    /** Mỗi sáng 00:05 (giờ VN): áp các mốc vừa tới ngày. */
    @Scheduled(cron = "0 5 0 * * *", zone = "Asia/Ho_Chi_Minh")
    @Transactional
    public int applyDue() {
        int n = 0;
        for (Long id : repository.findEmployeesDue(today())) {
            Optional<Employee> e = employeeRepository.findById(id);
            if (e.isPresent()) {
                sync(e.get());
                n++;
            }
        }
        if (n > 0) log.info("Áp dụng lịch sử công tác tới hạn cho {} nhân viên", n);
        return n;
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private Employee employee(Long id, Long companyId) {
        return employeeRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private void requireViewScope(Long userId, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
        }
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String displayName(User u) {
        return u.getEmployee() != null ? u.getEmployee().getFullName() : u.getEmail();
    }

    private JobHistoryDTO.Response toResponse(EmployeeJobHistory h, boolean current, String createdByName) {
        return JobHistoryDTO.Response.builder()
            .id(h.getId()).effectiveFrom(h.getEffectiveFrom()).changeType(h.getChangeType())
            .departmentId(h.getDepartment().getId()).departmentName(h.getDepartment().getName())
            .positionId(h.getPosition() != null ? h.getPosition().getId() : null)
            .positionName(h.getPosition() != null ? h.getPosition().getName() : null)
            .salaryGradeId(h.getSalaryGrade() != null ? h.getSalaryGrade().getId() : null)
            .salaryGradeCode(h.getSalaryGrade() != null ? h.getSalaryGrade().getCode() : null)
            .salaryGradeName(h.getSalaryGrade() != null ? h.getSalaryGrade().getName() : null)
            .managerId(h.getManager() != null ? h.getManager().getId() : null)
            .managerName(h.getManager() != null ? h.getManager().getFullName() : null)
            .note(h.getNote()).applied(h.isApplied()).current(current)
            .createdByName(createdByName).createdAt(h.getCreatedAt())
            .build();
    }
}
