package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
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

        @NotNull
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
    }
}
