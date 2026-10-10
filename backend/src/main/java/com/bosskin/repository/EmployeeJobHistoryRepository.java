package com.bosskin.repository;

import com.bosskin.entity.EmployeeJobHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface EmployeeJobHistoryRepository extends JpaRepository<EmployeeJobHistory, Long> {

    /** Toàn bộ quá trình của một nhân viên, mới nhất trước. */
    @Query("SELECT h FROM EmployeeJobHistory h WHERE h.employee.id = :employeeId AND h.deleted = false "
        + "ORDER BY h.effectiveFrom DESC, h.id DESC")
    List<EmployeeJobHistory> findByEmployee(@Param("employeeId") Long employeeId);

    /** Các dòng hiệu lực tới ngày {@code date}, mới nhất trước (dòng đầu = bản hiệu lực). */
    @Query("SELECT h FROM EmployeeJobHistory h WHERE h.employee.id = :employeeId AND h.deleted = false "
        + "AND h.effectiveFrom <= :date ORDER BY h.effectiveFrom DESC, h.id DESC")
    List<EmployeeJobHistory> findEffective(@Param("employeeId") Long employeeId, @Param("date") LocalDate date);

    default Optional<EmployeeJobHistory> effectiveOn(Long employeeId, LocalDate date) {
        return findEffective(employeeId, date).stream().findFirst();
    }

    Optional<EmployeeJobHistory> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);

    /** Nhân viên có dòng đã tới ngày mà chưa áp dụng (lịch chạy mỗi sáng). */
    @Query("SELECT DISTINCT h.employee.id FROM EmployeeJobHistory h WHERE h.deleted = false AND h.applied = false "
        + "AND h.effectiveFrom <= :date")
    List<Long> findEmployeesDue(@Param("date") LocalDate date);
}
