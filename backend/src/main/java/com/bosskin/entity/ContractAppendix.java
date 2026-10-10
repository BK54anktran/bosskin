package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Phụ lục hợp đồng (V16): trường null = giữ giá trị trước đó; overridesAllowances = thay cả bộ phụ cấp. */
@Entity
@Table(name = "contract_appendices")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ContractAppendix extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "contract_id", nullable = false)
    private Long contractId;

    @Column(name = "appendix_no", nullable = false, length = 50)
    private String appendixNo;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "base_salary", precision = 15, scale = 2)
    private BigDecimal baseSalary;

    @Column(name = "insurance_salary", precision = 15, scale = 2)
    private BigDecimal insuranceSalary;

    @Column(name = "position_title", length = 150)
    private String positionTitle;

    @Column(name = "overrides_allowances", nullable = false)
    @Builder.Default
    private boolean overridesAllowances = false;

    @Column(length = 1000)
    private String note;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
