package com.bosskin.controller;

import com.bosskin.dto.TaxPolicyDTO;
import com.bosskin.entity.SystemAdmin;
import com.bosskin.service.TaxPolicyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Bước I: thông số thuế TNCN / bảo hiểm dùng chung mọi công ty — chỉ system admin sửa. */
@RestController
@RequestMapping("/admin/tax-policies")
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
@RequiredArgsConstructor
public class TaxPolicyController {

    private final TaxPolicyService service;

    @GetMapping
    public ResponseEntity<List<TaxPolicyDTO.Response>> list() {
        return ResponseEntity.ok(service.list());
    }

    @PostMapping
    public ResponseEntity<TaxPolicyDTO.Response> create(@Valid @RequestBody TaxPolicyDTO.Upsert req,
                                                        @AuthenticationPrincipal SystemAdmin me) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req, me.getEmail()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TaxPolicyDTO.Response> update(@PathVariable Long id, @Valid @RequestBody TaxPolicyDTO.Upsert req,
                                                        @AuthenticationPrincipal SystemAdmin me) {
        return ResponseEntity.ok(service.update(id, req, me.getEmail()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
