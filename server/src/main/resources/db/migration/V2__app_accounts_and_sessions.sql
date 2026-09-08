-- Native/PWA account credentials and revocable refresh sessions.
-- username/password_hash stay nullable so existing local WeChat/dev identities continue to work.

ALTER TABLE users
    ADD COLUMN username VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NULL AFTER id,
    ADD COLUMN password_hash VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER username,
    ADD COLUMN enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER password_hash,
    ADD COLUMN auth_version INT UNSIGNED NOT NULL DEFAULT 0 AFTER enabled,
    ADD COLUMN last_login_at DATETIME(3) NULL AFTER auth_version,
    ADD UNIQUE KEY uk_users_username (username),
    ADD CONSTRAINT chk_users_enabled CHECK (enabled IN (0, 1));

CREATE TABLE refresh_sessions (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    client_type VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    device_name VARCHAR(80) NOT NULL DEFAULT '',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3) NOT NULL,
    revoked_at DATETIME(3) NULL,
    replaced_by CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_refresh_sessions_token_hash (token_hash),
    KEY idx_refresh_sessions_user_active (user_id, revoked_at, expires_at),
    CONSTRAINT fk_refresh_sessions_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_refresh_sessions_replacement FOREIGN KEY (replaced_by) REFERENCES refresh_sessions (id)
        ON DELETE SET NULL ON UPDATE RESTRICT,
    CONSTRAINT chk_refresh_sessions_client CHECK (client_type IN ('android', 'web', 'legacy'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
