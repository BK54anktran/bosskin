package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/** Bước J: lịch làm việc tuần (F cả ngày, H nửa ngày, O nghỉ — 7 ký tự T2→CN). */
public class WorkCalendarDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        /** null = lịch mặc định chưa lưu (dùng FFFFFOO). */
        private Long id;
        private String name;
        private String weekPattern;
        @com.fasterxml.jackson.annotation.JsonProperty("isDefault")
        private boolean isDefault;
        /** Phòng ban gán trực tiếp lịch này (lịch mặc định: rỗng — áp cho phòng chưa gán). */
        private List<Long> departmentIds;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotBlank @Size(max = 100) private String name;
        @NotNull @Pattern(regexp = "[FHO]{7}", message = "error.work_calendar.pattern_invalid")
        private String weekPattern;
        private List<Long> departmentIds;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class DefaultUpsert {
        @NotNull @Pattern(regexp = "[FHO]{7}", message = "error.work_calendar.pattern_invalid")
        private String weekPattern;
    }

    /** Lịch đã giải cho khoảng ngày — lưới phân ca / bảng công tô màu ngày nghỉ, ngày lễ. */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class View {
        private LocalDate from;
        private LocalDate to;
        private List<HolidayDTO.Response> holidays;
        private String defaultPattern;
        /** departmentId → week pattern đã tính kế thừa phòng cha. */
        private Map<Long, String> departmentPatterns;
    }

    /** Phòng ban cho ô chọn gán lịch. */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class DepartmentOption {
        private Long id;
        private String name;
        private int level;
    }
}
