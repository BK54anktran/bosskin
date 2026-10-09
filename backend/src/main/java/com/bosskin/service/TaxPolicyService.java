package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.TaxPolicyDTO;
import com.bosskin.entity.TaxPolicy;
import com.bosskin.repository.TaxPolicyRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Bước I: thông số thuế TNCN / bảo hiểm theo ngày hiệu lực. Bảng lương kỳ nào dùng chính sách
 * có {@code effective_from} ≤ ngày cuối kỳ gần nhất ({@link #forDate}).
 */
@Service
@RequiredArgsConstructor
public class TaxPolicyService {

    private static final BigDecimal MAX_AMOUNT = new BigDecimal("1000000000");

    private final TaxPolicyRepository repository;
    private final ObjectMapper objectMapper;
    private final AuditService audit;
    private final Clock clock;

    /** Chính sách áp dụng cho ngày {@code date}; chưa có chính sách nào hiệu lực → 400. */
    @Transactional(readOnly = true)
    public TaxPolicy forDate(LocalDate date) {
        return repository.findTopByEffectiveFromLessThanEqualOrderByEffectiveFromDesc(date)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "error.tax_policy.not_found|" + date));
    }

    /** Biểu thuế của chính sách, dạng dùng cho {@link FormulaEngine}. */
    public List<FormulaEngine.PitBracket> bracketsOf(TaxPolicy p) {
        return parse(p.getPitBrackets()).stream()
            .map(b -> new FormulaEngine.PitBracket(b.getUpTo(), b.getRate())).toList();
    }

    @Transactional(readOnly = true)
    public List<TaxPolicyDTO.Response> list() {
        LocalDate today = LocalDate.now(clock);
        Long currentId = repository.findTopByEffectiveFromLessThanEqualOrderByEffectiveFromDesc(today)
            .map(TaxPolicy::getId).orElse(null);
        return repository.findAllByOrderByEffectiveFromDesc().stream()
            .map(p -> TaxPolicyDTO.of(p, parse(p.getPitBrackets()), p.getId().equals(currentId))).toList();
    }

    @Transactional
    public TaxPolicyDTO.Response create(TaxPolicyDTO.Upsert req, String actorEmail) {
        validate(req);
        if (repository.existsByEffectiveFrom(req.getEffectiveFrom())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.tax_policy.duplicate_date");
        }
        TaxPolicy p = new TaxPolicy();
        apply(p, req, actorEmail);
        p = repository.save(p);
        audit.log("TAX_POLICY_CREATE").entity("TAX_POLICY", p.getId())
            .summary(p.getEffectiveFrom().toString()).detail(req).save();
        return TaxPolicyDTO.of(p, parse(p.getPitBrackets()), false);
    }

    @Transactional
    public TaxPolicyDTO.Response update(Long id, TaxPolicyDTO.Upsert req, String actorEmail) {
        validate(req);
        TaxPolicy p = getOrThrow(id);
        if (repository.existsByEffectiveFromAndIdNot(req.getEffectiveFrom(), id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.tax_policy.duplicate_date");
        }
        apply(p, req, actorEmail);
        p = repository.save(p);
        audit.log("TAX_POLICY_UPDATE").entity("TAX_POLICY", p.getId())
            .summary(p.getEffectiveFrom().toString()).detail(req).save();
        return TaxPolicyDTO.of(p, parse(p.getPitBrackets()), false);
    }

    @Transactional
    public void delete(Long id) {
        TaxPolicy p = getOrThrow(id);
        if (repository.count() <= 1) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.tax_policy.last_one");
        }
        repository.delete(p);
        audit.log("TAX_POLICY_DELETE").entity("TAX_POLICY", id).summary(p.getEffectiveFrom().toString()).save();
    }

    // ─── helpers ──────────────────────────────────────────────────────────────

    private TaxPolicy getOrThrow(Long id) {
        return repository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.tax_policy.not_found"));
    }

    private void apply(TaxPolicy p, TaxPolicyDTO.Upsert req, String actorEmail) {
        p.setEffectiveFrom(req.getEffectiveFrom());
        p.setPersonalDeduction(req.getPersonalDeduction());
        p.setDependentDeduction(req.getDependentDeduction());
        p.setReferenceWage(req.getReferenceWage());
        p.setInsuranceCapMultiplier(req.getInsuranceCapMultiplier());
        p.setUnemploymentCapMultiplier(req.getUnemploymentCapMultiplier());
        p.setMinWageRegion1(req.getMinWages().get(0));
        p.setMinWageRegion2(req.getMinWages().get(1));
        p.setMinWageRegion3(req.getMinWages().get(2));
        p.setMinWageRegion4(req.getMinWages().get(3));
        String note = req.getNote() == null ? null : req.getNote().trim();
        p.setNote(note == null || note.isEmpty() ? null : note.length() > 500 ? note.substring(0, 500) : note);
        p.setUpdatedBy(actorEmail);
        try {
            p.setPitBrackets(objectMapper.writeValueAsString(req.getBrackets()));
        } catch (Exception e) {
            throw bad("error.tax_policy.brackets_invalid");
        }
    }

    private void validate(TaxPolicyDTO.Upsert req) {
        if (!amountOk(req.getPersonalDeduction()) || !amountOk(req.getDependentDeduction())
            || !amountOk(req.getReferenceWage()) || req.getReferenceWage().signum() == 0) {
            throw bad("error.tax_policy.amount_invalid");
        }
        if (req.getInsuranceCapMultiplier() < 1 || req.getInsuranceCapMultiplier() > 100
            || req.getUnemploymentCapMultiplier() < 1 || req.getUnemploymentCapMultiplier() > 100) {
            throw bad("error.tax_policy.multiplier_invalid");
        }
        if (req.getMinWages().size() != 4
            || req.getMinWages().stream().anyMatch(w -> !amountOk(w) || w.signum() == 0)) {
            throw bad("error.tax_policy.min_wage_invalid");
        }
        List<TaxPolicyDTO.Bracket> bs = req.getBrackets();
        BigDecimal prev = BigDecimal.ZERO;
        for (int i = 0; i < bs.size(); i++) {
            TaxPolicyDTO.Bracket b = bs.get(i);
            boolean last = i == bs.size() - 1;
            if (b.getRate() == null || b.getRate().signum() < 0 || b.getRate().compareTo(BigDecimal.ONE) > 0) {
                throw bad("error.tax_policy.brackets_invalid");
            }
            if (last) {
                if (b.getUpTo() != null) throw bad("error.tax_policy.brackets_invalid");
            } else if (b.getUpTo() == null || b.getUpTo().compareTo(prev) <= 0 || !amountOk(b.getUpTo())) {
                throw bad("error.tax_policy.brackets_invalid");
            } else {
                prev = b.getUpTo();
            }
        }
    }

    private static boolean amountOk(BigDecimal v) {
        return v != null && v.signum() >= 0 && v.compareTo(MAX_AMOUNT) <= 0;
    }

    private List<TaxPolicyDTO.Bracket> parse(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<List<TaxPolicyDTO.Bracket>>() {});
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    private static ResponseStatusException bad(String key) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, key);
    }

    /** Dùng trong test / chỗ khác cần tra không ném lỗi. */
    @Transactional(readOnly = true)
    public Optional<TaxPolicy> findForDate(LocalDate date) {
        return repository.findTopByEffectiveFromLessThanEqualOrderByEffectiveFromDesc(date);
    }
}
