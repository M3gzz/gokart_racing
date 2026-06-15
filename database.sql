CREATE TABLE IF NOT EXISTS `gokart_racing_records` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `track_id` VARCHAR(50) NOT NULL,
    `best_time` INT NOT NULL, -- Store time in milliseconds
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_track_id` (`track_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gokart_racing_results` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `lobby_id` VARCHAR(50) NOT NULL,
    `track_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `position` INT NOT NULL,
    `total_time` INT NOT NULL, -- Store total time in milliseconds
    `best_lap_time` INT NOT NULL, -- Store best lap in milliseconds
    `race_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gokart_racing_track_records` (
    `track_id` VARCHAR(50) PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `best_time` INT NOT NULL, -- Store time in milliseconds
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
