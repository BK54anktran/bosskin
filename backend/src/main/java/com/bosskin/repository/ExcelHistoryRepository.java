package com.bosskin.repository;

import com.bosskin.entity.ExcelHistory;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ExcelHistoryRepository extends JpaRepository<ExcelHistory, Long> {

    @Query("""
        SELECT h, COALESCE(e.fullName, u.email, 'System')
        FROM ExcelHistory h
        LEFT JOIN User u ON u.id = h.userId
        LEFT JOIN Employee e ON e.id = u.employeeId
        WHERE h.companyId = :companyId
        ORDER BY h.createdAt DESC
        """)
    List<Object[]> findWithPerformerByCompanyId(@Param("companyId") Long companyId, Pageable pageable);
}
