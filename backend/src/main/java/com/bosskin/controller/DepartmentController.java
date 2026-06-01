package com.bosskin.controller;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.dto.PositionDTO;
import com.bosskin.entity.User;
import com.bosskin.service.DepartmentService;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.PositionExcelService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelSheet;
import com.bosskin.util.ExcelUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService    departmentService;
    private final DeptScopeService     deptScopeService;
    private final PositionExcelService positionExcelService;

    @GetMapping
    public ResponseEntity<List<DepartmentDTO.Response>> getTree(@AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        return ResponseEntity.ok(departmentService.getTree(user.getCompany().getId(), user.getId()));
    }

    private static final List<ExcelColumn<DepartmentDTO.ImportRow>> IMPORT_COLUMNS = List.of(
            ExcelColumn.of("Mã phòng ban (*)",    r -> r.getCode(),                (r, v) -> r.setCode(v)),
            ExcelColumn.of("Tên phòng ban (*)",   r -> r.getName(),                (r, v) -> r.setName(v)),
            ExcelColumn.of("Mã PB cha",           r -> r.getParentCode(),          (r, v) -> r.setParentCode(v)),
            ExcelColumn.of("Mô tả",               r -> r.getDescription(),         (r, v) -> r.setDescription(v)),
            ExcelColumn.of("Vĩ độ (Latitude)",    r -> r.getCheckInLatitude(),     (r, v) -> r.setCheckInLatitude(v)),
            ExcelColumn.of("Kinh độ (Longitude)", r -> r.getCheckInLongitude(),    (r, v) -> r.setCheckInLongitude(v)),
            ExcelColumn.of("Bán kính (m)",        r -> r.getCheckInRadiusMeters(), (r, v) -> r.setCheckInRadiusMeters(v)),
            ExcelColumn.readOnly("Số nhân viên",  r -> null),
            ExcelColumn.of("Xóa (x)",             r -> r.getDelete(),              (r, v) -> r.setDelete(v))
    );

    private static final List<ExcelColumn<DepartmentDTO.FlatItem>> DEPT_COLUMNS = List.of(
            ExcelColumn.readOnly("Mã phòng ban (*)",    DepartmentDTO.FlatItem::getCode),
            ExcelColumn.readOnly("Tên phòng ban (*)",   DepartmentDTO.FlatItem::getName),
            ExcelColumn.readOnly("Mã PB cha",           r -> r.getParentCode() == null ? "" : r.getParentCode()),
            ExcelColumn.readOnly("Mô tả",               r -> r.getDescription() == null ? "" : r.getDescription()),
            ExcelColumn.readOnly("Vĩ độ (Latitude)",    r -> r.getCheckInLatitude() == null ? "" : r.getCheckInLatitude()),
            ExcelColumn.readOnly("Kinh độ (Longitude)", r -> r.getCheckInLongitude() == null ? "" : r.getCheckInLongitude()),
            ExcelColumn.readOnly("Bán kính (m)",        r -> r.getCheckInLatitude() == null ? "" : r.getCheckInRadiusMeters()),
            ExcelColumn.readOnly("Số nhân viên",        DepartmentDTO.FlatItem::getEmployeeCount),
            ExcelColumn.readOnly("Xóa (x)",             r -> "")
    );

    private static final List<ExcelColumn<PositionDTO.FlatItem>> POS_COLUMNS = List.of(
            ExcelColumn.readOnly("Mã chức vụ (*)",   PositionDTO.FlatItem::getCode),
            ExcelColumn.readOnly("Tên chức vụ (*)",  PositionDTO.FlatItem::getName),
            ExcelColumn.readOnly("Mã phòng ban (*)", PositionDTO.FlatItem::getDepartmentCode),
            ExcelColumn.readOnly("Tên phòng ban",    PositionDTO.FlatItem::getDepartmentName),
            ExcelColumn.readOnly("Mô tả",            r -> r.getDescription() == null ? "" : r.getDescription()),
            ExcelColumn.readOnly("Số NV",            PositionDTO.FlatItem::getEmployeeCount),
            ExcelColumn.readOnly("Xóa (x)",          r -> "")
    );

    private static final List<ExcelColumn<PositionDTO.ImportRow>> POS_IMPORT_COLUMNS = List.of(
            ExcelColumn.of("Mã chức vụ (*)",   r -> r.getCode(),           (r, v) -> r.setCode(v)),
            ExcelColumn.of("Tên chức vụ (*)",  r -> r.getName(),           (r, v) -> r.setName(v)),
            ExcelColumn.of("Mã phòng ban (*)", r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
            ExcelColumn.readOnly("Tên phòng ban", r -> null),
            ExcelColumn.of("Mô tả",            r -> r.getDescription(),    (r, v) -> r.setDescription(v)),
            ExcelColumn.readOnly("Số NV",      r -> null),
            ExcelColumn.of("Xóa (x)",          r -> r.getDelete(),         (r, v) -> r.setDelete(v))
    );

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        List<DepartmentDTO.FlatItem> deptRows = departmentService.getFlat(
                user.getCompany().getId(), user.getId(), "DEPARTMENT_VIEW");
        List<PositionDTO.FlatItem> posRows = positionExcelService.getFlat(user.getCompany().getId());
        return ExcelUtils.exportSheets("danh_sach_phong_ban", List.of(
                ExcelSheet.of("Phòng ban", DEPT_COLUMNS, deptRows),
                ExcelSheet.of("Chức vụ",  POS_COLUMNS,  posRows)
        ));
    }

    @PostMapping("/positions/preview-import")
    public ResponseEntity<List<PositionDTO.ImportDiff>> previewImportPositions(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<PositionDTO.ImportRow> rows = ExcelUtils.importRows(file, 1, POS_IMPORT_COLUMNS, PositionDTO.ImportRow::new);
        return ResponseEntity.ok(positionExcelService.previewImport(user.getCompany().getId(), rows));
    }

    @PostMapping("/positions/import")
    public ResponseEntity<Void> importPositions(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<PositionDTO.ImportRow> rows = ExcelUtils.importRows(file, 1, POS_IMPORT_COLUMNS, PositionDTO.ImportRow::new);
        positionExcelService.importFromExcel(user.getCompany().getId(), rows);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<DepartmentDTO.ImportDiff>> previewImport(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");
        List<DepartmentDTO.ImportRow> rows = ExcelUtils.importRows(file, IMPORT_COLUMNS, DepartmentDTO.ImportRow::new);
        return ResponseEntity.ok(departmentService.previewImport(user.getCompany().getId(), rows));
    }

    @PostMapping("/import")
    public ResponseEntity<Void> importExcel(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "DEPARTMENT_MANAGE");

        List<DepartmentDTO.ImportRow> rows = ExcelUtils.importRows(file, IMPORT_COLUMNS, DepartmentDTO.ImportRow::new);
        departmentService.importFromExcel(user.getCompany().getId(), rows);
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
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Chỉ được tạo phòng ban con trong phạm vi được phép");
            if (!scope.contains(req.getParentId()))
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Phòng ban cha không nằm trong phạm vi được phép");
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
        if (!user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
    }

    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác phòng ban này");
    }
}
