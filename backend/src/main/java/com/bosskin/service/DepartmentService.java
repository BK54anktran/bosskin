package com.bosskin.service;

import com.bosskin.dto.DepartmentDTO;
import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.DepartmentRepository;
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
public class DepartmentService {

    private final DepartmentRepository departmentRepo;
    private final CompanyRepository    companyRepo;
    private final EmployeeRepository   employeeRepo;
    private final PositionRepository   positionRepo;
    private final DeptScopeService     deptScopeService;
    private static final Set<Integer> ALLOWED_ROUNDING = Set.of(1, 5, 15, 30, 60);

    @Transactional(readOnly = true)
    public List<DepartmentDTO.Response> getTree(Long companyId, Long userId) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "DEPARTMENT_VIEW");

        if (scopeIds.isEmpty()) {
            List<Department> roots = departmentRepo.findByCompanyIdAndParentIsNullOrderByName(companyId);
            return roots.stream().map(this::toResponse).toList();
        }

        List<Department> scoped = departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().filter(d -> scopeIds.contains(d.getId())).collect(Collectors.toList());

        Map<Long, List<Department>> byParent = new HashMap<>();
        for (Department d : scoped) {
            Long parentId = (d.getParent() == null || !scopeIds.contains(d.getParent().getId()))
                ? null : d.getParent().getId();
            byParent.computeIfAbsent(parentId, k -> new ArrayList<>()).add(d);
        }
        byParent.values().forEach(list -> list.sort(Comparator.comparing(Department::getName)));

        return byParent.getOrDefault(null, List.of()).stream()
            .map(d -> toResponseScoped(d, byParent))
            .toList();
    }

    private DepartmentDTO.Response toResponseScoped(Department d, Map<Long, List<Department>> byParent) {
        List<DepartmentDTO.Response> children = byParent.getOrDefault(d.getId(), List.of()).stream()
            .map(child -> toResponseScoped(child, byParent))
            .toList();
        return DepartmentDTO.Response.builder()
            .id(d.getId()).name(d.getName()).code(d.getCode()).description(d.getDescription())
            .parentId(d.getParent() == null ? null : d.getParent().getId())
            .parentName(d.getParent() == null ? null : d.getParent().getName())
            .level(d.getLevel())
            .managerId(d.getManager() == null ? null : d.getManager().getId())
            .managerName(d.getManager() == null ? null : d.getManager().getFullName())
            .employeeCount(d.getEmployees() == null ? 0 : d.getEmployees().size())
            .children(children)
            .checkInLatitude(d.getCheckInLatitude())
            .checkInLongitude(d.getCheckInLongitude())
            .checkInRadiusMeters(d.getCheckInRadiusMeters())
            .checkInToleranceMinutes(d.getCheckInToleranceMinutes())
            .checkOutToleranceMinutes(d.getCheckOutToleranceMinutes())
            .roundingCheckInMinutes(d.getRoundingCheckInMinutes())
            .roundingCheckOutMinutes(d.getRoundingCheckOutMinutes())
            .roundingWorkMinutes(d.getRoundingWorkMinutes())
            .build();
    }

    @Transactional(readOnly = true)
    public List<DepartmentDTO.FlatItem> getFlat(Long companyId, Long userId, String permissionCode) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, permissionCode);

        List<Department> all = departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId);

        // If scoped, keep only depts in scope; treat parents not in scope as virtual roots
        List<Department> source = scopeIds.isEmpty() ? all
            : all.stream().filter(d -> scopeIds.contains(d.getId())).collect(Collectors.toList());

        Map<Long, List<Department>> byParent = new HashMap<>();
        for (Department d : source) {
            Long parentId = d.getParent() == null ? null : d.getParent().getId();
            // If scoped and parent not in scope, treat as root
            if (!scopeIds.isEmpty() && parentId != null && !scopeIds.contains(parentId)) {
                parentId = null;
            }
            byParent.computeIfAbsent(parentId, k -> new ArrayList<>()).add(d);
        }
        byParent.values().forEach(list -> list.sort(Comparator.comparing(Department::getName)));

        List<DepartmentDTO.FlatItem> result = new ArrayList<>();
        walkFlat(byParent, null, null, null, result);
        return result;
    }

    private void walkFlat(Map<Long, List<Department>> byParent, Long parentId,
                          String parentName, String parentCode, List<DepartmentDTO.FlatItem> result) {
        for (Department d : byParent.getOrDefault(parentId, List.of())) {
            result.add(DepartmentDTO.FlatItem.builder()
                .id(d.getId())
                .name(d.getName())
                .code(d.getCode())
                .description(d.getDescription())
                .parentId(parentId)
                .parentName(parentName)
                .parentCode(parentCode)
                .level(d.getLevel())
                .employeeCount(d.getEmployees() == null ? 0 : d.getEmployees().size())
                .checkInLatitude(d.getCheckInLatitude())
                .checkInLongitude(d.getCheckInLongitude())
                .checkInRadiusMeters(d.getCheckInRadiusMeters())
                .build());
            walkFlat(byParent, d.getId(), d.getName(), d.getCode(), result);
        }
    }

    @Transactional(readOnly = true)
    public List<DepartmentDTO.ImportDiff> previewImport(Long companyId, List<DepartmentDTO.ImportRow> rows) {
        Map<String, Department> existing = departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d));

        List<DepartmentDTO.ImportDiff> result = new ArrayList<>();

        for (DepartmentDTO.ImportRow row : rows) {
            if (row.getCode() == null || row.getCode().isBlank()) continue;

            String code       = row.getCode().trim().toUpperCase();
            String parentCode = row.getParentCode() == null ? null : row.getParentCode().trim().toUpperCase();
            String name       = row.getName() == null ? "" : row.getName().trim();
            Department dept   = existing.get(code);

            // ── DELETE ──────────────────────────────────────────────────────
            if (row.isMarkedDelete()) {
                if (dept == null) continue;
                List<String> warnings = buildDeleteWarnings(dept);
                result.add(DepartmentDTO.ImportDiff.builder()
                    .action("DELETE").code(code).name(dept.getName())
                    .description(dept.getDescription())
                    .latitude(str(dept.getCheckInLatitude()))
                    .longitude(str(dept.getCheckInLongitude()))
                    .radiusMeters(str(dept.getCheckInRadiusMeters() == 0 ? null : dept.getCheckInRadiusMeters()))
                    .changes(List.of()).warnings(warnings).build());
                continue;
            }

            if (name.isBlank()) continue;

            // ── CREATE ──────────────────────────────────────────────────────
            if (dept == null) {
                result.add(DepartmentDTO.ImportDiff.builder()
                    .action("CREATE").code(code).name(name).parentCode(parentCode)
                    .description(row.getDescription() == null ? null : row.getDescription().trim())
                    .latitude(row.getCheckInLatitude())
                    .longitude(row.getCheckInLongitude())
                    .radiusMeters(row.getCheckInRadiusMeters())
                    .changes(List.of()).warnings(List.of()).build());
            } else {
                // ── UPDATE / NO_CHANGE ───────────────────────────────────────
                List<DepartmentDTO.FieldChange> changes = new ArrayList<>();
                addChange(changes, "Tên",         dept.getName(),        name);
                addChange(changes, "PB cha",      dept.getParent() == null ? null : dept.getParent().getCode(), parentCode);
                addChange(changes, "Mô tả",       dept.getDescription(), row.getDescription() == null ? null : row.getDescription().trim());
                addChange(changes, "Vĩ độ",   str(dept.getCheckInLatitude()),  row.getCheckInLatitude());
                addChange(changes, "Kinh độ", str(dept.getCheckInLongitude()), row.getCheckInLongitude());
                // Chỉ so sánh bán kính khi ít nhất 1 phía có tọa độ thực sự (không phải empty)
                boolean dbHasLocation  = dept.getCheckInLatitude() != null;
                boolean rowHasLocation = row.getCheckInLatitude() != null && !row.getCheckInLatitude().isBlank();
                if (dbHasLocation || rowHasLocation) {
                    addChange(changes, "Bán kính (m)", str(dept.getCheckInRadiusMeters()), row.getCheckInRadiusMeters());
                }

                result.add(DepartmentDTO.ImportDiff.builder()
                    .action(changes.isEmpty() ? "NO_CHANGE" : "UPDATE")
                    .code(code).name(name).parentCode(parentCode)
                    .changes(changes).warnings(List.of()).build());
            }
        }
        return result;
    }

    private List<String> buildDeleteWarnings(Department dept) {
        List<String> warnings = new ArrayList<>();
        long childCount = departmentRepo.countByParentIdAndCompanyId(dept.getId(), dept.getCompany().getId());
        if (childCount > 0)
            warnings.add("Có " + childCount + " phòng ban con sẽ mất phòng ban cha");
        long posCount = positionRepo.countByDepartmentIdAndDepartmentCompanyId(dept.getId(), dept.getCompany().getId());
        if (posCount > 0)
            warnings.add("Có " + posCount + " chức vụ thuộc phòng ban này sẽ bị xóa");
        int empCount = dept.getEmployees() == null ? 0 : dept.getEmployees().size();
        if (empCount > 0)
            warnings.add("Có " + empCount + " nhân viên đang thuộc phòng ban này");
        return warnings;
    }

    private void addChange(List<DepartmentDTO.FieldChange> list, String field, String oldVal, String newVal) {
        String o = oldVal == null ? "" : oldVal.trim();
        String n = newVal == null ? "" : newVal.trim();
        if (!o.equals(n)) {
            list.add(DepartmentDTO.FieldChange.builder().field(field).oldValue(o).newValue(n).build());
        }
    }

    private String str(Object val) {
        return val == null ? "" : val.toString();
    }

    @Transactional
    public void importFromExcel(Long companyId, List<DepartmentDTO.ImportRow> rows) {
        Company company = companyRepo.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));

        // Build lookup map code → existing dept
        Map<String, Department> existing = departmentRepo.findByCompanyIdOrderByLevelAscNameAsc(companyId)
            .stream().collect(Collectors.toMap(Department::getCode, d -> d));

        // Collect all codes từ file để resolve parent sau
        Map<String, Department> saved = new java.util.LinkedHashMap<>(existing);

        // ── Bước 1: xử lý tất cả DELETE bằng bulk SQL ──────────────────────
        Set<String> deletedCodes = new java.util.HashSet<>();
        List<Long> deleteIds = new ArrayList<>();

        for (DepartmentDTO.ImportRow row : rows) {
            if (row.getCode() == null || row.getCode().isBlank()) continue;
            if (!row.isMarkedDelete()) continue;
            String code = row.getCode().trim().toUpperCase();
            Department dept = existing.get(code);
            if (dept == null) continue;
            deletedCodes.add(code);
            deleteIds.add(dept.getId());
            saved.remove(code);
        }

        if (!deleteIds.isEmpty()) {
            // 1a. Tách phòng con khỏi parent bằng 1 câu UPDATE duy nhất
            departmentRepo.detachChildrenOfParents(deleteIds);
            // 1b. Soft-delete tất cả cùng lúc bằng 1 câu UPDATE duy nhất
            departmentRepo.softDeleteByIds(deleteIds);
            departmentRepo.flush();
        }

        // ── Bước 2: upsert các hàng còn lại ────────────────────────────────
        for (DepartmentDTO.ImportRow row : rows) {
            if (row.getCode() == null || row.getCode().isBlank()) continue;

            String code = row.getCode().trim().toUpperCase();

            if (row.isMarkedDelete() || deletedCodes.contains(code)) continue;

            if (row.getName() == null || row.getName().isBlank()) continue;

            String parentCode = row.getParentCode() == null ? null : row.getParentCode().trim().toUpperCase();

            Department parent = null;
            if (parentCode != null && !parentCode.isBlank()) {
                parent = saved.get(parentCode);
                if (parent == null)
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Mã phòng ban cha \"" + parentCode + "\" không tồn tại (dòng: " + code + ")");
            }

            int level = parent == null ? 0 : parent.getLevel() + 1;

            Department dept = saved.containsKey(code) ? saved.get(code) : new Department();
            dept.setCompany(company);
            dept.setCode(code);
            dept.setName(row.getName().trim());
            dept.setDescription(row.getDescription() == null ? null : row.getDescription().trim());
            dept.setParent(parent);
            dept.setLevel(level);
            if (row.getCheckInLatitude() != null && !row.getCheckInLatitude().isBlank()) {
                try { dept.setCheckInLatitude(Double.parseDouble(row.getCheckInLatitude())); } catch (NumberFormatException ignored) {}
            }
            if (row.getCheckInLongitude() != null && !row.getCheckInLongitude().isBlank()) {
                try { dept.setCheckInLongitude(Double.parseDouble(row.getCheckInLongitude())); } catch (NumberFormatException ignored) {}
            }
            if (row.getCheckInRadiusMeters() != null && !row.getCheckInRadiusMeters().isBlank()) {
                try { dept.setCheckInRadiusMeters(Integer.parseInt(row.getCheckInRadiusMeters())); } catch (NumberFormatException ignored) {}
            }

            Department persisted = departmentRepo.save(dept);
            saved.put(code, persisted);
        }
    }

    @Transactional
    public DepartmentDTO.Response create(Long companyId, DepartmentDTO.CreateRequest req) {
        if (departmentRepo.existsByCodeAndCompanyId(req.getCode(), companyId))
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã phòng ban đã tồn tại");

        Company company = companyRepo.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty không tồn tại"));

        Department parent = null;
        int level = 0;
        if (req.getParentId() != null) {
            parent = departmentRepo.findByIdAndCompanyId(req.getParentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban cha không tồn tại"));
            level = parent.getLevel() + 1;
        }

        Employee manager = null;
        if (req.getManagerId() != null) {
            manager = employeeRepo.findByIdAndCompanyId(req.getManagerId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Nhân viên không tồn tại"));
        }

        Department dept = Department.builder()
            .company(company)
            .name(req.getName())
            .code(req.getCode().toUpperCase())
            .description(req.getDescription())
            .parent(parent)
            .manager(manager)
            .level(level)
            .checkInLatitude(req.getCheckInLatitude())
            .checkInLongitude(req.getCheckInLongitude())
            .checkInRadiusMeters(req.getCheckInRadiusMeters() != null ? req.getCheckInRadiusMeters() : 100)
            .checkInToleranceMinutes(validateTolerance(req.getCheckInToleranceMinutes()))
            .checkOutToleranceMinutes(validateTolerance(req.getCheckOutToleranceMinutes()))
            .roundingCheckInMinutes(validateRounding(req.getRoundingCheckInMinutes()))
            .roundingCheckOutMinutes(validateRounding(req.getRoundingCheckOutMinutes()))
            .roundingWorkMinutes(validateRounding(req.getRoundingWorkMinutes()))
            .build();

        return toResponse(departmentRepo.save(dept));
    }

    @Transactional
    public DepartmentDTO.Response update(Long companyId, Long id, DepartmentDTO.CreateRequest req) {
        Department dept = departmentRepo.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban không tồn tại"));

        if (departmentRepo.existsByCodeAndCompanyIdAndIdNot(req.getCode(), companyId, id))
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã phòng ban đã tồn tại");

        Department parent = null;
        int level = 0;
        if (req.getParentId() != null) {
            if (req.getParentId().equals(id))
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phòng ban không thể là cha của chính nó");
            parent = departmentRepo.findByIdAndCompanyId(req.getParentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban cha không tồn tại"));
            level = parent.getLevel() + 1;
        }

        Employee manager = null;
        if (req.getManagerId() != null) {
            manager = employeeRepo.findByIdAndCompanyId(req.getManagerId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Nhân viên không tồn tại"));
        }

        dept.setName(req.getName());
        dept.setCode(req.getCode().toUpperCase());
        dept.setDescription(req.getDescription());
        dept.setParent(parent);
        dept.setManager(manager);
        dept.setLevel(level);
        dept.setCheckInLatitude(req.getCheckInLatitude());
        dept.setCheckInLongitude(req.getCheckInLongitude());
        if (req.getCheckInRadiusMeters() != null) dept.setCheckInRadiusMeters(req.getCheckInRadiusMeters());
        if (req.getCheckInToleranceMinutes() != null) {
            dept.setCheckInToleranceMinutes(validateTolerance(req.getCheckInToleranceMinutes()));
        }
        if (req.getCheckOutToleranceMinutes() != null) {
            dept.setCheckOutToleranceMinutes(validateTolerance(req.getCheckOutToleranceMinutes()));
        }
        if (req.getRoundingCheckInMinutes() != null) {
            dept.setRoundingCheckInMinutes(validateRounding(req.getRoundingCheckInMinutes()));
        }
        if (req.getRoundingCheckOutMinutes() != null) {
            dept.setRoundingCheckOutMinutes(validateRounding(req.getRoundingCheckOutMinutes()));
        }
        if (req.getRoundingWorkMinutes() != null) {
            dept.setRoundingWorkMinutes(validateRounding(req.getRoundingWorkMinutes()));
        }

        return toResponse(departmentRepo.save(dept));
    }

    @Transactional
    public void delete(Long companyId, Long id) {
        Department dept = departmentRepo.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban không tồn tại"));

        if (departmentRepo.countByParentIdAndCompanyId(id, companyId) > 0)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Phòng ban còn phòng con, không thể xóa");

        if (positionRepo.countByDepartmentIdAndDepartmentCompanyId(id, companyId) > 0)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Phòng ban còn chức vụ, không thể xóa");

        if (dept.getEmployees() != null && !dept.getEmployees().isEmpty())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Phòng ban còn nhân viên, không thể xóa");

        departmentRepo.delete(dept);
    }

    private DepartmentDTO.Response toResponse(Department d) {
        return DepartmentDTO.Response.builder()
            .id(d.getId())
            .name(d.getName())
            .code(d.getCode())
            .description(d.getDescription())
            .parentId(d.getParent() == null ? null : d.getParent().getId())
            .parentName(d.getParent() == null ? null : d.getParent().getName())
            .level(d.getLevel())
            .managerId(d.getManager() == null ? null : d.getManager().getId())
            .managerName(d.getManager() == null ? null : d.getManager().getFullName())
            .employeeCount(d.getEmployees() == null ? 0 : d.getEmployees().size())
            .children(d.getChildren() == null ? List.of() :
                d.getChildren().stream()
                    .sorted((a, b) -> a.getName().compareTo(b.getName()))
                    .map(this::toResponse).toList())
            .checkInLatitude(d.getCheckInLatitude())
            .checkInLongitude(d.getCheckInLongitude())
            .checkInRadiusMeters(d.getCheckInRadiusMeters())
            .checkInToleranceMinutes(d.getCheckInToleranceMinutes())
            .checkOutToleranceMinutes(d.getCheckOutToleranceMinutes())
            .roundingCheckInMinutes(d.getRoundingCheckInMinutes())
            .roundingCheckOutMinutes(d.getRoundingCheckOutMinutes())
            .roundingWorkMinutes(d.getRoundingWorkMinutes())
            .build();
    }

    private Integer validateRounding(Integer value) {
        if (value == null) return null;
        if (!ALLOWED_ROUNDING.contains(value)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Rounding phai la 1/5/15/30/60");
        }
        return value;
    }

    private Integer validateTolerance(Integer value) {
        if (value == null) return null;
        if (value < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tolerance phai >= 0");
        }
        return value;
    }
}
