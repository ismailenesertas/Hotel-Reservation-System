-- =============================================================================
-- MIGRATION 009: Rezervasyon ve ödeme değişikliklerini IslemLog'a yazan TRIGGER
-- (Şartname: Zorunlu Trigger 3)
--
-- Kayıt : Hangi tablo, hangi işlem (INSERT/UPDATE/DELETE), hangi kayıt, ne zaman,
--         eski ve yeni satırın tamamı (JSONB).
-- Kullanıcı: Backend işlem başında  SET LOCAL app.kullanici_id = '<id>'  çalıştırırsa
--         işlemi yapan kullanıcı 'aciklama' sütununa yazılır; ayar yoksa 'sistem'.
-- Not   : Hiçbir değeri değiştirmeyen UPDATE kaydedilmez (gereksiz log oluşmaz).
--         AFTER trigger olduğu için yalnızca başarılı değişiklikler loglanır; işlem
--         ROLLBACK olursa log satırı da geri alınır (veri ile log her zaman tutarlı).
--         Tek fonksiyon iki tabloda kullanılır: tablo adı TG_TABLE_NAME'den gelir.
--         fn_islem_log bir trigger FONKSİYONUDUR (RETURNS trigger).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_islem_log()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_kullanici TEXT := NULLIF(current_setting('app.kullanici_id', true), '');
BEGIN
    IF TG_OP = 'UPDATE' AND OLD IS NOT DISTINCT FROM NEW THEN
        RETURN NULL;   -- değişiklik yok, loglama
    END IF;

    INSERT INTO IslemLog (tablo_adi, islem_turu, kayit_id, eski_veri, yeni_veri, aciklama)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        'Kullanıcı: ' || COALESCE(v_kullanici, 'sistem')
    );

    RETURN NULL;   -- AFTER trigger
END;
$$;

DROP TRIGGER IF EXISTS trg_rezervasyon_log ON Rezervasyon;
CREATE TRIGGER trg_rezervasyon_log
    AFTER INSERT OR UPDATE OR DELETE
    ON Rezervasyon
    FOR EACH ROW
    EXECUTE FUNCTION fn_islem_log();

DROP TRIGGER IF EXISTS trg_odeme_log ON Odeme;
CREATE TRIGGER trg_odeme_log
    AFTER INSERT OR UPDATE OR DELETE
    ON Odeme
    FOR EACH ROW
    EXECUTE FUNCTION fn_islem_log();

COMMIT;
