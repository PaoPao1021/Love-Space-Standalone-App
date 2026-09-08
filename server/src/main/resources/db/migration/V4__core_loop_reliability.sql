-- Core-loop idempotency and leased outbox delivery.

ALTER TABLE albums
    ADD COLUMN client_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER couple_id,
    ADD UNIQUE KEY uk_albums_request (couple_id, client_request_id);

ALTER TABLE moments
    ADD COLUMN client_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER author_id,
    ADD UNIQUE KEY uk_moments_request (author_id, client_request_id);

ALTER TABLE photos
    ADD COLUMN client_request_id VARCHAR(96) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER uploaded_by,
    ADD UNIQUE KEY uk_photos_request (uploaded_by, client_request_id);

ALTER TABLE notification_outbox
    ADD COLUMN lease_owner VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER next_attempt_at,
    ADD COLUMN lease_until DATETIME(3) NULL AFTER lease_owner,
    ADD COLUMN updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
        ON UPDATE CURRENT_TIMESTAMP(3) AFTER created_at,
    ADD KEY idx_notification_outbox_lease (status, next_attempt_at, lease_until);
