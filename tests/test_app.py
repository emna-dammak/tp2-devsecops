import pytest
import sys
import os

# Ajouter le répertoire parent au path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import app, init_db

@pytest.fixture
def client():
    """Fixture pour créer un client de test"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        with app.app_context():
            init_db()
        yield client

def test_home_page(client):
    """Test de la page d'accueil"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'Bienvenue' in response.data

def test_users_page(client):
    """Test de la page des utilisateurs"""
    response = client.get('/users')
    assert response.status_code == 200
    assert b'Liste des utilisateurs' in response.data

def test_search_page(client):
    """Test de la page de recherche"""
    response = client.get('/search')
    assert response.status_code == 200
    assert b'Rechercher un utilisateur' in response.data

def test_search_result(client):
    """Test de la recherche d'utilisateur"""
    response = client.get('/search_result?username=test')
    assert response.status_code == 200
    assert b'sultats pour' in response.data

def test_api_user_not_found(client):
    """Test de l'API avec un utilisateur inexistant"""
    response = client.get('/api/user/9999')
    assert response.status_code == 404
    assert b'Utilisateur non' in response.data