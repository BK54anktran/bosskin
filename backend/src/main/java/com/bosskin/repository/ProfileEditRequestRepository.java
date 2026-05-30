package com.bosskin.repository;

import com.bosskin.entity.ProfileEditRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProfileEditRequestRepository extends JpaRepository<ProfileEditRequest, Long> {

    @Query("SELECT r FROM ProfileEditRequest r JOIN FETCH r.employee e " +
           "WHERE e.company.id = :companyId " +
           "AND (:status IS NULL OR r.status = :status) " +
           "ORDER BY r.createdAt DESC")
    List<ProfileEditRequest> findByCompanyId(
        @Param("companyId") Long companyId,
        @Param("status") ProfileEditRequest.Status status
    );

    @Query("SELECT r FROM ProfileEditRequest r JOIN FETCH r.employee e " +
           "WHERE r.id = :id AND e.company.id = :companyId")
    Optional<ProfileEditRequest> findByIdAndCompanyId(
        @Param("id") Long id,
        @Param("companyId") Long companyId
    );

    @Query("SELECT r FROM ProfileEditRequest r JOIN FETCH r.employee e " +
           "WHERE e.id = :employeeId AND r.status = :status " +
           "ORDER BY r.createdAt DESC")
    List<ProfileEditRequest> findByEmployeeIdAndStatus(
        @Param("employeeId") Long employeeId,
        @Param("status") ProfileEditRequest.Status status
    );

    long countByEmployee_Company_IdAndStatus(Long companyId, ProfileEditRequest.Status status);
}
