package com.bosskin.repository;

import com.bosskin.entity.AttendanceApproveLeave;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AttendanceApproveLeaveRepository extends JpaRepository<AttendanceApproveLeave, Long> {
    List<AttendanceApproveLeave> findByAttendanceId(Long attendanceId);
    void deleteByAttendanceId(Long attendanceId);
}
