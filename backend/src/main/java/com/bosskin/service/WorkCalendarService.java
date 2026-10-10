package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.HolidayDTO;
import com.bosskin.dto.WorkCalendarDTO;
import com.bosskin.entity.Department;
import com.bosskin.entity.Holiday;
import com.bosskin.entity.WorkCalendar;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.WorkCalendarRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Bước J: lịch làm việc tuần theo công ty, ghi đè theo phòng ban (kế thừa phòng cha), cộng ngày lễ.
 * Dùng cho công chuẩn kỳ lương, tô ngày nghỉ ở bảng công / lưới phân ca / Excel, đơn nghỉ và xoay ca.
 */
@Service
@RequiredArgsConstructor
public class WorkCalendarService {

    private final WorkCalendarRepository repository;
    private final DepartmentRepository departmentRepository;
    private final HolidayService holidayService;
    private final AuditService audit;

    // ── Quản lý lịch ─────────────────────────────────────────────────────────

    /** Lịch mặc định luôn đứng đầu; chưa lưu thì trả bản ảo id = null, FFFFFOO. */
    @Transactional(readOnly = true)
    public List<WorkCalendarDTO.Response> list(Long companyId) {
        List<WorkCalendar> cals = repository.findByCompanyIdAndDeletedFalseOrderByIsDefaultDescNameAsc(companyId);
        Map<Long, List<Long>> deptsByCal = departmentRepository.findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getWorkCalendarId() != null)
            .collect(Collectors.groupingBy(Department::getWorkCalendarId, Collectors.mapping(Department::getId, Collectors.toList())));
        List<WorkCalendarDTO.Response> out = new ArrayList<>();
        if (cals.stream().noneMatch(WorkCalendar::isDefault)) {
            out.add(WorkCalendarDTO.Response.builder().name("").weekPattern(WorkCalendar.DEFAULT_PATTERN)
                .isDefault(true).departmentIds(List.of()).build());
        }
        for (WorkCalendar c : cals) {
            out.add(toResponse(c, c.isDefault() ? List.of() : deptsByCal.getOrDefault(c.getId(), List.of())));
        }
        return out;
    }

    @Transactional
    public WorkCalendarDTO.Response saveDefault(Long companyId, WorkCalendarDTO.DefaultUpsert req) {
        WorkCalendar c = repository.findByCompanyIdAndIsDefaultTrueAndDeletedFalse(companyId)
            .orElseGet(() -> WorkCalendar.builder().companyId(companyId).name("").isDefault(true).build());
        String before = c.getWeekPattern();
        c.setWeekPattern(req.getWeekPattern());
        c = repository.save(c);
        audit.log("WORK_CALENDAR_UPDATE").entity("WORK_CALENDAR", c.getId()).summary("default " + c.getWeekPattern())
            .detail(AuditService.map("before", before, "after", c.getWeekPattern())).save();
        return toResponse(c, List.of());
    }

    @Transactional
    public WorkCalendarDTO.Response create(Long companyId, WorkCalendarDTO.Upsert req) {
        WorkCalendar c = repository.save(WorkCalendar.builder().companyId(companyId).name(req.getName().trim())
            .weekPattern(req.getWeekPattern()).build());
        List<Long> depts = assignDepartments(companyId, c.getId(), req.getDepartmentIds());
        audit.log("WORK_CALENDAR_CREATE").entity("WORK_CALENDAR", c.getId()).summary(c.getName() + " " + c.getWeekPattern())
            .detail(AuditService.map("departmentIds", depts)).save();
        return toResponse(c, depts);
    }

    @Transactional
    public WorkCalendarDTO.Response update(Long companyId, Long id, WorkCalendarDTO.Upsert req) {
        WorkCalendar c = getOrThrow(companyId, id);
        if (c.isDefault()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.work_calendar.default_readonly");
        }
        String before = c.getName() + " " + c.getWeekPattern();
        c.setName(req.getName().trim());
        c.setWeekPattern(req.getWeekPattern());
        c = repository.save(c);
        List<Long> depts = assignDepartments(companyId, c.getId(), req.getDepartmentIds());
        audit.log("WORK_CALENDAR_UPDATE").entity("WORK_CALENDAR", c.getId()).summary(c.getName() + " " + c.getWeekPattern())
            .detail(AuditService.map("before", before, "departmentIds", depts)).save();
        return toResponse(c, depts);
    }

    @Transactional
    public void delete(Long companyId, Long id) {
        WorkCalendar c = getOrThrow(companyId, id);
        if (c.isDefault()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.work_calendar.default_readonly");
        }
        assignDepartments(companyId, id, List.of());
        c.setDeleted(true);
        repository.save(c);
        audit.log("WORK_CALENDAR_DELETE").entity("WORK_CALENDAR", id).summary(c.getName()).save();
    }

    /** Gán đúng danh sách phòng cho lịch: phòng trong danh sách → lịch này, phòng đang gán mà không còn → bỏ gán. */
    private List<Long> assignDepartments(Long companyId, Long calendarId, List<Long> departmentIds) {
        Set<Long> wanted = new HashSet<>(departmentIds == null ? List.of() : departmentIds);
        List<Long> assigned = new ArrayList<>();
        Set<Long> known = new HashSet<>();
        for (Department d : departmentRepository.findByCompanyIdOrderByLevelAscNameAsc(companyId)) {
            known.add(d.getId());
            boolean want = wanted.contains(d.getId());
            if (want && !calendarId.equals(d.getWorkCalendarId())) {
                d.setWorkCalendarId(calendarId);
                departmentRepository.save(d);
            } else if (!want && calendarId.equals(d.getWorkCalendarId())) {
                d.setWorkCalendarId(null);
                departmentRepository.save(d);
            }
            if (want) assigned.add(d.getId());
        }
        if (!known.containsAll(wanted)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.department.not_found");
        }
        return assigned;
    }

    private WorkCalendar getOrThrow(Long companyId, Long id) {
        return repository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.work_calendar.not_found"));
    }

    private static WorkCalendarDTO.Response toResponse(WorkCalendar c, List<Long> depts) {
        return WorkCalendarDTO.Response.builder().id(c.getId()).name(c.getName()).weekPattern(c.getWeekPattern())
            .isDefault(c.isDefault()).departmentIds(depts).build();
    }

    // ── Lịch đã giải ─────────────────────────────────────────────────────────

    /** Phòng ban để gán lịch (toàn công ty — lịch là cấu hình chung, không lọc theo phạm vi xem phòng ban). */
    @Transactional(readOnly = true)
    public List<WorkCalendarDTO.DepartmentOption> departments(Long companyId) {
        return departmentRepository.findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .map(d -> new WorkCalendarDTO.DepartmentOption(d.getId(), d.getName(), d.getLevel()))
            .toList();
    }

    @Transactional(readOnly = true)
    public WorkCalendarDTO.View viewDto(Long companyId, LocalDate from, LocalDate to) {
        if (to.isBefore(from) || to.isAfter(from.plusDays(400))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.date.range_invalid");
        }
        CalendarView v = view(companyId, from, to);
        return WorkCalendarDTO.View.builder().from(from).to(to)
            .holidays(v.holidays.values().stream().map(HolidayDTO.Response::of).toList())
            .defaultPattern(v.defaultPattern).departmentPatterns(v.departmentPatterns).build();
    }

    /** Ảnh chụp lịch của công ty trong [from, to] — dùng trong vòng lặp theo ngày, không truy vấn thêm. */
    @Transactional(readOnly = true)
    public CalendarView view(Long companyId, LocalDate from, LocalDate to) {
        Map<Long, String> patterns = new HashMap<>();
        String defaultPattern = WorkCalendar.DEFAULT_PATTERN;
        for (WorkCalendar c : repository.findByCompanyIdAndDeletedFalseOrderByIsDefaultDescNameAsc(companyId)) {
            if (c.isDefault()) defaultPattern = c.getWeekPattern();
            else patterns.put(c.getId(), c.getWeekPattern());
        }
        // Phòng chưa gán lịch kế thừa phòng cha; danh sách đã xếp theo level nên cha luôn được giải trước
        Map<Long, String> deptPatterns = new LinkedHashMap<>();
        for (Department d : departmentRepository.findByCompanyIdOrderByLevelAscNameAsc(companyId)) {
            String p = d.getWorkCalendarId() != null ? patterns.get(d.getWorkCalendarId()) : null;
            if (p == null && d.getParent() != null) p = deptPatterns.get(d.getParent().getId());
            deptPatterns.put(d.getId(), p != null ? p : defaultPattern);
        }
        Map<LocalDate, Holiday> holidays = new TreeMap<>();
        for (Holiday h : holidayService.effective(companyId, from, to)) holidays.put(h.getDate(), h);
        return new CalendarView(defaultPattern, deptPatterns, holidays);
    }

    /** Lịch đã giải: tra ngày nghỉ / nửa ngày / ngày lễ theo phòng ban. */
    public static final class CalendarView {
        private final String defaultPattern;
        private final Map<Long, String> departmentPatterns;
        private final Map<LocalDate, Holiday> holidays;

        CalendarView(String defaultPattern, Map<Long, String> departmentPatterns, Map<LocalDate, Holiday> holidays) {
            this.defaultPattern = defaultPattern;
            this.departmentPatterns = departmentPatterns;
            this.holidays = holidays;
        }

        public static CalendarView defaults() {
            return new CalendarView(WorkCalendar.DEFAULT_PATTERN, Map.of(), Map.of());
        }

        public Holiday holiday(LocalDate d) { return holidays.get(d); }

        /** Ngày lễ / nghỉ bù / nghỉ hoán đổi (không tính ngày làm bù). */
        public boolean isHolidayOff(LocalDate d) {
            Holiday h = holidays.get(d);
            return h != null && h.isDayOff();
        }

        public String patternOf(Long departmentId) {
            return departmentId == null ? defaultPattern : departmentPatterns.getOrDefault(departmentId, defaultPattern);
        }

        /** Hệ số ngày làm theo lịch tuần (chưa xét ngày lễ): 1 cả ngày, 0.5 nửa ngày, 0 nghỉ. */
        public double weekWeight(Long departmentId, LocalDate d) {
            return switch (patternOf(departmentId).charAt(d.getDayOfWeek().getValue() - 1)) {
                case 'F' -> 1.0;
                case 'H' -> 0.5;
                default -> 0.0;
            };
        }

        /** Hệ số ngày phải đi làm sau khi xét ngày lễ: làm bù = 1, ngày lễ / nghỉ bù = 0. */
        public double workWeight(Long departmentId, LocalDate d) {
            Holiday h = holidays.get(d);
            if (h != null) return h.isDayOff() ? 0.0 : 1.0;
            return weekWeight(departmentId, d);
        }

        /** Ngày nghỉ (không phải đi làm) — tô màu như cuối tuần. */
        public boolean isOff(Long departmentId, LocalDate d) {
            return workWeight(departmentId, d) == 0.0;
        }

        /**
         * Công chuẩn và ngày lễ hưởng lương của một phòng trong [from, to]. Ngày lễ có lương rơi vào ngày làm
         * theo lịch tuần vẫn tính công chuẩn (được trả lương) và cộng vào HOLIDAY_DAYS; ngày nghỉ hoán đổi
         * (HOLIDAY không lương) bỏ khỏi công chuẩn; ngày làm bù cộng 1.
         */
        public PeriodDays periodDays(Long departmentId, LocalDate from, LocalDate to) {
            double standard = 0, holiday = 0;
            for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
                Holiday h = holidays.get(d);
                double week = weekWeight(departmentId, d);
                if (h == null) {
                    standard += week;
                } else if (!h.isDayOff()) {
                    standard += 1.0;
                } else if (h.isPaid()) {
                    standard += week;
                    holiday += week;
                }
            }
            return new PeriodDays(BigDecimal.valueOf(standard).setScale(2, java.math.RoundingMode.HALF_UP),
                BigDecimal.valueOf(holiday).setScale(2, java.math.RoundingMode.HALF_UP));
        }
    }

    public record PeriodDays(BigDecimal standardDays, BigDecimal holidayDays) {}
}
