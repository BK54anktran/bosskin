package com.bosskin.service;

import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.Position;
import com.bosskin.repository.PayrollRepository;
import org.apache.poi.ss.util.PaneInformation;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PayrollExcelServiceTest {

    @Mock private PayrollRepository payrollRepository;
    @Mock private DeptScopeService deptScopeService;

    @InjectMocks private PayrollExcelService service;

    @Test
    void export_createsExpectedSheetAndHeaders() throws Exception {
        Payroll payroll = buildPayroll();
        when(deptScopeService.resolvedScopes(99L, "PAYROLL_VIEW")).thenReturn(Set.of());
        when(payrollRepository.findExportByMonth(10L, 2026, 5)).thenReturn(List.of(payroll));

        var response = service.export(10L, 99L, 2026, 5);

        assertNotNull(response.getBody());
        assertTrue(response.getHeaders().getFirst("Content-Disposition").contains("luong_thang_05-2026"));

        try (Workbook workbook = WorkbookFactory.create(new ByteArrayInputStream(response.getBody()))) {
            Sheet sheet = workbook.getSheet("Luong Thang 05-2026");
            assertNotNull(sheet);

            PaneInformation pane = sheet.getPaneInformation();
            assertNotNull(pane);
            assertTrue(pane.isFreezePane());
            assertEquals(3, pane.getHorizontalSplitPosition());
            assertEquals(0, pane.getVerticalSplitPosition());

            Row header = sheet.getRow(0);
            assertEquals("Ma NV", header.getCell(0).getStringCellValue());
            assertEquals("Ho ten", header.getCell(1).getStringCellValue());
            assertEquals("Phong ban", header.getCell(2).getStringCellValue());
            assertEquals("Chuc vu", header.getCell(3).getStringCellValue());
            assertEquals("Luong co ban", header.getCell(4).getStringCellValue());
            assertEquals("Trang thai", header.getCell(13).getStringCellValue());
        }
    }

    private Payroll buildPayroll() {
        Company company = Company.builder()
            .id(10L)
            .name("BossKin")
            .code("BK")
            .build();

        Department department = Department.builder()
            .id(20L)
            .company(company)
            .name("Nhan su")
            .code("NS")
            .build();

        Position position = Position.builder()
            .id(30L)
            .department(department)
            .name("Truong phong")
            .code("TP")
            .build();

        Employee employee = Employee.builder()
            .id(40L)
            .company(company)
            .employeeCode("NV001")
            .fullName("Nguyen Van A")
            .email("nv1@example.com")
            .gender(Employee.Gender.MALE)
            .joinDate(LocalDate.of(2024, 1, 1))
            .department(department)
            .position(position)
            .build();

        return Payroll.builder()
            .id(50L)
            .employee(employee)
            .year(2026)
            .month(5)
            .baseSalary(new BigDecimal("10000000"))
            .allowance(new BigDecimal("500000"))
            .bonus(new BigDecimal("250000"))
            .overtimePay(new BigDecimal("125000"))
            .grossSalary(new BigDecimal("10875000"))
            .socialInsurance(new BigDecimal("800000"))
            .healthInsurance(new BigDecimal("150000"))
            .unemploymentInsurance(new BigDecimal("100000"))
            .personalIncomeTax(new BigDecimal("500000"))
            .otherDeductions(BigDecimal.ZERO)
            .netSalary(new BigDecimal("9325000"))
            .presentDays(22)
            .totalOvertimeHours(new BigDecimal("12.5"))
            .status(Payroll.Status.APPROVED)
            .build();
    }
}
