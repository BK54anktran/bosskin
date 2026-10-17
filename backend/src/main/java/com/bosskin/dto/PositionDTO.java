package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Data;

public class PositionDTO {

    @Data
    public static class CreateRequest {
        @NotBlank @Size(max = 100)
        private String name;

        @NotBlank @Size(max = 20)
        private String code;

        /** Bỏ trống = chức vụ chung của công ty (dùng ở mọi phòng ban). */
        private Long departmentId;

        private String description;
    }

    @Data
    @Builder
    public static class Response {
        private Long id;
        private String name;
        private String code;
        private Long departmentId;
        private String departmentName;
        private String description;
        /** true = chức vụ chung (không thuộc phòng ban nào). */
        private boolean common;
    }

    @Data
    @Builder
    public static class FlatItem {
        private Long id;
        private String code;
        private String name;
        private String description;
        private String departmentCode;
        private String departmentName;
        private long employeeCount;
    }

    @Data
    public static class ImportRow {
        private String code;
        private String name;
        private String departmentCode;
        private String departmentName;
        private String description;
        private String delete;

        public boolean isMarkedDelete() {
            if (delete == null) return false;
            String v = delete.trim().toLowerCase();
            return v.equals("x") || v.equals("delete") || v.equals("1") || v.equals("true");
        }
    }

    @Data
    @Builder
    public static class ImportDiff {
        /** "CREATE" | "UPDATE" | "NO_CHANGE" | "DELETE" */
        private String action;
        private String code;
        private String name;
        private String departmentCode;
        private String description;
        private java.util.List<com.bosskin.dto.DepartmentDTO.FieldChange> changes;
        private java.util.List<String> warnings;
    }
}
