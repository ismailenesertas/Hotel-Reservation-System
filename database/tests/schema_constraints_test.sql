-- =============================================================================
-- ŞEMA KISITLARI TESTİ
-- Amaç : CHECK, UNIQUE, FOREIGN KEY ve NOT NULL kısıtlarının hatalı veriyi
--        gerçekten reddettiğini doğrulamak.
-- Çalıştırma:
--   docker cp database/tests/schema_constraints_test.sql otel_postgres_db:/tmp/t.sql
--   docker exec otel_postgres_db psql -U postgres -d otel_db -v ON_ERROR_STOP=1 -f /tmp/t.sql
-- Güvenlik: Her şey tek transaction içinde çalışır ve sonda ROLLBACK edilir;
--           veritabanında kalıcı hiçbir değişiklik olmaz.
-- Sonuç : Başarısız test olursa betik "BAŞARISIZ" mesajıyla durur.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Yardımcı fonksiyonlar (pg_temp: yalnızca bu oturumda var olur)
-- -----------------------------------------------------------------------------

-- Verilen SQL'in belirtilen SQLSTATE hata koduyla REDDEDİLMESİNİ bekler.
-- 23514 check_violation, 23505 unique_violation,
-- 23503 foreign_key_violation, 23502 not_null_violation
CREATE FUNCTION pg_temp.hata_bekle(p_aciklama text, p_sqlstate text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    calisti boolean := false;
BEGIN
    BEGIN
        EXECUTE p_sql;
        calisti := true;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> p_sqlstate THEN
            RAISE EXCEPTION 'BAŞARISIZ: % -> beklenen hata %, gelen % (%)',
                p_aciklama, p_sqlstate, SQLSTATE, SQLERRM;
        END IF;
        RAISE NOTICE 'GEÇTİ   : % (reddedildi: %)', p_aciklama, SQLSTATE;
    END;
    IF calisti THEN
        RAISE EXCEPTION 'BAŞARISIZ: % -> hata bekleniyordu ama sorgu çalıştı', p_aciklama;
    END IF;
END $$;

-- Verilen SQL'in HATASIZ çalışmasını bekler (geçerli veri kabul edilmeli).
CREATE FUNCTION pg_temp.basari_bekle(p_aciklama text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    RAISE NOTICE 'GEÇTİ   : % (kabul edildi)', p_aciklama;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'BAŞARISIZ: % -> kabul edilmeliydi ama hata verdi: % (%)',
        p_aciklama, SQLSTATE, SQLERRM;
END $$;

-- -----------------------------------------------------------------------------
-- Test verisi (yalnızca bu transaction içinde)
-- -----------------------------------------------------------------------------
INSERT INTO OdaTipi (id, tip_adi, kapasite, temel_fiyat)
    VALUES (9001, 'test_standart', 2, 1000);
INSERT INTO Oda (id, oda_no, kat, oda_tipi_id)
    VALUES (9001, 'T-101', 1, 9001);
INSERT INTO Misafir (id, ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
    VALUES (9001, 'Test', 'Misafir', 'T0000000001', '5550000000', 'test1@example.com', '1990-01-01');
INSERT INTO Personel (id, ad, soyad, gorev)
    VALUES (9001, 'Test', 'Personel', 'resepsiyon');
INSERT INTO Rezervasyon (id, misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
    VALUES (9001, 9001, 9001, '2027-01-10', '2027-01-12', 2);
INSERT INTO Konaklama (id, rezervasyon_id, islemi_yapan_personel_id)
    VALUES (9001, 9001, 9001);
INSERT INTO EkHizmet (id, hizmet_adi, birim_fiyat)
    VALUES (9001, 'test_kahvalti', 150);

-- -----------------------------------------------------------------------------
-- OdaTipi
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('OdaTipi: kapasite 0 olamaz', '23514',
    $q$INSERT INTO OdaTipi (tip_adi, kapasite, temel_fiyat) VALUES ('x', 0, 100)$q$);
SELECT pg_temp.hata_bekle('OdaTipi: temel fiyat negatif olamaz', '23514',
    $q$INSERT INTO OdaTipi (tip_adi, kapasite, temel_fiyat) VALUES ('x', 2, -1)$q$);
SELECT pg_temp.hata_bekle('OdaTipi: tip adı tekrar edemez', '23505',
    $q$INSERT INTO OdaTipi (tip_adi, kapasite, temel_fiyat) VALUES ('test_standart', 2, 100)$q$);

-- -----------------------------------------------------------------------------
-- Oda
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('Oda: geçersiz durum değeri', '23514',
    $q$INSERT INTO Oda (oda_no, kat, oda_tipi_id, durum) VALUES ('T-102', 1, 9001, 'yok_boyle')$q$);
SELECT pg_temp.hata_bekle('Oda: oda numarası tekrar edemez', '23505',
    $q$INSERT INTO Oda (oda_no, kat, oda_tipi_id) VALUES ('T-101', 1, 9001)$q$);
SELECT pg_temp.hata_bekle('Oda: var olmayan oda tipi (FK)', '23503',
    $q$INSERT INTO Oda (oda_no, kat, oda_tipi_id) VALUES ('T-103', 1, 999999)$q$);
SELECT pg_temp.hata_bekle('Oda: rezervasyonu olan oda silinemez (RESTRICT)', '23503',
    $q$DELETE FROM Oda WHERE id = 9001$q$);

-- -----------------------------------------------------------------------------
-- SezonFiyati
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('SezonFiyati: bitiş başlangıçtan önce olamaz', '23514',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat)
       VALUES (9001, '2027-06-10', '2027-06-01', 1500)$q$);
SELECT pg_temp.hata_bekle('SezonFiyati: gecelik fiyat negatif olamaz', '23514',
    $q$INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat)
       VALUES (9001, '2027-06-01', '2027-06-10', -5)$q$);

-- -----------------------------------------------------------------------------
-- Misafir
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('Misafir: e-posta tekrar edemez', '23505',
    $q$INSERT INTO Misafir (ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
       VALUES ('A', 'B', 'T0000000002', '1', 'test1@example.com', '1990-01-01')$q$);
SELECT pg_temp.hata_bekle('Misafir: TC/pasaport tekrar edemez', '23505',
    $q$INSERT INTO Misafir (ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
       VALUES ('A', 'B', 'T0000000001', '1', 'baska@example.com', '1990-01-01')$q$);
SELECT pg_temp.hata_bekle('Misafir: ad boş (NULL) olamaz', '23502',
    $q$INSERT INTO Misafir (ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
       VALUES (NULL, 'B', 'T0000000003', '1', 'c@example.com', '1990-01-01')$q$);

-- -----------------------------------------------------------------------------
-- Personel ve Kullanici
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('Personel: geçersiz görev', '23514',
    $q$INSERT INTO Personel (ad, soyad, gorev) VALUES ('A', 'B', 'asci')$q$);
SELECT pg_temp.hata_bekle('Kullanici: geçersiz rol', '23514',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol) VALUES ('u1', 'h', 'misafir_degil')$q$);
SELECT pg_temp.hata_bekle('Kullanici: misafir rolü misafir kaydı olmadan olamaz', '23514',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol) VALUES ('u2', 'h', 'misafir')$q$);
SELECT pg_temp.hata_bekle('Kullanici: resepsiyon rolü misafire bağlanamaz', '23514',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, misafir_id) VALUES ('u3', 'h', 'resepsiyon', 9001)$q$);
SELECT pg_temp.basari_bekle('Kullanici: geçerli misafir hesabı',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, misafir_id) VALUES ('u4', 'h', 'misafir', 9001)$q$);
SELECT pg_temp.hata_bekle('Kullanici: kullanıcı adı tekrar edemez', '23505',
    $q$INSERT INTO Kullanici (kullanici_adi, sifre_hash, rol, personel_id) VALUES ('u4', 'h', 'resepsiyon', 9001)$q$);

-- -----------------------------------------------------------------------------
-- Rezervasyon
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('Rezervasyon: çıkış girişten sonra olmalı', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
       VALUES (9001, 9001, '2027-02-10', '2027-02-10', 1)$q$);
SELECT pg_temp.hata_bekle('Rezervasyon: kişi sayısı 0 olamaz', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
       VALUES (9001, 9001, '2027-02-10', '2027-02-12', 0)$q$);
SELECT pg_temp.hata_bekle('Rezervasyon: geçersiz durum', '23514',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
       VALUES (9001, 9001, '2027-02-10', '2027-02-12', 1, 'bilinmiyor')$q$);
SELECT pg_temp.hata_bekle('Rezervasyon: var olmayan misafir (FK)', '23503',
    $q$INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi)
       VALUES (999999, 9001, '2027-02-10', '2027-02-12', 1)$q$);

