import psycopg2
from flask import current_app


def get_db_connection():
    """
    PostgreSQL veritabanına bağlantı açar.

    Bağlantı bilgileri yalnızca uygulama config'inden (app/config.py ->
    backend/.env) okunur; kodda varsayılan parola yoktur.
    Bağlantı kurulamazsa hatayı loglar ve None döndürür.
    """
    cfg = current_app.config
    try:
        return psycopg2.connect(
            host=cfg["DB_HOST"],
            port=cfg["DB_PORT"],
            dbname=cfg["DB_NAME"],
            user=cfg["DB_USER"],
            password=cfg["DB_PASS"],
            connect_timeout=5,  # DB kapalıysa isteği süresiz bekletme
        )
    except psycopg2.OperationalError as e:
        # psycopg2 hata mesajı parolayı içermez; ayrıntı yalnızca sunucu loguna yazılır
        current_app.logger.error("Veritabanı bağlantı hatası: %s", e)
        return None
