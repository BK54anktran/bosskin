package com.bosskin.repository;

import com.bosskin.entity.FormulaVariable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface FormulaVariableRepository extends JpaRepository<FormulaVariable, Long> {

    List<FormulaVariable> findByCompanyIdOrderByName(Long companyId);

    Optional<FormulaVariable> findByCompanyIdAndName(Long companyId, String name);

    boolean existsByCompanyIdAndNameAndIdNot(Long companyId, String name, Long excludeId);
}
