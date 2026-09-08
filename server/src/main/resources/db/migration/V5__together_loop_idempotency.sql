-- Idempotency for the second-stage task and menu creation flows.

ALTER TABLE tasks
    ADD COLUMN client_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER created_by,
    ADD UNIQUE KEY uk_tasks_request (created_by, client_request_id);

ALTER TABLE dishes
    ADD COLUMN client_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER added_by,
    ADD UNIQUE KEY uk_dishes_request (added_by, client_request_id);
