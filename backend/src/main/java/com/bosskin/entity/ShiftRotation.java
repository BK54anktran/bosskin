package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

/**
 * Mẫu ca xoay vòng (Mốc 2b): chu kỳ N ngày, mỗi ngày là danh sách ca (rỗng = nghỉ).
 * Lưu dạng chuỗi: các ngày cách nhau dấu phẩy, nhiều ca trong ngày nối bằng "+", "0" = nghỉ.
 * Ví dụ 2 sáng – 2 chiều – 2 đêm – 2 nghỉ: "1,1,2,2,3,3,0,0".
 */
@Entity
@Table(name = "shift_rotations")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ShiftRotation extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, length = 2000)
    private String pattern;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    public List<List<Long>> days() {
        List<List<Long>> out = new ArrayList<>();
        if (pattern == null || pattern.isBlank()) return out;
        for (String day : pattern.split(",")) {
            List<Long> ids = new ArrayList<>();
            for (String p : day.trim().split("\\+")) {
                if (p.isBlank()) continue;
                long id = Long.parseLong(p.trim());
                if (id > 0) ids.add(id);
            }
            out.add(ids);
        }
        return out;
    }

    public static String encode(List<List<Long>> days) {
        StringBuilder sb = new StringBuilder();
        for (List<Long> d : days) {
            if (!sb.isEmpty()) sb.append(',');
            if (d == null || d.isEmpty()) sb.append('0');
            else sb.append(String.join("+", d.stream().map(String::valueOf).toList()));
        }
        return sb.toString();
    }
}
