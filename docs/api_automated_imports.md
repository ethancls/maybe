# Documentation API: Imports automatisés pour applications tierces

Cette documentation explique comment intégrer des applications tierces avec Maybe pour automatiser l'import de données financières.

## Vue d'ensemble

Le système d'import automatisé de Maybe permet aux applications tierces d'envoyer des données de transaction via:
1. **API REST**: Pour l'envoi direct de données
2. **Webhooks**: Pour les notifications automatiques lors de nouvelles transactions

## Configuration d'intégration

Avant d'utiliser l'API, vous devez configurer une intégration dans Maybe:

### Modèle IntegrationConfig

```ruby
# Créer une nouvelle configuration d'intégration
integration = family.integration_configs.create!(
  name: "Mon App Bancaire",
  app_type: "banking", # banking, accounting, ecommerce, etc.
  description: "Integration avec mon application bancaire",
  webhook_url: "https://monapp.com/webhook" # optionnel
)

# Générer un token API sécurisé
integration.generate_api_token!
```

## API Import Endpoint

### POST /api/v1/imports

Crée un nouvel import de données depuis une application tierce.

#### Headers requis
```
Content-Type: application/json
X-Api-Key: YOUR_API_KEY
```

#### Paramètres
```json
{
  "import": {
    "source_app_name": "Mon App Bancaire",
    "source_app_version": "1.0.0",
    "account_id": "uuid-optionnel-du-compte",
    "auto_import": false,
    "transactions": [
      {
        "date": "2024-08-19",
        "amount": "-45.99",
        "name": "Épicerie",
        "description": "Courses hebdomadaires",
        "account_name": "Compte Courant",
        "category": "Alimentation",
        "currency": "EUR",
        "tags": ["courses", "alimentation"],
        "notes": "Achat chez Carrefour"
      }
    ]
  }
}
```

#### Champs requis pour chaque transaction
- `date`: Date au format ISO (YYYY-MM-DD)
- `amount`: Montant (négatif pour dépenses, positif pour revenus)

#### Champs optionnels
- `name` / `description`: Description de la transaction
- `account_name`: Nom du compte (si pas d'account_id spécifié)
- `category`: Catégorie de la transaction
- `currency`: Devise (par défaut: devise de la famille)
- `tags`: Array de tags
- `notes`: Notes additionnelles

#### Réponses

**Succès (201 Created)**
```json
{
  "id": "uuid-de-l-import",
  "status": "created",
  "message": "Import créé avec succès",
  "transactions_count": 1,
  "configuration_url": "https://maybe.com/imports/uuid/configuration"
}
```

**Auto-import activé (202 Accepted)**
```json
{
  "id": "uuid-de-l-import",
  "status": "processing", 
  "message": "Import créé et traitement démarré",
  "transactions_count": 1
}
```

**Erreur de validation (422)**
```json
{
  "error": "validation_failed",
  "message": "Données de transaction invalides",
  "errors": [
    "Transaction à l'index 0 champ requis manquant: date"
  ]
}
```

## Webhooks

Pour les intégrations supportant les webhooks, vous pouvez recevoir des notifications automatiques.

### POST /webhooks/integration_import

#### Headers requis
```
Content-Type: application/json
X-Integration-Token: TOKEN_GENERE_PAR_MAYBE
```

#### Payload
```json
{
  "source_version": "1.0.0",
  "account_name": "Compte Courant",
  "transactions": [
    {
      "date": "2024-08-19",
      "amount": "-45.99",
      "description": "Nouvelle transaction",
      "category": "Alimentation"
    }
  ]
}
```

#### Réponse
```json
{
  "status": "accepted",
  "message": "Webhook reçu, import mis en file d'attente",
  "transactions_count": 1
}
```

## Exemples d'intégration

### Python (requests)
```python
import requests

# Configuration
api_key = "votre_api_key"
base_url = "https://maybe.com/api/v1"

# Envoi de transactions
data = {
    "import": {
        "source_app_name": "Mon App Python",
        "auto_import": True,
        "transactions": [
            {
                "date": "2024-08-19",
                "amount": "-25.50",
                "description": "Café",
                "category": "Restauration"
            }
        ]
    }
}

response = requests.post(
    f"{base_url}/imports",
    json=data,
    headers={"X-Api-Key": api_key}
)

print(response.json())
```

### JavaScript (fetch)
```javascript
const apiKey = 'votre_api_key';
const baseUrl = 'https://maybe.com/api/v1';

const importData = {
  import: {
    source_app_name: 'Mon App JS',
    transactions: [
      {
        date: '2024-08-19',
        amount: '-25.50',
        description: 'Café',
        category: 'Restauration'
      }
    ]
  }
};

fetch(`${baseUrl}/imports`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Api-Key': apiKey
  },
  body: JSON.stringify(importData)
})
.then(response => response.json())
.then(data => console.log(data));
```

## Types d'applications supportés

- `banking`: Applications bancaires
- `accounting`: Logiciels de comptabilité  
- `ecommerce`: Plateformes e-commerce
- `payment_processor`: Processeurs de paiement
- `expense_tracker`: Gestionnaires de dépenses
- `investment_platform`: Plateformes d'investissement
- `custom`: Intégrations personnalisées

## Sécurité

- Utilisez HTTPS pour toutes les requêtes
- Stockez les clés API de manière sécurisée
- Validez les webhooks avec le token d'intégration
- Limitez les permissions API au minimum nécessaire

## Limitations

- Maximum 1000 transactions par import
- Rate limiting: voir les headers de réponse
- Les imports automatiques nécessitent une validation manuelle si des erreurs de mapping sont détectées