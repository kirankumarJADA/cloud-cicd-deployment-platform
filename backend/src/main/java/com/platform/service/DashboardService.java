package com.platform.service;

import com.platform.dto.DashboardDtos.DashboardResponse;
import com.platform.dto.DashboardDtos.DeploymentEvent;
import com.platform.dto.DashboardDtos.ProfileResponse;
import com.platform.entity.User;
import com.platform.exception.ApiException;
import com.platform.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.lang.management.ManagementFactory;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class DashboardService {

    private final UserRepository userRepository;
    private final String appVersion;
    private final String environment;

    public DashboardService(UserRepository userRepository,
                            @Value("${app.version:1.0.0}") String appVersion,
                            @Value("${app.environment:local}") String environment) {
        this.userRepository = userRepository;
        this.appVersion = appVersion;
        this.environment = environment;
    }

    public ProfileResponse profile(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "User not found"));
        return new ProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.getRole().name(),
                user.getCreatedAt(),
                user.getLastLoginAt());
    }

    public DashboardResponse dashboard() {
        long uptimeMs = ManagementFactory.getRuntimeMXBean().getUptime();
        long uptimeSeconds = uptimeMs / 1000;
        Instant now = Instant.now();

        List<DeploymentEvent> recent = List.of(
                new DeploymentEvent("backend-test", "SUCCESS",
                        now.minus(14, ChronoUnit.MINUTES)),
                new DeploymentEvent("frontend-build", "SUCCESS",
                        now.minus(12, ChronoUnit.MINUTES)),
                new DeploymentEvent("docker-build", "SUCCESS",
                        now.minus(9, ChronoUnit.MINUTES)),
                new DeploymentEvent("image-push", "SUCCESS",
                        now.minus(7, ChronoUnit.MINUTES)),
                new DeploymentEvent("deploy-production", "SUCCESS",
                        now.minus(4, ChronoUnit.MINUTES)));

        return new DashboardResponse(
                "cloud-cicd-deployment-platform",
                appVersion,
                environment,
                userRepository.count(),
                uptimeSeconds,
                recent);
    }
}
