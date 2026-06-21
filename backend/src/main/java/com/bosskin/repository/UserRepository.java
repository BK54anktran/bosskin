package com.bosskin.repository;

import com.bosskin.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    Optional<User> findByEmailAndCompanyId(String email, Long companyId);
    boolean existsByEmail(String email);
    boolean existsByEmailAndCompanyId(String email, Long companyId);
    Optional<User> findByEmployeeId(Long employeeId);
    Optional<User> findFirstByCompanyId(Long companyId);
    List<User> findByCompanyId(Long companyId);

    List<User> findAllByFcmTokenIsNotNullAndShiftReminderMinutesIsNotNull();
}
