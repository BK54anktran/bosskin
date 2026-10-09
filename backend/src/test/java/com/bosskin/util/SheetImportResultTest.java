package com.bosskin.util;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import static org.assertj.core.api.Assertions.assertThat;

/** Dòng import lỗi phải mang mã lỗi trần ("error.x.y|tham số") để FE dịch, không kèm "400 BAD_REQUEST". */
class SheetImportResultTest {

    @Test
    void responseStatusMessage_keepsOnlyErrorKey() {
        var e = new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.attendance.invalid_date|32/13/2026");
        var row = SheetImportResult.RowResult.error(5, e.getMessage());
        assertThat(row.message()).isEqualTo("error.attendance.invalid_date|32/13/2026");
        assertThat(row.status()).isEqualTo("ERROR");
    }

    @Test
    void notFoundStatus_andWarn_areCleanedToo() {
        var e = new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found|EMP9");
        assertThat(SheetImportResult.RowResult.warn(1, e.getMessage()).message()).isEqualTo("error.employee.not_found|EMP9");
    }

    @Test
    void plainKeysAndNull_areUnchanged() {
        assertThat(SheetImportResult.RowResult.error(1, "error.leaveGrant.emp_required").message())
            .isEqualTo("error.leaveGrant.emp_required");
        assertThat(SheetImportResult.RowResult.error(1, null).message()).isNull();
    }
}
