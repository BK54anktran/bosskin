package com.bosskin.repository;

import com.bosskin.entity.EmployeeDependent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface EmployeeDependentRepository extends JpaRepository<EmployeeDependent, Long> {

    List<EmployeeDependent> findByEmployeeIdAndDeletedFalseOrderByDeductionFromAscIdAsc(Long employeeId);

    Optional<EmployeeDependent> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);

    @Query("SELECT d FROM EmployeeDependent d JOIN FETCH d.employee e LEFT JOIN FETCH e.department " +
           "WHERE d.companyId = :companyId AND d.deleted = false ORDER BY e.employeeCode, d.deductionFrom, d.id")
    List<EmployeeDependent> findByCompany(@Param("companyId") Long companyId);

    /** Số người phụ thuộc được giảm trừ trong tháng bắt đầu {@code month} (ngày 01). */
    @Query("SELECT COUNT(d) FROM EmployeeDependent d WHERE d.employee.id = :employeeId AND d.deleted = false " +
           "AND d.registrationStatus <> com.bosskin.entity.EmployeeDependent.RegistrationStatus.NOT_REGISTERED " +
           "AND d.deductionFrom <= :month AND (d.deductionTo IS NULL OR d.deductionTo >= :month)")
    long countDeductible(@Param("employeeId") Long employeeId, @Param("month") LocalDate month);
}
