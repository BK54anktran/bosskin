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
    private static final java.util.Set<Integer> ALLOWED_ROUNDING = java.util.Set.of(1, 5, 15, 30, 60);

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
        if (req.getAttendance().getDeviceBindingEnabled() != null) {
            c.setDeviceBindingEnabled(req.getAttendance().getDeviceBindingEnabled());
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
        if (req.getAttendance().getCheckInToleranceMinutes() != null) {
            validateTolerance(req.getAttendance().getCheckInToleranceMinutes(), "checkIn");
            c.setCheckInToleranceMinutes(req.getAttendance().getCheckInToleranceMinutes());
        }
        if (req.getAttendance().getCheckOutToleranceMinutes() != null) {
            validateTolerance(req.getAttendance().getCheckOutToleranceMinutes(), "checkOut");
            c.setCheckOutToleranceMinutes(req.getAttendance().getCheckOutToleranceMinutes());
        }
        if (req.getAttendance().getRoundingCheckInMinutes() != null) {
            validateRounding(req.getAttendance().getRoundingCheckInMinutes(), "checkIn");
            c.setRoundingCheckInMinutes(req.getAttendance().getRoundingCheckInMinutes());
        }
        if (req.getAttendance().getRoundingCheckOutMinutes() != null) {
            validateRounding(req.getAttendance().getRoundingCheckOutMinutes(), "checkOut");
            c.setRoundingCheckOutMinutes(req.getAttendance().getRoundingCheckOutMinutes());
        }
        if (req.getAttendance().getRoundingWorkMinutes() != null) {
            validateRounding(req.getAttendance().getRoundingWorkMinutes(), "work");
            c.setRoundingWorkMinutes(req.getAttendance().getRoundingWorkMinutes());
        }

        companyRepository.save(c);
        return toResponse(c);
    }

    private void validateRounding(Integer value, String field) {
        if (value == null) return;
        if (!ALLOWED_ROUNDING.contains(value)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.rounding_invalid." + field);
        }
    }

    private void validateTolerance(Integer value, String field) {
        if (value == null) return;
        if (value < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.tolerance_invalid." + field);
        }
    }

    private CompanySettingDTO.Response toResponse(Company c) {
        return CompanySettingDTO.Response.builder()
            .attendance(CompanySettingDTO.AttendanceSetting.builder()
                .dayNightMode(c.isAttendanceDayNightMode())
                .otEnabled(c.isAttendanceOtEnabled())
                .dayStartTime(c.getDayStartTime())
                .dayEndTime(c.getDayEndTime())
                .locationCheckEnabled(c.isLocationCheckEnabled())
                .deviceBindingEnabled(c.isDeviceBindingEnabled())
                .checkInLatitude(c.getCheckInLatitude())
                .checkInLongitude(c.getCheckInLongitude())
                .checkInRadiusMeters(c.getCheckInRadiusMeters())
                .checkInBeforeMinutes(c.getCheckInBeforeMinutes())
                .checkInAfterMinutes(c.getCheckInAfterMinutes())
                .checkOutBeforeMinutes(c.getCheckOutBeforeMinutes())
                .checkOutAfterMinutes(c.getCheckOutAfterMinutes())
                .checkInToleranceMinutes(c.getCheckInToleranceMinutes())
                .checkOutToleranceMinutes(c.getCheckOutToleranceMinutes())
                .roundingCheckInMinutes(c.getRoundingCheckInMinutes())
                .roundingCheckOutMinutes(c.getRoundingCheckOutMinutes())
                .roundingWorkMinutes(c.getRoundingWorkMinutes())
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
