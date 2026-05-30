package com.bosskin.repository;

import com.bosskin.entity.EmployeeLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EmployeeLocationRepository extends JpaRepository<EmployeeLocation, Long> {
    List<EmployeeLocation> findByEmployeeId(Long employeeId);
    void deleteByEmployeeId(Long employeeId);
}
