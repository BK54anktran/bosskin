package com.bosskin.repository;

import com.bosskin.entity.Holiday;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface HolidayRepository extends JpaRepository<Holiday, Long> {

    /** companyId null → mẫu hệ thống. */
    @Query("SELECT h FROM Holiday h WHERE h.deleted = false AND "
        + "((:companyId IS NULL AND h.companyId IS NULL) OR h.companyId = :companyId) "
        + "AND h.date BETWEEN :from AND :to ORDER BY h.date")
    List<Holiday> findActive(@Param("companyId") Long companyId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /** Các năm công ty đã tự chỉnh (kể cả dòng đã xoá — xoá hết vẫn là đã chỉnh). */
    @Query("SELECT DISTINCT YEAR(h.date) FROM Holiday h WHERE h.companyId = :companyId "
        + "AND h.date BETWEEN :from AND :to")
    List<Integer> findCustomizedYears(@Param("companyId") Long companyId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT h FROM Holiday h WHERE h.deleted = false AND "
        + "((:companyId IS NULL AND h.companyId IS NULL) OR h.companyId = :companyId) AND h.date = :date")
    Optional<Holiday> findActiveOn(@Param("companyId") Long companyId, @Param("date") LocalDate date);

    @Query("SELECT DISTINCT YEAR(h.date) FROM Holiday h WHERE h.deleted = false AND h.companyId IS NULL ORDER BY 1")
    List<Integer> findTemplateYears();
}
