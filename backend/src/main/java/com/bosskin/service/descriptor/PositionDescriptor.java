package com.bosskin.service.descriptor;

import com.bosskin.dto.PositionDTO;
import com.bosskin.service.PositionExcelService;
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
public class PositionDescriptor implements ExcelEntityDescriptor<PositionDTO.ImportRow> {

    private final PositionExcelService positionExcelService;

    @Override public String sheetKey() { return "excel.sheet.position.list"; }
    @Override public String type()     { return "position"; }

    @Override
    public List<ExcelColumn<PositionDTO.ImportRow>> columns() {
        return List.of(
            ExcelColumn.ofI18n("excel.col.position.code",           r -> r.getCode(),           (r, v) -> r.setCode(v)),
            ExcelColumn.ofI18n("excel.col.position.name",           r -> r.getName(),           (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.position.departmentCode", r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.position.departmentName", r -> null),
            ExcelColumn.ofI18n("excel.col.position.description",    r -> r.getDescription(),    (r, v) -> r.setDescription(v))
        );
    }

    @Override
    public PositionDTO.ImportRow newRow() { return new PositionDTO.ImportRow(); }

    @Override
    public List<PositionDTO.ImportRow> loadForExport(Long companyId, Long userId,
                                                      Map<String, String> filters) {
        return positionExcelService.getFlat(companyId).stream().map(flat -> {
            PositionDTO.ImportRow r = new PositionDTO.ImportRow();
            r.setCode(flat.getCode());
            r.setName(flat.getName());
            r.setDepartmentCode(flat.getDepartmentCode() != null ? flat.getDepartmentCode() : "");
            r.setDescription(flat.getDescription() != null ? flat.getDescription() : "");
            return r;
        }).collect(java.util.stream.Collectors.toList());
    }

    @Override
    public String getIdentifier(PositionDTO.ImportRow row) {
        return row.getCode() != null ? row.getCode() : "";
    }

    @Override
    public List<SheetImportResult.RowResult> importRows(
            Long companyId, Long userId,
            List<RowWithCommand<PositionDTO.ImportRow>> rows,
            boolean dryRun) {

        List<SheetImportResult.RowResult> results = new ArrayList<>();
        List<PositionDTO.ImportRow> toImport = new ArrayList<>();
        Map<Integer, Integer> indexToRowNum = new java.util.LinkedHashMap<>();

        for (RowWithCommand<PositionDTO.ImportRow> rw : rows) {
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
            List<PositionDTO.ImportDiff> diffs = positionExcelService.previewImport(companyId, toImport);
            for (int i = 0; i < diffs.size(); i++) {
                int rowNum = indexToRowNum.getOrDefault(i, i + 2);
                if ("NO_CHANGE".equals(diffs.get(i).getAction())) {
                    results.add(SheetImportResult.RowResult.skip(rowNum));
                } else {
                    results.add(SheetImportResult.RowResult.ok(rowNum));
                }
            }
        } else {
            try {
                positionExcelService.importFromExcel(companyId, toImport);
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
