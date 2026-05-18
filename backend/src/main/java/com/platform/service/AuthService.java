package com.platform.service;

import com.platform.dto.AuthDtos.AuthResponse;
import com.platform.dto.AuthDtos.LoginRequest;
import com.platform.dto.AuthDtos.RegisterRequest;
import com.platform.entity.User;
import com.platform.exception.ApiException;
import com.platform.repository.UserRepository;
import com.platform.security.JwtTokenProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider tokenProvider) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByUsername(request.username())) {
            throw new ApiException(HttpStatus.CONFLICT, "Username already taken");
        }
        if (userRepository.existsByEmail(request.email())) {
            throw new ApiException(HttpStatus.CONFLICT, "Email already registered");
        }

        User user = new User();
        user.setUsername(request.username());
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(User.Role.USER);
        userRepository.save(user);

        log.info("Registered new user username={}", user.getUsername());
        return issueToken(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByUsername(request.username())
                .orElseThrow(() -> new ApiException(
                        HttpStatus.UNAUTHORIZED, "Invalid username or password"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            log.warn("Failed login attempt username={}", request.username());
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "Invalid username or password");
        }

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);
        log.info("Successful login username={}", user.getUsername());
        return issueToken(user);
    }

    private AuthResponse issueToken(User user) {
        String token = tokenProvider.generateToken(
                user.getUsername(), user.getRole().name());
        return new AuthResponse(
                token,
                "Bearer",
                tokenProvider.getValiditySeconds(),
                user.getUsername(),
                user.getRole().name());
    }
}
