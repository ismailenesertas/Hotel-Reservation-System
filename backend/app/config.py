"""
Uygulama ayarlarının tek kaynağı.

Tüm ayarlar ortam değişkenlerinden (backend/.env) okunur. Gizli değerlerin
koddaki varsayılanı YOKTUR: eksikse uygulama açık bir hata mesajıyla durur
(fail-fast). Böylece yanlış/eksik yapılandırma sessizce gözden kaçmaz.
"""
import os

# Değeri mutlaka .env'de verilmesi gereken gizli ayarlar
REQUIRED_SECRETS = ("SECRET_KEY", "JWT_SECRET_KEY", "DB_PASS")


class ConfigError(RuntimeError):
    """Zorunlu bir ortam değişkeni eksik olduğunda fırlatılır."""


def load_config():
    """Ortam değişkenlerinden Flask config sözlüğünü oluşturur."""
    missing = [name for name in REQUIRED_SECRETS if not os.getenv(name)]
    if missing:
        raise ConfigError(
            "Eksik ortam değişkenleri: " + ", ".join(missing)
            + ". backend/.env.example dosyasını backend/.env olarak kopyalayıp doldurun."
        )

    return {
        "SECRET_KEY": os.getenv("SECRET_KEY"),
        "JWT_SECRET_KEY": os.getenv("JWT_SECRET_KEY"),
        # Gizli olmayan bağlantı ayarları için güvenli varsayılanlar
        "DB_HOST": os.getenv("DB_HOST", "localhost"),
        "DB_PORT": os.getenv("DB_PORT", "5432"),
        "DB_NAME": os.getenv("DB_NAME", "otel_db"),
        "DB_USER": os.getenv("DB_USER", "postgres"),
        "DB_PASS": os.getenv("DB_PASS"),
    }
