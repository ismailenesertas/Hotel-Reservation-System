-- =============================================================================
-- MIGRATION 011: VIEW - Oda bazında güncel durum ve son temizlik tarihi
-- (Şartname: Zorunlu View 2)
--
-- İçerik: Her oda için numara, kat, tip, kapasite, güncel durum,
--         son temizlik tarihi ve temizleyen personel ('temizlendi' kayıtlarından),
--         odada şu an kalan misafir ve planlanan çıkış tarihi (varsa).
-- Teknik: LEFT JOIN LATERAL ile her oda için "en son temizlik kaydı" ve
--         "aktif konaklama" alt sorgusu çalıştırılır; temizlik kaydı veya
--         misafiri olmayan odalar da listede yer alır (LEFT JOIN).
-- Kullanım: SELECT * FROM vw_oda_durumu ORDER BY oda_no;
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

DROP VIEW IF EXISTS vw_oda_durumu;

CREATE VIEW vw_oda_durumu AS
SELECT
    o.id            AS oda_id,
    o.oda_no,
    o.kat,
    ot.tip_adi      AS oda_tipi,
    ot.kapasite,
    o.durum,
    st.tarih        AS son_temizlik_tarihi,
    st.personel_adi AS son_temizleyen,
    ak.misafir_adi  AS mevcut_misafir,
    ak.cikis_tarihi AS planlanan_cikis
FROM Oda o
JOIN OdaTipi ot ON ot.id = o.oda_tipi_id
-- En son "temizlendi" kaydı
LEFT JOIN LATERAL (
    SELECT t.tarih, p.ad || ' ' || p.soyad AS personel_adi
    FROM TemizlikKaydi t
    JOIN Personel p ON p.id = t.personel_id
    WHERE t.oda_id = o.id AND t.durum = 'temizlendi'
    ORDER BY t.tarih DESC
    LIMIT 1
) st ON true
-- Odada şu an kalan misafir (check-in yapılmış, check-out yapılmamış)
LEFT JOIN LATERAL (
    SELECT m.ad || ' ' || m.soyad AS misafir_adi, r.cikis_tarihi
    FROM Konaklama k
    JOIN Rezervasyon r ON r.id = k.rezervasyon_id
    JOIN Misafir m     ON m.id = r.misafir_id
    WHERE r.oda_id = o.id AND k.gercek_cikis_zamani IS NULL
    ORDER BY k.gercek_giris_zamani DESC
    LIMIT 1
) ak ON true;

COMMENT ON VIEW vw_oda_durumu IS
    'Oda bazında güncel durum, son temizlik tarihi/personeli ve odadaki misafir';

COMMIT;
