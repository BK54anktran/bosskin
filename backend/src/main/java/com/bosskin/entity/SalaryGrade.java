package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;

@Entity
@Table(name = "salary_grades")
@SQLDelete(sql = "UPDATE salary_grades SET deleted = true WHERE id = ?")
@SQLRestriction("deleted = false")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalaryGrade extends BaseEntity {

    public enum PayType { DAILY, HOURLY }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    private Department department;

    @Column(name = "code", nullable = false, length = 20)
    private String code;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "pay_type", nullable = false)
    @Builder.Default
    private PayType payType = PayType.DAILY;

    @Column(name = "base_rate", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseRate;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
