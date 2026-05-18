package com.platform.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Map;

/**
 * Issues and validates HS256 JWTs. The signing secret is injected from the
 * {@code JWT_SECRET} environment variable — never hardcoded.
 */
@Component
public class JwtTokenProvider {

    private final SecretKey signingKey;
    private final long validitySeconds;

    public JwtTokenProvider(
            @Value("${security.jwt.secret}") String secret,
            @Value("${security.jwt.expiration-seconds:3600}") long validitySeconds) {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException(
                    "JWT_SECRET must be set and at least 32 bytes long for HS256 signing.");
        }
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.validitySeconds = validitySeconds;
    }

    public String generateToken(String username, String role) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + validitySeconds * 1000);
        return Jwts.builder()
                .subject(username)
                .claims(Map.of("role", role))
                .issuedAt(now)
                .expiration(expiry)
                .signWith(signingKey)
                .compact();
    }

    public boolean isValid(String token) {
        try {
            parse(token);
            return true;
        } catch (Exception ex) {
            return false;
        }
    }

    public String getUsername(String token) {
        return parse(token).getSubject();
    }

    public String getRole(String token) {
        Object role = parse(token).get("role");
        return role == null ? "USER" : role.toString();
    }

    public long getValiditySeconds() {
        return validitySeconds;
    }

    private Claims parse(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
