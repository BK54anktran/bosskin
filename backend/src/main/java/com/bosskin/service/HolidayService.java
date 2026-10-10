package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.DepartmentDTO;
import com.bosskin.dto.HolidayDTO;
import com.bosskin.entity.Holiday;
import com.bosskin.repository.HolidayRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;

/**
 * Bước J: ngày lễ. Mẫu hệ thống ({@code company_id} null) do system admin sửa; công ty chưa chỉnh năm nào thì
 * dùng mẫu năm đó. Lần chỉnh đầu tiên trong năm chép mẫu sang công ty (copy-on-write), sau đó chỉ dùng bản của công ty.
 */
@Service
@RequiredArgsConstructor
public class HolidayService {

    static final int MIN_YEAR = 2000;
    static final int MAX_YEAR = 2100;

    private final HolidayRepository repository;
    private final AuditService audit;

    // ── Tra cứu ──────────────────────────────────────────────────────────────

    /** Ngày lễ hiệu lực của công ty trong [from, to]: năm đã chỉnh dùng bản công ty, năm khác dùng mẫu. */
    @Transactional(readOnly = true)
    public List<Holiday> effective(Long companyId, LocalDate from, LocalDate to) {
        Set<Integer> customized = new HashSet<>(repository.findCustomizedYears(companyId, from, to));
        List<Holiday> out = new ArrayList<>();
        for (Holiday h : repository.findActive(companyId, from, to)) {
            if (customized.contains(h.getDate().getYear())) out.add(h);
        }
        for (Holiday h : repository.findActive(null, from, to)) {
            if (!customized.contains(h.getDate().getYear())) out.add(h);
        }
        out.sort(Comparator.comparing(Holiday::getDate));
        return out;
    }

    @Transactional(readOnly = true)
    public HolidayDTO.YearView year(Long companyId, int year) {
        checkYear(year);
        LocalDate from = LocalDate.of(year, 1, 1), to = LocalDate.of(year, 12, 31);
        boolean customized = !repository.findCustomizedYears(companyId, from, to).isEmpty();
        return HolidayDTO.YearView.builder().year(year).customized(customized)
            .items(effective(companyId, from, to).stream().map(HolidayDTO.Response::of).toList()).build();
    }

    // ── Công ty chỉnh ────────────────────────────────────────────────────────

    @Transactional
    public HolidayDTO.Response create(Long companyId, HolidayDTO.Upsert req) {
        validate(req);
        ensureCustomized(companyId, req.getDate().getYear());
        requireFreeDate(companyId, req.getDate(), null);
        Holiday h = repository.save(Holiday.builder().companyId(companyId).date(req.getDate())
            .name(req.getName().trim()).type(req.getType()).paid(paidOf(req)).build());
        audit.log("HOLIDAY_CREATE").entity("HOLIDAY", h.getId()).summary(h.getDate() + " " + h.getName())
            .detail(HolidayDTO.Response.of(h)).save();
        return HolidayDTO.Response.of(h);
    }

    /** {@code id} có thể là id dòng mẫu (công ty đang theo mẫu) — chép mẫu rồi sửa bản của công ty. */
    @Transactional
    public HolidayDTO.Response update(Long companyId, Long id, HolidayDTO.Upsert req) {
        validate(req);
        Holiday h = resolveForCompany(companyId, id);
        ensureCustomized(companyId, req.getDate().getYear());
        requireFreeDate(companyId, req.getDate(), h.getId());
        HolidayDTO.Response before = HolidayDTO.Response.of(h);
        h.setDate(req.getDate());
        h.setName(req.getName().trim());
        h.setType(req.getType());
        h.setPaid(paidOf(req));
        h = repository.save(h);
        audit.log("HOLIDAY_UPDATE").entity("HOLIDAY", h.getId()).summary(h.getDate() + " " + h.getName())
            .detail(AuditService.map("before", before, "after", HolidayDTO.Response.of(h))).save();
        return HolidayDTO.Response.of(h);
    }

