-- Adminer 4.8.4 MySQL 8.0.40 dump

SET NAMES utf8;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

SET NAMES utf8mb4;

DROP TABLE IF EXISTS `banners`;
CREATE TABLE `banners` (
  `id` int NOT NULL AUTO_INCREMENT,
  `banner_name` varchar(100) NOT NULL,
  `banner_image` varchar(255) NOT NULL,
  `description` text,
  `created_on` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `banners` (`id`, `banner_name`, `banner_image`, `description`, `created_on`) VALUES
(1,	'Promo Selamat Tahun Baru',	'https://cdn.example.com/banner/newyear.jpg',	'Diskon 20% untuk semua transaksi',	'2026-05-13 16:16:44'),
(2,	'Cashback 10%',	'https://cdn.example.com/banner/cashback.jpg',	'Cashback 10% untuk pembayaran pulsa',	'2026-05-13 16:16:44'),
(3,	'Gratis biaya admin',	'https://cdn.example.com/banner/freeadmin.jpg',	'Tidak ada biaya admin untuk bulan ini',	'2026-05-13 16:16:44'),
(4,	'Promo Weekend',	'https://cdn.example.com/banner/weekend.jpg',	'Diskon special weekend',	'2026-05-13 16:16:44'),
(5,	'Bonus Saldo',	'https://cdn.example.com/banner/bonus.jpg',	'Dapatkan bonus saldo setelah registrasi',	'2026-05-13 16:16:44');

DROP TABLE IF EXISTS `services`;
CREATE TABLE `services` (
  `id` int NOT NULL AUTO_INCREMENT,
  `service_code` varchar(50) NOT NULL,
  `service_name` varchar(100) NOT NULL,
  `service_icon` varchar(255) DEFAULT NULL,
  `service_tariff` decimal(15,2) NOT NULL,
  `created_on` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `service_code` (`service_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `services` (`id`, `service_code`, `service_name`, `service_icon`, `service_tariff`, `created_on`) VALUES
(1,	'PULSA',	'Pulsa Elektrik',	'https://cdn.example.com/icon/pulsa.png',	40000.00,	'2026-05-13 16:16:44'),
(2,	'PGN',	'Tagihan Gas',	'https://cdn.example.com/icon/pgn.png',	50000.00,	'2026-05-13 16:16:44'),
(3,	'LISTRIK',	'Tagihan Listrik',	'https://cdn.example.com/icon/listrik.png',	10000.00,	'2026-05-13 16:16:44'),
(4,	'PDAM',	'Tagihan PDAM',	'https://cdn.example.com/icon/pdam.png',	40000.00,	'2026-05-13 16:16:44'),
(5,	'PBB',	'Pajak Bumi dan Bangunan',	'https://cdn.example.com/icon/pbb.png',	40000.00,	'2026-05-13 16:16:44'),
(6,	'TV_LANGGANAN',	'TV Langganan',	'https://cdn.example.com/icon/tv.png',	36000.00,	'2026-05-13 16:16:44'),
(7,	'MUSIK',	'Langganan Musik',	'https://cdn.example.com/icon/musik.png',	50000.00,	'2026-05-13 16:16:44'),
(8,	'VOUCHER_GAME',	'Voucher Game',	'https://cdn.example.com/icon/game.png',	100000.00,	'2026-05-13 16:16:44'),
(9,	'VOUCHER_MAKANAN',	'Voucher Makanan',	'https://cdn.example.com/icon/food.png',	30000.00,	'2026-05-13 16:16:44'),
(10,	'KURBAN',	'Kurban',	'https://cdn.example.com/icon/kurban.png',	2500000.00,	'2026-05-13 16:16:44'),
(11,	'ZAKAT',	'Zakat',	'https://cdn.example.com/icon/zakat.png',	300000.00,	'2026-05-13 16:16:44'),
(12,	'QURBAN',	'Qurban',	'https://cdn.example.com/icon/qurban.png',	200000.00,	'2026-05-13 16:16:44');

DROP TABLE IF EXISTS `transactions`;
CREATE TABLE `transactions` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `user_id` char(36) NOT NULL,
  `invoice_number` varchar(50) NOT NULL,
  `service_code` varchar(50) DEFAULT NULL,
  `service_name` varchar(100) DEFAULT NULL,
  `transaction_type` varchar(20) NOT NULL,
  `total_amount` decimal(15,2) NOT NULL,
  `created_on` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `invoice_number` (`invoice_number`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `transactions` (`id`, `user_id`, `invoice_number`, `service_code`, `service_name`, `transaction_type`, `total_amount`, `created_on`) VALUES
('1f7e2750-4ee8-11f1-99c8-d843ae0b2827',	'8262c77d-4ee7-11f1-99c8-d843ae0b2827',	'INV1778689429291680',	NULL,	NULL,	'TOPUP',	50000.00,	'2026-05-13 16:23:49'),
('1f976b04-4ee8-11f1-99c8-d843ae0b2827',	'8262c77d-4ee7-11f1-99c8-d843ae0b2827',	'INV1778689429456173',	'PULSA',	'Pulsa Elektrik',	'PAYMENT',	40000.00,	'2026-05-13 16:23:49'),
('86290660-4ee8-11f1-99c8-d843ae0b2827',	'8262c77d-4ee7-11f1-99c8-d843ae0b2827',	'INV1778689601539789',	NULL,	NULL,	'TOPUP',	50000.00,	'2026-05-13 16:26:41'),
('8635aaab-4ee8-11f1-99c8-d843ae0b2827',	'8262c77d-4ee7-11f1-99c8-d843ae0b2827',	'INV1778689601622821',	'PGN',	'Tagihan Gas',	'PAYMENT',	50000.00,	'2026-05-13 16:26:41');

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `email` varchar(100) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `profile_image` varchar(255) DEFAULT NULL,
  `balance` decimal(15,2) DEFAULT '0.00',
  `created_on` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `users` (`id`, `email`, `first_name`, `last_name`, `password`, `profile_image`, `balance`, `created_on`, `updated_on`) VALUES
('3e1780c8-4ee9-11f1-99c8-d843ae0b2827',	'jarwo@example.com',	'jarwo',	'kuat',	'$2a$10$jlvNWtBfORCs2N/x1nv.Xu57gE35TAPflfsB6/c5/nbIyuX7xc4X.',	NULL,	0.00,	'2026-05-13 16:31:50',	'2026-05-13 16:31:50'),
('8262c77d-4ee7-11f1-99c8-d843ae0b2827',	'test@example.com',	'Updated',	'Name',	'$2a$10$FBq9Fm9F6VKjwqYVsnfdHe1eyvV5uto6TK7ufHDoEpJrDfc88j3lq',	NULL,	70000.00,	'2026-05-13 16:19:25',	'2026-05-13 16:26:41');

-- 2026-05-13 16:54:13
