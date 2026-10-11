import psycopg2
from psycopg2.extras import RealDictCursor
import os

def get_db_connection():
    """
    PostgreSQL veritabanına bağlantı sağlar.
    Verileri sözlük (dictionary) yapısında döndürmek için RealDictCursor kullanır.
    """
    try:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            database=os.getenv('DB_NAME', 'otel_db'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASS', 'postgres'),
            port=os.getenv('DB_PORT', '5432')
        )
        return conn
    except Exception as e:
        print(f"Veritabanı bağlantı hatası: {e}")
        return None