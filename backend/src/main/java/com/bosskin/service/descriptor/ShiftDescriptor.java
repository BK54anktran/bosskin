package com.bosskin.service.descriptor;

import com.bosskin.entity.Department;
import com.bosskin.repository.WorkShiftRepository;
import com.bosskin.service.ShiftExcelService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class ShiftDescriptor implements ExcelEntityDescriptor<ShiftExcelService.ShiftRow> {

    private final ShiftExcelService shiftExcelService;
    private final WorkShiftRepository shiftRepo;

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
    public List<ShiftExcelService.ShiftRow> loadForExport(Long companyId, Long userId,
                                                           Map<String, String> filters) {
        return shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream().map(sh -> {
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