    @Transactional
    public void delete(Long companyId, Long id) {
        Holiday h = resolveForCompany(companyId, id);
        h.setDeleted(true);
        repository.save(h);
        audit.log("HOLIDAY_DELETE").entity("HOLIDAY", h.getId()).summary(h.getDate() + " " + h.getName()).save();
    }

    /** Dòng của công ty ứng với {@code id}; id dòng mẫu → chép mẫu năm đó rồi lấy bản chép cùng ngày. */
    private Holiday resolveForCompany(Long companyId, Long id) {
        Holiday h = repository.findById(id).filter(x -> !x.isDeleted())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.holiday.not_found"));
        if (h.getCompanyId() == null) {
            ensureCustomized(companyId, h.getDate().getYear());
            return repository.findActiveOn(companyId, h.getDate())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.holiday.not_found"));
        }
        if (!h.getCompanyId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.holiday.not_found");
        }
        return h;
    }

    /** Năm chưa chỉnh → chép toàn bộ mẫu năm đó sang công ty. */
    private void ensureCustomized(Long companyId, int year) {
        checkYear(year);
        LocalDate from = LocalDate.of(year, 1, 1), to = LocalDate.of(year, 12, 31);
        if (!repository.findCustomizedYears(companyId, from, to).isEmpty()) return;
        List<Holiday> template = repository.findActive(null, from, to);
        for (Holiday t : template) {
            repository.save(Holiday.builder().companyId(companyId).date(t.getDate()).name(t.getName())
                .type(t.getType()).paid(t.isPaid()).build());
        }
        repository.flush();
    }

