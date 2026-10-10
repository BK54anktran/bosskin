package com.bosskin.service.descriptor;

import com.bosskin.entity.Department;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.WorkShiftRepository;
import com.bosskin.service.ShiftExcelService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.FilterDefinition;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.RequiredArgsConstructor;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Component
@Order(40) // bước E: thứ tự nhập theo phụ thuộc (phòng ban → … → nhân viên → số dư phép / phân ca)
@RequiredArgsConstructor
public class ShiftDescriptor implements ExcelEntityDescriptor<ShiftExcelService.ShiftRow> {

    private final ShiftExcelService    shiftExcelService;
    private final WorkShiftRepository  shiftRepo;
    private final DepartmentRepository deptRepo;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    @Override public String sheetKey() { return "excel.sheet.shift.list"; }
    @Override public String type()     { return "shift"; }

    @Override
    public List<ExcelColumn<ShiftExcelService.ShiftRow>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.shift.code",      r -> r.code,       (r, v) -> r.code = v),
            ExcelColumn.ofI18n("excel.col.shift.name",      r -> r.name,       (r, v) -> r.name = v),
            ExcelColumn.ofI18n("excel.col.shift.startTime", r -> r.startTime,  (r, v) -> r.startTime = v),
            ExcelColumn.ofI18n("excel.col.shift.endTime",   r -> r.endTime,    (r, v) -> r.endTime = v),
            ExcelColumn.ofI18n("excel.col.shift.breakStart",r -> r.breakStart, (r, v) -> r.breakStart = v),
            ExcelColumn.ofI18n("excel.col.shift.breakEnd",  r -> r.breakEnd,   (r, v) -> r.breakEnd = v),
            ExcelColumn.ofI18n("excel.col.shift.groupName", r -> r.groupName,  (r, v) -> r.groupName = v),
            ExcelColumn.ofI18n("excel.col.shift.color",     r -> r.color,      (r, v) -> r.color = v),
            ExcelColumn.ofI18n("excel.col.shift.deptCodes", r -> r.deptCodes,  (r, v) -> r.deptCodes = v)
        );
    }

    @Override
    public ShiftExcelService.ShiftRow newRow() { return new ShiftExcelService.ShiftRow(); }

    @Override
    public List<PickItem> searchForPick(Long companyId, Long userId, String q) {
        String lq = q == null ? "" : q.trim().toLowerCase();
        return shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream()
            .filter(sh -> lq.isEmpty()
                || (sh.getName() != null && sh.getName().toLowerCase().contains(lq))
                || (sh.getCode() != null && sh.getCode().toLowerCase().contains(lq)))
            .limit(20)
            .map(sh -> new PickItem(sh.getCode(), sh.getName() + " (" + sh.getCode() + ")"))
            .collect(Collectors.toList());
    }

    @Override
    public List<FilterDefinition> filterDefinitions(Long companyId) {
        List<FilterDefinition.Option> deptOptions = deptRepo
            .findByCompanyIdOrderByLevelAscNameAsc(companyId).stream()
            .filter(d -> d.getCode() != null && !d.getCode().isBlank())
            .map(d -> FilterDefinition.opt(d.getCode(), d.getName() + " (" + d.getCode() + ")"))
            .collect(Collectors.toList());

        List<FilterDefinition.Option> groupOptions = shiftRepo
            .findByCompanyIdAndActiveTrue(companyId).stream()
            .map(sh -> sh.getGroupName())
            .filter(g -> g != null && !g.isBlank())
            .distinct().sorted()
            .map(g -> FilterDefinition.opt(g, g))
            .collect(Collectors.toList());

        List<FilterDefinition> filters = new ArrayList<>();
        filters.add(FilterDefinition.text("search", "filter.search"));
        filters.add(FilterDefinition.select("departmentCodes", "filter.department", deptOptions));
        if (!groupOptions.isEmpty())
            filters.add(FilterDefinition.select("groupName", "filter.shift.group", groupOptions));
        return filters;
    }

    @Override
    public List<ShiftExcelService.ShiftRow> loadForExport(Long companyId, Long userId,
                                                           Map<String, String> filters) {
        String deptCodesRaw = filters.getOrDefault("departmentCodes",
            filters.getOrDefault("departmentCode", "")).trim();
        Set<String> deptFilter = deptCodesRaw.isEmpty() ? Set.of()
            : Arrays.stream(deptCodesRaw.split(","))
                .map(s -> s.trim().toUpperCase()).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
        String groupFilter = filters.getOrDefault("groupName", "").trim();
        String searchRaw = filters.getOrDefault("search", "").trim();
        Set<String> pickedCodes = searchRaw.isEmpty() ? Set.of()
            : Arrays.stream(searchRaw.split(","))
                .map(s -> s.trim().toUpperCase()).filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
        return shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream()
            .filter(sh -> {
                if (!pickedCodes.isEmpty())
                    return sh.getCode() != null && pickedCodes.contains(sh.getCode().toUpperCase());
                if (!groupFilter.isEmpty()
                        && !groupFilter.equals(sh.getGroupName())) return false;
                if (!deptFilter.isEmpty()) {
                    Set<String> shiftDeptCodes = sh.getDepartments().stream()
                        .map(Department::getCode).filter(c -> c != null)
                        .map(String::toUpperCase).collect(Collectors.toSet());
                    return shiftDeptCodes.stream().anyMatch(deptFilter::contains);
                }
                return true;
            })
            .map(sh -> {
                ShiftExcelService.ShiftRow r = new ShiftExcelService.ShiftRow();
                r.code      = sh.getCode();
                r.name      = sh.getName();
                r.startTime = sh.getStartTime() != null ? sh.getStartTime().format(TIME_FMT) : "";
                r.endTime   = sh.getEndTime()   != null ? sh.getEndTime().format(TIME_FMT)   : "";
                r.breakStart= sh.getBreakStart()!= null ? sh.getBreakStart().format(TIME_FMT): "";
                r.breakEnd  = sh.getBreakEnd()  != null ? sh.getBreakEnd().format(TIME_FMT)  : "";
                r.groupName = sh.getGroupName() != null ? sh.getGroupName() : "";
                r.color     = sh.getColor()     != null ? sh.getColor()     : "";
                r.deptCodes = sh.getDepartments().stream()
                    .map(Department::getCode).filter(c -> c != null)
                    .collect(Collectors.joining(","));
                return r;
            }).collect(Collectors.toList());
    }

    @Override
    public String getIdentifier(ShiftExcelService.ShiftRow row) {
        return row.code != null ? row.code : "";
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<ShiftExcelService.ShiftRow>> rows,
            boolean dryRun) {

        List<SheetImportResult.RowResult> results = new ArrayList<>();
        // ShiftExcelService.importRowsDirectly nhận List<ShiftRow> + command per row
        // Vì ShiftExcelService hiện không có method nhận List<ShiftRow> trực tiếp,
        // ta dùng importRowsDirect mới sẽ thêm vào ShiftExcelService
        List<ShiftExcelService.ShiftRow> toImport = new ArrayList<>();
        List<ImportCommand> commands = new ArrayList<>();
        Map<Integer, Integer> indexToRowNum = new java.util.LinkedHashMap<>();

        for (RowWithCommand<ShiftExcelService.ShiftRow> rw : rows) {
            if (rw.command() == null) {
                results.add(SheetImportResult.RowResult.skip(rw.rowNum()));
                continue;
            }
            indexToRowNum.put(toImport.size(), rw.rowNum());
            toImport.add(rw.data());
            commands.add(rw.command());
        }

        if (toImport.isEmpty()) return results;

        List<SheetImportResult.RowResult> importResults =
            shiftExcelService.importRowsDirect(companyId, toImport, commands, dryRun);

        for (int i = 0; i < importResults.size(); i++) {
            SheetImportResult.RowResult r = importResults.get(i);
            int rowNum = indexToRowNum.getOrDefault(i, i + 2);
            results.add(new SheetImportResult.RowResult(rowNum, r.status(), r.message()));
        }

        return results;
    }
}
