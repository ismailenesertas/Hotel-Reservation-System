-- =============================================================================
-- MIGRATION 008: Temizlik kaydı ile oda durumunu güncelleyen TRIGGER
--
-- Neden : Trigger 2 (007) check-out'ta odayı 'temizlikte' yapar; odayı yeniden
--         'bos' yapan bir mekanizma olmazsa oda bir daha kiralanamaz.
--         Oda yaşam döngüsü: bos -> dolu -> temizlikte -> bos
-- Kural : TemizlikKaydi eklendiğinde:
--   'temizlendi'       ve oda 'temizlikte' veya 'bakimda' -> oda 'bos'
--   'bakimda'          ve oda 'dolu' değil               -> oda 'bakimda'
--   'kontrol_bekliyor'                                    -> değişiklik yok
--   Misafir içerideyken (oda 'dolu') yapılan günlük temizlik odayı boşaltmaz.
-- Not   : fn_temizlik_oda_durumu bir trigger FONKSİYONUDUR (RETURNS trigger).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_temizlik_oda_durumu()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.durum = 'temizlendi' THEN
        UPDATE Oda SET durum = 'bos'
        WHERE id = NEW.oda_id AND durum IN ('temizlikte', 'bakimda');

    ELSIF NEW.durum = 'bakimda' THEN
        UPDATE Oda SET durum = 'bakimda'
        WHERE id = NEW.oda_id AND durum <> 'dolu';
    END IF;

    RETURN NULL;   -- AFTER trigger
END;
$$;

DROP TRIGGER IF EXISTS trg_temizlik_oda_durumu ON TemizlikKaydi;
CREATE TRIGGER trg_temizlik_oda_durumu
    AFTER INSERT
    ON TemizlikKaydi
    FOR EACH ROW
    EXECUTE FUNCTION fn_temizlik_oda_durumu();

COMMIT;
