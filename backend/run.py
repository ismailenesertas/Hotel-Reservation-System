import os

from app import create_app

app = create_app()  # .env burada yüklenir (load_dotenv)

if __name__ == '__main__':
    # Güvenli varsayılanlar: debug kapalı, yalnızca bu bilgisayardan erişim.
    # Geliştirirken backend/.env içinde FLASK_DEBUG=1 yapılabilir.
    debug = os.getenv('FLASK_DEBUG', '0').lower() in ('1', 'true', 'yes')
    host = os.getenv('FLASK_HOST', '127.0.0.1')
    app.run(host=host, port=5000, debug=debug)
