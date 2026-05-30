package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "employee_locations")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeLocation {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "latitude", nullable = false)
    private Double latitude;

    @Column(name = "longitude", nullable = false)
    private Double longitude;

    @Column(name = "radius_meters", nullable = false)
    @Builder.Default
    private int radiusMeters = 100;
}
