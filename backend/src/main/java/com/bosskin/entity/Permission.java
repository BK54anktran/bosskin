package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "permissions")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Permission {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "code", nullable = false, unique = true, length = 50)
    private String code;

    @Column(name = "description", nullable = false, length = 200)
    private String description;

    @Column(name = "module", nullable = false, length = 50)
    private String module;

    @Column(name = "required_rule", length = 50)
    private String requiredRule;
}
