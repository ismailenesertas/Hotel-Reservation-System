from flask import Flask
from dotenv import load_dotenv

from app.config import load_config

def create_app():
    load_dotenv()

    app = Flask(__name__)
    # Eksik gizli ayar varsa ConfigError ile burada durur
    app.config.update(load_config())
    
    # Blueprint'leri kaydetme
    from app.routes.test_routes import test_bp
    app.register_blueprint(test_bp)

    return app