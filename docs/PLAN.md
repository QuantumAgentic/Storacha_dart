# Plan Global - Package Storacha Dart

## 🎯 Objectif
Créer un package Dart de qualité professionnelle compatible Flutter (iOS, Android, Web, Desktop) qui implémente l'API cliente Storacha Network, en se basant sur la version JavaScript officielle [@storacha/client](https://github.com/storacha/storacha). Le package doit être **ultra-solide, performant et scalable**.

## 📚 Référence JavaScript

### Analyse du Client JS Officiel
Le client JavaScript [@storacha/client](https://www.npmjs.com/package/@storacha/client) repose sur:
- **@ucanto/client** - Framework UCAN pour autorisation décentralisée
- **@ucanto/transport** - Transport HTTP avec encodage CAR
- **multiformats** - CID, multibase, multicodec, multihash
- **@ipld/car** - Encodage/décodage Content Addressable aRchive
- **@ipld/dag-cbor** - CBOR encoding pour IPLD
- **uint8arrays** - Manipulation efficace de données binaires

### Fonctionnalités Clés à Implémenter
1. **Authentification** - Login via email avec vérification
2. **Gestion d'espaces** - Création, provisionnement, sélection
3. **Upload** - Fichiers uniques et répertoires avec progress tracking
4. **Cryptographie** - DID (did:key), UCAN tokens, Ed25519
5. **Stockage local** - Persistance sécurisée des clés et métadonnées
6. **Passerelles IPFS** - Configuration et délégations
7. **🔑 Signers Injectables** - Architecture permettant l'injection de signers externes (clés IPNS, HSM, secure enclave)

## 📦 Dépendances Dart - Analyse Approfondie

### 🔥 Catégorie: Networking & HTTP

#### 1. **dio** (^5.4.0) - Client HTTP Principal
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Popularité**: 96% (>150k likes)
- ✅ **Avantages**:
  - Intercepteurs pour retry, auth, logging
  - Support natif du multipart/form-data
  - Progress callbacks pour upload/download
  - Annulation de requêtes (CancelToken)
  - Timeout granulaire par requête
  - Gestion automatique des erreurs HTTP
- 🎯 **Cas d'usage**: Toutes les requêtes API Storacha
- 📖 **Documentation**: Excellente avec exemples

#### 2. **http** (^1.2.0) - Fallback & Tests
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Léger, simple, bien testé
- 🎯 **Cas d'usage**: Tests unitaires avec mocks

### 🔐 Catégorie: Cryptographie

#### 3. **pointycastle** (^3.7.4) - Cryptographie Avancée
- ⭐ **Pub.dev Score**: 130/140
- 📊 **Popularité**: Très utilisé (>25k likes)
- ✅ **Avantages**:
  - Ed25519 (signature DID)
  - RSA, AES, SHA-256/512
  - Générateurs aléatoires sécurisés
  - Pure Dart (multi-plateforme)
- 🎯 **Cas d'usage**: Génération clés DID, signatures UCAN
- ⚠️ **Note**: Performance inférieure à natives mais acceptable

#### 4. **crypto** (^3.0.3) - Hashing Standard
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: SHA-256, HMAC, MD5
- 🎯 **Cas d'usage**: Hashing CID, checksums

#### 5. **cryptography** (^2.7.0) - Alternative Moderne
- ⭐ **Pub.dev Score**: 120/140
- ✅ **Avantages**: 
  - API moderne et simple
  - Support cryptographie quantique-résistante
  - Meilleure performance que pointycastle
- 🎯 **Cas d'usage**: Alternative pour Ed25519
- ⚠️ **Considération**: Moins mature que pointycastle

**DÉCISION**: Utiliser **pointycastle** + **crypto** (stabilité éprouvée)

### 💾 Catégorie: Stockage Sécurisé

#### 6. **flutter_secure_storage** (^9.0.0) - Stockage Clés
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Popularité**: 95% (>80k likes)
- ✅ **Avantages**:
  - Keychain (iOS), KeyStore (Android)
  - Chiffrement AES-256
  - Support Web (localStorage chiffré)
  - API simple et cohérente
- 🎯 **Cas d'usage**: Clés privées DID, tokens UCAN
- 📱 **Plateformes**: iOS 12+, Android 21+, Web, Desktop

#### 7. **shared_preferences** (^2.2.2) - Métadonnées
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Flutter**
- ✅ **Avantages**: Léger, simple, multi-plateforme
- 🎯 **Cas d'usage**: Cache métadonnées (liste espaces, config)

### 📝 Catégorie: Sérialisation & Encodage

#### 8. **json_annotation** + **json_serializable** (^4.8.1 / ^6.7.1)
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Packages officiels Dart**
- ✅ **Avantages**:
  - Génération code à la compilation (performance)
  - Type-safe
  - Null-safety complet
- 🎯 **Cas d'usage**: Tous les modèles (Space, Account, CID...)

#### 9. **convert** (^3.1.1) - Encodages Standards
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Base64, hex, UTF-8, Latin1
- 🎯 **Cas d'usage**: Encodage bytes, base64url

#### 10. **typed_data** (^1.3.2) - Buffers Binaires
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Uint8List, ByteBuffer efficaces
- 🎯 **Cas d'usage**: Manipulation données binaires CAR

### 🔗 Catégorie: IPFS & Multiformats

#### 11. **multibase** - À Implémenter
- ❌ **Statut**: Pas de package Dart mature
- 🔨 **Solution**: Implémentation custom
  - Base58btc (Bitcoin)
  - Base32 (CIDv1)
  - Base64url
- 📏 **Complexité**: Moyenne (500 LOC)

#### 12. **multihash** - À Implémenter
- ❌ **Statut**: Pas de package Dart mature
- 🔨 **Solution**: Implémentation custom
  - SHA-256 (0x12)
  - SHA-512 (0x13)
  - Blake2b (0xb220)
- 📏 **Complexité**: Faible (200 LOC avec crypto)

#### 13. **cid** (Content Identifier) - À Implémenter
- ❌ **Statut**: Pas de package Dart mature
- 🔨 **Solution**: Implémentation custom
  - CIDv0 (base58btc, protobuf only)
  - CIDv1 (multibase + multicodec + multihash)
- 📏 **Complexité**: Moyenne (400 LOC)

#### 14. **varint** - À Implémenter
- ❌ **Statut**: Pas de package Dart mature
- 🔨 **Solution**: Implémentation custom
- 📏 **Complexité**: Faible (100 LOC)

### 🏗️ Catégorie: Utilitaires

#### 15. **uuid** (^4.3.3) - Génération UUID
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Popularité**: Excellent (>45k likes)
- ✅ **Avantages**: UUID v1/v4/v5, performant
- 🎯 **Cas d'usage**: IDs de requêtes, tracking

#### 16. **path** (^1.9.0) - Chemins de Fichiers
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Manipulation cross-platform
- 🎯 **Cas d'usage**: Construction chemins dans répertoires

#### 17. **mime** (^1.0.5) - Détection MIME
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Base de données MIME complète
- 🎯 **Cas d'usage**: Détection auto type fichiers

#### 18. **logging** (^1.2.0) - Logging Structuré
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Niveaux, hiérarchique, handlers
- 🎯 **Cas d'usage**: Debug, tracing, monitoring

#### 19. **cross_file** (^0.3.4+1) - Fichiers Cross-Platform
- ⭐ **Pub.dev Score**: 130/140
- 📊 **Package officiel Flutter**
- ✅ **Avantages**: Abstraction fichiers Web/Mobile
- 🎯 **Cas d'usage**: Upload fichiers depuis toutes plateformes

### 🧪 Catégorie: Testing & Qualité

#### 20. **test** (^1.25.0) - Framework de Tests
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Complet, rapide, bien documenté

#### 21. **mockito** (^5.4.4) - Mocking
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Très populaire** (>70k likes)
- ✅ **Avantages**: Génération mocks à la compilation
- 🎯 **Alternative**: mocktail (sans code gen)

#### 22. **fake_async** (^1.3.1) - Tests Asynchrones
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Dart**
- ✅ **Avantages**: Contrôle du temps dans tests

#### 23. **flutter_test** - Tests Flutter
- ⭐ **Package officiel Flutter SDK**
- ✅ **Avantages**: Widget testing, golden tests

#### 24. **integration_test** - Tests E2E
- ⭐ **Package officiel Flutter SDK**
- ✅ **Avantages**: Tests sur vrais devices

### 🔍 Catégorie: Analyse Statique

#### 25. **flutter_lints** (^3.0.1) - Règles Lint
- ⭐ **Pub.dev Score**: 140/140
- 📊 **Package officiel Flutter**
- ✅ **Avantages**: Règles recommandées par Flutter team

#### 26. **dart_code_metrics** - Optionnel
- ⭐ **Pub.dev Score**: 110/140
- ✅ **Avantages**: Métriques complexité, code smells
- ⚠️ **Note**: Payant pour features avancées

## 🏗️ Architecture Détaillée

### Structure des Dossiers
```
storacha_dart/
├── docs/
│   ├── PLAN.md                          # Ce fichier
│   ├── TODO.md                          # Suivi des tâches
│   ├── ARCHITECTURE.md                  # Diagrammes d'architecture
│   ├── API_REFERENCE.md                 # Référence API complète
│   └── MIGRATION_FROM_JS.md             # Guide migration depuis JS
├── lib/
│   ├── storacha_dart.dart               # Export principal
│   │
│   ├── src/
│   │   ├── client/
│   │   │   ├── storacha_client.dart     # Client principal
│   │   │   ├── client_config.dart       # Configuration
│   │   │   └── client_options.dart      # Options de création
│   │   │
│   │   ├── models/
│   │   │   ├── space.dart               # Modèle Space
│   │   │   ├── space.g.dart             # Généré
│   │   │   ├── account.dart             # Modèle Account
│   │   │   ├── account.g.dart           # Généré
│   │   │   ├── plan.dart                # Payment plan
│   │   │   ├── upload_result.dart       # Résultat upload
│   │   │   ├── storacha_file.dart       # Fichier à uploader
│   │   │   └── gateway_config.dart      # Config gateway
│   │   │
│   │   ├── services/
│   │   │   ├── auth/
│   │   │   │   ├── auth_service.dart        # Interface
│   │   │   │   ├── auth_service_impl.dart   # Implémentation
│   │   │   │   └── email_verifier.dart      # Vérification email
│   │   │   │
│   │   │   ├── space/
│   │   │   │   ├── space_service.dart       # Interface
│   │   │   │   ├── space_service_impl.dart  # Implémentation
│   │   │   │   ├── space_manager.dart       # Gestion espaces
│   │   │   │   └── space_delegator.dart     # Délégations
│   │   │   │
│   │   │   ├── upload/
│   │   │   │   ├── upload_service.dart      # Interface
│   │   │   │   ├── upload_service_impl.dart # Implémentation
│   │   │   │   ├── file_chunker.dart        # Découpage fichiers
│   │   │   │   ├── upload_queue.dart        # Queue uploads
│   │   │   │   └── progress_tracker.dart    # Suivi progression
│   │   │   │
│   │   │   └── gateway/
│   │   │       ├── gateway_service.dart     # Interface
│   │   │       └── gateway_service_impl.dart # Implémentation
│   │   │
│   │   ├── storage/
│   │   │   ├── storage_interface.dart       # Interface abstraite
│   │   │   ├── secure_storage_impl.dart     # flutter_secure_storage
│   │   │   ├── preferences_storage.dart     # shared_preferences
│   │   │   ├── memory_storage.dart          # En mémoire (tests)
│   │   │   └── storage_keys.dart            # Clés de stockage
│   │   │
│   │   ├── crypto/
│   │   │   ├── signer.dart                  # Interface Signer (injectable)
│   │   │   ├── ed25519_signer.dart          # Implémentation par défaut
│   │   │   │
│   │   │   ├── did/
│   │   │   │   ├── did.dart                 # DID abstrait
│   │   │   │   ├── did_key.dart             # did:key implementation
│   │   │   │   ├── ed25519_key_pair.dart    # Paire clés Ed25519
│   │   │   │   └── did_resolver.dart        # Résolution DID
│   │   │   │
│   │   │   ├── ucan/
│   │   │   │   ├── ucan.dart                # UCAN token
│   │   │   │   ├── ucan_builder.dart        # Construction UCAN
│   │   │   │   ├── ucan_validator.dart      # Validation UCAN
│   │   │   │   ├── capability.dart          # Capacités
│   │   │   │   ├── delegation.dart          # Délégations
│   │   │   │   └── proof.dart               # Preuves
│   │   │   │
│   │   │   └── utils/
│   │   │       ├── key_generator.dart       # Génération clés
│   │   │       ├── signer.dart              # Signature
│   │   │       └── verifier.dart            # Vérification
│   │   │
│   │   ├── ipfs/
│   │   │   ├── cid/
│   │   │   │   ├── cid.dart                 # Content Identifier
│   │   │   │   ├── cid_v0.dart              # CID version 0
│   │   │   │   ├── cid_v1.dart              # CID version 1
│   │   │   │   └── cid_parser.dart          # Parser CID
│   │   │   │
│   │   │   ├── multiformats/
│   │   │   │   ├── multibase.dart           # Multibase encoding
│   │   │   │   ├── multicodec.dart          # Multicodec
│   │   │   │   ├── multihash.dart           # Multihash
│   │   │   │   └── varint.dart              # Variable integers
│   │   │   │
│   │   │   └── car/
│   │   │       ├── car_encoder.dart         # Encodage CAR
│   │   │       ├── car_decoder.dart         # Décodage CAR
│   │   │       ├── car_header.dart          # Header CAR
│   │   │       └── car_block.dart           # Block CAR
│   │   │
│   │   ├── transport/
│   │   │   ├── http_transport.dart          # Transport HTTP
│   │   │   ├── request_interceptor.dart     # Intercepteur requêtes
│   │   │   ├── response_interceptor.dart    # Intercepteur réponses
│   │   │   ├── retry_interceptor.dart       # Retry automatique
│   │   │   └── auth_interceptor.dart        # Injection auth
│   │   │
│   │   ├── exceptions/
│   │   │   ├── storacha_exception.dart      # Exception de base
│   │   │   ├── auth_exception.dart          # Erreurs auth
│   │   │   ├── network_exception.dart       # Erreurs réseau
│   │   │   ├── upload_exception.dart        # Erreurs upload
│   │   │   ├── space_exception.dart         # Erreurs space
│   │   │   └── crypto_exception.dart        # Erreurs crypto
│   │   │
│   │   └── utils/
│   │       ├── logger.dart                  # Logger configuré
│   │       ├── validators.dart              # Validateurs
│   │       ├── extensions.dart              # Extensions Dart
│   │       └── constants.dart               # Constantes
│   │
│   └── storacha_dart_platform_interface.dart # Interface plateforme
│
├── test/
│   ├── unit/
│   │   ├── client/
│   │   │   └── storacha_client_test.dart
│   │   ├── models/
│   │   │   ├── space_test.dart
│   │   │   ├── account_test.dart
│   │   │   └── upload_result_test.dart
│   │   ├── services/
│   │   │   ├── auth_service_test.dart
│   │   │   ├── space_service_test.dart
│   │   │   ├── upload_service_test.dart
│   │   │   └── gateway_service_test.dart
│   │   ├── crypto/
│   │   │   ├── did_key_test.dart
│   │   │   ├── ucan_test.dart
│   │   │   └── ed25519_test.dart
│   │   ├── ipfs/
│   │   │   ├── cid_test.dart
│   │   │   ├── multibase_test.dart
│   │   │   ├── multihash_test.dart
│   │   │   └── car_encoder_test.dart
│   │   └── storage/
│   │       ├── secure_storage_test.dart
│   │       └── preferences_storage_test.dart
│   │
│   ├── integration/
│   │   ├── auth_flow_test.dart
│   │   ├── space_creation_test.dart
│   │   ├── file_upload_test.dart
│   │   ├── directory_upload_test.dart
│   │   └── full_workflow_test.dart
│   │
│   ├── performance/
│   │   ├── large_file_upload_test.dart
│   │   ├── concurrent_uploads_test.dart
│   │   └── memory_usage_test.dart
│   │
│   ├── mocks/
│   │   ├── mock_http_client.dart
│   │   ├── mock_storage.dart
│   │   ├── mock_auth_service.dart
│   │   └── mock_responses.dart
│   │
│   └── fixtures/
│       ├── test_files/
│       │   ├── sample.txt
│       │   ├── sample.pdf
│       │   └── sample.png
│       ├── test_data.dart
│       └── test_keys.dart
│
├── example/
│   ├── lib/
│   │   ├── main.dart                        # App exemple complète
│   │   ├── simple_upload.dart               # Exemple simple
│   │   ├── directory_upload.dart            # Upload répertoire
│   │   └── multi_space.dart                 # Multi-espaces
│   └── pubspec.yaml
│
├── benchmark/
│   ├── upload_benchmark.dart                # Benchmarks upload
│   ├── crypto_benchmark.dart                # Benchmarks crypto
│   └── serialization_benchmark.dart         # Benchmarks JSON
│
├── .github/
│   └── workflows/
│       ├── ci.yml                           # CI/CD
│       ├── publish.yml                      # Publication pub.dev
│       └── benchmarks.yml                   # Benchmarks auto
│
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

### 🔑 Architecture des Signers Injectables

Une des fonctionnalités clés du package est la possibilité d'injecter des signers externes, permettant à l'application hôte de garder le contrôle total sur la gestion des clés cryptographiques.

#### Cas d'Usage

1. **Clés IPNS gérées par l'app**
   - L'app Flutter possède déjà des clés IPNS
   - Ne veut pas les exposer au package Storacha
   - Veut juste utiliser Storacha pour l'upload/publication

2. **HSM (Hardware Security Module)**
   - Clés stockées dans un HSM externe
   - Signature déléguée au HSM
   - Clé privée jamais exposée

3. **Secure Enclave / Trusted Execution Environment**
   - iOS Secure Enclave
   - Android StrongBox/TEE
   - Signature native dans l'enclave

4. **Multi-signature / Threshold signatures**
   - Clés distribuées
   - Signature collaborative
   - Pas de clé unique stockée

#### Interface `Signer`

```dart
/// Abstract interface for signing operations
///
/// Implementations can provide custom key management while
/// keeping private keys hidden from the Storacha client.
abstract class Signer {
  /// Get the DID associated with this signer
  ///
  /// This is the public identifier, safe to expose.
  String get did;
  
  /// Get the public key bytes (optional)
  ///
  /// Some implementations may not expose the raw public key.
  Uint8List? get publicKey => null;
  
  /// Sign a message
  ///
  /// The implementation should:
  /// 1. Hash the message if needed
  /// 2. Sign using the private key (kept internal)
  /// 3. Return the signature bytes
  ///
  /// This method should NEVER expose or return the private key.
  Future<Uint8List> sign(Uint8List message);
  
  /// Verify a signature (optional)
  ///
  /// Default implementation can be provided using public key.
  /// Override for custom verification logic.
  Future<bool> verify(Uint8List message, Uint8List signature) async {
    throw UnimplementedError('Verification not supported by this signer');
  }
}
```

#### Implémentation par Défaut: `Ed25519Signer`

```dart
/// Default Ed25519-based signer with managed keys
class Ed25519Signer implements Signer {
  final Ed25519KeyPair _keyPair;
  final String _did;
  
  Ed25519Signer._(this._keyPair) 
    : _did = _generateDID(_keyPair.publicKey);
  
  /// Generate a new signer with random keys
  static Future<Ed25519Signer> generate() async {
    final keyPair = await generateEd25519KeyPair();
    return Ed25519Signer._(keyPair);
  }
  
  /// Load signer from stored private key
  static Future<Ed25519Signer> fromPrivateKey(Uint8List privateKey) async {
    final keyPair = Ed25519KeyPair.fromPrivateKey(privateKey);
    return Ed25519Signer._(keyPair);
  }
  
  @override
  String get did => _did;
  
  @override
  Uint8List get publicKey => _keyPair.publicKey;
  
  @override
  Future<Uint8List> sign(Uint8List message) async {
    return _keyPair.sign(message);
  }
  
  @override
  Future<bool> verify(Uint8List message, Uint8List signature) async {
    return _keyPair.verify(message, signature);
  }
}
```

#### Exemple: Signer IPNS Externe

```dart
/// Example: IPNS key managed by the host app
class IPNSSigner implements Signer {
  final String _did;
  final IPNSKeyManager _keyManager; // Host app's key manager
  
  IPNSSigner(this._did, this._keyManager);
  
  @override
  String get did => _did;
  
  @override
  Future<Uint8List> sign(Uint8List message) async {
    // Delegate signing to the host app's key manager
    // The private key never leaves the key manager
    return await _keyManager.signWithIPNSKey(message);
  }
}
```

#### Exemple: Secure Enclave Signer (iOS)

```dart
/// iOS Secure Enclave signer
class SecureEnclaveSigner implements Signer {
  final String _did;
  final SecureEnclaveKey _key;
  
  SecureEnclaveSigner(this._did, this._key);
  
  @override
  String get did => _did;
  
  @override
  Future<Uint8List> sign(Uint8List message) async {
    // Use iOS Security Framework via platform channel
    // Private key stored in Secure Enclave, never accessible
    return await _key.sign(message);
  }
}
```

#### Utilisation avec le Client

```dart
// Option 1: Utiliser le signer par défaut (géré par Storacha)
final client = await StorachaClient.create();
final account = await client.login('user@example.com');

// Option 2: Injecter un signer externe
final ipnsSigner = IPNSSigner(myIPNSDID, myKeyManager);
final client = await StorachaClient.create(
  config: ClientConfig(
    signer: ipnsSigner, // Clés IPNS gérées par l'app
  ),
);

// Option 3: Injecter un signer pour un espace spécifique
final space = await client.createSpace(
  'my-ipns-space',
  account: account,
  signer: ipnsSigner, // Ce space utilise les clés IPNS
);

// Option 4: Utiliser des signers différents pour différents espaces
final personalSpace = await client.createSpace('personal'); // Signer par défaut
final ipnsSpace = await client.createSpace('ipns', signer: ipnsSigner);
final secureSpace = await client.createSpace('secure', signer: secureEnclaveSigner);

// Les uploads utiliseront automatiquement le bon signer
await client.setCurrentSpace(ipnsSpace.did);
await client.uploadFile(data); // Signé avec ipnsSigner
```

#### Configuration Multi-Signer

```dart
class ClientConfig {
  /// Default signer for account operations
  final Signer? accountSigner;
  
  /// Map of space DID → Signer
  final Map<String, Signer>? spaceSigners;
  
  /// Fallback signer if no specific signer is set
  final Signer? defaultSigner;
  
  const ClientConfig({
    this.accountSigner,
    this.spaceSigners,
    this.defaultSigner,
  });
}
```

#### Avantages de cette Architecture

1. **🔒 Sécurité Maximale**
   - Clés privées jamais exposées au package
   - L'app garde le contrôle total
   - Support HSM/Secure Enclave natif

2. **🔄 Flexibilité**
   - Injection facile de signers custom
   - Support multi-signers par espace
   - Migration progressive possible

3. **🎯 Séparation des Responsabilités**
   - Storacha gère le transport et protocole
   - L'app gère les clés sensibles
   - Clean architecture

4. **🧪 Testabilité**
   - Mock signers pour tests
   - Pas besoin de vraies clés en test
   - Isolation parfaite

5. **🔌 Interopérabilité**
   - Réutilisation clés IPNS existantes
   - Intégration avec wallets crypto
   - Support multi-blockchain

#### Tests avec Mock Signer

```dart
class MockSigner implements Signer {
  final String _did;
  final List<SignRequest> signRequests = [];
  
  MockSigner([this._did = 'did:key:mock']);
  
  @override
  String get did => _did;
  
  @override
  Future<Uint8List> sign(Uint8List message) async {
    signRequests.add(SignRequest(message, DateTime.now()));
    // Return fake signature
    return Uint8List.fromList(List.filled(64, 0));
  }
}

// Dans les tests
test('upload uses correct signer', () async {
  final mockSigner = MockSigner('did:key:test123');
  final client = await StorachaClient.create(
    config: ClientConfig(signer: mockSigner),
  );
  
  await client.uploadFile(testData);
  
  expect(mockSigner.signRequests, isNotEmpty);
  expect(mockSigner.signRequests.first.message, contains(testData));
});
```

#### Migration depuis Gestion Interne

Pour les apps existantes qui veulent migrer progressivement:

```dart
// Phase 1: Storacha gère tout (existant)
final client = await StorachaClient.create();

// Phase 2: Export des clés existantes
final exportedKeys = await client.exportKeys();
await myKeyManager.import(exportedKeys);

// Phase 3: Création du signer custom
final customSigner = MyCustomSigner(myKeyManager);

// Phase 4: Nouveau client avec signer externe
final newClient = await StorachaClient.create(
  config: ClientConfig(signer: customSigner),
);

// Les données restent accessibles car même DID
```

## 🎯 Critères de Qualité & Performance

### Métriques de Qualité
| Métrique | Objectif | Justification |
|----------|----------|---------------|
| **Pub.dev Score** | ≥130/140 | Publication pro |
| **Code Coverage** | ≥85% | Fiabilité élevée |
| **Dart Analyze** | 0 errors, 0 warnings | Code propre |
| **Documentation** | 100% API publique | Utilisabilité |
| **Lines of Code** | <15,000 | Maintenabilité |
| **Cyclomatic Complexity** | <10 par fonction | Lisibilité |

### Métriques de Performance

#### Upload
| Scénario | Objectif | Condition |
|----------|----------|-----------|
| Fichier 1MB | <2s | WiFi 50Mbps |
| Fichier 10MB | <8s | WiFi 50Mbps |
| Fichier 100MB | <90s | WiFi 50Mbps |
| 100 fichiers 100KB | <30s | WiFi 50Mbps |

#### Cryptographie
| Opération | Objectif | Device |
|-----------|----------|--------|
| Génération clé Ed25519 | <100ms | iPhone 12 |
| Signature UCAN | <50ms | iPhone 12 |
| Vérification signature | <30ms | iPhone 12 |

#### Mémoire
| Opération | Objectif Max | Justification |
|-----------|--------------|---------------|
| Upload 100MB | +150MB RAM | Streaming |
| Client idle | <5MB RAM | Efficacité |
| 1000 CID en cache | <10MB RAM | Scalabilité |

#### Startup
| Opération | Objectif | Condition |
|-----------|----------|-----------|
| Client.create() | <200ms | Cache chaud |
| Client.create() | <1s | Cache froid |
| Login (email) | <500ms | Réseau exclu |

## 🧪 Stratégie de Tests - Exhaustive

### Tests Unitaires (Target: 85%+ coverage)

#### Layer 1: Modèles & Utils (100% coverage)
- ✅ Sérialisation/désérialisation JSON
- ✅ Validation des champs
- ✅ Égalité et hashCode
- ✅ Conversions de types
- ✅ Edge cases (null, vide, invalide)

#### Layer 2: Cryptographie (95% coverage)
- ✅ Génération clés Ed25519 (100 itérations)
- ✅ Signature/vérification (vecteurs de test officiels)
- ✅ Encodage/décodage DID
- ✅ Construction/parsing UCAN
- ✅ Validation délégations
- ✅ Chaînes de preuves UCAN
- ⚠️ Tests de sécurité (timing attacks, etc.)

#### Layer 3: IPFS & Multiformats (90% coverage)
- ✅ CID v0/v1 parsing
- ✅ Multibase (base58btc, base32, base64url)
- ✅ Multihash (SHA-256, SHA-512)
- ✅ Varint encoding/decoding
- ✅ CAR encoding/decoding
- ✅ Compatibilité avec implémentations JS/Go

#### Layer 4: Services (80% coverage)
- ✅ Auth service (tous les flows)
- ✅ Space service (CRUD complet)
- ✅ Upload service (chunks, retry, cancel)
- ✅ Gateway service
- ✅ Gestion d'erreurs

#### Layer 5: Storage (85% coverage)
- ✅ Secure storage (mock & réel si possible)
- ✅ Preferences storage
- ✅ Memory storage
- ✅ Migrations de données

### Tests d'Intégration (Target: 30 scénarios)

#### Scénarios Critiques
1. **Happy Path Complet**
   - Create client → Login → Create space → Upload file → Verify on gateway
   
2. **Multi-device Flow**
   - Device A: Create space with recovery
   - Device B: Login → Access same space
   
3. **Error Recovery**
   - Network failure during upload → Retry → Success
   - Invalid credentials → Re-login → Success
   
4. **Concurrent Operations**
   - Upload 10 files en parallèle
   - Create 5 spaces simultanément
   
5. **Large File Handling**
   - Upload 500MB fichier avec progress
   - Cancel mid-upload
   - Resume upload

#### Tests de Compatibilité
- ✅ Upload depuis Dart → Verify depuis JS client
- ✅ Create space JS → Access depuis Dart
- ✅ CID généré Dart == CID généré JS

### Tests de Performance

#### Benchmarks
```dart
// benchmark/upload_benchmark.dart
void main() {
  benchmark('Upload 1MB file', () async {
    final result = await client.uploadFile(data1MB);
  });
  
  benchmark('Generate 1000 CIDs', () {
    for (int i = 0; i < 1000; i++) {
      CID.parse('Qm...');
    }
  });
}
```

#### Profiling
- Memory profiling (DevTools)
- CPU profiling (Dart Observatory)
- Network profiling (Charles/Proxyman)

### Tests Multi-plateformes

#### Matrice de Tests
| Test | Android | iOS | Web | Desktop |
|------|---------|-----|-----|---------|
| Unit tests | ✅ | ✅ | ✅ | ✅ |
| Integration | ✅ | ✅ | ⚠️ | ⚠️ |
| E2E | ✅ | ✅ | ❌ | ❌ |
| Performance | ✅ | ✅ | ⚠️ | ❌ |

⚠️ = Tests limités, ❌ = Non applicable

### Tests de Sécurité

#### Checklist
- [ ] Clés privées never logged
- [ ] Clés privées never in stacktrace
- [ ] Secure storage encrypted at rest
- [ ] HTTPS only (no HTTP fallback)
- [ ] Certificate pinning (optionnel)
- [ ] UCAN expiration respected
- [ ] DID validation stricte

## 📈 Phases d'Implémentation - Détaillées

### Phase 0: Fondations (2 jours)
**Objectif**: Infrastructure et tooling

**Tâches**:
- [x] Structure projet
- [x] Configuration pubspec.yaml
- [x] Configuration analysis_options.yaml
- [x] Setup CI/CD GitHub Actions
- [ ] Configuration coverage
- [ ] Setup pre-commit hooks
- [ ] Documentation architecture

**Livrables**:
- ✅ Projet compile
- ✅ dart analyze = 0 issues
- ✅ CI/CD pipeline functional

### Phase 1: IPFS Core (5 jours)
**Objectif**: Implémenter multiformats & CID

**Jour 1-2: Multiformats**
```dart
// lib/src/ipfs/multiformats/varint.dart
class Varint {
  static Uint8List encode(int value) { ... }
  static int decode(Uint8List bytes) { ... }
}

// lib/src/ipfs/multiformats/multibase.dart
class Multibase {
  static String encode(Uint8List data, String encoding) { ... }
  static Uint8List decode(String encoded) { ... }
}

// lib/src/ipfs/multiformats/multihash.dart
class Multihash {
  final int code;
  final Uint8List digest;
  Uint8List encode() { ... }
}
```

**Jour 3-4: CID**
```dart
// lib/src/ipfs/cid/cid.dart
abstract class CID {
  int get version;
  int get codec;
  Multihash get hash;
  
  String toV0String();
  String toV1String([String base = 'base32']);
  Uint8List toBytes();
  
  static CID parse(String cidStr) { ... }
  static CID fromBytes(Uint8List bytes) { ... }
}
```

**Jour 5: CAR Basics**
```dart
// lib/src/ipfs/car/car_encoder.dart
class CAREncoder {
  Uint8List encode(CID root, List<Block> blocks) { ... }
}
```

**Tests**: 50+ tests, coverage >90%

### Phase 2: Cryptographie (5 jours)
**Objectif**: DID & UCAN

**Jour 1-2: Ed25519 & DID**
```dart
// lib/src/crypto/did/ed25519_key_pair.dart
class Ed25519KeyPair {
  final Uint8List publicKey;  // 32 bytes
  final Uint8List privateKey; // 64 bytes
  
  static Ed25519KeyPair generate() { ... }
  Uint8List sign(Uint8List message) { ... }
  bool verify(Uint8List message, Uint8List signature) { ... }
}

// lib/src/crypto/did/did_key.dart
class DIDKey implements DID {
  final Ed25519KeyPair keyPair;
  
  @override
  String get did => 'did:key:z${multibaseEncode(publicKey)}';
  
  String createJWT(Map<String, dynamic> payload) { ... }
}
```

**Jour 3-5: UCAN**
```dart
// lib/src/crypto/ucan/ucan.dart
class UCAN {
  final DID issuer;
  final DID audience;
  final List<Capability> capabilities;
  final DateTime expiration;
  final List<UCAN> proofs;
  
  String encode() { ... } // JWT
  static UCAN decode(String jwt) { ... }
  bool validate() { ... }
}

// lib/src/crypto/ucan/capability.dart
class Capability {
  final String resource; // "storage://did:key:z.../space"
  final String ability;  // "upload/add", "space/create"
  final Map<String, dynamic>? caveats;
}
```

**Tests**: 40+ tests, vecteurs de test UCAN spec

### Phase 3: Storage & Models (3 jours)
**Objectif**: Persistance & modèles de données

**Jour 1: Storage**
```dart
// lib/src/storage/storage_interface.dart
abstract class Storage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clear();
}

