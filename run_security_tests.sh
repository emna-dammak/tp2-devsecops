#!/bin/bash

# Script pour exécuter les tests de sécurité localement
# Usage: ./run_security_tests.sh

set -e

echo "🔒 Démarrage des tests de sécurité locaux..."
echo "============================================"
echo ""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Créer le dossier pour les rapports
mkdir -p reports

# 1. Tests unitaires
echo "📦 1. Exécution des tests unitaires..."
python -m pytest tests/ -v --cov=app --cov-report=html --cov-report=term
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tests unitaires: PASSÉS${NC}"
else
    echo -e "${RED}❌ Tests unitaires: ÉCHEC${NC}"
    exit 1
fi
echo ""

# 2. SAST - Bandit
echo "🔍 2. Analyse statique avec Bandit..."
bandit -r app.py -f json -o reports/bandit-report.json || true
bandit -r app.py -f txt || true

# Vérifier les vulnérabilités HIGH/CRITICAL seulement
if [ -f "reports/bandit-report.json" ]; then
    high_count=$(grep -o '"SEVERITY.HIGH": [0-9]*' reports/bandit-report.json | grep -o '[0-9]*' || echo "0")
    if [ "$high_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Bandit: $high_count vulnérabilités HIGH détectées${NC}"
    else
        echo -e "${GREEN}✅ Bandit: Aucune vulnérabilité critique (HIGH/CRITICAL)${NC}"
    fi
else
    echo -e "${GREEN}✅ Bandit: Scan complété${NC}"
fi
echo ""

# 3. SCA - Safety
echo "📦 3. Analyse des dépendances avec Safety..."
# Nouvelle syntaxe pour Safety 3.x
safety check --file requirements.txt --output json > reports/safety-report.json 2>&1 || true
safety check --file requirements.txt || true

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Safety: Aucune dépendance vulnérable${NC}"
else
    echo -e "${YELLOW}⚠️  Safety: Dépendances vulnérables détectées (vérifiez reports/safety-report.json)${NC}"
fi
echo ""

# 4. Analyse des secrets
echo "🔐 4. Recherche de secrets hardcodés..."
if command -v gitleaks &> /dev/null; then
    gitleaks detect --source . --report-path reports/gitleaks-report.json
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Gitleaks: Aucun secret détecté${NC}"
    else
        echo -e "${RED}❌ Gitleaks: Secrets détectés${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Gitleaks non installé, étape ignorée${NC}"
fi
echo ""

# 5. Construction Docker
echo "🐳 5. Construction de l'image Docker..."
docker build -t security-test-app:latest .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Image Docker construite${NC}"
else
    echo -e "${RED}❌ Échec de construction Docker${NC}"
    exit 1
fi
echo ""

# 6. Scan de l'image Docker avec Trivy
echo "🔎 6. Scan de sécurité Docker avec Trivy..."
if command -v trivy &> /dev/null; then
    trivy image --severity HIGH,CRITICAL security-test-app:latest
    trivy image --format json --output reports/trivy-report.json security-test-app:latest
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Trivy: Scan complété${NC}"
    else
        echo -e "${YELLOW}⚠️  Trivy: Vulnérabilités détectées${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Trivy non installé, étape ignorée${NC}"
    echo "   Installation: brew install trivy (macOS) ou apt-get install trivy (Linux)"
fi
echo ""

# 7. Démarrage de l'application pour DAST
echo "🚀 7. Démarrage de l'application..."
docker run -d -p 5000:5000 --name security-test-app security-test-app:latest
sleep 10

# Vérifier que l'application est démarrée
if curl -f http://localhost:5000/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application démarrée avec succès${NC}"
else
    echo -e "${RED}❌ Échec du démarrage de l'application${NC}"
    docker logs security-test-app
    docker stop security-test-app
    docker rm security-test-app
    exit 1
fi
echo ""

# 8. DAST - OWASP ZAP (si disponible)
echo "🌐 8. Analyse dynamique avec OWASP ZAP..."
if command -v docker &> /dev/null; then
    docker run --rm --network="host" \
        -v $(pwd)/reports:/zap/wrk:rw \
        owasp/zap2docker-stable:latest \
        zap-baseline.py -t http://localhost:5000 -r zap-report.html || true
    
    if [ -f "reports/zap-report.html" ]; then
        echo -e "${GREEN}✅ ZAP: Scan complété (voir reports/zap-report.html)${NC}"
    else
        echo -e "${YELLOW}⚠️  ZAP: Rapport non généré${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Docker non disponible pour ZAP${NC}"
fi
echo ""

# 9. Nettoyage
echo "🧹 9. Nettoyage..."
docker stop security-test-app
docker rm security-test-app
echo -e "${GREEN}✅ Nettoyage terminé${NC}"
echo ""

# Résumé final
echo "============================================"
echo "📊 RÉSUMÉ DES TESTS DE SÉCURITÉ"
echo "============================================"
echo ""
echo "Rapports générés dans le dossier: ./reports/"
echo "  - bandit-report.json"
echo "  - safety-report.json"
echo "  - trivy-report.json (si Trivy installé)"
echo "  - zap-report.html (si ZAP exécuté)"
echo ""
echo "Couverture de code: ./htmlcov/index.html"
echo ""
echo -e "${GREEN}✅ Tests de sécurité terminés!${NC}"
echo ""

# Ouvrir les rapports (optionnel)
read -p "Voulez-vous ouvrir le rapport de couverture? (o/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    if command -v open &> /dev/null; then
        open htmlcov/index.html
    elif command -v xdg-open &> /dev/null; then
        xdg-open htmlcov/index.html
    else
        echo "Ouvrez manuellement: htmlcov/index.html"
    fi
fi