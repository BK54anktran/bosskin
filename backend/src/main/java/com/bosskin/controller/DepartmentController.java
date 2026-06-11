package com.bosskin.controller;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.dto.PositionDTO;
import com.bosskin.entity.User;
import com.bosskin.service.DepartmentService;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.PositionExcelService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelSheet;
import com.bosskin.util.ExcelUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Locale;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService    departmentService;
    private final DeptScopeService     deptScopeService;
    private final PositionExcelService positionExcelService;
    private final ExcelI18n            excelI18n;

    @GetMapping
    public ResponseEntity<List<DepartmentDTO.Response>> getTree(@AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        return ResponseEntity.ok(departmentService.getTree(user.getCompany().getId(), user.getId()));
    }

    // ── Department import columns ─────────────────────────────────────────────
    private static final List<ExcelColumn<DepartmentDTO.ImportRow>> IMPORT_COLUMNS = List.of(
            ExcelColumn.ofI18n("excel.col.department.code",          r -> r.getCode(),                (r, v) -> r.setCode(v)),
            ExcelColumn.ofI18n("excel.col.department.name",          r -> r.getName(),                (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.department.parentCode",    r -> r.getParentCode(),          (r, v) -> r.setParentCode(v)),
            ExcelColumn.ofI18n("excel.col.department.description",   r -> r.getDescription(),         (r, v) -> r.setDescription(v)),
            ExcelColumn.ofI18n("excel.col.department.latitude",      r -> r.getCheckInLatitude(),     (r, v) -> r.setCheckInLatitude(v)),
            ExcelColumn.ofI18n("excel.col.department.longitude",     r -> r.getCheckInLongitude(),    (r, v) -> r.setCheckInLongitude(v)),
            ExcelColumn.ofI18n("excel.col.department.radius",        r -> r.getCheckInRadiusMeters(), (r, v) -> r.setCheckInRadiusMeters(v)),
            ExcelColumn.readOnlyI18n("excel.col.department.employeeCount", r -> null),
            ExcelColumn.ofI18n("excel.col.department.delete",        r -> r.getDelete(),              (r, v) -> r.setDelete(v))
    );

    // ── Department export columns ─────────────────────────────────────────────
    private static final List<ExcelColumn<DepartmentDTO.FlatItem>> DEPT_COLUMNS = List.of(
            ExcelColumn.readOnlyI18n("excel.col.department.code",          DepartmentDTO.FlatItem::getCode),
            ExcelColumn.readOnlyI18n("excel.col.department.name",          DepartmentDTO.FlatItem::getName),
            ExcelColumn.readOnlyI18n("excel.col.department.parentCode",    r -> r.getParentCode() == null ? "" : r.getParentCode()),
            ExcelColumn.readOnlyI18n("excel.col.department.description",   r -> r.getDescription() == null ? "" : r.getDescription()),
            ExcelColumn.readOnlyI18n("excel.col.department.latitude",      r -> r.getCheckInLatitude() == null ? "" : r.getCheckInLatitude()),
            ExcelColumn.readOnlyI18n("excel.col.department.longitude",     r -> r.getCheckInLongitude() == null ? "" : r.getCheckInLongitude()),
            ExcelColumn.readOnlyI18n("excel.col.department.radius",        r -> r.getCheckInRadiusMeters() == null ? "" : r.getCheckInRadiusMeters()),
            ExcelColumn.readOnlyI18n("excel.col.department.employeeCount", DepartmentDTO.FlatItem::getEmployeeCount),
            ExcelColumn.readOnlyI18n("excel.col.department.delete",        r -> "")
    );

    // ── Position export columns ───────────────────────────────────────────────
    private static final List<ExcelColumn<PositionDTO.FlatItem>> POS_COLUMNS = List.of(
            ExcelColumn.readOnlyI18n("excel.col.position.code",           PositionDTO.FlatItem::getCode),
            ExcelColumn.readOnlyI18n("excel.col.position.name",           PositionDTO.FlatItem::getName),
            ExcelColumn.readOnlyI18n("excel.col.position.departmentCode", PositionDTO.FlatItem::getDepartmentCode),
            ExcelColumn.readOnlyI18n("excel.col.position.departmentName", PositionDTO.FlatItem::getDepartmentName),
            ExcelColumn.readOnlyI18n("excel.col.position.description",    r -> r.getDescription() == null ? "" : r.getDescription()),
            ExcelColumn.readOnlyI18n("excel.col.position.employeeCount",  PositionDTO.FlatItem::getEmployeeCount),
            ExcelColumn.readOnlyI18n("excel.col.position.delete",         r -> "")
    );

    // ── Position import columns ───────────────────────────────────────────────
    private static final List<ExcelColumn<PositionDTO.ImportRow>> POS_IMPORT_COLUMNS = List.of(
            ExcelColumn.ofI18n("excel.col.position.code",           r -> r.getCode(),           (r, v) -> r.setCode(v)),
            ExcelColumn.ofI18n("excel.col.position.name",           r -> r.getName(),           (r, v) -> r.setName(v)),
            ExcelColumn.ofI18n("excel.col.position.departmentCode", r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
            ExcelColumn.readOnlyI18n("excel.col.position.departmentName", r -> null),
            ExcelColumn.ofI18n("excel.col.position.description",    r -> r.getDescription(),    (r, v) -> r.setDescription(v)),
            ExcelColumn.readOnlyI18n("excel.col.position.employeeCount", r -> null),
            ExcelColumn.ofI18n("excel.col.position.delete",         r -> r.getDelete(),         (r, v) -> r.setDelete(v))
    );

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        Locale locale = LocaleContextHolder.getLocale();
        List<DepartmentDTO.FlatItem> deptRows = departmentService.getFlat(
                user.getCompany().getId(), user.getId(), "DEPARTMENT_VIEW");
        List<PositionDTO.FlatItem> posRows = positionExcelService.getFlat(user.getCompany().getId());
        return ExcelUtils.exportSheets("excel.file.department", List.of(
                ExcelSheet.ofI18n("excel.sheet.department.list", DEPT_COLUMNS, deptRows),
                ExcelSheet.ofI18n("excel.sheet.position.list",   POS_COLUMNS,  posRows)
        ), excelI18n, locale);
    }

    @PostMapping("/positions/preview-import")
    public ResponseEntity<List<PositionDTO.ImportDiff>> previewImportPositions(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<PositionDTO.ImportRow> rows = ExcelUtils.importRowsByHeader(file, 1, POS_IMPORT_COLUMNS, PositionDTO.ImportRow::new, excelI18n);
        return ResponseEntity.ok(positionExcelService.previewImport(user.getCompany().getId(), rows));
    }

    @PostMapping("/positions/import")
    public ResponseEntity<Void> importPositions(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<PositionDTO.ImportRow> rows = ExcelUtils.importRowsByHeader(file, 1, POS_IMPORT_COLUMNS, PositionDTO.ImportRow::new, excelI18n);
        positionExcelService.importFromExcel(user.getCompany().getId(), rows);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<DepartmentDTO.ImportDiff>> previewImport(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<DepartmentDTO.ImportRow> rows = ExcelUtils.importRowsByHeader(file, 0, IMPORT_COLUMNS, DepartmentDTO.ImportRow::new, excelI18n);
        return ResponseEntity.ok(departmentService.previewImport(user.getCompany().getId(), user.getId(), rows));
    }

    @PostMapping("/import")
    public ResponseEntity<Void> importExcel(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<DepartmentDTO.ImportRow> rows = ExcelUtils.importRowsByHeader(file, 0, IMPORT_COLUMNS, DepartmentDTO.ImportRow::new, excelI18n);
        departmentService.importFromExcel(user.getCompany().getId(), user.getId(), rows);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/flat")
    public ResponseEntity<List<DepartmentDTO.FlatItem>> getFlat(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "DEPARTMENT_VIEW") String permission) {
        requirePermission(user, "DEPARTMENT_VIEW");
        return ResponseEntity.ok(departmentService.getFlat(user.getCompany().getId(), user.getId(), permission));
    }

    @PostMapping
    public ResponseEntity<DepartmentDTO.Response> create(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody DepartmentDTO.CreateRequest req) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty()) {
            if (req.getParentId() == null)
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.department.must_be_child_in_scope");
            if (!scope.contains(req.getParentId()))
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.department.parent_out_of_scope");
        }
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(departmentService.create(user.getCompany().getId(), req));
    }

    @PutMapping("/{id}")
    public ResponseEntity<DepartmentDTO.Response> update(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @Valid @RequestBody DepartmentDTO.CreateRequest req) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        requireViewScope(user, id);
        return ResponseEntity.ok(departmentService.update(user.getCompany().getId(), id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        requireViewScope(user, id);
        departmentService.delete(user.getCompany().getId(), id);
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }
}
