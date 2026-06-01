package com.bosskin.repository;

import com.bosskin.entity.Department;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface DepartmentRepository extends JpaRepository<Department, Long> {

    List<Department> findByCompanyIdAndParentIsNullOrderByName(Long companyId);
    List<Department> findByCompanyIdOrderByLevelAscNameAsc(Long companyId);
    List<Department> findByParentIdIn(Collection<Long> parentIds);
    Optional<Department> findByIdAndCompanyId(Long id, Long companyId);
    boolean existsByCodeAndCompanyId(String code, Long companyId);
    boolean existsByCodeAndCompanyIdAndIdNot(String code, Long companyId, Long id);
    long countByParentIdAndCompanyId(Long parentId, Long companyId);

    /** Soft-delete trực tiếp bằng SQL — bypass Hibernate cache, dùng khi xóa nhiều record cùng lúc. */
    @Modifying
    @Query("UPDATE Department d SET d.deleted = true WHERE d.id IN :ids")
    void softDeleteByIds(@Param("ids") Collection<Long> ids);

    /** Tách parent cho các phòng con — dùng trước khi soft-delete parent. */
    @Modifying
    @Query("UPDATE Department d SET d.parent = null, d.level = 0 WHERE d.parent.id IN :parentIds AND d.deleted = false")
    void detachChildrenOfParents(@Param("parentIds") Collection<Long> parentIds);
}