// lib/src/storage/secure_storage_impl.dart
class SecureStorageImpl implements Storage {
  final FlutterSecureStorage _storage;
  // Implémentation avec clés DID, UCAN tokens
}
```

**Jour 2-3: Models**
```dart
// lib/src/models/space.dart
@JsonSerializable()
class Space {
  final String did;
  final String? name;
  final DateTime createdAt;
  final Account? account;
  
  factory Space.fromJson(Map<String, dynamic> json) => _$SpaceFromJson(json);
  Map<String, dynamic> toJson() => _$SpaceToJson(this);
}

// lib/src/models/account.dart
@JsonSerializable()
class Account {
  final String email;
  final Plan plan;
  // ...
}
```

**Tests**: 25+ tests

### Phase 4: HTTP Transport (3 jours)
**Objectif**: Communication avec API Storacha

**Jour 1-2: Transport Layer**
```dart
// lib/src/transport/http_transport.dart
class HttpTransport {
  final Dio _dio;
  
  Future<Response> post(
    String endpoint,
    {required Uint8List body,
     required Map<String, String> headers}
  ) async { ... }
}

// lib/src/transport/auth_interceptor.dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Inject UCAN authorization
    options.headers['Authorization'] = 'Bearer ${ucan.encode()}';
    super.onRequest(options, handler);
  }
}
```

**Jour 3: Retry & Error Handling**
```dart
// lib/src/transport/retry_interceptor.dart
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration initialDelay;
  // Exponential backoff
}
```

**Tests**: 20+ tests avec mocks

### Phase 5: Auth Service (3 jours)
**Objectif**: Login & account management

```dart
// lib/src/services/auth/auth_service_impl.dart
class AuthServiceImpl implements AuthService {
  @override
  Future<Account> login(String email) async {
    // 1. POST /auth/email avec email
    // 2. Poll jusqu'à confirmation email
    // 3. Récupérer token
    // 4. Sauvegarder dans storage
    return account;
  }
  
