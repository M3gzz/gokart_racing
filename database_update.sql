CREATE TABLE IF NOT EXISTS `gokart_racing_tracks` (
    `track_id` VARCHAR(50) PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `laps` INT NOT NULL DEFAULT 3,
    `start_positions` LONGTEXT NOT NULL, -- JSON array of vector4s
    `checkpoints` LONGTEXT NOT NULL,     -- JSON array of vector3s
    `created_by` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
