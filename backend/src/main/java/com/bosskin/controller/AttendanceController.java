package com.bosskin.controller;

import com.bosskin.core.PayrollPeriod;
import com.bosskin.core.WorkFlagCalculator;
import com.bosskin.dto.AttendanceDTO;
import com.bosskin.dto.AttendanceRequestDTO;
import com.bosskin.entity.AttendanceApproveLeave;
import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ShiftAssignment;
import com.bosskin.entity.User;
import com.bosskin.entity.LeaveRequest;
import com.bosskin.repository.AttendanceApproveLeaveRepository;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.AttendanceRequestRepository;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveRequestRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.service.AttendanceCalculationService;
import com.bosskin.service.AttendanceCalculationService.AttendancePolicy;
import com.bosskin.service.AttendanceCalculationService.AttendanceRowData;
import com.bosskin.service.AttendanceCalculationService.ComputedHours;
import com.bosskin.service.AttendanceExcelService;
import com.bosskin.entity.Department;
import com.bosskin.entity.EmployeeLocation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.bosskin.repository.EmployeeLocationRepository;
import com.bosskin.service.DeptScopeService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.Comparator;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/attendances")
@RequiredArgsConstructor
public class AttendanceController {

    private final AttendanceRepository attendanceRepository;
    private final AttendanceRequestRepository attendanceRequestRepository;
    private final AttendanceApproveLeaveRepository attendanceApproveLeaveRepository;
    private final CompanyRepository companyRepository;
    private final EmployeeRepository employeeRepository;
    private final ShiftAssignmentRepository shiftAssignmentRepository;
    private final LeaveRequestRepository leaveRequestV2Repository;
    private final DeptScopeService deptScopeService;
    private final EmployeeLocationRepository employeeLocationRepository;
    private final AttendanceExcelService attendanceExcelService;
    private final AttendanceCalculationService calc;
    private final java.time.Clock clock;
    private final org.springframework.transaction.PlatformTransactionManager transactionManager;
    @jakarta.persistence.PersistenceContext
    private jakarta.persistence.EntityManager entityManager;
    private final com.bosskin.service.PeriodLockService periodLockService;
    private final com.bosskin.audit.AuditService audit;
    private final com.bosskin.service.WorkCalendarService workCalendarService;

