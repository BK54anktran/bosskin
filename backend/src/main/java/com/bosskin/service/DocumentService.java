package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.DocumentDTO;
import com.bosskin.entity.*;
import com.bosskin.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Bước N — tài liệu nhân sự: danh mục loại tài liệu, tài liệu gắn NV (file riêng tư, link ký tạm), cảnh báo sắp hết hạn
 * (cùng số ngày báo trước với hợp đồng), danh sách NV thiếu tài liệu bắt buộc, NV tự gửi bổ sung chờ HR duyệt.
 * Xem theo EMPLOYEE_DOCUMENT_VIEW + phạm vi phòng ban của quyền đó; sửa cần EMPLOYEE_DOCUMENT_EDIT.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DocumentService {

    public static final String VIEW = "EMPLOYEE_DOCUMENT_VIEW";
    public static final String EDIT = "EMPLOYEE_DOCUMENT_EDIT";
    static final long MAX_FILE_SIZE = 10L * 1024 * 1024;
    static final Set<String> ALLOWED_TYPES = Set.of(
        "application/pdf", "image/jpeg", "image/png", "image/webp",
        "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document");

    /** Bộ loại tài liệu mặc định cho công ty mới (giống V18). */
    private static final List<Object[]> DEFAULT_TYPES = List.of(
        new Object[]{"CCCD", true, true},
        new Object[]{"SYLL", true, false},
        new Object[]{"BANG_CAP", false, false},
        new Object[]{"CHUNG_CHI", false, true},
        new Object[]{"HD_DA_KY", false, false},
        new Object[]{"KHAM_SK", false, true});

    private final DocumentTypeRepository typeRepository;
    private final EmployeeDocumentRepository repository;
    private final EmployeeRepository employeeRepository;
    private final LaborContractRepository contractRepository;
    private final CompanyRepository companyRepository;
    private final UserRepository userRepository;
    private final DeptScopeService deptScopeService;
    private final DocumentStorageService storage;
    private final PushService pushService;
    private final AuditService audit;
    private final Clock clock;

    private LocalDate today() {
        return LocalDate.now(clock);
    }

    // ── Loại tài liệu ───────────────────────────────────────────────────────

    public List<DocumentDTO.TypeResponse> listTypes(Long companyId) {
        return typeRepository.findByCompanyIdAndDeletedFalseOrderBySortOrderAscNameAsc(companyId).stream()
            .map(DocumentService::toTypeResponse).toList();
    }

    @Transactional
    public void createDefaultTypes(Long companyId, java.util.Locale locale) {
        int order = 1;
        for (Object[] t : DEFAULT_TYPES) {
            // Tên theo ngôn ngữ được chọn khi tạo công ty (mã loại cố định, sửa tên sau tuỳ ý)
            String name = com.bosskin.i18n.AppText.msgIn(locale, "default.docType." + t[0]);
            typeRepository.save(DocumentType.builder().companyId(companyId).code((String) t[0]).name(name)
                .required((Boolean) t[1]).hasExpiry((Boolean) t[2]).sortOrder(order++).build());
        }
    }

    @Transactional
    public DocumentDTO.TypeResponse createType(Long companyId, DocumentDTO.TypeUpsert req) {
        String code = normalizeCode(req.getCode());
        if (typeRepository.existsByCompanyIdAndCodeAndDeletedFalse(companyId, code)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.document.type_code_exists|" + code);
        }
        DocumentType t = DocumentType.builder().companyId(companyId).code(code).build();
        applyType(t, req);
        t = typeRepository.save(t);
        audit.log("DOCUMENT_TYPE_CREATE").entity("DOCUMENT_TYPE", t.getId()).summary(t.getCode() + " — " + t.getName()).save();
        return toTypeResponse(t);
    }

    @Transactional
    public DocumentDTO.TypeResponse updateType(Long companyId, Long id, DocumentDTO.TypeUpsert req) {
        DocumentType t = type(companyId, id);
        String code = normalizeCode(req.getCode());
        if (!code.equals(t.getCode()) && typeRepository.existsByCompanyIdAndCodeAndDeletedFalse(companyId, code)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.document.type_code_exists|" + code);
        }
        t.setCode(code);
        applyType(t, req);
        t = typeRepository.save(t);
        audit.log("DOCUMENT_TYPE_UPDATE").entity("DOCUMENT_TYPE", t.getId()).summary(t.getCode() + " — " + t.getName()).save();
        return toTypeResponse(t);
    }

    /** Xoá mềm; tài liệu đã gắn loại này giữ nguyên. */
    @Transactional
    public void deleteType(Long companyId, Long id) {
        DocumentType t = type(companyId, id);
        t.setDeleted(true);
        typeRepository.save(t);
        audit.log("DOCUMENT_TYPE_DELETE").entity("DOCUMENT_TYPE", t.getId()).summary(t.getCode() + " — " + t.getName()).save();
    }

    // ── Tài liệu (HR) ───────────────────────────────────────────────────────

    public List<DocumentDTO.Response> listByEmployee(Long companyId, Long userId, Long employeeId) {
        Employee e = employee(companyId, employeeId);
        requireScope(userId, e);
        return repository.findByEmployee(e.getId()).stream().map(this::toResponse).toList();
    }

    /** Tài liệu NV tự gửi đang chờ duyệt (trong phạm vi). */
    public List<DocumentDTO.Response> pending(Long companyId, Long userId) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, VIEW);
        return repository.findByCompany(companyId).stream()
            .filter(d -> d.getStatus() == EmployeeDocument.Status.PENDING)
            .filter(d -> inScope(scope, d.getEmployee()))
            .sorted(Comparator.comparing(EmployeeDocument::getCreatedAt))
            .map(this::toResponse).toList();
    }

    @Transactional
    public DocumentDTO.Response upload(Long companyId, User user, Long employeeId, Long typeId, String title,
                                       LocalDate issuedOn, LocalDate expiresOn, Long contractId, String note,
                                       MultipartFile file) {
        Employee e = employee(companyId, employeeId);
        requireScope(user.getId(), e);
        EmployeeDocument d = newDocument(companyId, user, e, typeId, title, issuedOn, expiresOn, contractId, note, file);
        d.setStatus(EmployeeDocument.Status.APPROVED);
        d.setReviewedBy(user.getId());
        d.setReviewedAt(LocalDateTime.now(clock));
        d = repository.save(d);
        audit.log("DOCUMENT_UPLOAD").entity("EMPLOYEE", e.getId()).summary(summary(d))
            .detail(AuditService.map("documentId", d.getId(), "type", d.getDocumentType().getCode(), "file", d.getFileName()))
            .save();
        return toResponse(d);
    }

    @Transactional
    public DocumentDTO.Response update(Long companyId, Long userId, Long id, DocumentDTO.Update req) {
        EmployeeDocument d = document(companyId, id);
        requireScope(userId, d.getEmployee());
        if (req.getTypeId() != null) d.setDocumentType(type(companyId, req.getTypeId()));
        d.setTitle(trim(req.getTitle()));
        d.setIssuedOn(req.getIssuedOn());
        d.setExpiresOn(req.getExpiresOn());
        d.setContract(contract(companyId, d.getEmployee(), req.getContractId()));
        d.setNote(trim(req.getNote()));
        validateDates(d);
        d = repository.save(d);
        audit.log("DOCUMENT_UPDATE").entity("EMPLOYEE", d.getEmployee().getId()).summary(summary(d))
            .detail(AuditService.map("documentId", d.getId(), "issuedOn", d.getIssuedOn(), "expiresOn", d.getExpiresOn()))
            .save();
        return toResponse(d);
    }

    /** Xoá mềm; file vẫn giữ trong kho (khôi phục được). */
    @Transactional
    public void delete(Long companyId, Long userId, Long id) {
        EmployeeDocument d = document(companyId, id);
        requireScope(userId, d.getEmployee());
        d.setDeleted(true);
        repository.save(d);
        audit.log("DOCUMENT_DELETE").entity("EMPLOYEE", d.getEmployee().getId()).summary(summary(d))
            .detail(AuditService.map("documentId", d.getId(), "file", d.getFileName())).save();
    }

    @Transactional
    public DocumentDTO.Response review(Long companyId, User user, Long id, boolean approve, String note) {
        EmployeeDocument d = document(companyId, id);
        requireScope(user.getId(), d.getEmployee());
        if (d.getStatus() != EmployeeDocument.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.document.not_pending");
        }
        if (user.getEmployee() != null && user.getEmployee().getId().equals(d.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.document.cannot_review_own");
        }
        d.setStatus(approve ? EmployeeDocument.Status.APPROVED : EmployeeDocument.Status.REJECTED);
        d.setReviewNote(trim(note));
        d.setReviewedBy(user.getId());
        d.setReviewedAt(LocalDateTime.now(clock));
        d = repository.save(d);
        audit.log(approve ? "DOCUMENT_APPROVE" : "DOCUMENT_REJECT").entity("EMPLOYEE", d.getEmployee().getId())
            .summary(summary(d)).detail(AuditService.map("documentId", d.getId(), "note", d.getReviewNote())).save();
        return toResponse(d);
    }

    /** Link ký tạm; mỗi lần lấy ghi nhật ký DOCUMENT_VIEW. */
    @Transactional
    public DocumentDTO.Link link(Long companyId, Long userId, Long id) {
        EmployeeDocument d = document(companyId, id);
        requireScope(userId, d.getEmployee());
        return issueLink(d, false);
    }

    /** Tài liệu đã duyệt sắp / đã hết hạn trong {@code days} ngày (mặc định = số ngày báo trước hợp đồng của công ty). */
    public List<DocumentDTO.Response> expiring(Long companyId, Long userId, Integer days) {
        int n = days != null ? days : warningDays(companyId);
        Set<Long> scope = deptScopeService.resolvedScopes(userId, VIEW);
        return expiringDocs(companyId, n).stream()
            .filter(d -> inScope(scope, d.getEmployee()))
            .map(this::toResponse).toList();
    }

    /** NV đang làm (trong phạm vi) chưa có bản đã duyệt còn hạn của mỗi loại bắt buộc. */
    public List<DocumentDTO.Missing> missing(Long companyId, Long userId) {
        List<DocumentType> required = typeRepository.findByCompanyIdAndDeletedFalseOrderBySortOrderAscNameAsc(companyId)
            .stream().filter(DocumentType::isRequired).toList();
        if (required.isEmpty()) return List.of();
        Set<Long> scope = deptScopeService.resolvedScopes(userId, VIEW);
        LocalDate t = today();
        Map<Long, Set<Long>> validTypesByEmployee = new HashMap<>();
        for (EmployeeDocument d : repository.findByCompany(companyId)) {
            if (d.validOn(t)) {
                validTypesByEmployee.computeIfAbsent(d.getEmployee().getId(), k -> new HashSet<>())
                    .add(d.getDocumentType().getId());
            }
        }
        List<DocumentDTO.Missing> out = new ArrayList<>();
        for (Employee e : employeeRepository.findAllByCompanyIdFetchDepartment(companyId)) {
            if (e.getStatus() == Employee.Status.INACTIVE || !inScope(scope, e)) continue;
            Set<Long> has = validTypesByEmployee.getOrDefault(e.getId(), Set.of());
            List<String> miss = required.stream().filter(rt -> !has.contains(rt.getId())).map(DocumentType::getName).toList();
            if (miss.isEmpty()) continue;
            out.add(DocumentDTO.Missing.builder().employeeId(e.getId()).employeeCode(e.getEmployeeCode())
                .employeeName(e.getFullName())
                .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
                .missingTypes(miss).build());
        }
        out.sort(Comparator.comparing(DocumentDTO.Missing::getEmployeeCode));
        return out;
    }

    // ── Tự phục vụ ───────────────────────────────────────────────────────────

    public List<DocumentDTO.Response> listSelf(Long userId) {
        return repository.findByEmployee(self(userId).getId()).stream().map(this::toResponse).toList();
    }

    /** NV tự gửi bổ sung → PENDING, HR duyệt. */
    @Transactional
    public DocumentDTO.Response uploadSelf(User user, Long typeId, String title, LocalDate issuedOn, LocalDate expiresOn,
                                           String note, MultipartFile file) {
        Employee e = self(user.getId());
        EmployeeDocument d = newDocument(e.getCompany().getId(), user, e, typeId, title, issuedOn, expiresOn, null, note, file);
        d.setStatus(EmployeeDocument.Status.PENDING);
        d = repository.save(d);
        audit.log("DOCUMENT_UPLOAD").entity("EMPLOYEE", e.getId()).summary(summary(d))
            .detail(AuditService.map("documentId", d.getId(), "type", d.getDocumentType().getCode(), "self", true))
            .save();
        return toResponse(d);
    }

    @Transactional
    public DocumentDTO.Link linkSelf(Long userId, Long id) {
        EmployeeDocument d = ownDocument(userId, id);
        return issueLink(d, true);
    }

    /** NV rút bản tự gửi còn chờ duyệt. */
    @Transactional
    public void deleteSelf(Long userId, Long id) {
        EmployeeDocument d = ownDocument(userId, id);
        if (d.getStatus() != EmployeeDocument.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.document.not_pending");
        }
        d.setDeleted(true);
        repository.save(d);
        audit.log("DOCUMENT_DELETE").entity("EMPLOYEE", d.getEmployee().getId()).summary(summary(d))
            .detail(AuditService.map("documentId", d.getId(), "self", true)).save();
    }

    // ── Cảnh báo hằng ngày ───────────────────────────────────────────────────

    /** 07:35 VN: báo đẩy cho tài khoản có EMPLOYEE_DOCUMENT_VIEW khi tài liệu còn đúng N / 7 / 0 ngày. */
    @Scheduled(cron = "0 35 7 * * *", zone = "Asia/Ho_Chi_Minh")
    public void dailyJob() {
        for (Long companyId : repository.findCompaniesWithExpiring(today().plusDays(180))) {
            try {
                notifyExpiring(companyId);
            } catch (RuntimeException ex) {
                log.warn("Không gửi được cảnh báo tài liệu công ty {}: {}", companyId, ex.getMessage());
            }
        }
    }

    void notifyExpiring(Long companyId) {
        // V26: tính năng cảnh báo tài liệu tắt → không gửi thông báo
        if (!companyRepository.findById(companyId).map(c -> c.hasFeature(com.bosskin.core.CompanyFeatures.HR_DOCUMENT_ALERT)).orElse(false)) return;
        int days = warningDays(companyId);
        LocalDate t = today();
        Set<Long> marks = new HashSet<>(List.of(0L, 7L, (long) days));
        List<EmployeeDocument> due = expiringDocs(companyId, days).stream()
            .filter(d -> marks.contains(ChronoUnit.DAYS.between(t, d.getExpiresOn())))
            .toList();
        if (due.isEmpty()) return;
        for (User u : userRepository.findByCompanyId(companyId)) {
            if (!u.isEnabled() || !u.hasPermission(VIEW)) continue;
            String body = due.size() == 1
                ? com.bosskin.i18n.AppText.msgIn(com.bosskin.i18n.AppText.localeOf(u.getLanguage()), "push.docExpiring.one", due.get(0).getEmployee().getFullName(), due.get(0).getDocumentType().getName(), String.valueOf(due.get(0).getExpiresOn()))
                : com.bosskin.i18n.AppText.msgIn(com.bosskin.i18n.AppText.localeOf(u.getLanguage()), "push.docExpiring.many", String.valueOf(due.size()));
            pushService.notifyUser(u, "DOCUMENT_EXPIRING", com.bosskin.i18n.AppText.msgIn(com.bosskin.i18n.AppText.localeOf(u.getLanguage()), "push.docExpiring.title"), body, null);
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    /** Bản mới nhất (theo ngày hết hạn) của mỗi NV × loại; bản đó hết hạn trước hôm nay + n → cần thay. */
    private List<EmployeeDocument> expiringDocs(Long companyId, int n) {
        LocalDate limit = today().plusDays(n);
        Map<String, EmployeeDocument> latest = new HashMap<>();
        for (EmployeeDocument d : repository.findByCompany(companyId)) {
            if (d.getStatus() != EmployeeDocument.Status.APPROVED || !d.getDocumentType().isHasExpiry()) continue;
            if (d.getEmployee().getStatus() == Employee.Status.INACTIVE) continue;
            String k = d.getEmployee().getId() + "|" + d.getDocumentType().getId();
            EmployeeDocument cur = latest.get(k);
            if (cur == null || later(d.getExpiresOn(), cur.getExpiresOn())) latest.put(k, d);
        }
        return latest.values().stream()
            .filter(d -> d.getExpiresOn() != null && !d.getExpiresOn().isAfter(limit))
            .sorted(Comparator.comparing(EmployeeDocument::getExpiresOn))
            .toList();
    }

    /** null = không hết hạn = muộn nhất. */
    private static boolean later(LocalDate a, LocalDate b) {
        if (a == null) return b != null;
        return b != null && a.isAfter(b);
    }

    private EmployeeDocument newDocument(Long companyId, User user, Employee e, Long typeId, String title,
                                         LocalDate issuedOn, LocalDate expiresOn, Long contractId, String note,
                                         MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.s3.file_empty");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.s3.file_too_large");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_TYPES.contains(contentType)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.s3.invalid_type");
        }
        String fileName = file.getOriginalFilename() == null || file.getOriginalFilename().isBlank()
            ? "document" : file.getOriginalFilename().replaceAll("[\\\\/\\r\\n]", "_");
        if (fileName.length() > 255) fileName = fileName.substring(fileName.length() - 255);
        EmployeeDocument d = EmployeeDocument.builder()
            .companyId(companyId).employee(e).documentType(type(companyId, typeId))
            .title(trim(title)).issuedOn(issuedOn).expiresOn(expiresOn)
            .contract(contract(companyId, e, contractId)).note(trim(note))
            .fileName(fileName).contentType(contentType).fileSize(file.getSize())
            .uploadedBy(user.getId())
            .build();
        validateDates(d);
        try {
            d.setFileKey(storage.store(companyId, file.getBytes(), fileName, contentType));
        } catch (IOException ex) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "error.s3.upload_failed");
        }
        return d;
    }

    private void validateDates(EmployeeDocument d) {
        if (d.getDocumentType().isHasExpiry() && d.getExpiresOn() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.document.expiry_required");
        }
        if (d.getIssuedOn() != null && d.getExpiresOn() != null && d.getExpiresOn().isBefore(d.getIssuedOn())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.document.invalid_dates");
        }
    }

    private DocumentDTO.Link issueLink(EmployeeDocument d, boolean self) {
        DocumentDTO.Link link = storage.link(d.getFileKey(), d.getFileName(), d.getContentType());
        audit.log("DOCUMENT_VIEW").entity("EMPLOYEE", d.getEmployee().getId()).summary(summary(d))
            .detail(AuditService.map("documentId", d.getId(), "file", d.getFileName(), "self", self)).save();
        return link;
    }

    private LaborContract contract(Long companyId, Employee e, Long contractId) {
        if (contractId == null) return null;
        LaborContract c = contractRepository.findByIdAndCompanyIdAndDeletedFalse(contractId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.contract.not_found"));
        if (!c.getEmployee().getId().equals(e.getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.document.contract_mismatch");
        }
        return c;
    }

    private int warningDays(Long companyId) {
        return companyRepository.findById(companyId).map(Company::getContractExpiryWarningDays).orElse(30);
    }

    private DocumentType type(Long companyId, Long id) {
        if (id == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.document.type_not_found");
        return typeRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.document.type_not_found"));
    }

    private EmployeeDocument document(Long companyId, Long id) {
        return repository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.document.not_found"));
    }

    private EmployeeDocument ownDocument(Long userId, Long id) {
        Employee e = self(userId);
        EmployeeDocument d = repository.findByIdAndCompanyIdAndDeletedFalse(id, e.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.document.not_found"));
        if (!d.getEmployee().getId().equals(e.getId())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.document.not_found");
        }
        return d;
    }

    private Employee employee(Long companyId, Long employeeId) {
        if (employeeId == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found");
        return employeeRepository.findByIdAndCompanyId(employeeId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private Employee self(Long userId) {
        return employeeRepository.findByUserIdFetch(userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private void requireScope(Long userId, Employee e) {
        if (!inScope(deptScopeService.resolvedScopes(userId, VIEW), e)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
        }
    }

    private static boolean inScope(Set<Long> scope, Employee e) {
        return scope.isEmpty() || (e.getDepartment() != null && scope.contains(e.getDepartment().getId()));
    }

    private static void applyType(DocumentType t, DocumentDTO.TypeUpsert req) {
        t.setName(req.getName().trim());
        t.setRequired(req.isRequired());
        t.setHasExpiry(req.isHasExpiry());
        if (req.getSortOrder() != null) t.setSortOrder(req.getSortOrder());
    }

    private static String normalizeCode(String code) {
        String c = code.trim().toUpperCase();
        if (!c.matches("[A-Z0-9_]{1,30}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.document.type_code_invalid");
        }
        return c;
    }

    private static String trim(String v) {
        return v == null || v.isBlank() ? null : v.trim();
    }

    private static String summary(EmployeeDocument d) {
        return d.getEmployee().getEmployeeCode() + " " + d.getEmployee().getFullName() + " — " + d.getDocumentType().getName();
    }

    private static DocumentDTO.TypeResponse toTypeResponse(DocumentType t) {
        return DocumentDTO.TypeResponse.builder().id(t.getId()).code(t.getCode()).name(t.getName())
            .required(t.isRequired()).hasExpiry(t.isHasExpiry()).sortOrder(t.getSortOrder()).build();
    }

    private DocumentDTO.Response toResponse(EmployeeDocument d) {
        Employee e = d.getEmployee();
        return DocumentDTO.Response.builder()
            .id(d.getId()).employeeId(e.getId()).employeeCode(e.getEmployeeCode()).employeeName(e.getFullName())
            .departmentId(e.getDepartment() != null ? e.getDepartment().getId() : null)
            .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
            .typeId(d.getDocumentType().getId()).typeCode(d.getDocumentType().getCode()).typeName(d.getDocumentType().getName())
            .title(d.getTitle()).fileName(d.getFileName()).contentType(d.getContentType()).fileSize(d.getFileSize())
            .issuedOn(d.getIssuedOn()).expiresOn(d.getExpiresOn())
            .daysToExpiry(d.getExpiresOn() == null ? null : (int) ChronoUnit.DAYS.between(today(), d.getExpiresOn()))
            .contractId(d.getContract() != null ? d.getContract().getId() : null)
            .contractNo(d.getContract() != null ? d.getContract().getContractNo() : null)
            .status(d.getStatus().name()).reviewNote(d.getReviewNote()).note(d.getNote()).createdAt(d.getCreatedAt())
            .build();
    }
}
