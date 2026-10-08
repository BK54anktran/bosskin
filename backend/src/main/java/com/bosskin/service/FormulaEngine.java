package com.bosskin.service;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.util.*;

/**
 * Recursive-descent formula evaluator.
 * Grammar:
 *   expr   = term   (('+' | '-') term)*
 *   term   = factor (('*' | '/') factor)*
 *   factor = NUMBER | VARIABLE | '(' expr ')' | '-' factor
 */
@Component
public class FormulaEngine {

    private static final MathContext MC = new MathContext(20, RoundingMode.HALF_UP);

    public static final Set<String> ALLOWED_VARIABLES = Set.of(
            // Ngày công
            "PRESENT_DAYS", "ABSENT_DAYS", "LEAVE_DAYS",
            "ON_TIME_DAYS", "LATE_IN_DAYS", "EARLY_OUT_DAYS", "OVERTIME_DAYS",
            // Giờ công
            "DAY_HOURS", "NIGHT_HOURS", "DAY_OT", "NIGHT_OT", "TOTAL_OT_HOURS",
            // Cài đặt
            "BASE_RATE", "STANDARD_WORK_DAYS", "HOURS_PER_DAY",
            // Nghỉ phép theo loại (L1)
            "PAID_LEAVE_DAYS", "UNPAID_LEAVE_DAYS",
            // Bảo hiểm & thuế hệ thống tính sẵn — dùng được trong công thức NET (L5)
            "SOCIAL_INS", "HEALTH_INS", "UNEMPLOYMENT_INS", "TOTAL_INSURANCE", "PIT",
            // Khoản chỉnh tay trên bảng lương nháp (L6)
            "ALLOWANCE_MANUAL", "BONUS", "OTHER_DEDUCTIONS",
            // Hợp đồng & thâm niên
            "CONTRACT_SALARY",
            "TENURE_YEARS", "TENURE_MONTHS", "TENURE_DAYS",
            // Kết quả
            "GROSS"
    );

    // Built-in functions recognized by the lexer/parser
    public static final Set<String> BUILTIN_FUNCTIONS = Set.of("PIT_VN", "IF", "MIN", "MAX", "ABS", "ROUND", "FLOOR", "CEIL");

    // Keywords reserved — không được dùng làm tên biến tùy chỉnh
    public static final Set<String> RESERVED_KEYWORDS = Set.of("AND", "OR", "IF", "MIN", "MAX", "ABS", "PIT_VN", "ROUND", "FLOOR", "CEIL");

