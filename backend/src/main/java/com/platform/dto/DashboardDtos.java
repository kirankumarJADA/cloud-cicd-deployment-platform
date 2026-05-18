package com.platform.dto;

import java.time.Instant;
import java.util.List;

public final class DashboardDtos {

    private DashboardDtos() {
    }

    public record ProfileResponse(
            Long id,
            String username,
            String email,
            String role,
            Instant createdAt,
            Instant lastLoginAt
    ) {
    }

    public record DeploymentEvent(
            String stage,
            String status,
            Instant timestamp
    ) {
    }

    public record DashboardResponse(
            String serviceName,
            String version,
            String environment,
            long totalUsers,
            long uptimeSeconds,
            List<DeploymentEvent> recentDeployments
    ) {
    }
}
