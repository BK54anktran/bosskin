package com.bosskin.service;

import com.bosskin.dto.CompanySettingDTO;
import com.bosskin.entity.Company;
import com.bosskin.repository.CompanyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CompanySettingService {

    private final CompanyRepository companyRepository;

    public CompanySettingDTO.Response getByCompanyId(Long companyId) {
        Company c = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        return toResponse(c);
    }

    @Transactional
    public CompanySettingDTO.Response update(Long companyId, CompanySettingDTO.Upsert req) {
        Company c = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));

        if (req.getLeaves().getHoursPerDay() == null || req.getLeaves().getHoursPerDay().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.hours_per_day_invalid");
        }

        c.setAttendanceDayNightMode(Boolean.TRUE.equals(req.getAttendance().getDayNightMode()));
        c.setAttendanceOtEnabled(Boolean.TRUE.equals(req.getAttendance().getOtEnabled()));
        if (req.getAttendance().getDayStartTime() != null) {
            c.setDayStartTime(req.getAttendance().getDayStartTime());
        }
        if (req.getAttendance().getDayEndTime() != null) {
            c.setDayEndTime(req.getAttendance().getDayEndTime());
        }
        c.setLeaveHoursPerDay(req.getLeaves().getHoursPerDay().setScale(2, RoundingMode.HALF_UP));
        if (req.getPayroll() != null) {
            if (req.getPayroll().getStandardWorkDays() != null && req.getPayroll().getStandardWorkDays() > 0) {
                c.setStandardWorkDays(req.getPayroll().getStandardWorkDays());
            }
            if (req.getPayroll().getPayrollCutoffDay() != null) {
                int cutoff = req.getPayroll().getPayrollCutoffDay();
                if (cutoff < 1 || cutoff > 28) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.cutoff_day_invalid");
                }
                c.setPayrollCutoffDay(cutoff);
            }
        }
        if (req.getAttendance().getLocationCheckEnabled() != null) {
            c.setLocationCheckEnabled(req.getAttendance().getLocationCheckEnabled());
        }
        c.setCheckInLatitude(req.getAttendance().getCheckInLatitude());
        c.setCheckInLongitude(req.getAttendance().getCheckInLongitude());
        if (req.getAttendance().getCheckInRadiusMeters() != null) {
            c.setCheckInRadiusMeters(req.getAttendance().getCheckInRadiusMeters());
        }
        if (req.getAttendance().getCheckInBeforeMinutes() != null && req.getAttendance().getCheckInBeforeMinutes() >= 0) {
            c.setCheckInBeforeMinutes(req.getAttendance().getCheckInBeforeMinutes());
        }
        if (req.getAttendance().getCheckInAfterMinutes() != null && req.getAttendance().getCheckInAfterMinutes() >= 0) {
            c.setCheckInAfterMinutes(req.getAttendance().getCheckInAfterMinutes());
        }
        if (req.getAttendance().getCheckOutBeforeMinutes() != null && req.getAttendance().getCheckOutBeforeMinutes() >= 0) {
            c.setCheckOutBeforeMinutes(req.getAttendance().getCheckOutBeforeMinutes());
        }
        if (req.getAttendance().getCheckOutAfterMinutes() != null && req.getAttendance().getCheckOutAfterMinutes() >= 0) {
            c.setCheckOutAfterMinutes(req.getAttendance().getCheckOutAfterMinutes());
        }

        companyRepository.save(c);
        return toResponse(c);
    }

    private CompanySettingDTO.Response toResponse(Company c) {
        return CompanySettingDTO.Response.builder()
            .attendance(CompanySettingDTO.AttendanceSetting.builder()
                .dayNightMode(c.isAttendanceDayNightMode())
                .otEnabled(c.isAttendanceOtEnabled())
                .dayStartTime(c.getDayStartTime())
                .dayEndTime(c.getDayEndTime())
                .locationCheckEnabled(c.isLocationCheckEnabled())
                .checkInLatitude(c.getCheckInLatitude())
                .checkInLongitude(c.getCheckInLongitude())
                .checkInRadiusMeters(c.getCheckInRadiusMeters())
                .checkInBeforeMinutes(c.getCheckInBeforeMinutes())
                .checkInAfterMinutes(c.getCheckInAfterMinutes())
                .checkOutBeforeMinutes(c.getCheckOutBeforeMinutes())
                .checkOutAfterMinutes(c.getCheckOutAfterMinutes())
                .build())
            .leaves(CompanySettingDTO.LeaveSetting.builder()
                .hoursPerDay(c.getLeaveHoursPerDay())
                .build())
            .payroll(CompanySettingDTO.PayrollSetting.builder()
                .standardWorkDays(c.getStandardWorkDays())
                .payrollCutoffDay(c.getPayrollCutoffDay())
                .build())
            .build();
    }
}
