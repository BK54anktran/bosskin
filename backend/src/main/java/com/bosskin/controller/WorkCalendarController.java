package com.bosskin.controller;

import com.bosskin.dto.HolidayDTO;
import com.bosskin.dto.WorkCalendarDTO;
import com.bosskin.entity.User;
import com.bosskin.service.HolidayService;
import com.bosskin.service.WorkCalendarService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelSheet;
import com.bosskin.util.ExcelUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * Bước J — ngày lễ và lịch làm việc tuần.
 * <pre>
 * GET    /api/v1/holidays?year=                    — CALENDAR_VIEW
 * POST   /api/v1/holidays                          — CALENDAR_MANAGE (lần đầu trong năm chép mẫu hệ thống)
 * PUT    /api/v1/holidays/{id}                     — CALENDAR_MANAGE (id mẫu → chép rồi sửa bản công ty)
 * DELETE /api/v1/holidays/{id}                     — CALENDAR_MANAGE
 * GET    /api/v1/holidays/export?year=             — CALENDAR_VIEW
 * POST   /api/v1/holidays/preview-import           — CALENDAR_MANAGE
 * POST   /api/v1/holidays/import                   — CALENDAR_MANAGE
 * GET    /api/v1/work-calendars                    — CALENDAR_VIEW
 * PUT    /api/v1/work-calendars/default            — CALENDAR_MANAGE
 * POST   /api/v1/work-calendars                    — CALENDAR_MANAGE
 * PUT    /api/v1/work-calendars/{id}               — CALENDAR_MANAGE
 * DELETE /api/v1/work-calendars/{id}               — CALENDAR_MANAGE
 * GET    /api/v1/work-calendars/departments        — CALENDAR_VIEW (phòng ban để gán lịch)
 * GET    /api/v1/work-calendars/view?from=&to=     — CALENDAR_VIEW / SHIFT_VIEW / ATTENDANCE_VIEW / ATTENDANCE_SELF
 * </pre>
 */
@RestController
@RequiredArgsConstructor
public class WorkCalendarController {

    private final HolidayService holidayService;
    private final WorkCalendarService calendarService;
    private final ExcelI18n excelI18n;

    private static final List<ExcelColumn<HolidayDTO.Response>> EXPORT_COLUMNS = List.of(
        ExcelColumn.readOnlyI18n("excel.col.holiday.date", r -> r.getDate().toString()),
        ExcelColumn.readOnlyI18n("excel.col.holiday.name", HolidayDTO.Response::getName),
        ExcelColumn.readOnlyI18n("excel.col.holiday.type", r -> r.getType().name()),
        ExcelColumn.readOnlyI18n("excel.col.holiday.paid", r -> r.isPaid() ? "1" : "0"),
        ExcelColumn.readOnlyI18n("excel.col.holiday.delete", r -> "")
    );

    private static final List<ExcelColumn<HolidayDTO.ImportRow>> IMPORT_COLUMNS = List.of(
        ExcelColumn.ofI18n("excel.col.holiday.date", HolidayDTO.ImportRow::getDate, HolidayDTO.ImportRow::setDate),
        ExcelColumn.ofI18n("excel.col.holiday.name", HolidayDTO.ImportRow::getName, HolidayDTO.ImportRow::setName),
        ExcelColumn.ofI18n("excel.col.holiday.type", HolidayDTO.ImportRow::getType, HolidayDTO.ImportRow::setType),
        ExcelColumn.ofI18n("excel.col.holiday.paid", HolidayDTO.ImportRow::getPaid, HolidayDTO.ImportRow::setPaid),
        ExcelColumn.ofI18n("excel.col.holiday.delete", HolidayDTO.ImportRow::getDelete, HolidayDTO.ImportRow::setDelete)
    );

    // ── Ngày lễ ──────────────────────────────────────────────────────────────

    @GetMapping("/api/v1/holidays")
    public ResponseEntity<HolidayDTO.YearView> holidays(@AuthenticationPrincipal User user, @RequestParam int year) {
        requireAny(user, "CALENDAR_VIEW");
        return ResponseEntity.ok(holidayService.year(companyId(user), year));
    }

