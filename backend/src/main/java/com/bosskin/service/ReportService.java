package com.bosskin.service;

import com.bosskin.entity.*;
import com.bosskin.entity.ExcelHistory.HistoryType;
import com.bosskin.repository.*;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelUtils;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xddf.usermodel.chart.*;
import org.apache.poi.xssf.usermodel.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.Locale;
import java.util.stream.Collectors;

/**
 * Service tạo báo cáo HRM.
 * Mỗi phương thức trả về ResponseEntity<byte[]> (file xlsx) để controller trả về client.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReportService {

    private final EmployeeRepository       employeeRepo;
    private final DepartmentRepository     deptRepo;
    private final AttendanceRepository     attendanceRepo;
    private final PayrollRepository        payrollRepo;
    private final LeaveGrantRepository     leaveGrantRepo;
    private final LeaveTypeRepository      leaveTypeRepo;
    private final LeaveRequestRepository   leaveRequestRepo;
    private final ExcelHistoryHelper       historyHelper;
    private final ExcelI18n               excelI18n;
    private final com.bosskin.repository.EmployeeDependentRepository dependentRepo;
    private final ContractService          contractService;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    // ─── 1. EMPLOYEE HEADCOUNT ───────────────────────────────────────────────

    public ResponseEntity<byte[]> reportEmployeeHeadcount(Long companyId, Long userId,
                                                          Long deptId, Locale locale) {
        List<Employee> employees = deptId != null
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
                .filter(e -> e.getDepartment() != null && e.getDepartment().getId().equals(deptId))
                .collect(Collectors.toList())
            : employeeRepo.findAllByCompanyIdFetchDepartment(companyId);

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetHeadcount", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);

            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.position", locale), i18n("excel.report.gender", locale), i18n("excel.report.joinDate", locale), i18n("excel.report.leaveDate", locale), i18n("excel.report.status", locale)};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Employee e : employees) {
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, e.getPosition() != null ? e.getPosition().getName() : "", data);
                setCell(r, 5, e.getGender() != null ? i18n("excel.enum.gender." + e.getGender().name(), locale) : "", data);
                setCell(r, 6, e.getJoinDate() != null ? e.getJoinDate().format(DATE_FMT) : "", data);
                setCell(r, 7, e.getLeaveDate() != null ? e.getLeaveDate().format(DATE_FMT) : "", data);
                setCell(r, 8, e.getStatus() != null ? i18n("excel.enum.empStatus." + e.getStatus().name(), locale) : "", data);
            }

            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(0, 1);

            // Summary sheet
            XSSFSheet sumSheet = wb.createSheet(i18n("excel.report.sheetSummary", locale));
            Map<String, Long> byDept = employees.stream()
                .collect(Collectors.groupingBy(
                    e -> e.getDepartment() != null ? e.getDepartment().getName() : "N/A",
                    Collectors.counting()));
            Map<String, Long> byStatus = employees.stream()
                .collect(Collectors.groupingBy(
                    e -> e.getStatus() != null ? i18n("excel.enum.empStatus." + e.getStatus().name(), locale) : "?",
                    Collectors.counting()));

            writeHeader(sumSheet, hdr, new String[]{i18n("excel.report.department", locale), i18n("excel.report.count", locale)});
            int sr = 1;
            for (Map.Entry<String, Long> entry : byDept.entrySet()) {
                Row r = sumSheet.createRow(sr++);
                setCell(r, 0, entry.getKey(), data);
                setCell(r, 1, entry.getValue().intValue(), num);
            }
            sr++;
            Row total = sumSheet.createRow(sr++);
            setCell(total, 0, i18n("excel.report.total", locale), hdr);
            setCell(total, 1, employees.size(), hdr);
            sr++;
            writeHeader(sumSheet, hdr, sr, new String[]{i18n("excel.report.status", locale), i18n("excel.report.count", locale)});
            sr++;
            for (Map.Entry<String, Long> entry : byStatus.entrySet()) {
                Row r = sumSheet.createRow(sr++);
                setCell(r, 0, entry.getKey(), data);
                setCell(r, 1, entry.getValue().intValue(), num);
            }
            autoSizeColumns(sumSheet, 2);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "employee_headcount",
                "employee-headcount.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("employee-headcount", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 2. NEW HIRES ────────────────────────────────────────────────────────

    public ResponseEntity<byte[]> reportNewHires(Long companyId, Long userId,
                                                  LocalDate from, LocalDate to, Long deptId, Locale locale) {
        List<Employee> employees = employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .filter(e -> e.getJoinDate() != null
                && !e.getJoinDate().isBefore(from)
                && !e.getJoinDate().isAfter(to))
            .filter(e -> deptId == null
                || (e.getDepartment() != null && e.getDepartment().getId().equals(deptId)))
            .sorted(Comparator.comparing(Employee::getJoinDate))
            .collect(Collectors.toList());

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetNewHires", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);

            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.position", locale), i18n("excel.report.joinDate", locale), i18n("excel.report.gender", locale), i18n("excel.report.email", locale)};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Employee e : employees) {
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, e.getPosition() != null ? e.getPosition().getName() : "", data);
                setCell(r, 5, e.getJoinDate() != null ? e.getJoinDate().format(DATE_FMT) : "", data);
                setCell(r, 6, e.getGender() != null ? i18n("excel.enum.gender." + e.getGender().name(), locale) : "", data);
                setCell(r, 7, e.getEmail(), data);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(0, 1);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "new_hires",
                "new-hires.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("new-hires", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 3. RESIGNED EMPLOYEES ───────────────────────────────────────────────

    public ResponseEntity<byte[]> reportResigned(Long companyId, Long userId,
                                                  LocalDate from, LocalDate to, Long deptId, Locale locale) {
        List<Employee> resigned = employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .filter(e -> e.getLeaveDate() != null
                && !e.getLeaveDate().isBefore(from)
                && !e.getLeaveDate().isAfter(to))
            .filter(e -> deptId == null
                || (e.getDepartment() != null && e.getDepartment().getId().equals(deptId)))
            .sorted(Comparator.comparing(Employee::getLeaveDate))
            .collect(Collectors.toList());

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetResigned", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);

            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.position", locale), i18n("excel.report.joinDate", locale), i18n("excel.report.leaveDate", locale), i18n("excel.report.tenureDays", locale)};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Employee e : resigned) {
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, e.getPosition() != null ? e.getPosition().getName() : "", data);
                setCell(r, 5, e.getJoinDate() != null ? e.getJoinDate().format(DATE_FMT) : "", data);
                setCell(r, 6, e.getLeaveDate().format(DATE_FMT), data);
                long tenure = e.getJoinDate() != null
                    ? java.time.temporal.ChronoUnit.DAYS.between(e.getJoinDate(), e.getLeaveDate()) : 0;
                setCell(r, 7, (int) tenure, num);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(0, 1);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "resigned",
                "resigned.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("resigned", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 4. ATTENDANCE SUMMARY ───────────────────────────────────────────────

    public ResponseEntity<byte[]> reportAttendanceSummary(Long companyId, Long userId,
                                                           int year, int month, Long deptId, Locale locale) {
        LocalDate from = LocalDate.of(year, month, 1);
        LocalDate to   = from.withDayOfMonth(from.lengthOfMonth());

        List<Attendance> records = attendanceRepo.findByCompanyAndDateRange(companyId, from, to);

        List<Employee> employees = deptId != null
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
                .filter(e -> e.getDepartment() != null && e.getDepartment().getId().equals(deptId))
                .collect(Collectors.toList())
            : employeeRepo.findAllByCompanyIdFetchDepartment(companyId);

        Map<Long, List<Attendance>> byEmp = records.stream()
            .collect(Collectors.groupingBy(a -> a.getEmployee().getId()));

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetAttendance", locale) + String.format(" %02d-%d", month, year));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);
            XSSFCellStyle moneyInt = moneyIntStyle(wb);

            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.present", locale), i18n("excel.report.absent", locale), i18n("excel.report.late", locale), i18n("excel.report.halfDay", locale), i18n("excel.report.leave", locale),
                i18n("excel.report.dayHours", locale), i18n("excel.report.nightHours", locale), i18n("excel.report.otDayH", locale), i18n("excel.report.otNightH", locale)};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Employee e : employees) {
                List<Attendance> atts = byEmp.getOrDefault(e.getId(), List.of());
                long present  = atts.stream().filter(a -> a.getStatus() == Attendance.Status.PRESENT).count();
                long late     = atts.stream().filter(a -> a.getStatus() == Attendance.Status.LATE).count();
                long halfDay  = atts.stream().filter(a -> a.getStatus() == Attendance.Status.HALF_DAY).count();
                long leave    = atts.stream().filter(a -> a.getStatus() == Attendance.Status.LEAVE).count();
                long absent   = atts.stream().filter(a -> a.getStatus() == Attendance.Status.ABSENT).count();
                double dayHrs = atts.stream().mapToDouble(a -> nvl(a.getSnapDayHours())).sum();
                double ngtHrs = atts.stream().mapToDouble(a -> nvl(a.getSnapNightHours())).sum();
                double otDay  = atts.stream().mapToDouble(a -> nvl(a.getSnapDayOt())).sum();
                double otNgt  = atts.stream().mapToDouble(a -> nvl(a.getSnapNightOt())).sum();

                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, (int) present,  num);
                setCell(r, 5, (int) absent,   num);
                setCell(r, 6, (int) late,     num);
                setCell(r, 7, (int) halfDay,  num);
                setCell(r, 8, (int) leave,    num);
                setCellD(r, 9,  round2(dayHrs), money, moneyInt);
                setCellD(r, 10, round2(ngtHrs), money, moneyInt);
                setCellD(r, 11, round2(otDay),  money, moneyInt);
                setCellD(r, 12, round2(otNgt),  money, moneyInt);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(3, 1);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "attendance_summary",
                "attendance-summary.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("attendance-summary", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 5. OVERTIME SUMMARY ─────────────────────────────────────────────────

    public ResponseEntity<byte[]> reportOvertimeSummary(Long companyId, Long userId,
                                                         int year, int month, Long deptId, Locale locale) {
        LocalDate from = LocalDate.of(year, month, 1);
        LocalDate to   = from.withDayOfMonth(from.lengthOfMonth());

        List<Attendance> records = attendanceRepo.findByCompanyAndDateRange(companyId, from, to)
            .stream()
            .filter(a -> nvl(a.getSnapDayOt()) > 0 || nvl(a.getSnapNightOt()) > 0)
            .collect(Collectors.toList());

        Map<Long, List<Attendance>> byEmp = records.stream()
            .collect(Collectors.groupingBy(a -> a.getEmployee().getId()));

        List<Employee> employees = deptId != null
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
                .filter(e -> e.getDepartment() != null && e.getDepartment().getId().equals(deptId))
                .collect(Collectors.toList())
            : employeeRepo.findAllByCompanyIdFetchDepartment(companyId);

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetOt", locale) + String.format(" %02d-%d", month, year));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);
            XSSFCellStyle moneyInt = moneyIntStyle(wb);

            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.otDays", locale), i18n("excel.report.otDayHours", locale), i18n("excel.report.otNightHours", locale), i18n("excel.report.totalOt", locale)};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Employee e : employees) {
                List<Attendance> atts = byEmp.getOrDefault(e.getId(), List.of());
                if (atts.isEmpty()) continue;
                double otDay  = atts.stream().mapToDouble(a -> nvl(a.getSnapDayOt())).sum();
                double otNgt  = atts.stream().mapToDouble(a -> nvl(a.getSnapNightOt())).sum();
                long otDays   = atts.stream().filter(a -> nvl(a.getSnapDayOt()) > 0 || nvl(a.getSnapNightOt()) > 0).count();

                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, (int) otDays, num);
                setCellD(r, 5, round2(otDay),          money, moneyInt);
                setCellD(r, 6, round2(otNgt),          money, moneyInt);
                setCellD(r, 7, round2(otDay + otNgt),  money, moneyInt);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(3, 1);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "overtime_summary",
                "overtime-summary.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("overtime-summary", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 6. PAYROLL COST SUMMARY ─────────────────────────────────────────────

    public ResponseEntity<byte[]> reportPayrollSummary(Long companyId, Long userId,
                                                        int year, int month, Long deptId,
                                                        Locale locale) {
        Pageable all = PageRequest.of(0, Integer.MAX_VALUE);
        List<Payroll> payrolls = payrollRepo
            .findByMonthWithFilters(year, month, companyId, deptId, null, all)
            .getContent();

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetPayroll", locale) + String.format(" %02d-%d", month, year));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);
            XSSFCellStyle moneyInt = moneyIntStyle(wb);
            XSSFCellStyle hrs = hrsStyle(wb);

            // Col order: empCode|empName|dept|grade|payType|baseSalary|presentDays|dayHrs|nightHrs|otDay|otNight|totalAllowance|totalIncome|gross|totalDeduction|net|status
            String[] headers = {
                excelI18n.resolve("excel.col.payroll.empCode",        locale),
                excelI18n.resolve("excel.col.payroll.empName",        locale),
                excelI18n.resolve("excel.col.payroll.department",     locale),
                excelI18n.resolve("excel.col.payroll.salaryGrade",    locale),
                excelI18n.resolve("excel.col.payroll.payType",        locale),
                excelI18n.resolve("excel.col.payroll.baseSalary",     locale),
                excelI18n.resolve("excel.col.payroll.presentDays",    locale),
                excelI18n.resolve("excel.col.payroll.dayHours",       locale),
                excelI18n.resolve("excel.col.payroll.nightHours",     locale),
                excelI18n.resolve("excel.col.payroll.otDay",          locale),
                excelI18n.resolve("excel.col.payroll.otNight",        locale),
                excelI18n.resolve("excel.col.payroll.totalAllowance", locale),
                excelI18n.resolve("excel.col.payroll.totalIncome",    locale),
                excelI18n.resolve("excel.col.payroll.gross",          locale),
                excelI18n.resolve("excel.col.payroll.totalDeduction", locale),
                excelI18n.resolve("excel.col.payroll.net",            locale),
                excelI18n.resolve("excel.col.payroll.employerInsurance", locale),
                excelI18n.resolve("excel.col.payroll.totalCost",      locale),
                excelI18n.resolve("excel.col.payroll.status",         locale),
            };
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Payroll p : payrolls) {
                BigDecimal totalAllowance = sumPayrollEntries(p.getAllowanceEntries())
                    .add(bdNvl(p.getAllowance())).add(bdNvl(p.getBonus()));
                BigDecimal totalIncome = sumPayrollEntries(p.getIncomeEntries())
                    .add(bdNvl(p.getOvertimePay()));
                BigDecimal totalDeduction = p.totalDeduction();

                Employee e = p.getEmployee();
                Row r = sheet.createRow(row++);
                setCell(r, 0,  e.getEmployeeCode(), data);
                setCell(r, 1,  e.getFullName(), data);
                setCell(r, 2,  p.getDepartmentName() != null ? p.getDepartmentName()
                    : e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 3,  p.getSalaryGradeName() != null ? p.getSalaryGradeName()
                               : (e.getSalaryGrade() != null ? e.getSalaryGrade().getName() : ""), data);
                setCell(r, 4,  p.getPayType() != null ? p.getPayType() : "", data);
                setCellBD(r, 5,  p.getBaseSalary(),  money, moneyInt);
                setCell(r, 6,  p.getPresentDays() != null ? p.getPresentDays() : 0, num);
                setCellBD(r, 7,  p.getDayHours(),   hrs, moneyInt);
                setCellBD(r, 8,  p.getNightHours(), hrs, moneyInt);
                setCellBD(r, 9,  p.getDayOt(),      hrs, moneyInt);
                setCellBD(r, 10, p.getNightOt(),    hrs, moneyInt);
                setCellBD(r, 11, totalAllowance,      money, moneyInt);
                setCellBD(r, 12, totalIncome,          money, moneyInt);
                setCellBD(r, 13, p.getGrossSalary(), money, moneyInt);
                setCellBD(r, 14, totalDeduction,       money, moneyInt);
                setCellBD(r, 15, p.getNetSalary(),   money, moneyInt);
                // Bước M: chi phí công ty = GROSS + BH công ty đóng
                setCellBD(r, 16, p.employerInsuranceTotal(), money, moneyInt);
                setCellBD(r, 17, bdNvl(p.getGrossSalary()).add(p.employerInsuranceTotal()), money, moneyInt);
                setCell(r, 18, p.getStatus() != null ? p.getStatus().name() : "", data);
            }

            // Totals row — chỉ sum cột tổng tiền (11-15), bỏ lương cơ bản và giờ công
            if (!payrolls.isEmpty()) {
                Row totRow = sheet.createRow(row);
                XSSFCellStyle bold = boldStyle(wb);
                for (int i = 0; i < 11; i++) setCell(totRow, i, i == 2 ? i18n("excel.report.total", locale) : "", bold);
                setCellBD(totRow, 11,
                    payrolls.stream().map(p -> sumPayrollEntries(p.getAllowanceEntries())
                        .add(bdNvl(p.getAllowance())).add(bdNvl(p.getBonus())))
                        .reduce(BigDecimal.ZERO, BigDecimal::add), money, moneyInt);
                setCellBD(totRow, 12,
                    payrolls.stream().map(p -> sumPayrollEntries(p.getIncomeEntries())
                        .add(bdNvl(p.getOvertimePay())))
                        .reduce(BigDecimal.ZERO, BigDecimal::add), money, moneyInt);
                setCellBD(totRow, 13, sum(payrolls, Payroll::getGrossSalary), money, moneyInt);
                setCellBD(totRow, 14,
                    payrolls.stream().map(Payroll::totalDeduction)
                        .reduce(BigDecimal.ZERO, BigDecimal::add), money, moneyInt);
                setCellBD(totRow, 15, sum(payrolls, Payroll::getNetSalary), money, moneyInt);
                setCellBD(totRow, 16, sum(payrolls, Payroll::employerInsuranceTotal), money, moneyInt);
                setCellBD(totRow, 17, sum(payrolls, p -> bdNvl(p.getGrossSalary()).add(p.employerInsuranceTotal())), money, moneyInt);
            }

            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(4, 1);

            // Dept summary sheet
            XSSFSheet sumSheet = wb.createSheet(i18n("excel.report.byDept", locale));
            Map<String, List<Payroll>> byDept = payrolls.stream()
                .collect(Collectors.groupingBy(
                    p -> p.getDepartmentName() != null ? p.getDepartmentName()
                        : p.getEmployee().getDepartment() != null
                        ? p.getEmployee().getDepartment().getName() : "N/A"));
            writeHeader(sumSheet, hdr, new String[]{
                excelI18n.resolve("excel.col.payroll.department",  locale),
                excelI18n.resolve("excel.col.report.headcount",    locale),
                excelI18n.resolve("excel.col.payroll.gross",       locale),
                excelI18n.resolve("excel.col.payroll.net",         locale),
                excelI18n.resolve("excel.col.payroll.employerInsurance", locale),
                excelI18n.resolve("excel.col.payroll.totalCost",   locale),
            });
            int sr = 1;
            for (Map.Entry<String, List<Payroll>> entry : byDept.entrySet()) {
                Row r = sumSheet.createRow(sr++);
                setCell(r, 0, entry.getKey(), data);
                setCell(r, 1, entry.getValue().size(), num);
                setCellBD(r, 2, sum(entry.getValue(), Payroll::getGrossSalary), money, moneyInt);
                setCellBD(r, 3, sum(entry.getValue(), Payroll::getNetSalary),   money, moneyInt);
                setCellBD(r, 4, sum(entry.getValue(), Payroll::employerInsuranceTotal), money, moneyInt);
                setCellBD(r, 5, sum(entry.getValue(), p -> bdNvl(p.getGrossSalary()).add(p.employerInsuranceTotal())), money, moneyInt);
            }
            autoSizeColumns(sumSheet, 6);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "payroll_summary",
                "payroll-summary.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("payroll-summary", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── Bước M: NV tham gia bảo hiểm / người phụ thuộc ──────────────────────

    /** Nhân viên đang làm có ngày tham gia BH hoặc số sổ BHXH; MST / CCCD / sổ BHXH che theo quyền. */
    public ResponseEntity<byte[]> reportInsuredEmployees(Long companyId, Long userId, Long deptId, Locale locale) {
        List<Employee> employees = employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .filter(e -> deptId == null || (e.getDepartment() != null && e.getDepartment().getId().equals(deptId)))
            .filter(e -> e.getStatus() != Employee.Status.INACTIVE)
            .filter(e -> e.getInsuranceJoinDate() != null || (e.getSocialInsuranceNo() != null && !e.getSocialInsuranceNo().isBlank()))
            .sorted(java.util.Comparator.comparing(Employee::getEmployeeCode))
            .collect(Collectors.toList());
        Map<Long, BigDecimal> insuranceSalary = contractService.currentInsuranceSalaries(companyId);
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetInsured", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);
            XSSFCellStyle moneyInt = moneyIntStyle(wb);
            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale),
                i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.identityCard", locale), i18n("excel.report.taxCode", locale),
                i18n("excel.report.socialInsuranceNo", locale), i18n("excel.report.healthInsurancePlace", locale),
                i18n("excel.report.insuranceJoinDate", locale), i18n("excel.report.insuranceSalary", locale)};
            writeHeader(sheet, hdr, headers);
            int row = 1;
            for (Employee e : employees) {
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, nz(com.bosskin.core.SensitiveData.forViewer(e.getIdentityCard())), data);
                setCell(r, 5, nz(com.bosskin.core.SensitiveData.forViewer(e.getTaxCode())), data);
                setCell(r, 6, nz(com.bosskin.core.SensitiveData.forViewer(e.getSocialInsuranceNo())), data);
                setCell(r, 7, nz(e.getHealthInsurancePlace()), data);
                setCell(r, 8, e.getInsuranceJoinDate() != null ? e.getInsuranceJoinDate().format(DATE_FMT) : "", data);
                BigDecimal salary = insuranceSalary.get(e.getId());
                if (salary == null) salary = e.getContractSalary();
                setCellBD(r, 9, salary, money, moneyInt);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(3, 1);
            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "insured_employees",
                "insured-employees.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("insured-employees", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    /** Người phụ thuộc của nhân viên; MST / CCCD che theo quyền. */
    public ResponseEntity<byte[]> reportDependents(Long companyId, Long userId, Long deptId, Locale locale) {
        List<com.bosskin.entity.EmployeeDependent> rows = dependentRepo.findByCompany(companyId).stream()
            .filter(d -> deptId == null || (d.getEmployee().getDepartment() != null
                && d.getEmployee().getDepartment().getId().equals(deptId)))
            .collect(Collectors.toList());
        java.time.format.DateTimeFormatter monthFmt = java.time.format.DateTimeFormatter.ofPattern("MM/yyyy");
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetDependents", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale),
                i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.dependentName", locale), i18n("excel.report.relationship", locale),
                i18n("excel.report.dateOfBirth", locale), i18n("excel.report.dependentId", locale),
                i18n("excel.report.deductionFrom", locale), i18n("excel.report.deductionTo", locale),
                i18n("excel.report.registrationStatus", locale)};
            writeHeader(sheet, hdr, headers);
            int row = 1;
            for (var d : rows) {
                Employee e = d.getEmployee();
                String id = d.getTaxCode() != null ? d.getTaxCode() : d.getIdentityNo();
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, d.getFullName(), data);
                setCell(r, 5, i18n("excel.enum.relationship." + d.getRelationship().name(), locale), data);
                setCell(r, 6, d.getDateOfBirth() != null ? d.getDateOfBirth().format(DATE_FMT) : "", data);
                setCell(r, 7, nz(com.bosskin.core.SensitiveData.forViewer(id)), data);
                setCell(r, 8, d.getDeductionFrom().format(monthFmt), data);
                setCell(r, 9, d.getDeductionTo() != null ? d.getDeductionTo().format(monthFmt) : "", data);
                setCell(r, 10, i18n("excel.enum.dependentStatus." + d.getRegistrationStatus().name(), locale), data);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(3, 1);
            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "dependents",
                "dependents.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("dependents", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    private static String nz(String v) { return v == null ? "" : v; }

    // ─── 7. LEAVE BALANCE SUMMARY ────────────────────────────────────────────

    public ResponseEntity<byte[]> reportLeaveBalance(Long companyId, Long userId, Long deptId, Locale locale) {
        List<LeaveGrant> grants = leaveGrantRepo.findForCompany(companyId, null, null);
        List<LeaveType> types = leaveTypeRepo.findByCompanyIdAndDeletedFalseOrderByNameAsc(companyId);

        List<Employee> employees = deptId != null
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
                .filter(e -> e.getDepartment() != null && e.getDepartment().getId().equals(deptId))
                .collect(Collectors.toList())
            : employeeRepo.findAllByCompanyIdFetchDepartment(companyId);

        Map<Long, Map<Long, BigDecimal>> remainingByEmpAndType = new HashMap<>();
        for (LeaveGrant g : grants) {
            if (g.getEmployee() == null || g.getLeaveType() == null) continue;
            Long eid = g.getEmployee().getId();
            Long tid = g.getLeaveType().getId();
            BigDecimal remaining = (g.getGrantDays() != null ? g.getGrantDays() : BigDecimal.ZERO)
                .subtract(g.getUsedDays());
            remainingByEmpAndType.computeIfAbsent(eid, k -> new HashMap<>())
                .merge(tid, remaining, BigDecimal::add);
        }

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetLeaveBalance", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);

            // Header: Emp Code | Name | Dept | [LeaveType1] | [LeaveType2] | ...
            String[] baseHdrs = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale)};
            Row hRow = sheet.createRow(0);
            hRow.setHeight((short) 500);
            for (int i = 0; i < baseHdrs.length; i++) {
                Cell c = hRow.createCell(i);
                c.setCellValue(baseHdrs[i]);
                c.setCellStyle(hdr);
            }
            for (int i = 0; i < types.size(); i++) {
                Cell c = hRow.createCell(baseHdrs.length + i);
                c.setCellValue(types.get(i).getName() + " (days)");
                c.setCellStyle(hdr);
            }

            int row = 1;
            for (Employee e : employees) {
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                Map<Long, BigDecimal> empRemaining = remainingByEmpAndType.getOrDefault(e.getId(), Map.of());
                for (int i = 0; i < types.size(); i++) {
                    BigDecimal val = empRemaining.getOrDefault(types.get(i).getId(), BigDecimal.ZERO);
                    setCellBD(r, baseHdrs.length + i, val, money);
                }
            }
            autoSizeColumns(sheet, baseHdrs.length + types.size());
            sheet.createFreezePane(3, 1);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "leave_balance",
                "leave-balance.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("leave-balance", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 8. LEAVE USAGE ──────────────────────────────────────────────────────

    public ResponseEntity<byte[]> reportLeaveUsage(Long companyId, Long userId,
                                                    LocalDate from, LocalDate to, Long deptId, Locale locale) {
        List<LeaveRequest> requests = leaveRequestRepo
            .findByCompanyAndStatus(companyId, null).stream()
            .filter(lr -> !lr.getFromDate().isAfter(to) && !lr.getToDate().isBefore(from))
            .filter(lr -> deptId == null
                || (lr.getEmployee().getDepartment() != null
                    && lr.getEmployee().getDepartment().getId().equals(deptId)))
            .sorted(Comparator.comparing(LeaveRequest::getFromDate))
            .collect(Collectors.toList());

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet(i18n("excel.report.sheetLeaveUsage", locale));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);

            String[] headers = {i18n("excel.report.no", locale), i18n("excel.report.employeeCode", locale), i18n("excel.report.fullName", locale), i18n("excel.report.department", locale),
                i18n("excel.report.leaveType", locale), i18n("excel.report.from", locale), i18n("excel.report.to", locale), i18n("excel.report.days", locale), i18n("excel.report.status", locale), i18n("excel.report.reason", locale)};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (LeaveRequest lr : requests) {
                Row r = sheet.createRow(row++);
                Employee e = lr.getEmployee();
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e != null ? e.getEmployeeCode() : "", data);
                setCell(r, 2, e != null ? e.getFullName() : "", data);
                setCell(r, 3, e != null && e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, lr.getLeaveType() != null ? lr.getLeaveType().getName() : "", data);
                setCell(r, 5, lr.getFromDate() != null ? lr.getFromDate().format(DATE_FMT) : "", data);
                setCell(r, 6, lr.getToDate() != null ? lr.getToDate().format(DATE_FMT) : "", data);
                setCellBD(r, 7, lr.getRequestedAmount(), money);
                setCell(r, 8, lr.getStatus() != null ? lr.getStatus().name() : "", data);
                setCell(r, 9, lr.getReason() != null ? lr.getReason() : "", data);
            }
            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(3, 1);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "leave_usage",
                "leave-usage.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("leave-usage", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ── Yearly Overview ───────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> reportYearlyOverview(Long companyId, Long userId,
                                                        int year, Long deptId, Locale locale) {
        // Payroll: gross, net, deduction, count, dayOt, nightOt, presentDays per month
        double[] gross = new double[13], net = new double[13], ded = new double[13];
        int[]    payCount = new int[13];
        double[] dayOtA = new double[13], nightOtA = new double[13], presDayA = new double[13];
        for (Object[] r : payrollRepo.findYearlySummary(companyId, year, deptId)) {
            int m = asInt(r[0]);
            gross[m]    = asDbl(r[1]);
            net[m]      = asDbl(r[2]);
            ded[m]      = asDbl(r[3]);
            payCount[m] = asInt(r[4]);
            dayOtA[m]   = asDbl(r[5]);
            nightOtA[m] = asDbl(r[6]);
            presDayA[m] = asDbl(r[7]);
        }
        double[] otTotal = new double[13];
        for (int m = 1; m <= 12; m++) otTotal[m] = dayOtA[m] + nightOtA[m];

        // HR: new hires, resigned, headcount per month (computed từ danh sách nhân viên)
        int[] headcount = new int[13], newHires = new int[13], resigned = new int[13];
        List<Employee> emps = deptId != null
            ? employeeRepo.findAllByCompanyIdAndDepartmentIdInFetchDepartment(companyId, List.of(deptId))
            : employeeRepo.findAllByCompanyIdFetchDepartment(companyId);
        for (int m = 1; m <= 12; m++) {
            LocalDate from = LocalDate.of(year, m, 1);
            LocalDate to   = from.withDayOfMonth(from.lengthOfMonth());
            for (Employee e : emps) {
                if (e.getJoinDate() == null) continue;
                if (!e.getJoinDate().isBefore(from) && !e.getJoinDate().isAfter(to)) newHires[m]++;
                if (e.getLeaveDate() != null
                        && !e.getLeaveDate().isBefore(from) && !e.getLeaveDate().isAfter(to)) resigned[m]++;
                if (!e.getJoinDate().isAfter(to)
                        && (e.getLeaveDate() == null || e.getLeaveDate().isAfter(to))) headcount[m]++;
            }
        }

        // Leave: days used, request count per month
        double[] leaveDays = new double[13];
        int[]    leaveCount = new int[13];
        for (Object[] r : leaveRequestRepo.findMonthlyLeaveUsageByYear(
                companyId, year, deptId, LeaveRequest.Status.APPROVED)) {
            int m = asInt(r[0]);
            leaveDays[m]  = asDbl(r[1]);
            leaveCount[m] = asInt(r[2]);
        }

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            buildYearSummarySheet(wb, year, locale, gross, net, ded, newHires, resigned, headcount, otTotal, leaveDays);
            buildYearHrSheet(wb, year, locale, newHires, resigned, headcount);
            buildYearPayrollSheet(wb, year, locale, gross, net, ded, payCount);
            buildYearAttendanceSheet(wb, year, locale, presDayA, otTotal, payCount);
            buildYearLeaveSheet(wb, year, locale, leaveDays, leaveCount);
            byte[] bytes = toBytes(wb);
            String filename = "yearly-overview-" + year + ".xlsx";
            return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"" + filename + "\"")
                .header("Content-Type",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                .body(bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    /** Sheet 1 — Tổng quan: tất cả chỉ số chính theo tháng + 2 biểu đồ */
    private void buildYearSummarySheet(XSSFWorkbook wb, int year, Locale locale,
            double[] gross, double[] net, double[] ded,
            int[] newHires, int[] resigned, int[] headcount,
            double[] otTotal, double[] leaveDays) {
        XSSFSheet sheet = wb.createSheet(i18n("excel.sheet.yearly.summary", locale));
        XSSFCellStyle hdr = headerStyle(wb), data = dataStyle(wb), num = numStyle(wb);
        XSSFCellStyle money = moneyIntStyle(wb), hrs = hrsStyle(wb), pct = pctStyle(wb);
        String[] headers = {
            i18n("excel.col.yearly.month",       locale),
            i18n("excel.col.yearly.headcount",    locale),
            i18n("excel.col.yearly.newHires",     locale),
            i18n("excel.col.yearly.resigned",     locale),
            i18n("excel.col.yearly.netChange",    locale),
            i18n("excel.col.yearly.turnoverRate", locale),
            i18n("excel.col.payroll.gross",       locale),
            i18n("excel.col.payroll.net",         locale),
            i18n("excel.col.yearly.deduction",    locale),
            i18n("excel.col.yearly.otHours",      locale),
            i18n("excel.col.yearly.leaveDays",    locale),
        };
        writeHeader(sheet, hdr, headers);
        int tNH = 0, tRs = 0;
        double tGross = 0, tNet = 0, tDed = 0, tOt = 0, tLeave = 0;
        for (int m = 1; m <= 12; m++) {
            Row row = sheet.createRow(m);
            double turnover = headcount[m] > 0 ? (resigned[m] * 100.0 / headcount[m]) : 0;
            setCell(row, 0, String.format("%02d", m), data);
            setCell(row, 1, headcount[m], num);
            setCell(row, 2, newHires[m], num);
            setCell(row, 3, resigned[m], num);
            setCell(row, 4, newHires[m] - resigned[m], num);
            setCellD(row, 5, turnover, pct, pct);
            setCellD(row, 6, gross[m], money, money);
            setCellD(row, 7, net[m], money, money);
            setCellD(row, 8, ded[m], money, money);
            setCellD(row, 9, otTotal[m], hrs, num);
            setCellD(row, 10, leaveDays[m], hrs, num);
            tNH += newHires[m]; tRs += resigned[m];
            tGross += gross[m]; tNet += net[m]; tDed += ded[m];
            tOt += otTotal[m]; tLeave += leaveDays[m];
        }
        Row tot = sheet.createRow(13);
        XSSFCellStyle bold = boldStyle(wb);
        setCell(tot, 0, i18n("excel.report.total", locale), bold);
        setCell(tot, 1, headcount[12], bold);
        setCell(tot, 2, tNH, bold); setCell(tot, 3, tRs, bold);
        setCell(tot, 4, tNH - tRs, bold);
        setCellD(tot, 6, tGross, money, money); setCellD(tot, 7, tNet, money, money);
        setCellD(tot, 8, tDed, money, money);
        setCellD(tot, 9, tOt, hrs, num); setCellD(tot, 10, tLeave, hrs, num);
        autoSizeColumns(sheet, headers.length);
        sheet.createFreezePane(1, 1);
        addBarChart(sheet,
            i18n("excel.chart.yearly.grossVsNet", locale) + " " + year,
            1, 12, 0, new int[]{6, 7},
            new String[]{i18n("excel.col.payroll.gross", locale), i18n("excel.col.payroll.net", locale)},
            0, 15, 8, 33);
        addLineChart(sheet,
            i18n("excel.chart.yearly.headcountTrend", locale) + " " + year,
            1, 12, 0, new int[]{1, 2, 3},
            new String[]{
                i18n("excel.col.yearly.headcount", locale),
                i18n("excel.col.yearly.newHires", locale),
                i18n("excel.col.yearly.resigned", locale)},
            8, 15, 16, 33);
    }

    /** Sheet 2 — Nhân sự: biến động nhân sự + tỷ lệ thôi việc + 2 biểu đồ */
    private void buildYearHrSheet(XSSFWorkbook wb, int year, Locale locale,
            int[] newHires, int[] resigned, int[] headcount) {
        XSSFSheet sheet = wb.createSheet(i18n("excel.sheet.yearly.hr", locale));
        XSSFCellStyle hdr = headerStyle(wb), data = dataStyle(wb), num = numStyle(wb), pct = pctStyle(wb);
        String[] headers = {
            i18n("excel.col.yearly.month",       locale),
            i18n("excel.col.yearly.headcount",    locale),
            i18n("excel.col.yearly.newHires",     locale),
            i18n("excel.col.yearly.resigned",     locale),
            i18n("excel.col.yearly.netChange",    locale),
            i18n("excel.col.yearly.turnoverRate", locale),
        };
        writeHeader(sheet, hdr, headers);
        int tNH = 0, tRs = 0;
        for (int m = 1; m <= 12; m++) {
            Row row = sheet.createRow(m);
            double turnover = headcount[m] > 0 ? (resigned[m] * 100.0 / headcount[m]) : 0;
            setCell(row, 0, String.format("%02d", m), data);
            setCell(row, 1, headcount[m], num);
            setCell(row, 2, newHires[m], num);
            setCell(row, 3, resigned[m], num);
            setCell(row, 4, newHires[m] - resigned[m], num);
            setCellD(row, 5, turnover, pct, pct);
            tNH += newHires[m]; tRs += resigned[m];
        }
        Row tot = sheet.createRow(13);
        XSSFCellStyle bold = boldStyle(wb);
        setCell(tot, 0, i18n("excel.report.total", locale), bold);
        setCell(tot, 1, headcount[12], bold);
        setCell(tot, 2, tNH, bold); setCell(tot, 3, tRs, bold);
        setCell(tot, 4, tNH - tRs, bold);
        autoSizeColumns(sheet, headers.length);
        sheet.createFreezePane(1, 1);
        addBarChart(sheet,
            i18n("excel.chart.yearly.hrMovement", locale) + " " + year,
            1, 12, 0, new int[]{2, 3},
            new String[]{i18n("excel.col.yearly.newHires", locale), i18n("excel.col.yearly.resigned", locale)},
            0, 15, 8, 33);
        addLineChart(sheet,
            i18n("excel.chart.yearly.headcountTrend", locale) + " " + year,
            1, 12, 0, new int[]{1},
            new String[]{i18n("excel.col.yearly.headcount", locale)},
            0, 34, 8, 52);
    }

    /** Sheet 3 — Chi phí lương: gross/net/khấu trừ, avg, MoM% + 2 biểu đồ */
    private void buildYearPayrollSheet(XSSFWorkbook wb, int year, Locale locale,
            double[] gross, double[] net, double[] ded, int[] payCount) {
        XSSFSheet sheet = wb.createSheet(i18n("excel.sheet.yearly.payroll", locale));
        XSSFCellStyle hdr = headerStyle(wb), data = dataStyle(wb), num = numStyle(wb);
        XSSFCellStyle money = moneyIntStyle(wb), pct = pctStyle(wb);
        String[] headers = {
            i18n("excel.col.yearly.month",       locale),
            i18n("excel.col.yearly.payslipCount", locale),
            i18n("excel.col.payroll.gross",       locale),
            i18n("excel.col.payroll.net",         locale),
            i18n("excel.col.yearly.deduction",    locale),
            i18n("excel.col.yearly.avgNet",       locale),
            i18n("excel.col.yearly.momChange",    locale),
        };
        writeHeader(sheet, hdr, headers);
        int tCount = 0; double tGross = 0, tNet = 0, tDed = 0;
        for (int m = 1; m <= 12; m++) {
            Row row = sheet.createRow(m);
            double avgNet = payCount[m] > 0 ? net[m] / payCount[m] : 0;
            double prevNet = m > 1 ? net[m - 1] : 0;
            double mom = prevNet > 0 ? ((net[m] - prevNet) / prevNet * 100) : 0;
            setCell(row, 0, String.format("%02d", m), data);
            setCell(row, 1, payCount[m], num);
            setCellD(row, 2, gross[m], money, money);
            setCellD(row, 3, net[m], money, money);
            setCellD(row, 4, ded[m], money, money);
            setCellD(row, 5, avgNet, money, money);
            if (m > 1) setCellD(row, 6, mom, pct, pct);
            tCount += payCount[m]; tGross += gross[m]; tNet += net[m]; tDed += ded[m];
        }
        Row tot = sheet.createRow(13);
        XSSFCellStyle bold = boldStyle(wb);
        setCell(tot, 0, i18n("excel.report.total", locale), bold); setCell(tot, 1, tCount, bold);
        setCellD(tot, 2, tGross, money, money); setCellD(tot, 3, tNet, money, money);
        setCellD(tot, 4, tDed, money, money);
        autoSizeColumns(sheet, headers.length);
        sheet.createFreezePane(1, 1);
        addBarChart(sheet,
            i18n("excel.chart.yearly.payrollCost", locale) + " " + year,
            1, 12, 0, new int[]{2, 3, 4},
            new String[]{
                i18n("excel.col.payroll.gross", locale),
                i18n("excel.col.payroll.net", locale),
                i18n("excel.col.yearly.deduction", locale)},
            0, 15, 8, 33);
        addLineChart(sheet,
            i18n("excel.chart.yearly.avgSalary", locale) + " " + year,
            1, 12, 0, new int[]{5},
            new String[]{i18n("excel.col.yearly.avgNet", locale)},
            0, 34, 8, 52);
    }

    /** Sheet 4 — Chấm công & OT: ngày công, giờ OT + 2 biểu đồ */
    private void buildYearAttendanceSheet(XSSFWorkbook wb, int year, Locale locale,
            double[] presDay, double[] otTotal, int[] payCount) {
        XSSFSheet sheet = wb.createSheet(i18n("excel.sheet.yearly.attendance", locale));
        XSSFCellStyle hdr = headerStyle(wb), data = dataStyle(wb), num = numStyle(wb), hrs = hrsStyle(wb);
        String[] headers = {
            i18n("excel.col.yearly.month",          locale),
            i18n("excel.col.yearly.presentDays",     locale),
            i18n("excel.col.yearly.avgPresentDays",  locale),
            i18n("excel.col.yearly.otHours",         locale),
            i18n("excel.col.yearly.avgOtHours",      locale),
        };
        writeHeader(sheet, hdr, headers);
        double tPres = 0, tOt = 0;
        for (int m = 1; m <= 12; m++) {
            Row row = sheet.createRow(m);
            double avgPres = payCount[m] > 0 ? presDay[m] / payCount[m] : 0;
            double avgOt   = payCount[m] > 0 ? otTotal[m] / payCount[m] : 0;
            setCell(row, 0, String.format("%02d", m), data);
            setCellD(row, 1, presDay[m], num, num);
            setCellD(row, 2, avgPres, hrs, num);
            setCellD(row, 3, otTotal[m], hrs, num);
            setCellD(row, 4, avgOt, hrs, num);
            tPres += presDay[m]; tOt += otTotal[m];
        }
        Row tot = sheet.createRow(13);
        XSSFCellStyle bold = boldStyle(wb);
        setCell(tot, 0, i18n("excel.report.total", locale), bold);
        setCellD(tot, 1, tPres, num, num); setCellD(tot, 3, tOt, hrs, num);
        autoSizeColumns(sheet, headers.length);
        sheet.createFreezePane(1, 1);
        addBarChart(sheet,
            i18n("excel.chart.yearly.otTrend", locale) + " " + year,
            1, 12, 0, new int[]{3},
            new String[]{i18n("excel.col.yearly.otHours", locale)},
            0, 15, 8, 33);
        addLineChart(sheet,
            i18n("excel.chart.yearly.presentTrend", locale) + " " + year,
            1, 12, 0, new int[]{2},
            new String[]{i18n("excel.col.yearly.avgPresentDays", locale)},
            0, 34, 8, 52);
    }

    /** Sheet 5 — Nghỉ phép: số đơn và ngày phép đã dùng + biểu đồ */
    private void buildYearLeaveSheet(XSSFWorkbook wb, int year, Locale locale,
            double[] leaveDays, int[] leaveCount) {
        XSSFSheet sheet = wb.createSheet(i18n("excel.sheet.yearly.leave", locale));
        XSSFCellStyle hdr = headerStyle(wb), data = dataStyle(wb), num = numStyle(wb), hrs = hrsStyle(wb);
        String[] headers = {
            i18n("excel.col.yearly.month",      locale),
            i18n("excel.col.yearly.leaveCount", locale),
            i18n("excel.col.yearly.leaveDays",  locale),
        };
        writeHeader(sheet, hdr, headers);
        int tCount = 0; double tDays = 0;
        for (int m = 1; m <= 12; m++) {
            Row row = sheet.createRow(m);
            setCell(row, 0, String.format("%02d", m), data);
            setCell(row, 1, leaveCount[m], num);
            setCellD(row, 2, leaveDays[m], hrs, num);
            tCount += leaveCount[m]; tDays += leaveDays[m];
        }
        Row tot = sheet.createRow(13);
        XSSFCellStyle bold = boldStyle(wb);
        setCell(tot, 0, i18n("excel.report.total", locale), bold);
        setCell(tot, 1, tCount, bold); setCellD(tot, 2, tDays, hrs, num);
        autoSizeColumns(sheet, headers.length);
        sheet.createFreezePane(1, 1);
        addBarChart(sheet,
            i18n("excel.chart.yearly.leaveTrend", locale) + " " + year,
            1, 12, 0, new int[]{2},
            new String[]{i18n("excel.col.yearly.leaveDays", locale)},
            0, 15, 7, 33);
    }

    /** Column bar chart nhúng vào sheet, tham chiếu dữ liệu từ cell range. */
    private static void addBarChart(XSSFSheet sheet, String title,
            int r1, int r2, int catCol, int[] valCols, String[] names,
            int ancC1, int ancR1, int ancC2, int ancR2) {
        XSSFDrawing d = sheet.createDrawingPatriarch();
        XSSFChart chart = d.createChart(d.createAnchor(0, 0, 0, 0, ancC1, ancR1, ancC2, ancR2));
        chart.setTitleText(title); chart.setTitleOverlay(false);
        XDDFChartLegend legend = chart.getOrAddLegend();
        legend.setPosition(LegendPosition.BOTTOM);
        XDDFCategoryAxis catAxis = chart.createCategoryAxis(AxisPosition.BOTTOM);
        XDDFValueAxis valAxis = chart.createValueAxis(AxisPosition.LEFT);
        valAxis.setCrosses(AxisCrosses.AUTO_ZERO);
        XDDFBarChartData data = (XDDFBarChartData) chart.createData(ChartTypes.BAR, catAxis, valAxis);
        data.setBarDirection(BarDirection.COL);
        XDDFCategoryDataSource cats = XDDFDataSourcesFactory.fromStringCellRange(
            sheet, new CellRangeAddress(r1, r2, catCol, catCol));
        for (int i = 0; i < valCols.length; i++) {
            XDDFNumericalDataSource<Double> vals = XDDFDataSourcesFactory.fromNumericCellRange(
                sheet, new CellRangeAddress(r1, r2, valCols[i], valCols[i]));
            XDDFBarChartData.Series s = (XDDFBarChartData.Series) data.addSeries(cats, vals);
            s.setTitle(names[i], null);
        }
        chart.plot(data);
    }

    /** Line chart nhúng vào sheet, tham chiếu dữ liệu từ cell range. */
    private static void addLineChart(XSSFSheet sheet, String title,
            int r1, int r2, int catCol, int[] valCols, String[] names,
            int ancC1, int ancR1, int ancC2, int ancR2) {
        XSSFDrawing d = sheet.createDrawingPatriarch();
        XSSFChart chart = d.createChart(d.createAnchor(0, 0, 0, 0, ancC1, ancR1, ancC2, ancR2));
        chart.setTitleText(title); chart.setTitleOverlay(false);
        XDDFChartLegend legend = chart.getOrAddLegend();
        legend.setPosition(LegendPosition.BOTTOM);
        XDDFCategoryAxis catAxis = chart.createCategoryAxis(AxisPosition.BOTTOM);
        XDDFValueAxis valAxis = chart.createValueAxis(AxisPosition.LEFT);
        valAxis.setCrosses(AxisCrosses.AUTO_ZERO);
        XDDFLineChartData data = (XDDFLineChartData) chart.createData(ChartTypes.LINE, catAxis, valAxis);
        XDDFCategoryDataSource cats = XDDFDataSourcesFactory.fromStringCellRange(
            sheet, new CellRangeAddress(r1, r2, catCol, catCol));
        for (int i = 0; i < valCols.length; i++) {
            XDDFNumericalDataSource<Double> vals = XDDFDataSourcesFactory.fromNumericCellRange(
                sheet, new CellRangeAddress(r1, r2, valCols[i], valCols[i]));
            XDDFLineChartData.Series s = (XDDFLineChartData.Series) data.addSeries(cats, vals);
            s.setTitle(names[i], null);
            s.setSmooth(false);
            s.setMarkerStyle(MarkerStyle.CIRCLE);
        }
        chart.plot(data);
    }

    // ─── HELPERS ─────────────────────────────────────────────────────────────

    private void writeHeader(XSSFSheet sheet, XSSFCellStyle hdrStyle, String[] headers) {
        writeHeader(sheet, hdrStyle, 0, headers);
    }

    private void writeHeader(XSSFSheet sheet, XSSFCellStyle hdrStyle, int rowIdx, String[] headers) {
        Row hRow = sheet.createRow(rowIdx);
        hRow.setHeight((short) 500);
        for (int i = 0; i < headers.length; i++) {
            Cell c = hRow.createCell(i);
            c.setCellValue(headers[i]);
            c.setCellStyle(hdrStyle);
        }
    }

    private void setCell(Row row, int col, String val, CellStyle style) {
        Cell c = row.createCell(col);
        c.setCellValue(val != null ? val : "");
        c.setCellStyle(style);
    }

    private void setCell(Row row, int col, int val, CellStyle style) {
        Cell c = row.createCell(col);
        c.setCellValue(val);
        c.setCellStyle(style);
    }

    /** Picks intStyle for whole numbers to avoid LibreOffice trailing-dot rendering. */
    private void setCellD(Row row, int col, double val, CellStyle decStyle, CellStyle intStyle) {
        Cell c = row.createCell(col);
        c.setCellValue(val);
        c.setCellStyle(val % 1.0 == 0.0 ? intStyle : decStyle);
    }

    private void setCellBD(Row row, int col, BigDecimal val, CellStyle style) {
        Cell c = row.createCell(col);
        c.setCellValue(val != null ? val.doubleValue() : 0);
        c.setCellStyle(style);
    }

    /** Picks intStyle for whole-number BigDecimals to avoid LibreOffice trailing-dot rendering. */
    private void setCellBD(Row row, int col, BigDecimal val, CellStyle decStyle, CellStyle intStyle) {
        Cell c = row.createCell(col);
        double dv = val != null ? val.doubleValue() : 0;
        c.setCellValue(dv);
        c.setCellStyle(dv % 1.0 == 0.0 ? intStyle : decStyle);
    }

    private void autoSizeColumns(XSSFSheet sheet, int count) {
        for (int i = 0; i < count; i++) {
            sheet.setColumnWidth(i, Math.min(30 * 256, Math.max(12 * 256, 18 * 256)));
        }
    }

    private static XSSFCellStyle headerStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        XSSFFont font = wb.createFont();
        font.setBold(true);
        font.setColor(new XSSFColor(new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF}, null));
        style.setFont(font);
        style.setFillForegroundColor(new XSSFColor(new byte[]{(byte)0x21,(byte)0x5C,(byte)0x98}, null));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.MEDIUM);
        style.setWrapText(true);
        return style;
    }

    private static XSSFCellStyle dataStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static XSSFCellStyle numStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static XSSFCellStyle moneyStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0.##"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static XSSFCellStyle moneyIntStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static XSSFCellStyle hrsStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0.0#"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static XSSFCellStyle pctStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        style.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("0.0"));
        style.setAlignment(HorizontalAlignment.RIGHT);
        style.setBorderRight(BorderStyle.HAIR);
        style.setBorderBottom(BorderStyle.HAIR);
        return style;
    }

    private static XSSFCellStyle boldStyle(XSSFWorkbook wb) {
        XSSFCellStyle style = wb.createCellStyle();
        XSSFFont font = wb.createFont();
        font.setBold(true);
        style.setFont(font);
        style.setBorderTop(BorderStyle.MEDIUM);
        return style;
    }

    private static byte[] toBytes(XSSFWorkbook wb) throws IOException {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            wb.write(out);
            return out.toByteArray();
        }
    }

    private double nvl(Double v) { return v != null ? v : 0.0; }

    private static BigDecimal bdNvl(BigDecimal v) { return v != null ? v : BigDecimal.ZERO; }

    private static int asInt(Object o) { return o == null ? 0 : ((Number) o).intValue(); }
    private static double asDbl(Object o) { return o == null ? 0.0 : ((Number) o).doubleValue(); }
    private String i18n(String key, Locale locale) { return excelI18n.resolve(key, locale); }

    private static BigDecimal sumPayrollEntries(Map<String, Payroll.DeductionEntry> m) {
        if (m == null || m.isEmpty()) return BigDecimal.ZERO;
        return m.values().stream()
            .map(Payroll.DeductionEntry::getAmount)
            .filter(Objects::nonNull)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }

    private BigDecimal sum(List<Payroll> payrolls, java.util.function.Function<Payroll, BigDecimal> getter) {
        return payrolls.stream()
            .map(getter)
            .filter(Objects::nonNull)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
