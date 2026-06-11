package com.bosskin.service.descriptor;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.service.DepartmentService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelEntityDescriptor;
import com.bosskin.util.ImportCommand;
import com.bosskin.util.SheetImportResult;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class DepartmentDescriptor implements ExcelEntityDescriptor<DepartmentDTO.ImportRow> {

    private final DepartmentService departmentService;

    @Override public String sheetKey() { return "excel.sheet.department.list"; }
    @Override public String type()     { return "department"; }

    @Override
    public List<ExcelColumn<DepartmentDTO.ImportRow>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.department.code",        r -> r.getCode(),                (r, v) -> r.setCode(v)),
            ExcelColumn.ofI18n("excel.col.department.name",        r -> r.getName(),                (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.department.parentCode",  r -> r.getParentCode(),          (r, v) -> r.setParentCode(v)),
            ExcelColumn.ofI18n("excel.col.department.description", r -> r.getDescription(),         (r, v) -> r.setDescription(v)),
            ExcelColumn.ofI18n("excel.col.department.latitude",    r -> r.getCheckInLatitude(),     (r, v) -> r.setCheckInLatitude(v)),
            ExcelColumn.ofI18n("excel.col.department.longitude",   r -> r.getCheckInLongitude(),    (r, v) -> r.setCheckInLongitude(v)),
            ExcelColumn.ofI18n("excel.col.department.radius",      r -> r.getCheckInRadiusMeters(), (r, v) -> r.setCheckInRadiusMeters(v)),
            ExcelColumn.readOnlyI18n("excel.col.department.employeeCount", r -> null)
        );
    }

    @Override
    public DepartmentDTO.ImportRow newRow() { return new DepartmentDTO.ImportRow(); }

    @Override
    public List<DepartmentDTO.ImportRow> loadForExport(Long companyId, Long userId,
                                                        Map<String, String> filters) {
        return departmentService.getFlat(companyId, userId, "DEPARTMENT_VIEW")
            .stream().map(flat -> {
                DepartmentDTO.ImportRow r = new DepartmentDTO.ImportRow();
                r.setCode(flat.getCode());
                r.setName(flat.getName());
                r.setParentCode(flat.getParentCode() != null ? flat.getParentCode() : "");
                r.setDescription(flat.getDescription() != null ? flat.getDescription() : "");
                r.setCheckInLatitude(flat.getCheckInLatitude() != null ? String.valueOf(flat.getCheckInLatitude()) : "");
                r.setCheckInLongitude(flat.getCheckInLongitude() != null ? String.valueOf(flat.getCheckInLongitude()) : "");
                r.setCheckInRadiusMeters(flat.getCheckInRadiusMeters() != null ? String.valueOf(flat.getCheckInRadiusMeters()) : "");
                return r;
            }).collect(java.util.stream.Collectors.toList());
    }

    @Override
    public String getIdentifier(DepartmentDTO.ImportRow row) {
        return row.getCode() != null ? row.getCode() : "";
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<DepartmentDTO.ImportRow>> rows,
            boolean dryRun) {

        List<SheetImportResult.RowResult> results = new ArrayList<>();
        List<DepartmentDTO.ImportRow> toImport = new ArrayList<>();
        Map<Integer, Integer> indexToRowNum = new java.util.LinkedHashMap<>();

        for (RowWithCommand<DepartmentDTO.ImportRow> rw : rows) {
            if (rw.command() == null) {
                results.add(SheetImportResult.RowResult.skip(rw.rowNum()));
                continue;
            }
            if (rw.command() == ImportCommand.DELETE) {
                rw.data().setDelete("x");
            }
            indexToRowNum.put(toImport.size(), rw.rowNum());
            toImport.add(rw.data());
        }

        if (toImport.isEmpty()) return results;

        if (dryRun) {
            List<DepartmentDTO.ImportDiff> diffs = departmentService.previewImport(companyId, userId, toImport);
            for (int i = 0; i < diffs.size(); i++) {
                DepartmentDTO.ImportDiff diff = diffs.get(i);
                int rowNum = indexToRowNum.getOrDefault(i, i + 2);
                if ("NO_CHANGE".equals(diff.getAction())) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                } else {
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                }
            }
        } else {
            try {
                departmentService.importFromExcel(companyId, userId, toImport);
                for (int i = 0; i < toImport.size(); i++) {
                    results.add(SheetImportResult.RowResult.ok(indexToRowNum.getOrDefault(i, i + 2)));
                }
            } catch (Exception e) {
                for (int i = 0; i < toImport.size(); i++) {
                    results.add(SheetImportResult.RowResult.error(
                        indexToRowNum.getOrDefault(i, i + 2), e.getMessage()));
                }
            }
        }

        return results;
    }
}
