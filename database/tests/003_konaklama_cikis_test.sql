-- =============================================================================
-- TEST: Migration 003 - konaklama çıkış zamanı kontrolü
-- Ön koşul: schema.sql ve migrations/001-003 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (9301, 'test_tip_003', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES (9301, 'T-9301', 1, 9301);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9301, 'Test', 'Misafir', 'T0000009301', '1', 't9301@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES (9301, 'Test', 'Resepsiyon', 'resepsiyon');
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
    VALUES (9301, 9301, 9301, '2027-05-01', '2027-05-03', 1);

SELECT pg_temp.basari_bekle('Check-in: çıkış zamanı boş (NULL) olabilir',
    $q$INSERT INTO Konaklama (id, rezervasyon_id, gercek_giris_zamani, islemi_yapan_personel_id)
       VALUES (9301, 9301, '2027-05-01 14:00', 9301)$q$);
SELECT pg_temp.hata_bekle('Check-out: girişten önceki zaman reddedilir', '23514',
    $q$UPDATE Konaklama SET gercek_cikis_zamani = '2027-05-01 13:59' WHERE id = 9301$q$);
SELECT pg_temp.basari_bekle('Check-out: girişten sonraki zaman kabul edilir',
    $q$UPDATE Konaklama SET gercek_cikis_zamani = '2027-05-03 11:00' WHERE id = 9301$q$);

\echo 'MIGRATION 003 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
