package com.bosskin.repository;

import com.bosskin.entity.SalaryFormula;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface SalaryFormulaRepository extends JpaRepository<SalaryFormula, Long> {

    List<SalaryFormula> findBySalaryGradeIdOrderByEffectiveDateDesc(Long gradeId);

    @Query(value = """
        SELECT f.* FROM salary_formulas f
        JOIN salary_grades g ON f.salary_grade_id = g.id
        LEFT JOIN departments d ON g.department_id = d.id
        WHERE g.department_id IS NULL OR d.company_id = :companyId
        ORDER BY f.effective_date DESC
        """, nativeQuery = true)
    List<SalaryFormula> findByCompanyId(Long companyId);

    Optional<SalaryFormula> findTopBySalaryGradeIdAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
            Long gradeId, LocalDate date);

    Optional<SalaryFormula> findTopBySalaryGradeIdOrderByEffectiveDateDesc(Long gradeId);

    @Query(value = """
        SELECT COUNT(*) FROM salary_formulas f
        JOIN salary_grades g ON f.salary_grade_id = g.id
        LEFT JOIN departments d ON g.department_id = d.id
        WHERE f.name = :name
          AND (g.department_id IS NULL OR d.company_id = :companyId)
          AND f.id != :excludeId
        """, nativeQuery = true)
    long countByNameAndCompanyIdAndIdNot(
        @org.springframework.data.repository.query.Param("name") String name,
        @org.springframework.data.repository.query.Param("companyId") Long companyId,
        @org.springframework.data.repository.query.Param("excludeId") Long excludeId
    );

    @Transactional
    @Modifying
    @Query(value = """
        UPDATE salary_formulas SET
          custom_vars = :customVars,
          deduction_vars = :deductionVars,
          income_vars = :incomeVars,
          allowance_vars = :allowanceVars
        WHERE id = :id
        """, nativeQuery = true)
    void updateVarsById(
        @org.springframework.data.repository.query.Param("id") Long id,
        @org.springframework.data.repository.query.Param("customVars") String customVars,
        @org.springframework.data.repository.query.Param("deductionVars") String deductionVars,
        @org.springframework.data.repository.query.Param("incomeVars") String incomeVars,
        @org.springframework.data.repository.query.Param("allowanceVars") String allowanceVars
    );
}
