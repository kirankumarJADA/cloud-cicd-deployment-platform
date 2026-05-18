package com.platform.security;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtTokenProviderTest {

    private static final String SECRET =
            "unit-test-secret-key-that-is-definitely-long-enough-256bit";

    private final JwtTokenProvider provider = new JwtTokenProvider(SECRET, 3600);

    @Test
    void generatesAndValidatesToken() {
        String token = provider.generateToken("alice", "ADMIN");

        assertTrue(provider.isValid(token));
        assertEquals("alice", provider.getUsername(token));
        assertEquals("ADMIN", provider.getRole(token));
        assertEquals(3600, provider.getValiditySeconds());
    }

    @Test
    void rejectsTamperedToken() {
        String token = provider.generateToken("bob", "USER");
        String tampered = token.substring(0, token.length() - 2) + "xx";

        assertFalse(provider.isValid(tampered));
    }

    @Test
    void rejectsTokenSignedWithDifferentKey() {
        JwtTokenProvider other = new JwtTokenProvider(
                "a-completely-different-secret-key-also-long-enough-here", 3600);
        String foreignToken = other.generateToken("eve", "USER");

        assertFalse(provider.isValid(foreignToken));
    }

    @Test
    void rejectsTooShortSecret() {
        assertThrows(IllegalStateException.class,
                () -> new JwtTokenProvider("short", 3600));
    }
}