    /** Vietnamese progressive PIT (Thuế TNCN lũy tiến theo biểu thuế 7 bậc). */
    static BigDecimal pitVN(BigDecimal taxableIncome) {
        if (taxableIncome.compareTo(BigDecimal.ZERO) <= 0) return BigDecimal.ZERO;
        BigDecimal[] brackets = {
            new BigDecimal("5000000"),
            new BigDecimal("10000000"),
            new BigDecimal("18000000"),
            new BigDecimal("32000000"),
            new BigDecimal("52000000"),
            new BigDecimal("80000000"),
        };
        double[] rates = { 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35 };
        BigDecimal tax = BigDecimal.ZERO;
        BigDecimal remaining = taxableIncome;
        BigDecimal lower = BigDecimal.ZERO;
        for (int i = 0; i < brackets.length && remaining.compareTo(BigDecimal.ZERO) > 0; i++) {
            BigDecimal slice = brackets[i].subtract(lower);
            BigDecimal taxable = remaining.min(slice);
            tax = tax.add(taxable.multiply(BigDecimal.valueOf(rates[i]), MC));
            remaining = remaining.subtract(taxable);
            lower = brackets[i];
        }
        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            tax = tax.add(remaining.multiply(BigDecimal.valueOf(0.35), MC));
        }
        return tax.setScale(2, RoundingMode.HALF_UP);
    }

    public record SystemVar(String description, String category) {}

    public static final java.util.LinkedHashMap<String, SystemVar> SYSTEM_VARS =
            new java.util.LinkedHashMap<>() {{
        // Ngày công — ngày
        put("PRESENT_DAYS",   new SystemVar("Số ngày có mặt (PRESENT + LATE)",   "Chấm công — ngày"));
        put("ABSENT_DAYS",    new SystemVar("Số ngày vắng",                       "Chấm công — ngày"));
        put("LEAVE_DAYS",     new SystemVar("Số ngày nghỉ phép",                  "Chấm công — ngày"));
        put("ON_TIME_DAYS",   new SystemVar("Số ngày đi đúng giờ",               "Chấm công — ngày"));
        put("LATE_IN_DAYS",   new SystemVar("Số ngày đi trễ",                    "Chấm công — ngày"));
        put("EARLY_OUT_DAYS", new SystemVar("Số ngày về sớm",                    "Chấm công — ngày"));
        put("OVERTIME_DAYS",  new SystemVar("Số ngày có OT",                     "Chấm công — ngày"));
        // Ngày công — giờ
        put("DAY_HOURS",      new SystemVar("Tổng giờ ca ngày",                  "Chấm công — giờ"));
        put("NIGHT_HOURS",    new SystemVar("Tổng giờ ca đêm",                   "Chấm công — giờ"));
        put("DAY_OT",         new SystemVar("Tổng giờ OT ca ngày",               "Chấm công — giờ"));
        put("NIGHT_OT",       new SystemVar("Tổng giờ OT ca đêm",               "Chấm công — giờ"));
        put("TOTAL_OT_HOURS", new SystemVar("Tổng giờ làm thêm (DAY_OT + NIGHT_OT)", "Chấm công — giờ"));
        // Lương & Hợp đồng
        put("BASE_RATE",          new SystemVar("Đơn giá cơ bản từ bậc lương",   "Lương & Hợp đồng"));
        put("CONTRACT_SALARY",    new SystemVar("Lương cơ bản theo hợp đồng",    "Lương & Hợp đồng"));
        put("STANDARD_WORK_DAYS", new SystemVar("Số ngày công chuẩn/tháng",      "Lương & Hợp đồng"));
        put("HOURS_PER_DAY",      new SystemVar("Số giờ làm/ngày",              "Lương & Hợp đồng"));
        put("GROSS",              new SystemVar("Lương gộp (kết quả công thức Gross)", "Lương & Hợp đồng"));
        // Thâm niên
        put("TENURE_YEARS",  new SystemVar("Số năm đã làm việc tại công ty",    "Thâm niên"));
        put("TENURE_MONTHS", new SystemVar("Tổng số tháng đã làm việc",         "Thâm niên"));
        put("TENURE_DAYS",   new SystemVar("Tổng số ngày đã làm việc",          "Thâm niên"));
    }};

    // Backward-compat: map name -> description (dùng ở validate cũ)
    public static final java.util.LinkedHashMap<String, String> SYSTEM_VAR_DESCRIPTIONS =
            SYSTEM_VARS.entrySet().stream().collect(
                java.util.stream.Collectors.toMap(
                    java.util.Map.Entry::getKey,
                    e -> e.getValue().description(),
                    (a, b) -> a,
                    java.util.LinkedHashMap::new
                ));

    // ─── Public API ────────────────────────────────────────────────────────────

    /**
     * Resolve custom variables (expression-based) into concrete BigDecimal values,
     * using topological sort to handle dependencies. Detects circular references.
     *
     * @param customVars map of varName -> expression string (e.g. "THUONG_LE" -> "BASE_RATE * 0.5")
     * @param baseVars   already-resolved system variables (PRESENT_DAYS, BASE_RATE, etc.)
     * @return new vars map = baseVars + resolved custom vars
     */
    public Map<String, BigDecimal> resolveCustomVars(
            Map<String, String> customVars,
            Map<String, BigDecimal> baseVars) {

        if (customVars.isEmpty()) return baseVars;

        // Build dependency graph: varName -> set of custom var names it references
        Map<String, Set<String>> deps = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : customVars.entrySet()) {
            Set<String> referenced = new HashSet<>();
            try {
                for (Token t : new Lexer(entry.getValue()).tokenize()) {
                    if (t.type == TokenType.VARIABLE && customVars.containsKey(t.value)) {
                        referenced.add(t.value);
                    }
                }
            } catch (FormulaEvaluationException ignored) {}
            deps.put(entry.getKey(), referenced);
        }

        // Kahn's algorithm (topo sort)
        // inDegree[node] = số dependency của node đó trong customVars
        Map<String, Integer> inDegree = new LinkedHashMap<>();
        for (String k : deps.keySet()) inDegree.put(k, 0);
        for (Map.Entry<String, Set<String>> e : deps.entrySet()) {
            // e.getKey() phụ thuộc vào e.getValue() → inDegree của e.getKey() tăng
            inDegree.merge(e.getKey(), e.getValue().size(), Integer::sum);
        }

        Queue<String> queue = new LinkedList<>();
        for (Map.Entry<String, Integer> e : inDegree.entrySet()) {
            if (e.getValue() == 0) queue.add(e.getKey());
        }

        List<String> order = new ArrayList<>();
        while (!queue.isEmpty()) {
            String cur = queue.poll();
            order.add(cur);
            // Giảm inDegree của các node phụ thuộc vào cur
            for (Map.Entry<String, Set<String>> e : deps.entrySet()) {
                if (e.getValue().contains(cur)) {
                    inDegree.merge(e.getKey(), -1, Integer::sum);
                    if (inDegree.get(e.getKey()) == 0) queue.add(e.getKey());
                }
            }
        }

        if (order.size() != customVars.size()) {
            throw new FormulaEvaluationException(
                "Phát hiện tham chiếu vòng tròn trong biến tùy chỉnh");
        }

        // Evaluate in topo order, accumulating resolved values
        Map<String, BigDecimal> resolved = new LinkedHashMap<>(baseVars);
        for (String name : order) {
            String expr = customVars.get(name);
            try {
                resolved.put(name, evaluate(expr, resolved));
            } catch (FormulaEvaluationException e) {
                throw new FormulaEvaluationException(
                    "Lỗi tính biến '" + name + "': " + e.getMessage());
            }
        }
        return resolved;
    }

    /**
     * Tên biến (VARIABLE) xuất hiện trong biểu thức; biểu thức lỗi cú pháp trả rỗng.
     */
    public Set<String> referencedVariables(String expression) {
        Set<String> names = new HashSet<>();
        if (expression == null || expression.isBlank()) return names;
        try {
            for (Token t : new Lexer(expression).tokenize()) {
                if (t.type == TokenType.VARIABLE) names.add(t.value);
            }
        } catch (FormulaEvaluationException ignored) {}
        return names;
    }

    /**
     * Chỉ giữ các biến tuỳ chỉnh được dùng tới (trực tiếp hoặc qua biến khác) từ {@code roots} (L2).
     * Biến global không ai dùng (vd. đang lỗi chia 0) không làm hỏng lương mọi người.
     */
    public Map<String, String> keepReachable(Map<String, String> customVars, Set<String> roots) {
        Set<String> needed = new HashSet<>();
        java.util.Deque<String> stack = new java.util.ArrayDeque<>(roots);
        while (!stack.isEmpty()) {
            String name = stack.pop();
            if (!customVars.containsKey(name) || !needed.add(name)) continue;
            stack.addAll(referencedVariables(customVars.get(name)));
        }
        Map<String, String> result = new LinkedHashMap<>();
        customVars.forEach((k, v) -> { if (needed.contains(k)) result.put(k, v); });
        return result;
    }

    /**
     * Như {@link #resolveCustomVars} nhưng bỏ qua (chưa tính) các biến phụ thuộc — trực tiếp
     * hoặc gián tiếp — vào một tên trong {@code notYetAvailable} (vd. GROSS trước khi có GROSS) (L2).
     */
    public Map<String, BigDecimal> resolveCustomVarsExcept(
            Map<String, String> customVars, Map<String, BigDecimal> baseVars, Set<String> notYetAvailable) {
        Set<String> blocked = new HashSet<>(notYetAvailable);
        boolean changed = true;
        while (changed) {
            changed = false;
            for (Map.Entry<String, String> e : customVars.entrySet()) {
                if (blocked.contains(e.getKey())) continue;
                Set<String> refs = referencedVariables(e.getValue());
                refs.retainAll(blocked);
                if (!refs.isEmpty()) { blocked.add(e.getKey()); changed = true; }
            }
        }
        Map<String, String> ready = new LinkedHashMap<>();
        customVars.forEach((k, v) -> { if (!blocked.contains(k)) ready.put(k, v); });
        return resolveCustomVars(ready, baseVars);
    }

    /**
     * Validate custom variable expressions and detect circular references.
     * Returns list of error messages (empty = valid).
     */
    public List<String> validateCustomVars(Map<String, String> customVars, Set<String> systemVars) {
        List<String> errors = new ArrayList<>();
        Set<String> allAllowed = new HashSet<>(systemVars);
        allAllowed.addAll(customVars.keySet());

        for (Map.Entry<String, String> entry : customVars.entrySet()) {
            List<String> errs = validate(entry.getValue(), allAllowed);
            for (String e : errs) errors.add("[" + entry.getKey() + "] " + e);
        }

        // Circular check
        try {
            Map<String, BigDecimal> dummyBase = new HashMap<>();
            for (String v : systemVars) dummyBase.put(v, BigDecimal.ONE);
            resolveCustomVars(customVars, dummyBase);
        } catch (FormulaEvaluationException e) {
            errors.add(e.getMessage());
        }
        return errors;
    }

    public BigDecimal evaluate(String expression, Map<String, BigDecimal> vars) {
        Lexer lexer = new Lexer(expression);
        List<Token> tokens = lexer.tokenize();
        Parser parser = new Parser(tokens, vars, false);
        BigDecimal result = parser.parseExpr();
        if (parser.current().type != TokenType.EOF) {
            throw new FormulaEvaluationException("Unexpected token: " + parser.current().value);
        }
        return result.setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * Validates expression syntax and checks for literal division-by-zero.
     * Returns empty list if valid, otherwise a list of error messages.
     */
    public List<String> validate(String expression, Set<String> allowedVars) {
        List<String> errors = new ArrayList<>();
        List<Token> tokens;
        try {
            tokens = new Lexer(expression).tokenize();
        } catch (FormulaEvaluationException e) {
            errors.add("Lỗi cú pháp: " + e.getMessage());
            return errors;
        }

        // Check for unknown variables (FUNCTION tokens are always allowed if in BUILTIN_FUNCTIONS)
        for (Token t : tokens) {
            if (t.type == TokenType.VARIABLE && !allowedVars.contains(t.value)) {
                errors.add("Biến không hợp lệ: " + t.value);
            }
        }

        // Parse check
        try {
            // All vars = 1 to detect literal /0
            Map<String, BigDecimal> onesMap = new HashMap<>();
            for (String v : allowedVars) onesMap.put(v, BigDecimal.ONE);

            Parser parser = new Parser(tokens, onesMap, true);
            parser.parseExpr();
            if (parser.current().type != TokenType.EOF) {
                errors.add("Công thức có ký tự không hợp lệ ở cuối: " + parser.current().value);
            }
        } catch (FormulaEvaluationException e) {
            errors.add(e.getMessage());
        }

        return errors;
    }

    // ─── Exception ─────────────────────────────────────────────────────────────

    public static class FormulaEvaluationException extends RuntimeException {
        public FormulaEvaluationException(String msg) { super(msg); }
    }

    // ─── Token ─────────────────────────────────────────────────────────────────

    enum TokenType { NUMBER, VARIABLE, FUNCTION, PLUS, MINUS, STAR, SLASH, LPAREN, RPAREN, COMMA, GT, LT, GTE, LTE, EQ, NEQ, AND, OR, EOF }

    record Token(TokenType type, String value) {}

    // ─── Lexer ─────────────────────────────────────────────────────────────────

    static class Lexer {
        private final String src;
        private int pos = 0;

        Lexer(String src) { this.src = src.trim(); }

        List<Token> tokenize() {
            List<Token> tokens = new ArrayList<>();
            while (pos < src.length()) {
                char c = src.charAt(pos);
                if (Character.isWhitespace(c)) { pos++; continue; }
                if (c == '+') { tokens.add(new Token(TokenType.PLUS, "+")); pos++; }
                else if (c == '-') { tokens.add(new Token(TokenType.MINUS, "-")); pos++; }
                else if (c == '*') { tokens.add(new Token(TokenType.STAR, "*")); pos++; }
                else if (c == '/') { tokens.add(new Token(TokenType.SLASH, "/")); pos++; }
                else if (c == '(') { tokens.add(new Token(TokenType.LPAREN, "(")); pos++; }
                else if (c == ')') { tokens.add(new Token(TokenType.RPAREN, ")")); pos++; }
                else if (c == ',') { tokens.add(new Token(TokenType.COMMA, ",")); pos++; }
                else if (c == '>' && pos + 1 < src.length() && src.charAt(pos + 1) == '=') { tokens.add(new Token(TokenType.GTE, ">=")); pos += 2; }
                else if (c == '>') { tokens.add(new Token(TokenType.GT, ">")); pos++; }
                else if (c == '<' && pos + 1 < src.length() && src.charAt(pos + 1) == '=') { tokens.add(new Token(TokenType.LTE, "<=")); pos += 2; }
                else if (c == '<') { tokens.add(new Token(TokenType.LT, "<")); pos++; }
                else if (c == '=' && pos + 1 < src.length() && src.charAt(pos + 1) == '=') { tokens.add(new Token(TokenType.EQ, "==")); pos += 2; }
                else if (c == '!' && pos + 1 < src.length() && src.charAt(pos + 1) == '=') { tokens.add(new Token(TokenType.NEQ, "!=")); pos += 2; }
                else if (Character.isDigit(c) || c == '.') { tokens.add(readNumber()); }
                else if (Character.isUpperCase(c) || c == '_') { tokens.add(readVariable()); }
                else {
                    throw new FormulaEvaluationException("Ký tự không hợp lệ: '" + c + "'");
                }
            }
            tokens.add(new Token(TokenType.EOF, ""));
            return tokens;
        }

        private Token readNumber() {
            int start = pos;
            while (pos < src.length() && (Character.isDigit(src.charAt(pos)) || src.charAt(pos) == '.')) pos++;
            return new Token(TokenType.NUMBER, src.substring(start, pos));
        }

        private Token readVariable() {
            int start = pos;
            while (pos < src.length() && (Character.isUpperCase(src.charAt(pos)) || Character.isDigit(src.charAt(pos)) || src.charAt(pos) == '_')) pos++;
            String name = src.substring(start, pos);
            if (name.equals("AND")) return new Token(TokenType.AND, "AND");
            if (name.equals("OR"))  return new Token(TokenType.OR,  "OR");
            // Peek ahead: if followed by '(' it's a function call
            int peek = pos;
            while (peek < src.length() && Character.isWhitespace(src.charAt(peek))) peek++;
            if (peek < src.length() && src.charAt(peek) == '(' && BUILTIN_FUNCTIONS.contains(name)) {
                return new Token(TokenType.FUNCTION, name);
            }
            return new Token(TokenType.VARIABLE, name);
        }
    }

    // ─── Parser / Evaluator ────────────────────────────────────────────────────

    static class Parser {
        private final List<Token> tokens;
        private final Map<String, BigDecimal> vars;
        private final boolean staticCheck; // when true, /0 is a static error
        private int pos = 0;
        /** > 0 khi đang đọc nhánh IF không được chọn: chỉ phân tích cú pháp, không báo lỗi giá trị (L15). */
        private int skipDepth = 0;

        Parser(List<Token> tokens, Map<String, BigDecimal> vars, boolean staticCheck) {
            this.tokens = tokens;
            this.vars = vars;
            this.staticCheck = staticCheck;
        }

        Token current() { return tokens.get(pos); }

        Token consume(TokenType expected) {
            Token t = current();
            if (t.type != expected) {
                throw new FormulaEvaluationException(
                        "Mong đợi '" + expected + "' nhưng gặp '" + t.value + "'");
            }
            pos++;
            return t;
        }

        Token consumeAny() { return tokens.get(pos++); }

        // expr = or
        BigDecimal parseExpr() {
            return parseOr();
        }

        // or = and ('OR' and)*
        BigDecimal parseOr() {
            BigDecimal left = parseAnd();
            while (current().type == TokenType.OR) {
                consumeAny();
                BigDecimal right = parseAnd();
                left = (left.compareTo(BigDecimal.ZERO) != 0 || right.compareTo(BigDecimal.ZERO) != 0)
                    ? BigDecimal.ONE : BigDecimal.ZERO;
            }
            return left;
        }

        // and = comparison ('AND' comparison)*
        BigDecimal parseAnd() {
            BigDecimal left = parseComparison();
            while (current().type == TokenType.AND) {
                consumeAny();
                BigDecimal right = parseComparison();
                left = (left.compareTo(BigDecimal.ZERO) != 0 && right.compareTo(BigDecimal.ZERO) != 0)
                    ? BigDecimal.ONE : BigDecimal.ZERO;
            }
            return left;
        }

        // comparison = additive (('>' | '<' | '>=' | '<=' | '==' | '!=') additive)?
        BigDecimal parseComparison() {
            BigDecimal left = parseAdditive();
            TokenType op = current().type;
            if (op == TokenType.GT || op == TokenType.LT ||
                op == TokenType.GTE || op == TokenType.LTE ||
                op == TokenType.EQ || op == TokenType.NEQ) {
                consumeAny();
                BigDecimal right = parseAdditive();
                int cmp = left.compareTo(right);
                boolean result = switch (op) {
                    case GT  -> cmp > 0;
                    case LT  -> cmp < 0;
                    case GTE -> cmp >= 0;
                    case LTE -> cmp <= 0;
                    case EQ  -> cmp == 0;
                    case NEQ -> cmp != 0;
                    default  -> false;
                };
                return result ? BigDecimal.ONE : BigDecimal.ZERO;
            }
            return left;
        }

        // additive = term (('+' | '-') term)*
        BigDecimal parseAdditive() {
            BigDecimal left = parseTerm();
            while (current().type == TokenType.PLUS || current().type == TokenType.MINUS) {
                TokenType op = consumeAny().type;
                BigDecimal right = parseTerm();
                left = op == TokenType.PLUS ? left.add(right, MC) : left.subtract(right, MC);
            }
            return left;
        }

        // term = factor (('*' | '/') factor)*
        BigDecimal parseTerm() {
            BigDecimal left = parseFactor();
            while (current().type == TokenType.STAR || current().type == TokenType.SLASH) {
                TokenType op = consumeAny().type;
                BigDecimal right = parseFactor();
                if (op == TokenType.SLASH) {
                    if (right.compareTo(BigDecimal.ZERO) == 0) {
                        if (skipDepth > 0) { left = BigDecimal.ZERO; continue; }
                        if (staticCheck) {
                            throw new FormulaEvaluationException("Phép chia cho 0 trong công thức");
                        }
                        throw new FormulaEvaluationException("Lỗi chia cho 0 khi tính lương");
                    }
                    left = left.divide(right, MC);
                } else {
                    left = left.multiply(right, MC);
                }
            }
            return left;
        }

        // factor = NUMBER | VARIABLE | FUNCTION '(' expr ')' | '(' expr ')' | '-' factor
        BigDecimal parseFactor() {
            Token t = current();
            if (t.type == TokenType.NUMBER) {
                consumeAny();
                try {
                    return new BigDecimal(t.value);
                } catch (NumberFormatException e) {
                    throw new FormulaEvaluationException("Số không hợp lệ: " + t.value);
                }
            }
            if (t.type == TokenType.FUNCTION) {
                consumeAny();
                consume(TokenType.LPAREN);
                return switch (t.value) {
                    case "PIT_VN" -> {
                        BigDecimal arg = parseExpr();
                        consume(TokenType.RPAREN);
                        yield staticCheck ? BigDecimal.ONE : pitVN(arg);
                    }
                    case "IF" -> {
                        // Chỉ tính nhánh được chọn: IF(PRESENT_DAYS > 0, X / PRESENT_DAYS, 0) không lỗi chia 0
                        BigDecimal cond = parseExpr();
                        boolean takeTrue = staticCheck || skipDepth > 0 || cond.compareTo(BigDecimal.ZERO) != 0;
                        consume(TokenType.COMMA);
                        if (!takeTrue) skipDepth++;
                        BigDecimal trueVal = parseExpr();
                        if (!takeTrue) skipDepth--;
                        consume(TokenType.COMMA);
                        boolean skipFalse = takeTrue && !staticCheck && skipDepth == 0;
                        if (skipFalse) skipDepth++;
                        BigDecimal falseVal = parseExpr();
                        if (skipFalse) skipDepth--;
                        consume(TokenType.RPAREN);
                        yield takeTrue ? trueVal : falseVal;
                    }
                    case "ROUND" -> {
                        // ROUND(x) làm tròn tới đồng; ROUND(x, n) làm tròn n chữ số (n âm: tới hàng chục, trăm…)
                        BigDecimal arg = parseExpr();
                        int digits = 0;
                        if (current().type == TokenType.COMMA) {
                            consumeAny();
                            digits = parseExpr().intValue();
                        }
                        consume(TokenType.RPAREN);
                        yield arg.setScale(digits, RoundingMode.HALF_UP);
                    }
                    case "FLOOR" -> {
                        BigDecimal arg = parseExpr();
                        consume(TokenType.RPAREN);
                        yield arg.setScale(0, RoundingMode.FLOOR);
                    }
                    case "CEIL" -> {
                        BigDecimal arg = parseExpr();
                        consume(TokenType.RPAREN);
                        yield arg.setScale(0, RoundingMode.CEILING);
                    }
                    case "MIN" -> {
                        BigDecimal a = parseExpr();
                        consume(TokenType.COMMA);
                        BigDecimal b = parseExpr();
                        consume(TokenType.RPAREN);
                        yield a.min(b);
                    }
                    case "MAX" -> {
                        BigDecimal a = parseExpr();
                        consume(TokenType.COMMA);
                        BigDecimal b = parseExpr();
                        consume(TokenType.RPAREN);
                        yield a.max(b);
                    }
                    case "ABS" -> {
                        BigDecimal arg = parseExpr();
                        consume(TokenType.RPAREN);
                        yield arg.abs();
                    }
                    default -> throw new FormulaEvaluationException("Hàm không xác định: " + t.value);
                };
            }
            if (t.type == TokenType.VARIABLE) {
                consumeAny();
                BigDecimal val = vars.get(t.value);
                if (val == null) {
                    if (skipDepth > 0) return BigDecimal.ZERO;
                    throw new FormulaEvaluationException("Biến chưa được gán giá trị: " + t.value);
                }
                return val;
            }
            if (t.type == TokenType.LPAREN) {
                consumeAny();
                BigDecimal val = parseExpr();
                consume(TokenType.RPAREN);
                return val;
            }
            if (t.type == TokenType.MINUS) {
                consumeAny();
                return parseFactor().negate();
            }
            throw new FormulaEvaluationException("Token không mong đợi: '" + t.value + "'");
        }
    }
}