  @override
  Future<void> logout() async {
    await _storage.delete('auth_token');
    await _storage.delete('account');
  }
}
```

**Tests**: 15+ tests + 1 integration test

### Phase 6: Space Service (4 jours)
**Objectif**: Gestion des espaces

```dart
// lib/src/services/space/space_service_impl.dart
class SpaceServiceImpl implements SpaceService {
  @override
  Future<Space> createSpace(
    String name, {
    Account? account,
    List<Gateway>? authorizeGatewayServices,
    bool skipGatewayAuthorization = false,
  }) async {
    // 1. Générer DID pour le space
    final spaceDID = DIDKey.generate();
    
    // 2. Créer delegation du account vers space
    if (account != null) {
      final delegation = await _createDelegation(account, spaceDID);
    }
    
    // 3. POST /space/create avec delegation
    final response = await _transport.post('/space/create', ...);
    
    // 4. Sauvegarder localement
    await _storage.write('space:$name', space.toJson());
    
    return space;
  }
  
  @override
  Future<List<Space>> listSpaces() async { ... }
  
  @override
  Future<void> setCurrentSpace(String did) async { ... }
}
```

**Tests**: 20+ tests + 2 integration tests

### Phase 7: Upload Service (5 jours)
**Objectif**: Upload fichiers & répertoires

**Jour 1-2: File Upload**
```dart
// lib/src/services/upload/upload_service_impl.dart
class UploadServiceImpl implements UploadService {
  @override
  Future<CID> uploadFile(
    Uint8List content, {
    String? filename,
    String? mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    // 1. Calculer CID du contenu
    final cid = await _calculateCID(content);
    
    // 2. Encoder en CAR
    final car = _carEncoder.encode(cid, content);
    
    // 3. Upload avec progress
    final response = await _transport.post(
      '/upload',
      body: car,
      onSendProgress: onProgress,
    );
    
    return cid;
  }
}
```

**Jour 3-4: Directory Upload**
```dart
@override
Future<CID> uploadDirectory(List<StorachaFile> files) async {
  // 1. Créer UnixFS directory structure
  final directory = _buildDirectory(files);
  
  // 2. Calculer CID du directory
  final dirCID = await _calculateDirectoryCID(directory);
  
  // 3. Encoder tous les blocks en CAR
  final car = _carEncoder.encodeDirectory(dirCID, directory);
  
  // 4. Upload
  await _transport.post('/upload', body: car);
  
  return dirCID;
}
```

**Jour 5: Chunking & Queue**
```dart
// lib/src/services/upload/file_chunker.dart
class FileChunker {
  static const int defaultChunkSize = 1024 * 1024; // 1MB
  
