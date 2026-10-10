package com.bosskin.controller;

import com.bosskin.dto.ContractDTO;
import com.bosskin.entity.User;
import com.bosskin.service.ContractService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelSheet;
import com.bosskin.util.ExcelUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Bước L — hợp đồng lao động.
 * <pre>
 * GET    /api/v1/contracts?employeeId=              — CONTRACT_VIEW (+ phạm vi phòng ban)
 * GET    /api/v1/contracts/{id}                     — CONTRACT_VIEW
 * GET    /api/v1/contracts/expiring?days=           — CONTRACT_VIEW (cần gia hạn; days trống = cấu hình công ty)
 * POST   /api/v1/contracts                          — CONTRACT_VIEW + CONTRACT_EDIT
 * PUT    /api/v1/contracts/{id}                     — CONTRACT_VIEW + CONTRACT_EDIT
 * POST   /api/v1/contracts/{id}/activate            — CONTRACT_VIEW + CONTRACT_EDIT
 * POST   /api/v1/contracts/{id}/terminate           — CONTRACT_VIEW + CONTRACT_EDIT
 * DELETE /api/v1/contracts/{id}                     — CONTRACT_VIEW + CONTRACT_DELETE
 * POST   /api/v1/contracts/{id}/appendices          — CONTRACT_VIEW + CONTRACT_EDIT
 * PUT    /api/v1/contracts/appendices/{appendixId}  — CONTRACT_VIEW + CONTRACT_EDIT
 * DELETE /api/v1/contracts/appendices/{appendixId}  — CONTRACT_VIEW + CONTRACT_EDIT
 * GET    /api/v1/contracts/export                   — CONTRACT_VIEW (sheet hợp đồng + sheet phụ cấp)
 * POST   /api/v1/contracts/preview-import           — CONTRACT_VIEW + CONTRACT_EDIT
 * POST   /api/v1/contracts/import                   — CONTRACT_VIEW + CONTRACT_EDIT
 * </pre>
 */
@RestController
@RequestMapping("/api/v1/contracts")
@RequiredArgsConstructor
public class ContractController {

    private final ContractService service;
    private final ExcelI18n excelI18n;

    private static final List<ExcelColumn<ContractDTO.Response>> EXPORT_COLUMNS = List.of(
        ExcelColumn.readOnlyI18n("excel.col.contract.no", ContractDTO.Response::getContractNo),
        ExcelColumn.readOnlyI18n("excel.col.contract.employeeCode", ContractDTO.Response::getEmployeeCode),
        ExcelColumn.readOnlyI18n("excel.col.contract.employeeName", ContractDTO.Response::getEmployeeName),
        ExcelColumn.readOnlyI18n("excel.col.contract.department", ContractDTO.Response::getDepartmentName),
        ExcelColumn.readOnlyI18n("excel.col.contract.type", ContractDTO.Response::getContractType),
        ExcelColumn.readOnlyI18n("excel.col.contract.status", ContractDTO.Response::getStatus),
        ExcelColumn.readOnlyI18n("excel.col.contract.signDate", r -> str(r.getSignDate())),
        ExcelColumn.readOnlyI18n("excel.col.contract.startDate", r -> str(r.getStartDate())),
        ExcelColumn.readOnlyI18n("excel.col.contract.endDate", r -> str(r.getEndDate())),
        ExcelColumn.readOnlyI18n("excel.col.contract.baseSalary", r -> money(r.getBaseSalary())),
        ExcelColumn.readOnlyI18n("excel.col.contract.insuranceSalary", r -> money(r.getInsuranceSalary())),
        ExcelColumn.readOnlyI18n("excel.col.contract.positionTitle", ContractDTO.Response::getPositionTitle),
        ExcelColumn.readOnlyI18n("excel.col.contract.note", ContractDTO.Response::getNote),
        ExcelColumn.readOnlyI18n("excel.col.contract.currentBaseSalary", r -> money(r.getCurrentBaseSalary())),
        ExcelColumn.readOnlyI18n("excel.col.contract.terminationDate", r -> str(r.getTerminationDate())),
        ExcelColumn.readOnlyI18n("excel.col.contract.appendixCount", r -> r.getAppendices().size())
    );

