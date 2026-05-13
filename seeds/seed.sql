-- SIMS PPOB Seed Data
-- 5 Banners + 12 Services

INSERT IGNORE INTO banners (id, banner_name, banner_image, description) VALUES
(1, 'Promo Selamat Tahun Baru', 'https://cdn.example.com/banner/newyear.jpg', 'Diskon 20% untuk semua transaksi'),
(2, 'Cashback 10%', 'https://cdn.example.com/banner/cashback.jpg', 'Cashback 10% untuk pembayaran pulsa'),
(3, 'Gratis biaya admin', 'https://cdn.example.com/banner/freeadmin.jpg', 'Tidak ada biaya admin untuk bulan ini'),
(4, 'Promo Weekend', 'https://cdn.example.com/banner/weekend.jpg', 'Diskon special weekend'),
(5, 'Bonus Saldo', 'https://cdn.example.com/banner/bonus.jpg', 'Dapatkan bonus saldo setelah registrasi');

INSERT IGNORE INTO services (id, service_code, service_name, service_icon, service_tariff) VALUES
(1, 'PULSA', 'Pulsa Elektrik', 'https://cdn.example.com/icon/pulsa.png', 40000.00),
(2, 'PGN', 'Tagihan Gas', 'https://cdn.example.com/icon/pgn.png', 50000.00),
(3, 'LISTRIK', 'Tagihan Listrik', 'https://cdn.example.com/icon/listrik.png', 10000.00),
(4, 'PDAM', 'Tagihan PDAM', 'https://cdn.example.com/icon/pdam.png', 40000.00),
(5, 'PBB', 'Pajak Bumi dan Bangunan', 'https://cdn.example.com/icon/pbb.png', 40000.00),
(6, 'TV_LANGGANAN', 'TV Langganan', 'https://cdn.example.com/icon/tv.png', 36000.00),
(7, 'MUSIK', 'Langganan Musik', 'https://cdn.example.com/icon/musik.png', 50000.00),
(8, 'VOUCHER_GAME', 'Voucher Game', 'https://cdn.example.com/icon/game.png', 100000.00),
(9, 'VOUCHER_MAKANAN', 'Voucher Makanan', 'https://cdn.example.com/icon/food.png', 30000.00),
(10, 'KURBAN', 'Kurban', 'https://cdn.example.com/icon/kurban.png', 2500000.00),
(11, 'ZAKAT', 'Zakat', 'https://cdn.example.com/icon/zakat.png', 300000.00),
(12, 'QURBAN', 'Qurban', 'https://cdn.example.com/icon/qurban.png', 200000.00);