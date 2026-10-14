package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.ShiftDTO;
import com.bosskin.dto.ShiftRegistrationDTO;
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
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Đăng ký lịch làm việc (V23, docs/thiet-ke/dang-ky-ca.md).
 * <p>
 * Quản lý (SHIFT_REGISTRATION_MANAGE, phạm vi phòng ban theo SHIFT_VIEW) tạo đợt cho một số phòng ban, mở / đóng; tới hạn chót
 * đợt tự đóng. Nhân viên (SHIFT_REGISTRATION_SELF) thuộc phòng ban của đợt đăng ký từng ngày theo ca có sẵn, giờ tuỳ chỉnh hoặc
 * "rảnh cả ngày". Quản lý duyệt theo ngày / từng ô → tạo phân ca qua {@link WorkShiftService#assign} (mỗi ô một giao dịch:
 * ô lỗi được báo lại, không huỷ cả lần duyệt). Công ty tắt chức năng → mọi API 403.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ShiftRegistrationService {

    static final int MAX_RANGE_DAYS = 62;
    static final int MAX_SLOTS_PER_DAY = 2;
    private static final DateTimeFormatter HM = DateTimeFormatter.ofPattern("HH:mm");
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final ShiftRegistrationRoundRepository roundRepo;
    private final ShiftRegistrationRepository regRepo;
    private final CompanyRepository companyRepo;
    private final EmployeeRepository employeeRepo;
    private final DepartmentRepository departmentRepo;
    private final WorkShiftRepository shiftRepo;
    private final ShiftAssignmentRepository assignRepo;
    private final UserRepository userRepo;
    private final DeptScopeService deptScopeService;
    private final WorkShiftService workShiftService;
    private final FcmService fcmService;
    private final AuditService audit;
    private final Clock clock;

    // ── Đợt (quản lý) ───────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ShiftRegistrationDTO.RoundResponse> listRounds(User user) {
        Long companyId = requireEnabled(user);
        Set<Long> scope = managerScope(user);
        List<ShiftRegistrationRound> rounds = roundRepo.findByCompanyIdOrderByFromDateDescIdDesc(companyId).stream()
            .filter(r -> visible(r, scope)).toList();
        Map<Long, Long> counts = new HashMap<>();
        if (!rounds.isEmpty()) {
            for (Object[] row : regRepo.countEmployeesByRound(rounds.stream().map(ShiftRegistrationRound::getId).toList())) {
                counts.put((Long) row[0], (Long) row[1]);
            }
        }
        Context ctx = new Context(companyId);
        return rounds.stream()
            .map(r -> toRoundResponse(r, ctx, counts.getOrDefault(r.getId(), 0L).intValue()))
            .toList();
    }

    @Transactional
    public ShiftRegistrationDTO.RoundResponse createRound(User user, ShiftRegistrationDTO.RoundUpsert req) {
        Long companyId = requireEnabled(user);
        ShiftRegistrationRound r = ShiftRegistrationRound.builder().companyId(companyId).createdBy(user.getId()).build();
        apply(r, req, companyId, managerScope(user));
        if (req.isOpen()) r.setStatus(ShiftRegistrationRound.Status.OPEN);
        r = roundRepo.save(r);
        audit.log("SHIFT_REG_ROUND_CREATE").entity("SHIFT_REG_ROUND", r.getId())
            .summary(r.getName() + " " + r.getFromDate().format(DMY) + " – " + r.getToDate().format(DMY))
            .detail(AuditService.map("status", r.getStatus().name(), "departments", r.getDepartmentIds()))
            .save();
        if (r.getStatus() == ShiftRegistrationRound.Status.OPEN) notifyOpened(r);
        return toRoundResponse(r, new Context(companyId), 0);
    }

    @Transactional
    public ShiftRegistrationDTO.RoundResponse updateRound(User user, Long id, ShiftRegistrationDTO.RoundUpsert req) {
        Long companyId = requireEnabled(user);
        Set<Long> scope = managerScope(user);
        ShiftRegistrationRound r = getRound(companyId, id, scope);
        apply(r, req, companyId, scope);
        r = roundRepo.save(r);
        audit.log("SHIFT_REG_ROUND_UPDATE").entity("SHIFT_REG_ROUND", r.getId()).summary(r.getName()).save();
        return toRoundResponse(r, new Context(companyId), registeredCount(r.getId()));
    }

    @Transactional
    public void deleteRound(User user, Long id) {
        Long companyId = requireEnabled(user);
        ShiftRegistrationRound r = getRound(companyId, id, managerScope(user));
        boolean anyApproved = regRepo.findByRoundFetch(r.getId()).stream()
            .anyMatch(x -> x.getStatus() == ShiftRegistration.Status.APPROVED);
        if (anyApproved) throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift_registration.has_approved");
        r.setDeleted(true);
        roundRepo.save(r);
        audit.log("SHIFT_REG_ROUND_DELETE").entity("SHIFT_REG_ROUND", r.getId()).summary(r.getName()).save();
    }

    @Transactional
    public ShiftRegistrationDTO.RoundResponse open(User user, Long id) {
        Long companyId = requireEnabled(user);
        ShiftRegistrationRound r = getRound(companyId, id, managerScope(user));
        if (r.getToDate().isBefore(today())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.round_ended");
        }
        boolean first = r.getStatus() == ShiftRegistrationRound.Status.DRAFT;
        r.setStatus(ShiftRegistrationRound.Status.OPEN);
        // Hạn chót đã qua mà mở lại → bỏ hạn chót, nếu không job sẽ đóng ngay.
        if (r.getClosesAt() != null && !r.getClosesAt().isAfter(now())) r.setClosesAt(null);
        roundRepo.save(r);
        audit.log("SHIFT_REG_ROUND_OPEN").entity("SHIFT_REG_ROUND", r.getId()).summary(r.getName()).save();
        if (first) notifyOpened(r);
        return toRoundResponse(r, new Context(companyId), registeredCount(r.getId()));
    }

    @Transactional
    public ShiftRegistrationDTO.RoundResponse close(User user, Long id) {
        Long companyId = requireEnabled(user);
        ShiftRegistrationRound r = getRound(companyId, id, managerScope(user));
        r.setStatus(ShiftRegistrationRound.Status.CLOSED);
        roundRepo.save(r);
        audit.log("SHIFT_REG_ROUND_CLOSE").entity("SHIFT_REG_ROUND", r.getId()).summary(r.getName()).save();
        return toRoundResponse(r, new Context(companyId), registeredCount(r.getId()));
    }

    /** Tới hạn chót thì tự đóng (mỗi 5 phút). */
    @Scheduled(cron = "0 */5 * * * *", zone = "Asia/Ho_Chi_Minh")
    @Transactional
    public void autoClose() {
        for (ShiftRegistrationRound r : roundRepo.findByStatusAndClosesAtLessThanEqual(ShiftRegistrationRound.Status.OPEN, now())) {
            r.setStatus(ShiftRegistrationRound.Status.CLOSED);
            roundRepo.save(r);
            log.info("Shift registration round {} auto-closed", r.getId());
        }
    }

    // ── Lưới + duyệt (quản lý) ──────────────────────────────────────────

    @Transactional(readOnly = true)
    public ShiftRegistrationDTO.BoardResponse board(User user, Long id) {
        Long companyId = requireEnabled(user);
        Set<Long> scope = managerScope(user);
        ShiftRegistrationRound r = getRound(companyId, id, scope);
        Context ctx = new Context(companyId);
        List<ShiftRegistration> all = regRepo.findByRoundFetch(r.getId());
        ctx.preloadAssignments(all);
        Map<Long, List<ShiftRegistration>> byEmp = all.stream()
            .filter(x -> WorkShiftService.inShiftScope(x.getEmployee(), scope, user.getEmployeeId()))
            .collect(Collectors.groupingBy(x -> x.getEmployee().getId(), LinkedHashMap::new, Collectors.toList()));
        // Nhân viên thuộc đợt + người đã đăng ký nhưng nay đã chuyển phòng (vẫn hiện để không mất đăng ký).
        Map<Long, Employee> emps = new LinkedHashMap<>();
        for (Employee e : roundEmployees(r, ctx.employees())) {
            if (WorkShiftService.inShiftScope(e, scope, user.getEmployeeId())) emps.put(e.getId(), e);
        }
        byEmp.values().forEach(list -> emps.putIfAbsent(list.get(0).getEmployee().getId(), list.get(0).getEmployee()));
        List<ShiftRegistrationDTO.BoardEmployee> rows = emps.values().stream()
            .sorted(Comparator.comparing(Employee::getFullName, Comparator.nullsLast(String::compareTo)))
            .map(e -> {
                List<ShiftRegistration> regs = byEmp.getOrDefault(e.getId(), List.of());
                return ShiftRegistrationDTO.BoardEmployee.builder()
                    .id(e.getId()).code(e.getEmployeeCode()).name(e.getFullName())
                    .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
                    .days((int) regs.stream().filter(x -> x.getStatus() != ShiftRegistration.Status.REJECTED)
                        .map(ShiftRegistration::getWorkDate).distinct().count())
                    .registrations(regs.stream().map(x -> toRegResponse(x, ctx)).toList())
                    .build();
            }).toList();
        int registered = (int) rows.stream().filter(x -> !x.getRegistrations().isEmpty()).count();
        return ShiftRegistrationDTO.BoardResponse.builder()
            .round(toRoundResponse(r, ctx, registered)).employees(rows).shifts(ctx.shiftOptions()).build();
    }

    /** Duyệt mọi đăng ký chờ của một ngày → phân ca. "Rảnh cả ngày" dùng anyShiftId (trống = bỏ qua, báo lại). */
    public ShiftRegistrationDTO.DecideResult approveDay(User user, Long roundId, LocalDate date, Long anyShiftId) {
        Long companyId = requireEnabled(user);
        Set<Long> scope = managerScope(user);
        ShiftRegistrationRound r = getRound(companyId, roundId, scope);
        if (date.isBefore(r.getFromDate()) || date.isAfter(r.getToDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.outside_round|" + date.format(DMY));
        }
        WorkShift anyShift = anyShiftId != null ? requireShift(companyId, anyShiftId) : null;
        int approved = 0;
        List<ShiftRegistrationDTO.Skipped> skipped = new ArrayList<>();
        for (ShiftRegistration reg : regRepo.findByRoundAndDateFetch(r.getId(), date)) {
            if (reg.getStatus() != ShiftRegistration.Status.PENDING) continue;
            if (!WorkShiftService.inShiftScope(reg.getEmployee(), scope, user.getEmployeeId())) continue;
            Long shiftId = reg.getKind() == ShiftRegistration.Kind.ANY ? (anyShift != null ? anyShift.getId() : null) : null;
            try {
                if (reg.getKind() == ShiftRegistration.Kind.ANY && anyShift == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.any_needs_shift");
                }
                approveOne(user, companyId, reg, shiftId, null, null);
                approved++;
            } catch (ResponseStatusException e) {
                skipped.add(new ShiftRegistrationDTO.Skipped(reg.getId(), reg.getEmployee().getFullName(), date, e.getReason()));
            }
        }
        audit.log("SHIFT_REG_APPROVE").entity("SHIFT_REG_ROUND", r.getId())
            .summary(r.getName() + " " + date.format(DMY))
            .detail(AuditService.map("approved", approved, "skipped", skipped.size()))
            .save();
        return ShiftRegistrationDTO.DecideResult.builder().approved(approved).skipped(skipped).build();
    }

    /** Duyệt một ô, được đổi sang ca / giờ khác (bắt buộc với "rảnh cả ngày"). */
    public ShiftRegistrationDTO.RegistrationResponse approve(User user, Long regId, ShiftRegistrationDTO.ApproveOneRequest req) {
        Long companyId = requireEnabled(user);
        ShiftRegistration reg = getRegistrationForManager(user, companyId, regId);
        if (reg.getStatus() != ShiftRegistration.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift_registration.already_decided");
        }
        Long shiftId = req != null ? req.getShiftId() : null;
        LocalTime start = req != null ? req.getStartTime() : null;
        LocalTime end = req != null ? req.getEndTime() : null;
        if (shiftId == null && (start == null || end == null) && reg.getKind() == ShiftRegistration.Kind.ANY) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.any_needs_shift");
        }
        approveOne(user, companyId, reg, shiftId, start, end);
        audit.log("SHIFT_REG_APPROVE").entity("SHIFT_REGISTRATION", reg.getId())
            .summary(reg.getEmployee().getFullName() + " " + reg.getWorkDate().format(DMY)).save();
        return toRegResponse(regRepo.findById(regId).orElseThrow(), new Context(companyId));
    }

    @Transactional
    public ShiftRegistrationDTO.RegistrationResponse reject(User user, Long regId) {
        Long companyId = requireEnabled(user);
        ShiftRegistration reg = getRegistrationForManager(user, companyId, regId);
        if (reg.getStatus() != ShiftRegistration.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift_registration.already_decided");
        }
        requireNotOwn(user, reg);
        reg.setStatus(ShiftRegistration.Status.REJECTED);
        reg.setDecidedBy(user.getId());
        reg.setDecidedAt(now());
        regRepo.save(reg);
        audit.log("SHIFT_REG_REJECT").entity("SHIFT_REGISTRATION", reg.getId())
            .summary(reg.getEmployee().getFullName() + " " + reg.getWorkDate().format(DMY)).save();
        return toRegResponse(reg, new Context(companyId));
    }

    /**
     * Tạo phân ca cho một đăng ký (giao dịch của WorkShiftService.assign) rồi ghi trạng thái. Đổi ca / giờ: shiftId hoặc
     * start–end; không truyền thì theo đăng ký.
     */
    private void approveOne(User user, Long companyId, ShiftRegistration reg, Long shiftId, LocalTime start, LocalTime end) {
        requireNotOwn(user, reg);
        ShiftDTO.AssignRequest a = new ShiftDTO.AssignRequest();
        a.setEmployeeId(reg.getEmployee().getId());
        a.setWorkDate(reg.getWorkDate());
        a.setNote(reg.getNote());
        if (shiftId != null) {
            a.setShiftId(requireShift(companyId, shiftId).getId());
        } else if (start != null && end != null) {
            a.setCustomStartTime(start);
            a.setCustomEndTime(end);
        } else if (reg.getKind() == ShiftRegistration.Kind.SHIFT && reg.getShiftId() != null
            && shiftRepo.findById(reg.getShiftId()).filter(WorkShift::isActive).isPresent()) {
            a.setShiftId(reg.getShiftId());
        } else {
            // Ca đã ngừng dùng → giữ đúng giờ nhân viên đăng ký.
            a.setCustomStartTime(reg.getStartTime());
            a.setCustomEndTime(reg.getEndTime());
        }
        ShiftDTO.AssignResponse created = workShiftService.assign(companyId, a, user.getId());
        reg.setStatus(ShiftRegistration.Status.APPROVED);
        reg.setAssignmentId(created.getId());
        reg.setDecidedBy(user.getId());
        reg.setDecidedAt(now());
        regRepo.save(reg);
    }

    // ── Nhân viên ───────────────────────────────────────────────────────

    /** Đợt đang mở của tôi + đợt đã đóng chưa qua quá 7 ngày. */
    @Transactional(readOnly = true)
    public List<ShiftRegistrationDTO.RoundResponse> myRounds(User user) {
        Long companyId = requireEnabled(user);
        Employee me = requireEmployee(user);
        LocalDate cutoff = today().minusDays(7);
        Context ctx = new Context(companyId);
        return roundRepo.findByCompanyIdOrderByFromDateDescIdDesc(companyId).stream()
            .filter(r -> r.getStatus() != ShiftRegistrationRound.Status.DRAFT)
            .filter(r -> r.getStatus() == ShiftRegistrationRound.Status.OPEN || !r.getToDate().isBefore(cutoff))
            .filter(r -> eligible(r, me))
            .map(r -> toRoundResponse(r, ctx, 0))
            .toList();
    }

    @Transactional(readOnly = true)
    public ShiftRegistrationDTO.SelfRoundResponse myRound(User user, Long roundId) {
        Long companyId = requireEnabled(user);
        Employee me = requireEmployee(user);
        ShiftRegistrationRound r = roundRepo.findByIdAndCompanyId(roundId, companyId)
            .filter(x -> x.getStatus() != ShiftRegistrationRound.Status.DRAFT)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift_registration.not_found"));
        if (!eligible(r, me) && regRepo.findByRoundIdAndEmployeeIdOrderByWorkDateAscStartTimeAsc(r.getId(), me.getId()).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.shift_registration.not_in_scope");
        }
        return selfResponse(r, me, new Context(companyId));
    }

    /**
     * Ghi cả lịch của tôi trong đợt: thay mọi đăng ký chưa duyệt; ngày đã có khung được duyệt giữ nguyên (khung gửi
     * cho ngày đó bị bỏ qua).
     */
    @Transactional
    public ShiftRegistrationDTO.SelfRoundResponse saveMine(User user, Long roundId, ShiftRegistrationDTO.SelfSaveRequest req) {
        Long companyId = requireEnabled(user);
        Employee me = requireEmployee(user);
        ShiftRegistrationRound r = roundRepo.findByIdAndCompanyId(roundId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift_registration.not_found"));
        if (r.getStatus() != ShiftRegistrationRound.Status.OPEN) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift_registration.not_open");
        }
        if (!eligible(r, me)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.shift_registration.not_in_scope");

        Context ctx = new Context(companyId);
        List<ShiftRegistration> existing = regRepo.findByRoundIdAndEmployeeIdOrderByWorkDateAscStartTimeAsc(r.getId(), me.getId());
        Set<LocalDate> lockedDays = existing.stream()
            .filter(x -> x.getStatus() == ShiftRegistration.Status.APPROVED)
            .map(ShiftRegistration::getWorkDate).collect(Collectors.toSet());
        LocalDate today = today();

        // Kiểm tra + dựng các khung mới, nhóm theo ngày.
        Map<LocalDate, List<ShiftRegistration>> byDay = new TreeMap<>();
        for (ShiftRegistrationDTO.SlotInput in : req.getSlots()) {
            LocalDate d = in.getWorkDate();
            if (lockedDays.contains(d)) continue;
            if (d.isBefore(r.getFromDate()) || d.isAfter(r.getToDate())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.outside_round|" + d.format(DMY));
            }
            if (d.isBefore(today)) {
                // Ngày đã qua: giữ nguyên đăng ký cũ, không cho thêm mới.
                boolean same = existing.stream().anyMatch(x -> x.getWorkDate().equals(d) && sameSlot(x, in));
                if (same) continue;
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.past_date|" + d.format(DMY));
            }
            byDay.computeIfAbsent(d, k -> new ArrayList<>()).add(buildSlot(r, me, in, ctx));
        }
        for (Map.Entry<LocalDate, List<ShiftRegistration>> e : byDay.entrySet()) validateDay(e.getKey(), e.getValue());

        Set<LocalDate> dayset = new HashSet<>(byDay.keySet());
        dayset.addAll(lockedDays);
        existing.stream()
            .filter(x -> x.getWorkDate().isBefore(today) && x.getStatus() != ShiftRegistration.Status.REJECTED)
            .forEach(x -> dayset.add(x.getWorkDate()));
        int days = dayset.size();
        if (r.getMinDays() != null && days > 0 && days < r.getMinDays()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.min_days|" + r.getMinDays());
        }

        // Thay: xoá mềm đăng ký chưa duyệt của ngày chưa qua, thêm khung mới.
        for (ShiftRegistration x : existing) {
            if (x.getStatus() == ShiftRegistration.Status.APPROVED || x.getWorkDate().isBefore(today)) continue;
            x.setDeleted(true);
            regRepo.save(x);
        }
        byDay.values().forEach(regRepo::saveAll);
        regRepo.flush();
        audit.log("SHIFT_REG_SUBMIT").entity("SHIFT_REG_ROUND", r.getId())
            .summary(me.getEmployeeCode() + " " + me.getFullName() + " — " + r.getName())
            .detail(AuditService.map("days", byDay.size()))
            .save();
        return selfResponse(r, me, ctx);
    }

    // ── Kiểm tra ────────────────────────────────────────────────────────

    private ShiftRegistration buildSlot(ShiftRegistrationRound r, Employee me, ShiftRegistrationDTO.SlotInput in, Context ctx) {
        ShiftRegistration.Kind kind;
        try {
            kind = ShiftRegistration.Kind.valueOf(in.getKind());
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.invalid_time");
        }
        ShiftRegistration s = ShiftRegistration.builder()
            .roundId(r.getId()).employee(me).workDate(in.getWorkDate()).kind(kind)
            .note(in.getNote() != null && !in.getNote().isBlank() ? in.getNote().trim() : null)
            .build();
        switch (kind) {
            case ANY -> { /* rảnh cả ngày: không có giờ */ }
            case SHIFT -> {
                WorkShift ws = ctx.shift(in.getShiftId());
                if (ws == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.not_found");
                s.setShiftId(ws.getId());
                s.setStartTime(ws.getStartTime());
                s.setEndTime(ws.getEndTime());
            }
            case CUSTOM -> {
                if (in.getStartTime() == null || in.getEndTime() == null || in.getStartTime().equals(in.getEndTime())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.invalid_time");
                }
                s.setStartTime(in.getStartTime().withSecond(0).withNano(0));
                s.setEndTime(in.getEndTime().withSecond(0).withNano(0));
                checkLimits(r, s.getStartTime(), s.getEndTime());
            }
        }
        return s;
    }

    /** Giới hạn của đợt áp cho giờ tuỳ chỉnh (ca có sẵn do công ty đặt nên không chặn). */
    static void checkLimits(ShiftRegistrationRound r, LocalTime start, LocalTime end) {
        boolean overnight = end.isBefore(start);
        if (!overnight && r.getEarliestTime() != null && r.getLatestTime() != null
            && (start.isBefore(r.getEarliestTime()) || end.isAfter(r.getLatestTime()))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.outside_window|"
                + r.getEarliestTime().format(HM) + "|" + r.getLatestTime().format(HM));
        }
        if (overnight && r.getEarliestTime() != null && r.getLatestTime() != null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.outside_window|"
                + r.getEarliestTime().format(HM) + "|" + r.getLatestTime().format(HM));
        }
        BigDecimal hours = BigDecimal.valueOf(minutes(start, end)).divide(BigDecimal.valueOf(60), 2, java.math.RoundingMode.HALF_UP);
        if (r.getMinHours() != null && hours.compareTo(r.getMinHours()) < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.too_short|" + plain(r.getMinHours()));
        }
        if (r.getMaxHours() != null && hours.compareTo(r.getMaxHours()) > 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.too_long|" + plain(r.getMaxHours()));
        }
    }

    /** ≤ 2 khung / ngày, "rảnh cả ngày" đứng một mình, các khung không chồng giờ. */
    static void validateDay(LocalDate d, List<ShiftRegistration> slots) {
        String day = d.format(DMY);
        if (slots.size() > MAX_SLOTS_PER_DAY) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.too_many_slots|" + day);
        }
        if (slots.size() > 1 && slots.stream().anyMatch(s -> s.getKind() == ShiftRegistration.Kind.ANY)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.any_alone|" + day);
        }
        for (int i = 0; i < slots.size(); i++) {
            for (int j = i + 1; j < slots.size(); j++) {
                ShiftRegistration a = slots.get(i), b = slots.get(j);
                if (overlaps(a.getStartTime(), a.getEndTime(), b.getStartTime(), b.getEndTime())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.overlap_slot|" + day);
                }
            }
        }
    }

    static boolean overlaps(LocalTime s1, LocalTime e1, LocalTime s2, LocalTime e2) {
        int a1 = s1.toSecondOfDay() / 60, b1 = a1 + minutes(s1, e1);
        int a2 = s2.toSecondOfDay() / 60, b2 = a2 + minutes(s2, e2);
        return a1 < b2 && a2 < b1;
    }

    /** Độ dài khung (phút); kết thúc trước bắt đầu = qua đêm. */
    static int minutes(LocalTime start, LocalTime end) {
        int m = (int) ChronoUnit.MINUTES.between(start, end);
        return m <= 0 ? m + 24 * 60 : m;
    }

    private static boolean sameSlot(ShiftRegistration x, ShiftRegistrationDTO.SlotInput in) {
        return x.getKind().name().equals(in.getKind())
            && Objects.equals(x.getShiftId(), in.getShiftId())
            && (x.getKind() != ShiftRegistration.Kind.CUSTOM
                || (Objects.equals(x.getStartTime(), in.getStartTime()) && Objects.equals(x.getEndTime(), in.getEndTime())));
    }

    private static String plain(BigDecimal v) {
        return v.stripTrailingZeros().toPlainString();
    }

    private void apply(ShiftRegistrationRound r, ShiftRegistrationDTO.RoundUpsert req, Long companyId, Set<Long> scope) {
        if (req.getName() == null || req.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.name_required");
        }
        if (req.getToDate().isBefore(req.getFromDate())
            || ChronoUnit.DAYS.between(req.getFromDate(), req.getToDate()) >= MAX_RANGE_DAYS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.range_invalid|" + MAX_RANGE_DAYS);
        }
        if (req.getToDate().isBefore(today())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.round_ended");
        }
        Set<Long> depts = new LinkedHashSet<>();
        for (Long id : req.getDepartmentIds()) {
            if (id == null) continue;
            departmentRepo.findByIdAndCompanyId(id, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
            if (!scope.isEmpty() && !scope.contains(id)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
            }
            depts.add(id);
        }
        if (depts.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.departments_required");
        if ((req.getEarliestTime() == null) != (req.getLatestTime() == null)
            || (req.getEarliestTime() != null && !req.getLatestTime().isAfter(req.getEarliestTime()))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.window_invalid");
        }
        if ((req.getMinHours() != null && req.getMaxHours() != null && req.getMinHours().compareTo(req.getMaxHours()) > 0)
            || invalidHours(req.getMinHours()) || invalidHours(req.getMaxHours())
            || (req.getMinDays() != null && req.getMinDays() < 1) || (req.getNeededPerDay() != null && req.getNeededPerDay() < 1)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift_registration.limits_invalid");
        }
        // Hai đợt cùng phòng ban không được chồng ngày.
        Set<Long> expanded = deptScopeService.expandDepartmentsWithDescendants(depts);
        for (ShiftRegistrationRound o : roundRepo.findByCompanyIdOrderByFromDateDescIdDesc(companyId)) {
            if (o.getId().equals(r.getId())) continue;
            if (o.getToDate().isBefore(req.getFromDate()) || o.getFromDate().isAfter(req.getToDate())) continue;
            Set<Long> oe = deptScopeService.expandDepartmentsWithDescendants(o.getDepartmentIds());
            if (oe.stream().anyMatch(expanded::contains)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.shift_registration.overlap|" + o.getName());
            }
        }
        r.setName(req.getName().trim());
        r.setFromDate(req.getFromDate());
        r.setToDate(req.getToDate());
        r.setDepartmentIds(new HashSet<>(depts));
        r.setClosesAt(req.getClosesAt());
        r.setEarliestTime(req.getEarliestTime());
        r.setLatestTime(req.getLatestTime());
        r.setMinHours(req.getMinHours());
        r.setMaxHours(req.getMaxHours());
        r.setMinDays(req.getMinDays());
        r.setNeededPerDay(req.getNeededPerDay());
        r.setNote(req.getNote() != null && !req.getNote().isBlank() ? req.getNote().trim() : null);
    }

    /** Số giờ một khung phải trong (0, 24]. */
    private static boolean invalidHours(BigDecimal v) {
        return v != null && (v.signum() <= 0 || v.compareTo(BigDecimal.valueOf(24)) > 0);
    }

    // ── Phạm vi + tra cứu ───────────────────────────────────────────────

    private Long requireEnabled(User user) {
        if (user == null || user.getCompany() == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        Long companyId = user.getCompany().getId();
        boolean enabled = companyRepo.findById(companyId).map(Company::isShiftRegistrationEnabled).orElse(false);
        if (!enabled) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.shift_registration.disabled");
        return companyId;
    }

    /** Phạm vi phòng ban của người quản lý theo SHIFT_VIEW (rỗng = cả công ty). */
    private Set<Long> managerScope(User user) {
        return deptScopeService.resolvedScopes(user.getId(), "SHIFT_VIEW");
    }

    private boolean visible(ShiftRegistrationRound r, Set<Long> scope) {
        if (scope.isEmpty()) return true;
        return deptScopeService.expandDepartmentsWithDescendants(r.getDepartmentIds()).stream().anyMatch(scope::contains);
    }

    private ShiftRegistrationRound getRound(Long companyId, Long id, Set<Long> scope) {
        return roundRepo.findByIdAndCompanyId(id, companyId).filter(r -> visible(r, scope))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift_registration.not_found"));
    }

    private ShiftRegistration getRegistrationForManager(User user, Long companyId, Long regId) {
        ShiftRegistration reg = regRepo.findById(regId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift_registration.not_found"));
        Set<Long> scope = managerScope(user);
        getRound(companyId, reg.getRoundId(), scope);
        if (!WorkShiftService.inShiftScope(reg.getEmployee(), scope, user.getEmployeeId())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift_registration.not_found");
        }
        return reg;
    }

    private static void requireNotOwn(User user, ShiftRegistration reg) {
        if (user.getEmployeeId() != null && user.getEmployeeId().equals(reg.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.shift_registration.cannot_process_own");
        }
    }

    private Employee requireEmployee(User user) {
        if (user.getEmployeeId() == null) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.shift_registration.not_in_scope");
        return employeeRepo.findByIdAndCompanyId(user.getEmployeeId(), user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "error.shift_registration.not_in_scope"));
    }

    private WorkShift requireShift(Long companyId, Long shiftId) {
        return shiftRepo.findById(shiftId)
            .filter(s -> s.isActive() && s.getCompany() != null && companyId.equals(s.getCompany().getId()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.shift.not_found"));
    }

    private boolean eligible(ShiftRegistrationRound r, Employee e) {
        return e.getStatus() == Employee.Status.ACTIVE && e.getDepartment() != null
            && deptScopeService.expandDepartmentsWithDescendants(r.getDepartmentIds()).contains(e.getDepartment().getId());
    }

    private List<Employee> roundEmployees(ShiftRegistrationRound r) {
        return roundEmployees(r, employeeRepo.findAllByCompanyIdFetchDepartment(r.getCompanyId()));
    }

    private List<Employee> roundEmployees(ShiftRegistrationRound r, List<Employee> all) {
        Set<Long> depts = deptScopeService.expandDepartmentsWithDescendants(r.getDepartmentIds());
        return all.stream()
            .filter(e -> e.getStatus() == Employee.Status.ACTIVE && e.getDepartment() != null && depts.contains(e.getDepartment().getId()))
            .toList();
    }

    private int registeredCount(Long roundId) {
        return regRepo.countEmployeesByRound(List.of(roundId)).stream().findFirst().map(x -> ((Long) x[1]).intValue()).orElse(0);
    }

    private void notifyOpened(ShiftRegistrationRound r) {
        try {
            String title = "Đăng ký lịch: " + r.getName();
            String body = r.getFromDate().format(DMY) + " – " + r.getToDate().format(DMY)
                + (r.getClosesAt() != null ? " · hạn " + r.getClosesAt().format(DateTimeFormatter.ofPattern("dd/MM HH:mm")) : "");
            for (Employee e : roundEmployees(r)) {
                userRepo.findByEmployeeId(e.getId())
                    .filter(u -> u.getFcmToken() != null && u.isEnabled())
                    .ifPresent(u -> fcmService.sendSimple(u.getFcmToken(), title, body,
                        Map.of("type", "SHIFT_REGISTRATION", "roundId", String.valueOf(r.getId()))));
            }
        } catch (Exception ex) {
            log.warn("Shift registration notify failed for round {}: {}", r.getId(), ex.getMessage());
        }
    }

    private ShiftRegistrationDTO.SelfRoundResponse selfResponse(ShiftRegistrationRound r, Employee me, Context ctx) {
        List<ShiftRegistrationDTO.RegistrationResponse> regs = regRepo
            .findByRoundIdAndEmployeeIdOrderByWorkDateAscStartTimeAsc(r.getId(), me.getId()).stream()
            .map(x -> toRegResponse(x, ctx)).toList();
        return ShiftRegistrationDTO.SelfRoundResponse.builder()
            .round(toRoundResponse(r, ctx, 0))
            .editable(r.getStatus() == ShiftRegistrationRound.Status.OPEN && eligible(r, me))
            .registrations(regs).shifts(ctx.shiftOptions()).build();
    }

    private ShiftRegistrationDTO.RoundResponse toRoundResponse(ShiftRegistrationRound r, Context ctx, int registered) {
        List<ShiftDTO.DeptRef> depts = r.getDepartmentIds().stream()
            .map(id -> new ShiftDTO.DeptRef(id, ctx.deptName(id)))
            .sorted(Comparator.comparing(ShiftDTO.DeptRef::getName, Comparator.nullsLast(String::compareTo)))
            .toList();
        return ShiftRegistrationDTO.RoundResponse.builder()
            .id(r.getId()).name(r.getName()).fromDate(r.getFromDate()).toDate(r.getToDate())
            .status(r.getStatus().name()).closesAt(r.getClosesAt())
            .earliestTime(r.getEarliestTime()).latestTime(r.getLatestTime())
            .minHours(r.getMinHours()).maxHours(r.getMaxHours()).minDays(r.getMinDays()).neededPerDay(r.getNeededPerDay())
            .note(r.getNote()).departments(depts)
            .registeredCount(registered).employeeCount(roundEmployees(r, ctx.employees()).size())
            .createdByName(ctx.userName(r.getCreatedBy()))
            .build();
    }

    private ShiftRegistrationDTO.RegistrationResponse toRegResponse(ShiftRegistration x, Context ctx) {
        WorkShift ws = x.getShiftId() != null ? ctx.shiftAny(x.getShiftId()) : null;
        // Đã duyệt: giờ / ca thực tế của phân ca đã tạo (có thể khác đăng ký, vd. "rảnh cả ngày" được xếp ca SANG).
        ShiftAssignment sa = x.getAssignmentId() != null ? ctx.assignment(x.getAssignmentId()) : null;
        return ShiftRegistrationDTO.RegistrationResponse.builder()
            .assignedShiftCode(sa != null && sa.getShift() != null ? sa.getShift().getCode() : null)
            .assignedStartTime(sa != null ? sa.effectiveStartTime() : null)
            .assignedEndTime(sa != null ? sa.effectiveEndTime() : null)
            .id(x.getId()).employeeId(x.getEmployee().getId()).workDate(x.getWorkDate())
            .kind(x.getKind().name()).shiftId(x.getShiftId()).shiftCode(ws != null ? ws.getCode() : null)
            .startTime(x.getStartTime()).endTime(x.getEndTime()).note(x.getNote())
            .status(x.getStatus().name()).assignmentId(x.getAssignmentId())
            .build();
    }

    private LocalDate today() {
        return LocalDate.now(clock);
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    /** Tra cứu dùng chung trong một lần gọi (ca, tên phòng ban, tên người tạo). */
    private final class Context {
        private final Long companyId;
        private Map<Long, WorkShift> shifts;
        private Map<Long, String> deptNames;
        private final Map<Long, String> userNames = new HashMap<>();
        private List<Employee> employees;
        private final Map<Long, ShiftAssignment> assignments = new HashMap<>();

        Context(Long companyId) {
            this.companyId = companyId;
        }

        WorkShift shift(Long id) {
            return id == null ? null : activeShifts().get(id);
        }

        /** Phân ca đã tạo khi duyệt; đã bị xoá → null. Nạp sẵn cả lô bằng preloadAssignments. */
        ShiftAssignment assignment(Long id) {
            if (!assignments.containsKey(id)) assignments.put(id, assignRepo.findById(id).orElse(null));
            return assignments.get(id);
        }

        void preloadAssignments(Collection<ShiftRegistration> regs) {
            List<Long> ids = regs.stream().map(ShiftRegistration::getAssignmentId).filter(Objects::nonNull)
                .filter(id -> !assignments.containsKey(id)).toList();
            if (ids.isEmpty()) return;
            ids.forEach(id -> assignments.put(id, null));
            assignRepo.findAllById(ids).forEach(a -> assignments.put(a.getId(), a));
        }

        WorkShift shiftAny(Long id) {
            WorkShift s = activeShifts().get(id);
            return s != null ? s : shiftRepo.findById(id).orElse(null);
        }

        Map<Long, WorkShift> activeShifts() {
            if (shifts == null) {
                shifts = new LinkedHashMap<>();
                shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream()
                    .sorted(Comparator.comparing(WorkShift::getStartTime, Comparator.nullsLast(Comparator.naturalOrder())))
                    .forEach(s -> shifts.put(s.getId(), s));
            }
            return shifts;
        }

        List<ShiftRegistrationDTO.ShiftOption> shiftOptions() {
            return activeShifts().values().stream()
                .filter(s -> s.getStartTime() != null && s.getEndTime() != null)
                .map(s -> ShiftRegistrationDTO.ShiftOption.builder().id(s.getId()).code(s.getCode()).name(s.getName())
                    .startTime(s.getStartTime()).endTime(s.getEndTime()).color(s.getColor()).build())
                .toList();
        }

        String deptName(Long id) {
            if (deptNames == null) {
                deptNames = new HashMap<>();
                departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId).forEach(d -> deptNames.put(d.getId(), d.getName()));
            }
            return deptNames.get(id);
        }

        List<Employee> employees() {
            if (employees == null) employees = employeeRepo.findAllByCompanyIdFetchDepartment(companyId);
            return employees;
        }

        String userName(Long userId) {
            if (userId == null) return null;
            return userNames.computeIfAbsent(userId, id -> userRepo.findById(id)
                .map(u -> u.getEmployee() != null ? u.getEmployee().getFullName() : u.getEmail()).orElse(null));
        }
    }
}
