-- =============================================================================
-- TÜM MIGRATION'LARI SIRAYLA UYGULAR
-- Ön koşul: schema.sql (baseline) bir kez yüklenmiş olmalı.
-- Her migration tekrar çalıştırılabilir (idempotent) ve kendi transaction'ı
-- içindedir; bu dosyayı birden fazla kez çalıştırmak güvenlidir.
-- Yeni migration eklendiğinde buraya numara sırasıyla eklenir.
-- =============================================================================
\set ON_ERROR_STOP on

\ir migrations/001_durum_degerleri_ascii.sql
\ir migrations/002_kullanici_tekil_hesap.sql
\ir migrations/003_konaklama_cikis_kontrolu.sql

\echo 'TÜM MIGRATIONLAR UYGULANDI'
