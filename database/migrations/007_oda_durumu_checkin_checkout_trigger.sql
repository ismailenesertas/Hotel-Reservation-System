-- =============================================================================
-- MIGRATION 007: Check-in / check-out ile oda durumunu güncelleyen TRIGGER
-- (Şartname: Zorunlu Trigger 2)
--
-- Kural : Check-in  = Konaklama kaydı eklenir           -> Oda.durum = 'dolu'
--         Check-out = gercek_cikis_zamani doldurulur    -> Oda.durum = 'temizlikte'
-- Neden AFTER: Konaklama satırı başarıyla yazıldıktan sonra oda güncellenir.
--         İşlem herhangi bir nedenle geri alınırsa (ROLLBACK) oda güncellemesi de
--         aynı transaction'da olduğu için birlikte geri alınır.
-- Not   : Oda, Konaklama -> Rezervasyon -> Oda yolu ile bulunur (Konaklama'da
--         oda_id tutulmaz; 3NF gereği oda bilgisi yalnızca Rezervasyon'dadır).
--         fn_oda_durumu_guncelle bir trigger FONKSİYONUDUR (RETURNS trigger).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_oda_durumu_guncelle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_oda_id INT;
BEGIN
    SELECT r.oda_id INTO v_oda_id
    FROM Rezervasyon r
    WHERE r.id = NEW.rezervasyon_id;

    IF TG_OP = 'INSERT' THEN
        -- Check-in
        UPDATE Oda SET durum = 'dolu' WHERE id = v_oda_id;

    ELSIF TG_OP = 'UPDATE'
          AND OLD.gercek_cikis_zamani IS NULL
          AND NEW.gercek_cikis_zamani IS NOT NULL THEN
        -- Check-out (çıkış zamanı ilk kez dolduruldu)
        UPDATE Oda SET durum = 'temizlikte' WHERE id = v_oda_id;
    END IF;

    RETURN NULL;   -- AFTER trigger: dönüş değeri kullanılmaz
END;
$$;

DROP TRIGGER IF EXISTS trg_konaklama_oda_durumu ON Konaklama;
CREATE TRIGGER trg_konaklama_oda_durumu
    AFTER INSERT OR UPDATE OF gercek_cikis_zamani
    ON Konaklama
    FOR EACH ROW
    EXECUTE FUNCTION fn_oda_durumu_guncelle();

COMMIT;
