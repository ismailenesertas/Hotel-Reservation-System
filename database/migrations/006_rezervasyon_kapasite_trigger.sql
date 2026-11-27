-- =============================================================================
-- MIGRATION 006: Kişi sayısı oda tipinin kapasitesini aşamaz (TRIGGER)
--
-- Neden : Rezervasyon.kisi_sayisi ile OdaTipi.kapasite farklı tablolarda.
--         CHECK kısıtı başka tabloya bakamaz; bu yüzden kural trigger ile uygulanır.
-- Kural : kisi_sayisi <= (Oda -> OdaTipi).kapasite
-- Ne zaman: INSERT'te ve oda_id / kisi_sayisi değiştiren UPDATE'te.
-- Not   : fn_rezervasyon_kapasite_kontrol bir trigger FONKSİYONUDUR (RETURNS trigger).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_rezervasyon_kapasite_kontrol()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    oda_kapasitesi INT;
BEGIN
    SELECT ot.kapasite INTO oda_kapasitesi
    FROM Oda o
    JOIN OdaTipi ot ON ot.id = o.oda_tipi_id
    WHERE o.id = NEW.oda_id;

    -- Oda yoksa kontrolü FOREIGN KEY'e bırak (anlamlı FK hatası versin)
    IF oda_kapasitesi IS NOT NULL AND NEW.kisi_sayisi > oda_kapasitesi THEN
        RAISE EXCEPTION 'Kapasite aşımı: oda % en fazla % kişiliktir, % kişi istendi',
            NEW.oda_id, oda_kapasitesi, NEW.kisi_sayisi
            USING ERRCODE = 'check_violation';   -- SQLSTATE 23514
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rezervasyon_kapasite ON Rezervasyon;
CREATE TRIGGER trg_rezervasyon_kapasite
    BEFORE INSERT OR UPDATE OF oda_id, kisi_sayisi
    ON Rezervasyon
    FOR EACH ROW
    EXECUTE FUNCTION fn_rezervasyon_kapasite_kontrol();

COMMIT;
