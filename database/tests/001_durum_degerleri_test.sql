-- =============================================================================
-- TEST: Migration 001 - durum / rol değerleri tek (ASCII) yazım
-- Ön koşul: schema.sql ve migrations/001 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (9101, 'test_tip_001', 2, 1000);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9101, 'Test', 'Misafir', 'T0000009101', '1', 't9101@example.com', '1990-01-01');
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES (9101, 'T-9101', 1, 9101);

-- Varsayılan değer yeni yazımla geçerli olmalı
SELECT pg_temp.esit_bekle('Oda: varsayılan durum',
    $q$SELECT durum FROM Oda WHERE id = 9101$q$, 'bos');

-- Türkçe karakterli eski yazımlar artık REDDEDİLİR
SELECT pg_temp.hata_bekle('Oda: "boş" reddedilir', '23514',
    $q$UPDATE Oda SET durum = 'boş' WHERE id = 9101$q$);
SELECT pg_temp.hata_bekle('Oda: "bakımda" reddedilir', '23514',
    $q$UPDATE Oda SET durum = 'bakımda' WHERE id = 9101$q$);
SELECT pg_temp.hata_bekle('Personel: "kat görevlisi" reddedilir', '23514',
    $q$INSERT INTO Personel (ad, soyad, gorev) VALUES ('A', 'B', 'kat görevlisi')$q$);
SELECT pg_temp.hata_bekle('Personel: "kat gorevlisi" (boşluklu) reddedilir', '23514',
    $q$INSERT INTO Personel (ad, soyad, gorev) VALUES ('A', 'B', 'kat gorevlisi')$q$);
SELECT pg_temp.hata_bekle('Personel: "yönetici" reddedilir', '23514',
    $q$INSERT INTO Personel (ad, soyad, gorev) VALUES ('A', 'B', 'yönetici')$q$);
SELECT pg_temp.hata_bekle('Kullanici: "yönetici" rolü reddedilir', '23514',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol) VALUES ('t001', 'h', 'yönetici')$q$);
SELECT pg_temp.hata_bekle('Rezervasyon: "onaylı" reddedilir', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
       VALUES (9101, 9101, '2027-03-01', '2027-03-02', 1, 'onaylı')$q$);
SELECT pg_temp.hata_bekle('Rezervasyon: "tamamlandı" reddedilir', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
       VALUES (9101, 9101, '2027-03-01', '2027-03-02', 1, 'tamamlandı')$q$);

-- Yeni (ASCII) yazımlar KABUL edilir
SELECT pg_temp.basari_bekle('Oda: bos/dolu/temizlikte/bakimda',
    $q$UPDATE Oda SET durum = 'dolu' WHERE id = 9101;
       UPDATE Oda SET durum = 'temizlikte' WHERE id = 9101;
       UPDATE Oda SET durum = 'bakimda' WHERE id = 9101;
       UPDATE Oda SET durum = 'bos' WHERE id = 9101$q$);
SELECT pg_temp.basari_bekle('Personel: kat_gorevlisi ve yonetici',
    $q$INSERT INTO Personel (id, ad, soyad, gorev) VALUES (9101, 'A', 'B', 'kat_gorevlisi'), (9102, 'C', 'D', 'yonetici')$q$);
SELECT pg_temp.basari_bekle('Kullanici: personele bağlı yonetici',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, personel_id) VALUES ('t001_y', 'h', 'yonetici', 9102)$q$);
SELECT pg_temp.basari_bekle('Kullanici: bağımsız sistem yöneticisi',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol) VALUES ('t001_admin', 'h', 'yonetici')$q$);
SELECT pg_temp.basari_bekle('Rezervasyon: onayli ve tamamlandi',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
       VALUES (9101, 9101, '2027-03-01', '2027-03-02', 1, 'onayli'),
              (9101, 9101, '2027-04-01', '2027-04-02', 1, 'tamamlandi')$q$);
SELECT pg_temp.basari_bekle('TemizlikKaydi: bakimda',
    $q$INSERT INTO TemizlikKaydi (oda_id, personel_id, durum) VALUES (9101, 9101, 'bakimda')$q$);

-- Rol-ilişki kuralı korunuyor
SELECT pg_temp.hata_bekle('Kullanici: resepsiyon rolü kayıtsız olamaz', '23514',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol) VALUES ('t001_r', 'h', 'resepsiyon')$q$);

\echo 'MIGRATION 001 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
