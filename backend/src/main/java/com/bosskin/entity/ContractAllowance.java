package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/** Phụ cấp theo hợp đồng (appendixId null) hoặc theo phụ lục (V16). {@code code} → biến lương ALLOWANCE_<code>. */
@Entity
@Table(name = "contract_allowances")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ContractAllowance extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "contract_id", nullable = false)
    private Long contractId;

    @Column(name = "appendix_id")
    private Long appendixId;

    @Column(nullable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false)
    @Builder.Default
    private boolean insurable = false;

    @Column(nullable = false)
    @Builder.Default
    private boolean taxable = true;
}