  Stream<Uint8List> chunk(Uint8List data) async* {
    for (int i = 0; i < data.length; i += defaultChunkSize) {
      yield data.sublist(i, min(i + defaultChunkSize, data.length));
    }
  }
}

// lib/src/services/upload/upload_queue.dart
class UploadQueue {
  final Queue<UploadTask> _queue = Queue();
  final int concurrency;
  
  Future<void> add(UploadTask task) async { ... }
}
```

**Tests**: 30+ tests + 3 integration tests

### Phase 8: Client Principal (2 jours)
**Objectif**: API publique unifiée

```dart
// lib/src/client/storacha_client.dart
class StorachaClient {
  final AuthService _authService;
  final SpaceService _spaceService;
  final UploadService _uploadService;
  final GatewayService _gatewayService;
  
  static Future<StorachaClient> create([ClientConfig? config]) async {
    // Initialize all services
    return StorachaClient._internal(...);
  }
  
  // Auth
  Future<Account> login(String email) => _authService.login(email);
  
  // Spaces
  Future<Space> createSpace(String name, {Account? account}) =>
      _spaceService.createSpace(name, account: account);
  
  Future<void> setCurrentSpace(String did) =>
      _spaceService.setCurrentSpace(did);
  
  // Upload
  Future<CID> uploadFile(Uint8List content, {String? filename}) =>
      _uploadService.uploadFile(content, filename: filename);
  
