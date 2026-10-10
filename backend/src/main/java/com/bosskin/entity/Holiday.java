package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

/**
 * Ngày lễ / nghỉ bù / làm bù (V14). {@code companyId} null = mẫu hệ thống.
 * Ngày nghỉ hoán đổi nhập là HOLIDAY với {@code paid = false}.
 */
@Entity
@Table(name = "holidays")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Holiday extends BaseEntity {

    public enum Type { HOLIDAY, COMPENSATORY, SWAP_WORKDAY }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id")
    private Long companyId;

    @Column(name = "holiday_date", nullable = false)
    private LocalDate date;

    @Column(nullable = false, length = 150)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private Type type = Type.HOLIDAY;

    @Column(nullable = false)
    @Builder.Default
    private boolean paid = true;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;

    /** Ngày nghỉ (lễ, nghỉ bù, nghỉ hoán đổi) — không phải ngày làm bù. */
    public boolean isDayOff() {
        return type != Type.SWAP_WORKDAY;
    }
}
