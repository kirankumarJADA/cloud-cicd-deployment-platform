package com.platform.controller;

import com.platform.dto.DashboardDtos.DashboardResponse;
import com.platform.dto.DashboardDtos.ProfileResponse;
import com.platform.service.DashboardService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping("/me")
    public ResponseEntity<ProfileResponse> me(Authentication authentication) {
        return ResponseEntity.ok(
                dashboardService.profile(authentication.getName()));
    }

    @GetMapping("/dashboard")
    public ResponseEntity<DashboardResponse> dashboard() {
        return ResponseEntity.ok(dashboardService.dashboard());
    }
}
