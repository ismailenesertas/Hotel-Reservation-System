-- =============================================================================
-- MIGRATION 003: Konaklama çıkış zamanı giriş zamanından önce olamaz
--
-- Sorun : Konaklama.gercek_cikis_zamani için tarih sırası kontrolü yoktu;
--         hatalı bir check-out kaydı giriş zamanından önceye yazılabiliyordu.
-- Çözüm : CHECK kısıtı. Çıkış henüz yapılmadıysa (NULL) kural uygulanmaz.
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

ALTER TABLE Konaklama DROP CONSTRAINT IF EXISTS chk_konaklama_cikis;
ALTER TABLE Konaklama ADD CONSTRAINT chk_konaklama_cikis CHECK (
    gercek_cikis_zamani IS NULL OR gercek_cikis_zamani >= gercek_giris_zamani
);

COMMIT;
