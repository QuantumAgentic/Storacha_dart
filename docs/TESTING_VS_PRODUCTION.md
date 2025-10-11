# Testing vs Production Usage

## 🎯 La Différence Clé

**Les tests NE publient RIEN en ligne !** Tout est simulé localement avec des mocks.

---

## 🧪 Mode Test (Mock)

### Dans les tests :

```dart
// MOCK TRANSPORT - Aucune requête réseau réelle !
final transport = MockStorachaTransport();
final client = StorachaClient(config, transport: transport);
```

### Ce qui se passe :

```
┌─────────────────────────────────────────┐
│          StorachaClient                 │
│  (createSpace, uploadFile)              │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│      MockStorachaTransport             │
│   ❌ PAS de requêtes HTTP              │
│   ✅ Retourne des réponses simulées    │
│   ✅ Tout reste en mémoire             │
└─────────────────────────────────────────┘
```

### Code du Mock :

```dart
class MockStorachaTransport implements StorachaTransport {
  @override
  Future<BlobAllocation> invokeBlobAdd(...) async {
    // ❌ PAS de requête HTTP !
    // ✅ Retourne juste un objet simulé
    return const BlobAllocation(
      allocated: true,
      url: 'https://test.upload.url/blob',  // URL fictive !
    );
  }

  @override
  Future<void> uploadBlob(...) async {
    // ❌ PAS d'upload réel !
    // ✅ Simule juste le succès
    print('Mock: Upload simulé');
  }
}
```

---

## 🌐 Mode Production (Réel)

### En production :

```dart
// PAS de transport spécifié = transport réel par défaut
final client = StorachaClient(config);  // ← Utilise le vrai réseau !
```

### Ce qui se passe :

```
┌─────────────────────────────────────────┐
│          StorachaClient                 │
│  (createSpace, uploadFile)              │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│      StorachaTransport (RÉEL)          │
│   ✅ Vraies requêtes HTTP              │
│   ✅ POST vers up.storacha.network     │
│   ✅ Upload de vrais fichiers          │
└───────────────┬─────────────────────────┘
                │
                ▼
        🌐 Internet
                │
                ▼
┌─────────────────────────────────────────┐
│      Storacha Network                   │
│   (up.storacha.network)                │
│   ✅ Stockage persistant               │
│   ✅ Réplication IPFS                  │
│   ✅ Archivage Filecoin                │
└─────────────────────────────────────────┘
```

---

## 📋 Comparaison

| Aspect | Mode Test (Mock) | Mode Production |
|--------|------------------|-----------------|
| **Requêtes HTTP** | ❌ Aucune | ✅ Réelles |
| **Upload fichiers** | ❌ Simulé | ✅ Réel vers Storacha |
| **Spaces créés** | 🔵 En mémoire locale | 🟢 Sur réseau Storacha |
| **CIDs générés** | ✅ Valides (calculés) | ✅ Valides (calculés) |
| **Données persistantes** | ❌ Perdues à la fin du test | ✅ Stockées sur IPFS/Filecoin |
| **Coût** | 🆓 Gratuit | 💰 Consomme quota Storacha |
| **Vitesse** | ⚡ Instantané | 🐢 Dépend du réseau |
| **Internet requis** | ❌ Non | ✅ Oui |

---

## 🔍 Détails Techniques

### 1️⃣ **createSpace() dans les tests**

```dart
// Mode Test
final space = await client.createSpace('Test Space');
```

**Ce qui se passe** :
- ✅ Génère un nouveau Ed25519 key pair
- ✅ Crée un DID:key local
- ✅ Stocke le space en mémoire du client
- ❌ **AUCUNE** requête réseau
- ❌ **RIEN** n'est publié sur Storacha

**Résultat** : Le space n'existe que dans la RAM, pendant le test.

---

### 2️⃣ **uploadFile() dans les tests**

```dart
// Mode Test
final cid = await client.uploadFile(file);
```

**Ce qui se passe** :
1. ✅ **Encode le fichier en UnixFS** (réel, correct)
2. ✅ **Génère un CAR file** (réel, correct)
3. ✅ **Calcule le CID** (réel, correct)
4. ❌ **Mock simule l'allocation** (pas de vraie requête)
5. ❌ **Mock simule l'upload** (pas de vrai PUT HTTP)
6. ❌ **Mock simule l'enregistrement** (pas de vraie requête)
7. ✅ **Retourne le CID** (valide mais données pas uploadées)

**Résultat** : Le CID est valide, mais le fichier n'est PAS sur IPFS.

---

### 3️⃣ **Comment identifier le mode ?**

```dart
// MOCK (Tests) - injection explicite
final mockTransport = MockStorachaTransport();
final client = StorachaClient(config, transport: mockTransport);
// ❌ Pas de réseau

// PRODUCTION - pas de transport spécifié
final client = StorachaClient(config);
// ✅ Utilise le vrai StorachaTransport par défaut
```

Regardons le code du client :