    private static final List<ExcelColumn<ContractDTO.ImportRow>> IMPORT_COLUMNS = List.of(
        ExcelColumn.ofI18n("excel.col.contract.no", ContractDTO.ImportRow::getContractNo, ContractDTO.ImportRow::setContractNo),
        ExcelColumn.ofI18n("excel.col.contract.employeeCode", ContractDTO.ImportRow::getEmployeeCode, ContractDTO.ImportRow::setEmployeeCode),
        ExcelColumn.ofI18n("excel.col.contract.type", ContractDTO.ImportRow::getContractType, ContractDTO.ImportRow::setContractType),
        ExcelColumn.ofI18n("excel.col.contract.status", ContractDTO.ImportRow::getStatus, ContractDTO.ImportRow::setStatus),
        ExcelColumn.ofI18n("excel.col.contract.signDate", ContractDTO.ImportRow::getSignDate, ContractDTO.ImportRow::setSignDate),
        ExcelColumn.ofI18n("excel.col.contract.startDate", ContractDTO.ImportRow::getStartDate, ContractDTO.ImportRow::setStartDate),
        ExcelColumn.ofI18n("excel.col.contract.endDate", ContractDTO.ImportRow::getEndDate, ContractDTO.ImportRow::setEndDate),
        ExcelColumn.ofI18n("excel.col.contract.baseSalary", ContractDTO.ImportRow::getBaseSalary, ContractDTO.ImportRow::setBaseSalary),
        ExcelColumn.ofI18n("excel.col.contract.insuranceSalary", ContractDTO.ImportRow::getInsuranceSalary, ContractDTO.ImportRow::setInsuranceSalary),
        ExcelColumn.ofI18n("excel.col.contract.positionTitle", ContractDTO.ImportRow::getPositionTitle, ContractDTO.ImportRow::setPositionTitle),
        ExcelColumn.ofI18n("excel.col.contract.note", ContractDTO.ImportRow::getNote, ContractDTO.ImportRow::setNote)
    );

    private static final List<ExcelColumn<ContractDTO.AllowanceExportRow>> ALLOWANCE_EXPORT_COLUMNS = List.of(
        ExcelColumn.readOnlyI18n("excel.col.contract.no", ContractDTO.AllowanceExportRow::contractNo),
        ExcelColumn.readOnlyI18n("excel.col.allowance.code", r -> r.allowance().getCode()),
        ExcelColumn.readOnlyI18n("excel.col.allowance.name", r -> r.allowance().getName()),
        ExcelColumn.readOnlyI18n("excel.col.allowance.amount", r -> money(r.allowance().getAmount())),
        ExcelColumn.readOnlyI18n("excel.col.allowance.insurable", r -> r.allowance().isInsurable() ? "1" : "0"),
        ExcelColumn.readOnlyI18n("excel.col.allowance.taxable", r -> r.allowance().isTaxable() ? "1" : "0")
    );

    private static final List<ExcelColumn<ContractDTO.AllowanceImportRow>> ALLOWANCE_IMPORT_COLUMNS = List.of(
        ExcelColumn.ofI18n("excel.col.contract.no", ContractDTO.AllowanceImportRow::getContractNo, ContractDTO.AllowanceImportRow::setContractNo),
        ExcelColumn.ofI18n("excel.col.allowance.code", ContractDTO.AllowanceImportRow::getCode, ContractDTO.AllowanceImportRow::setCode),
        ExcelColumn.ofI18n("excel.col.allowance.name", ContractDTO.AllowanceImportRow::getName, ContractDTO.AllowanceImportRow::setName),
        ExcelColumn.ofI18n("excel.col.allowance.amount", ContractDTO.AllowanceImportRow::getAmount, ContractDTO.AllowanceImportRow::setAmount),
        ExcelColumn.ofI18n("excel.col.allowance.insurable", ContractDTO.AllowanceImportRow::getInsurable, ContractDTO.AllowanceImportRow::setInsurable),
        ExcelColumn.ofI18n("excel.col.allowance.taxable", ContractDTO.AllowanceImportRow::getTaxable, ContractDTO.AllowanceImportRow::setTaxable)
    );

    @GetMapping
    public ResponseEntity<List<ContractDTO.Response>> list(@AuthenticationPrincipal User user,
                                                           @RequestParam(required = false) Long employeeId) {
        require(user, "CONTRACT_VIEW");
        return ResponseEntity.ok(service.list(user.getCompanyId(), user.getId(), employeeId));
    }

