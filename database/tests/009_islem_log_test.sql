-- =============================================================================
-- TEST: Migration 009 - IslemLog trigger'ı (Şartname Trigger 3)
-- Ön koşul: schema.sql ve migrations/001-009 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (9901, 'test_tip_009', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES (9901, 'T-9901', 1, 9901);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9901, 'Test', 'Misafir', 'T0000009901', '1', 't9901@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES (9901, 'Test', 'Resepsiyon', 'resepsiyon');

-- Bu testteki logları ayırt etmek için başlangıç noktası
CREATE TEMP TABLE log_baslangic AS SELECT COALESCE(max(id), 0) AS son_id FROM IslemLog;
CREATE TEMP VIEW test_log AS
    SELECT * FROM IslemLog WHERE id > (SELECT son_id FROM log_baslangic);

-- INSERT
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
    VALUES (9901, 9901, 9901, '2027-10-01', '2027-10-03', 1);
SELECT pg_temp.esit_bekle('INSERT loglandı',
    $q$SELECT tablo_adi || '/' || islem_turu || '/' || kayit_id FROM test_log ORDER BY id DESC LIMIT 1$q$,
    'rezervasyon/INSERT/9901');
SELECT pg_temp.esit_bekle('INSERT: eski veri NULL, yeni veri dolu',
    $q$SELECT (eski_veri IS NULL AND yeni_veri->>'durum' = 'beklemede')::text FROM test_log ORDER BY id DESC LIMIT 1$q$,
    'true');
SELECT pg_temp.esit_bekle('Kullanıcı ayarı yokken "sistem"',
    $q$SELECT aciklama FROM test_log ORDER BY id DESC LIMIT 1$q$, 'Kullanıcı: sistem');

-- UPDATE (kullanıcı bilgisiyle)
SET LOCAL app.kullanici_id = '42';
UPDATE Rezervasyon SET durum = 'onayli' WHERE id = 9901;
SELECT pg_temp.esit_bekle('UPDATE: eski ve yeni durum kaydedildi',
    $q$SELECT islem_turu || ':' || (eski_veri->>'durum') || '->' || (yeni_veri->>'durum') FROM test_log ORDER BY id DESC LIMIT 1$q$,
    'UPDATE:beklemede->onayli');
SELECT pg_temp.esit_bekle('UPDATE: işlemi yapan kullanıcı',
    $q$SELECT aciklama FROM test_log ORDER BY id DESC LIMIT 1$q$, 'Kullanıcı: 42');

-- Değer değiştirmeyen UPDATE loglanmaz
UPDATE Rezervasyon SET durum = 'onayli' WHERE id = 9901;
SELECT pg_temp.esit_bekle('Değişiklik yapmayan UPDATE loglanmadı (toplam 2 kayıt)',
    $q$SELECT count(*)::text FROM test_log$q$, '2');

-- Başarısız işlem loglanmaz (çakışma trigger'ı reddeder)
SELECT pg_temp.hata_bekle('Çakışan rezervasyon reddedilir', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9901, 9901, '2027-10-02', '2027-10-04', 1)$q$);
SELECT pg_temp.esit_bekle('Reddedilen işlem için log yok (hâlâ 2 kayıt)',
    $q$SELECT count(*)::text FROM test_log$q$, '2');

-- Ödeme tablosu da loglanır
INSERT INTO Konaklama (id, rezervasyon_id, islemi_yapan_personel_id) VALUES (9901, 9901, 9901);
INSERT INTO Odeme (id, konaklama_id, tutar, odeme_turu) VALUES (9901, 9901, 2000, 'kart');
SELECT pg_temp.esit_bekle('Odeme INSERT loglandı',
    $q$SELECT tablo_adi || '/' || islem_turu || '/' || (yeni_veri->>'tutar') FROM test_log ORDER BY id DESC LIMIT 1$q$,
    'odeme/INSERT/2000.00');
SELECT pg_temp.esit_bekle('Konaklama ve Oda değişiklikleri loglanmaz (yalnızca rezervasyon/odeme)',
    $q$SELECT string_agg(DISTINCT tablo_adi, ',' ORDER BY tablo_adi) FROM test_log$q$, 'odeme,rezervasyon');

-- DELETE
DELETE FROM Odeme WHERE id = 9901;
SELECT pg_temp.esit_bekle('DELETE: eski veri dolu, yeni veri NULL',
    $q$SELECT islem_turu || ':' || (eski_veri->>'odeme_turu') || ':' || COALESCE(yeni_veri::text, 'NULL') FROM test_log ORDER BY id DESC LIMIT 1$q$,
    'DELETE:kart:NULL');

\echo 'MIGRATION 009 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
