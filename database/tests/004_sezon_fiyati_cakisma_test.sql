-- =============================================================================
-- TEST: Migration 004 - sezon fiyatı çakışma trigger'ı
-- Ön koşul: schema.sql ve migrations/001-004 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES
    (9401, 'test_tip_004a', 2, 1000),
    (9402, 'test_tip_004b', 3, 1500);

-- Mevcut sezon: 1-10 Haziran 2027 (her iki uç dahil)
INSERT INTO SezonFiyati (id, oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat)
    VALUES (9401, 9401, '2027-06-01', '2027-06-10', 2000);

-- Çakışan dönemler reddedilir (23P01 exclusion_violation)
SELECT pg_temp.hata_bekle('Aynı dönem', '23P01',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-06-01', '2027-06-10', 1)$q$);
SELECT pg_temp.hata_bekle('Bitiş günü ortak (10 Haziran iki sezonda olamaz)', '23P01',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-06-10', '2027-06-20', 1)$q$);
SELECT pg_temp.hata_bekle('Başlangıç günü ortak', '23P01',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-05-20', '2027-06-01', 1)$q$);
SELECT pg_temp.hata_bekle('Mevcut dönemi içine alan dönem', '23P01',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-05-01', '2027-07-01', 1)$q$);
SELECT pg_temp.hata_bekle('Mevcut dönemin içinde kalan dönem', '23P01',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-06-03', '2027-06-05', 1)$q$);
SELECT pg_temp.hata_bekle('Tek günlük dönem mevcut dönemin içinde', '23P01',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-06-05', '2027-06-05', 1)$q$);

-- Çakışmayan dönemler kabul edilir
SELECT pg_temp.basari_bekle('Hemen sonraki gün başlayan dönem (11-20 Haziran)',
    $q$INSERT INTO SezonFiyati (id, oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9402, 9401, '2027-06-11', '2027-06-20', 2500)$q$);
SELECT pg_temp.basari_bekle('Hemen önceki gün biten dönem (20-31 Mayıs)',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-05-20', '2027-05-31', 1800)$q$);
SELECT pg_temp.basari_bekle('Farklı oda tipi aynı dönem',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9402, '2027-06-01', '2027-06-10', 3000)$q$);

-- Ters tarih aralığı trigger'da değil CHECK kısıtında (23514) reddedilmeli
SELECT pg_temp.hata_bekle('Ters aralık: CHECK kısıtı anlamlı hatayı verir', '23514',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES (9401, '2027-09-10', '2027-09-01', 1)$q$);

-- Güncelleme
SELECT pg_temp.basari_bekle('Kaydın kendi dönemini daraltması (kendisiyle çakışmaz)',
    $q$UPDATE SezonFiyati SET bitis_tarihi = '2027-06-09' WHERE id = 9401$q$);
SELECT pg_temp.hata_bekle('Güncelleme ile başka dönemin içine kaydırma', '23P01',
    $q$UPDATE SezonFiyati SET bitis_tarihi = '2027-06-12' WHERE id = 9401$q$);
SELECT pg_temp.basari_bekle('Yalnızca fiyat güncellemesi (trigger tetiklenmez)',
    $q$UPDATE SezonFiyati SET gecelik_fiyat = 2100 WHERE id = 9401$q$);

SELECT pg_temp.esit_bekle('Oda tipi 9401 için sezon sayısı',
    $q$SELECT count(*)::text FROM SezonFiyati WHERE oda_tipi_id = 9401$q$, '3');

\echo 'MIGRATION 004 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
