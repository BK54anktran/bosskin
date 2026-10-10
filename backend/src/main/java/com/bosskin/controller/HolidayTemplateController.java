package com.bosskin.controller;

import com.bosskin.dto.HolidayDTO;
import com.bosskin.service.HolidayService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Bước J: mẫu ngày lễ hệ thống theo năm — công ty chưa tự chỉnh năm nào thì dùng mẫu năm đó. */
@RestController
@RequestMapping("/admin/holidays")
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
@RequiredArgsConstructor
public class HolidayTemplateController {

    private final HolidayService service;

    @GetMapping
    public ResponseEntity<List<HolidayDTO.Response>> list(@RequestParam int year) {
        return ResponseEntity.ok(service.templateYear(year));
    }

    @GetMapping("/years")
    public ResponseEntity<List<Integer>> years() {
        return ResponseEntity.ok(service.templateYears());
    }

    @PostMapping
    public ResponseEntity<HolidayDTO.Response> create(@Valid @RequestBody HolidayDTO.Upsert req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createTemplate(req));
    }

    @PutMapping("/{id}")
    public ResponseEntity<HolidayDTO.Response> update(@PathVariable Long id, @Valid @RequestBody HolidayDTO.Upsert req) {
        return ResponseEntity.ok(service.updateTemplate(id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deleteTemplate(id);
        return ResponseEntity.noContent().build();
    }
}
