-- =============================================================================
-- TEST: Migration 005 - çakışan rezervasyon trigger'ı (Şartname Trigger 1)
-- Ön koşul: schema.sql ve migrations/001-005 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (9501, 'test_tip_005', 4, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES
    (9501, 'T-9501', 1, 9501),
    (9502, 'T-9502', 1, 9501);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi) VALUES
    (9501, 'Ayşe', 'Test', 'T0000009501', '1', 't9501@example.com', '1990-01-01'),
    (9502, 'Mehmet', 'Test', 'T0000009502', '1', 't9502@example.com', '1990-01-01');

-- Mevcut rezervasyon: oda 9501, 10-15 Temmuz (giriş 10, çıkış 15 sabahı)
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
    VALUES (9501, 9501, 9501, '2027-07-10', '2027-07-15', 2);

-- Çakışmalar reddedilir (23P01)
SELECT pg_temp.hata_bekle('Aynı tarihler', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-10', '2027-07-15', 1)$q$);
SELECT pg_temp.hata_bekle('Sondan kesişme (14-18)', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-14', '2027-07-18', 1)$q$);
SELECT pg_temp.hata_bekle('Baştan kesişme (8-11)', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-08', '2027-07-11', 1)$q$);
SELECT pg_temp.hata_bekle('İçinde kalan (11-12)', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-11', '2027-07-12', 1)$q$);
SELECT pg_temp.hata_bekle('Kapsayan (1-31)', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-01', '2027-07-31', 1)$q$);
SELECT pg_temp.hata_bekle('Onaylı durumda da çakışma reddedilir', '23P01',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum) VALUES (9502, 9501, '2027-07-12', '2027-07-13', 1, 'onayli')$q$);

-- Ters / sıfır günlük aralık trigger'da değil CHECK kısıtında (23514) reddedilmeli
SELECT pg_temp.hata_bekle('Ters aralık (çıkış girişten önce): CHECK hatası', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-12', '2027-07-11', 1)$q$);
SELECT pg_temp.hata_bekle('Sıfır gece (giriş = çıkış): CHECK hatası', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-12', '2027-07-12', 1)$q$);

-- Çakışmayanlar kabul edilir
SELECT pg_temp.basari_bekle('Çıkış günü yeni giriş (15-17): yarı açık aralık',
    $q$INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9502, 9501, '2027-07-15', '2027-07-17', 1)$q$);
SELECT pg_temp.basari_bekle('Giriş günü önceki çıkış (5-10)',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9501, '2027-07-05', '2027-07-10', 1)$q$);
SELECT pg_temp.basari_bekle('Farklı oda aynı tarihler',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9502, 9502, '2027-07-10', '2027-07-15', 1)$q$);
SELECT pg_temp.basari_bekle('İptal durumundaki yeni kayıt kontrol edilmez',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum) VALUES (9502, 9501, '2027-07-11', '2027-07-12', 1, 'iptal')$q$);

-- İptal edilen rezervasyon odayı serbest bırakır
SELECT pg_temp.basari_bekle('Rezervasyon 9501 iptal edilir',
    $q$UPDATE Rezervasyon SET durum = 'iptal' WHERE id = 9501$q$);
SELECT pg_temp.basari_bekle('Serbest kalan tarihlere yeni rezervasyon (10-15)',
    $q$INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi) VALUES (9503, 9502, 9501, '2027-07-10', '2027-07-15', 2)$q$);
SELECT pg_temp.hata_bekle('İptal edilmiş 9501 çakışan tarihte yeniden aktif yapılamaz', '23P01',
    $q$UPDATE Rezervasyon SET durum = 'beklemede' WHERE id = 9501$q$);

-- Güncellemeler
SELECT pg_temp.basari_bekle('Kendi tarihini kısaltma (kendisiyle çakışmaz)',
    $q$UPDATE Rezervasyon SET cikis_tarihi = '2027-07-14' WHERE id = 9503$q$);
SELECT pg_temp.hata_bekle('Tarih uzatma ile sonraki rezervasyona taşma', '23P01',
    $q$UPDATE Rezervasyon SET cikis_tarihi = '2027-07-16' WHERE id = 9503$q$);
SELECT pg_temp.hata_bekle('Dolu bir odaya oda değiştirme', '23P01',
    $q$UPDATE Rezervasyon SET oda_id = 9501, giris_tarihi = '2027-07-16', cikis_tarihi = '2027-07-17'
       WHERE id = (SELECT id FROM Rezervasyon WHERE oda_id = 9502 AND misafir_id = 9502 LIMIT 1)$q$);
SELECT pg_temp.basari_bekle('Kişi sayısı güncellemesi (trigger tetiklenmez)',
    $q$UPDATE Rezervasyon SET kisi_sayisi = 1 WHERE id = 9503$q$);

SELECT pg_temp.esit_bekle('Oda 9501 için aktif rezervasyon sayısı',
    $q$SELECT count(*)::text FROM Rezervasyon WHERE oda_id = 9501 AND durum <> 'iptal'$q$, '3');

\echo 'MIGRATION 005 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
