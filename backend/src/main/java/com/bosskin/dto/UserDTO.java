package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

public class UserDTO {

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SyncEmployeesRequest {
        @NotBlank
        @Size(min = 6, max = 100)
        private String initialPassword;
    }

    @Getter
    @Setter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SyncEmployeesResponse {
        private int createdCount;
        private int linkedCount;
        private int skippedCount;
        private int totalEmployees;
    }
}
