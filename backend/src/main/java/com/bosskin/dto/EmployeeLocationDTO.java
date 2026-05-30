package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

public class EmployeeLocationDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        private Long id;
        private String name;
        private Double latitude;
        private Double longitude;
        private int radiusMeters;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotBlank private String name;
        @NotNull  private Double latitude;
        @NotNull  private Double longitude;
        private int radiusMeters = 100;
    }
}
