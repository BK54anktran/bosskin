package com.bosskin.repository;

import com.bosskin.entity.ContractAllowance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface ContractAllowanceRepository extends JpaRepository<ContractAllowance, Long> {

    List<ContractAllowance> findByContractIdOrderByIdAsc(Long contractId);

    List<ContractAllowance> findByContractIdInOrderByIdAsc(Collection<Long> contractIds);

    /** Phụ cấp gốc của hợp đồng (appendix_id null). */
    @Modifying
    @Query("DELETE FROM ContractAllowance a WHERE a.contractId = :contractId AND a.appendixId IS NULL")
    void deleteContractLevel(@Param("contractId") Long contractId);

    @Modifying
    @Query("DELETE FROM ContractAllowance a WHERE a.appendixId = :appendixId")
    void deleteByAppendix(@Param("appendixId") Long appendixId);
}
