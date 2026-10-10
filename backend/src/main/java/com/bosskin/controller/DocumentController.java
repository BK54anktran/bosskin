package com.bosskin.controller;

import com.bosskin.dto.DocumentDTO;
import com.bosskin.entity.User;
import com.bosskin.service.DocumentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;

/**
 * Bước N — tài liệu nhân sự.
 * <pre>
 * GET    /api/v1/document-types                         — mọi tài khoản trong công ty (để chọn loại khi gửi)
 * POST/PUT/DELETE /api/v1/document-types[/{id}]          — EMPLOYEE_DOCUMENT_VIEW + EDIT
 * GET    /api/v1/employee-documents?employeeId=         — EMPLOYEE_DOCUMENT_VIEW (+ phạm vi phòng ban)
 * POST   /api/v1/employee-documents (multipart)         — VIEW + EDIT
 * PUT    /api/v1/employee-documents/{id}                — VIEW + EDIT (sửa thông tin)
 * DELETE /api/v1/employee-documents/{id}                — VIEW + EDIT (xoá mềm)
 * POST   /api/v1/employee-documents/{id}/approve|reject — VIEW + EDIT (bản NV tự gửi)
 * GET    /api/v1/employee-documents/{id}/link           — VIEW (link ký tạm, ghi nhật ký)
 * GET    /api/v1/employee-documents/pending|expiring|missing — VIEW
 * GET/POST /api/v1/employee-documents/self, GET self/{id}/link, DELETE self/{id} — nhân viên tự phục vụ
 * </pre>
 */
@RestController
@RequiredArgsConstructor
public class DocumentController {

    private final DocumentService service;

    // ── Loại tài liệu ───────────────────────────────────────────────────────

    @GetMapping("/api/v1/document-types")
    public List<DocumentDTO.TypeResponse> types(@AuthenticationPrincipal User user) {
        require(user);
        return service.listTypes(user.getCompanyId());
    }

    @PostMapping("/api/v1/document-types")
    public ResponseEntity<DocumentDTO.TypeResponse> createType(@AuthenticationPrincipal User user,
                                                               @Valid @RequestBody DocumentDTO.TypeUpsert req) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createType(user.getCompanyId(), req));
    }

    @PutMapping("/api/v1/document-types/{id}")
    public DocumentDTO.TypeResponse updateType(@AuthenticationPrincipal User user, @PathVariable Long id,
                                               @Valid @RequestBody DocumentDTO.TypeUpsert req) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        return service.updateType(user.getCompanyId(), id, req);
    }

    @DeleteMapping("/api/v1/document-types/{id}")
    public ResponseEntity<Void> deleteType(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        service.deleteType(user.getCompanyId(), id);
        return ResponseEntity.noContent().build();
    }

    // ── Tài liệu (HR) ───────────────────────────────────────────────────────

    @GetMapping("/api/v1/employee-documents")
    public List<DocumentDTO.Response> list(@AuthenticationPrincipal User user, @RequestParam Long employeeId) {
        require(user, DocumentService.VIEW);
        return service.listByEmployee(user.getCompanyId(), user.getId(), employeeId);
    }

    @PostMapping(value = "/api/v1/employee-documents", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<DocumentDTO.Response> upload(
            @AuthenticationPrincipal User user,
            @RequestParam Long employeeId,
            @RequestParam Long typeId,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate issuedOn,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate expiresOn,
            @RequestParam(required = false) Long contractId,
            @RequestParam(required = false) String note,
            @RequestParam("file") MultipartFile file) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        return ResponseEntity.status(HttpStatus.CREATED).body(service.upload(user.getCompanyId(), user, employeeId,
            typeId, title, issuedOn, expiresOn, contractId, note, file));
    }

    @PutMapping("/api/v1/employee-documents/{id}")
    public DocumentDTO.Response update(@AuthenticationPrincipal User user, @PathVariable Long id,
                                       @Valid @RequestBody DocumentDTO.Update req) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        return service.update(user.getCompanyId(), user.getId(), id, req);
    }

    @DeleteMapping("/api/v1/employee-documents/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        service.delete(user.getCompanyId(), user.getId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/employee-documents/{id}/approve")
    public DocumentDTO.Response approve(@AuthenticationPrincipal User user, @PathVariable Long id,
                                        @Valid @RequestBody(required = false) DocumentDTO.ReviewRequest req) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        return service.review(user.getCompanyId(), user, id, true, req != null ? req.getNote() : null);
    }

    @PostMapping("/api/v1/employee-documents/{id}/reject")
    public DocumentDTO.Response reject(@AuthenticationPrincipal User user, @PathVariable Long id,
                                       @Valid @RequestBody(required = false) DocumentDTO.ReviewRequest req) {
        require(user, DocumentService.VIEW, DocumentService.EDIT);
        return service.review(user.getCompanyId(), user, id, false, req != null ? req.getNote() : null);
    }

    @GetMapping("/api/v1/employee-documents/{id}/link")
    public DocumentDTO.Link link(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user, DocumentService.VIEW);
        return service.link(user.getCompanyId(), user.getId(), id);
    }

    @GetMapping("/api/v1/employee-documents/pending")
    public List<DocumentDTO.Response> pending(@AuthenticationPrincipal User user) {
        require(user, DocumentService.VIEW);
        return service.pending(user.getCompanyId(), user.getId());
    }

    @GetMapping("/api/v1/employee-documents/expiring")
    public List<DocumentDTO.Response> expiring(@AuthenticationPrincipal User user,
                                               @RequestParam(required = false) Integer days) {
        require(user, DocumentService.VIEW);
        return service.expiring(user.getCompanyId(), user.getId(), days);
    }

    @GetMapping("/api/v1/employee-documents/missing")
    public List<DocumentDTO.Missing> missing(@AuthenticationPrincipal User user) {
        require(user, DocumentService.VIEW);
        return service.missing(user.getCompanyId(), user.getId());
    }

    // ── Tự phục vụ ───────────────────────────────────────────────────────────

    @GetMapping("/api/v1/employee-documents/self")
    public List<DocumentDTO.Response> self(@AuthenticationPrincipal User user) {
        require(user);
        return service.listSelf(user.getId());
    }

    @PostMapping(value = "/api/v1/employee-documents/self", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<DocumentDTO.Response> uploadSelf(
            @AuthenticationPrincipal User user,
            @RequestParam Long typeId,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate issuedOn,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate expiresOn,
            @RequestParam(required = false) String note,
            @RequestParam("file") MultipartFile file) {
        require(user);
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(service.uploadSelf(user, typeId, title, issuedOn, expiresOn, note, file));
    }

    @GetMapping("/api/v1/employee-documents/self/{id}/link")
    public DocumentDTO.Link selfLink(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user);
        return service.linkSelf(user.getId(), id);
    }

    @DeleteMapping("/api/v1/employee-documents/self/{id}")
    public ResponseEntity<Void> deleteSelf(@AuthenticationPrincipal User user, @PathVariable Long id) {
        require(user);
        service.deleteSelf(user.getId(), id);
        return ResponseEntity.noContent().build();
    }

    private static void require(User user, String... perms) {
        if (user == null || user.getCompanyId() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        for (String p : perms) {
            if (!user.hasPermission(p)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}
