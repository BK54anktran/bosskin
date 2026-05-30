package com.bosskin.security;

import com.bosskin.repository.SystemAdminRepository;
import com.bosskin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;
    private final SystemAdminRepository systemAdminRepository;

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        // Thử company user trước, sau đó system admin
        return userRepository.findByEmail(email)
            .map(u -> (UserDetails) u)
            .orElseGet(() -> systemAdminRepository.findByEmail(email)
                .map(a -> (UserDetails) a)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + email)));
    }
}