    private static final ZoneId ATTENDANCE_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    @GetMapping
    public ResponseEntity<Page<AttendanceDTO.Response>> getByMonth(
        @AuthenticationPrincipal User user,
        @RequestParam int year,
        @RequestParam int month,
        @RequestParam(required = false) Long employeeId,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "50") int size
    ) {
        requirePermission(user, "ATTENDANCE_VIEW");
        var pageable = PageRequest.of(page, size);
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return ResponseEntity.ok(Page.empty());
            }
        }
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        boolean selfOnly = scopeIds.contains(-1L);
        Long selfEmployeeId = null;
        Employee selfEmployee = null;
        if (selfOnly) {
            selfEmployee = getSelfEmployee(user);
            selfEmployeeId = selfEmployee.getId();
            if (employeeId != null && !employeeId.equals(selfEmployeeId)) {
                return ResponseEntity.ok(Page.empty());
            }
            employeeId = selfEmployeeId;
            if (selectedDeptScope != null) {
                Long selfDeptId = selfEmployee.getDepartment() != null
                    ? selfEmployee.getDepartment().getId()
                    : null;
                if (selfDeptId == null || !selectedDeptScope.contains(selfDeptId)) {
                    return ResponseEntity.ok(Page.empty());
                }
            }
            scopeIds = Collections.emptySet();
        }
        Page<Attendance> result;
        if (!scopeIds.isEmpty()) {
            Set<Long> deptScope = scopeIds.stream()
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
            if (deptScope.isEmpty()) {
                return ResponseEntity.ok(Page.empty());
            }
            if (selectedDeptScope != null) {
                Set<Long> intersection = new HashSet<>(deptScope);
                intersection.retainAll(selectedDeptScope);
                if (intersection.isEmpty()) {
                    return ResponseEntity.ok(Page.empty());
                }
                deptScope = intersection;
            }
            Long companyId = user.getCompany().getId();
            com.bosskin.core.PayrollPeriod period = PayrollPeriod.of(year, month, getSelfCompany(user).getPayrollCutoffDay());
            result = attendanceRepository.findByPeriodWithDeptScope(period.from(), period.to(), companyId, employeeId, deptScope, pageable);
        } else {
            Long companyId = user.getCompany().getId();
            com.bosskin.core.PayrollPeriod period = PayrollPeriod.of(year, month, getSelfCompany(user).getPayrollCutoffDay());
            if (selectedDeptScope != null) {
                result = attendanceRepository.findByPeriodWithDeptScope(period.from(), period.to(), companyId, employeeId, selectedDeptScope, pageable);
            } else {
                result = attendanceRepository.findByPeriodWithFilters(period.from(), period.to(), companyId, employeeId, departmentId, pageable);
            }
        }
        return ResponseEntity.ok(result.map(AttendanceDTO.Response::from));
    }

    @GetMapping("/timesheet")
    public ResponseEntity<List<AttendanceDTO.TimesheetRow>> getTimesheet(
        @AuthenticationPrincipal User user,
        @RequestParam Long employeeId,
        @RequestParam int year,
        @RequestParam int month
    ) {
        requirePermission(user, "ATTENDANCE_VIEW");
        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scopeIds.contains(-1L)) {
            Long selfEmployeeId = getSelfEmployee(user).getId();
            if (!employeeId.equals(selfEmployeeId)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.self_only");
            }
        } else {
            requireViewScope(user, employee.getDepartment().getId());
        }

        var company = employee.getCompany();
        LocalTime dayStart, dayEnd;
        if (company.isAttendanceDayNightMode()) {
            dayStart = company.getDayStartTime() != null ? company.getDayStartTime() : LocalTime.of(6, 0);
            dayEnd   = company.getDayEndTime()   != null ? company.getDayEndTime()   : LocalTime.of(22, 0);
        } else {
            dayStart = LocalTime.MIDNIGHT;
            dayEnd   = LocalTime.of(23, 59);
        }

        var period = PayrollPeriod.of(year, month, employee.getCompany().getPayrollCutoffDay());
        LocalDate from = period.from();
        LocalDate to   = period.to();

        Map<LocalDate, List<Attendance>> attMap = attendanceRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(Attendance::getDate));

        Map<LocalDate, List<com.bosskin.entity.AttendanceRequest>> requestMap = attendanceRequestRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(com.bosskin.entity.AttendanceRequest::getRequestDate));

        Map<LocalDate, List<ShiftAssignment>> shiftMap = shiftAssignmentRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(ShiftAssignment::getWorkDate));

        Map<LocalDate, LeaveRequest> leaveMap = new java.util.HashMap<>();
        for (LeaveRequest lr : leaveRequestV2Repository.findApprovedByEmployeeAndDateRange(employeeId, from, to)) {
            for (LocalDate d = lr.getFromDate(); !d.isAfter(lr.getToDate()); d = d.plusDays(1)) {
                leaveMap.putIfAbsent(d, lr);
            }
        }

        boolean otEnabled = company.isAttendanceOtEnabled();
        AttendancePolicy policy = resolveAttendancePolicy(employee);
        List<AttendanceDTO.TimesheetRow> rows = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            rows.addAll(buildTimesheetRows(d, attMap.getOrDefault(d, List.of()), shiftMap.get(d), requestMap.get(d), leaveMap.get(d), dayStart, dayEnd, otEnabled, policy));
        }
        markCalendar(rows, employee, from, to);
        return ResponseEntity.ok(rows);
    }

    @GetMapping("/timesheet-range")
    public ResponseEntity<List<AttendanceDTO.TimesheetRow>> getTimesheetRange(
        @AuthenticationPrincipal User user,
        @RequestParam Long employeeId,
        @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate from,
        @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        requirePermission(user, "ATTENDANCE_VIEW");
        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scopeIds.contains(-1L)) {
            if (!employeeId.equals(getSelfEmployee(user).getId()))
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        } else {
            requireViewScope(user, employee.getDepartment().getId());
        }
        var company = employee.getCompany();
        LocalTime dayStart, dayEnd;
        if (company.isAttendanceDayNightMode()) {
            dayStart = company.getDayStartTime() != null ? company.getDayStartTime() : LocalTime.of(6, 0);
            dayEnd   = company.getDayEndTime()   != null ? company.getDayEndTime()   : LocalTime.of(22, 0);
        } else {
            dayStart = LocalTime.MIDNIGHT;
            dayEnd   = LocalTime.of(23, 59);
        }
        Map<LocalDate, List<Attendance>> attMap = attendanceRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(Attendance::getDate));
        Map<LocalDate, List<com.bosskin.entity.AttendanceRequest>> requestMap = attendanceRequestRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(com.bosskin.entity.AttendanceRequest::getRequestDate));
        Map<LocalDate, List<ShiftAssignment>> shiftMap = shiftAssignmentRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(ShiftAssignment::getWorkDate));
        Map<LocalDate, LeaveRequest> leaveMap = new java.util.HashMap<>();
        for (LeaveRequest lr : leaveRequestV2Repository.findApprovedByEmployeeAndDateRange(employeeId, from, to)) {
            for (LocalDate d = lr.getFromDate(); !d.isAfter(lr.getToDate()); d = d.plusDays(1)) {
                leaveMap.putIfAbsent(d, lr);
            }
        }
        boolean otEnabled = company.isAttendanceOtEnabled();
        AttendancePolicy policy = resolveAttendancePolicy(employee);
        List<AttendanceDTO.TimesheetRow> rows = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            rows.addAll(buildTimesheetRows(d, attMap.getOrDefault(d, List.of()), shiftMap.get(d), requestMap.get(d), leaveMap.get(d), dayStart, dayEnd, otEnabled, policy));
        }
        markCalendar(rows, employee, from, to);
        return ResponseEntity.ok(rows);
    }

    @GetMapping("/day-view")
    public ResponseEntity<List<AttendanceDTO.DayViewRow>> getDayView(
        @AuthenticationPrincipal User user,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
        @RequestParam(required = false) Long departmentId
    ) {
        requirePermission(user, "ATTENDANCE_VIEW");
        Company company = getSelfCompany(user);
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        List<Employee> employees = resolveDayViewEmployees(user, company, departmentId, scopeIds);
        if (employees.isEmpty()) {
            return ResponseEntity.ok(List.of());
        }

        LocalTime dayStart, dayEnd;
        if (company.isAttendanceDayNightMode()) {
            dayStart = company.getDayStartTime() != null ? company.getDayStartTime() : LocalTime.of(6, 0);
            dayEnd   = company.getDayEndTime()   != null ? company.getDayEndTime()   : LocalTime.of(22, 0);
        } else {
            dayStart = LocalTime.MIDNIGHT;
            dayEnd   = LocalTime.of(23, 59);
        }

        Map<Long, List<Attendance>> attMap = attendanceRepository.findByCompanyAndDate(company.getId(), date)
            .stream()
            .collect(Collectors.groupingBy(a -> a.getEmployee().getId()));

        Map<Long, List<AttendanceRequest>> requestMap = attendanceRequestRepository
            .findByCompanyAndRequestDate(company.getId(), date)
            .stream()
            .collect(Collectors.groupingBy(r -> r.getEmployee().getId()));

        Map<Long, List<ShiftAssignment>> shiftMap = shiftAssignmentRepository
            .findByCompanyAndDate(company.getId(), date)
            .stream()
            .collect(Collectors.groupingBy(sa -> sa.getEmployee().getId()));

        Map<Long, List<LeaveRequest>> leaveMap = leaveRequestV2Repository
            .findApprovedByCompanyAndDate(company.getId(), date)
            .stream()
            .collect(Collectors.groupingBy(lr -> lr.getEmployee().getId()));

        boolean otEnabled = company.isAttendanceOtEnabled();
        List<AttendanceDTO.DayViewRow> rows = employees.stream()
            .flatMap(employee -> {
                List<LeaveRequest> empLeaves = leaveMap.getOrDefault(employee.getId(), List.of());
                return buildDayViewRows(
                    employee,
                    date,
                    attMap.getOrDefault(employee.getId(), List.of()),
                    shiftMap.get(employee.getId()),
                    requestMap.get(employee.getId()),
                    empLeaves,
                    dayStart,
                    dayEnd,
                    otEnabled,
                    resolveAttendancePolicy(employee)
                ).stream();
            })
            .toList();
        markCalendarDay(rows, company.getId(), date);
        return ResponseEntity.ok(rows);
    }

    /** Bước J: ngày nghỉ theo lịch tuần của phòng + ngày lễ (thay cho T7/CN cố định). */
    private void markCalendar(List<AttendanceDTO.TimesheetRow> rows, Employee employee, LocalDate from, LocalDate to) {
        var cal = workCalendarService.view(employee.getCompany().getId(), from, to);
        Long deptId = employee.getDepartment() != null ? employee.getDepartment().getId() : null;
        for (AttendanceDTO.TimesheetRow r : rows) {
            r.setWeekend(cal.isOff(deptId, r.getDate()));
            var h = cal.holiday(r.getDate());
            r.setHolidayName(h != null ? h.getName() : null);
        }
    }

    private void markCalendarDay(List<AttendanceDTO.DayViewRow> rows, Long companyId, LocalDate date) {
        var cal = workCalendarService.view(companyId, date, date);
        var h = cal.holiday(date);
        for (AttendanceDTO.DayViewRow r : rows) {
            r.setWeekend(cal.isOff(r.getDepartmentId(), date));
            r.setHolidayName(h != null ? h.getName() : null);
        }
    }

    private List<AttendanceDTO.TimesheetRow> buildTimesheetRows(
        LocalDate date,
        List<Attendance> atts,
        List<ShiftAssignment> assignments,
        List<AttendanceRequest> requests,
        LeaveRequest leave,
        LocalTime dayStart,
        LocalTime dayEnd,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        List<ShiftAssignment> effectiveAssignments =
            assignments == null || assignments.isEmpty()
                ? Collections.singletonList(null)
                : assignments.stream()
                    .sorted(this::compareAssignments)
                    .toList();

        Map<Long, Attendance> attByShift = atts.stream()
            .filter(a -> a.getShiftAssignment() != null)
            .collect(Collectors.toMap(a -> a.getShiftAssignment().getId(), a -> a, (a, b) -> a));
        Attendance noShiftAtt = atts.stream()
            .filter(a -> a.getShiftAssignment() == null)
            .findFirst().orElse(null);

        List<AttendanceDTO.TimesheetRow> rows = new ArrayList<>();
        for (int i = 0; i < effectiveAssignments.size(); i++) {
            ShiftAssignment sa = effectiveAssignments.get(i);
            Attendance att = sa != null ? attByShift.getOrDefault(sa.getId(), noShiftAtt) : noShiftAtt;
            LeaveRequest slotLeave = resolveLeaveForSlot(leave, sa, effectiveAssignments.size(), i);
            rows.add(buildRow(date, att, sa, i, requests, slotLeave, dayStart, dayEnd, otEnabled, policy));
        }
        return rows;
    }

    private AttendanceDTO.TimesheetRow buildRow(
        LocalDate date,
        Attendance att,
        ShiftAssignment assignment,
        int slotIndex,
        List<AttendanceRequest> requests,
        LeaveRequest leave,
        LocalTime dayStart,
        LocalTime dayEnd,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        LocalTime leaveFrom = leave != null && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getFromTime() : null;
        LocalTime leaveTo   = leave != null && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getToTime()   : null;
        AttendanceRowData data = computeRowData(att, assignment, slotIndex, requests, leaveFrom, leaveTo, dayStart, dayEnd, otEnabled, policy);

        var h = computeHours(att, data, policy, dayStart, dayEnd, true);
        double calcActual = h.actualHours(), calcRegDay = h.regularDayHours(),
               calcOtDay = h.otDayHours(), calcRegNight = h.regularNightHours(), calcOtNight = h.otNightHours();

        String dayLabel = switch (date.getDayOfWeek()) {
            case MONDAY    -> "T2";
            case TUESDAY   -> "T3";
            case WEDNESDAY -> "T4";
            case THURSDAY  -> "T5";
            case FRIDAY    -> "T6";
            case SATURDAY  -> "T7";
            case SUNDAY    -> "CN";
        };

        LocalTime roundedCheckIn = roundUp(data.checkIn(), policy.roundingCheckInMinutes());
        LocalTime roundedCheckOut = roundDown(data.checkOut(), policy.roundingCheckOutMinutes());
        return AttendanceDTO.TimesheetRow.builder()
            .date(date)
            .dayLabel(dayLabel)
            .shiftAssignmentId(assignment != null ? assignment.getId() : null)
            .shiftName(data.shiftName())
            .shiftColor(data.shiftColor())
            .shiftStart(data.shiftStart())
            .shiftEnd(data.shiftEnd())
            .breakMinutes(data.breakMinutes())
            .checkIn(roundedCheckIn)
            .checkOut(roundedCheckOut)
            .checkInRaw(data.effectiveCheckIn())
            .checkOutRaw(data.effectiveCheckOut())
            .checkInRounded(data.checkIn() != null && !data.checkIn().equals(roundedCheckIn))
            .checkOutRounded(data.checkOut() != null && !data.checkOut().equals(roundedCheckOut))
            .status(data.status())
            .requestedCheckIn(data.requestedCheckIn())
            .requestedCheckInStatus(data.requestedCheckInStatus())
            .requestedCheckOut(data.requestedCheckOut())
            .requestedCheckOutStatus(data.requestedCheckOutStatus())
            .requestedOvertimeMinutes(data.requestedOvertimeMinutes())
            .requestedOvertimeScope(data.requestedOvertimeScope())
            .requestedOvertimePeriod(data.requestedOvertimePeriod())
            .requestedOvertimeStatus(data.requestedOvertimeStatus())
            .requests(requests == null ? List.of() : requests.stream().map(AttendanceRequestDTO.Response::from).toList())
            .actualHours(calcActual)
            .totalHours(calcRegDay + calcRegNight + calcOtDay + calcOtNight)
            .regularDayHours(calcRegDay)
            .otDayHours(calcOtDay)
            .regularNightHours(calcRegNight)
            .otNightHours(calcOtNight)
            .leaveRequestId(leave != null ? leave.getId() : null)
            .leaveCode(leave != null ? leave.getLeaveType().getCode() : null)
            .leaveMode(leave != null ? leave.getMode().name() : null)
            .leaveStatus(leave != null ? leave.getStatus() : null)
            .leaveApplied(leave != null ? leave.isApplied() : null)
            .leaveProcessedByName(leave != null && leave.getProcessedBy() != null && leave.getProcessedBy().getEmployee() != null
                ? leave.getProcessedBy().getEmployee().getFullName() : null)
            .leaveProcessedAt(leave != null ? leave.getProcessedAt() : null)
            .leaveCreatedAt(leave != null ? leave.getCreatedAt() : null)
            .leaveAmount(leave != null ? leave.getRequestedAmount() : null)
            .leaveFromTime(leave != null && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getFromTime() : null)
            .leaveToTime(leave != null && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getToTime() : null)
            .attendanceId(att != null ? att.getId() : null)
            .approved(att != null && att.isApproved())
            .approvedAt(att != null ? att.getApprovedAt() : null)
            .approvedByName(att != null && att.getApprovedBy() != null && att.getApprovedBy().getEmployee() != null
                ? att.getApprovedBy().getEmployee().getFullName() : null)
            .workFlags(resolveWorkFlags(att, data, leave, policy))
            .overrideCheckIn(att != null ? att.getOverrideCheckIn() : null)
            .overrideCheckOut(att != null ? att.getOverrideCheckOut() : null)
            .overrideBreakMinutes(att != null ? att.getOverrideBreakMinutes() : null)
            .overrideOtDayMinutes(att != null ? att.getOverrideOtDayMinutes() : null)
            .overrideOtNightMinutes(att != null ? att.getOverrideOtNightMinutes() : null)
            .overrideNote(att != null ? att.getOverrideNote() : null)
            .build();
    }


    private List<AttendanceDTO.DayViewRow> buildDayViewRows(
        Employee employee,
        LocalDate date,
        List<Attendance> atts,
        List<ShiftAssignment> assignments,
        List<AttendanceRequest> requests,
        List<LeaveRequest> leaves,
        LocalTime dayStart,
        LocalTime dayEnd,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        List<ShiftAssignment> effectiveAssignments =
            assignments == null || assignments.isEmpty()
                ? Collections.singletonList(null)
                : assignments.stream()
                    .sorted(this::compareAssignments)
                    .toList();

        Map<Long, Attendance> attByShift = atts.stream()
            .filter(a -> a.getShiftAssignment() != null)
            .collect(Collectors.toMap(a -> a.getShiftAssignment().getId(), a -> a, (a, b) -> a));
        Attendance noShiftAtt = atts.stream()
            .filter(a -> a.getShiftAssignment() == null)
            .findFirst().orElse(null);

        List<AttendanceDTO.DayViewRow> result = new ArrayList<>();
        for (int i = 0; i < effectiveAssignments.size(); i++) {
            ShiftAssignment sa = effectiveAssignments.get(i);
            Attendance att = sa != null ? attByShift.getOrDefault(sa.getId(), noShiftAtt) : noShiftAtt;
            LeaveRequest slotLeave = resolveLeaveForSlotFromList(leaves, sa, effectiveAssignments.size(), i);
            result.add(buildDayViewRow(employee, date, att, sa, effectiveAssignments, requests, slotLeave, leaves, dayStart, dayEnd, otEnabled, policy));
        }
        return result;
    }

    private AttendanceDTO.DayViewRow buildDayViewRow(
        Employee employee,
        LocalDate date,
        Attendance att,
        ShiftAssignment assignment,
        List<ShiftAssignment> assignments,
        List<AttendanceRequest> requests,
        LeaveRequest leave,
        List<LeaveRequest> allLeaves,
        LocalTime dayStart,
        LocalTime dayEnd,
        boolean otEnabled,
        AttendancePolicy policy
    ) {
        int slotIndex = assignments != null ? assignments.indexOf(assignment) : 0;
        // Tính giờ công chỉ dùng leave applied HOUR_RANGE
        LocalTime leaveFrom = leave != null && leave.isApplied() && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getFromTime() : null;
        LocalTime leaveTo   = leave != null && leave.isApplied() && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getToTime()   : null;
        AttendanceRowData data = computeRowData(att, assignment, slotIndex, requests, leaveFrom, leaveTo, dayStart, dayEnd, otEnabled, policy);

        var h = computeHours(att, data, policy, dayStart, dayEnd, true);
        double actualHours = h.actualHours(), regularDayHours = h.regularDayHours(),
               otDayHours = h.otDayHours(), regularNightHours = h.regularNightHours(), otNightHours = h.otNightHours();
        boolean approved = att != null && att.isApproved();

        String dayLabel = switch (date.getDayOfWeek()) {
            case MONDAY    -> "T2";
            case TUESDAY   -> "T3";
            case WEDNESDAY -> "T4";
            case THURSDAY  -> "T5";
            case FRIDAY    -> "T6";
            case SATURDAY  -> "T7";
            case SUNDAY    -> "CN";
        };
        var department = employee.getDepartment();
        LocalTime roundedCheckIn = roundUp(data.checkIn(), policy.roundingCheckInMinutes());
        LocalTime roundedCheckOut = roundDown(data.checkOut(), policy.roundingCheckOutMinutes());
        return AttendanceDTO.DayViewRow.builder()
            .employeeId(employee.getId())
            .employeeCode(employee.getEmployeeCode())
            .employeeFullName(employee.getFullName())
            .departmentId(department != null ? department.getId() : null)
            .departmentName(department != null ? department.getName() : null)
            .date(date)
            .dayLabel(dayLabel)
            .shiftAssignmentId(assignment != null ? assignment.getId() : null)
            .shiftName(data.shiftName())
            .shiftColor(data.shiftColor())
            .shiftStart(data.shiftStart())
            .shiftEnd(data.shiftEnd())
            .breakMinutes(data.breakMinutes())
            .checkIn(roundedCheckIn)
            .checkOut(roundedCheckOut)
            .checkInRaw(data.effectiveCheckIn())
            .checkOutRaw(data.effectiveCheckOut())
            .checkInRounded(data.checkIn() != null && !data.checkIn().equals(roundedCheckIn))
            .checkOutRounded(data.checkOut() != null && !data.checkOut().equals(roundedCheckOut))
            .status(data.status())
            .requestedCheckIn(data.requestedCheckIn())
            .requestedCheckInStatus(data.requestedCheckInStatus())
            .requestedCheckOut(data.requestedCheckOut())
            .requestedCheckOutStatus(data.requestedCheckOutStatus())
            .requestedOvertimeMinutes(data.requestedOvertimeMinutes())
            .requestedOvertimeScope(data.requestedOvertimeScope())
            .requestedOvertimePeriod(data.requestedOvertimePeriod())
            .requestedOvertimeStatus(data.requestedOvertimeStatus())
            .requests(requests == null ? List.of() : requests.stream().map(AttendanceRequestDTO.Response::from).toList())
            .attendanceId(data.attendanceId())
            .actualHours(actualHours)
            .totalHours(regularDayHours + regularNightHours + otDayHours + otNightHours)
            .regularDayHours(regularDayHours)
            .otDayHours(otDayHours)
            .regularNightHours(regularNightHours)
            .otNightHours(otNightHours)
            .leaveRequestId(leave != null ? leave.getId() : null)
            .leaveCode(leave != null ? leave.getLeaveType().getCode() : null)
            .leaveMode(leave != null ? leave.getMode().name() : null)
            .leaveStatus(leave != null ? leave.getStatus() : null)
            .leaveApplied(leave != null ? leave.isApplied() : null)
            .leaveProcessedByName(leave != null && leave.getProcessedBy() != null && leave.getProcessedBy().getEmployee() != null
                ? leave.getProcessedBy().getEmployee().getFullName() : null)
            .leaveProcessedAt(leave != null ? leave.getProcessedAt() : null)
            .leaveCreatedAt(leave != null ? leave.getCreatedAt() : null)
            .leaveAmount(leave != null ? leave.getRequestedAmount() : null)
            .leaveFromTime(leave != null && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getFromTime() : null)
            .leaveToTime(leave != null && leave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? leave.getToTime() : null)
            .overrideCheckIn(att != null ? att.getOverrideCheckIn() : null)
            .overrideCheckOut(att != null ? att.getOverrideCheckOut() : null)
            .overrideBreakMinutes(att != null ? att.getOverrideBreakMinutes() : null)
            .overrideOtDayMinutes(att != null ? att.getOverrideOtDayMinutes() : null)
            .overrideOtNightMinutes(att != null ? att.getOverrideOtNightMinutes() : null)
            .overrideNote(att != null ? att.getOverrideNote() : null)
            .approved(approved)
            .approvedAt(att != null ? att.getApprovedAt() : null)
            .approvedByName(att != null && att.getApprovedBy() != null && att.getApprovedBy().getEmployee() != null
                ? att.getApprovedBy().getEmployee().getFullName() : null)
            .workFlags(resolveWorkFlags(att, data, leave, policy))
            .leaves(allLeaves == null ? List.of() : allLeaves.stream().map(lr -> AttendanceDTO.DayViewRow.LeaveInfo.builder()
                .leaveRequestId(lr.getId())
                .leaveCode(lr.getLeaveType().getCode())
                .leaveMode(lr.getMode().name())
                .leaveStatus(lr.getStatus())
                .leaveApplied(lr.isApplied())
                .leaveProcessedByName(lr.getProcessedBy() != null && lr.getProcessedBy().getEmployee() != null
                    ? lr.getProcessedBy().getEmployee().getFullName() : null)
                .leaveProcessedAt(lr.getProcessedAt())
                .leaveCreatedAt(lr.getCreatedAt())
                .leaveAmount(lr.getRequestedAmount())
                .leaveFromTime(lr.getMode() == LeaveRequest.Mode.HOUR_RANGE ? lr.getFromTime() : null)
                .leaveToTime(lr.getMode() == LeaveRequest.Mode.HOUR_RANGE ? lr.getToTime() : null)
                .build()).toList())
            .build();
    }

    /** For hour-range leave with multiple shifts, attach leave only to the slot whose time overlaps the leave window.
     *  For day-range leave (or single slot), always attach. */
    private LeaveRequest resolveLeaveForSlotFromList(List<LeaveRequest> leaves, ShiftAssignment sa, int totalSlots, int slotIndex) {
        if (leaves == null || leaves.isEmpty()) return null;
        // DAY_RANGE ưu tiên, gắn vào slot 0
        for (LeaveRequest lr : leaves) {
            if (lr.getMode() == LeaveRequest.Mode.DAY_RANGE) {
                return slotIndex == 0 ? lr : null;
            }
        }
        // Tất cả HOUR_RANGE: match theo shift overlap
        for (LeaveRequest lr : leaves) {
            LeaveRequest resolved = resolveLeaveForSlot(lr, sa, totalSlots, slotIndex);
            if (resolved != null) return resolved;
        }
        return null;
    }

    private LeaveRequest resolveLeaveForSlot(LeaveRequest leave, ShiftAssignment sa, int totalSlots, int slotIndex) {
        if (leave == null) return null;
        if (leave.getMode() == LeaveRequest.Mode.DAY_RANGE || totalSlots <= 1) {
            return slotIndex == 0 ? leave : null;
        }
        // HOUR_RANGE: match to the shift that overlaps with [fromTime, toTime]
        if (leave.getFromTime() == null || leave.getToTime() == null) {
            return slotIndex == 0 ? leave : null;
        }
        LocalTime shiftStart = assignmentStartTime(sa);
        LocalTime shiftEnd   = assignmentEndTime(sa);
        if (shiftStart == null || shiftEnd == null) return null;
        // Check overlap
        int lf = leave.getFromTime().toSecondOfDay() / 60;
        int lt = leave.getToTime().toSecondOfDay() / 60;
        if (lt <= lf) lt += 1440;
        int ss = shiftStart.toSecondOfDay() / 60;
        int se = shiftEnd.toSecondOfDay() / 60;
        if (se <= ss) se += 1440;
        boolean overlaps = lf < se && lt > ss;
        return overlaps ? leave : null;
    }

    private LocalTime assignmentEndTime(ShiftAssignment assignment) {
        if (assignment == null) return null;
        if (assignment.isCustom()) return assignment.getCustomEndTime();
        if (assignment.getShift() != null) return assignment.effectiveEndTime();
        return null;
    }

    // ── Delegated to AttendanceCalculationService ────────────────────────────

    private AttendancePolicy resolveAttendancePolicy(Employee employee) { return calc.resolvePolicy(employee); }
    private LocalTime assignmentStartTime(ShiftAssignment assignment) {
        if (assignment == null) {
            return null;
        }
        if (assignment.isCustom()) {
            return assignment.getCustomStartTime();
        }
        if (assignment.getShift() != null) return assignment.effectiveStartTime();
        return null;
    }

    private int compareAssignments(ShiftAssignment a, ShiftAssignment b) {
        LocalTime startA = assignmentStartTime(a);
        LocalTime startB = assignmentStartTime(b);
        int cmp = compareNullable(startA, startB);
        if (cmp != 0) {
            return cmp;
        }
        Long idA = a != null ? a.getId() : null;
        Long idB = b != null ? b.getId() : null;
        return compareNullable(idA, idB);
    }

    private <T extends Comparable<T>> int compareNullable(T a, T b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
    }

    private List<Employee> resolveDayViewEmployees(User user, Company company, Long departmentId, Set<Long> scopeIds) {
        List<Employee> employees = employeeRepository.findAllByCompanyIdFetchDepartment(company.getId());
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return List.of();
            }
        }
        if (scopeIds.contains(-1L)) {
            Employee self = getSelfEmployee(user);
            if (selectedDeptScope != null
                && (self.getDepartment() == null || !selectedDeptScope.contains(self.getDepartment().getId()))) {
                return List.of();
            }
            return List.of(self);
        }
        if (!scopeIds.isEmpty()) {
            Set<Long> deptScope = scopeIds.stream()
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
            if (deptScope.isEmpty()) {
                return List.of();
            }
            if (selectedDeptScope != null) {
                Set<Long> intersection = new HashSet<>(deptScope);
                intersection.retainAll(selectedDeptScope);
                if (intersection.isEmpty()) {
                    return List.of();
                }
                deptScope = intersection;
            }
            final Set<Long> finalDeptScope = deptScope;
            return employees.stream()
                .filter(e -> e.getDepartment() != null && finalDeptScope.contains(e.getDepartment().getId()))
                .toList();
        }
        if (selectedDeptScope != null) {
            final Set<Long> finalSelectedDeptScope = selectedDeptScope;
            return employees.stream()
                .filter(e -> e.getDepartment() != null && finalSelectedDeptScope.contains(e.getDepartment().getId()))
                .toList();
        }
        return employees;
    }

    // ── Type aliases from AttendanceCalculationService ───────────────────────
    private AttendanceRowData computeRowData(Attendance att, ShiftAssignment sa, int slotIdx, List<AttendanceRequest> req, LocalTime lf, LocalTime lt, LocalTime ds, LocalTime de, boolean ot, AttendancePolicy p) { return calc.computeRowData(att, sa, slotIdx, req, lf, lt, ds, de, ot, p); }
    private ComputedHours computeHours(Attendance att, AttendanceRowData d, AttendancePolicy p, LocalTime ds, LocalTime de, boolean snap) { return calc.computeHours(att, d, p, ds, de, snap); }
    private String resolveWorkFlags(Attendance att, AttendanceRowData d, LeaveRequest lr, AttendancePolicy p) { return calc.resolveWorkFlags(att, d, lr, p); }
    private LocalTime roundUp(LocalTime v, Integer s) { return calc.roundUp(v, s); }
    private LocalTime roundDown(LocalTime v, Integer s) { return calc.roundDown(v, s); }
    private int roundDownMinutes(int m, Integer s) { return calc.roundDownMinutes(m, s); }
    private double roundDownHours(double h, Integer s) { return calc.roundDownHours(h, s); }
    private int hoursToMinutes(double h) { return calc.hoursToMinutes(h); }
    private LocalTime chooseEarlier(LocalTime a, LocalTime r, LocalTime ss, LocalTime se) { return calc.chooseEarlier(a, r, ss, se); }
    private LocalTime chooseLater(LocalTime a, LocalTime r, LocalTime ss, LocalTime se) { return calc.chooseLater(a, r, ss, se); }

    @PostMapping("/approve")
    @Transactional
    public ResponseEntity<Void> approve(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "ATTENDANCE_APPROVE");
        approveRow(user, body, true);
        return ResponseEntity.ok().build();
    }

    /**
     * Duyệt một dòng công: theo attendanceId, hoặc theo employeeId + date (+ shiftAssignmentId).
     * Dùng chung cho duyệt từng dòng và duyệt hàng loạt ({@link #approveBulk}).
     */
    private void approveRow(User user, Map<String, Object> body, boolean audit) {
        approveRow(user, body, audit, false);
    }

    /** {@code prechecked}: phạm vi, công của chính mình và khoá kỳ đã kiểm cho cả lô (duyệt hàng loạt). */
    private void approveRow(User user, Map<String, Object> body, boolean audit, boolean prechecked) {
        Long attendanceId = body.get("attendanceId") instanceof Number n ? n.longValue() : null;

        Attendance att;
        Long employeeId;
        LocalDate date;
        ShiftAssignment sa;

        if (attendanceId != null) {
            att = attendanceRepository.findByIdAndCompanyId(attendanceId, user.getCompany().getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.attendance.not_found"));
            employeeId = att.getEmployee().getId();
            date = att.getDate();
            sa = att.getShiftAssignment();
            if (!prechecked) {
                requireCanApprove(user, att.getEmployee());
                periodLockService.requireOpen(user.getCompany().getId(), date);
            }
        } else {
            employeeId = body.get("employeeId") instanceof Number n ? n.longValue() : null;
            String dateStr = body.get("date") instanceof String s ? s : null;
            Long shiftAssignmentId = body.get("shiftAssignmentId") instanceof Number n ? n.longValue() : null;
            if (employeeId == null || dateStr == null)
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.missing_fields");
            date = LocalDate.parse(dateStr);
            Employee employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
            if (!prechecked) {
                requireCanApprove(user, employee);
                periodLockService.requireOpen(user.getCompany().getId(), date);
            }
            // A2: phân ca phải thuộc đúng nhân viên và đúng ngày (chặn gắn phân ca công ty khác)
            final Long empIdForSa = employeeId;
            final LocalDate dateForSa = date;
            sa = shiftAssignmentId != null
                ? shiftAssignmentRepository.findById(shiftAssignmentId)
                    .filter(x -> x.getEmployee() != null && x.getEmployee().getId().equals(empIdForSa)
                        && dateForSa.equals(x.getWorkDate()))
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shiftAssignment.not_found"))
                : null;
            final ShiftAssignment finalSa = sa;
            // Ngày không có ca và chưa có bản ghi công (T7, CN…): không tạo bản ghi "vắng" đã duyệt
            if (sa == null
                    && shiftAssignmentRepository.findByEmployeeIdAndWorkDate(employeeId, date).isEmpty()
                    && attendanceRepository.findByEmployeeIdAndDate(employeeId, date).isEmpty()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.nothing_to_approve");
            }
            att = (shiftAssignmentId != null
                ? attendanceRepository.findByEmployeeIdAndDateAndShift(employeeId, date, shiftAssignmentId)
                : attendanceRepository.findByEmployeeIdAndDate(employeeId, date).stream()
                    .filter(a -> a.getShiftAssignment() == null).findFirst()
            ).orElseGet(() -> attendanceRepository.save(Attendance.builder()
                .employee(employee)
                .shiftAssignment(finalSa)
                .date(date)
                .status(Attendance.Status.ABSENT)
                .build()));
        }

        Company company = getSelfCompany(user);
        LocalTime dayStart, dayEnd;
        if (company.isAttendanceDayNightMode()) {
            dayStart = company.getDayStartTime() != null ? company.getDayStartTime() : LocalTime.of(6, 0);
            dayEnd   = company.getDayEndTime()   != null ? company.getDayEndTime()   : LocalTime.of(22, 0);
        } else {
            dayStart = LocalTime.MIDNIGHT;
            dayEnd   = LocalTime.of(23, 59);
        }

        List<ShiftAssignment> allAssignments = shiftAssignmentRepository
            .findByEmployeeIdAndWorkDateWithShift(employeeId, date)
            .stream().sorted(this::compareAssignments).toList();
        int slotIdx = sa != null ? allAssignments.indexOf(sa) : 0;
        if (slotIdx < 0) slotIdx = 0;

        List<AttendanceRequest> requests = attendanceRequestRepository
            .findByEmployeeAndDateRange(employeeId, date, date);
        List<LeaveRequest> allLeaves = leaveRequestV2Repository.findApprovedByEmployeeAndDateRange(employeeId, date, date);
        LeaveRequest slotLeave = resolveLeaveForSlotFromList(allLeaves, sa, Math.max(1, allAssignments.size()), slotIdx);
        LocalTime leaveFrom = slotLeave != null && slotLeave.isApplied() && slotLeave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? slotLeave.getFromTime() : null;
        LocalTime leaveTo   = slotLeave != null && slotLeave.isApplied() && slotLeave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? slotLeave.getToTime()   : null;

        boolean otEnabled = company.isAttendanceOtEnabled();
        AttendancePolicy policy = resolveAttendancePolicy(att.getEmployee());
        AttendanceRowData data = computeRowData(att, sa, slotIdx, requests, leaveFrom, leaveTo, dayStart, dayEnd, otEnabled, policy);

        var snap = computeHours(att, data, policy, dayStart, dayEnd, false);

        att.setApproved(true);
        att.setApprovedAt(LocalDateTime.now(clock));
        att.setApprovedBy(user);
        att.setSnapActualHours(snap.actualHours());
        att.setSnapDayHours(snap.regularDayHours());
        att.setSnapDayOt(snap.otDayHours());
        att.setSnapNightHours(snap.regularNightHours());
        att.setSnapNightOt(snap.otNightHours());

        // Recompute status dựa trên giờ công thực tế
        boolean hasActualHours = snap.actualHours() > 0
            || snap.regularDayHours() > 0 || snap.otDayHours() > 0
            || snap.regularNightHours() > 0 || snap.otNightHours() > 0;
        boolean hasCheckInData = data.checkIn() != null || data.checkOut() != null
            || (att.getOverrideCheckIn() != null) || (att.getOverrideCheckOut() != null);
        att.setStatus(approvedStatus(att, hasActualHours, hasCheckInData, slotLeave, data, policy));

        var workFlags = WorkFlagCalculator.calculate(
            data.shiftStart(), data.shiftEnd(),
            data.flagCheckIn(), data.flagCheckOut(),
            data.otDayHours(), data.otNightHours(),
            slotLeave != null,
            policy.checkInToleranceMinutes(),
            policy.checkOutToleranceMinutes()
        );
        att.setWorkFlags(WorkFlagCalculator.serialize(workFlags));
        var flex = calc.flexibleOutcome(data, snap, slotLeave != null, att.getStatus(), policy);
        if (flex != null) { att.setStatus(flex.status()); att.setWorkFlags(flex.workFlags()); }
        attendanceRepository.save(att);

        // Snapshot leave cho slot này
        attendanceApproveLeaveRepository.deleteByAttendanceId(att.getId());
        if (slotLeave != null) {
            double leaveHours;
            if (slotLeave.getMode() == LeaveRequest.Mode.HOUR_RANGE && slotLeave.getFromTime() != null && slotLeave.getToTime() != null) {
                int from = slotLeave.getFromTime().toSecondOfDay() / 60;
                int to   = slotLeave.getToTime().toSecondOfDay() / 60;
                if (to <= from) to += 1440;
                leaveHours = (to - from) / 60.0;
            } else {
                leaveHours = slotLeave.getRequestedAmount() != null
                    ? slotLeave.getRequestedAmount().doubleValue() * company.getLeaveHoursPerDay().doubleValue()
                    : 0;
            }
            attendanceApproveLeaveRepository.save(AttendanceApproveLeave.builder()
                .attendance(att)
                .leaveRequest(slotLeave)
                .leaveTypeName(slotLeave.getLeaveType().getName())
                .paid(slotLeave.getLeaveType().isPaid())
                .leaveHours(leaveHours)
                .build());
        }

        if (audit) auditAttendance("ATTENDANCE_APPROVE", att, null);
    }

    /** Chấm thiếu một đầu: có giờ vào mà không có giờ ra (quên chấm ra) hoặc ngược lại — không duyệt tự động. */
    private static boolean isIncompletePunch(Attendance a) {
        boolean hasIn = a.getCheckIn() != null || a.getOverrideCheckIn() != null;
        boolean hasOut = a.getCheckOut() != null || a.getOverrideCheckOut() != null;
        return hasIn != hasOut;
    }

    /**
     * Duyệt hàng loạt cả phòng (hoặc cả công ty trong phạm vi) cho một khoảng ngày (≤ 62 ngày).
     * Mỗi dòng chạy trong transaction riêng: dòng lỗi không làm hỏng cả lô. Bỏ qua dòng đã duyệt,
     * ngày thuộc kỳ đã khoá, công của chính mình và ngày không có ca lẫn dữ liệu.
     * Chỉ duyệt các ngày đã qua (trước hôm nay): ngày hôm nay/tương lai còn đang làm → {@code notEnded}.
     * Dòng chấm thiếu (có giờ vào mà không có giờ ra, hoặc ngược lại) để quản lý xem từng dòng → {@code incomplete}.
     * Body: { "from": "2026-09-01", "to": "2026-09-30", "departmentId": 4 (tuỳ chọn) }.
     */
    @PostMapping("/approve-bulk")
    public ResponseEntity<Map<String, Object>> approveBulk(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "ATTENDANCE_APPROVE");
        Long companyId = user.getCompany().getId();
        LocalDate from, to;
        try {
            from = LocalDate.parse(String.valueOf(body.get("from")));
            to = LocalDate.parse(String.valueOf(body.get("to")));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.date.range_invalid");
        }
        if (to.isBefore(from) || java.time.temporal.ChronoUnit.DAYS.between(from, to) > 62) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.date.range_invalid");
        }
        Long departmentId = body.get("departmentId") instanceof Number n ? n.longValue() : null;
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scope.contains(DeptScopeService.SCOPE_SELF_ONLY) && scope.size() == 1) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        Long selfEmpId = user.getEmployee() != null ? user.getEmployee().getId() : null;
        java.util.function.Predicate<Employee> inScope = e -> e.getDepartment() != null
            && (departmentId == null || departmentId.equals(e.getDepartment().getId()))
            && (scope.isEmpty() || scope.contains(e.getDepartment().getId()))
            && (selfEmpId == null || !selfEmpId.equals(e.getId()));

        LocalDate today = LocalDate.now(clock);
        List<Attendance> atts = attendanceRepository.findByCompanyAndDateRangeAndDept(companyId, from, to, departmentId);
        Map<String, Attendance> attByKey = new java.util.HashMap<>();
        for (Attendance a : atts) {
            Long saId = a.getShiftAssignment() != null ? a.getShiftAssignment().getId() : null;
            attByKey.put(a.getEmployee().getId() + "|" + a.getDate() + "|" + saId, a);
        }
        // Dòng cần duyệt: mỗi phân ca, cộng bản ghi công không gắn ca nhưng có dữ liệu (làm ngày nghỉ)
        record Row(Employee emp, LocalDate date, Map<String, Object> body) {}
        List<Row> rows = new ArrayList<>();
        int alreadyApproved = 0, locked = 0, notEnded = 0, incomplete = 0;
        Map<LocalDate, Boolean> lockCache = new java.util.HashMap<>();
        for (ShiftAssignment sa : shiftAssignmentRepository.findByCompanyAndDateRange(companyId, from, to)) {
            Employee e = sa.getEmployee();
            if (!inScope.test(e)) continue;
            Attendance a = attByKey.remove(e.getId() + "|" + sa.getWorkDate() + "|" + sa.getId());
            if (a != null && a.isApproved()) { alreadyApproved++; continue; }
            if (!sa.getWorkDate().isBefore(today)) { notEnded++; continue; }
            if (a != null && isIncompletePunch(a)) { incomplete++; continue; }
            if (lockCache.computeIfAbsent(sa.getWorkDate(), d -> periodLockService.isLocked(companyId, d))) { locked++; continue; }
            Map<String, Object> b = new java.util.HashMap<>();
            if (a != null) b.put("attendanceId", a.getId());
            else { b.put("employeeId", e.getId()); b.put("date", sa.getWorkDate().toString()); b.put("shiftAssignmentId", sa.getId()); }
            rows.add(new Row(e, sa.getWorkDate(), b));
        }
        for (Attendance a : attByKey.values()) {
            if (!inScope.test(a.getEmployee()) || a.isApproved()) continue;
            boolean hasData = a.getCheckIn() != null || a.getCheckOut() != null
                || a.getOverrideCheckIn() != null || a.getOverrideCheckOut() != null;
            if (!hasData) continue;
            if (!a.getDate().isBefore(today)) { notEnded++; continue; }
            if (isIncompletePunch(a)) { incomplete++; continue; }
            if (lockCache.computeIfAbsent(a.getDate(), d -> periodLockService.isLocked(companyId, d))) { locked++; continue; }
            rows.add(new Row(a.getEmployee(), a.getDate(), Map.of("attendanceId", a.getId())));
        }

        var perRow = new org.springframework.transaction.support.TransactionTemplate(transactionManager);
        perRow.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        int approved = 0;
        List<Map<String, Object>> errors = new ArrayList<>();
        int failed = 0;
        // Phiên JPA mở suốt request (open-in-view): xoá cache sau mỗi dòng, nếu không mỗi lần flush phải
        // dò toàn bộ hàng nghìn bản ghi đã nạp → chậm dần (đo thử 300 NV × 23 ngày: 7 dòng/giây).
        entityManager.clear();
        // Theo lô 50 dòng / transaction cho nhanh; lô nào lỗi thì chạy lại từng dòng của lô đó
        // để biết dòng nào lỗi và không làm hỏng các dòng còn lại.
        final int chunkSize = 50;
        for (int i = 0; i < rows.size(); i += chunkSize) {
            List<Row> chunk = rows.subList(i, Math.min(rows.size(), i + chunkSize));
            try {
                perRow.executeWithoutResult(st -> {
                    for (Row row : chunk) approveRow(user, row.body(), false, true);
                    entityManager.flush();
                    entityManager.clear();
                });
                approved += chunk.size();
                continue;
            } catch (Exception chunkError) {
                entityManager.clear();
            }
            for (Row row : chunk) {
                try {
                    perRow.executeWithoutResult(st -> {
                        approveRow(user, row.body(), false, true);
                        entityManager.flush();
                        entityManager.clear();
                    });
                    approved++;
                } catch (Exception ex) {
                    entityManager.clear();
                    failed++;
                    if (errors.size() < 50) {
                        String reason = ex instanceof ResponseStatusException rse && rse.getReason() != null
                            ? rse.getReason() : "error.internal";
                        errors.add(Map.of("employeeName", row.emp().getFullName(), "date", row.date().toString(), "reason", reason));
                    }
                }
            }
        }
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("total", rows.size() + alreadyApproved + locked + notEnded + incomplete);
        result.put("approved", approved);
        result.put("alreadyApproved", alreadyApproved);
        result.put("locked", locked);
        result.put("notEnded", notEnded);
        result.put("incomplete", incomplete);
        result.put("failed", failed);
        result.put("errors", errors);
        audit.log("ATTENDANCE_BULK_APPROVE").entity("DEPARTMENT", departmentId)
            .summary(from + " → " + to + " · " + approved + "/" + rows.size())
            .detail(com.bosskin.audit.AuditService.map("from", from, "to", to, "departmentId", departmentId,
                "approved", approved, "failed", failed, "alreadyApproved", alreadyApproved, "locked", locked,
                "notEnded", notEnded, "incomplete", incomplete))
            .save();
        return ResponseEntity.ok(result);
    }

    /** Bước 2 — nhật ký thao tác trên bảng công. */
    private void auditAttendance(String action, Attendance att, Object detail) {
        audit.log(action).entity("ATTENDANCE", att.getId())
            .summary(att.getEmployee().getFullName() + " · " + att.getDate()
                + (att.getStatus() != null ? " · " + att.getStatus() : ""))
            .detail(detail != null ? detail : com.bosskin.audit.AuditService.map(
                "employeeId", att.getEmployee().getId(), "date", att.getDate(), "status", att.getStatus(),
                "dayHours", att.getSnapDayHours(), "dayOt", att.getSnapDayOt(),
                "nightHours", att.getSnapNightHours(), "nightOt", att.getSnapNightOt()))
            .save();
    }

    @PatchMapping("/{attendanceId}/override")
    @Transactional
    public ResponseEntity<Void> override(
        @PathVariable Long attendanceId,
        @AuthenticationPrincipal User user,
        @RequestBody AttendanceDTO.OverrideRequest req
    ) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Attendance att = attendanceRepository.findByIdAndCompanyId(attendanceId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.attendance.not_found"));
        requireViewScope(user, att.getEmployee().getDepartment().getId());
        requireNotOwnAttendance(user, att.getEmployee());
        periodLockService.requireOpen(user.getCompany().getId(), att.getDate());
        var before = com.bosskin.audit.AuditService.map(
            "checkIn", att.getOverrideCheckIn(), "checkOut", att.getOverrideCheckOut(),
            "breakMinutes", att.getOverrideBreakMinutes(), "otDayMinutes", att.getOverrideOtDayMinutes(),
            "otNightMinutes", att.getOverrideOtNightMinutes(), "note", att.getOverrideNote(),
            "approved", att.isApproved());

        att.setOverrideCheckIn(req.getOverrideCheckIn());
        att.setOverrideCheckOut(req.getOverrideCheckOut());
        att.setOverrideBreakMinutes(req.getOverrideBreakMinutes());
        att.setOverrideOtDayMinutes(req.getOverrideOtDayMinutes());
        att.setOverrideOtNightMinutes(req.getOverrideOtNightMinutes());
        att.setOverrideNote(req.getOverrideNote());
        // Reset approve snapshot so it recalculates
        att.setApproved(false);
        att.setSnapActualHours(null);
        att.setSnapDayHours(null);
        att.setSnapDayOt(null);
        att.setSnapNightHours(null);
        att.setSnapNightOt(null);
        att.setWorkFlags(null);
        attendanceRepository.save(att);
        auditAttendance("ATTENDANCE_OVERRIDE", att, com.bosskin.audit.AuditService.map(
            "employeeId", att.getEmployee().getId(), "date", att.getDate(), "before", before,
            "after", com.bosskin.audit.AuditService.map(
                "checkIn", req.getOverrideCheckIn(), "checkOut", req.getOverrideCheckOut(),
                "breakMinutes", req.getOverrideBreakMinutes(), "otDayMinutes", req.getOverrideOtDayMinutes(),
                "otNightMinutes", req.getOverrideOtNightMinutes(), "note", req.getOverrideNote())));
        return ResponseEntity.ok().build();
    }

    @PostMapping("/override")
    @Transactional
    public ResponseEntity<Map<String, Long>> createOverride(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Long employeeId = body.get("employeeId") instanceof Number n ? n.longValue() : null;
        String dateStr  = body.get("date") instanceof String s ? s : null;
        if (employeeId == null || dateStr == null)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.missing_fields");

        Employee employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment().getId());
        requireNotOwnAttendance(user, employee);
        periodLockService.requireOpen(user.getCompany().getId(), LocalDate.parse(dateStr));

        LocalDate date = LocalDate.parse(dateStr);
        // Find or create attendance record for this employee + date
        List<Attendance> existing = attendanceRepository.findByEmployeeIdAndDate(employeeId, date);
        Attendance att = existing.isEmpty()
            ? attendanceRepository.save(Attendance.builder()
                .employee(employee)
                .date(date)
                .status(Attendance.Status.ABSENT)
                .build())
            : existing.get(0);
        return ResponseEntity.ok(Map.of("attendanceId", att.getId()));
    }

    @PostMapping("/unapprove")
    @Transactional
    public ResponseEntity<Void> unapprove(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "ATTENDANCE_APPROVE");
        Long attendanceId = body.get("attendanceId") instanceof Number n ? n.longValue() : null;
        if (attendanceId == null)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.missing_fields");

        attendanceRepository.findByIdAndCompanyId(attendanceId, user.getCompany().getId()).ifPresent(att -> {
            requireCanApprove(user, att.getEmployee());
            periodLockService.requireOpen(user.getCompany().getId(), att.getDate());
            att.setApproved(false);
            att.setApprovedAt(null);
            att.setApprovedBy(null);
            att.setSnapActualHours(null);
            att.setSnapDayHours(null);
            att.setSnapDayOt(null);
            att.setSnapNightHours(null);
            att.setSnapNightOt(null);
            att.setWorkFlags(null);
            // A5: giữ nguyên trạng thái; lần duyệt sau sẽ tính lại
            attendanceRepository.save(att);
            auditAttendance("ATTENDANCE_UNAPPROVE", att, null);
        });
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    @Transactional
    public ResponseEntity<Void> delete(
        @AuthenticationPrincipal User user,
        @PathVariable Long id
    ) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        var att = attendanceRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.attendance.not_found"));
        periodLockService.requireOpen(user.getCompany().getId(), att.getDate());
        if (att.isApproved())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.already_approved");
        if (att.isDeleted())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.already_deleted");
        att.setDeleted(true);
        att.setDeletedAt(java.time.LocalDateTime.now(clock));
        att.setDeletedBy(user);
        attendanceRepository.save(att);
        auditAttendance("ATTENDANCE_DELETE", att, null);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/check-in")
    public ResponseEntity<AttendanceDTO.Response> checkIn(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Long> body) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Long employeeId = body.get("employeeId");
        LocalDate today = LocalDate.now(clock);

        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment().getId());

        LocalDateTime now = LocalDateTime.now(clock);
        ShiftTarget target = requireCheckInTarget(employee, getSelfCompany(user), now);
        periodLockService.requireOpen(user.getCompany().getId(), target.attendance().getDate());
        target.attendance().setCheckIn(now);
        target.attendance().setStatus(checkInStatus(employee, target, now));
        Attendance savedIn = attendanceRepository.save(target.attendance());
        auditAttendance("ATTENDANCE_MANUAL_CHECK_IN", savedIn, com.bosskin.audit.AuditService.map(
            "employeeId", employee.getId(), "date", savedIn.getDate(), "checkIn", savedIn.getCheckIn()));
        return ResponseEntity.status(HttpStatus.CREATED).body(AttendanceDTO.Response.from(savedIn));
    }

    @GetMapping("/self/today")
    public ResponseEntity<AttendanceDTO.SelfTodayResponse> getSelfToday(
        @AuthenticationPrincipal User user,
        Locale locale,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        requirePermission(user, "ATTENDANCE_SELF");
        return ResponseEntity.ok(buildSelfToday(user, date, locale));
    }

    @GetMapping("/self/history")
    public ResponseEntity<List<AttendanceDTO.Response>> getSelfHistory(
        @AuthenticationPrincipal User user,
        @RequestParam int year,
        @RequestParam int month
    ) {
        requirePermission(user, "ATTENDANCE_SELF");
        var employee = getSelfEmployee(user);
        var period = PayrollPeriod.of(year, month, employee.getCompany().getPayrollCutoffDay());
        List<AttendanceDTO.Response> history = attendanceRepository
            .findApprovedByEmployeeAndDateRange(employee.getId(), period.from(), period.to())
            .stream()
            .map(AttendanceDTO.Response::from)
            .toList();
        return ResponseEntity.ok(history);
    }

    @PatchMapping("/self/setting")
    public ResponseEntity<AttendanceDTO.SelfTodayResponse> updateSelfAttendanceSetting(
        @AuthenticationPrincipal User user,
        Locale locale,
        @RequestBody Map<String, Boolean> body) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        boolean enabled = Boolean.TRUE.equals(body.get("enabled"));
        Company company = getSelfCompany(user);
        company.setSelfAttendanceEnabled(enabled);
        companyRepository.save(company);
        return ResponseEntity.ok(buildSelfToday(user, null, locale));
    }

    @Transactional
    @PostMapping("/self/check-in")
    public ResponseEntity<AttendanceDTO.SelfTodayResponse> selfCheckIn(
            @AuthenticationPrincipal User user,
            @RequestBody(required = false) Map<String, Object> body,
            @RequestHeader(value = "X-Device-ID", required = false) String deviceId,
            Locale locale) {
        requirePermission(user, "ATTENDANCE_SELF");
        var employee = getSelfEmployee(user);
        validateSelfAttendanceEnabled(user);
        LocalDateTime now = LocalDateTime.now(clock);
        ShiftTarget target = requireCheckInTarget(employee, getSelfCompany(user), now);
        periodLockService.requireOpen(user.getCompany().getId(), target.attendance().getDate());
        Attendance.Status status = checkInStatus(employee, target, now);
        Double lat = numberOrNull(body, "latitude");
        Double lng = numberOrNull(body, "longitude");
        validateGpsSignal(employee, body);
        requireBoundDevice(employee, deviceId);
        validateCheckInLocation(employee, lat, lng);
        target.attendance().setCheckIn(now);
        target.attendance().setStatus(status);
        target.attendance().setCheckInLatitude(lat);
        target.attendance().setCheckInLongitude(lng);
        attendanceRepository.save(target.attendance());
        return ResponseEntity.status(HttpStatus.CREATED).body(buildSelfToday(user, null, locale));
    }

    @Transactional
    @PostMapping("/self/check-out")
    public ResponseEntity<AttendanceDTO.SelfTodayResponse> selfCheckOut(
            @AuthenticationPrincipal User user,
            @RequestBody(required = false) Map<String, Object> body,
            @RequestHeader(value = "X-Device-ID", required = false) String deviceId,
            Locale locale) {
        requirePermission(user, "ATTENDANCE_SELF");
        var employee = getSelfEmployee(user);
        validateSelfAttendanceEnabled(user);
        LocalDateTime checkOut = LocalDateTime.now(clock);
        ShiftTarget target = requireCheckOutTarget(employee, getSelfCompany(user), checkOut);
        periodLockService.requireOpen(user.getCompany().getId(), target.attendance().getDate());
        Double lat = numberOrNull(body, "latitude");
        Double lng = numberOrNull(body, "longitude");
        validateGpsSignal(employee, body);
        requireBoundDevice(employee, deviceId);
        validateCheckInLocation(employee, lat, lng);
        target.attendance().setCheckOut(checkOut);
        target.attendance().setCheckOutLatitude(lat);
        target.attendance().setCheckOutLongitude(lng);
        attendanceRepository.save(target.attendance());
        return ResponseEntity.ok(buildSelfToday(user, null, locale));
    }

    @PostMapping("/check-out")
    public ResponseEntity<AttendanceDTO.Response> checkOut(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Long> body) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Long employeeId = body.get("employeeId");
        LocalDate today = LocalDate.now(clock);

        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment().getId());

        LocalDateTime now = LocalDateTime.now(clock);
        ShiftTarget target = requireCheckOutTarget(employee, getSelfCompany(user), now);
        periodLockService.requireOpen(user.getCompany().getId(), target.attendance().getDate());
        target.attendance().setCheckOut(now);
        Attendance savedOut = attendanceRepository.save(target.attendance());
        auditAttendance("ATTENDANCE_MANUAL_CHECK_OUT", savedOut, com.bosskin.audit.AuditService.map(
            "employeeId", employee.getId(), "date", savedOut.getDate(), "checkOut", savedOut.getCheckOut()));
        return ResponseEntity.ok(AttendanceDTO.Response.from(savedOut));
    }

    private AttendanceDTO.SelfTodayResponse buildSelfToday(User user) {
        return buildSelfToday(user, null, Locale.getDefault());
    }

    private AttendanceDTO.SelfTodayResponse buildSelfToday(User user, LocalDate targetDate) {
        return buildSelfToday(user, targetDate, Locale.getDefault());
    }

    private AttendanceDTO.SelfTodayResponse buildSelfToday(User user, LocalDate targetDate, Locale locale) {
        Company company = user != null ? getSelfCompany(user) : null;
        if (user == null || user.getEmployee() == null) {
            return AttendanceDTO.SelfTodayResponse.builder()
                .enabled(company != null && company.isSelfAttendanceEnabled())
                .message("attendanceAccountNotLinked")
                .build();
        }

        var employee = getSelfEmployee(user);
        LocalDate today = LocalDate.now(clock);
        LocalDate date = targetDate != null ? targetDate : today;
        boolean enabled = company.isSelfAttendanceEnabled();
        LocalTime now = LocalTime.now(clock);
        boolean isToday = date.equals(today);

        // Load shifts của ngày hiện tại
        List<ShiftWindow> shifts = getShiftWindows(employee.getId(), date, company);
        List<ShiftAssignment> assignments = shiftAssignmentRepository
            .findByEmployeeIdAndWorkDateWithShift(employee.getId(), date)
            .stream().sorted(this::compareAssignments).toList();
        List<Attendance> attendances = attendanceRepository.findByEmployeeIdAndDate(employee.getId(), date);
        Map<Long, Attendance> attByShift = attendances.stream()
            .filter(a -> a.getShiftAssignment() != null)
            .collect(Collectors.toMap(a -> a.getShiftAssignment().getId(), a -> a, (a, b) -> a));
        Attendance noShiftAtt = attendances.stream().filter(a -> a.getShiftAssignment() == null).findFirst().orElse(null);
        Attendance attendance = attendances.isEmpty() ? null : attendances.get(0);

        // Hôm nay: ca qua đêm của hôm qua còn trong khung giờ thì hiển thị ca đó (A3/A4).
        // Nút check-in/out tính theo thời gian tuyệt đối của từng ca, giống endpoint check-in/out.
        ShiftWindow shift = shifts.isEmpty() ? null : shifts.get(0);
        boolean canCheckIn = false;
        boolean canCheckOut = false;
        if (isToday) {
            LocalDateTime nowDt = LocalDateTime.now(clock);
            Slot activeOvernight = candidateSlots(employee, company, today).stream()
                .filter(sl -> sl.workDate().isBefore(today))
                .filter(sl -> !nowDt.isBefore(sl.checkInFrom()) && !nowDt.isAfter(sl.checkOutTo()))
                .findFirst().orElse(null);
            if (activeOvernight != null) {
                shifts = List.of(activeOvernight.sw());
                shift = activeOvernight.sw();
                date = activeOvernight.workDate();
                attendance = findExistingAttendance(employee, date, activeOvernight.sa());
            }
            canCheckIn = findCheckInTarget(employee, company, nowDt) != null;
            canCheckOut = findCheckOutTarget(employee, company, nowDt) != null;
        }

        String message = null;
        if (!enabled) {
            message = localizedCheckInOutDisabledMessage(locale);
        } else if (shift == null) {
            // V25: không có ca nhưng công ty cho chấm không cần ca → báo công tính theo giờ thực tế
            message = isToday && company.isCheckInWithoutShift()
                ? "attendanceNoShiftFreeCheckIn" : localizedNoShiftMessage(locale, isToday);
        }

        List<AttendanceDTO.AllowedLocation> allowedLocations = resolveAllowedLocations(employee);

        return AttendanceDTO.SelfTodayResponse.builder()
            .enabled(enabled)
            .message(message)
            .employeeId(employee.getId())
            .employeeName(employee.getFullName())
            .date(date)
            .shift(shift != null ? shift.toDto() : null)
            .shifts(shifts.stream().map(ShiftWindow::toDto).toList())
            .attendance(attendance != null ? AttendanceDTO.Response.from(attendance) : null)
            .canCheckIn(isToday && enabled && canCheckIn)
            .canCheckOut(isToday && enabled && canCheckOut)
            .allowedLocations(allowedLocations)
            .build();
    }

    private String localizedCheckInOutDisabledMessage(Locale locale) {
        return "attendanceCheckInOutDisabled";
    }

    private String localizedNoShiftMessage(Locale locale, boolean isToday) {
        return isToday ? "attendanceNoShiftsToday" : "attendanceNoShiftsOnDate";
    }

    private boolean isEnglish(Locale locale) {
        return locale != null && "en".equalsIgnoreCase(locale.getLanguage());
    }

    private Employee getSelfEmployee(User user) {
        if (user == null || user.getEmployee() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.employee_not_linked");
        }
        return employeeRepository.findById(user.getEmployee().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private Company getSelfCompany(User user) {
        if (user == null || user.getCompany() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "error.auth.invalid_session");
        }
        return companyRepository.findById(user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
    }

    private void validateSelfAttendanceEnabled(User user) {
        if (!getSelfCompany(user).isSelfAttendanceEnabled()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.self_check_disabled");
        }
    }

    private ShiftWindow getShiftWindowOrThrow(Long employeeId, LocalDate date) {
        ShiftWindow shift = getShiftWindow(employeeId, date);
        if (shift == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.no_shift_today");
        }
        return shift;
    }

    private ShiftWindow getShiftWindow(Long employeeId, LocalDate date) {
        List<ShiftWindow> windows = getShiftWindows(employeeId, date);
        return windows.isEmpty() ? null : windows.get(0);
    }

    private Attendance getOrCreateAttendanceForShift(Employee employee, LocalDate date, ShiftAssignment sa) {
        Long saId = sa != null ? sa.getId() : null;
        if (saId != null) {
            return attendanceRepository.findByEmployeeIdAndDateAndShift(employee.getId(), date, saId)
                .orElseGet(() -> Attendance.builder()
                    .employee(employee)
                    .shiftAssignment(sa)
                    .date(date)
                    .status(Attendance.Status.PRESENT)
                    .build());
        }
        return attendanceRepository.findByEmployeeIdAndDate(employee.getId(), date).stream()
            .filter(a -> a.getShiftAssignment() == null)
            .findFirst()
            .orElseGet(() -> Attendance.builder()
                .employee(employee)
                .date(date)
                .status(Attendance.Status.PRESENT)
                .build());
    }

    private Comparator<ShiftAssignment> saComparator() {
        return (a, b) -> compareAssignments(a, b);
    }

    private List<ShiftWindow> getShiftWindows(Long employeeId, LocalDate date) {
        Company company = employeeRepository.findById(employeeId)
            .map(e -> companyRepository.findById(e.getCompany().getId()).orElse(null))
            .orElse(null);
        return getShiftWindows(employeeId, date, company);
    }

    private List<ShiftWindow> getShiftWindows(Long employeeId, LocalDate date, Company company) {
        return shiftAssignmentRepository.findByEmployeeIdAndWorkDateWithShift(employeeId, date)
            .stream()
            .map(sa -> toShiftWindow(sa, company))
            .filter(java.util.Objects::nonNull)
            .sorted(Comparator.comparing(ShiftWindow::startTime).thenComparing(ShiftWindow::endTime))
            .toList();
    }

    /**
     * Một ca cụ thể theo thời gian tuyệt đối. Ca qua đêm (giờ kết thúc <= giờ bắt đầu)
     * kết thúc vào ngày hôm sau; ngày công ({@code workDate}) luôn là ngày bắt đầu ca.
     */
    private record Slot(LocalDate workDate, ShiftAssignment sa, ShiftWindow sw,
                        LocalDateTime start, LocalDateTime end) {
        LocalDateTime checkInFrom() { return start.minusMinutes(sw.checkInBeforeMinutes()); }
        LocalDateTime checkInTo()   {
            // Ca linh hoạt: vào muộn nhất là lúc còn vừa đủ số phút phải làm trước giờ đóng khung (Mốc 2b)
            Integer req = sa != null ? sa.flexibleRequiredMinutes() : null;
            if (req != null) {
                LocalDateTime latest = end.minusMinutes(req);
                return latest.isAfter(start) ? latest : start.plusMinutes(sw.checkInAfterMinutes());
            }
            return start.plusMinutes(sw.checkInAfterMinutes());
        }
        LocalDateTime checkOutTo()  { return end.plusMinutes(sw.checkOutAfterMinutes()); }
    }

    private record ShiftTarget(Attendance attendance, ShiftAssignment shiftAssignment, ShiftWindow shift,
                               LocalDateTime shiftStart) {}

    /** Các ca của hôm qua và hôm nay (đủ để bắt ca qua đêm), sắp theo giờ bắt đầu. */
    private List<Slot> candidateSlots(Employee employee, Company company, LocalDate today) {
        List<Slot> slots = new ArrayList<>();
        for (LocalDate d : List.of(today.minusDays(1), today)) {
            for (ShiftAssignment sa : shiftAssignmentRepository.findByEmployeeIdAndWorkDateWithShift(employee.getId(), d)) {
                ShiftWindow sw = toShiftWindow(sa, company);
                if (sw == null) continue;
                LocalDateTime start = d.atTime(sw.startTime());
                LocalDateTime end = sw.endTime().isAfter(sw.startTime())
                    ? d.atTime(sw.endTime())
                    : d.plusDays(1).atTime(sw.endTime());
                slots.add(new Slot(d, sa, sw, start, end));
            }
        }
        slots.sort(Comparator.comparing(Slot::start));
        return slots;
    }

    private Attendance findExistingAttendance(Employee employee, LocalDate date, ShiftAssignment sa) {
        if (sa != null) {
            return attendanceRepository.findByEmployeeIdAndDateAndShift(employee.getId(), date, sa.getId()).orElse(null);
        }
        return attendanceRepository.findByEmployeeIdAndDate(employee.getId(), date).stream()
            .filter(a -> a.getShiftAssignment() == null).findFirst().orElse(null);
    }

    /** Ca đầu tiên đang trong khung check-in mà chưa check-in; null nếu không có. */
    /**
     * Trạng thái công khi duyệt — luôn tính lại, không để rỗng (A5).
     * Không có giờ công/check-in: nghỉ phép đã duyệt → LEAVE (L1), còn lại → ABSENT.
     * Có giờ công: so giờ vào với giờ bắt đầu ca + dung sai → PRESENT / LATE.
     */
    private Attendance.Status approvedStatus(Attendance att, boolean hasHours, boolean hasCheckIn,
                                             LeaveRequest slotLeave, AttendanceRowData data, AttendancePolicy policy) {
        if (!hasHours && !hasCheckIn) {
            return slotLeave != null ? Attendance.Status.LEAVE : Attendance.Status.ABSENT;
        }
        if (att.getStatus() == Attendance.Status.HALF_DAY) return Attendance.Status.HALF_DAY;
        LocalTime in = data.checkIn();
        LocalTime start = data.shiftStart();
        if (in == null || start == null) return Attendance.Status.PRESENT;
        int tolerance = policy.checkInToleranceMinutes() != null ? policy.checkInToleranceMinutes() : 15;
        int diff = (in.toSecondOfDay() / 60 - start.toSecondOfDay() / 60 + 1440) % 1440;
        if (diff > 720) diff -= 1440; // vào trước giờ bắt đầu (kể cả ca qua nửa đêm)
        return diff > tolerance ? Attendance.Status.LATE : Attendance.Status.PRESENT;
    }

    private static Double numberOrNull(Map<String, Object> body, String key) {
        Object v = body != null ? body.get(key) : null;
        return v instanceof Number n ? n.doubleValue() : null;
    }

    /**
     * Gắn thiết bị (V6): công ty bật thì chỉ chấm được trên thiết bị đã gắn. Lần đầu (chưa gắn)
     * tự gắn thiết bị đang dùng; khác thiết bị → 403, quản lý gỡ gắn khi nhân viên đổi máy.
     */
    private void requireBoundDevice(Employee employee, String deviceId) {
        if (!employee.getCompany().isDeviceBindingEnabled()) return;
        if (deviceId == null || deviceId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.device_missing");
        }
        if (employee.getBoundDeviceId() == null) {
            employee.setBoundDeviceId(deviceId.trim());
            employee.setBoundDeviceAt(LocalDateTime.now(clock));
            employeeRepository.save(employee);
            return;
        }
        if (!employee.getBoundDeviceId().equals(deviceId.trim())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.device_not_bound");
        }
    }

    /** Sai số GPS tối đa (mét) khi công ty bật kiểm vị trí. */
    private static final double MAX_GPS_ACCURACY_METERS = 150;

    /**
     * Chống gian lận vị trí (A19): từ chối toạ độ giả lập (app báo isMocked) và toạ độ
     * quá thiếu chính xác khi công ty bật kiểm vị trí.
     */
    private void validateGpsSignal(Employee employee, Map<String, Object> body) {
        if (body != null && Boolean.TRUE.equals(body.get("isMocked"))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.mock_location");
        }
        Double accuracy = numberOrNull(body, "accuracy");
        if (accuracy != null && accuracy > MAX_GPS_ACCURACY_METERS
            && employee.getCompany().isLocationCheckEnabled()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.gps_inaccurate");
        }
    }

    private ShiftTarget findCheckInTarget(Employee employee, Company company, LocalDateTime now) {
        for (Slot sl : candidateSlots(employee, company, now.toLocalDate())) {
            if (now.isBefore(sl.checkInFrom()) || now.isAfter(sl.checkInTo())) continue;
            Attendance att = getOrCreateAttendanceForShift(employee, sl.workDate(), sl.sa());
            if (att.getCheckIn() == null) return new ShiftTarget(att, sl.sa(), sl.sw(), sl.start());
        }
        if (isFreeCheckInDay(employee, company, now)) {
            Attendance att = getOrCreateAttendanceForShift(employee, now.toLocalDate(), null);
            if (att.getCheckIn() == null) return new ShiftTarget(att, null, null, null);
        }
        return null;
    }

    /** Giờ tối đa từ lúc chấm vào không theo ca tới lúc chấm ra (quá thì coi như quên chấm ra, quản lý sửa công). */
    private static final int MAX_NO_SHIFT_HOURS = 24;

    /**
     * V25: công ty bật "chấm công không cần xếp ca", hôm nay nhân viên không có ca nào và không đang trong khung
     * của ca qua đêm hôm qua → được chấm vào / ra một lần trong ngày, công không gắn ca.
     */
    private boolean isFreeCheckInDay(Employee employee, Company company, LocalDateTime now) {
        if (company == null || !company.isCheckInWithoutShift()) return false;
        if (!shiftAssignmentRepository.findByEmployeeIdAndWorkDateWithShift(employee.getId(), now.toLocalDate()).isEmpty()) {
            return false;
        }
        return candidateSlots(employee, company, now.toLocalDate()).stream()
            .noneMatch(sl -> !now.isBefore(sl.checkInFrom()) && !now.isAfter(sl.checkOutTo()));
    }

    /** Công không theo ca (hôm nay hoặc hôm qua) đã chấm vào, chưa chấm ra, trong {@link #MAX_NO_SHIFT_HOURS} giờ. */
    private ShiftTarget findNoShiftCheckOutTarget(Employee employee, Company company, LocalDateTime now) {
        if (company == null || !company.isCheckInWithoutShift()) return null;
        for (LocalDate d : List.of(now.toLocalDate(), now.toLocalDate().minusDays(1))) {
            Attendance att = findExistingAttendance(employee, d, null);
            if (att != null && att.getCheckIn() != null && att.getCheckOut() == null
                && !now.isBefore(att.getCheckIn()) && !now.isAfter(att.getCheckIn().plusHours(MAX_NO_SHIFT_HOURS))) {
                return new ShiftTarget(att, null, null, null);
            }
        }
        return null;
    }

    /**
     * Ca đã check-in, chưa check-out, và chưa quá hạn check-out (giờ kết thúc + khung sau).
     * Cho phép check-out bất kỳ lúc nào sau check-in — về sớm được ghi nhận, không bị chặn (A14).
     */
    private ShiftTarget findCheckOutTarget(Employee employee, Company company, LocalDateTime now) {
        for (Slot sl : candidateSlots(employee, company, now.toLocalDate())) {
            if (now.isAfter(sl.checkOutTo())) continue;
            Attendance att = findExistingAttendance(employee, sl.workDate(), sl.sa());
            if (att != null && att.getCheckIn() != null && att.getCheckOut() == null
                && !now.isBefore(att.getCheckIn())) {
                return new ShiftTarget(att, sl.sa(), sl.sw(), sl.start());
            }
        }
        return findNoShiftCheckOutTarget(employee, company, now);
    }

    private ShiftTarget requireCheckInTarget(Employee employee, Company company, LocalDateTime now) {
        ShiftTarget t = findCheckInTarget(employee, company, now);
        if (t != null) return t;
        if (isFreeCheckInDay(employee, company, now)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.already_checked_in");
        }
        if (candidateSlots(employee, company, now.toLocalDate()).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.no_shift_today");
        }
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.outside_check_in_window");
    }

    private ShiftTarget requireCheckOutTarget(Employee employee, Company company, LocalDateTime now) {
        ShiftTarget t = findCheckOutTarget(employee, company, now);
        if (t != null) return t;
        if (isFreeCheckInDay(employee, company, now)) {
            Attendance att = findExistingAttendance(employee, now.toLocalDate(), null);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, att != null && att.getCheckOut() != null
                ? "error.attendance.already_checked_out" : "error.attendance.not_checked_in");
        }
        if (candidateSlots(employee, company, now.toLocalDate()).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.no_shift_today");
        }
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.outside_check_out_window");
    }

    /** Đi muộn khi check-in sau giờ bắt đầu ca + dung sai (phòng ban → công ty → mặc định 15 phút) (A13). */
    private Attendance.Status checkInStatus(Employee employee, ShiftTarget target, LocalDateTime now) {
        // Công không theo ca (V25): không có giờ bắt đầu để xét đi muộn
        if (target.shiftStart() == null) return Attendance.Status.PRESENT;
        // Ca linh hoạt: vào lúc nào trong khung cũng đúng giờ; thiếu giờ xét khi duyệt (Mốc 2b)
        if (target.shiftAssignment() != null && target.shiftAssignment().flexibleRequiredMinutes() != null) {
            return Attendance.Status.PRESENT;
        }
        Integer tol = resolveAttendancePolicy(employee).checkInToleranceMinutes();
        int tolerance = tol != null ? tol : 15;
        return now.isAfter(target.shiftStart().plusMinutes(tolerance))
            ? Attendance.Status.LATE : Attendance.Status.PRESENT;
    }

    private ShiftWindow toShiftWindow(ShiftAssignment sa, Company company) {
        LocalTime start;
        LocalTime end;
        String name;
        String color;
        Long id = sa.getId();

        if (sa.isCustom()) {
            start = sa.getCustomStartTime();
            end = sa.getCustomEndTime();
            name = "Tùy chỉnh";
            color = "#1976D2";
        } else if (sa.getShift() != null) {
            var shift = sa.getShift();
            start = sa.effectiveStartTime();
            end = sa.effectiveEndTime();
            name = shift.getName();
            color = shift.getColor();
        } else {
            return null;
        }
        if (start == null || end == null) return null;
        int ciBefore = company != null ? company.getCheckInBeforeMinutes() : 30;
        int ciAfter  = company != null ? company.getCheckInAfterMinutes()  : 30;
        int coBefore = company != null ? company.getCheckOutBeforeMinutes() : 30;
        int coAfter  = company != null ? company.getCheckOutAfterMinutes()  : 30;
        return new ShiftWindow(id, name, color, start, end, ciBefore, ciAfter, coBefore, coAfter);
    }


    private void requireWithinWindow(LocalTime now, LocalTime from, LocalTime to, String message) {
        if (!isWithinWindow(now, from, to)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, message);
        }
    }

    private boolean isWithinWindow(LocalTime now, LocalTime from, LocalTime to) {
        if (from == null || to == null) {
            return false;
        }
        if (from.equals(to)) {
            return true;
        }
        if (from.isBefore(to) || from.equals(to)) {
            return !now.isBefore(from) && !now.isAfter(to);
        }
        return !now.isBefore(from) || !now.isAfter(to);
    }

    private record ShiftWindow(Long id, String name, String color, LocalTime startTime, LocalTime endTime,
                               int checkInBeforeMinutes, int checkInAfterMinutes,
                               int checkOutBeforeMinutes, int checkOutAfterMinutes) {
        LocalTime checkInFrom() { return startTime.minusMinutes(checkInBeforeMinutes); }
        LocalTime checkInTo() { return startTime.plusMinutes(checkInAfterMinutes); }
        LocalTime checkOutFrom() { return endTime.minusMinutes(checkOutBeforeMinutes); }
        LocalTime checkOutTo() { return endTime.plusMinutes(checkOutAfterMinutes); }

        AttendanceDTO.ShiftInfo toDto() {
            return AttendanceDTO.ShiftInfo.builder()
                .id(id)
                .name(name)
                .color(color)
                .startTime(startTime)
                .endTime(endTime)
                .checkInFrom(checkInFrom())
                .checkInTo(checkInTo())
                .checkOutFrom(checkOutFrom())
                .checkOutTo(checkOutTo())
                .build();
        }
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    /**
     * Người duyệt/bỏ duyệt công (A1): có quyền ATTENDANCE_APPROVE (kiểm ở endpoint),
     * nhân viên nằm trong phạm vi xem, và không phải công của chính mình.
     */
    private void requireCanApprove(User user, Employee employee) {
        requireViewScope(user, employee.getDepartment().getId());
        requireNotOwnAttendance(user, employee);
    }

    private void requireNotOwnAttendance(User user, Employee employee) {
        if (user.getEmployee() != null && user.getEmployee().getId().equals(employee.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.attendance.cannot_approve_own");
        }
    }

    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    /** Trả về danh sách vị trí cho phép theo thứ tự ưu tiên. null = tự do (không cấu hình hoặc tắt). */
    private List<AttendanceDTO.AllowedLocation> resolveAllowedLocations(Employee employee) {
        if (!employee.getCompany().isLocationCheckEnabled()) return null;
        // 1. Employee locations
        List<EmployeeLocation> empLocs = employeeLocationRepository.findByEmployeeId(employee.getId());
        if (!empLocs.isEmpty()) {
            return empLocs.stream().map(loc -> AttendanceDTO.AllowedLocation.builder()
                    .latitude(loc.getLatitude())
                    .longitude(loc.getLongitude())
                    .radiusMeters(loc.getRadiusMeters())
                    .source("employee")
                    .build()).toList();
        }
        // 2. Department tree
        Department dept = employee.getDepartment();
        while (dept != null) {
            if (dept.getCheckInLatitude() != null) {
                return List.of(AttendanceDTO.AllowedLocation.builder()
                        .latitude(dept.getCheckInLatitude())
                        .longitude(dept.getCheckInLongitude())
                        .radiusMeters(dept.getCheckInRadiusMeters())
                        .source("department")
                        .build());
            }
            dept = dept.getParent();
        }
        // 3. Company
        Company company = employee.getCompany();
        if (company.getCheckInLatitude() != null) {
            return List.of(AttendanceDTO.AllowedLocation.builder()
                    .latitude(company.getCheckInLatitude())
                    .longitude(company.getCheckInLongitude())
                    .radiusMeters(company.getCheckInRadiusMeters())
                    .source("company")
                    .build());
        }
        return null; // tự do
    }

    private void validateCheckInLocation(Employee employee, Double lat, Double lng) {
        if (!employee.getCompany().isLocationCheckEnabled()) return; // tính năng tắt → không cần GPS
        if (lat == null || lng == null)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.location_required");

        // 1. Employee locations (ưu tiên cao nhất)
        List<EmployeeLocation> empLocs = employeeLocationRepository.findByEmployeeId(employee.getId());
        if (!empLocs.isEmpty()) {
            boolean ok = empLocs.stream().anyMatch(loc ->
                    haversineMeters(lat, lng, loc.getLatitude(), loc.getLongitude()) <= loc.getRadiusMeters());
            if (!ok) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.attendance.out_of_range");
            return;
        }

        // 2. Walk up department tree
        Department dept = employee.getDepartment();
        while (dept != null) {
            if (dept.getCheckInLatitude() != null) {
                if (haversineMeters(lat, lng, dept.getCheckInLatitude(), dept.getCheckInLongitude())
                        > dept.getCheckInRadiusMeters()) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "error.attendance.out_of_department_range|" + dept.getName());
                }
                return;
            }
            dept = dept.getParent();
        }

        // 3. Company
        Company company = employee.getCompany();
        if (company.getCheckInLatitude() != null) {
            if (haversineMeters(lat, lng, company.getCheckInLatitude(), company.getCheckInLongitude())
                    > company.getCheckInRadiusMeters()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "error.attendance.out_of_company_range");
            }
        }
        // else: không có cấu hình → tự do
    }

    // ── Excel Export / Import ────────────────────────────────────────────────

    @GetMapping("/export-timesheet")
    public ResponseEntity<byte[]> exportTimesheetExcel(
            @AuthenticationPrincipal User user,
            @RequestParam Long employeeId,
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate to) {
        requirePermission(user, "ATTENDANCE_VIEW");
        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        if (scopeIds.contains(-1L)) {
            if (!employeeId.equals(getSelfEmployee(user).getId()))
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        } else {
            requireViewScope(user, employee.getDepartment().getId());
        }
        var company = employee.getCompany();
        List<AttendanceDTO.TimesheetRow> rows = timesheetRowsFor(employee, from, to);
        return attendanceExcelService.exportTimesheetRange(
            user.getCompany().getId(), user.getId(),
            employee.getFullName(), employee.getEmployeeCode(), from, to, rows,
            company.isAttendanceDayNightMode(), company.isAttendanceOtEnabled(), LocaleContextHolder.getLocale());
    }

    /** Các dòng bảng công của một NV (giống màn hình / file xuất) — dùng khi xuất và khi so sánh lúc nhập lại. */
    private List<AttendanceDTO.TimesheetRow> timesheetRowsFor(Employee employee, LocalDate from, LocalDate to) {
        Long employeeId = employee.getId();
        var company = employee.getCompany();
        LocalTime dayStart = company.isAttendanceDayNightMode() && company.getDayStartTime() != null
            ? company.getDayStartTime() : (company.isAttendanceDayNightMode() ? LocalTime.of(6,0) : LocalTime.MIDNIGHT);
        LocalTime dayEnd = company.isAttendanceDayNightMode() && company.getDayEndTime() != null
            ? company.getDayEndTime() : (company.isAttendanceDayNightMode() ? LocalTime.of(22,0) : LocalTime.of(23,59));
        Map<LocalDate, List<Attendance>> attMap = attendanceRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(Attendance::getDate));
        Map<LocalDate, List<com.bosskin.entity.AttendanceRequest>> requestMap = attendanceRequestRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(com.bosskin.entity.AttendanceRequest::getRequestDate));
        Map<LocalDate, List<ShiftAssignment>> shiftMap = shiftAssignmentRepository
            .findByEmployeeAndDateRange(employeeId, from, to)
            .stream().collect(Collectors.groupingBy(ShiftAssignment::getWorkDate));
        Map<LocalDate, LeaveRequest> leaveMap = new java.util.HashMap<>();
        for (LeaveRequest lr : leaveRequestV2Repository.findApprovedByEmployeeAndDateRange(employeeId, from, to)) {
            for (LocalDate d = lr.getFromDate(); !d.isAfter(lr.getToDate()); d = d.plusDays(1))
                leaveMap.putIfAbsent(d, lr);
        }
        boolean otEnabled = company.isAttendanceOtEnabled();
        AttendancePolicy policy = resolveAttendancePolicy(employee);
        List<AttendanceDTO.TimesheetRow> rows = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1))
            rows.addAll(buildTimesheetRows(d, attMap.getOrDefault(d, List.of()), shiftMap.get(d), requestMap.get(d), leaveMap.get(d), dayStart, dayEnd, otEnabled, policy));
        markCalendar(rows, employee, from, to);
        return rows;
    }

    @GetMapping("/export-day-view")
    public ResponseEntity<byte[]> exportDayView(
            @AuthenticationPrincipal User user,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) Long departmentId) {
        requirePermission(user, "ATTENDANCE_VIEW");
        Company company = getSelfCompany(user);
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "ATTENDANCE_VIEW");
        List<Employee> employees = resolveDayViewEmployees(user, company, departmentId, scopeIds);
        if (employees.isEmpty()) {
            return attendanceExcelService.exportDayView(user.getCompany().getId(), user.getId(),
                date, List.of(),
                company.isAttendanceDayNightMode(), company.isAttendanceOtEnabled(),
                LocaleContextHolder.getLocale());
        }

        LocalTime dayStart, dayEnd;
        if (company.isAttendanceDayNightMode()) {
            dayStart = company.getDayStartTime() != null ? company.getDayStartTime() : LocalTime.of(6, 0);
            dayEnd   = company.getDayEndTime()   != null ? company.getDayEndTime()   : LocalTime.of(22, 0);
        } else {
            dayStart = LocalTime.MIDNIGHT;
            dayEnd   = LocalTime.of(23, 59);
        }

        Map<Long, List<Attendance>> attMap = attendanceRepository.findByCompanyAndDate(company.getId(), date)
            .stream().collect(Collectors.groupingBy(a -> a.getEmployee().getId()));
        Map<Long, List<AttendanceRequest>> requestMap = attendanceRequestRepository
            .findByCompanyAndRequestDate(company.getId(), date)
            .stream().collect(Collectors.groupingBy(r -> r.getEmployee().getId()));
        Map<Long, List<ShiftAssignment>> shiftMap = shiftAssignmentRepository
            .findByCompanyAndDate(company.getId(), date)
            .stream().collect(Collectors.groupingBy(sa -> sa.getEmployee().getId()));
        Map<Long, List<LeaveRequest>> leaveMap = leaveRequestV2Repository
            .findApprovedByCompanyAndDate(company.getId(), date)
            .stream().collect(Collectors.groupingBy(lr -> lr.getEmployee().getId()));

        boolean otEnabled = company.isAttendanceOtEnabled();
        List<AttendanceDTO.DayViewRow> rows = employees.stream()
            .flatMap(employee -> buildDayViewRows(
                employee, date,
                attMap.getOrDefault(employee.getId(), List.of()),
                shiftMap.get(employee.getId()),
                requestMap.get(employee.getId()),
                leaveMap.getOrDefault(employee.getId(), List.of()),
                dayStart, dayEnd, otEnabled,
                resolveAttendancePolicy(employee)
            ).stream())
            .toList();
        markCalendarDay(rows, company.getId(), date);

        return attendanceExcelService.exportDayView(user.getCompany().getId(), user.getId(),
            date, rows,
            company.isAttendanceDayNightMode(), otEnabled, LocaleContextHolder.getLocale());
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> exportExcel(
            @AuthenticationPrincipal User user,
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate from,
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate to,
            @RequestParam(required = false) List<Long> departmentIds) {
        requirePermission(user, "ATTENDANCE_VIEW");
        return attendanceExcelService.exportAttendance(
            user.getCompany().getId(), user.getId(), from, to, departmentIds);
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<AttendanceExcelService.AttendanceDiff>> previewImport(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "ATTENDANCE_VIEW");
        return ResponseEntity.ok(
            attendanceExcelService.previewImport(user.getCompany().getId(), user.getId(), file));
    }

    @PostMapping("/import")
    public ResponseEntity<Map<String, Integer>> importExcel(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Map<String, Integer> res = attendanceExcelService.importAttendance(user.getCompany().getId(), user.getId(), file);
        audit.log("ATTENDANCE_IMPORT").summary(file.getOriginalFilename()).detail(res).save();
        return ResponseEntity.ok(res);
    }

    @PostMapping("/preview-import-timesheet")
    public ResponseEntity<List<AttendanceExcelService.AttendanceDiff>> previewImportTimesheet(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "ATTENDANCE_VIEW");
        return ResponseEntity.ok(
            attendanceExcelService.previewImportTimesheet(user.getCompany().getId(), user.getId(), file, this::timesheetRowsFor));
    }

    @PostMapping("/import-timesheet")
    public ResponseEntity<Map<String, Integer>> importTimesheet(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        requirePermission(user, "ATTENDANCE_APPROVE"); // import bảng công ghi luôn trạng thái đã duyệt
        Map<String, Integer> result = new java.util.HashMap<>(
            attendanceExcelService.importTimesheet(user.getCompany().getId(), user.getId(), file, this::timesheetRowsFor));

        // Xử lý approve/unapprove cho các row có trạng thái duyệt thay đổi
        List<AttendanceExcelService.ApproveTask> approveTasks = attendanceExcelService.getLastImportApproveTasks();
        // A18: mỗi dòng duyệt/bỏ duyệt trong transaction riêng — một dòng lỗi không làm
        // hỏng cả lần import (trước đây lỗi trong cùng transaction → UnexpectedRollbackException)
        var perRow = new org.springframework.transaction.support.TransactionTemplate(transactionManager);
        perRow.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        int approved = 0, approveFailed = 0;
        for (AttendanceExcelService.ApproveTask task : approveTasks) {
            try {
                Boolean done = perRow.execute(status -> {
                    Attendance att = attendanceRepository.findById(task.attendanceId()).orElse(null);
                    if (att == null) return false;
                    requireNotOwnAttendance(user, att.getEmployee());
                    if (task.approve()) {
                        doApprove(att, user);
                    } else {
                        att.setApproved(false);
                        att.setApprovedAt(null); att.setApprovedBy(null);
                        att.setSnapActualHours(null); att.setSnapDayHours(null);
                        att.setSnapDayOt(null); att.setSnapNightHours(null);
                        att.setSnapNightOt(null); att.setWorkFlags(null);
                        attendanceRepository.save(att);
                    }
                    return true;
                });
                if (Boolean.TRUE.equals(done)) approved++;
            } catch (Exception e) {
                approveFailed++;
            }
        }
        if (approved > 0) result.put("approved", approved);
        if (approveFailed > 0) result.put("approveFailed", approveFailed);
        audit.log("ATTENDANCE_IMPORT_TIMESHEET").summary(file.getOriginalFilename()).detail(result).save();
        return ResponseEntity.ok(result);
    }

    private void doApprove(Attendance att, User user) {
        Long employeeId = att.getEmployee().getId();
        LocalDate date  = att.getDate();
        ShiftAssignment sa = att.getShiftAssignment();
        Company company = getSelfCompany(user);
        LocalTime dayStart = company.isAttendanceDayNightMode() && company.getDayStartTime() != null
            ? company.getDayStartTime() : (company.isAttendanceDayNightMode() ? LocalTime.of(6,0) : LocalTime.MIDNIGHT);
        LocalTime dayEnd = company.isAttendanceDayNightMode() && company.getDayEndTime() != null
            ? company.getDayEndTime() : (company.isAttendanceDayNightMode() ? LocalTime.of(22,0) : LocalTime.of(23,59));

        List<ShiftAssignment> allAssignments = shiftAssignmentRepository
            .findByEmployeeIdAndWorkDateWithShift(employeeId, date)
            .stream().sorted(this::compareAssignments).toList();
        int slotIdx = sa != null ? allAssignments.indexOf(sa) : 0;
        if (slotIdx < 0) slotIdx = 0;

        List<AttendanceRequest> requests = attendanceRequestRepository.findByEmployeeAndDateRange(employeeId, date, date);
        List<LeaveRequest> allLeaves = leaveRequestV2Repository.findApprovedByEmployeeAndDateRange(employeeId, date, date);
        LeaveRequest slotLeave = resolveLeaveForSlotFromList(allLeaves, sa, Math.max(1, allAssignments.size()), slotIdx);
        LocalTime leaveFrom = slotLeave != null && slotLeave.isApplied() && slotLeave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? slotLeave.getFromTime() : null;
        LocalTime leaveTo   = slotLeave != null && slotLeave.isApplied() && slotLeave.getMode() == LeaveRequest.Mode.HOUR_RANGE ? slotLeave.getToTime()   : null;

        boolean otEnabled = company.isAttendanceOtEnabled();
        AttendancePolicy policy = resolveAttendancePolicy(att.getEmployee());
        AttendanceRowData data = computeRowData(att, sa, slotIdx, requests, leaveFrom, leaveTo, dayStart, dayEnd, otEnabled, policy);
        var snap = computeHours(att, data, policy, dayStart, dayEnd, false);

        att.setApproved(true);
        att.setApprovedAt(LocalDateTime.now(clock));
        att.setApprovedBy(user);
        att.setSnapActualHours(snap.actualHours());
        att.setSnapDayHours(snap.regularDayHours());
        att.setSnapDayOt(snap.otDayHours());
        att.setSnapNightHours(snap.regularNightHours());
        att.setSnapNightOt(snap.otNightHours());

        boolean hasActualHours2 = snap.actualHours() > 0 || snap.regularDayHours() > 0
            || snap.otDayHours() > 0 || snap.regularNightHours() > 0 || snap.otNightHours() > 0;
        boolean hasCheckInData2 = data.checkIn() != null || data.checkOut() != null
            || att.getOverrideCheckIn() != null || att.getOverrideCheckOut() != null;
        att.setStatus(approvedStatus(att, hasActualHours2, hasCheckInData2, slotLeave, data, policy));

        var workFlags = WorkFlagCalculator.calculate(
            data.shiftStart(), data.shiftEnd(),
            data.flagCheckIn(), data.flagCheckOut(),
            data.otDayHours(), data.otNightHours(),
            slotLeave != null,
            policy.checkInToleranceMinutes(), policy.checkOutToleranceMinutes()
        );
        att.setWorkFlags(WorkFlagCalculator.serialize(workFlags));
        var flex = calc.flexibleOutcome(data, snap, slotLeave != null, att.getStatus(), policy);
        if (flex != null) { att.setStatus(flex.status()); att.setWorkFlags(flex.workFlags()); }
        attendanceRepository.save(att);

        attendanceApproveLeaveRepository.deleteByAttendanceId(att.getId());
        if (slotLeave != null) {
            double leaveHours;
            if (slotLeave.getMode() == LeaveRequest.Mode.HOUR_RANGE && slotLeave.getFromTime() != null && slotLeave.getToTime() != null) {
                int f = slotLeave.getFromTime().toSecondOfDay() / 60, t = slotLeave.getToTime().toSecondOfDay() / 60;
                if (t <= f) t += 1440;
                leaveHours = (t - f) / 60.0;
            } else {
                leaveHours = slotLeave.getRequestedAmount() != null
                    ? slotLeave.getRequestedAmount().doubleValue() * company.getLeaveHoursPerDay().doubleValue() : 0;
            }
            attendanceApproveLeaveRepository.save(AttendanceApproveLeave.builder()
                .attendance(att).leaveRequest(slotLeave)
                .leaveTypeName(slotLeave.getLeaveType().getName())
                .paid(slotLeave.getLeaveType().isPaid()).leaveHours(leaveHours).build());
        }
    }

    /** Haversine formula — trả về khoảng cách mét giữa 2 điểm GPS. */
    private static double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