    private void requireFreeDate(Long companyId, LocalDate date, Long exceptId) {
        repository.findActiveOn(companyId, date).filter(x -> !x.getId().equals(exceptId)).ifPresent(x -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.holiday.duplicate_date|" + date);
        });
    }

    // ── Mẫu hệ thống (system admin) ──────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<HolidayDTO.Response> templateYear(int year) {
        checkYear(year);
        return repository.findActive(null, LocalDate.of(year, 1, 1), LocalDate.of(year, 12, 31)).stream()
            .map(HolidayDTO.Response::of).toList();
    }

    @Transactional(readOnly = true)
    public List<Integer> templateYears() {
        return repository.findTemplateYears();
    }

    @Transactional
    public HolidayDTO.Response createTemplate(HolidayDTO.Upsert req) {
        validate(req);
        requireFreeDate(null, req.getDate(), null);
        Holiday h = repository.save(Holiday.builder().date(req.getDate()).name(req.getName().trim())
            .type(req.getType()).paid(paidOf(req)).build());
        audit.log("HOLIDAY_TEMPLATE_CREATE").entity("HOLIDAY", h.getId()).summary(h.getDate() + " " + h.getName()).save();
        return HolidayDTO.Response.of(h);
    }

    @Transactional
    public HolidayDTO.Response updateTemplate(Long id, HolidayDTO.Upsert req) {
        validate(req);
        Holiday h = templateOrThrow(id);
        requireFreeDate(null, req.getDate(), id);
        HolidayDTO.Response before = HolidayDTO.Response.of(h);
        h.setDate(req.getDate());
        h.setName(req.getName().trim());
        h.setType(req.getType());
        h.setPaid(paidOf(req));
        h = repository.save(h);
        audit.log("HOLIDAY_TEMPLATE_UPDATE").entity("HOLIDAY", h.getId()).summary(h.getDate() + " " + h.getName())
            .detail(AuditService.map("before", before, "after", HolidayDTO.Response.of(h))).save();
        return HolidayDTO.Response.of(h);
    }

    @Transactional
    public void deleteTemplate(Long id) {
        Holiday h = templateOrThrow(id);
        h.setDeleted(true);
        repository.save(h);
        audit.log("HOLIDAY_TEMPLATE_DELETE").entity("HOLIDAY", h.getId()).summary(h.getDate() + " " + h.getName()).save();
    }

    private Holiday templateOrThrow(Long id) {
        return repository.findById(id).filter(h -> h.getCompanyId() == null && !h.isDeleted())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.holiday.not_found"));
    }

    // ── Excel (theo năm, khoá = ngày) ────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<HolidayDTO.ImportDiff> previewImport(Long companyId, List<HolidayDTO.ImportRow> rows) {
        Map<LocalDate, Holiday> current = currentFor(companyId, rows);
        List<HolidayDTO.ImportDiff> out = new ArrayList<>();
        for (Parsed p : parse(rows)) {
            Holiday h = current.get(p.date);
            String code = p.date.toString();
            if (p.delete) {
                if (h != null) out.add(HolidayDTO.ImportDiff.builder().action("DELETE").code(code).name(h.getName())
                    .changes(List.of()).warnings(List.of()).build());
                continue;
            }
            if (h == null) {
                out.add(HolidayDTO.ImportDiff.builder().action("CREATE").code(code).name(p.name)
                    .changes(List.of(
                        change("type", "", p.type.name()),
                        change("paid", "", String.valueOf(p.paid))))
                    .warnings(List.of()).build());
                continue;
            }
            List<DepartmentDTO.FieldChange> changes = new ArrayList<>();
            addChange(changes, "name", h.getName(), p.name);
            addChange(changes, "type", h.getType().name(), p.type.name());
            addChange(changes, "paid", String.valueOf(h.isPaid()), String.valueOf(p.paid));
            out.add(HolidayDTO.ImportDiff.builder().action(changes.isEmpty() ? "NO_CHANGE" : "UPDATE")
                .code(code).name(p.name).changes(changes).warnings(List.of()).build());
        }
        return out;
    }

    @Transactional
    public Map<String, Integer> importFromExcel(Long companyId, List<HolidayDTO.ImportRow> rows) {
        List<Parsed> parsed = parse(rows);
        new TreeSet<>(parsed.stream().map(p -> p.date.getYear()).toList()).forEach(y -> ensureCustomized(companyId, y));
        int created = 0, updated = 0, deleted = 0;
        // Xoá trước để ngày vừa xoá có thể tạo lại trong cùng file
        for (Parsed p : parsed) {
            if (!p.delete) continue;
            Optional<Holiday> h = repository.findActiveOn(companyId, p.date);
            if (h.isPresent()) { h.get().setDeleted(true); repository.saveAndFlush(h.get()); deleted++; }
        }
        for (Parsed p : parsed) {
            if (p.delete) continue;
            Optional<Holiday> existing = repository.findActiveOn(companyId, p.date);
            if (existing.isEmpty()) {
                repository.save(Holiday.builder().companyId(companyId).date(p.date).name(p.name)
                    .type(p.type).paid(p.paid).build());
                created++;
            } else {
                Holiday h = existing.get();
                if (!h.getName().equals(p.name) || h.getType() != p.type || h.isPaid() != p.paid) {
                    h.setName(p.name);
                    h.setType(p.type);
                    h.setPaid(p.paid);
                    repository.save(h);
                    updated++;
                }
            }
        }
        Map<String, Integer> result = Map.of("created", created, "updated", updated, "deleted", deleted);
        audit.log("HOLIDAY_IMPORT").entity("HOLIDAY", null).summary("+" + created + " ~" + updated + " -" + deleted)
            .detail(result).save();
        return result;
    }

    /** Ngày lễ hiệu lực hiện tại theo các năm có trong file. */
    private Map<LocalDate, Holiday> currentFor(Long companyId, List<HolidayDTO.ImportRow> rows) {
        Map<LocalDate, Holiday> m = new HashMap<>();
        for (int y : new TreeSet<>(parse(rows).stream().map(p -> p.date.getYear()).toList())) {
            for (Holiday h : effective(companyId, LocalDate.of(y, 1, 1), LocalDate.of(y, 12, 31))) m.put(h.getDate(), h);
        }
        return m;
    }

    private record Parsed(LocalDate date, String name, Holiday.Type type, boolean paid, boolean delete) {}

    private List<Parsed> parse(List<HolidayDTO.ImportRow> rows) {
        List<Parsed> out = new ArrayList<>();
        Set<LocalDate> seen = new HashSet<>();
        for (HolidayDTO.ImportRow r : rows) {
            if (r.getDate() == null || r.getDate().isBlank()) continue;
            LocalDate date = parseDate(r.getDate().trim());
            checkYear(date.getYear());
            if (!seen.add(date)) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.holiday.duplicate_date|" + date);
            }
            if (r.isMarkedDelete()) {
                out.add(new Parsed(date, null, null, false, true));
                continue;
            }
            String name = r.getName() == null ? "" : r.getName().trim();
            if (name.isEmpty()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.holiday.name_required|" + date);
            }
            if (name.length() > 150) name = name.substring(0, 150);
            out.add(new Parsed(date, name, parseType(r.getType(), date), parsePaid(r.getPaid()), false));
        }
        return out;
    }

    private static final List<DateTimeFormatter> DATE_FORMATS = List.of(
        DateTimeFormatter.ISO_LOCAL_DATE, DateTimeFormatter.ofPattern("d/M/yyyy"), DateTimeFormatter.ofPattern("d-M-yyyy"));

    static LocalDate parseDate(String v) {
        if (v.matches("\\d{5}(\\.0+)?")) { // số seri ngày của Excel
            return LocalDate.of(1899, 12, 30).plusDays(Long.parseLong(v.replaceAll("\\..*", "")));
        }
        for (DateTimeFormatter f : DATE_FORMATS) {
            try { return LocalDate.parse(v, f); } catch (DateTimeParseException ignored) { }
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.holiday.date_invalid|" + v);
    }

    private static Holiday.Type parseType(String v, LocalDate date) {
        if (v == null || v.isBlank()) return Holiday.Type.HOLIDAY;
        String s = v.trim().toUpperCase(Locale.ROOT);
        for (Holiday.Type t : Holiday.Type.values()) if (t.name().equals(s)) return t;
        String l = v.trim().toLowerCase(Locale.ROOT);
        if (l.startsWith("lễ") || l.startsWith("le") || l.startsWith("holiday")) return Holiday.Type.HOLIDAY;
        if (l.startsWith("nghỉ bù") || l.startsWith("nghi bu") || l.startsWith("compensatory")) return Holiday.Type.COMPENSATORY;
        if (l.startsWith("làm bù") || l.startsWith("lam bu") || l.startsWith("swap") || l.startsWith("workday")) {
            return Holiday.Type.SWAP_WORKDAY;
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.holiday.type_invalid|" + date + "|" + v);
    }

    private static boolean parsePaid(String v) {
        if (v == null || v.isBlank()) return true;
        String l = v.trim().toLowerCase(Locale.ROOT);
        return !(l.equals("0") || l.equals("false") || l.equals("no") || l.equals("không") || l.equals("khong") || l.equals("n"));
    }

    private static DepartmentDTO.FieldChange change(String field, String oldV, String newV) {
        return DepartmentDTO.FieldChange.builder().field(field).oldValue(oldV).newValue(newV).build();
    }

    private static void addChange(List<DepartmentDTO.FieldChange> list, String field, String oldV, String newV) {
        String o = oldV == null ? "" : oldV.trim(), n = newV == null ? "" : newV.trim();
        if (!o.equals(n)) list.add(change(field, o, n));
    }

    // ── Chung ────────────────────────────────────────────────────────────────

    private static void validate(HolidayDTO.Upsert req) {
        checkYear(req.getDate().getYear());
        if (req.getName() == null || req.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.holiday.name_required|" + req.getDate());
        }
    }

    /** Ngày làm bù luôn là ngày làm có lương — cờ paid chỉ có nghĩa với ngày nghỉ. */
    private static boolean paidOf(HolidayDTO.Upsert req) {
        return req.getType() == Holiday.Type.SWAP_WORKDAY || req.isPaid();
    }

    private static void checkYear(int year) {
        if (year < MIN_YEAR || year > MAX_YEAR) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.holiday.year_invalid");
        }
    }
}
