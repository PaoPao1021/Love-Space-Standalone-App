-- Idempotency for wish and time-capsule creation retries.

ALTER TABLE wishes
    ADD COLUMN client_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER created_by,
    ADD UNIQUE KEY uk_wishes_request (created_by, client_request_id);

ALTER TABLE capsules
    ADD COLUMN client_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER author_id,
    ADD UNIQUE KEY uk_capsules_request (author_id, client_request_id);
