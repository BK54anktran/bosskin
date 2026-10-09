package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Thông số thuế TNCN / bảo hiểm theo ngày hiệu lực (V13). Dùng chung cho mọi công ty. */
@Entity
@Table(name = "tax_policies")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class TaxPolicy extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "effective_from", nullable = false, unique = true)
    private LocalDate effectiveFrom;

    @Column(name = "personal_deduction", nullable = false, precision = 15, scale = 2)
    private BigDecimal personalDeduction;

    @Column(name = "dependent_deduction", nullable = false, precision = 15, scale = 2)
    private BigDecimal dependentDeduction;

    /** JSON: [{"upTo":10000000,"rate":0.05}, …, {"upTo":null,"rate":0.35}] — thu nhập tính thuế / tháng. */
    @Column(name = "pit_brackets", nullable = false, length = 1000)
    private String pitBrackets;

    @Column(name = "reference_wage", nullable = false, precision = 15, scale = 2)
    private BigDecimal referenceWage;

    @Column(name = "insurance_cap_multiplier", nullable = false)
    private int insuranceCapMultiplier;

    @Column(name = "unemployment_cap_multiplier", nullable = false)
    private int unemploymentCapMultiplier;

    @Column(name = "min_wage_region1", nullable = false, precision = 15, scale = 2)
    private BigDecimal minWageRegion1;

    @Column(name = "min_wage_region2", nullable = false, precision = 15, scale = 2)
    private BigDecimal minWageRegion2;

    @Column(name = "min_wage_region3", nullable = false, precision = 15, scale = 2)
    private BigDecimal minWageRegion3;

    @Column(name = "min_wage_region4", nullable = false, precision = 15, scale = 2)
    private BigDecimal minWageRegion4;

    @Column(name = "note", length = 500)
    private String note;

    @Column(name = "updated_by", length = 150)
    private String updatedBy;

    public BigDecimal minWageOfRegion(int region) {
        return switch (region) {
            case 2 -> minWageRegion2;
            case 3 -> minWageRegion3;
            case 4 -> minWageRegion4;
            default -> minWageRegion1;
        };
    }
}
