-- LoveSpace initial relational schema.
-- All DATETIME values are UTC; date-only business values use Asia/Shanghai at the service boundary.
-- Empty strings used by the cloud-database implementation for missing relationships become NULL.

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

CREATE TABLE users (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nick_name VARCHAR(20) NOT NULL DEFAULT '',
    avatar_url VARCHAR(1024) NOT NULL DEFAULT '',
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    role VARCHAR(16) NULL,
    mood_today JSON NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_users_couple (couple_id),
    CONSTRAINT chk_users_role CHECK (role IS NULL OR role IN ('', 'creator', 'partner'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE couples (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    creator_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    partner_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    start_date DATE NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    invite_code CHAR(6) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    schema_version INT UNSIGNED NOT NULL DEFAULT 2,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    dissolved_at DATETIME(3) NULL,
    dissolved_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_couples_invite_code (invite_code),
    KEY idx_couples_status (status),
    KEY idx_couples_creator (creator_id),
    KEY idx_couples_partner (partner_id),
    CONSTRAINT fk_couples_creator FOREIGN KEY (creator_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_couples_partner FOREIGN KEY (partner_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_couples_dissolved_by FOREIGN KEY (dissolved_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_couples_status CHECK (status IN ('active', 'dissolved')),
    CONSTRAINT chk_couples_members CHECK (partner_id IS NULL OR creator_id <> partner_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

ALTER TABLE users
    ADD CONSTRAINT fk_users_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE TABLE couple_invites (
    invite_code CHAR(6) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    used_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    used_at DATETIME(3) NULL,
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (invite_code),
    UNIQUE KEY uk_couple_invites_couple (couple_id),
    KEY idx_couple_invites_created_by (created_by),
    KEY idx_couple_invites_used_by (used_by),
    CONSTRAINT fk_couple_invites_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_couple_invites_created_by FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_couple_invites_used_by FOREIGN KEY (used_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_couple_invites_status CHECK (status IN ('active', 'used', 'dissolved'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE media_assets (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    owner_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    object_key VARCHAR(1024) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    media_type VARCHAR(16) NOT NULL DEFAULT 'image',
    content_type VARCHAR(127) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
    size_bytes BIGINT UNSIGNED NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    deleted_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_media_assets_object_key (object_key),
    KEY idx_media_assets_owner_status (owner_id, status, created_at),
    KEY idx_media_assets_couple_status (couple_id, status, created_at),
    CONSTRAINT fk_media_assets_owner FOREIGN KEY (owner_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_media_assets_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_media_assets_type CHECK (media_type IN ('image', 'audio', 'other')),
    CONSTRAINT chk_media_assets_status CHECK (status IN ('active', 'pending', 'ready', 'failed', 'deleted'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE anniversaries (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(30) NOT NULL,
    date DATE NOT NULL,
    type VARCHAR(16) NOT NULL DEFAULT 'custom',
    cover_url VARCHAR(1024) NOT NULL DEFAULT '',
    note VARCHAR(500) NOT NULL DEFAULT '',
    is_repeat TINYINT(1) NOT NULL DEFAULT 1,
    remind_days_before SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    is_top TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_anniversaries_couple_top_date (couple_id, is_top, date),
    CONSTRAINT fk_anniversaries_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_anniversaries_type CHECK (type IN ('together', 'birthday', 'valentine', 'meet', 'first', 'custom')),
    CONSTRAINT chk_anniversaries_repeat CHECK (is_repeat IN (0, 1)),
    CONSTRAINT chk_anniversaries_top CHECK (is_top IN (0, 1)),
    CONSTRAINT chk_anniversaries_reminder CHECK (remind_days_before <= 365)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE albums (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(30) NOT NULL,
    cover_url VARCHAR(1024) NOT NULL DEFAULT '',
    photo_count INT UNSIGNED NOT NULL DEFAULT 0,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_albums_couple_created (couple_id, created_at),
    CONSTRAINT fk_albums_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_albums_default CHECK (is_default IN (0, 1))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE photos (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    album_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    file_id VARCHAR(1024) NOT NULL,
    thumb_file_id VARCHAR(1024) NOT NULL DEFAULT '',
    description VARCHAR(300) NOT NULL DEFAULT '',
    location VARCHAR(100) NOT NULL DEFAULT '',
    tags JSON NOT NULL,
    uploaded_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    is_favorite TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_photos_album_created (album_id, created_at),
    KEY idx_photos_couple_created (couple_id, created_at),
    KEY idx_photos_uploader (uploaded_by),
    CONSTRAINT fk_photos_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_photos_album FOREIGN KEY (album_id) REFERENCES albums (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_photos_uploader FOREIGN KEY (uploaded_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_photos_tags CHECK (JSON_TYPE(tags) = 'ARRAY'),
    CONSTRAINT chk_photos_favorite CHECK (is_favorite IN (0, 1))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE moments (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    author_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title VARCHAR(50) NOT NULL DEFAULT '',
    content TEXT NOT NULL,
    images JSON NOT NULL,
    voice_file_id VARCHAR(300) NULL,
    tags JSON NOT NULL,
    related_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    event_date DATE NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_moments_couple_created (couple_id, created_at),
    KEY idx_moments_couple_event (couple_id, event_date, created_at),
    KEY idx_moments_author (author_id),
    CONSTRAINT fk_moments_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_moments_author FOREIGN KEY (author_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_moments_images CHECK (JSON_TYPE(images) = 'ARRAY'),
    CONSTRAINT chk_moments_tags CHECK (JSON_TYPE(tags) = 'ARRAY')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE moods (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    mood_type VARCHAR(16) NOT NULL,
    mood_emoji VARCHAR(8) NOT NULL DEFAULT '',
    content VARCHAR(500) NOT NULL DEFAULT '',
    images JSON NOT NULL,
    visibility VARCHAR(8) NOT NULL DEFAULT 'both',
    date DATE NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_moods_couple_user_date (couple_id, user_id, date),
    KEY idx_moods_couple_date (couple_id, date),
    KEY idx_moods_user_visibility_created (user_id, visibility, created_at),
    CONSTRAINT fk_moods_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_moods_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_moods_type CHECK (mood_type IN ('happy', 'love', 'calm', 'excited', 'miss', 'grateful', 'tired', 'anxious', 'sad', 'angry')),
    CONSTRAINT chk_moods_visibility CHECK (visibility IN ('both', 'self')),
    CONSTRAINT chk_moods_images CHECK (JSON_TYPE(images) = 'ARRAY')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE daily_questions (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    date DATE NOT NULL,
    question VARCHAR(500) NOT NULL,
    category VARCHAR(20) NOT NULL,
    answers JSON NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_daily_questions_couple_date (couple_id, date),
    KEY idx_daily_questions_couple_created (couple_id, created_at),
    CONSTRAINT fk_daily_questions_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_daily_questions_answers CHECK (JSON_TYPE(answers) = 'OBJECT')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE points (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    from_user VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    to_user VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    amount INT NOT NULL,
    reason VARCHAR(128) NOT NULL,
    note VARCHAR(200) NOT NULL DEFAULT '',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_points_couple_created (couple_id, created_at),
    KEY idx_points_couple_recipient_created (couple_id, to_user, created_at),
    CONSTRAINT fk_points_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_points_recipient FOREIGN KEY (to_user) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_points_nonzero CHECK (amount <> 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE point_balances (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    score BIGINT NOT NULL DEFAULT 0,
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_point_balances_couple_user (couple_id, user_id),
    CONSTRAINT fk_point_balances_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_point_balances_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE point_exchanges (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(30) NOT NULL,
    cost INT UNSIGNED NOT NULL,
    icon VARCHAR(8) NOT NULL DEFAULT '🎁',
    created_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_point_exchanges_couple_created (couple_id, created_at),
    KEY idx_point_exchanges_creator (created_by),
    CONSTRAINT fk_point_exchanges_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_point_exchanges_creator FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_point_exchanges_cost CHECK (cost BETWEEN 1 AND 10000)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE point_exchange_records (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    exchange_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    item_name VARCHAR(30) NOT NULL,
    cost INT UNSIGNED NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_exchange_records_couple_created (couple_id, created_at),
    KEY idx_exchange_records_user (user_id),
    CONSTRAINT fk_exchange_records_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_exchange_records_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_exchange_records_cost CHECK (cost BETWEEN 1 AND 10000)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE dishes (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(40) NOT NULL,
    category VARCHAR(20) NOT NULL DEFAULT '主食',
    image_url VARCHAR(1024) NOT NULL DEFAULT '',
    tags JSON NOT NULL,
    rating DECIMAL(2, 1) NOT NULL DEFAULT 5.0,
    location VARCHAR(100) NOT NULL DEFAULT '',
    note VARCHAR(500) NOT NULL DEFAULT '',
    price DECIMAL(12, 2) NOT NULL DEFAULT 0,
    description TEXT NOT NULL,
    specs JSON NOT NULL,
    is_available TINYINT(1) NOT NULL DEFAULT 1,
    last_eaten_at DATE NULL,
    added_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    KEY idx_dishes_couple_rating (couple_id, rating),
    KEY idx_dishes_couple_category_rating (couple_id, category, rating),
    KEY idx_dishes_added_by (added_by),
    CONSTRAINT fk_dishes_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_dishes_added_by FOREIGN KEY (added_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_dishes_tags CHECK (JSON_TYPE(tags) = 'ARRAY'),
    CONSTRAINT chk_dishes_specs CHECK (JSON_TYPE(specs) = 'ARRAY'),
    CONSTRAINT chk_dishes_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_dishes_price CHECK (price >= 0),
    CONSTRAINT chk_dishes_available CHECK (is_available IN (0, 1))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE orders (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    items JSON NOT NULL,
    total_price DECIMAL(14, 2) NOT NULL,
    note VARCHAR(200) NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'placed',
    ordered_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_orders_couple_created (couple_id, created_at),
    KEY idx_orders_ordered_by (ordered_by),
    CONSTRAINT fk_orders_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_orders_ordered_by FOREIGN KEY (ordered_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_orders_items CHECK (JSON_TYPE(items) = 'ARRAY'),
    CONSTRAINT chk_orders_total CHECK (total_price >= 0),
    CONSTRAINT chk_orders_status CHECK (status IN ('placed'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE menu_categories (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(20) NOT NULL,
    icon VARCHAR(8) NOT NULL DEFAULT '🍽️',
    sort_order SMALLINT NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_menu_categories_couple_sort (couple_id, sort_order),
    CONSTRAINT fk_menu_categories_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_menu_categories_sort CHECK (sort_order BETWEEN -10000 AND 10000)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE tasks (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title VARCHAR(50) NOT NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    type VARCHAR(32) NOT NULL DEFAULT 'single',
    assignee VARCHAR(16) NOT NULL DEFAULT 'both',
    reward_points SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    completed_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    due_date DATE NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    completed_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    KEY idx_tasks_couple_status_created (couple_id, status, created_at),
    KEY idx_tasks_created_by (created_by),
    KEY idx_tasks_completed_by (completed_by),
    CONSTRAINT fk_tasks_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_tasks_created_by FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_tasks_completed_by FOREIGN KEY (completed_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_tasks_assignee CHECK (assignee IN ('me', 'partner', 'both')),
    CONSTRAINT chk_tasks_reward CHECK (reward_points <= 100),
    CONSTRAINT chk_tasks_status CHECK (status IN ('pending', 'completed'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE wishes (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title VARCHAR(80) NOT NULL,
    description TEXT NOT NULL,
    image_url VARCHAR(1024) NOT NULL DEFAULT '',
    created_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'todo',
    completed_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_wishes_couple_status_created (couple_id, status, created_at),
    KEY idx_wishes_created_by (created_by),
    CONSTRAINT fk_wishes_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_wishes_created_by FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_wishes_status CHECK (status IN ('todo', 'doing', 'done'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE capsules (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    author_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    images JSON NOT NULL,
    voice_file_id VARCHAR(300) NULL,
    unlock_date DATE NOT NULL,
    is_unlocked TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_capsules_couple_unlocked_date (couple_id, is_unlocked, unlock_date),
    KEY idx_capsules_author (author_id),
    CONSTRAINT fk_capsules_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_capsules_author FOREIGN KEY (author_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_capsules_images CHECK (JSON_TYPE(images) = 'ARRAY'),
    CONSTRAINT chk_capsules_unlocked CHECK (is_unlocked IN (0, 1))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE quizzes (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    question VARCHAR(255) NOT NULL,
    options JSON NOT NULL,
    user1_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    user1_answer VARCHAR(255) NOT NULL DEFAULT '',
    user2_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    user2_answer VARCHAR(255) NOT NULL DEFAULT '',
    is_matched TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_quizzes_couple_question (couple_id, question),
    KEY idx_quizzes_couple_created (couple_id, created_at),
    KEY idx_quizzes_user1 (user1_id),
    KEY idx_quizzes_user2 (user2_id),
    CONSTRAINT fk_quizzes_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_quizzes_user1 FOREIGN KEY (user1_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_quizzes_user2 FOREIGN KEY (user2_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_quizzes_options CHECK (JSON_TYPE(options) = 'ARRAY'),
    CONSTRAINT chk_quizzes_matched CHECK (is_matched IN (0, 1)),
    CONSTRAINT chk_quizzes_distinct_users CHECK (user2_id IS NULL OR user1_id <> user2_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE notifications (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    to_user VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    from_user VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    from_name VARCHAR(50) NOT NULL DEFAULT '',
    type VARCHAR(32) NOT NULL,
    title VARCHAR(50) NOT NULL,
    content VARCHAR(500) NOT NULL,
    related_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    is_read TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_notifications_recipient_unread (couple_id, to_user, is_read, created_at),
    CONSTRAINT fk_notifications_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_notifications_recipient FOREIGN KEY (to_user) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_notifications_read CHECK (is_read IN (0, 1))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE fitness_goals (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    goal_type VARCHAR(16) NOT NULL DEFAULT 'fat-loss',
    current_weight DECIMAL(5, 1) NULL,
    target_weight DECIMAL(5, 1) NULL,
    height DECIMAL(4, 1) NULL,
    age TINYINT UNSIGNED NULL,
    biological_sex VARCHAR(8) NULL,
    weekly_workouts TINYINT UNSIGNED NOT NULL DEFAULT 3,
    daily_steps INT UNSIGNED NOT NULL DEFAULT 8000,
    privacy VARCHAR(16) NOT NULL DEFAULT 'trend',
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_fitness_goals_couple_user (couple_id, user_id),
    CONSTRAINT fk_fitness_goals_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_fitness_goals_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_fitness_goals_type CHECK (goal_type IN ('fat-loss', 'muscle', 'shape')),
    CONSTRAINT chk_fitness_goals_weight CHECK ((current_weight IS NULL OR current_weight BETWEEN 30 AND 300) AND (target_weight IS NULL OR target_weight BETWEEN 30 AND 300)),
    CONSTRAINT chk_fitness_goals_profile CHECK ((height IS NULL OR height BETWEEN 120 AND 230) AND (age IS NULL OR age BETWEEN 18 AND 80) AND (biological_sex IS NULL OR biological_sex IN ('male', 'female'))),
    CONSTRAINT chk_fitness_goals_targets CHECK (weekly_workouts BETWEEN 1 AND 7 AND daily_steps BETWEEN 1000 AND 50000),
    CONSTRAINT chk_fitness_goals_privacy CHECK (privacy IN ('private', 'trend', 'shared'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE fitness_checkins (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    date DATE NOT NULL,
    workouts JSON NOT NULL,
    workout_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    workout_type VARCHAR(16) NOT NULL DEFAULT 'rest',
    minutes SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    calories SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    steps INT UNSIGNED NOT NULL DEFAULT 0,
    water TINYINT UNSIGNED NOT NULL DEFAULT 0,
    sleep DECIMAL(3, 1) NOT NULL DEFAULT 0,
    healthy_meal TINYINT(1) NOT NULL DEFAULT 0,
    weight DECIMAL(5, 1) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_fitness_checkins_couple_user_date (couple_id, user_id, date),
    KEY idx_fitness_checkins_couple_date (couple_id, date),
    CONSTRAINT fk_fitness_checkins_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_fitness_checkins_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_fitness_checkins_workouts CHECK (JSON_TYPE(workouts) = 'ARRAY'),
    CONSTRAINT chk_fitness_checkins_workout_count CHECK (workout_count <= 12),
    CONSTRAINT chk_fitness_checkins_workout_type CHECK (workout_type IN ('rest', 'strength', 'run', 'walk', 'cycle', 'swim', 'yoga', 'other')),
    CONSTRAINT chk_fitness_checkins_steps CHECK (steps <= 100000),
    CONSTRAINT chk_fitness_checkins_water CHECK (water <= 20),
    CONSTRAINT chk_fitness_checkins_sleep CHECK (sleep BETWEEN 0 AND 24),
    CONSTRAINT chk_fitness_checkins_meal CHECK (healthy_meal IN (0, 1)),
    CONSTRAINT chk_fitness_checkins_weight CHECK (weight IS NULL OR weight BETWEEN 30 AND 300)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE fitness_challenges (
    id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    couple_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    preset_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title VARCHAR(100) NOT NULL,
    metric VARCHAR(16) NOT NULL,
    target INT UNSIGNED NOT NULL,
    unit VARCHAR(16) NOT NULL,
    reward_points SMALLINT UNSIGNED NOT NULL DEFAULT 10,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_by VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_date DATE NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    completed_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_fitness_challenges_daily_preset (couple_id, preset_id, created_date),
    KEY idx_fitness_challenges_active (couple_id, status, end_date),
    KEY idx_fitness_challenges_created (couple_id, created_date),
    KEY idx_fitness_challenges_creator (created_by),
    CONSTRAINT fk_fitness_challenges_couple FOREIGN KEY (couple_id) REFERENCES couples (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_fitness_challenges_creator FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_fitness_challenges_metric CHECK (metric IN ('workouts', 'minutes', 'steps', 'checkins')),
    CONSTRAINT chk_fitness_challenges_target CHECK (target > 0),
    CONSTRAINT chk_fitness_challenges_reward CHECK (reward_points > 0),
    CONSTRAINT chk_fitness_challenges_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_fitness_challenges_status CHECK (status IN ('active', 'completed'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
