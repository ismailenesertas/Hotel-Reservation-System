-- =============================================================================
-- TEST: Migration 008 - temizlik kaydı / oda durumu trigger'ı
-- Ön koşul: schema.sql ve migrations/001-008 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (9801, 'test_tip_008', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id, durum) VALUES
    (9801, 'T-9801', 1, 9801, 'temizlikte'),
    (9802, 'T-9802', 1, 9801, 'dolu'),
    (9803, 'T-9803', 1, 9801, 'bos');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES (9801, 'Test', 'Kat', 'kat_gorevlisi');

-- Temizlikteki oda temizlenince boşalır
INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9801, 9801, 'kontrol_bekliyor');
SELECT pg_temp.esit_bekle('kontrol_bekliyor: durum değişmez',
    $q$SELECT durum FROM Oda WHERE id = 9801$q$, 'temizlikte');
INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9801, 9801, 'temizlendi');
SELECT pg_temp.esit_bekle('temizlendi: temizlikteki oda boş olur',
    $q$SELECT durum FROM Oda WHERE id = 9801$q$, 'bos');

-- Misafir içerideyken günlük temizlik
INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9802, 9801, 'temizlendi');
SELECT pg_temp.esit_bekle('temizlendi: dolu oda dolu kalır',
    $q$SELECT durum FROM Oda WHERE id = 9802$q$, 'dolu');
INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9802, 9801, 'bakimda');
SELECT pg_temp.esit_bekle('bakimda: dolu oda bakıma alınmaz',
    $q$SELECT durum FROM Oda WHERE id = 9802$q$, 'dolu');

-- Bakım döngüsü
INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9803, 9801, 'bakimda');
SELECT pg_temp.esit_bekle('bakimda: boş oda bakıma alınır',
    $q$SELECT durum FROM Oda WHERE id = 9803$q$, 'bakimda');
INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9803, 9801, 'temizlendi');
SELECT pg_temp.esit_bekle('temizlendi: bakımdaki oda boş olur',
    $q$SELECT durum FROM Oda WHERE id = 9803$q$, 'bos');

\echo 'MIGRATION 008 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
