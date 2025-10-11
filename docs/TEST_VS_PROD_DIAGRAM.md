# Test vs Production - Diagrammes Visuels

## 🧪 Mode Test (Mock) - RIEN n'est publié

```
┌──────────────────────────────────────────────────────────────┐
│                   TEST UNITAIRE                              │
└──────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  test/unit/client/storacha_client_test.dart                 │
│                                                              │
│  setUp(() async {                                            │
│    final signer = await Ed25519Signer.generate();           │
│    final config = ClientConfig(principal: signer);          │
│    client = StorachaClient(                                 │
│      config,                                                 │
│      transport: MockStorachaTransport()  ← 🎭 MOCK !       │
│    );                                                        │
│  });                                                         │
│                                                              │
│  test('upload file', () async {                             │
│    await client.createSpace('Test');  ← 🔵 Mémoire locale  │
│    final cid = await client.uploadFile(file);               │
│    expect(cid, isNotNull);                                  │
│  });                                                         │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              StorachaClient (votre code)                     │
│                                                              │
│  createSpace('Test')  ───►  ✅ Crée DID local               │
│                             ✅ Stocke en _spaces[]           │
│                             ❌ PAS de requête réseau         │
│                                                              │
│  uploadFile(file)     ───►  ✅ Encode UnixFS                │
│                             ✅ Génère CAR                    │
│                             ✅ Calcule CID                   │
│                             ❌ PAS d'upload réseau           │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│          MockStorachaTransport (simulateur)                  │
│                                                              │
│  invokeBlobAdd() {                                          │
│    return BlobAllocation(url: 'https://fake.url');          │
│  } ───► ✅ Retourne immédiatement                           │
│         ❌ Aucun HTTP                                        │
│                                                              │
│  uploadBlob() {                                             │
│    print('Mock: upload simulé');                            │
│  } ───► ✅ Simule le succès                                 │
│         ❌ Aucun PUT HTTP                                    │
│                                                              │
│  invokeUploadAdd() {                                        │
│    return UploadResult(root: cid);                          │
│  } ───► ✅ Retourne le CID                                  │
│         ❌ Aucun HTTP                                        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
                    ❌ FIN DU TEST
                    
Résultat: 
  ✅ Test passe rapidement
  ✅ Aucun coût
  ❌ Aucune donnée sur Internet
  ❌ Space n'existe que pendant le test
  ❌ Fichier pas sur IPFS
```

---

## 🌐 Mode Production (Réel) - Tout est publié

```
┌──────────────────────────────────────────────────────────────┐
│                 UTILISATION RÉELLE                           │
└──────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  example/upload_example.dart (ou votre app)                  │
│                                                              │
│  final signer = await Ed25519Signer.generate();             │
│  final config = ClientConfig(                                │
│    principal: signer,                                        │
│    endpoints: StorachaEndpoints.production,                  │
│  );                                                          │
│  final client = StorachaClient(config);                     │
│                    ^^^^^^^^^^^^^^^^^^                        │
│                    PAS de mock = RÉEL !                      │
│                                                              │
│  await client.createSpace('My Files');  ← 🟢 Vrai space    │
│  final cid = await client.uploadFile(file);                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              StorachaClient (votre code)                     │
│                                                              │
│  createSpace('My Files') ──► ✅ Crée DID local              │
│                              ✅ Stocke en _spaces[]          │
│                              ⚠️  Pas encore sur réseau       │
│                                                              │
│  uploadFile(file)        ──► ✅ Encode UnixFS               │
│                              ✅ Génère CAR                   │
│                              ✅ Calcule CID                  │
│                              ⬇️  Envoie au transport         │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         StorachaTransport (client HTTP réel)                 │
│                                                              │
│  invokeBlobAdd() {                                          │
│    POST https://up.storacha.network                          │
│    Content-Type: application/vnd.ipld.car                    │
│    Body: UCAN JWT (signé avec Ed25519)                       │
│  } ───► ✅ Vraie requête HTTP                                │
│         ⬇️  Attend réponse du serveur                        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (Internet)
┌─────────────────────────────────────────────────────────────┐
│              🌐 Storacha Network                            │
│          (up.storacha.network)                              │
│                                                              │
│  ✅ Reçoit la requête                                        │
│  ✅ Vérifie la signature UCAN                                │
│  ✅ Alloue espace de stockage                                │
│  ✅ Retourne URL d'upload                                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (Réponse)
┌─────────────────────────────────────────────────────────────┐
│         StorachaTransport (client HTTP réel)                 │
│                                                              │
│  uploadBlob(url, carBytes) {                                │
│    PUT https://carpark-prod-0.r2.cloudflarestorage.com/...  │
│    Content-Type: application/vnd.ipld.car                    │
│    Body: [... CAR file bytes ...]                           │
│  } ───► ✅ Upload du fichier encodé                         │
│         ⬇️  Transfert des données                            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (Internet)
┌─────────────────────────────────────────────────────────────┐
│              ☁️  Cloudflare R2 Storage                      │
│                                                              │
│  ✅ Reçoit le CAR file                                       │
│  ✅ Stocke les blocs IPFS                                    │
│  ✅ Retourne 200 OK                                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (Succès)
┌─────────────────────────────────────────────────────────────┐
│         StorachaTransport (client HTTP réel)                 │
│                                                              │
│  invokeUploadAdd(root, shards) {                            │
│    POST https://up.storacha.network                          │
│    Content-Type: application/vnd.ipld.car                    │
│    Body: UCAN JWT (upload/add capability)                    │
│  } ───► ✅ Enregistre l'upload                               │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (Internet)
┌─────────────────────────────────────────────────────────────┐
│              🌐 Storacha Network                            │
│                                                              │
│  ✅ Enregistre le mapping root CID → shards                  │
│  ✅ Lance la réplication IPFS                                │
│  ✅ Queue pour archivage Filecoin                            │
│  ✅ Retourne UploadResult                                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (Réponse finale)
┌─────────────────────────────────────────────────────────────┐
│              StorachaClient (votre code)                     │
│                                                              │
│  ✅ Reçoit le CID final                                      │
│  ✅ Retourne à l'utilisateur                                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
                  ✅ UPLOAD COMPLET

Résultat:
  ✅ Fichier stocké sur IPFS
  ✅ Accessible via https://w3s.link/ipfs/<CID>
  ✅ Répliqué sur plusieurs nodes
  ✅ Sera archivé sur Filecoin
  ✅ Persistant et permanent
  💰 Quota Storacha consommé
```

