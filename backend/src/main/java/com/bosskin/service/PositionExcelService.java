package com.bosskin.service;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.dto.PositionDTO;
import com.bosskin.entity.Department;
import com.bosskin.entity.Position;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeJobHistoryRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PositionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PositionExcelService {

    private final PositionRepository positionRepo;
    private final DepartmentRepository departmentRepo;
    private final EmployeeRepository employeeRepo;
    private final EmployeeJobHistoryRepository jobHistoryRepo;

    @Transactional(readOnly = true)
    public List<PositionDTO.FlatItem> getFlat(Long companyId) {
        // Build map positionId → employeeCount
        Map<Long, Long> empCount = positionRepo.countEmployeesByCompany(companyId)
            .stream().collect(Collectors.toMap(
                row -> ((Number) row[0]).longValue(),
                row -> ((Number) row[1]).longValue()
            ));

        return positionRepo.findByDepartmentCompanyId(companyId).stream()
            .map(p -> PositionDTO.FlatItem.builder()
                .id(p.getId())
                .code(p.getCode())
                .name(p.getName())
                .description(p.getDescription())
                .departmentCode(p.getDepartment().getCode())
                .departmentName(p.getDepartment().getName())
                .employeeCount(empCount.getOrDefault(p.getId(), 0L))
                .build())
            .sorted(Comparator.comparing(PositionDTO.FlatItem::getDepartmentCode)
                .thenComparing(PositionDTO.FlatItem::getCode))
            .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<PositionDTO.ImportDiff> previewImport(Long companyId, List<PositionDTO.ImportRow> rows) {
        Map<String, Position> existing = positionRepo.findByDepartmentCompanyId(companyId)
            .stream().collect(Collectors.toMap(Position::getCode, p -> p));

        Map<Long, Long> empCount = positionRepo.countEmployeesByCompany(companyId)
            .stream().collect(Collectors.toMap(
                r -> ((Number) r[0]).longValue(),
                r -> ((Number) r[1]).longValue()
            ));

        List<PositionDTO.ImportDiff> result = new ArrayList<>();

        for (PositionDTO.ImportRow row : rows) {
            if (row.getCode() == null || row.getCode().isBlank()) continue;

            String code     = row.getCode().trim().toUpperCase();
            String deptCode = row.getDepartmentCode() == null ? null : row.getDepartmentCode().trim().toUpperCase();
            String name     = row.getName() == null ? "" : row.getName().trim();
            Position pos    = existing.get(code);

            // ── DELETE ──────────────────────────────────────────────────────
            if (row.isMarkedDelete()) {
                if (pos == null) continue;
                List<String> warnings = new ArrayList<>();
                long count = empCount.getOrDefault(pos.getId(), 0L);
                if (count > 0)
                    warnings.add("error.import.position_has_employees|" + count);
                result.add(PositionDTO.ImportDiff.builder()
                    .action("DELETE").code(code).name(pos.getName())
                    .departmentCode(pos.getDepartment().getCode())
                    .description(pos.getDescription())
                    .changes(List.of()).warnings(warnings).build());
                continue;
            }

            if (name.isBlank()) continue;

            // ── CREATE ──────────────────────────────────────────────────────
            if (pos == null) {
                result.add(PositionDTO.ImportDiff.builder()
                    .action("CREATE").code(code).name(name)
                    .departmentCode(deptCode)
                    .description(row.getDescription() == null ? null : row.getDescription().trim())
                    .changes(List.of()).warnings(List.of()).build());
            } else {
                // ── UPDATE / NO_CHANGE ───────────────────────────────────────
                List<DepartmentDTO.FieldChange> changes = new ArrayList<>();
                addChange(changes, com.bosskin.i18n.AppText.msg("import.field.name"),       pos.getName(),        name);
                addChange(changes, com.bosskin.i18n.AppText.msg("import.field.department"), pos.getDepartment().getCode(), deptCode);
                addChange(changes, com.bosskin.i18n.AppText.msg("import.field.description"),     pos.getDescription(), row.getDescription() == null ? null : row.getDescription().trim());

                result.add(PositionDTO.ImportDiff.builder()
                    .action(changes.isEmpty() ? "NO_CHANGE" : "UPDATE")
                    .code(code).name(name).departmentCode(deptCode)
                    .changes(changes).warnings(List.of()).build());
            }
        }
        return result;
    }

    @Transactional
    public void importFromExcel(Long companyId, List<PositionDTO.ImportRow> rows) {
        Map<String, Position> existing = positionRepo.findByDepartmentCompanyId(companyId)
            .stream().collect(Collectors.toMap(Position::getCode, p -> p));

        Map<String, Department> deptMap = departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d));

        // ── Bước 1: bulk DELETE ──────────────────────────────────────────────
        List<Long> deleteIds = new ArrayList<>();
        Set<String> deletedCodes = new HashSet<>();
        for (PositionDTO.ImportRow row : rows) {
            if (row.getCode() == null || row.getCode().isBlank()) continue;
            if (!row.isMarkedDelete()) continue;
            String code = row.getCode().trim().toUpperCase();
            Position pos = existing.get(code);
            if (pos == null) continue;
            // Như nút xoá: chức vụ còn NV / quá trình công tác dùng thì không xoá (xoá mềm làm hỏng nạp NV)
            if (employeeRepo.countByPositionIdAndCompanyId(pos.getId(), companyId) > 0
                    || jobHistoryRepo.countUsingPosition(pos.getId()) > 0)
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.import.position_in_use|" + code);
            deleteIds.add(pos.getId());
            deletedCodes.add(code);
        }
        if (!deleteIds.isEmpty()) {
            positionRepo.softDeleteByIds(deleteIds);
            positionRepo.flush();
        }

        // ── Bước 2: upsert ───────────────────────────────────────────────────
        for (PositionDTO.ImportRow row : rows) {
            if (row.getCode() == null || row.getCode().isBlank()) continue;
            String code = row.getCode().trim().toUpperCase();
            if (row.isMarkedDelete() || deletedCodes.contains(code)) continue;
            if (row.getName() == null || row.getName().isBlank()) continue;

            String deptCode = row.getDepartmentCode() == null ? null : row.getDepartmentCode().trim().toUpperCase();
            Department dept = null;
            if (deptCode != null && !deptCode.isBlank()) {
                dept = deptMap.get(deptCode);
                if (dept == null)
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "error.import.position_department_missing|" + deptCode + "|" + code);
            } else {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "error.import.position_department_required|" + code);
            }

            Position pos = existing.containsKey(code) ? existing.get(code) : new Position();
            pos.setCode(code);
            pos.setName(row.getName().trim());
            pos.setDepartment(dept);
            pos.setDescription(row.getDescription() == null ? null : row.getDescription().trim());
            positionRepo.save(pos);
        }
    }

    private void addChange(List<DepartmentDTO.FieldChange> list, String field, String oldVal, String newVal) {
        String o = oldVal == null ? "" : oldVal.trim();
        String n = newVal == null ? "" : newVal.trim();
        if (!o.equals(n))
            list.add(DepartmentDTO.FieldChange.builder().field(field).oldValue(o).newValue(n).build());
    }
}
