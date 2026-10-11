from flask import Flask
from dotenv import load_dotenv
import os

def create_app():
    load_dotenv()
    
    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    
    # Blueprint'leri kaydetme
    from app.routes.test_routes import test_bp
    app.register_blueprint(test_bp)

    return app