package com.bosskin.repository;

import com.bosskin.entity.LeaveLedgerEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface LeaveLedgerEntryRepository extends JpaRepository<LeaveLedgerEntry, Long> {

    @Query("""
        SELECT e FROM LeaveLedgerEntry e JOIN FETCH e.grant g
        WHERE e.request.id = :requestId ORDER BY e.id ASC
        """)
    List<LeaveLedgerEntry> findByRequestIdFetchGrant(@Param("requestId") Long requestId);

    @Query("""
        SELECT e FROM LeaveLedgerEntry e
        JOIN FETCH e.grant g LEFT JOIN FETCH g.leaveType
        JOIN FETCH e.request r JOIN FETCH r.leaveType
        WHERE e.companyId = :companyId AND e.employeeId = :employeeId
        ORDER BY e.id DESC
        """)
    List<LeaveLedgerEntry> findByEmployee(@Param("companyId") Long companyId, @Param("employeeId") Long employeeId);
}
