-- =============================================================================
-- TEST: Migration 002 - her misafir/personel için tek kullanıcı hesabı
-- Ön koşul: schema.sql ve migrations/001-002 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9201, 'Test', 'Misafir', 'T0000009201', '1', 't9201@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES (9201, 'Test', 'Resepsiyon', 'resepsiyon');

SELECT pg_temp.basari_bekle('Misafir için ilk hesap',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, misafir_id) VALUES ('t002_m1', 'h', 'misafir', 9201)$q$);
SELECT pg_temp.hata_bekle('Aynı misafire ikinci hesap reddedilir', '23505',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, misafir_id) VALUES ('t002_m2', 'h', 'misafir', 9201)$q$);

SELECT pg_temp.basari_bekle('Personel için ilk hesap',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, personel_id) VALUES ('t002_p1', 'h', 'resepsiyon', 9201)$q$);
SELECT pg_temp.hata_bekle('Aynı personele ikinci hesap reddedilir', '23505',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, personel_id) VALUES ('t002_p2', 'h', 'resepsiyon', 9201)$q$);

-- NULL değerler birbirini engellemez: birden fazla bağımsız yönetici olabilir
SELECT pg_temp.basari_bekle('İki bağımsız yönetici (NULL bağlantılar çakışmaz)',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol) VALUES ('t002_a1', 'h', 'yonetici'), ('t002_a2', 'h', 'yonetici')$q$);

\echo 'MIGRATION 002 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
