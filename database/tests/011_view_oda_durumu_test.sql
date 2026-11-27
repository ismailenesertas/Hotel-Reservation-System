-- =============================================================================
-- TEST: Migration 011 - vw_oda_durumu (Şartname View 2)
-- Ön koşul: schema.sql ve migrations/001-011 uygulanmış olmalı.
-- Tek transaction içinde çalışır ve ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat) VALUES (91101, 'test_tip_011', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id) VALUES
    (91101, 'T-91101', 3, 91101),   -- temizlik geçmişi var, şu an misafir var
    (91102, 'T-91102', 3, 91101);   -- hiç kaydı yok
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (91101, 'Ali', 'Test', 'T0000091101', '1', 't91101@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev) VALUES
    (91101, 'Fatma', 'Kat', 'kat_gorevlisi'),
    (91102, 'Hasan', 'Kat', 'kat_gorevlisi'),
    (91103, 'Test', 'Resepsiyon', 'resepsiyon');

-- Temizlik geçmişi: son "temizlendi" kaydı Hasan'a ait; daha yeni "kontrol_bekliyor" sayılmaz
INSERT INTO TemizlikKaydi (oda_id, personel_id, tarih, durum) VALUES
    (91101, 91101, '2027-01-01 10:00', 'temizlendi'),
    (91101, 91102, '2027-01-05 10:00', 'temizlendi'),
    (91101, 91101, '2027-01-06 10:00', 'kontrol_bekliyor');

-- Aktif konaklama (check-in yapılmış, check-out yok)
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
    VALUES (91101, 91101, 91101, '2027-01-10', '2027-01-14', 2, 'onayli');
INSERT INTO Konaklama (rezervasyon_id, gercek_giris_zamani, islemi_yapan_personel_id)
    VALUES (91101, '2027-01-10 14:00', 91103);

SELECT pg_temp.esit_bekle('Her iki oda da listede (temizlik kaydı olmayan dahil)',
    $q$SELECT count(*)::text FROM vw_oda_durumu WHERE oda_id IN (91101, 91102)$q$, '2');
SELECT pg_temp.esit_bekle('Oda 91101: durum, son temizlik ve temizleyen',
    $q$SELECT durum || '|' || son_temizlik_tarihi || '|' || son_temizleyen FROM vw_oda_durumu WHERE oda_id = 91101$q$,
    'dolu|2027-01-05 10:00:00|Hasan Kat');
SELECT pg_temp.esit_bekle('Oda 91101: mevcut misafir ve planlanan çıkış',
    $q$SELECT mevcut_misafir || '|' || planlanan_cikis FROM vw_oda_durumu WHERE oda_id = 91101$q$,
    'Ali Test|2027-01-14');
SELECT pg_temp.esit_bekle('Oda 91102: kaydı yok -> boş, temizlik ve misafir NULL',
    $q$SELECT durum || '|' || COALESCE(son_temizlik_tarihi::text, 'NULL') || '|' || COALESCE(mevcut_misafir, 'NULL') FROM vw_oda_durumu WHERE oda_id = 91102$q$,
    'bos|NULL|NULL');

-- Check-out + temizlik sonrası view güncel durumu yansıtır (trigger 007 + 008)
UPDATE Konaklama SET gercek_cikis_zamani = '2027-01-14 11:00' WHERE rezervasyon_id = 91101;
SELECT pg_temp.esit_bekle('Check-out sonrası: temizlikte, misafir yok',
    $q$SELECT durum || '|' || COALESCE(mevcut_misafir, 'NULL') FROM vw_oda_durumu WHERE oda_id = 91101$q$,
    'temizlikte|NULL');
INSERT INTO TemizlikKaydi (oda_id, personel_id, tarih, durum) VALUES (91101, 91101, '2027-01-14 13:00', 'temizlendi');
SELECT pg_temp.esit_bekle('Temizlik sonrası: boş, son temizlik güncellendi',
    $q$SELECT durum || '|' || son_temizlik_tarihi || '|' || son_temizleyen FROM vw_oda_durumu WHERE oda_id = 91101$q$,
    'bos|2027-01-14 13:00:00|Fatma Kat');

\echo 'MIGRATION 011 TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
