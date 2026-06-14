package com.bosskin.repository;

import com.bosskin.entity.Employee;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long> {

    Optional<Employee> findByIdAndCompanyId(Long id, Long companyId);
    List<Employee> findByCompanyId(Long companyId);
    boolean existsByEmailAndCompanyId(String email, Long companyId);
    boolean existsByEmployeeCodeAndCompanyId(String employeeCode, Long companyId);
    Optional<Employee> findByEmployeeCodeAndCompanyId(String employeeCode, Long companyId);
    long countByCompanyId(Long companyId);
    long countByCompanyIdAndDepartmentId(Long companyId, Long departmentId);
    long countByPositionIdAndCompanyId(Long positionId, Long companyId);

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department d
        LEFT JOIN FETCH e.position p
        WHERE e.company.id = :companyId
        ORDER BY e.fullName
        """)
    List<Employee> findAllByCompanyIdFetchDepartment(@Param("companyId") Long companyId);

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department d
        LEFT JOIN FETCH e.position p
        WHERE e.company.id = :companyId
          AND d.id IN :deptIds
        ORDER BY e.fullName
        """)
    List<Employee> findAllByCompanyIdAndDepartmentIdInFetchDepartment(
        @Param("companyId") Long companyId,
        @Param("deptIds") Collection<Long> deptIds
    );

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department
        LEFT JOIN FETCH e.position
        WHERE e.id = (SELECT u.employee.id FROM User u WHERE u.id = :userId)
        """)
    Optional<Employee> findByUserIdFetch(@Param("userId") Long userId);

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department d
        LEFT JOIN FETCH e.position p
        WHERE e.company.id = :companyId
          AND (:search IS NULL
               OR e.fullName LIKE CONCAT('%',:search,'%')
               OR e.email    LIKE CONCAT('%',:search,'%')
               OR e.employeeCode LIKE CONCAT('%',:search,'%'))
          AND (:departmentId IS NULL OR d.id = :departmentId)
          AND (:status IS NULL OR e.status = :status)
        """)
    Page<Employee> findAllWithFilters(
        @Param("companyId")    Long companyId,
        @Param("search")       String search,
        @Param("departmentId") Long departmentId,
        @Param("status")       Employee.Status status,
        Pageable pageable
    );

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department d
        LEFT JOIN FETCH e.position p
        WHERE e.company.id = :companyId
          AND d.id IN :deptIds
          AND (:search IS NULL
               OR e.fullName LIKE CONCAT('%',:search,'%')
               OR e.email    LIKE CONCAT('%',:search,'%')
               OR e.employeeCode LIKE CONCAT('%',:search,'%'))
          AND (:status IS NULL OR e.status = :status)
        """)
    Page<Employee> findAllWithDeptScope(
        @Param("companyId") Long companyId,
        @Param("deptIds")   Collection<Long> deptIds,
        @Param("search")    String search,
        @Param("status")    Employee.Status status,
        Pageable pageable
    );

    // ── Dashboard KPI queries ─────────────────────────────────────────────────

    @Query("""
        SELECT COUNT(e) FROM Employee e
        WHERE e.company.id = :companyId
          AND e.joinDate BETWEEN :from AND :to
          AND (:deptId IS NULL OR e.department.id = :deptId)
        """)
    long countJoinedBetween(@Param("companyId") Long companyId,
                             @Param("from") LocalDate from,
                             @Param("to") LocalDate to,
                             @Param("deptId") Long deptId);

    @Query(value = """
        SELECT COUNT(*) FROM employees
        WHERE company_id = :companyId
          AND leave_date BETWEEN :from AND :to
          AND (:deptId IS NULL OR department_id = :deptId)
        """, nativeQuery = true)
    long countResignedBetween(@Param("companyId") Long companyId,
                               @Param("from") LocalDate from,
                               @Param("to") LocalDate to,
                               @Param("deptId") Long deptId);

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department d
        WHERE e.company.id = :companyId
          AND e.salaryGrade IS NULL
          AND e.status = com.bosskin.entity.Employee.Status.ACTIVE
          AND (:deptId IS NULL OR d.id = :deptId)
        ORDER BY e.fullName
        """)
    List<Employee> findActiveMissingSalaryGrade(@Param("companyId") Long companyId,
                                                @Param("deptId") Long deptId);

    @Query("""
        SELECT e FROM Employee e
        JOIN FETCH e.department d
        WHERE e.company.id = :companyId
          AND e.status = com.bosskin.entity.Employee.Status.ACTIVE
          AND e.joinDate BETWEEN :from AND :to
          AND (:deptId IS NULL OR d.id = :deptId)
        ORDER BY e.joinDate
        """)
    List<Employee> findActiveJoinedBetween(@Param("companyId") Long companyId,
                                           @Param("from") LocalDate from,
                                           @Param("to") LocalDate to,
                                           @Param("deptId") Long deptId);
}
