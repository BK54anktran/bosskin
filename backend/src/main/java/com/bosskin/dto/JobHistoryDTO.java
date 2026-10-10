package com.bosskin.dto;

import com.bosskin.entity.EmployeeJobHistory;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/** Bước K — quá trình công tác và sơ đồ tổ chức. */
public class JobHistoryDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        private Long id;
        private LocalDate effectiveFrom;
        private EmployeeJobHistory.ChangeType changeType;
        private Long departmentId;
        private String departmentName;
        private Long positionId;
        private String positionName;
        private Long salaryGradeId;
        private String salaryGradeCode;
        private String salaryGradeName;
        private Long managerId;
        private String managerName;
        private String note;
        /** Đã tới ngày và áp vào hồ sơ. */
        private boolean applied;
        /** Bản đang hiệu lực hôm nay. */
        private boolean current;
        private String createdByName;
        private LocalDateTime createdAt;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotNull private LocalDate effectiveFrom;
        @NotNull private EmployeeJobHistory.ChangeType changeType;
        @NotNull private Long departmentId;
        private Long positionId;
        private Long salaryGradeId;
        private Long managerId;
        @Size(max = 500) private String note;
    }

    /** Một nút sơ đồ tổ chức: FE dựng cây theo managerId (theo người) hoặc departmentId (theo phòng ban). */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class OrgNode {
        private Long id;
        private String employeeCode;
        private String fullName;
        private String avatar;
        private Long departmentId;
        private String departmentName;
        private String positionName;
        private Long managerId;
        /** Trưởng phòng (departments.manager_id). */
        private boolean departmentHead;
    }
}