  Future<CID> uploadDirectory(List<StorachaFile> files) =>
      _uploadService.uploadDirectory(files);
  
  // Gateway
  String getGatewayUrl(CID cid, {String gateway = 'storacha.link'}) =>
      _gatewayService.getGatewayUrl(cid, gateway: gateway);
}
```

**Tests**: Integration tests complets

### Phase 9: Tests & Documentation (4 jours)
**Jour 1-2: Tests Complets**
- Augmenter coverage à 85%+
- Integration tests multi-scénarios
- Performance tests

**Jour 3: Documentation**
- README complet
- API reference (dartdoc)
- Migration guide depuis JS
- Examples

**Jour 4: Polish**
- dart analyze = 0 issues
- Format code
- Optimize imports
- Benchmarks finaux

### Phase 10: Publication (1 jour)
**Pre-publication Checklist**
- [ ] All tests pass
- [ ] Coverage ≥85%
- [ ] dart analyze clean
- [ ] README complet
- [ ] CHANGELOG à jour
- [ ] LICENSE correct
- [ ] pubspec.yaml complet (description, homepage, etc.)
- [ ] Example app functional
- [ ] Documentation dartdoc complète

**Publication**
```bash
dart pub publish --dry-run  # Vérification
dart pub publish            # Publication réelle
```

## 🚀 Optimisations de Performance

### Memory Management
1. **Streaming Upload**: Ne pas charger fichier entier en mémoire
2. **Weak References**: Cache CID avec WeakMap équivalent
3. **Dispose Pattern**: Nettoyer ressources (Dio, streams)

### Network Optimization
1. **HTTP/2**: Utiliser si disponible
2. **Connection Pooling**: Réutiliser connexions (Dio default)
3. **Compression**: Gzip pour requêtes texte
4. **Chunked Transfer**: Pour gros fichiers

### Crypto Optimization
1. **Key Caching**: Garder clés en mémoire pendant session
2. **Isolate**: Signatures lourdes en background
3. **Native Bindings**: FFI pour Ed25519 si nécessaire

## 📊 Monitoring & Analytics

### Logging Strategy
```dart
final logger = Logger('storacha_dart');

logger.info('Upload started', {
  'file_size': fileSize,
  'mime_type': mimeType,
});

logger.severe('Upload failed', error, stackTrace);
```

### Metrics à Exposer
- Upload success rate
- Average upload time
- Network errors rate
- Auth failures
- Space creation time

## 🔒 Sécurité - Checklist Complète

### Stockage
- [x] Clés privées dans flutter_secure_storage
- [x] Jamais de clés dans logs
- [x] Jamais de clés dans stacktraces
- [ ] Option de password-protect storage
- [ ] Automatic key rotation (optionnel)

### Réseau
- [x] HTTPS uniquement
- [ ] Certificate pinning (optionnel)
- [ ] Timeout configuration
- [x] Retry avec backoff

### Cryptographie
- [x] Ed25519 pour signatures
- [x] Random sécurisé (SecureRandom)
- [ ] Constant-time comparisons
- [ ] Zeroize sensitive data après usage

### UCAN
- [x] Validation expiration
- [x] Validation chaîne de preuves
- [x] Validation signatures
- [ ] Revocation checks (si API disponible)

## 📚 Documentation Complète

### README.md
- [x] Installation
- [x] Quick start
- [x] Examples
- [x] Platform support
- [x] Contributing guide
- [ ] Troubleshooting

### Dartdoc
- [ ] Tous les éléments publics documentés
- [ ] Examples dans doc comments
- [ ] Links entre classes

### Guides
- [ ] MIGRATION_FROM_JS.md
- [ ] ARCHITECTURE.md
- [ ] CONTRIBUTING.md
- [ ] SECURITY.md

## 🎯 Objectifs de Release

### v0.1.0 (MVP)
- ✅ Client création
- ✅ Email auth
- ✅ Space création
- ✅ File upload
- ✅ CID génération
- ✅ Gateway URL

### v0.2.0
- [ ] Directory upload
- [ ] Progress tracking
- [ ] Upload cancellation
- [ ] Multiple spaces

### v0.3.0
- [ ] Upload queue
- [ ] Concurrent uploads
- [ ] Retry strategies
- [ ] Better error handling

### v1.0.0 (Stable)
- [ ] Feature complete
- [ ] 85%+ coverage
- [ ] Production ready
- [ ] Performance optimized
- [ ] Fully documented

## 📞 Support & Communauté

### Canaux de Support
- GitHub Issues - Bugs & feature requests
- GitHub Discussions - Questions & help
- Discord - Real-time chat (si créé)

### Contribution
- Contribution guidelines
- Code of conduct
- Pull request template
- Issue templates

---

**Dernière mise à jour**: 2025-10-11
**Version du plan**: 2.0  
**Statut**: Ready to implement  
**Estimation totale**: 35-40 jours (1 développeur)
