-- =============================================================================
-- TÜM VERİTABANI TESTLERİNİ ÇALIŞTIRIR
-- Ön koşul: schema.sql ve migrate.sql uygulanmış olmalı.
-- Her test dosyası kendi transaction'ında çalışır ve ROLLBACK ile biter;
-- veritabanında kalıcı değişiklik olmaz. İlk başarısız testte durur.
-- =============================================================================
\set ON_ERROR_STOP on

\ir schema_constraints_test.sql
\ir 001_durum_degerleri_test.sql
\ir 002_kullanici_tekil_hesap_test.sql
\ir 003_konaklama_cikis_test.sql
\ir 004_sezon_fiyati_cakisma_test.sql
\ir 005_rezervasyon_cakisma_test.sql
\ir 006_rezervasyon_kapasite_test.sql

\echo '=== TÜM VERİTABANI TESTLERİ GEÇTİ ==='
