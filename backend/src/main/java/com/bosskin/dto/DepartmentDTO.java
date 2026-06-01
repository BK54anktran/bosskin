package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Data;

import java.util.List;

public class DepartmentDTO {

    @Data
    public static class CreateRequest {
        @NotBlank
        @Size(max = 100)
        private String name;

        @NotBlank
        @Size(max = 20)
        private String code;

        private String description;
        private Long parentId;
        private Long managerId;
        private Double checkInLatitude;
        private Double checkInLongitude;
        private Integer checkInRadiusMeters;
        private Integer checkInToleranceMinutes;
        private Integer checkOutToleranceMinutes;
        private Integer roundingCheckInMinutes;
        private Integer roundingCheckOutMinutes;
        private Integer roundingWorkMinutes;
    }

    @Data
    @Builder
    public static class Response {
        private Long id;
        private String name;
        private String code;
        private String description;
        private Long parentId;
        private String parentName;
        private int level;
        private int employeeCount;
        private Long managerId;
        private String managerName;
        private List<Response> children;
        private Double checkInLatitude;
        private Double checkInLongitude;
        private int checkInRadiusMeters;
        private Integer checkInToleranceMinutes;
        private Integer checkOutToleranceMinutes;
        private Integer roundingCheckInMinutes;
        private Integer roundingCheckOutMinutes;
        private Integer roundingWorkMinutes;
    }

    @Data
    @Builder
    public static class FlatItem {
        private Long id;
        private String name;
        private String code;
        private String description;
        private Long parentId;
        private String parentName;
        private String parentCode;
        private int level;
        private int employeeCount;
        private Double checkInLatitude;
        private Double checkInLongitude;
        private Integer checkInRadiusMeters;
    }

    @Data
    public static class ImportRow {
        private String code;
        private String name;
        private String parentCode;
        private String description;
        private String checkInLatitude;
        private String checkInLongitude;
        private String checkInRadiusMeters;
        /** "x", "X", "1", "true" → xóa phòng ban này */
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
        private String parentCode;
        private String description;
        private String latitude;
        private String longitude;
        private String radiusMeters;
        private java.util.List<FieldChange> changes;
        /** Cảnh báo liên đới khi xóa (nhân viên, chức vụ, phòng con) */
        private java.util.List<String> warnings;
    }

    @Data
    @Builder
    public static class FieldChange {
        private String field;
        private String oldValue;
        private String newValue;
    }
}