    @PostMapping("/api/v1/holidays")
    public ResponseEntity<HolidayDTO.Response> createHoliday(@AuthenticationPrincipal User user,
                                                             @Valid @RequestBody HolidayDTO.Upsert req) {
        requireManage(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(holidayService.create(companyId(user), req));
    }

    @PutMapping("/api/v1/holidays/{id}")
    public ResponseEntity<HolidayDTO.Response> updateHoliday(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                             @Valid @RequestBody HolidayDTO.Upsert req) {
        requireManage(user);
        return ResponseEntity.ok(holidayService.update(companyId(user), id, req));
    }

    @DeleteMapping("/api/v1/holidays/{id}")
    public ResponseEntity<Void> deleteHoliday(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requireManage(user);
        holidayService.delete(companyId(user), id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/holidays/export")
    public ResponseEntity<byte[]> exportHolidays(@AuthenticationPrincipal User user, @RequestParam int year) {
        requireAny(user, "CALENDAR_VIEW");
        List<HolidayDTO.Response> rows = holidayService.year(companyId(user), year).getItems();
        return ExcelUtils.exportSheets("excel.file.holiday",
            List.of(ExcelSheet.ofI18n("excel.sheet.holiday", EXPORT_COLUMNS, rows)),
            excelI18n, LocaleContextHolder.getLocale());
    }

    @PostMapping("/api/v1/holidays/preview-import")
    public ResponseEntity<List<HolidayDTO.ImportDiff>> previewImport(@AuthenticationPrincipal User user,
                                                                     @RequestParam("file") MultipartFile file) {
        requireManage(user);
        List<HolidayDTO.ImportRow> rows = ExcelUtils.importRowsByHeader(file, 0, IMPORT_COLUMNS, HolidayDTO.ImportRow::new, excelI18n);
        return ResponseEntity.ok(holidayService.previewImport(companyId(user), rows));
    }

    @PostMapping("/api/v1/holidays/import")
    public ResponseEntity<Map<String, Integer>> importHolidays(@AuthenticationPrincipal User user,
                                                               @RequestParam("file") MultipartFile file) {
        requireManage(user);
        List<HolidayDTO.ImportRow> rows = ExcelUtils.importRowsByHeader(file, 0, IMPORT_COLUMNS, HolidayDTO.ImportRow::new, excelI18n);
        return ResponseEntity.ok(holidayService.importFromExcel(companyId(user), rows));
    }

    // ── Lịch tuần ────────────────────────────────────────────────────────────

    @GetMapping("/api/v1/work-calendars")
    public ResponseEntity<List<WorkCalendarDTO.Response>> calendars(@AuthenticationPrincipal User user) {
        requireAny(user, "CALENDAR_VIEW");
        return ResponseEntity.ok(calendarService.list(companyId(user)));
    }

    @PutMapping("/api/v1/work-calendars/default")
    public ResponseEntity<WorkCalendarDTO.Response> saveDefault(@AuthenticationPrincipal User user,
                                                                @Valid @RequestBody WorkCalendarDTO.DefaultUpsert req) {
        requireManage(user);
        return ResponseEntity.ok(calendarService.saveDefault(companyId(user), req));
    }

    @PostMapping("/api/v1/work-calendars")
    public ResponseEntity<WorkCalendarDTO.Response> createCalendar(@AuthenticationPrincipal User user,
                                                                   @Valid @RequestBody WorkCalendarDTO.Upsert req) {
        requireManage(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(calendarService.create(companyId(user), req));
    }

    @PutMapping("/api/v1/work-calendars/{id}")
    public ResponseEntity<WorkCalendarDTO.Response> updateCalendar(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                                   @Valid @RequestBody WorkCalendarDTO.Upsert req) {
        requireManage(user);
        return ResponseEntity.ok(calendarService.update(companyId(user), id, req));
    }

    @DeleteMapping("/api/v1/work-calendars/{id}")
    public ResponseEntity<Void> deleteCalendar(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requireManage(user);
        calendarService.delete(companyId(user), id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/work-calendars/departments")
    public ResponseEntity<List<WorkCalendarDTO.DepartmentOption>> calendarDepartments(@AuthenticationPrincipal User user) {
        requireAny(user, "CALENDAR_VIEW");
        return ResponseEntity.ok(calendarService.departments(companyId(user)));
    }

    /** Lịch đã giải để tô màu lưới phân ca / bảng công — đọc được với quyền xem ca hoặc công. */
    @GetMapping("/api/v1/work-calendars/view")
    public ResponseEntity<WorkCalendarDTO.View> view(@AuthenticationPrincipal User user,
                                                     @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                     @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireAny(user, "CALENDAR_VIEW", "SHIFT_VIEW", "ATTENDANCE_VIEW", "ATTENDANCE_SELF");
        return ResponseEntity.ok(calendarService.viewDto(companyId(user), from, to));
    }

    private static void requireManage(User user) {
        requireAny(user, "CALENDAR_VIEW");
        requireAny(user, "CALENDAR_MANAGE");
    }

    private static void requireAny(User user, String... perms) {
        if (user != null) for (String p : perms) if (user.hasPermission(p)) return;
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    private static Long companyId(User user) {
        if (user.getCompanyId() == null) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        return user.getCompanyId();
    }
}
