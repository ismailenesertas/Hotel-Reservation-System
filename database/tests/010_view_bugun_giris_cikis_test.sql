-- =============================================================================
-- TEST: Migration 010 - vw_bugun_giris_cikis (Şartname View 1)
-- Ön koşul: schema.sql ve migrations/001-010 uygulanmış olmalı.
-- Tarihler CURRENT_DATE'e göre üretilir; test her gün çalışır.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (91001, 'test_tip_010', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES
    (91001, 'T-91001', 1, 91001), (91002, 'T-91002', 1, 91001),
    (91003, 'T-91003', 1, 91001), (91004, 'T-91004', 1, 91001),
    (91005, 'T-91005', 1, 91001);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (91001, 'Zeynep', 'Test', 'T0000091001', '5551112233', 't91001@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES (91001, 'Test', 'Resepsiyon', 'resepsiyon');

INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum) VALUES
    (91001, 91001, 91001, CURRENT_DATE,     CURRENT_DATE + 2, 2, 'onayli'),     -- bugün giriş, check-in yok
    (91002, 91001, 91002, CURRENT_DATE,     CURRENT_DATE + 1, 1, 'beklemede'),  -- bugün giriş, check-in yapıldı
    (91003, 91001, 91003, CURRENT_DATE - 3, CURRENT_DATE,     1, 'onayli'),     -- bugün çıkış
    (91004, 91001, 91004, CURRENT_DATE,     CURRENT_DATE + 3, 1, 'iptal'),      -- iptal: görünmemeli
    (91005, 91001, 91005, CURRENT_DATE - 1, CURRENT_DATE + 1, 1, 'onayli');     -- devam ediyor: görünmemeli
INSERT INTO Konaklama (rezervasyon_id, gercek_giris_zamani, islemi_yapan_personel_id) VALUES
    (91002, now(), 91001),
    (91003, now() - interval '3 days', 91001),
    (91005, now() - interval '1 day', 91001);

CREATE TEMP VIEW test_v AS
    SELECT * FROM vw_bugun_giris_cikis WHERE rezervasyon_id BETWEEN 91001 AND 91005;

SELECT pg_temp.esit_bekle('Listede yalnızca bugünkü aktif hareketler (3 kayıt)',
    $q$SELECT string_agg(rezervasyon_id::text, ',' ORDER BY rezervasyon_id) FROM test_v$q$, '91001,91002,91003');
SELECT pg_temp.esit_bekle('Giriş / çıkış sınıflandırması',
    $q$SELECT string_agg(rezervasyon_id || '=' || hareket, ',' ORDER BY rezervasyon_id) FROM test_v$q$,
    '91001=giris,91002=giris,91003=cikis');
SELECT pg_temp.esit_bekle('Check-in bilgisi (91001 yok, 91002 var)',
    $q$SELECT string_agg(rezervasyon_id || '=' || check_in_yapildi, ',' ORDER BY rezervasyon_id) FROM test_v WHERE hareket = 'giris'$q$,
    '91001=false,91002=true');
SELECT pg_temp.esit_bekle('Misafir, oda ve oda tipi bilgisi JOIN ile geliyor',
    $q$SELECT misafir_adi || '|' || telefon || '|' || oda_no || '|' || oda_tipi FROM test_v WHERE rezervasyon_id = 91003$q$,
    'Zeynep Test|5551112233|T-91003|test_tip_010');

-- Check-out yapılınca çıkış listesinde işaretlenir (listeden düşmez)
UPDATE Konaklama SET gercek_cikis_zamani = now() WHERE rezervasyon_id = 91003;
SELECT pg_temp.esit_bekle('Check-out sonrası check_out_yapildi = true',
    $q$SELECT check_out_yapildi::text FROM test_v WHERE rezervasyon_id = 91003$q$, 'true');

\echo 'MIGRATION 010 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