-- -----------------------------------------------------------------------------
-- Konaklama, KonaklamaHizmeti, Odeme
-- -----------------------------------------------------------------------------
SELECT pg_temp.hata_bekle('Konaklama: bir rezervasyona tek konaklama', '23505',
    $q$INSERT INTO Konaklama (rezervasyon_id, islemi_yapan_personel_id) VALUES (9001, 9001)$q$);
SELECT pg_temp.hata_bekle('KonaklamaHizmeti: adet 0 olamaz', '23514',
    $q$INSERT INTO KonaklamaHizmeti (konaklama_id, hizmet_id, adet) VALUES (9001, 9001, 0)$q$);
SELECT pg_temp.hata_bekle('Odeme: geçersiz ödeme türü', '23514',
    $q$INSERT INTO Odeme (konaklama_id, tutar, odeme_turu) VALUES (9001, 100, 'cek')$q$);
SELECT pg_temp.hata_bekle('Odeme: tutar negatif olamaz', '23514',
    $q$INSERT INTO Odeme (konaklama_id, tutar, odeme_turu) VALUES (9001, -1, 'nakit')$q$);
SELECT pg_temp.basari_bekle('Odeme: geçerli ödeme',
    $q$INSERT INTO Odeme (konaklama_id, tutar, odeme_turu) VALUES (9001, 2300, 'kart')$q$);

-- -----------------------------------------------------------------------------
\echo 'TÜM ŞEMA KISIT TESTLERİ GEÇTİ (değişiklikler geri alınıyor)'
ROLLBACK;
