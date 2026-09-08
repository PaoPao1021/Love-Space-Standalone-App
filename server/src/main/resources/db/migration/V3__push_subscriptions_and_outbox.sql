-- Provider-neutral push registrations and a durable notification outbox.

CREATE TABLE push_subscriptions (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    device_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    platform VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    provider VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    endpoint VARCHAR(2048) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    public_key VARCHAR(256) CHARACTER SET ascii COLLATE ascii_bin NULL,
    auth_secret VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
    status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL DEFAULT 'active',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    last_success_at DATETIME(3) NULL,
    last_failure_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_push_subscriptions_user_device (user_id, device_id),
    KEY idx_push_subscriptions_user_active (user_id, status),
    CONSTRAINT fk_push_subscriptions_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT chk_push_subscriptions_platform CHECK (platform IN ('android', 'web')),
    CONSTRAINT chk_push_subscriptions_provider CHECK (provider IN ('getui', 'webpush')),
    CONSTRAINT chk_push_subscriptions_status CHECK (status IN ('active', 'disabled'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE notification_outbox (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    notification_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL DEFAULT 'pending',
    attempt_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    last_error VARCHAR(500) NOT NULL DEFAULT '',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    sent_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_notification_outbox_notification (notification_id),
    KEY idx_notification_outbox_due (status, next_attempt_at),
    CONSTRAINT fk_notification_outbox_notification FOREIGN KEY (notification_id) REFERENCES notifications (id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_notification_outbox_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT chk_notification_outbox_status CHECK (status IN ('pending', 'sent', 'failed', 'dead')),
    CONSTRAINT chk_notification_outbox_attempts CHECK (attempt_count <= 20)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
