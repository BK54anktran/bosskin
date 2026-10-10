package com.bosskin.repository;

import com.bosskin.entity.LaborContract;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface LaborContractRepository extends JpaRepository<LaborContract, Long> {

    @Query("SELECT c FROM LaborContract c JOIN FETCH c.employee e JOIN FETCH e.department "
        + "WHERE c.companyId = :companyId AND c.deleted = false AND e.deleted = false "
        + "ORDER BY e.employeeCode, c.startDate DESC, c.id DESC")
    List<LaborContract> findByCompany(@Param("companyId") Long companyId);

    @Query("SELECT c FROM LaborContract c WHERE c.employee.id = :employeeId AND c.deleted = false "
        + "ORDER BY c.startDate DESC, c.id DESC")
    List<LaborContract> findByEmployee(@Param("employeeId") Long employeeId);

    /** Hợp đồng không nháp của nhân viên giao với [from, to] (lọc chính xác theo ngày kết thúc ở Java). */
    @Query("SELECT c FROM LaborContract c WHERE c.employee.id = :employeeId AND c.deleted = false "
        + "AND c.status <> com.bosskin.entity.LaborContract.Status.DRAFT AND c.startDate <= :to "
        + "ORDER BY c.startDate, c.id")
    List<LaborContract> findNonDraftStartingBefore(@Param("employeeId") Long employeeId, @Param("to") LocalDate to);

    Optional<LaborContract> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);

    Optional<LaborContract> findByCompanyIdAndContractNoAndDeletedFalse(Long companyId, String contractNo);

    /** Nhân viên có hợp đồng không nháp → lương HĐ do hợp đồng quản lý. */
    @Query("SELECT COUNT(c) > 0 FROM LaborContract c WHERE c.employee.id = :employeeId AND c.deleted = false "
        + "AND c.status <> com.bosskin.entity.LaborContract.Status.DRAFT")
    boolean managesSalary(@Param("employeeId") Long employeeId);

    /** Hợp đồng ACTIVE có ngày kết thúc tới {@code until} (gồm cả đã quá hạn). */
    @Query("SELECT c FROM LaborContract c JOIN FETCH c.employee e JOIN FETCH e.department "
        + "WHERE c.companyId = :companyId AND c.deleted = false AND e.deleted = false "
        + "AND c.status = com.bosskin.entity.LaborContract.Status.ACTIVE "
        + "AND c.endDate IS NOT NULL AND c.endDate <= :until ORDER BY c.endDate, c.id")
    List<LaborContract> findActiveEndingBy(@Param("companyId") Long companyId, @Param("until") LocalDate until);

    @Query("SELECT DISTINCT c.companyId FROM LaborContract c WHERE c.deleted = false "
        + "AND c.status = com.bosskin.entity.LaborContract.Status.ACTIVE AND c.endDate IS NOT NULL")
    List<Long> findCompaniesWithEndingContracts();

    @Query("SELECT DISTINCT c.employee.id FROM LaborContract c WHERE c.deleted = false "
        + "AND c.status <> com.bosskin.entity.LaborContract.Status.DRAFT")
    List<Long> findManagedEmployeeIds();
}
