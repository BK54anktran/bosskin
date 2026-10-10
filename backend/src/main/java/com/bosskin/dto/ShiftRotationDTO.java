package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;
import java.util.List;

public class ShiftRotationDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotBlank private String name;
        /** Mỗi phần tử là một ngày trong chu kỳ: danh sách id ca (rỗng = nghỉ). */
        @NotEmpty private List<List<Long>> days;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        private Long id;
        private String name;
        private List<List<Long>> days;
        /** Mã ca tương ứng từng ngày, "" = nghỉ — để hiển thị nhanh */
        private List<String> dayCodes;
        private int cycleLength;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class GenerateRequest {
        @NotEmpty private List<Long> employeeIds;
        @NotNull private LocalDate from;
        @NotNull private LocalDate to;
        /** Vị trí trong chu kỳ ứng với ngày `from` của người đầu tiên (0 = ngày đầu chu kỳ). */
        private int startOffset;
        /** Mỗi người sau lệch thêm bao nhiêu ngày so với người trước (để các tổ xoay so le). */
        private int staggerPerEmployee;
        /** Bước J: ngày lễ / nghỉ bù để trống ca (chu kỳ vẫn chạy tiếp). */
        private boolean skipHolidays;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class GenerateResult {
        private int assignedDays;
        private int clearedDays;
        private int unchangedDays;
        private List<Conflict> conflicts;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Conflict {
        private Long employeeId;
        private String employeeName;
        private LocalDate date;
        private String reason;
    }
}
