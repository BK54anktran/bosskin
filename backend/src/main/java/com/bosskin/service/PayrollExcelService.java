package com.bosskin.service;

import com.bosskin.entity.Payroll;
import com.bosskin.repository.PayrollRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class PayrollExcelService {

    private final PayrollRepository payrollRepository;
    private final DeptScopeService deptScopeService;

    private static final DateTimeFormatter FILE_TS_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss");
    private static final String XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    private static void writeText(Row row, int col, String value, CellStyle style) {
        Cell cell = row.createCell(col);
        if (value != null && !value.isBlank()) {
            cell.setCellValue(value);
        }
        cell.setCellStyle(style);
    }

    private static void writeInteger(Row row, int col, Integer value, CellStyle style) {
        Cell cell = row.createCell(col);
        if (value != null) {
            cell.setCellValue(value.doubleValue());
        }
        cell.setCellStyle(style);
    }

    private static void writeDecimal(Row row, int col, BigDecimal value, CellStyle style) {
        Cell cell = row.createCell(col);
        if (value != null) {
            cell.setCellValue(value.doubleValue());
        }
        cell.setCellStyle(style);
    }

    private static void writeMoney(Row row, int col, BigDecimal value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(nvl(value).doubleValue());
        cell.setCellStyle(style);
    }

    private static BigDecimal nvl(BigDecimal value) {
        return value != null ? value : BigDecimal.ZERO;
    }

    private static String safeEmployeeCode(Payroll p) {
        return p.getEmployee() != null ? safeText(p.getEmployee().getEmployeeCode()) : "";
    }

    private static String safeText(String value) {
        return value == null ? "" : value.trim();
    }

    private static String statusKey(Payroll.Status status) {
        return status != null ? status.name() : "";
    }

    private static String buildSheetName(int month, int year) {
        String raw = String.format("Luong Thang %02d-%04d", month, year);
        return sanitizeSheetName(raw);
    }

    private static String sanitizeSheetName(String raw) {
        String sanitized = raw
            .replaceAll("[\\\\/?*\\[\\]:]", " ")
            .replaceAll("\\s+", " ")
            .trim();
        if (sanitized.length() > 31) {
            return sanitized.substring(0, 31);
        }
        return sanitized;
    }

    private static String buildContentDisposition(String filename) {
        return "attachment; filename=\"" + filename + "\"";
    }

    private static CellStyle buildHeaderStyle(Workbook wb) {
        CellStyle style = wb.createCellStyle();
        Font font = wb.createFont();
        font.setBold(true);
        style.setFont(font);
        style.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.THIN);
        return style;
    }

    private static CellStyle buildTextStyle(Workbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static CellStyle buildMoneyStyle(Workbook wb) {
        CellStyle style = buildTextStyle(wb);
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        return style;
    }

    private static CellStyle buildDecimalStyle(Workbook wb) {
        CellStyle style = buildTextStyle(wb);
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0.0"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        return style;
    }

    private static CellStyle buildIntegerStyle(Workbook wb) {
        CellStyle style = buildTextStyle(wb);
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("0"));
        style.setAlignment(HorizontalAlignment.CENTER);
        return style;
    }

    // ─── Export phiếu lương tổng hợp gọn ─────────────────────────────────────
    // 1 sheet, mỗi hàng = 1 người, chỉ các giá trị cố định/tổng hợp

    private static final List<String> PAYSLIP_HEADERS = List.of(
        "Ma NV", "Ho ten", "Phong ban", "Bac luong", "Loai tinh",
        "Ngay cong", "Gio ngay", "Gio dem", "OT ngay", "OT dem",
        "Luong co ban", "Tong tro cap", "Tong thu nhap them",
        "Gross", "Tong khau tru", "Net", "Trang thai"
    );

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> exportPayslips(Long companyId, Long userId, int year, int month, Collection<Long> payrollIds) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "PAYROLL_VIEW");

        List<Payroll> payrolls;
        if (payrollIds != null && !payrollIds.isEmpty()) {
            payrolls = payrollRepository.findPayslipsByIds(payrollIds, companyId);
        } else {
            Set<Long> deptScope = scopeIds.stream()
                .filter(id -> id != null && id > 0)
                .collect(java.util.stream.Collectors.toSet());
            payrolls = scopeIds.isEmpty()
                ? payrollRepository.findExportByMonth(companyId, year, month)
                : (deptScope.isEmpty() ? List.of()
                    : payrollRepository.findExportByMonthAndDeptScope(companyId, year, month, deptScope));
        }

        if (payrolls.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found");
        }

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet(buildSheetName(month, year));
            sheet.createFreezePane(4, 1);

            CellStyle headerStyle  = buildHeaderStyle(wb);
            CellStyle textStyle    = buildTextStyle(wb);
            CellStyle moneyStyle   = buildMoneyStyle(wb);
            CellStyle decimalStyle = buildDecimalStyle(wb);
            CellStyle integerStyle = buildIntegerStyle(wb);

            // Column widths
            int[] widths = {14,24,20,18,12, 10,10,10,10,10, 16,16,16, 16,16,16, 12};
            Row header = sheet.createRow(0);
            for (int i = 0; i < PAYSLIP_HEADERS.size(); i++) {
                Cell cell = header.createCell(i);
                cell.setCellValue(PAYSLIP_HEADERS.get(i));
                cell.setCellStyle(headerStyle);
                sheet.setColumnWidth(i, widths[i] * 256);
            }

            int rowIdx = 1;
            for (Payroll p : payrolls) {
                Row row = sheet.createRow(rowIdx++);
                int c = 0;
                var emp = p.getEmployee();

                writeText(row, c++, safeEmployeeCode(p), textStyle);
                writeText(row, c++, safeText(emp.getFullName()), textStyle);
                writeText(row, c++, emp.getDepartment() != null ? safeText(emp.getDepartment().getName()) : "", textStyle);
                // Bậc lương: code + tên
                String gradeLabel = emp.getSalaryGrade() != null
                    ? safeText(emp.getSalaryGrade().getCode()) + " - " + safeText(emp.getSalaryGrade().getName())
                    : "";
                writeText(row, c++, gradeLabel, textStyle);
                writeText(row, c++, safeText(p.getPayType()), textStyle);

                writeInteger(row, c++, p.getPresentDays(), integerStyle);
                writeDecimal(row, c++, p.getDayHours(), decimalStyle);
                writeDecimal(row, c++, p.getNightHours(), decimalStyle);
                writeDecimal(row, c++, p.getDayOt(), decimalStyle);
                writeDecimal(row, c++, p.getNightOt(), decimalStyle);

                writeMoney(row, c++, p.getBaseSalary(), moneyStyle);

                // Tổng trợ cấp = allowanceEntries + allowance thủ công + bonus
                BigDecimal totalAllowance = sumEntries(p.getAllowanceEntries())
                    .add(nvl(p.getAllowance()))
                    .add(nvl(p.getBonus()));
                writeMoney(row, c++, totalAllowance, moneyStyle);

                // Tổng thu nhập thêm = incomeEntries + overtimePay
                BigDecimal totalIncome = sumEntries(p.getIncomeEntries())
                    .add(nvl(p.getOvertimePay()));
                writeMoney(row, c++, totalIncome, moneyStyle);

                writeMoney(row, c++, p.getGrossSalary(), moneyStyle);

                // Tổng khấu trừ = BHXH + BHYT + BHTN + TNCN + customDeductions + otherDeductions
                BigDecimal totalDed = nvl(p.getSocialInsurance())
                    .add(nvl(p.getHealthInsurance()))
                    .add(nvl(p.getUnemploymentInsurance()))
                    .add(nvl(p.getPersonalIncomeTax()))
                    .add(nvl(p.getOtherDeductions()))
                    .add(sumEntries(p.getCustomDeductions()));
                writeMoney(row, c++, totalDed, moneyStyle);

                writeMoney(row, c++, p.getNetSalary(), moneyStyle);
                writeText(row, c, statusKey(p.getStatus()), textStyle);
            }

            byte[] bytes = toBytes(wb);
            String filename = buildPayslipsFilename(month, year);
            return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, buildContentDisposition(filename))
                .contentType(MediaType.parseMediaType(XLSX_MIME))
                .body(bytes);
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "error.excel.export_failed", e);
        }
    }

    private static BigDecimal sumEntries(Map<String, Payroll.DeductionEntry> entries) {
        if (entries == null || entries.isEmpty()) return BigDecimal.ZERO;
        return entries.values().stream()
            .map(Payroll.DeductionEntry::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static String buildPayslipsFilename(int month, int year) {
        String base = String.format("phieu_luong_thang_%02d-%04d", month, year);
        String ts = LocalDateTime.now().format(FILE_TS_FMT);
        return base + "-" + ts + ".xlsx";
    }

    private static byte[] toBytes(Workbook wb) throws IOException {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            wb.write(out);
            return out.toByteArray();
        }
    }
}
