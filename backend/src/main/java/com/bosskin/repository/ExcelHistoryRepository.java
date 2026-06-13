package com.bosskin.repository;

import com.bosskin.entity.ExcelHistory;
import com.bosskin.entity.ExcelHistory.HistoryType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
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

    @Query("""
        SELECT h, COALESCE(e.fullName, u.email, 'System')
        FROM ExcelHistory h
        LEFT JOIN User u ON u.id = h.userId
        LEFT JOIN Employee e ON e.id = u.employeeId
        WHERE h.companyId = :companyId
          AND (:type IS NULL OR h.type = :type)
          AND (:module IS NULL OR h.module = :module OR h.module LIKE CONCAT('%', :module, '%'))
          AND (:dateFrom IS NULL OR CAST(h.createdAt AS localdate) >= :dateFrom)
          AND (:dateTo   IS NULL OR CAST(h.createdAt AS localdate) <= :dateTo)
        ORDER BY h.createdAt DESC
        """)
    Page<Object[]> findWithFilters(
        @Param("companyId") Long companyId,
        @Param("type")      HistoryType type,
        @Param("module")    String module,
        @Param("dateFrom")  LocalDate dateFrom,
        @Param("dateTo")    LocalDate dateTo,
        Pageable pageable);
}
