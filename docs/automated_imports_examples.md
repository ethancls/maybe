# Exemple d'utilisation: Système d'import automatisé Maybe

Ce document fournit des exemples pratiques d'utilisation du nouveau système d'import automatisé.

## Configuration d'une intégration

### 1. Créer une configuration d'intégration

```ruby
# Dans une console Rails ou migration
family = Family.find_by(name: "Ma Famille")

# Créer une configuration pour une application bancaire
banking_integration = family.integration_configs.create!(
  name: "Mon App Bancaire",
  app_type: "banking",
  description: "Intégration avec notre système bancaire interne",
  webhook_url: "https://monapp.com/webhooks/maybe"
)

# Générer un token API sécurisé
banking_integration.generate_api_token!
puts "Token d'intégration: #{banking_integration.api_token}"
```

### 2. Configuration pour une app de comptabilité

```ruby
accounting_integration = family.integration_configs.create!(
  name: "Sage Comptabilité",
  app_type: "accounting", 
  description: "Synchronisation avec Sage"
)
accounting_integration.generate_api_token!
```

## Utilisation de l'API REST

### Curl - Import manuel

```bash
curl -X POST https://maybe.com/api/v1/imports \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{
    "import": {
      "source_app_name": "Mon App Bancaire",
      "source_app_version": "2.1.0",
      "transactions": [
        {
          "date": "2024-08-19",
          "amount": "-75.50",
          "description": "Restaurant Le Comptoir",
          "category": "Restauration",
          "account_name": "Compte Courant",
          "currency": "EUR",
          "tags": ["restaurants", "sortie"],
          "notes": "Déjeuner d'\''affaires avec client"
        },
        {
          "date": "2024-08-19", 
          "amount": "2500.00",
          "description": "Virement salaire",
          "category": "Salaire",
          "account_name": "Compte Courant",
          "currency": "EUR"
        }
      ]
    }
  }'
```

### Curl - Import automatique

```bash
curl -X POST https://maybe.com/api/v1/imports \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{
    "import": {
      "source_app_name": "Mon App Bancaire",
      "auto_import": true,
      "transactions": [
        {
          "date": "2024-08-19",
          "amount": "-25.99",
          "description": "Abonnement Netflix",
          "category": "Divertissement"
        }
      ]
    }
  }'
```

## Utilisation des Webhooks

### Configuration du webhook côté application tierce

```javascript
// Dans votre application tierce
const webhookUrl = 'https://maybe.com/webhooks/integration_import';
const integrationToken = 'TOKEN_GENERE_PAR_MAYBE';

// Envoyer de nouvelles transactions
async function sendTransactionsToMaybe(transactions) {
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Integration-Token': integrationToken
    },
    body: JSON.stringify({
      source_version: '1.0.0',
      account_name: 'Compte Principal',
      transactions: transactions
    })
  });
  
  return response.json();
}

// Exemple d'utilisation
const newTransactions = [
  {
    date: '2024-08-19',
    amount: '-12.50',
    description: 'Café Starbucks',
    category: 'Café'
  }
];

sendTransactionsToMaybe(newTransactions)
  .then(result => console.log('Import queued:', result))
  .catch(err => console.error('Error:', err));
```

### Python - Application e-commerce

```python
import requests
import json
from datetime import datetime

class MaybeIntegration:
    def __init__(self, webhook_url, token):
        self.webhook_url = webhook_url
        self.token = token
    
    def send_sales_data(self, sales):
        """Envoie les données de vente à Maybe"""
        transactions = []
        
        for sale in sales:
            transactions.append({
                'date': sale['date'].strftime('%Y-%m-%d'),
                'amount': str(-abs(float(sale['amount']))),  # Négatif pour les dépenses
                'description': f"Vente {sale['product_name']}",
                'category': 'Revenus e-commerce',
                'tags': ['vente', 'e-commerce', sale['category']],
                'notes': f"Commande #{sale['order_id']}"
            })
        
        payload = {
            'source_version': '1.2.0',
            'account_name': 'Compte E-commerce',
            'transactions': transactions
        }
        
        response = requests.post(
            self.webhook_url,
            headers={
                'Content-Type': 'application/json',
                'X-Integration-Token': self.token
            },
            json=payload
        )
        
        return response.json()

# Utilisation
integration = MaybeIntegration(
    webhook_url='https://maybe.com/webhooks/integration_import',
    token='YOUR_INTEGRATION_TOKEN'
)

# Données de vente exemple
sales_data = [
    {
        'date': datetime.now(),
        'amount': 89.99,
        'product_name': 'T-shirt premium',
        'category': 'vetements',
        'order_id': 'ORD-001'
    }
]

result = integration.send_sales_data(sales_data)
print(f"Import status: {result}")
```

