package com.bosskin.dto;

import jakarta.validation.constraints.Size;
import lombok.*;

import java.util.List;

/** Bước K — đơn của cấp dưới trực tiếp chờ quản lý duyệt (chế độ MANAGER_THEN_HR). */
public class TeamApprovalDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        /** Công ty có bật chế độ quản lý trực tiếp duyệt trước không. */
        private boolean enabled;
        /** Số cấp dưới trực tiếp đang làm. */
        private int reportCount;
        private List<LeaveDTO.LeaveRequestResponse> leaves;
        private List<AttendanceRequestDTO.Response> attendances;
        private List<ShiftSwapDTO.Response> swaps;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Count {
        private boolean enabled;
        private int reportCount;
        private long count;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ProcessRequest {
        @Size(max = 500)
        private String note;
    }
}
