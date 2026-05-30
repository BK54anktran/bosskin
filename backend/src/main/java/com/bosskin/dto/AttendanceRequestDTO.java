package com.bosskin.dto;

import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.User;
import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.Size;
import lombok.*;
import org.hibernate.Hibernate;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

public class AttendanceRequestDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class CreateRequest {
        private LocalDate requestDate;
        private AttendanceRequest.Type requestType;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckIn;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckOut;
        private Integer requestedOvertimeMinutes;
        private AttendanceRequest.OvertimeScope requestedOvertimeScope;
        private AttendanceRequest.OvertimePeriod requestedOvertimePeriod;
        private Long shiftAssignmentId;
        @Size(max = 1000)
        private String note;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private Long departmentId;
        private String departmentName;
        private LocalDate requestDate;
        private AttendanceRequest.Type requestType;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckIn;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime requestedCheckOut;
        private Integer requestedOvertimeMinutes;
        private AttendanceRequest.OvertimeScope requestedOvertimeScope;
        private AttendanceRequest.OvertimePeriod requestedOvertimePeriod;
        private Long shiftAssignmentId;
        private String shiftName;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftStart;
        @JsonFormat(pattern = "HH:mm")
        private LocalTime shiftEnd;
        private boolean applied;
        private String note;
        private AttendanceRequest.Status status;
        private String adminNote;
        private String processedByName;
        private LocalDateTime createdAt;
        private LocalDateTime processedAt;
        private LocalDateTime updatedAt;

        public static Response from(com.bosskin.entity.AttendanceRequest r) {
            var employee = r.getEmployee();
            var department = employee != null ? employee.getDepartment() : null;
            return Response.builder()
                .id(r.getId())
                .employeeId(employee != null ? employee.getId() : null)
                .employeeCode(employee != null ? employee.getEmployeeCode() : null)
                .employeeName(employee != null ? employee.getFullName() : null)
                .departmentId(department != null ? department.getId() : null)
                .departmentName(department != null ? department.getName() : null)
                .requestDate(r.getRequestDate())
                .requestType(r.getRequestType())
                .requestedCheckIn(r.getRequestedCheckIn())
                .requestedCheckOut(r.getRequestedCheckOut())
                .requestedOvertimeMinutes(r.getRequestedOvertimeMinutes())
                .requestedOvertimeScope(r.getRequestedOvertimeScope())
                .requestedOvertimePeriod(r.getRequestedOvertimePeriod())
                .shiftAssignmentId(r.getShiftAssignment() != null ? r.getShiftAssignment().getId() : null)
                .shiftName(r.getShiftAssignment() != null && r.getShiftAssignment().getShift() != null
                    ? r.getShiftAssignment().getShift().getName()
                    : r.getShiftAssignment() != null ? "Tùy chỉnh" : null)
                .shiftStart(r.getShiftAssignment() != null
                    ? (r.getShiftAssignment().getCustomStartTime() != null
                        ? r.getShiftAssignment().getCustomStartTime()
                        : r.getShiftAssignment().getShift() != null
                            ? r.getShiftAssignment().getShift().getStartTime()
                            : null)
                    : null)
                .shiftEnd(r.getShiftAssignment() != null
                    ? (r.getShiftAssignment().getCustomEndTime() != null
                        ? r.getShiftAssignment().getCustomEndTime()
                        : r.getShiftAssignment().getShift() != null
                            ? r.getShiftAssignment().getShift().getEndTime()
                            : null)
                    : null)
                .applied(r.isApplied())
                .note(r.getNote())
                .status(r.getStatus())
                .adminNote(r.getAdminNote())
                .processedByName(resolveProcessedByName(r.getProcessedBy()))
                .createdAt(r.getCreatedAt())
                .processedAt(r.getProcessedAt())
                .updatedAt(r.getUpdatedAt())
                .build();
        }

        private static String resolveProcessedByName(User processedBy) {
            if (processedBy == null) {
                return null;
            }
            try {
                if (processedBy.getEmployee() != null && Hibernate.isInitialized(processedBy.getEmployee())) {
                    String fullName = processedBy.getEmployee().getFullName();
                    if (fullName != null && !fullName.isBlank()) {
                        return fullName;
                    }
                }
            } catch (Exception ignored) {
                // Fallback to email below
            }
            return processedBy.getEmail();
        }
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ProcessRequest {
        @Size(max = 1000)
        private String adminNote;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ToggleAppliedRequest {
        private boolean applied;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class PendingCount {
        private long count;
    }
}
