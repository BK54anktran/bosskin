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

import java.time.DayOfWeek;
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
            com.bosskin.core.PayrollPeriod period = PayrollPeriod.of(year, month, user.getCompany().getPayrollCutoffDay());
            result = attendanceRepository.findByPeriodWithDeptScope(period.from(), period.to(), companyId, employeeId, deptScope, pageable);
        } else {
            Long companyId = user.getCompany().getId();
            com.bosskin.core.PayrollPeriod period = PayrollPeriod.of(year, month, user.getCompany().getPayrollCutoffDay());
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
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chỉ được xem dữ liệu của chính mình");
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
        return ResponseEntity.ok(rows);
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
            .weekend(date.getDayOfWeek() == DayOfWeek.SATURDAY || date.getDayOfWeek() == DayOfWeek.SUNDAY)
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
            .weekend(date.getDayOfWeek() == DayOfWeek.SATURDAY || date.getDayOfWeek() == DayOfWeek.SUNDAY)
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
        if (assignment.getShift() != null) {
            return assignment.getCustomEndTime() != null
                ? assignment.getCustomEndTime()
                : assignment.getShift().getEndTime();
        }
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
        if (assignment.getShift() != null) {
            return assignment.getCustomStartTime() != null
                ? assignment.getCustomStartTime()
                : assignment.getShift().getStartTime();
        }
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
        requirePermission(user, "ATTENDANCE_VIEW");
        Long attendanceId = body.get("attendanceId") instanceof Number n ? n.longValue() : null;

        Attendance att;
        Long employeeId;
        LocalDate date;
        ShiftAssignment sa;

        if (attendanceId != null) {
            att = attendanceRepository.findByIdAndCompanyId(attendanceId, user.getCompany().getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy bản ghi chấm công"));
            employeeId = att.getEmployee().getId();
            date = att.getDate();
            sa = att.getShiftAssignment();
        } else {
            employeeId = body.get("employeeId") instanceof Number n ? n.longValue() : null;
            String dateStr = body.get("date") instanceof String s ? s : null;
            Long shiftAssignmentId = body.get("shiftAssignmentId") instanceof Number n ? n.longValue() : null;
            if (employeeId == null || dateStr == null)
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Thiếu attendanceId hoặc employeeId+date");
            date = LocalDate.parse(dateStr);
            Employee employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
            sa = shiftAssignmentId != null
                ? shiftAssignmentRepository.findById(shiftAssignmentId).orElse(null)
                : null;
            final ShiftAssignment finalSa = sa;
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
        att.setApprovedAt(LocalDateTime.now());
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
        if (!hasActualHours && !hasCheckInData && slotLeave == null) {
            att.setStatus(Attendance.Status.ABSENT);
        } else if (att.getStatus() == Attendance.Status.ABSENT && (hasActualHours || hasCheckInData)) {
            att.setStatus(Attendance.Status.PRESENT);
        }

        var workFlags = WorkFlagCalculator.calculate(
            data.shiftStart(), data.shiftEnd(),
            data.flagCheckIn(), data.flagCheckOut(),
            data.otDayHours(), data.otNightHours(),
            slotLeave != null,
            policy.checkInToleranceMinutes(),
            policy.checkOutToleranceMinutes()
        );
        att.setWorkFlags(WorkFlagCalculator.serialize(workFlags));
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

        return ResponseEntity.ok().build();
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
        requirePermission(user, "ATTENDANCE_VIEW");
        Long attendanceId = body.get("attendanceId") instanceof Number n ? n.longValue() : null;
        if (attendanceId == null)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Thiếu attendanceId");

        attendanceRepository.findByIdAndCompanyId(attendanceId, user.getCompany().getId()).ifPresent(att -> {
            att.setApproved(false);
            att.setApprovedAt(null);
            att.setApprovedBy(null);
            att.setSnapActualHours(null);
            att.setSnapDayHours(null);
            att.setSnapDayOt(null);
            att.setSnapNightHours(null);
            att.setSnapNightOt(null);
            att.setWorkFlags(null);
            att.setStatus(null);
            attendanceRepository.save(att);
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
        if (att.isApproved())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.already_approved");
        if (att.isDeleted())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.already_deleted");
        att.setDeleted(true);
        att.setDeletedAt(java.time.LocalDateTime.now());
        att.setDeletedBy(user);
        attendanceRepository.save(att);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/check-in")
    public ResponseEntity<AttendanceDTO.Response> checkIn(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Long> body) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Long employeeId = body.get("employeeId");
        LocalDate today = LocalDate.now(ATTENDANCE_ZONE);

        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment().getId());

        List<ShiftWindow> shifts = getShiftWindows(employeeId, today);
        LocalDateTime now = LocalDateTime.now(ATTENDANCE_ZONE);
        ShiftTarget target = resolveCheckInTarget(employee, today, shifts, now.toLocalTime());
        Attendance.Status status = target.shift().startTime().plusMinutes(15).isBefore(now.toLocalTime())
            ? Attendance.Status.LATE : Attendance.Status.PRESENT;
        target.attendance().setCheckIn(now);
        target.attendance().setStatus(status);
        return ResponseEntity.status(HttpStatus.CREATED).body(AttendanceDTO.Response.from(attendanceRepository.save(target.attendance())));
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
            @RequestBody(required = false) Map<String, Double> body,
            Locale locale) {
        requirePermission(user, "ATTENDANCE_SELF");
        var employee = getSelfEmployee(user);
        validateSelfAttendanceEnabled(user);
        LocalDate today = resolveEffectiveDateForSelf(employee.getId());
        List<ShiftWindow> shifts = getShiftWindows(employee.getId(), today);
        LocalDateTime now = LocalDateTime.now(ATTENDANCE_ZONE);
        ShiftTarget target = resolveCheckInTarget(employee, today, shifts, now.toLocalTime());
        Attendance.Status status = target.shift().startTime().plusMinutes(15).isBefore(now.toLocalTime())
            ? Attendance.Status.LATE : Attendance.Status.PRESENT;
        Double lat = body != null ? body.get("latitude") : null;
        Double lng = body != null ? body.get("longitude") : null;
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
            @RequestBody(required = false) Map<String, Double> body,
            Locale locale) {
        requirePermission(user, "ATTENDANCE_SELF");
        var employee = getSelfEmployee(user);
        validateSelfAttendanceEnabled(user);
        LocalDate today = resolveEffectiveDateForSelf(employee.getId());
        List<ShiftWindow> shifts = getShiftWindows(employee.getId(), today);
        ShiftTarget target = resolveCheckOutTarget(employee, today, shifts, LocalTime.now(ATTENDANCE_ZONE));
        LocalDateTime checkOut = LocalDateTime.now(ATTENDANCE_ZONE);
        Double lat = body != null ? body.get("latitude") : null;
        Double lng = body != null ? body.get("longitude") : null;
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
        LocalDate today = LocalDate.now(ATTENDANCE_ZONE);

        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment().getId());

        List<ShiftWindow> shifts = getShiftWindows(employeeId, today);
        ShiftTarget target = resolveCheckOutTarget(employee, today, shifts, LocalTime.now(ATTENDANCE_ZONE));
        target.attendance().setCheckOut(LocalDateTime.now(ATTENDANCE_ZONE));
        return ResponseEntity.ok(AttendanceDTO.Response.from(attendanceRepository.save(target.attendance())));
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
        LocalDate today = LocalDate.now(ATTENDANCE_ZONE);
        LocalDate date = targetDate != null ? targetDate : today;
        boolean enabled = company.isSelfAttendanceEnabled();
        LocalTime now = LocalTime.now(ATTENDANCE_ZONE);
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

        // Nếu đang xem hôm nay, kiểm tra thêm ca hôm qua tràn qua
        if (isToday) {
            LocalDate yesterday = date.minusDays(1);
            List<ShiftWindow> prevShifts = getShiftWindows(employee.getId(), yesterday, company);
            List<ShiftWindow> overnightShifts = prevShifts.stream()
                .filter(sw -> sw.endTime().isBefore(sw.startTime()))
                .filter(sw -> isWithinWindow(now, sw.checkInFrom(), sw.checkOutTo()))
                .toList();
            if (!overnightShifts.isEmpty()) {
                shifts = overnightShifts;
                List<Attendance> prevAtts = attendanceRepository.findByEmployeeIdAndDate(employee.getId(), yesterday);
                attendance = prevAtts.isEmpty() ? null : prevAtts.get(0);
                date = yesterday;
            }
        }

        ShiftWindow shift = shifts.isEmpty() ? null : shifts.get(0);
        boolean canCheckIn = false;
        boolean canCheckOut = false;
        for (int i = 0; i < shifts.size(); i++) {
            ShiftWindow sw = shifts.get(i);
            ShiftAssignment sa = i < assignments.size() ? assignments.get(i) : null;
            Attendance slotAtt = sa != null ? attByShift.getOrDefault(sa.getId(), noShiftAtt) : noShiftAtt;
            if ((slotAtt == null || slotAtt.getCheckIn() == null)
                && isWithinWindow(now, sw.checkInFrom(), sw.checkInTo())) {
                canCheckIn = true;
            }
            if (slotAtt != null && slotAtt.getCheckIn() != null && slotAtt.getCheckOut() == null
                && isWithinWindow(now, sw.checkOutFrom(), sw.checkOutTo())) {
                canCheckOut = true;
            }
        }

        String message = null;
        if (!enabled) {
            message = localizedCheckInOutDisabledMessage(locale);
        } else if (shift == null) {
            message = localizedNoShiftMessage(locale, isToday);
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
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Tài khoản chưa được liên kết với nhân viên nào");
        }
        return employeeRepository.findById(user.getEmployee().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Nhân viên không tồn tại"));
    }

    private Company getSelfCompany(User user) {
        if (user == null || user.getCompany() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Phiên đăng nhập không hợp lệ");
        }
        return companyRepository.findById(user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty không tồn tại"));
    }

    private void validateSelfAttendanceEnabled(User user) {
        if (!getSelfCompany(user).isSelfAttendanceEnabled()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chức năng check-in/out đang tắt");
        }
    }

    private ShiftWindow getShiftWindowOrThrow(Long employeeId, LocalDate date) {
        ShiftWindow shift = getShiftWindow(employeeId, date);
        if (shift == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Hôm nay chưa được xếp ca");
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

    // Trả về ngày hiệu lực để check-in/out: nếu giờ hiện tại nằm trong cửa sổ của ca tràn đêm
    // từ hôm qua (endTime < startTime và giờ hiện tại < 12:00), thì dùng ngày hôm qua.
    private LocalDate resolveEffectiveDateForSelf(Long employeeId) {
        LocalDate today = LocalDate.now(ATTENDANCE_ZONE);
        LocalTime now = LocalTime.now(ATTENDANCE_ZONE);
        LocalDate yesterday = today.minusDays(1);
        List<ShiftWindow> prevShifts = getShiftWindows(employeeId, yesterday);
        boolean hasOvernightWindow = prevShifts.stream()
            .filter(sw -> sw.endTime().isBefore(sw.startTime()))
            .anyMatch(sw -> isWithinWindow(now, sw.checkInFrom(), sw.checkOutTo()));
        return hasOvernightWindow ? yesterday : today;
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

    private ShiftTarget resolveCheckInTarget(Employee employee, LocalDate date, List<ShiftWindow> shifts, LocalTime now) {
        if (shifts.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Hôm nay chưa được xếp ca");
        }
        List<ShiftAssignment> assignments = shiftAssignmentRepository
            .findByEmployeeIdAndWorkDateWithShift(employee.getId(), date)
            .stream().sorted(this::compareAssignments).toList();
        for (int i = 0; i < shifts.size(); i++) {
            ShiftWindow sw = shifts.get(i);
            ShiftAssignment sa = i < assignments.size() ? assignments.get(i) : null;
            Attendance att = getOrCreateAttendanceForShift(employee, date, sa);
            if (att.getCheckIn() == null && isWithinWindow(now, sw.checkInFrom(), sw.checkInTo())) {
                return new ShiftTarget(att, sa, sw);
            }
        }
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chưa tới hoặc đã quá giờ check-in");
    }

    private ShiftTarget resolveCheckOutTarget(Employee employee, LocalDate date, List<ShiftWindow> shifts, LocalTime now) {
        if (shifts.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Hôm nay chưa được xếp ca");
        }
        List<ShiftAssignment> assignments = shiftAssignmentRepository
            .findByEmployeeIdAndWorkDateWithShift(employee.getId(), date)
            .stream().sorted(this::compareAssignments).toList();
        for (int i = 0; i < shifts.size(); i++) {
            ShiftWindow sw = shifts.get(i);
            ShiftAssignment sa = i < assignments.size() ? assignments.get(i) : null;
            Attendance att = getOrCreateAttendanceForShift(employee, date, sa);
            if (att.getCheckIn() != null && att.getCheckOut() == null
                && isWithinWindow(now, sw.checkOutFrom(), sw.checkOutTo())) {
                return new ShiftTarget(att, sa, sw);
            }
        }
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chưa tới hoặc đã quá giờ check-out");
    }

    private record ShiftTarget(Attendance attendance, ShiftAssignment shiftAssignment, ShiftWindow shift) {}

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
            start = sa.getCustomStartTime() != null ? sa.getCustomStartTime() : shift.getStartTime();
            end = sa.getCustomEndTime() != null ? sa.getCustomEndTime() : shift.getEndTime();
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
                    "Vị trí của bạn nằm ngoài phạm vi được phép check-in");
            return;
        }

        // 2. Walk up department tree
        Department dept = employee.getDepartment();
        while (dept != null) {
            if (dept.getCheckInLatitude() != null) {
                if (haversineMeters(lat, lng, dept.getCheckInLatitude(), dept.getCheckInLongitude())
                        > dept.getCheckInRadiusMeters()) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Vị trí của bạn nằm ngoài phạm vi phòng ban " + dept.getName());
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
                        "Vị trí của bạn nằm ngoài phạm vi công ty");
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
        return attendanceExcelService.exportTimesheetRange(
            user.getCompany().getId(), user.getId(),
            employee.getFullName(), employee.getEmployeeCode(), from, to, rows,
            company.isAttendanceDayNightMode(), otEnabled, LocaleContextHolder.getLocale());
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
        return ResponseEntity.ok(
            attendanceExcelService.importAttendance(user.getCompany().getId(), user.getId(), file));
    }

    @PostMapping("/preview-import-timesheet")
    public ResponseEntity<List<AttendanceExcelService.AttendanceDiff>> previewImportTimesheet(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "ATTENDANCE_VIEW");
        return ResponseEntity.ok(
            attendanceExcelService.previewImportTimesheet(user.getCompany().getId(), user.getId(), file));
    }

    @PostMapping("/import-timesheet")
    @Transactional
    public ResponseEntity<Map<String, Integer>> importTimesheet(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "ATTENDANCE_MANAGE");
        Map<String, Integer> result = new java.util.HashMap<>(
            attendanceExcelService.importTimesheet(user.getCompany().getId(), user.getId(), file));

        // Xử lý approve/unapprove cho các row có trạng thái duyệt thay đổi
        List<AttendanceExcelService.ApproveTask> approveTasks = attendanceExcelService.getLastImportApproveTasks();
        int approved = 0;
        for (AttendanceExcelService.ApproveTask task : approveTasks) {
            try {
                Attendance att = attendanceRepository.findById(task.attendanceId()).orElse(null);
                if (att == null) continue;
                if (task.approve()) {
                    doApprove(att, user);
                } else {
                    att.setApproved(false);
                    att.setApprovedAt(null); att.setApprovedBy(null);
                    att.setSnapActualHours(null); att.setSnapDayHours(null);
                    att.setSnapDayOt(null); att.setSnapNightHours(null);
                    att.setSnapNightOt(null); att.setWorkFlags(null);
                    att.setStatus(null);
                    attendanceRepository.save(att);
                }
                approved++;
            } catch (Exception ignored) {}
        }
        if (approved > 0) result.put("approved", approved);
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
        att.setApprovedAt(LocalDateTime.now());
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
        if (!hasActualHours2 && !hasCheckInData2 && slotLeave == null) {
            att.setStatus(Attendance.Status.ABSENT);
        } else if (att.getStatus() == Attendance.Status.ABSENT && (hasActualHours2 || hasCheckInData2)) {
            att.setStatus(Attendance.Status.PRESENT);
        }

        var workFlags = WorkFlagCalculator.calculate(
            data.shiftStart(), data.shiftEnd(),
            data.flagCheckIn(), data.flagCheckOut(),
            data.otDayHours(), data.otNightHours(),
            slotLeave != null,
            policy.checkInToleranceMinutes(), policy.checkOutToleranceMinutes()
        );
        att.setWorkFlags(WorkFlagCalculator.serialize(workFlags));
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
