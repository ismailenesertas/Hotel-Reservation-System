-- =============================================================================
-- MIGRATION 010: VIEW - Bugün giriş ve çıkış yapacak misafirler
-- (Şartname: Zorunlu View 1)
--
-- İçerik: Giriş tarihi bugün olan (gelecek misafir) ve çıkış tarihi bugün olan
--         (ayrılacak misafir) aktif rezervasyonlar. İptal edilenler gösterilmez.
--         Resepsiyon için işlemin yapılıp yapılmadığı da gösterilir
--         (check_in_yapildi / check_out_yapildi).
-- Kullanım: SELECT * FROM vw_bugun_giris_cikis ORDER BY hareket, oda_no;
-- Not   : "Bugün" = CURRENT_DATE (veritabanı sunucusunun tarihi).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

DROP VIEW IF EXISTS vw_bugun_giris_cikis;

CREATE VIEW vw_bugun_giris_cikis AS
SELECT
    CASE WHEN r.giris_tarihi = CURRENT_DATE THEN 'giris' ELSE 'cikis' END AS hareket,
    r.id                AS rezervasyon_id,
    m.id                AS misafir_id,
    m.ad || ' ' || m.soyad AS misafir_adi,
    m.telefon,
    o.oda_no,
    ot.tip_adi          AS oda_tipi,
    r.giris_tarihi,
    r.cikis_tarihi,
    r.kisi_sayisi,
    r.durum             AS rezervasyon_durumu,
    k.id                AS konaklama_id,
    (k.id IS NOT NULL)                      AS check_in_yapildi,
    (k.gercek_cikis_zamani IS NOT NULL)     AS check_out_yapildi
FROM Rezervasyon r
JOIN Misafir  m  ON m.id  = r.misafir_id
JOIN Oda      o  ON o.id  = r.oda_id
JOIN OdaTipi  ot ON ot.id = o.oda_tipi_id
LEFT JOIN Konaklama k ON k.rezervasyon_id = r.id   -- check-in yapılmamışsa NULL
WHERE r.durum <> 'iptal'
  AND (r.giris_tarihi = CURRENT_DATE OR r.cikis_tarihi = CURRENT_DATE);

COMMENT ON VIEW vw_bugun_giris_cikis IS
    'Bugün giriş (hareket=giris) ve çıkış (hareket=cikis) yapacak misafirler; resepsiyon günlük listesi';

COMMIT;
