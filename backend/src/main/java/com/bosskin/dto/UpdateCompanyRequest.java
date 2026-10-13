package com.bosskin.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * System admin sửa thông tin công ty. Mã công ty không đổi được: gửi {@code code} khác mã hiện tại
 * → 400 error.company.code_immutable (gửi đúng mã cũ hoặc bỏ trống thì bỏ qua).
 */
@Getter @Setter
public class UpdateCompanyRequest {
    private String name;
    private String code;
    private String domain;
    private String address;
    private String phone;
    private String companyEmail;
}
