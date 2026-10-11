from flask import Blueprint, jsonify
from app.utils.db import get_db_connection

test_bp = Blueprint('test', __name__)

@test_bp.route('/api/db-test', methods=['GET'])
def db_test():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT version();')
            db_version = cursor.fetchone()
            cursor.close()
            conn.close()
            return jsonify({
                "status": "success", 
                "message": "Veritabanı bağlantısı başarılı!",
                "version": db_version['version']
            }), 200
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500
    return jsonify({"status": "error", "message": "Bağlantı kurulamadı"}), 500