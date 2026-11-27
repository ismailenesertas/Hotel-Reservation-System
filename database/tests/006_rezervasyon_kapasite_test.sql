-- =============================================================================
-- TEST: Migration 006 - kişi sayısı / oda kapasitesi trigger'ı
-- Ön koşul: schema.sql ve migrations/001-006 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES
    (9601, 'test_tek_kisilik', 1, 800),
    (9602, 'test_aile', 4, 2000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES
    (9601, 'T-9601', 1, 9601),
    (9602, 'T-9602', 1, 9602);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9601, 'Test', 'Misafir', 'T0000009601', '1', 't9601@example.com', '1990-01-01');

SELECT pg_temp.basari_bekle('Kapasite sınırında (1 kişilik odaya 1 kişi)',
    $q$INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9601, 9601, 9601, '2027-08-01', '2027-08-03', 1)$q$);
SELECT pg_temp.hata_bekle('Kapasite aşımı (1 kişilik odaya 2 kişi)', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9601, 9601, '2027-08-10', '2027-08-12', 2)$q$);
SELECT pg_temp.basari_bekle('Aile odasına 4 kişi',
    $q$INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9602, 9601, 9602, '2027-08-01', '2027-08-03', 4)$q$);
SELECT pg_temp.hata_bekle('Aile odasına 5 kişi', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9601, 9602, '2027-08-10', '2027-08-12', 5)$q$);

-- Güncellemeler
SELECT pg_temp.hata_bekle('Güncelleme ile kişi sayısını kapasite üstüne çıkarma', '23514',
    $q$UPDATE Rezervasyon SET kisi_sayisi = 2 WHERE id = 9601$q$);
SELECT pg_temp.hata_bekle('4 kişilik rezervasyonu 1 kişilik odaya taşıma', '23514',
    $q$UPDATE Rezervasyon SET oda_id = 9601, giris_tarihi = '2027-08-20', cikis_tarihi = '2027-08-21' WHERE id = 9602$q$);
SELECT pg_temp.basari_bekle('Tarih güncellemesi kapasiteyi etkilemez',
    $q$UPDATE Rezervasyon SET cikis_tarihi = '2027-08-04' WHERE id = 9602$q$);

-- Var olmayan oda: trigger değil FOREIGN KEY hata vermeli
SELECT pg_temp.hata_bekle('Var olmayan oda (FK hatası)', '23503',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9601, 999999, '2027-08-01', '2027-08-02', 1)$q$);

\echo 'MIGRATION 006 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
