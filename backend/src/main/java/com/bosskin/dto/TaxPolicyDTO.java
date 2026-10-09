package com.bosskin.dto;

import com.bosskin.entity.TaxPolicy;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public class TaxPolicyDTO {

    /** Một bậc thuế: thu nhập tính thuế / tháng đến {@code upTo} (null = phần còn lại), thuế suất {@code rate} (0–1). */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Bracket {
        private BigDecimal upTo;
        @NotNull private BigDecimal rate;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private LocalDate effectiveFrom;
        private BigDecimal personalDeduction;
        private BigDecimal dependentDeduction;
        private List<Bracket> brackets;
        private BigDecimal referenceWage;
        private int insuranceCapMultiplier;
        private int unemploymentCapMultiplier;
        private BigDecimal insuranceCap;
        private List<BigDecimal> minWages;
        private String note;
        private String updatedBy;
        private LocalDateTime updatedAt;
        /** Chính sách đang áp dụng cho hôm nay. */
        private boolean current;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotNull private LocalDate effectiveFrom;
        @NotNull private BigDecimal personalDeduction;
        @NotNull private BigDecimal dependentDeduction;
        @NotEmpty @Valid private List<Bracket> brackets;
        @NotNull private BigDecimal referenceWage;
        @NotNull private Integer insuranceCapMultiplier;
        @NotNull private Integer unemploymentCapMultiplier;
        /** Lương tối thiểu vùng I–IV, đúng 4 phần tử. */
        @NotNull private List<BigDecimal> minWages;
        private String note;
    }

    public static Response of(TaxPolicy p, List<Bracket> brackets, boolean current) {
        return Response.builder()
            .id(p.getId()).effectiveFrom(p.getEffectiveFrom())
            .personalDeduction(p.getPersonalDeduction()).dependentDeduction(p.getDependentDeduction())
            .brackets(brackets).referenceWage(p.getReferenceWage())
            .insuranceCapMultiplier(p.getInsuranceCapMultiplier())
            .unemploymentCapMultiplier(p.getUnemploymentCapMultiplier())
            .insuranceCap(p.getReferenceWage().multiply(BigDecimal.valueOf(p.getInsuranceCapMultiplier())))
            .minWages(List.of(p.getMinWageRegion1(), p.getMinWageRegion2(), p.getMinWageRegion3(), p.getMinWageRegion4()))
            .note(p.getNote()).updatedBy(p.getUpdatedBy()).updatedAt(p.getUpdatedAt())
            .current(current)
            .build();
    }
}
