package com.bosskin.repository;

import com.bosskin.entity.ContractAppendix;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ContractAppendixRepository extends JpaRepository<ContractAppendix, Long> {

    List<ContractAppendix> findByContractIdAndDeletedFalseOrderByEffectiveFromAscIdAsc(Long contractId);

    List<ContractAppendix> findByContractIdInAndDeletedFalseOrderByEffectiveFromAscIdAsc(Collection<Long> contractIds);

    Optional<ContractAppendix> findByIdAndDeletedFalse(Long id);
}
