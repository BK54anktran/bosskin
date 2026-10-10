package com.bosskin.service;

import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Position;
import com.bosskin.entity.User;
import com.bosskin.repository.AttendanceRequestRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@org.mockito.junit.jupiter.MockitoSettings(strictness = org.mockito.quality.Strictness.LENIENT)
class AttendanceRequestServiceTest {

    @Mock private AttendanceRequestRepository requestRepository;
    @Mock private EmployeeRepository employeeRepository;
    @Mock private ShiftAssignmentRepository shiftAssignmentRepository;
    @Mock private PeriodLockService periodLockService;
    @Mock private ManagerApprovalService managerApproval;

    @InjectMocks private AttendanceRequestService service;

    @Test
    void approveRequest_deniesWhenUserDoesNotHaveApprovePermission() {
        User user = User.builder()
                .id(1L)
                .email("staff@example.com")
                .company(Company.builder().id(10L).name("Bosskin").code("CAD").build())
                .build();

        ResponseStatusException ex = assertThrows(
                ResponseStatusException.class,
                () -> service.approveRequest(99L, user, null)
        );

        assertEquals(403, ex.getStatusCode().value());
        verify(requestRepository, never()).findByIdAndCompanyId(99L, 10L);
    }

    @Test
    void createRequest_allowsMultipleRequestsOnSameDay() {
        User user = buildUser(1L);
        Employee employee = buildEmployee(10L);

        when(employeeRepository.findByUserIdFetch(1L)).thenReturn(Optional.of(employee));
        org.mockito.Mockito.lenient().when(shiftAssignmentRepository.findByEmployeeIdAndWorkDateWithShift(10L, LocalDate.of(2026, 5, 24)))
                .thenReturn(java.util.List.of());
        when(requestRepository.save(org.mockito.ArgumentMatchers.any(AttendanceRequest.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        var response = service.createRequest(
                user,
                new com.bosskin.dto.AttendanceRequestDTO.CreateRequest(
                        LocalDate.of(2026, 5, 24),
                        AttendanceRequest.Type.CHECK_IN,
                        java.time.LocalTime.of(8, 0),
                        null,
                        null,
                        null,
                        null,
                        null,
                        "Đơn 1"
                )
        );

        assertNotNull(response);
    }

    private User buildUser(Long id) {
        Company company = Company.builder()
                .id(10L)
                .name("Bosskin")
                .code("CAD")
                .build();
        return User.builder()
                .id(id)
                .email("staff@example.com")
                .company(company)
                .build();
    }

    private Employee buildEmployee(Long id) {
        Company company = Company.builder()
                .id(10L)
                .name("Bosskin")
                .code("CAD")
                .build();
        Department department = Department.builder()
                .id(20L)
                .company(company)
                .name("Ban Giam Doc")
                .code("BGD")
                .build();
        Position position = Position.builder()
                .id(30L)
                .department(department)
                .name("Tro ly")
                .code("TL")
                .build();

        return Employee.builder()
                .id(id)
                .company(company)
                .employeeCode("EMP001")
                .fullName("Staff One")
                .email("employee@example.com")
                .gender(Employee.Gender.MALE)
                .joinDate(LocalDate.of(2024, 1, 1))
                .department(department)
                .position(position)
                .build();
    }
}
