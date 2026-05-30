package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "formula_variables")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FormulaVariable extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "company_id", nullable = false)
    private Company company;

    @Column(name = "name", nullable = false, length = 50)
    private String name;

    @Column(name = "label", nullable = false, length = 100)
    private String label;

    @Column(name = "expression", nullable = false, columnDefinition = "TEXT")
    private String expression;

    @Column(name = "show_in_formula", nullable = false)
    @Builder.Default
    private boolean showInFormula = true;

    @Column(name = "category", length = 50)
    private String category;
}
