"""
Cette version contient des vulnérabilités intentionnelles pour la démonstration.
NE PAS UTILISER EN PRODUCTION!
"""
from flask import Flask, request, render_template_string
import sqlite3
import os

app = Flask(__name__)

# Configuration de la base de données
DATABASE = 'users.db'

def init_db():
    """Initialise la base de données"""
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            email TEXT NOT NULL
        )
    ''')
    conn.commit()
    conn.close()

@app.route('/')
def home():
    """Page d'accueil"""
    return render_template_string('''
        <h1>Bienvenue sur l'application de démonstration</h1>
        <p><a href="/users">Voir les utilisateurs</a></p>
        <p><a href="/search">Rechercher un utilisateur</a></p>
        <p><a href="/admin">Panel Admin</a></p>
    ''')

@app.route('/users')
def list_users():
    """Liste tous les utilisateurs"""
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('SELECT id, username, email FROM users')
    users = cursor.fetchall()
    conn.close()
    
    html = '<h1>Liste des utilisateurs</h1><ul>'
    for user in users:
        html += f'<li>{user[0]} - {user[1]} - {user[2]}</li>'
    html += '</ul>'
    return render_template_string(html)

@app.route('/search')
def search():
    """Formulaire de recherche"""
    return render_template_string('''
        <h1>Rechercher un utilisateur</h1>
        <form action="/search_result" method="get">
            <input type="text" name="username" placeholder="Nom d'utilisateur">
            <button type="submit">Rechercher</button>
        </form>
    ''')

# VULNÉRABILITÉ 1: Injection SQL
@app.route('/search_result')
def search_result():
    """Résultat de recherche - VULNÉRABLE À L'INJECTION SQL"""
    username = request.args.get('username', '')
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    # DANGER: Concaténation directe sans paramètres liés
    query = f"SELECT id, username, email FROM users WHERE username LIKE '%{username}%'"
    cursor.execute(query)
    users = cursor.fetchall()
    conn.close()
    
    html = f'<h1>Résultats pour: {username}</h1><ul>'
    for user in users:
        html += f'<li>{user[0]} - {user[1]} - {user[2]}</li>'
    html += '</ul>'
    html += '<p><a href="/search">Nouvelle recherche</a></p>'
    
    return render_template_string(html)

# VULNÉRABILITÉ 2: Route admin non protégée
@app.route('/admin')
def admin_panel():
    """Panel d'administration - NON PROTÉGÉ"""
    # DANGER: Pas d'authentification requise
    return render_template_string('''
        <h1>Panel Administrateur</h1>
        <p>Bienvenue dans le panel d'administration!</p>
        <ul>
            <li><a href="/admin/delete_all">Supprimer tous les utilisateurs</a></li>
            <li><a href="/admin/config">Configuration système</a></li>
        </ul>
    ''')

# VULNÉRABILITÉ 3: Endpoint dangereux non protégé
@app.route('/admin/delete_all')
def delete_all_users():
    """Supprime tous les utilisateurs - NON PROTÉGÉ"""
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('DELETE FROM users')
    conn.commit()
    conn.close()
    return 'Tous les utilisateurs ont été supprimés!'

# VULNÉRABILITÉ 4: Exposition d'informations sensibles
@app.route('/admin/config')
def show_config():
    """Affiche la configuration - EXPOSE DES SECRETS"""
    # DANGER: Exposition de variables d'environnement
    config = {
        'database': DATABASE,
        'secret_key': 'super_secret_key_123',  # Secret hardcodé
        'api_key': os.environ.get('API_KEY', 'default_api_key'),
        'debug': True
    }
    return config

@app.route('/api/user/<int:user_id>')
def get_user(user_id):
    """API pour récupérer un utilisateur par ID"""
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('SELECT id, username, email FROM users WHERE id = ?', (user_id,))
    user = cursor.fetchone()
    conn.close()
    
    if user:
        return {
            'id': user[0],
            'username': user[1],
            'email': user[2]
        }
    return {'error': 'Utilisateur non trouvé'}, 404

if __name__ == '__main__':
    init_db()
    # VULNÉRABILITÉ 5: Debug mode activé en production
    app.run(host='0.0.0.0', port=5000, debug=True)