package com.bosskin.service;

import com.bosskin.entity.*;
import com.bosskin.entity.ExcelHistory.HistoryType;
import com.bosskin.repository.*;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelUtils;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
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

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    // ─── 1. EMPLOYEE HEADCOUNT ───────────────────────────────────────────────

    public ResponseEntity<byte[]> reportEmployeeHeadcount(Long companyId, Long userId,
                                                          Long deptId) {
        List<Employee> employees = deptId != null
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
                .filter(e -> e.getDepartment() != null && e.getDepartment().getId().equals(deptId))
                .collect(Collectors.toList())
            : employeeRepo.findAllByCompanyIdFetchDepartment(companyId);

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet("Employee Headcount");
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);

            String[] headers = {"#", "Employee Code", "Full Name", "Department",
                "Position", "Gender", "Join Date", "Leave Date", "Status"};
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Employee e : employees) {
                Row r = sheet.createRow(row++);
                setCell(r, 0, row - 1, num);
                setCell(r, 1, e.getEmployeeCode(), data);
                setCell(r, 2, e.getFullName(), data);
                setCell(r, 3, e.getDepartment() != null ? e.getDepartment().getName() : "", data);
                setCell(r, 4, e.getPosition() != null ? e.getPosition().getName() : "", data);
                setCell(r, 5, e.getGender() != null ? e.getGender().name() : "", data);
                setCell(r, 6, e.getJoinDate() != null ? e.getJoinDate().format(DATE_FMT) : "", data);
                setCell(r, 7, e.getLeaveDate() != null ? e.getLeaveDate().format(DATE_FMT) : "", data);
                setCell(r, 8, e.getStatus() != null ? e.getStatus().name() : "", data);
            }

            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(0, 1);

            // Summary sheet
            XSSFSheet sumSheet = wb.createSheet("Summary");
            Map<String, Long> byDept = employees.stream()
                .collect(Collectors.groupingBy(
                    e -> e.getDepartment() != null ? e.getDepartment().getName() : "N/A",
                    Collectors.counting()));
            Map<String, Long> byStatus = employees.stream()
                .collect(Collectors.groupingBy(
                    e -> e.getStatus() != null ? e.getStatus().name() : "UNKNOWN",
                    Collectors.counting()));

            writeHeader(sumSheet, hdr, new String[]{"Department", "Count"});
            int sr = 1;
            for (Map.Entry<String, Long> entry : byDept.entrySet()) {
                Row r = sumSheet.createRow(sr++);
                setCell(r, 0, entry.getKey(), data);
                setCell(r, 1, entry.getValue().intValue(), num);
            }
            sr++;
            Row total = sumSheet.createRow(sr++);
            setCell(total, 0, "TOTAL", hdr);
            setCell(total, 1, employees.size(), hdr);
            sr++;
            writeHeader(sumSheet, hdr, sr, new String[]{"Status", "Count"});
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
                                                  LocalDate from, LocalDate to, Long deptId) {
        List<Employee> employees = employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .filter(e -> e.getJoinDate() != null
                && !e.getJoinDate().isBefore(from)
                && !e.getJoinDate().isAfter(to))
            .filter(e -> deptId == null
                || (e.getDepartment() != null && e.getDepartment().getId().equals(deptId)))
            .sorted(Comparator.comparing(Employee::getJoinDate))
            .collect(Collectors.toList());

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet("New Hires");
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);

            String[] headers = {"#", "Employee Code", "Full Name", "Department",
                "Position", "Join Date", "Gender", "Email"};
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
                setCell(r, 6, e.getGender() != null ? e.getGender().name() : "", data);
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
                                                  LocalDate from, LocalDate to, Long deptId) {
        List<Employee> resigned = employeeRepo.findAllByCompanyIdFetchDepartment(companyId).stream()
            .filter(e -> e.getLeaveDate() != null
                && !e.getLeaveDate().isBefore(from)
                && !e.getLeaveDate().isAfter(to))
            .filter(e -> deptId == null
                || (e.getDepartment() != null && e.getDepartment().getId().equals(deptId)))
            .sorted(Comparator.comparing(Employee::getLeaveDate))
            .collect(Collectors.toList());

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet("Resigned");
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);

            String[] headers = {"#", "Employee Code", "Full Name", "Department",
                "Position", "Join Date", "Leave Date", "Tenure (days)"};
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
                                                           int year, int month, Long deptId) {
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
            XSSFSheet sheet = wb.createSheet(String.format("Attendance %02d-%d", month, year));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);
            XSSFCellStyle moneyInt = moneyIntStyle(wb);

            String[] headers = {"#", "Employee Code", "Full Name", "Department",
                "Present", "Absent", "Late", "Half Day", "Leave",
                "Day Hours", "Night Hours", "OT Day (h)", "OT Night (h)"};
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
                                                         int year, int month, Long deptId) {
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
            XSSFSheet sheet = wb.createSheet(String.format("OT Summary %02d-%d", month, year));
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);
            XSSFCellStyle moneyInt = moneyIntStyle(wb);

            String[] headers = {"#", "Employee Code", "Full Name", "Department",
                "OT Days", "OT Day Hours", "OT Night Hours", "Total OT Hours"};
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
            XSSFSheet sheet = wb.createSheet(String.format("Payroll %02d-%d", month, year));
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
                excelI18n.resolve("excel.col.payroll.status",         locale),
            };
            writeHeader(sheet, hdr, headers);

            int row = 1;
            for (Payroll p : payrolls) {
                BigDecimal totalAllowance = sumPayrollEntries(p.getAllowanceEntries())
                    .add(bdNvl(p.getAllowance())).add(bdNvl(p.getBonus()));
                BigDecimal totalIncome = sumPayrollEntries(p.getIncomeEntries())
                    .add(bdNvl(p.getOvertimePay()));
                BigDecimal totalDeduction = bdNvl(p.getSocialInsurance())
                    .add(bdNvl(p.getHealthInsurance())).add(bdNvl(p.getUnemploymentInsurance()))
                    .add(bdNvl(p.getPersonalIncomeTax())).add(bdNvl(p.getOtherDeductions()))
                    .add(sumPayrollEntries(p.getCustomDeductions()));

                Employee e = p.getEmployee();
                Row r = sheet.createRow(row++);
                setCell(r, 0,  e.getEmployeeCode(), data);
                setCell(r, 1,  e.getFullName(), data);
                setCell(r, 2,  e.getDepartment() != null ? e.getDepartment().getName() : "", data);
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
                setCell(r, 16, p.getStatus() != null ? p.getStatus().name() : "", data);
            }

            // Totals row — chỉ sum cột tổng tiền (11-15), bỏ lương cơ bản và giờ công
            if (!payrolls.isEmpty()) {
                Row totRow = sheet.createRow(row);
                XSSFCellStyle bold = boldStyle(wb);
                for (int i = 0; i < 11; i++) setCell(totRow, i, i == 2 ? "TOTAL" : "", bold);
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
                    payrolls.stream().map(p -> bdNvl(p.getSocialInsurance())
                        .add(bdNvl(p.getHealthInsurance())).add(bdNvl(p.getUnemploymentInsurance()))
                        .add(bdNvl(p.getPersonalIncomeTax())).add(bdNvl(p.getOtherDeductions()))
                        .add(sumPayrollEntries(p.getCustomDeductions())))
                        .reduce(BigDecimal.ZERO, BigDecimal::add), money, moneyInt);
                setCellBD(totRow, 15, sum(payrolls, Payroll::getNetSalary), money, moneyInt);
            }

            autoSizeColumns(sheet, headers.length);
            sheet.createFreezePane(4, 1);

            // Dept summary sheet
            XSSFSheet sumSheet = wb.createSheet("By Dept");
            Map<String, List<Payroll>> byDept = payrolls.stream()
                .collect(Collectors.groupingBy(
                    p -> p.getEmployee().getDepartment() != null
                        ? p.getEmployee().getDepartment().getName() : "N/A"));
            writeHeader(sumSheet, hdr, new String[]{
                excelI18n.resolve("excel.col.payroll.department",  locale),
                excelI18n.resolve("excel.col.report.headcount",    locale),
                excelI18n.resolve("excel.col.payroll.gross",       locale),
                excelI18n.resolve("excel.col.payroll.net",         locale),
            });
            int sr = 1;
            for (Map.Entry<String, List<Payroll>> entry : byDept.entrySet()) {
                Row r = sumSheet.createRow(sr++);
                setCell(r, 0, entry.getKey(), data);
                setCell(r, 1, entry.getValue().size(), num);
                setCellBD(r, 2, sum(entry.getValue(), Payroll::getGrossSalary), money, moneyInt);
                setCellBD(r, 3, sum(entry.getValue(), Payroll::getNetSalary),   money, moneyInt);
            }
            autoSizeColumns(sumSheet, 4);

            byte[] bytes = toBytes(wb);
            historyHelper.save(companyId, userId, HistoryType.REPORT, "payroll_summary",
                "payroll-summary.xlsx", bytes, null, null, null);
            return ExcelUtils.buildFileResponse("payroll-summary", bytes);
        } catch (IOException e) {
            throw new RuntimeException("error.excel.export_failed", e);
        }
    }

    // ─── 7. LEAVE BALANCE SUMMARY ────────────────────────────────────────────

    public ResponseEntity<byte[]> reportLeaveBalance(Long companyId, Long userId, Long deptId) {
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
            XSSFSheet sheet = wb.createSheet("Leave Balances");
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);

            // Header: Emp Code | Name | Dept | [LeaveType1] | [LeaveType2] | ...
            String[] baseHdrs = {"#", "Employee Code", "Full Name", "Department"};
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
                                                    LocalDate from, LocalDate to, Long deptId) {
        List<LeaveRequest> requests = leaveRequestRepo
            .findByCompanyAndStatus(companyId, null).stream()
            .filter(lr -> !lr.getFromDate().isAfter(to) && !lr.getToDate().isBefore(from))
            .filter(lr -> deptId == null
                || (lr.getEmployee().getDepartment() != null
                    && lr.getEmployee().getDepartment().getId().equals(deptId)))
            .sorted(Comparator.comparing(LeaveRequest::getFromDate))
            .collect(Collectors.toList());

        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            XSSFSheet sheet = wb.createSheet("Leave Usage");
            XSSFCellStyle hdr = headerStyle(wb);
            XSSFCellStyle data = dataStyle(wb);
            XSSFCellStyle num = numStyle(wb);
            XSSFCellStyle money = moneyStyle(wb);

            String[] headers = {"#", "Employee Code", "Full Name", "Department",
                "Leave Type", "From", "To", "Days", "Status", "Reason"};
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
