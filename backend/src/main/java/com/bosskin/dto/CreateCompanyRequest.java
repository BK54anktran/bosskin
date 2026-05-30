package com.bosskin.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class CreateCompanyRequest {

    @NotBlank
    private String name;

    @NotBlank
    @Size(min = 2, max = 20)
    private String code;

    private String domain;
    private String address;
    private String phone;
    private String companyEmail;

    // Tài khoản admin đầu tiên của công ty
    @NotBlank @Email
    private String adminEmail;

    @NotBlank @Size(min = 6)
    private String adminPassword;

    private String adminFullName;
}
