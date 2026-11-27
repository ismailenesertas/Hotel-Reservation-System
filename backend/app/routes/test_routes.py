from flask import Blueprint, jsonify, current_app
from app.utils.db import get_db_connection

test_bp = Blueprint('test', __name__)


@test_bp.route('/api/db-test', methods=['GET'])
def db_test():
    conn = get_db_connection()
    if conn is None:
        # 503: servis (veritabanı) şu an kullanılamıyor
        return jsonify({"status": "error", "message": "Veritabanına bağlanılamadı"}), 503

    try:
        with conn.cursor() as cursor:
            cursor.execute('SELECT version();')
            db_version = cursor.fetchone()[0]
        return jsonify({
            "status": "success",
            "message": "Veritabanı bağlantısı başarılı!",
            "version": db_version
        }), 200
    except Exception:
        # Ayrıntı yalnızca sunucu loguna; istemciye genel mesaj
        current_app.logger.exception("db-test sorgusu başarısız")
        return jsonify({"status": "error", "message": "Veritabanı sorgusu başarısız"}), 500
    finally:
        # Başarılı ya da hatalı her durumda bağlantı kapanır
        conn.close()