```dart
class StorachaClient {
  StorachaClient(ClientConfig config, {StorachaTransport? transport})
      : _config = config,
        _transport = transport ?? StorachaTransport();
        //                       ^^^^^^^^^^^^^^^^^^
        //                       Vrai transport par défaut !
```

---

## 🎓 Pourquoi utiliser des Mocks ?

### Avantages des tests avec mocks :

1. **⚡ Vitesse** : Tests instantanés (pas d'attente réseau)
2. **🔒 Fiabilité** : Pas de dépendance au réseau/service externe
3. **💰 Gratuit** : Pas de quota Storacha consommé
4. **🧪 Déterminisme** : Résultats toujours identiques
5. **🔧 CI/CD** : Tests exécutables sans credentials
6. **🎯 Isolation** : Teste uniquement la logique du client

### Inconvénients :

- ❌ Ne valide pas l'intégration réseau réelle
- ❌ Ne teste pas les erreurs réseau réelles
- ❌ Ne vérifie pas que Storacha accepte les requêtes

**C'est pour ça qu'on a aussi les tests d'intégration !**

---

## 🔬 Tests E2E (End-to-End) Réels

Pour tester avec le **vrai réseau Storacha**, il faudrait :

```dart
// test/e2e/real_upload_test.dart (NON inclus par défaut)

@Tags(['e2e', 'network-required'])
void main() {
  test('real upload to staging', () async {
    // ⚠️ Credentials réels requis !
    final signer = await Ed25519Signer.fromPrivateKey(
      Uint8List.fromList(base64Decode(Platform.environment['STORACHA_KEY']!)),
    );
    
    // ✅ Pas de mock = vrai réseau !
    final config = ClientConfig(
      principal: signer,
      endpoints: StorachaEndpoints.staging,  // ou .production
    );
    final client = StorachaClient(config);
    
    // ✅ Space créé sur le VRAI réseau Storacha
    final space = await client.createSpace('E2E Test Space');
    
    final file = MemoryFile(
      name: 'test.txt',
      bytes: Uint8List.fromList(utf8.encode('E2E test')),
    );
    
    // ✅ Vraie requête HTTP vers up.storacha.network
    final cid = await client.uploadFile(file);
    
    // ✅ Vérification : fichier accessible via IPFS gateway
    final response = await http.get(Uri.parse('https://w3s.link/ipfs/$cid'));
    expect(response.statusCode, equals(200));
    expect(response.body, equals('E2E test'));
    
    client.close();
  });
}
```

**⚠️ Ces tests E2E ne sont PAS inclus par défaut car ils** :
- Nécessitent des credentials Storacha
- Coûtent du quota
- Dépendent du réseau
- Sont plus lents

---

## 🛡️ Sécurité

### Dans les tests :

```dart
// ✅ Signer généré aléatoirement
final signer = await Ed25519Signer.generate();

// ✅ Pas de clé privée réelle exposée
// ✅ Pas de credentials requis
// ✅ Safe pour CI/CD publique
```

### En production :

```dart
// ⚠️ Utiliser des clés privées sécurisées !
final privateKeyBytes = await secureStorage.read(key: 'storacha_key');
final signer = await Ed25519Signer.fromPrivateKey(privateKeyBytes);

// ⚠️ Ne JAMAIS commit les clés privées
// ⚠️ Utiliser des variables d'environnement
// ⚠️ Chiffrer les clés au repos
```

---

## 📊 Résumé

```
┌────────────────────────────────────────────────────────┐
│                    TESTS                               │
│                                                        │
│  Mode: MOCK (Simulé)                                  │
│  Réseau: ❌ Aucune requête                            │
│  Spaces: 🔵 En mémoire locale                         │
│  Upload: ❌ Simulé                                     │
│  CIDs: ✅ Calculés (mais pas publiés)                 │
│  Coût: 🆓 Gratuit                                      │
│  CI/CD: ✅ Compatible                                  │
│                                                        │
│  But: Tester la LOGIQUE du client                     │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│                  PRODUCTION                            │
│                                                        │
│  Mode: RÉEL (HTTP)                                    │
│  Réseau: ✅ up.storacha.network                       │
│  Spaces: 🟢 Sur réseau Storacha                       │
│  Upload: ✅ Vers IPFS + Filecoin                      │
│  CIDs: ✅ Publiés et accessibles                      │
│  Coût: 💰 Consomme quota                              │
│  Credentials: ⚠️ Requis                               │
│                                                        │
│  But: Stocker RÉELLEMENT des fichiers                │
└────────────────────────────────────────────────────────┘
```

---

## ✅ Conclusion

**Les 528 tests du package utilisent TOUS des mocks.**

- ✅ Aucune requête réseau réelle
- ✅ Aucun space créé sur Storacha
- ✅ Aucun fichier uploadé vers IPFS
- ✅ Tout reste en mémoire locale
- ✅ Tests rapides, fiables, gratuits

**Pour utiliser le vrai réseau Storacha** :
- Créer un client SANS spécifier de transport mock
- Fournir des credentials valides
- Avoir un compte Storacha actif
- Accepter de consommer du quota

**Le package est prêt pour les deux modes** ! 🎉

