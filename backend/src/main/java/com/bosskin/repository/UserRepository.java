package com.bosskin.repository;

import com.bosskin.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    @Modifying
    @Transactional
    @Query("UPDATE User u SET u.language = :language WHERE u.id = :id")
    int updateLanguage(@Param("id") Long id, @Param("language") String language);

    Optional<User> findByEmail(String email);
    Optional<User> findByEmailAndCompanyId(String email, Long companyId);
    boolean existsByEmail(String email);
    boolean existsByEmailAndCompanyId(String email, Long companyId);
    Optional<User> findByEmployeeId(Long employeeId);
    Optional<User> findFirstByCompanyId(Long companyId);
    List<User> findByCompanyId(Long companyId);

    /** V22: số tài khoản của công ty không theo đuôi email {@code @domain} (chặn đổi đuôi). */
    @Query("SELECT COUNT(u) FROM User u WHERE u.company.id = :companyId AND LOWER(u.email) NOT LIKE CONCAT('%@', :domain)")
    long countEmailOutsideDomain(@Param("companyId") Long companyId, @Param("domain") String domain);

    /** D10: danh sách người dùng — nạp sẵn nhân viên, phòng ban, vai trò, quyền trực tiếp trong một câu. */
    @org.springframework.data.jpa.repository.Query("""
        SELECT DISTINCT u FROM User u
        LEFT JOIN FETCH u.employee e LEFT JOIN FETCH e.department
        LEFT JOIN FETCH u.roles LEFT JOIN FETCH u.directPermissions
        WHERE u.company.id = :companyId""")
    List<User> findForListing(@org.springframework.data.repository.query.Param("companyId") Long companyId);

    List<User> findAllByFcmTokenIsNotNullAndShiftReminderMinutesIsNotNull();
    List<User> findAllByFcmTokenIsNotNullAndCheckInOutNotifMinutesIsNotNull();

    /** Một thiết bị chỉ thuộc một tài khoản: gỡ token khỏi các tài khoản khác (máy dùng chung). */
    @Transactional
    @Modifying
    @Query("UPDATE User u SET u.fcmToken = NULL WHERE u.fcmToken = :token AND u.id <> :userId")
    int clearFcmTokenFromOthers(@Param("token") String token, @Param("userId") Long userId);

    /** Gỡ token khỏi mọi tài khoản (đăng xuất trên thiết bị đó, hoặc FCM báo token hết hiệu lực). */
    @Transactional
    @Modifying
    @Query("UPDATE User u SET u.fcmToken = NULL WHERE u.fcmToken = :token")
    int clearFcmToken(@Param("token") String token);
}
