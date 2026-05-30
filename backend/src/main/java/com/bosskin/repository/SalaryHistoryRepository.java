package com.bosskin.repository;

import com.bosskin.entity.SalaryHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface SalaryHistoryRepository extends JpaRepository<SalaryHistory, Long> {

    List<SalaryHistory> findByEmployeeIdOrderByEffectiveDateDesc(Long employeeId);

    Optional<SalaryHistory> findTopByEmployeeIdAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
            Long employeeId, LocalDate date);

    @Query("SELECT s FROM SalaryHistory s WHERE s.employee.company.id = :companyId AND s.employee.id = :employeeId ORDER BY s.effectiveDate DESC")
    List<SalaryHistory> findByCompanyAndEmployee(Long companyId, Long employeeId);
}
