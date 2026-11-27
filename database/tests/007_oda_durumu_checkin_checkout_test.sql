-- =============================================================================
-- TEST: Migration 007 - check-in/check-out oda durumu trigger'ı (Şartname Trigger 2)
-- Ön koşul: schema.sql ve migrations/001-007 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (9701, 'test_tip_007', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES
    (9701, 'T-9701', 1, 9701),
    (9702, 'T-9702', 1, 9701);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9701, 'Test', 'Misafir', 'T0000009701', '1', 't9701@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES (9701, 'Test', 'Resepsiyon', 'resepsiyon');
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
    VALUES (9701, 9701, 9701, '2027-09-01', '2027-09-03', 1, 'onayli');

SELECT pg_temp.esit_bekle('Başlangıç: oda boş',
    $q$SELECT durum FROM Oda WHERE id = 9701$q$, 'bos');

-- Check-in
SELECT pg_temp.basari_bekle('Check-in (Konaklama eklenir)',
    $q$INSERT INTO Konaklama (id, rezervasyon_id, gercek_giris_zamani, islemi_yapan_personel_id)
       VALUES (9701, 9701, '2027-09-01 14:00', 9701)$q$);
SELECT pg_temp.esit_bekle('Check-in sonrası oda dolu',
    $q$SELECT durum FROM Oda WHERE id = 9701$q$, 'dolu');
SELECT pg_temp.esit_bekle('Diğer oda etkilenmedi',
    $q$SELECT durum FROM Oda WHERE id = 9702$q$, 'bos');

-- Çıkış zamanı dışındaki güncelleme durumu değiştirmez
SELECT pg_temp.basari_bekle('Personel bilgisini güncelleme',
    $q$UPDATE Konaklama SET islemi_yapan_personel_id = 9701 WHERE id = 9701$q$);
SELECT pg_temp.esit_bekle('Oda hâlâ dolu',
    $q$SELECT durum FROM Oda WHERE id = 9701$q$, 'dolu');

-- Check-out
SELECT pg_temp.basari_bekle('Check-out (çıkış zamanı yazılır)',
    $q$UPDATE Konaklama SET gercek_cikis_zamani = '2027-09-03 11:00' WHERE id = 9701$q$);
SELECT pg_temp.esit_bekle('Check-out sonrası oda temizlikte',
    $q$SELECT durum FROM Oda WHERE id = 9701$q$, 'temizlikte');

-- Başarısız check-out oda durumunu değiştirmez (aynı transaction'da geri alınır)
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
    VALUES (9702, 9701, 9702, '2027-09-01', '2027-09-03', 1, 'onayli');
INSERT INTO Konaklama (id, rezervasyon_id, gercek_giris_zamani, islemi_yapan_personel_id)
    VALUES (9702, 9702, '2027-09-01 15:00', 9701);
SELECT pg_temp.hata_bekle('Geçersiz check-out (girişten önce) reddedilir', '23514',
    $q$UPDATE Konaklama SET gercek_cikis_zamani = '2027-09-01 10:00' WHERE id = 9702$q$);
SELECT pg_temp.esit_bekle('Başarısız check-out sonrası oda hâlâ dolu',
    $q$SELECT durum FROM Oda WHERE id = 9702$q$, 'dolu');

\echo 'MIGRATION 007 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
