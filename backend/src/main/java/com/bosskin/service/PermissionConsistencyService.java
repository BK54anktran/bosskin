package com.bosskin.service;

import com.bosskin.entity.Permission;
import com.bosskin.repository.PermissionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PermissionConsistencyService {

    private final PermissionRepository permissionRepository;

    public Set<String> normalizePermissionCodes(Collection<String> requestedCodes) {
        if (requestedCodes == null || requestedCodes.isEmpty()) {
            return new LinkedHashSet<>();
        }

        Map<String, Permission> byCode = permissionRepository.findAll().stream()
            .collect(Collectors.toMap(Permission::getCode, Function.identity()));

        Set<String> selected = requestedCodes.stream()
            .filter(Objects::nonNull)
            .filter(byCode::containsKey)
            .collect(Collectors.toCollection(LinkedHashSet::new));

        if (selected.isEmpty()) {
            return selected;
        }

        Map<String, String> moduleViewCode = byCode.values().stream()
            .filter(p -> p.getCode() != null && p.getCode().endsWith("_VIEW"))
            .collect(Collectors.toMap(
                Permission::getModule,
                Permission::getCode,
                // Prefer the canonical "<MODULE>_VIEW" code over sub-module variants
                (a, b) -> {
                    String moduleOfA = byCode.get(a) != null ? byCode.get(a).getModule() : "";
                    if ((moduleOfA + "_VIEW").equals(a)) return a;
                    String moduleOfB = byCode.get(b) != null ? byCode.get(b).getModule() : "";
                    if ((moduleOfB + "_VIEW").equals(b)) return b;
                    return a;
                }
            ));

        Set<String> modulesNeedingView = new LinkedHashSet<>();
        for (String code : selected) {
            Permission p = byCode.get(code);
            if (p != null && !code.endsWith("_VIEW")) {
                modulesNeedingView.add(p.getModule());
            }
        }
        for (String module : modulesNeedingView) {
            String viewCode = moduleViewCode.get(module);
            if (viewCode != null) {
                selected.add(viewCode);
            }
        }

        Set<String> selectedViews = selected.stream()
            .filter(code -> code.endsWith("_VIEW"))
            .collect(Collectors.toSet());

        return selected.stream()
            .filter(code -> {
                if (code.endsWith("_VIEW")) {
                    return true;
                }
                Permission p = byCode.get(code);
                if (p == null) {
                    return false;
                }
                String viewCode = moduleViewCode.get(p.getModule());
                return viewCode == null || selectedViews.contains(viewCode);
            })
            .collect(Collectors.toCollection(LinkedHashSet::new));
    }

    public Map<String, List<Long>> filterScopesByPermissionCodes(
        Map<String, ? extends Collection<Long>> rawScopes,
        Collection<String> allowedCodes
    ) {
        Map<String, List<Long>> result = new LinkedHashMap<>();
        if (rawScopes == null || rawScopes.isEmpty()) {
            return result;
        }
        Set<String> allowedSet = allowedCodes == null
            ? new LinkedHashSet<>()
            : allowedCodes.stream().filter(Objects::nonNull).collect(Collectors.toSet());

        rawScopes.forEach((perm, ids) -> {
            if (!allowedSet.contains(perm)) {
                return;
            }
            List<Long> cleanIds = ids == null
                ? List.of()
                : ids.stream().filter(Objects::nonNull).distinct().toList();
            result.put(perm, cleanIds);
        });
        return result;
    }
}
