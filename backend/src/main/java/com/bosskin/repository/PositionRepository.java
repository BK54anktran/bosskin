package com.bosskin.repository;

import com.bosskin.entity.Position;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface PositionRepository extends JpaRepository<Position, Long> {
    List<Position> findByDepartmentId(Long departmentId);
    List<Position> findByCompanyId(Long companyId);
    Optional<Position> findByIdAndCompanyId(Long id, Long companyId);
    boolean existsByCodeAndCompanyId(String code, Long companyId);
    boolean existsByCodeAndCompanyIdAndIdNot(String code, Long companyId, Long id);

    /** Chức vụ dùng được ở một phòng ban: của phòng ban đó + chức vụ chung. */
    @Query("SELECT p FROM Position p WHERE p.company.id = :companyId AND (p.department IS NULL OR p.department.id = :departmentId)")
    List<Position> findUsableInDepartment(@Param("departmentId") Long departmentId, @Param("companyId") Long companyId);
    long countByDepartmentIdAndDepartmentCompanyId(Long departmentId, Long companyId);

    @Query("SELECT p.id, COUNT(e) FROM Position p LEFT JOIN Employee e ON e.position.id = p.id WHERE p.company.id = :companyId AND p.deleted = false GROUP BY p.id")
    List<Object[]> countEmployeesByCompany(@Param("companyId") Long companyId);

    @Modifying
    @Query("UPDATE Position p SET p.deleted = true WHERE p.id IN :ids")
    void softDeleteByIds(@Param("ids") Collection<Long> ids);
}