    @GetMapping("/expiring")
    public ResponseEntity<List<ContractDTO.Response>> expiring(@AuthenticationPrincipal User user,
                                                               @RequestParam(required = false) Integer days) {
        require(user, "CONTRACT_VIEW");
        return ResponseEntity.ok(service.expiring(user.getCompanyId(), user.getId(), days));
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@AuthenticationPrincipal User user) {
        require(user, "CONTRACT_VIEW");
        List<ContractDTO.Response> rows = service.list(user.getCompanyId(), user.getId(), null);
        return ExcelUtils.exportSheets("excel.file.contract", List.of(
                ExcelSheet.ofI18n("excel.sheet.contract", EXPORT_COLUMNS, rows),
                ExcelSheet.ofI18n("excel.sheet.contractAllowance", ALLOWANCE_EXPORT_COLUMNS, service.allowanceRows(rows))),
            excelI18n, LocaleContextHolder.getLocale());
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<ContractDTO.ImportDiff>> previewImport(@AuthenticationPrincipal User user,
                                                                      @RequestParam("file") MultipartFile file) {
        requireEdit(user);
        return ResponseEntity.ok(service.previewImport(user.getCompanyId(), user.getId(),
            ExcelUtils.importRowsByHeader(file, 0, IMPORT_COLUMNS, ContractDTO.ImportRow::new, excelI18n),
            allowanceRows(file)));
    }

    @PostMapping("/import")
    public ResponseEntity<Map<String, Integer>> importExcel(@AuthenticationPrincipal User user,
                                                            @RequestParam("file") MultipartFile file) {
        requireEdit(user);
        return ResponseEntity.ok(service.importFromExcel(user.getCompanyId(), user,
            ExcelUtils.importRowsByHeader(file, 0, IMPORT_COLUMNS, ContractDTO.ImportRow::new, excelI18n),
            allowanceRows(file)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ContractDTO.Response> get(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, "CONTRACT_VIEW");
        return ResponseEntity.ok(service.get(user.getCompanyId(), user.getId(), id));
    }

    @PostMapping
    public ResponseEntity<ContractDTO.Response> create(@AuthenticationPrincipal User user,
                                                       @Valid @RequestBody ContractDTO.Upsert req) {
        requireEdit(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(user.getCompanyId(), user, req));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ContractDTO.Response> update(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                       @Valid @RequestBody ContractDTO.Upsert req) {
        requireEdit(user);
        return ResponseEntity.ok(service.update(user.getCompanyId(), user, id, req));
    }

    @PostMapping("/{id}/activate")
    public ResponseEntity<ContractDTO.Response> activate(@AuthenticationPrincipal User user, @PathVariable Long id) {
        requireEdit(user);
        return ResponseEntity.ok(service.activate(user.getCompanyId(), user, id));
    }

    @PostMapping("/{id}/terminate")
    public ResponseEntity<ContractDTO.Response> terminate(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                          @Valid @RequestBody ContractDTO.TerminateRequest req) {
        requireEdit(user);
        return ResponseEntity.ok(service.terminate(user.getCompanyId(), user, id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, "CONTRACT_VIEW");
        require(user, "CONTRACT_DELETE");
        service.delete(user.getCompanyId(), user, id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/appendices")
    public ResponseEntity<ContractDTO.Response> addAppendix(@AuthenticationPrincipal User user, @PathVariable Long id,
                                                            @Valid @RequestBody ContractDTO.AppendixUpsert req) {
        requireEdit(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addAppendix(user.getCompanyId(), user, id, req));
    }

    @PutMapping("/appendices/{appendixId}")
    public ResponseEntity<ContractDTO.Response> updateAppendix(@AuthenticationPrincipal User user, @PathVariable Long appendixId,
                                                               @Valid @RequestBody ContractDTO.AppendixUpsert req) {
        requireEdit(user);
        return ResponseEntity.ok(service.updateAppendix(user.getCompanyId(), user, appendixId, req));
    }

    @DeleteMapping("/appendices/{appendixId}")
    public ResponseEntity<ContractDTO.Response> deleteAppendix(@AuthenticationPrincipal User user, @PathVariable Long appendixId) {
        requireEdit(user);
        return ResponseEntity.ok(service.deleteAppendix(user.getCompanyId(), user, appendixId));
    }

    /** Sheet phụ cấp (thứ 2) — file không có sheet này thì giữ nguyên phụ cấp (null). */
    private List<ContractDTO.AllowanceImportRow> allowanceRows(MultipartFile file) {
        try (InputStream is = file.getInputStream(); XSSFWorkbook wb = new XSSFWorkbook(is)) {
            if (wb.getNumberOfSheets() < 2) return null;
        } catch (IOException | RuntimeException e) {
            return null;
        }
        return ExcelUtils.importRowsByHeader(file, 1, ALLOWANCE_IMPORT_COLUMNS, ContractDTO.AllowanceImportRow::new, excelI18n);
    }

    private static void requireEdit(User user) {
        require(user, "CONTRACT_VIEW");
        require(user, "CONTRACT_EDIT");
    }

    private static void require(User user, String perm) {
        if (user == null || user.getCompanyId() == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }

    private static String money(BigDecimal v) {
        return v == null ? "" : v.stripTrailingZeros().toPlainString();
    }
}
