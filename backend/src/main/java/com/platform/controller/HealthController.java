package com.platform.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

/**
 * Lightweight, unauthenticated liveness endpoint used by load balancers and the
 * deployment scripts' smoke tests. The richer health detail lives under
 * {@code /actuator/health}.
 */
@RestController
@RequestMapping("/api/public")
public class HealthController {

    private final String version;

    public HealthController(@Value("${app.version:1.0.0}") String version) {
        this.version = version;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
                "status", "UP",
                "service", "cloud-cicd-deployment-platform",
                "version", version,
                "timestamp", Instant.now().toString());
    }
}
