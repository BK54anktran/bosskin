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
    }

    @Data
    @Builder
    public static class FlatItem {
        private Long id;
        private String name;
        private String code;
        private Long parentId;
        private int level;
        private int employeeCount;
    }
}
