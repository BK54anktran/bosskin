package com.bosskin.repository;

import com.bosskin.entity.EmployeeDocument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface EmployeeDocumentRepository extends JpaRepository<EmployeeDocument, Long> {

    @Query("SELECT d FROM EmployeeDocument d JOIN FETCH d.documentType JOIN FETCH d.employee e LEFT JOIN FETCH e.department " +
           "LEFT JOIN FETCH d.contract WHERE d.employee.id = :employeeId AND d.deleted = false " +
           "ORDER BY d.documentType.sortOrder, d.createdAt DESC")
    List<EmployeeDocument> findByEmployee(@Param("employeeId") Long employeeId);

    @Query("SELECT d FROM EmployeeDocument d JOIN FETCH d.documentType JOIN FETCH d.employee e LEFT JOIN FETCH e.department " +
           "LEFT JOIN FETCH d.contract WHERE d.companyId = :companyId AND d.deleted = false")
    List<EmployeeDocument> findByCompany(@Param("companyId") Long companyId);

    Optional<EmployeeDocument> findByIdAndCompanyIdAndDeletedFalse(Long id, Long companyId);

    /** Công ty có tài liệu đã duyệt hết hạn tới {@code until} — cho job cảnh báo hằng ngày. */
    @Query("SELECT DISTINCT d.companyId FROM EmployeeDocument d WHERE d.deleted = false " +
           "AND d.status = com.bosskin.entity.EmployeeDocument.Status.APPROVED AND d.expiresOn IS NOT NULL " +
           "AND d.expiresOn <= :until")
    List<Long> findCompaniesWithExpiring(@Param("until") LocalDate until);
}
