package com.bosskin.service;

import com.bosskin.entity.Payroll;
import com.bosskin.repository.PayrollRepository;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class PayrollExcelService {

    private final PayrollRepository payrollRepository;
    private final DeptScopeService deptScopeService;
    private final ExcelI18n excelI18n;


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

    private String buildSheetName(int month, int year) {
        java.util.Locale locale = LocaleContextHolder.getLocale();
        String label = String.format("%02d-%04d", month, year);
        String raw = excelI18n.resolve("excel.sheet.payroll", locale, label);
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

    private static CellStyle buildHeaderStyle(Workbook wb) {
        org.apache.poi.xssf.usermodel.XSSFWorkbook xwb = (org.apache.poi.xssf.usermodel.XSSFWorkbook) wb;
        org.apache.poi.xssf.usermodel.XSSFCellStyle style = xwb.createCellStyle();
        org.apache.poi.xssf.usermodel.XSSFFont font = xwb.createFont();
        font.setBold(true);
        font.setColor(new org.apache.poi.xssf.usermodel.XSSFColor(
            new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));
        style.setFont(font);
        style.setFillForegroundColor(new org.apache.poi.xssf.usermodel.XSSFColor(
            new byte[]{(byte)0x21,(byte)0x5C,(byte)0x98}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.MEDIUM);
        style.setBorderRight(BorderStyle.THIN);
        style.setWrapText(true);
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

    private static final List<String> PAYSLIP_HEADER_KEYS = List.of(
        "excel.col.payroll.empCode",     "excel.col.payroll.empName",
        "excel.col.payroll.department",  "excel.col.payroll.salaryGrade",
        "excel.col.payroll.payType",     "excel.col.payroll.presentDays",
        "excel.col.payroll.dayHours",    "excel.col.payroll.nightHours",
        "excel.col.payroll.otDay",       "excel.col.payroll.otNight",
        "excel.col.payroll.baseSalary",  "excel.col.payroll.totalAllowance",
        "excel.col.payroll.totalIncome", "excel.col.payroll.gross",
        "excel.col.payroll.totalDeduction", "excel.col.payroll.net",
        "excel.col.payroll.status"
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

        java.util.Locale locale = LocaleContextHolder.getLocale();
        List<String> headers = PAYSLIP_HEADER_KEYS.stream()
            .map(k -> excelI18n.resolve(k, locale))
            .collect(java.util.stream.Collectors.toList());

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
            for (int i = 0; i < headers.size(); i++) {
                Cell cell = header.createCell(i);
                cell.setCellValue(headers.get(i));
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

            for (int i = 0; i < headers.size(); i++) {
                sheet.autoSizeColumn(i);
                sheet.setColumnWidth(i, Math.min(sheet.getColumnWidth(i) + 512, 65280));
            }

            byte[] bytes = toBytes(wb);
            String filenameBase = excelI18n.resolve("excel.file.payroll", locale)
                + "-" + String.format("%02d-%04d", month, year);
            return ExcelUtils.buildFileResponse(filenameBase, bytes);
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

    private static byte[] toBytes(Workbook wb) throws IOException {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            wb.write(out);
            return out.toByteArray();
        }
    }
}