### PHP - Intégration avec système de paie

```php
<?php
class MaybePayrollIntegration {
    private $webhookUrl;
    private $token;
    
    public function __construct($webhookUrl, $token) {
        $this->webhookUrl = $webhookUrl;
        $this->token = $token;
    }
    
    public function sendPayrollData($employees) {
        $transactions = [];
        
        foreach ($employees as $employee) {
            $transactions[] = [
                'date' => date('Y-m-d'),
                'amount' => (string)(-abs($employee['salary'])), // Négatif pour les dépenses
                'description' => "Salaire " . $employee['name'],
                'category' => 'Salaires',
                'account_name' => 'Compte Salaires',
                'tags' => ['salaire', 'paie', $employee['department']],
                'notes' => "Paie du mois " . date('m/Y')
            ];
        }
        
        $payload = [
            'source_version' => '1.0.0',
            'transactions' => $transactions
        ];
        
        $options = [
            'http' => [
                'header' => [
                    'Content-Type: application/json',
                    'X-Integration-Token: ' . $this->token
                ],
                'method' => 'POST',
                'content' => json_encode($payload)
            ]
        ];
        
        $context = stream_context_create($options);
        $result = file_get_contents($this->webhookUrl, false, $context);
        
        return json_decode($result, true);
    }
}

// Utilisation
$integration = new MaybePayrollIntegration(
    'https://maybe.com/webhooks/integration_import',
    'YOUR_INTEGRATION_TOKEN'
);

$employees = [
    ['name' => 'Jean Dupont', 'salary' => 3500, 'department' => 'IT'],
    ['name' => 'Marie Martin', 'salary' => 4200, 'department' => 'Marketing']
];

$result = $integration->sendPayrollData($employees);
echo "Import result: " . json_encode($result);
?>
```

## Cas d'usage par type d'application

### Banking Apps
- Synchronisation quotidienne des transactions
- Import automatique des relevés
- Catégorisation automatique basée sur les marchands

### Accounting Software  
- Export périodique des écritures comptables
- Synchronisation des factures clients/fournisseurs
- Import des rapprochements bancaires

### E-commerce Platforms
- Import des ventes et revenus
- Synchronisation des frais de transaction
- Suivi des remboursements et retours

### Payment Processors
- Import des transactions Stripe/PayPal
- Synchronisation des frais de traitement
- Gestion des chargebacks

### Expense Trackers
- Import des notes de frais
- Synchronisation des reçus numérisés
- Catégorisation automatique des dépenses

## Monitoring et débogage

### Vérifier le statut d'un import

```ruby
# Dans la console Rails
import = Import.find('uuid-de-l-import')
puts "Status: #{import.status}"
puts "Errors: #{import.error}" if import.error
puts "Transactions: #{import.rows.count}"
```

### Logs d'intégration

```ruby
# Vérifier les logs d'une intégration
integration = IntegrationConfig.find_by(name: "Mon App")
puts "Last used: #{integration.updated_at}"

# Tester la connexion webhook
result = integration.test_webhook
puts "Webhook test: #{result}"
```

## Sécurité

### Rotation des tokens

```ruby
# Générer un nouveau token
integration.generate_api_token!
puts "Nouveau token: #{integration.api_token}"

# Désactiver une intégration
integration.update!(status: 'inactive')
```

### Validation des données

```ruby
# Valider les données avant import
import = ApiImport.new(family: family)
result = import.validate_json_structure(transactions_data)

if result[:valid]
  # Procéder à l'import
else
  puts "Erreurs: #{result[:errors]}"
end
```