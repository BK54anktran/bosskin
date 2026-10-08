package com.bosskin.service;

import com.bosskin.dto.ShiftRotationDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ShiftRotation;
import com.bosskin.entity.WorkShift;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftRotationRepository;
import com.bosskin.repository.WorkShiftRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/** Mẫu ca xoay vòng và sinh phân ca theo mẫu (Mốc 2b). */
@Service
@RequiredArgsConstructor
public class ShiftRotationService {

    /** Sinh tối đa ~3 tháng một lần để tránh thao tác quá lớn. */
    static final int MAX_DAYS = 93;

    private final ShiftRotationRepository rotationRepo;
    private final WorkShiftRepository shiftRepo;
    private final EmployeeRepository employeeRepo;
    private final WorkShiftService shiftService;

    @Transactional(readOnly = true)
    public List<ShiftRotationDTO.Response> list(Long companyId) {
        Map<Long, String> codes = shiftCodes(companyId);
        return rotationRepo.findByCompanyIdAndActiveTrueOrderByName(companyId).stream()
            .map(r -> toResponse(r, codes)).toList();
    }

    @Transactional
    public ShiftRotationDTO.Response create(Long companyId, ShiftRotationDTO.Upsert req) {
        validateDays(companyId, req.getDays());
        ShiftRotation r = ShiftRotation.builder()
            .companyId(companyId).name(req.getName().trim())
            .pattern(ShiftRotation.encode(req.getDays())).build();
        return toResponse(rotationRepo.save(r), shiftCodes(companyId));
    }

    @Transactional
    public ShiftRotationDTO.Response update(Long companyId, Long id, ShiftRotationDTO.Upsert req) {
        ShiftRotation r = get(companyId, id);
        validateDays(companyId, req.getDays());
        r.setName(req.getName().trim());
        r.setPattern(ShiftRotation.encode(req.getDays()));
        return toResponse(rotationRepo.save(r), shiftCodes(companyId));
    }

    @Transactional
    public void delete(Long companyId, Long id) {
        ShiftRotation r = get(companyId, id);
        r.setActive(false);
        rotationRepo.save(r);
    }

    /**
     * Sinh phân ca cho danh sách nhân viên trong [from, to]. Ngày thứ k của người thứ i dùng
     * ngày (k + startOffset + i × staggerPerEmployee) mod N của chu kỳ. Mỗi ngày xử lý trong
     * giao dịch riêng: ngày lỗi (đã có công, trùng giờ, kỳ khoá) được bỏ qua và báo lại.
     * Không @Transactional ở đây để lỗi một ngày không huỷ cả lần sinh.
     */
    public ShiftRotationDTO.GenerateResult generate(Long companyId, Long rotationId,
                                                    ShiftRotationDTO.GenerateRequest req, Long createdBy) {
        ShiftRotation r = rotationRepo.findByIdAndCompanyIdAndActiveTrue(rotationId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.rotation.not_found"));
        List<List<Long>> days = r.days();
        if (days.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.rotation.empty");
        if (req.getTo().isBefore(req.getFrom())
            || ChronoUnit.DAYS.between(req.getFrom(), req.getTo()) >= MAX_DAYS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.rotation.range_invalid");
        }
        int n = days.size();
        int assigned = 0, cleared = 0, unchanged = 0;
        List<ShiftRotationDTO.Conflict> conflicts = new ArrayList<>();
        List<Long> empIds = req.getEmployeeIds();
        for (int i = 0; i < empIds.size(); i++) {
            Employee emp = employeeRepo.findByIdAndCompanyId(empIds.get(i), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
            for (LocalDate d = req.getFrom(); !d.isAfter(req.getTo()); d = d.plusDays(1)) {
                long k = ChronoUnit.DAYS.between(req.getFrom(), d) + req.getStartOffset()
                    + (long) i * req.getStaggerPerEmployee();
                List<Long> shiftIds = days.get((int) Math.floorMod(k, (long) n));
                try {
                    switch (shiftService.applyRotationDay(companyId, emp.getId(), d, shiftIds, createdBy)) {
                        case ASSIGNED -> assigned++;
                        case CLEARED -> cleared++;
                        case UNCHANGED -> unchanged++;
                    }
                } catch (ResponseStatusException e) {
                    conflicts.add(new ShiftRotationDTO.Conflict(emp.getId(), emp.getFullName(), d, e.getReason()));
                }
            }
        }
        return ShiftRotationDTO.GenerateResult.builder()
            .assignedDays(assigned).clearedDays(cleared).unchangedDays(unchanged).conflicts(conflicts).build();
    }

    private ShiftRotation get(Long companyId, Long id) {
        return rotationRepo.findByIdAndCompanyIdAndActiveTrue(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.rotation.not_found"));
    }

    private void validateDays(Long companyId, List<List<Long>> days) {
        if (days == null || days.isEmpty() || days.size() > 62) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.rotation.empty");
        }
        Set<Long> valid = shiftCodes(companyId).keySet();
        boolean anyShift = false;
        for (List<Long> d : days) {
            if (d == null) continue;
            if (d.size() > WorkShiftService.MAX_SHIFTS_PER_DAY) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.shift.too_many_per_day");
            }
            for (Long id : d) {
                if (!valid.contains(id)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.rotation.shift_invalid");
                anyShift = true;
            }
        }
        if (!anyShift) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.rotation.empty");
    }

    private Map<Long, String> shiftCodes(Long companyId) {
        return shiftRepo.findByCompanyIdAndActiveTrue(companyId).stream()
            .collect(Collectors.toMap(WorkShift::getId, WorkShift::getCode, (a, b) -> a));
    }

    private ShiftRotationDTO.Response toResponse(ShiftRotation r, Map<Long, String> codes) {
        List<List<Long>> days = r.days();
        List<String> dayCodes = days.stream()
            .map(d -> d.stream().map(id -> codes.getOrDefault(id, "?")).collect(Collectors.joining("+")))
            .toList();
        return ShiftRotationDTO.Response.builder()
            .id(r.getId()).name(r.getName()).days(days).dayCodes(dayCodes).cycleLength(days.size()).build();
    }
}
