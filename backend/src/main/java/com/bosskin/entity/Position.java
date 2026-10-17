package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.Where;

@Entity
@Table(name = "positions")
@SQLDelete(sql = "UPDATE positions SET deleted = true WHERE id = ?")
@Where(clause = "deleted = false")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Position extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "code", nullable = false, length = 20)
    private String code;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "company_id", nullable = false)
    private Company company;

    /** NULL = chức vụ chung của công ty (dùng ở mọi phòng ban). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    private Department department;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    public boolean isCommon() { return department == null; }

    /** Dùng được ở phòng ban này: chức vụ chung hoặc đúng phòng ban của chức vụ. */
    public boolean usableIn(Long departmentId) {
        return department == null || (departmentId != null && department.getId().equals(departmentId));
    }
}
