package com.bosskin.util;

import org.apache.poi.ss.usermodel.Cell;

/**
 * D9 — giữ số 0 đầu của SĐT, CCCD, số tài khoản khi đọc / ghi Excel.
 *
 * <ul>
 *   <li>Khi xuất: cột chữ được định dạng Text ("@"), nên ô người dùng gõ thêm vẫn là chữ.</li>
 *   <li>Khi đọc ô số: theo định dạng hiển thị kiểu "0000000000" thì bù số 0 cho đủ độ dài.</li>
 *   <li>SĐT / CCCD Việt Nam đã mất số 0 (9 / 11 chữ số) thì bù lại một số 0.</li>
 * </ul>
 */
public final class ExcelText {

    public static final String TEXT_FORMAT = "@";

    private ExcelText() {}

    /** Ô kiểu số → chuỗi; số nguyên giữ đủ chữ số theo định dạng toàn số 0 của ô. */
    public static String numeric(Cell cell) {
        double d = cell.getNumericCellValue();
        if (d != Math.floor(d) || Double.isInfinite(d)) return String.valueOf(d);
        String s = String.valueOf((long) d);
        String fmt = cell.getCellStyle() == null ? null : cell.getCellStyle().getDataFormatString();
        if (fmt != null && fmt.matches("0+") && s.length() < fmt.length()) {
            s = "0".repeat(fmt.length() - s.length()) + s;
        }
        return s;
    }

    /** SĐT di động / cố định VN có 10 chữ số bắt đầu bằng 0; Excel lưu dạng số còn 9 chữ số. */
    public static String phone(String v) {
        if (v == null) return null;
        String t = v.trim();
        return t.matches("[1-9]\\d{8}") ? "0" + t : t;
    }

    /**
     * CCCD 12 chữ số luôn bắt đầu bằng mã tỉnh 001–096 (Excel dạng số mất 1–2 số 0 → còn 10–11 chữ số);
     * CMND 9 chữ số có thể bắt đầu bằng 0 (còn 8 chữ số).
     */
    public static String identityCard(String v) {
        if (v == null) return null;
        String t = v.trim();
        if (t.matches("\\d{10,11}")) return "0".repeat(12 - t.length()) + t;
        if (t.matches("\\d{8}")) return "0" + t;
        return t;
    }
}
