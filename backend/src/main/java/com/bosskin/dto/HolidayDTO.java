package com.bosskin.dto;

import com.bosskin.entity.Holiday;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDate;
import java.util.List;

/** Bước J: ngày lễ / nghỉ bù / làm bù. */
public class HolidayDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        private Long id;
        private LocalDate date;
        private String name;
        private Holiday.Type type;
        private boolean paid;
        /** TEMPLATE = đang dùng mẫu hệ thống, COMPANY = công ty tự chỉnh. */
        private String source;

        public static Response of(Holiday h) {
            return Response.builder().id(h.getId()).date(h.getDate()).name(h.getName())
                .type(h.getType()).paid(h.isPaid())
                .source(h.getCompanyId() == null ? "TEMPLATE" : "COMPANY").build();
        }
    }

    /** Danh sách ngày lễ một năm của công ty. */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class YearView {
        private int year;
        /** true = công ty đã chỉnh năm này (không còn theo mẫu). */
        private boolean customized;
        private List<Response> items;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotNull private LocalDate date;
        @NotBlank @Size(max = 150) private String name;
        @NotNull private Holiday.Type type;
        private boolean paid = true;
    }

    // ── Excel ────────────────────────────────────────────────────────────────

    @Data @NoArgsConstructor
    public static class ImportRow {
        private String date;
        private String name;
        private String type;
        private String paid;
        private String delete;

        public boolean isMarkedDelete() {
            if (delete == null) return false;
            String v = delete.trim().toLowerCase();
            return v.equals("x") || v.equals("delete") || v.equals("1") || v.equals("true");
        }
    }

    @Data @Builder
    public static class ImportDiff {
        /** "CREATE" | "UPDATE" | "NO_CHANGE" | "DELETE" */
        private String action;
        /** Ngày yyyy-MM-dd — khoá định danh dòng. */
        private String code;
        private String name;
        private List<DepartmentDTO.FieldChange> changes;
        private List<String> warnings;
    }
}
