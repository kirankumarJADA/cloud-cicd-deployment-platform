-- V1: core schema for the sample production application.

CREATE TABLE users (
    id            BIGSERIAL    PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL UNIQUE,
    email         VARCHAR(120) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    role          VARCHAR(16)  NOT NULL DEFAULT 'USER',
    created_at    TIMESTAMP    NOT NULL DEFAULT now(),
    last_login_at TIMESTAMP
);

CREATE INDEX idx_users_username ON users (username);

-- Seed admin account.
-- Username: admin   Password: AdminPass123   (BCrypt, strength 10)
-- CHANGE THIS IN PRODUCTION immediately after first login.
INSERT INTO users (username, email, password_hash, role, created_at)
VALUES (
    'admin',
    'admin@platform.local',
    '$2a$10$ZtGAW6MCwUnDDqrGEXjXBe3USiR/PW40Aapz2w8Aa2RBSeqXksuge',
    'ADMIN',
    now()
);
