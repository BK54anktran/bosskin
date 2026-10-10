package com.bosskin.entity;

import java.time.LocalDateTime;

/** Bước K — đơn có bước quản lý trực tiếp duyệt trước (chế độ MANAGER_THEN_HR). */
public interface ManagerApprovable {
    User getManagerApprovedBy();
    void setManagerApprovedBy(User user);
    LocalDateTime getManagerApprovedAt();
    void setManagerApprovedAt(LocalDateTime at);
    String getManagerNote();
    void setManagerNote(String note);
}