---

## 🔍 Comparaison Côte à Côte

```
╔══════════════════════════════════════════════════════════╗
║              TESTS (Mock)          vs      PRODUCTION    ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  StorachaClient(config,                                  ║
║    transport: Mock   🎭            transport: Réel  🌐  ║
║  )                                                       ║
║                                                          ║
║  createSpace()                                           ║
║    │                                                     ║
║    ├──► 🔵 Mémoire locale          🟢 Registré Storacha║
║    ├──► ❌ Pas de réseau           ✅ UCAN signé & envoyé║
║    └──► ⚡ Instantané               🐢 ~500ms            ║
║                                                          ║
║  uploadFile()                                            ║
║    │                                                     ║
║    ├──► ✅ Encode (réel)           ✅ Encode (réel)     ║
║    ├──► ✅ CID calculé             ✅ CID calculé       ║
║    ├──► ❌ Upload simulé           ✅ Upload vers R2     ║
║    ├──► ❌ Pas sur IPFS            ✅ Publié sur IPFS   ║
║    └──► ⚡ ~5ms                     🐢 ~2-5s             ║
║                                                          ║
║  Données persistantes:                                   ║
║    ❌ Perdues (RAM)                ✅ Stockées (cloud)   ║
║                                                          ║
║  Coût:                                                   ║
║    🆓 Gratuit                       💰 Quota consommé    ║
║                                                          ║
║  Internet:                                               ║
║    ❌ Pas besoin                    ✅ Requis            ║
║                                                          ║
║  Credentials:                                            ║
║    ❌ Pas besoin                    ⚠️  Requis           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

---

## 🎯 Points Clés

### 1. **Le code du client est IDENTIQUE**

```dart
// Même code dans les deux cas !
await client.createSpace('My Space');
final cid = await client.uploadFile(file);
```

### 2. **Seul le transport change**

```dart
// TEST
StorachaClient(config, transport: MockStorachaTransport())

// PROD  
StorachaClient(config)  // Utilise le vrai transport
```

### 3. **L'encoding est toujours réel**

- ✅ UnixFS encoding
- ✅ CAR file generation
- ✅ CID calculation
- ✅ SHA-256 hashing

**Ces étapes sont IDENTIQUES en test et prod !**

### 4. **Seul le réseau diffère**

- **Test** : Mock retourne des réponses simulées
- **Prod** : Vraies requêtes HTTP vers Storacha

---

## 📊 Statistiques

### Tests (528 tests) :

```
Durée totale: ~3 secondes
Requêtes HTTP: 0
Données uploadées: 0 octets
Coût: 0 €
```

### Production (1 upload de 1 MB) :

```
Durée: ~2-5 secondes
Requêtes HTTP: 3 (blob/add, PUT, upload/add)
Données uploadées: ~1 MB
Coût: ~0.001 € (selon pricing Storacha)
```

---

## ✅ Conclusion

**Question** : "Où sont créés les spaces dans les tests ?"

**Réponse** : 
- 🔵 **En mémoire locale** (RAM de la machine de test)
- ❌ **PAS sur le réseau Storacha**
- ❌ **PAS sur Internet**
- ❌ **PAS persistants**

**Les tests sont 100% locaux et offline !** 🎉

