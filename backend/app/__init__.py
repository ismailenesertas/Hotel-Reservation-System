from flask import Flask
from dotenv import load_dotenv
import os

def create_app():
    # Çevresel değişkenleri yükle
    load_dotenv()
    
    app = Flask(__name__)
    
    # Konfigürasyonları ayarla
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')
    
    # Basit bir test route'u
    @app.route('/api/health', methods=['GET'])
    def health_check():
        return {"status": "success", "message": "API calisiyor!"}, 200
        
    # İleride route'larımızı (blueprint'leri) buraya kaydedeceğiz
    # from app.routes.auth_routes import auth_bp
    # app.register_blueprint(auth_bp, url_prefix='/api/auth')

    return app