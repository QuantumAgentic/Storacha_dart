# TODO - Storacha Dart Implementation

> **Statut du Projet**: 🚀 Phase 0 (Fondations) - 10% Complété  
> **Dernière mise à jour**: 2025-10-11  
> **Estimation totale**: 35-40 jours

## 📊 Vue d'Ensemble

| Phase | Progression | Tests | Jours estimés | Status |
|-------|-------------|-------|---------------|--------|
| Phase 0: Fondations | ████████░░ 80% | N/A | 2j | 🟢 En cours |
| Phase 1: IPFS Core | ░░░░░░░░░░ 0% | 0/50 | 5j | ⚪ À faire |
| Phase 2: Cryptographie | ░░░░░░░░░░ 0% | 0/40 | 5j | ⚪ À faire |
| Phase 3: Storage & Models | ░░░░░░░░░░ 0% | 0/25 | 3j | ⚪ À faire |
| Phase 4: HTTP Transport | ░░░░░░░░░░ 0% | 0/20 | 3j | ⚪ À faire |
| Phase 5: Auth Service | ░░░░░░░░░░ 0% | 0/15 | 3j | ⚪ À faire |
| Phase 6: Space Service | ░░░░░░░░░░ 0% | 0/20 | 4j | ⚪ À faire |
| Phase 7: Upload Service | ░░░░░░░░░░ 0% | 0/30 | 5j | ⚪ À faire |
| Phase 8: Client Principal | ░░░░░░░░░░ 0% | 0/10 | 2j | ⚪ À faire |
| Phase 9: Tests & Docs | ░░░░░░░░░░ 0% | N/A | 4j | ⚪ À faire |
| Phase 10: Publication | ░░░░░░░░░░ 0% | N/A | 1j | ⚪ À faire |

**Total**: 37 jours

## 🎯 Phase 0: Fondations (Jour 0-2)

### Infrastructure

- [x] **[DONE]** Créer structure de dossiers
- [x] **[DONE]** Configurer pubspec.yaml avec dépendances
- [x] **[DONE]** Configurer analysis_options.yaml strict
- [x] **[DONE]** Créer README.md initial
- [x] **[DONE]** Créer LICENSE (MIT)
- [x] **[DONE]** Créer .gitignore
- [x] **[DONE]** Créer CHANGELOG.md
- [x] **[DONE]** Créer docs/PLAN.md (version 2.0)
- [x] **[DONE]** Créer docs/TODO.md
- [ ] **[TODO]** Créer .github/workflows/ci.yml (CI/CD)
- [ ] **[TODO]** Configurer coverage tracking
- [ ] **[TODO]** Setup pre-commit hooks (optional)
- [ ] **[TODO]** Initialiser repository Git indépendant

### Documentation Technique

- [ ] **[TODO]** Créer docs/ARCHITECTURE.md
  - Diagrammes de séquence (login, upload)
  - Diagrammes de classes
  - Flow diagrams
- [ ] **[TODO]** Créer docs/API_REFERENCE.md
- [ ] **[TODO]** Créer docs/MIGRATION_FROM_JS.md
- [ ] **[TODO]** Créer CONTRIBUTING.md
- [ ] **[TODO]** Créer SECURITY.md

### Livrables Phase 0
- ✅ Projet compile sans erreurs
- ✅ `dart analyze` retourne 0 issues
- ⏳ CI/CD pipeline fonctionnel
- ⏳ Documentation architecture complète

---

## 🔗 Phase 1: IPFS Core (Jour 3-7)

### Jour 3: Varint & Multibase

#### Varint Implementation
- [ ] **[TODO]** Créer `lib/src/ipfs/multiformats/varint.dart`
  - [ ] Fonction `encode(int value) → Uint8List`
  - [ ] Fonction `decode(Uint8List bytes) → int`
  - [ ] Fonction `encodingLength(int value) → int`
- [ ] **[TODO]** Tests varint (10+ tests)
  - [ ] Test 0, 1, 127, 128, 255, 256
  - [ ] Test max safe int
  - [ ] Test erreurs (negative numbers)

#### Multibase Implementation
- [ ] **[TODO]** Créer `lib/src/ipfs/multiformats/multibase.dart`
  - [ ] Support base58btc (Bitcoin)
  - [ ] Support base32 (lowercase)
  - [ ] Support base64url
  - [ ] Fonction `encode(Uint8List data, String encoding) → String`
  - [ ] Fonction `decode(String encoded) → Uint8List`
  - [ ] Fonction `detectEncoding(String str) → String?`
- [ ] **[TODO]** Tests multibase (15+ tests)
  - [ ] Test chaque encodage
  - [ ] Test round-trip (encode → decode)
  - [ ] Test vecteurs de test officiels
  - [ ] Test détection automatique

**Estimation Jour 3**: 6-8h de dev + 2-3h de tests

### Jour 4: Multihash

- [ ] **[TODO]** Créer `lib/src/ipfs/multiformats/multihash.dart`
  - [ ] Class `Multihash` avec `code`, `digest`, `length`
  - [ ] Support SHA-256 (code 0x12)
  - [ ] Support SHA-512 (code 0x13)
  - [ ] Fonction `encode() → Uint8List`
  - [ ] Fonction `static decode(Uint8List bytes) → Multihash`
  - [ ] Fonction `static fromDigest(int code, Uint8List digest) → Multihash`
- [ ] **[TODO]** Créer `lib/src/ipfs/multiformats/multicodec.dart`
  - [ ] Constantes pour codecs communs
  - [ ] `dagPB = 0x70`
  - [ ] `dagCBOR = 0x71`
  - [ ] `raw = 0x55`
  - [ ] `json = 0x0200`
- [ ] **[TODO]** Tests multihash (12+ tests)
  - [ ] Test SHA-256 encoding/decoding
  - [ ] Test SHA-512 encoding/decoding
  - [ ] Test vecteurs officiels
  - [ ] Test erreurs (invalid code, truncated)

**Estimation Jour 4**: 6-8h de dev + 2h de tests

### Jour 5-6: CID Implementation

- [ ] **[TODO]** Créer `lib/src/ipfs/cid/cid.dart`
  - [ ] Abstract class `CID`
  - [ ] Getters: `version`, `codec`, `hash`
  - [ ] Méthodes abstraites: `toBytes()`, `toString()`
  - [ ] Factory `CID.parse(String str)`
  - [ ] Factory `CID.fromBytes(Uint8List bytes)`
  - [ ] Equality & hashCode overrides
- [ ] **[TODO]** Créer `lib/src/ipfs/cid/cid_v0.dart`
  - [ ] Class `CIDv0 extends CID`
  - [ ] Version toujours 0
  - [ ] Codec toujours dag-pb (0x70)
  - [ ] Hash toujours SHA-256
  - [ ] toString() → base58btc
- [ ] **[TODO]** Créer `lib/src/ipfs/cid/cid_v1.dart`
  - [ ] Class `CIDv1 extends CID`
  - [ ] Version toujours 1
  - [ ] Codec configurable
  - [ ] Hash configurable
  - [ ] toString([String base = 'base32']) → string
  - [ ] Conversion CIDv0 → CIDv1
- [ ] **[TODO]** Créer `lib/src/ipfs/cid/cid_parser.dart`
  - [ ] Fonction `parseCID(String str) → CID`
  - [ ] Détection auto v0 vs v1
  - [ ] Validation format
- [ ] **[TODO]** Tests CID (20+ tests)
  - [ ] Test parsing CIDv0 valides
  - [ ] Test parsing CIDv1 valides (différentes bases)
  - [ ] Test conversion v0 → v1
  - [ ] Test CID identiques == true
  - [ ] Test toString() round-trip
  - [ ] Test erreurs (invalid format)
  - [ ] Test compatibilité avec CID JS/Go connus

**Estimation Jour 5-6**: 12-14h de dev + 3-4h de tests

### Jour 7: CAR Format Basics

- [ ] **[TODO]** Créer `lib/src/ipfs/car/car_header.dart`
  - [ ] Class `CARHeader` avec `version`, `roots`
  - [ ] Encode/decode CBOR
- [ ] **[TODO]** Créer `lib/src/ipfs/car/car_block.dart`
  - [ ] Class `Block` avec `cid`, `data`
- [ ] **[TODO]** Créer `lib/src/ipfs/car/car_encoder.dart`
  - [ ] Fonction `encode(CID root, Uint8List data) → Uint8List`
  - [ ] Format: [header length][header][block length][block CID][block data]
- [ ] **[TODO]** Tests CAR (10+ tests)
  - [ ] Test encoding simple
  - [ ] Test round-trip avec decoder
  - [ ] Test multiple blocks

**Estimation Jour 7**: 6h de dev + 2h de tests

### Phase 1 - Checklist Final
- [ ] Tous les tests passent (50+)
- [ ] Coverage ≥90%
- [ ] `dart analyze` clean
- [ ] Benchmarks CID parsing (<1μs)
- [ ] Documentation dartdoc complète

---

## 🔐 Phase 2: Cryptographie (Jour 8-12)

### Jour 8: Ed25519 Key Pair

- [ ] **[TODO]** Créer `lib/src/crypto/utils/key_generator.dart`
  - [ ] Fonction `generateEd25519KeyPair() → Ed25519KeyPair`
  - [ ] Utiliser `pointycastle` SecureRandom
- [ ] **[TODO]** Créer `lib/src/crypto/did/ed25519_key_pair.dart`
  - [ ] Class `Ed25519KeyPair`
  - [ ] Fields: `publicKey` (32 bytes), `privateKey` (64 bytes)
  - [ ] Méthode `sign(Uint8List message) → Uint8List` (64 bytes)
  - [ ] Méthode `verify(Uint8List message, Uint8List signature) → bool`
  - [ ] Méthode `toBytes() → Uint8List` (private export)
  - [ ] Factory `fromBytes(Uint8List bytes) → Ed25519KeyPair`
- [ ] **[TODO]** Tests Ed25519 (15+ tests)
  - [ ] Test génération clés (100 itérations)
  - [ ] Test signature/vérification (happy path)
  - [ ] Test vérification échoue avec mauvaise signature
  - [ ] Test vecteurs de test RFC 8032
  - [ ] Test serialization/deserialization

**Estimation Jour 8**: 7h de dev + 2h de tests

### Jour 8.5: Signer Interface (Injectable Architecture)

- [ ] **[TODO]** Créer `lib/src/crypto/signer.dart`
  - [ ] Abstract class `Signer`
  - [ ] Getter `String get did`
  - [ ] Getter `Uint8List? get publicKey` (optional)
  - [ ] Méthode `Future<Uint8List> sign(Uint8List message)`
  - [ ] Méthode `Future<bool> verify(Uint8List message, Uint8List signature)` (optional)
  - [ ] Documentation complète sur l'injection externe
- [ ] **[TODO]** Créer `lib/src/crypto/ed25519_signer.dart`
  - [ ] Class `Ed25519Signer implements Signer`
  - [ ] Field privé `Ed25519KeyPair _keyPair`
  - [ ] Factory `generate() → Future<Ed25519Signer>`
  - [ ] Factory `fromPrivateKey(Uint8List key) → Future<Ed25519Signer>`
  - [ ] Implémentation `sign()` qui délègue à `_keyPair.sign()`
  - [ ] Implémentation `verify()` qui délègue à `_keyPair.verify()`
  - [ ] Méthode `exportPrivateKey() → Uint8List` (pour migration)
- [ ] **[TODO]** Tests Signer (10+ tests)
  - [ ] Test Ed25519Signer génération
  - [ ] Test Ed25519Signer fromPrivateKey
  - [ ] Test sign/verify round-trip
  - [ ] Test MockSigner pour tests
  - [ ] Test injection dans client (préparation)

**Estimation Jour 8.5**: 4h de dev + 1.5h de tests

**💡 Note Architecture**: Cette interface `Signer` permettra aux apps d'injecter leurs propres implémentations (clés IPNS, HSM, Secure Enclave) sans exposer les clés privées au package Storacha.

### Jour 9: DID Key

- [ ] **[TODO]** Créer `lib/src/crypto/did/did.dart`
  - [ ] Abstract class `DID`
  - [ ] Getter `String get did`
  - [ ] Méthode `Uint8List sign(Uint8List message)`
  - [ ] Méthode `bool verify(Uint8List message, Uint8List signature)`
- [ ] **[TODO]** Créer `lib/src/crypto/did/did_key.dart`
  - [ ] Class `DIDKey implements DID`
  - [ ] Field `Ed25519KeyPair keyPair`
  - [ ] Getter `did` → `did:key:z${multibaseEncode(publicKey)}`
  - [ ] Factory `generate() → DIDKey`
  - [ ] Factory `fromPrivateKey(Uint8List bytes) → DIDKey`
  - [ ] Factory `parse(String didStr) → DIDKey` (public key only)
- [ ] **[TODO]** Créer `lib/src/crypto/did/did_resolver.dart`
  - [ ] Fonction `resolve(String did) → DID?`
  - [ ] Support did:key uniquement pour l'instant
- [ ] **[TODO]** Tests DID (12+ tests)
  - [ ] Test génération DID format correct
  - [ ] Test parsing DID valide
  - [ ] Test round-trip (generate → toString → parse)
  - [ ] Test signature via DID
  - [ ] Test erreurs (invalid format)

**Estimation Jour 9**: 6h de dev + 2h de tests

### Jour 10-12: UCAN Tokens

#### Jour 10: UCAN Core

- [ ] **[TODO]** Créer `lib/src/crypto/ucan/capability.dart`
  - [ ] Class `Capability`
  - [ ] Fields: `resource` (String), `ability` (String), `caveats` (Map?)
  - [ ] JSON serialization
- [ ] **[TODO]** Créer `lib/src/crypto/ucan/ucan.dart`
  - [ ] Class `UCAN`
  - [ ] Fields: `issuer` (DID), `audience` (DID), `capabilities`, `expiration`, `proofs`
  - [ ] Optional: `notBefore`, `facts`, `nonce`
- [ ] **[TODO]** Tests Capability (5 tests)

**Estimation Jour 10**: 5h de dev + 1h de tests

#### Jour 11: UCAN Builder & Encoding

- [ ] **[TODO]** Créer `lib/src/crypto/ucan/ucan_builder.dart`
  - [ ] Class `UCANBuilder`
  - [ ] Méthode `issuer(DID did) → UCANBuilder`
  - [ ] Méthode `audience(DID did) → UCANBuilder`
  - [ ] Méthode `capability(Capability cap) → UCANBuilder`
  - [ ] Méthode `expiration(DateTime exp) → UCANBuilder`
  - [ ] Méthode `proof(UCAN proof) → UCANBuilder`
  - [ ] Méthode `build() → UCAN`
  - [ ] Méthode `sign(DID signer) → String` (JWT)
- [ ] **[TODO]** Implémenter JWT encoding dans UCAN
  - [ ] Header: `{ "alg": "EdDSA", "typ": "JWT", "ucv": "0.9.0" }`
  - [ ] Payload: UCAN fields en JSON
  - [ ] Signature: Ed25519 de header.payload
  - [ ] Format: `base64url(header).base64url(payload).base64url(signature)`
- [ ] **[TODO]** Tests Builder (8 tests)

**Estimation Jour 11**: 7h de dev + 2h de tests

#### Jour 12: UCAN Validation

- [ ] **[TODO]** Créer `lib/src/crypto/ucan/ucan_validator.dart`
  - [ ] Class `UCANValidator`
  - [ ] Méthode `validate(String jwt) → ValidationResult`
  - [ ] Vérifications:
    - [ ] Format JWT valide
    - [ ] Signature valide
    - [ ] Expiration non dépassée
    - [ ] Chaîne de preuves valide (récursif)
    - [ ] Capabilities cohérentes
- [ ] **[TODO]** Créer `lib/src/crypto/ucan/delegation.dart`
  - [ ] Fonctions helper pour créer délégations communes
  - [ ] `createSpaceDelegation(DID from, DID to, String spaceDID)`
  - [ ] `createUploadDelegation(DID from, DID to, String spaceDID)`
- [ ] **[TODO]** Tests Validation (10 tests)
  - [ ] Test UCAN valide
  - [ ] Test UCAN expiré
  - [ ] Test signature invalide
  - [ ] Test chaîne de preuves invalide
  - [ ] Test vecteurs UCAN spec

**Estimation Jour 12**: 8h de dev + 2h de tests

### Phase 2 - Checklist Final
- [ ] Tous les tests passent (40+)
- [ ] Coverage ≥95%
- [ ] `dart analyze` clean
- [ ] Benchmarks (sign <50ms, verify <30ms)
- [ ] Documentation complète

---

## 💾 Phase 3: Storage & Models (Jour 13-15)

### Jour 13: Storage Layer

- [ ] **[TODO]** Créer `lib/src/storage/storage_interface.dart`
  - [ ] Abstract class `Storage`
  - [ ] Méthodes: `write`, `read`, `delete`, `clear`, `containsKey`
- [ ] **[TODO]** Créer `lib/src/storage/storage_keys.dart`
  - [ ] Constantes pour clés
  - [ ] `kCurrentSpace`, `kSpacesList`, `kAuthToken`, etc.
- [ ] **[TODO]** Créer `lib/src/storage/secure_storage_impl.dart`
  - [ ] Class `SecureStorageImpl implements Storage`
  - [ ] Wrapper `FlutterSecureStorage`
  - [ ] Encryption des valeurs sensibles
- [ ] **[TODO]** Créer `lib/src/storage/preferences_storage.dart`
  - [ ] Class `PreferencesStorage implements Storage`
  - [ ] Wrapper `SharedPreferences`
  - [ ] Pour métadonnées non-sensibles
- [ ] **[TODO]** Créer `lib/src/storage/memory_storage.dart`
  - [ ] Class `MemoryStorage implements Storage`
  - [ ] Pour tests uniquement
- [ ] **[TODO]** Tests Storage (10 tests)
  - [ ] Test write/read/delete
  - [ ] Test persistance (si possible)
  - [ ] Test isolation entre instances

**Estimation Jour 13**: 6h de dev + 2h de tests

### Jour 14-15: Models

#### Core Models

- [ ] **[TODO]** Créer `lib/src/models/space.dart`
  - [ ] Class `Space` avec `@JsonSerializable()`
  - [ ] Fields: `did`, `name`, `createdAt`, `account`
  - [ ] Methods: `fromJson`, `toJson`
- [ ] **[TODO]** Créer `lib/src/models/account.dart`
  - [ ] Class `Account` avec `@JsonSerializable()`
  - [ ] Fields: `email`, `did`, `plan`
  - [ ] Nested class `Plan` avec `wait()` method
- [ ] **[TODO]** Créer `lib/src/models/plan.dart`
  - [ ] Class `Plan`
  - [ ] Méthode `wait({Duration interval, Duration timeout})`
- [ ] **[TODO]** Créer `lib/src/models/upload_result.dart`
  - [ ] Class `UploadResult`
  - [ ] Fields: `cid`, `size`, `uploadedAt`
- [ ] **[TODO]** Créer `lib/src/models/storacha_file.dart`
  - [ ] Class `StorachaFile`
  - [ ] Fields: `path`, `content`, `mimeType`
- [ ] **[TODO]** Créer `lib/src/models/gateway_config.dart`
  - [ ] Class `GatewayConfig`
  - [ ] Fields: `url`, `did`

#### Code Generation

- [ ] **[TODO]** Exécuter `dart run build_runner build`
- [ ] **[TODO]** Vérifier fichiers `.g.dart` générés

#### Tests Models

- [ ] **[TODO]** Tests sérialisation (15 tests)
  - [ ] Test JSON round-trip pour chaque modèle
  - [ ] Test champs optionnels
  - [ ] Test valeurs null
  - [ ] Test égalité

**Estimation Jour 14-15**: 10h de dev + 3h de tests

### Phase 3 - Checklist Final
- [ ] Tous les tests passent (25+)
- [ ] Coverage ≥85%
- [ ] Code generation OK
- [ ] `dart analyze` clean

---

## 🌐 Phase 4: HTTP Transport (Jour 16-18)

### Jour 16: Base Transport

- [ ] **[TODO]** Créer `lib/src/transport/http_transport.dart`
  - [ ] Class `HttpTransport`
  - [ ] Field `Dio _dio`
  - [ ] Constructor avec configuration
  - [ ] Méthode `post(String path, {...})`
  - [ ] Méthode `get(String path, {...})`
  - [ ] Support `Uint8List` body
  - [ ] Support headers custom
- [ ] **[TODO]** Créer `lib/src/utils/constants.dart`
  - [ ] Constante `kStorachaApiUrl` = 'https://up.storacha.network'
  - [ ] Autres endpoints
- [ ] **[TODO]** Tests Transport (5 tests avec mocks)

**Estimation Jour 16**: 5h de dev + 2h de tests

### Jour 17: Interceptors

- [ ] **[TODO]** Créer `lib/src/transport/auth_interceptor.dart`
  - [ ] Class `AuthInterceptor extends Interceptor`
  - [ ] Injection UCAN token dans Authorization header
  - [ ] Format: `Bearer ${ucanJWT}`
- [ ] **[TODO]** Créer `lib/src/transport/retry_interceptor.dart`
  - [ ] Class `RetryInterceptor extends Interceptor`
  - [ ] Retry sur erreurs réseau (5xx, timeouts)
  - [ ] Exponential backoff (1s, 2s, 4s, 8s)
  - [ ] Max retries configurable (default 3)
- [ ] **[TODO]** Créer `lib/src/transport/logging_interceptor.dart`
  - [ ] Log requêtes/réponses (debug mode)
  - [ ] Masquer données sensibles
- [ ] **[TODO]** Tests Interceptors (10 tests)

**Estimation Jour 17**: 6h de dev + 2h de tests

### Jour 18: Error Handling

- [ ] **[TODO]** Créer `lib/src/exceptions/storacha_exception.dart`
  - [ ] Class `StorachaException implements Exception`
  - [ ] Field `message`, `code`, `details`
- [ ] **[TODO]** Créer exceptions spécifiques
  - [ ] `AuthException` - Erreurs authentification
  - [ ] `NetworkException` - Erreurs réseau
  - [ ] `UploadException` - Erreurs upload
  - [ ] `SpaceException` - Erreurs spaces
  - [ ] `CryptoException` - Erreurs crypto
  - [ ] `ValidationException` - Erreurs validation
- [ ] **[TODO]** Créer `lib/src/transport/response_interceptor.dart`
  - [ ] Conversion erreurs HTTP → exceptions custom
  - [ ] Parsing error body JSON
- [ ] **[TODO]** Tests Exceptions (5 tests)

**Estimation Jour 18**: 5h de dev + 2h de tests

### Phase 4 - Checklist Final
- [ ] Tous les tests passent (20+)
- [ ] Coverage ≥80%
- [ ] Retry fonctionne
- [ ] `dart analyze` clean

---

## 🔐 Phase 5: Auth Service (Jour 19-21)

### Implementation

- [ ] **[TODO]** Créer `lib/src/services/auth/auth_service.dart`
  - [ ] Abstract class `AuthService`
  - [ ] Méthode `Future<Account> login(String email)`
  - [ ] Méthode `Future<void> logout()`
  - [ ] Méthode `Future<Account?> getCurrentAccount()`
- [ ] **[TODO]** Créer `lib/src/services/auth/auth_service_impl.dart`
  - [ ] Class `AuthServiceImpl implements AuthService`
  - [ ] Inject `HttpTransport`, `Storage`
  - [ ] Login flow:
    1. POST `/auth/email` avec `{ "email": "..." }`
    2. Poll `/auth/session/{sessionId}` jusqu'à confirmation
    3. Récupérer account info + token
    4. Sauvegarder dans storage
  - [ ] Logout: clear storage
  - [ ] getCurrentAccount: read from storage
- [ ] **[TODO]** Créer `lib/src/services/auth/email_verifier.dart`
  - [ ] Class `EmailVerifier`
  - [ ] Méthode `poll(String sessionId, {timeout, interval})`
  - [ ] Polling avec backoff

### Tests

- [ ] **[TODO]** Tests unitaires Auth (10 tests)
  - [ ] Test login success
  - [ ] Test login timeout
  - [ ] Test logout
  - [ ] Test getCurrentAccount
  - [ ] Test polling retry
- [ ] **[TODO]** Integration test Auth (1 test)
  - [ ] Test login flow complet (avec mock email)

**Estimation Jour 19-21**: 12h de dev + 4h de tests

### Phase 5 - Checklist
- [ ] Tests passent (15+)
- [ ] Coverage ≥80%
- [ ] `dart analyze` clean

---

## 📦 Phase 6: Space Service (Jour 22-25)

### Implementation

- [ ] **[TODO]** Créer `lib/src/services/space/space_service.dart`
  - [ ] Abstract class `SpaceService`
  - [ ] `Future<Space> createSpace(String name, {Account? account, ...})`
  - [ ] `Future<List<Space>> listSpaces()`
  - [ ] `Future<Space?> getCurrentSpace()`
  - [ ] `Future<void> setCurrentSpace(String did)`
  - [ ] `Future<void> deleteSpace(String did)`
- [ ] **[TODO]** Créer `lib/src/services/space/space_service_impl.dart`
  - [ ] Class `SpaceServiceImpl implements SpaceService`
  - [ ] createSpace logic:
    1. Générer DID pour space (DIDKey.generate())
    2. Si account fourni, créer delegation
    3. POST `/space/create` avec delegation
    4. Sauvegarder space localement
    5. Si premier space, set as current
  - [ ] listSpaces: read from storage
  - [ ] getCurrentSpace: read from storage
  - [ ] setCurrentSpace: write to storage
- [ ] **[TODO]** Créer `lib/src/services/space/space_delegator.dart`
  - [ ] Fonction `createSpaceDelegation(Account account, DID spaceDID)`
  - [ ] Création UCAN avec capabilities:
    - `space/*` (full access)
    - `upload/*` (upload rights)
- [ ] **[TODO]** Créer `lib/src/services/space/space_manager.dart`
  - [ ] Gestion cache des spaces
  - [ ] Synchronisation local/remote

### Tests

- [ ] **[TODO]** Tests unitaires Space (15 tests)
  - [ ] Test createSpace sans account
  - [ ] Test createSpace avec account
  - [ ] Test createSpace avec gateway authorization
  - [ ] Test listSpaces
  - [ ] Test setCurrentSpace
  - [ ] Test deleteSpace
- [ ] **[TODO]** Integration tests Space (2 tests)
  - [ ] Test create + list + switch
  - [ ] Test multi-space workflow

**Estimation Jour 22-25**: 16h de dev + 5h de tests

### Phase 6 - Checklist
- [ ] Tests passent (20+)
- [ ] Coverage ≥80%
- [ ] `dart analyze` clean

---

## 📤 Phase 7: Upload Service (Jour 26-30)

### Jour 26-27: Single File Upload

- [ ] **[TODO]** Créer `lib/src/services/upload/upload_service.dart`
  - [ ] Abstract class `UploadService`
  - [ ] `Future<CID> uploadFile(Uint8List content, {filename, mimeType, onProgress})`
  - [ ] `Future<CID> uploadDirectory(List<StorachaFile> files, {onProgress})`
  - [ ] `Future<void> cancelUpload(String uploadId)`
- [ ] **[TODO]** Créer `lib/src/services/upload/upload_service_impl.dart`
  - [ ] uploadFile logic:
    1. Déterminer MIME type si non fourni
    2. Calculer hash du contenu (SHA-256)
    3. Créer CID du contenu
    4. Encoder en CAR format
    5. POST `/upload` avec CAR + metadata
    6. Parse response pour confirmer CID
- [ ] **[TODO]** Créer `lib/src/services/upload/cid_calculator.dart`
  - [ ] Fonction `calculateCID(Uint8List content) → Future<CID>`
  - [ ] Hash SHA-256
  - [ ] Créer Multihash
  - [ ] Créer CIDv1 avec codec raw
- [ ] **[TODO]** Tests Upload File (12 tests)
  - [ ] Test upload petit fichier (<1KB)
  - [ ] Test upload moyen fichier (1MB)
  - [ ] Test upload progress tracking
  - [ ] Test MIME type detection
  - [ ] Test erreurs réseau

**Estimation Jour 26-27**: 12h de dev + 3h de tests

### Jour 28-29: Directory Upload

- [ ] **[TODO]** Créer `lib/src/ipfs/unixfs/unixfs_directory.dart`
  - [ ] Class `UnixFSDirectory`
  - [ ] Méthode `addFile(String path, Uint8List content)`
  - [ ] Méthode `build() → List<Block>`
  - [ ] Structure hiérarchique
- [ ] **[TODO]** Implémenter uploadDirectory
  - [ ] Parser paths pour créer hiérarchie
  - [ ] Créer blocks UnixFS pour chaque fichier
  - [ ] Créer blocks UnixFS pour répertoires
  - [ ] Calculer CID root du directory
  - [ ] Encoder tous les blocks en CAR
  - [ ] Upload CAR
- [ ] **[TODO]** Tests Upload Directory (10 tests)
  - [ ] Test directory plat (pas de sous-dossiers)
  - [ ] Test directory avec sous-dossiers
  - [ ] Test paths avec `/`
  - [ ] Test fichiers vides
  - [ ] Test gros directory (100+ fichiers)

**Estimation Jour 28-29**: 14h de dev + 4h de tests

### Jour 30: Advanced Features

- [ ] **[TODO]** Créer `lib/src/services/upload/file_chunker.dart`
  - [ ] Class `FileChunker`
  - [ ] Méthode `chunk(Uint8List data, {chunkSize = 1MB})`
  - [ ] Stream de chunks
- [ ] **[TODO]** Créer `lib/src/services/upload/upload_queue.dart`
  - [ ] Class `UploadQueue`
  - [ ] Queue FIFO avec concurrency limit
  - [ ] Méthode `add(UploadTask task)`
  - [ ] Méthode `cancel(String taskId)`
- [ ] **[TODO]** Créer `lib/src/services/upload/progress_tracker.dart`
  - [ ] Class `ProgressTracker`
  - [ ] Agrégation de progress multi-fichiers
  - [ ] Stream de `UploadProgress`
- [ ] **[TODO]** Tests Advanced (8 tests)
  - [ ] Test chunking
  - [ ] Test queue concurrency
  - [ ] Test cancel upload
  - [ ] Test progress aggregation

**Estimation Jour 30**: 8h de dev + 3h de tests

### Phase 7 - Checklist
- [ ] Tests passent (30+)
- [ ] Coverage ≥80%
- [ ] Upload 100MB fonctionne
- [ ] `dart analyze` clean

---

## 🎨 Phase 8: Client Principal (Jour 31-32)

### Implementation

- [ ] **[TODO]** Créer `lib/src/client/client_config.dart`
  - [ ] Class `ClientConfig`
  - [ ] Fields de base: `apiUrl`, `timeout`, `retryCount`, `logLevel`
  - [ ] **Fields Signers**: 
    - [ ] `Signer? defaultSigner` - Signer par défaut
    - [ ] `Signer? accountSigner` - Signer pour opérations account
    - [ ] `Map<String, Signer>? spaceSigners` - Map spaceDID → Signer
  - [ ] Méthode `getSignerForSpace(String spaceDID) → Signer`
- [ ] **[TODO]** Créer `lib/src/client/storacha_client.dart`
  - [ ] Class `StorachaClient`
  - [ ] Factory `create([ClientConfig? config])`
  - [ ] Initialisation de tous les services
  - [ ] Méthodes publiques (proxies vers services):
    - [ ] `login(String email)`
    - [ ] `logout()`
    - [ ] `createSpace(String name, {Account? account, ...})`
    - [ ] `listSpaces()`
    - [ ] `setCurrentSpace(String did)`
    - [ ] `uploadFile(Uint8List content, {filename, onProgress})`
    - [ ] `uploadDirectory(List<StorachaFile> files, {onProgress})`
    - [ ] `getGatewayUrl(CID cid, {gateway})`
- [ ] **[TODO]** Créer `lib/src/services/gateway/gateway_service.dart`
  - [ ] Class `GatewayService`
  - [ ] Méthode `getGatewayUrl(CID cid, String gateway)`
  - [ ] Format: `https://{cid}.ipfs.{gateway}`
- [ ] **[TODO]** Créer `lib/storacha_dart.dart` (export principal)
  - [ ] Export `StorachaClient`
  - [ ] Export modèles publics
  - [ ] Export exceptions
  - [ ] Masquer `src/*` (private)

### Tests

- [ ] **[TODO]** Integration tests complets (15 tests)
  - [ ] Test flow complet: create → login → createSpace → upload
  - [ ] Test multi-space workflow
  - [ ] Test error handling à chaque étape
  - [ ] Test concurrent uploads
  - [ ] Test large file (100MB)
  - [ ] **Tests Signers Injectables**:
    - [ ] Test client avec signer externe (mock)
    - [ ] Test createSpace avec signer spécifique
    - [ ] Test multi-signers (différents espaces)
    - [ ] Test upload utilise le bon signer
    - [ ] Test fallback au signer par défaut

**Estimation Jour 31-32**: 10h de dev + 6h de tests

### Phase 8 - Checklist
- [ ] Tests integration passent (10+)
- [ ] API publique finalisée
- [ ] `dart analyze` clean

---

## 📝 Phase 9: Tests & Documentation (Jour 33-36)

### Jour 33: Tests Complémentaires

- [ ] **[TODO]** Augmenter coverage à 85%+
  - [ ] Identifier branches non testées
  - [ ] Ajouter tests edge cases
  - [ ] Tester error paths
- [ ] **[TODO]** Performance tests
  - [ ] Créer `test/performance/large_file_upload_test.dart`
  - [ ] Créer `test/performance/concurrent_uploads_test.dart`
  - [ ] Créer `test/performance/memory_usage_test.dart`
- [ ] **[TODO]** Exécuter `dart test --coverage=coverage`
- [ ] **[TODO]** Générer rapport coverage

**Estimation Jour 33**: 8h

### Jour 34: Benchmarks

- [ ] **[TODO]** Créer `benchmark/upload_benchmark.dart`
- [ ] **[TODO]** Créer `benchmark/crypto_benchmark.dart`
- [ ] **[TODO]** Créer `benchmark/serialization_benchmark.dart`
- [ ] **[TODO]** Exécuter benchmarks et documenter résultats
- [ ] **[TODO]** Optimiser bottlenecks si nécessaire

**Estimation Jour 34**: 6h

### Jour 35: Documentation

- [ ] **[TODO]** Finaliser README.md
  - [ ] Exemples complets
  - [ ] Troubleshooting section
  - [ ] FAQ
- [ ] **[TODO]** Créer docs/ARCHITECTURE.md
  - [ ] Diagrammes de séquence
  - [ ] Diagrammes de classes
  - [ ] Explication flows
- [ ] **[TODO]** Créer docs/API_REFERENCE.md
  - [ ] Documentation complète de l'API
- [ ] **[TODO]** Créer docs/MIGRATION_FROM_JS.md
  - [ ] Mapping API JS → Dart
  - [ ] Exemples côte à côte
- [ ] **[TODO]** Créer CONTRIBUTING.md
- [ ] **[TODO]** Créer SECURITY.md
- [ ] **[TODO]** Documenter toutes les API publiques (dartdoc)
  - [ ] Classes
  - [ ] Méthodes
  - [ ] Parameters
  - [ ] Examples dans doc comments

**Estimation Jour 35**: 8h

### Jour 36: Polish

- [ ] **[TODO]** `dart analyze --fatal-infos --fatal-warnings`
- [ ] **[TODO]** `dart format lib/ test/ -l 80`
- [ ] **[TODO]** Optimize imports
- [ ] **[TODO]** Remove unused code
- [ ] **[TODO]** Review TODOs dans code
- [ ] **[TODO]** Update CHANGELOG.md
- [ ] **[TODO]** Review pubspec.yaml (description, keywords, etc.)
- [ ] **[TODO]** Créer example app complète
  - [ ] Simple CLI example
  - [ ] Flutter app example (optional)

**Estimation Jour 36**: 6h

### Phase 9 - Checklist
- [ ] Coverage ≥85%
- [ ] `dart analyze` = 0 issues
- [ ] Documentation complète
- [ ] Examples fonctionnels

---

## 🚀 Phase 10: Publication (Jour 37)

### Pre-Publication

- [ ] **[TODO]** Review checklist complet
  - [ ] Tous les tests passent
  - [ ] Coverage ≥85%
  - [ ] `dart analyze` clean
  - [ ] Documentation complète
  - [ ] CHANGELOG à jour
  - [ ] LICENSE correct
  - [ ] README complet
  - [ ] Examples fonctionnels
- [ ] **[TODO]** `dart pub publish --dry-run`
  - [ ] Vérifier warnings
  - [ ] Corriger issues
- [ ] **[TODO]** Test installation en local
  - [ ] Créer projet test
  - [ ] Dépendre de path local
  - [ ] Vérifier tout fonctionne

### Publication

- [ ] **[TODO]** Tag version Git
  ```bash
  git tag -a v0.1.0 -m "Initial release"
  git push origin v0.1.0
  ```
- [ ] **[TODO]** `dart pub publish`
- [ ] **[TODO]** Vérifier sur pub.dev
  - [ ] Score pub.dev
  - [ ] Documentation générée
  - [ ] Example visible

### Post-Publication

- [ ] **[TODO]** Créer GitHub Release
- [ ] **[TODO]** Annoncer sur communautés Dart/Flutter
- [ ] **[TODO]** Tweet/post (si applicable)
- [ ] **[TODO]** Setup monitoring pub.dev stats
- [ ] **[TODO]** Préparer v0.2.0 roadmap

**Estimation Jour 37**: 4h

---

## 📊 Métriques de Succès

### Objectifs Finaux

- [ ] **Pub.dev Score**: ≥130/140
- [ ] **Code Coverage**: ≥85%
- [ ] **Dart Analyze**: 0 errors, 0 warnings
- [ ] **Documentation**: 100% API publique
- [ ] **Performance**:
  - [ ] Upload 10MB < 8s (WiFi 50Mbps)
  - [ ] Client.create() < 200ms
  - [ ] Generate Ed25519 key < 100ms
- [ ] **Tests**: 250+ tests passant

### Métriques Actuelles (Live Update)

```
Tests: 0/250+
Coverage: 0%
Dart Analyze: Non exécuté
Documentation: 20%
Pub Score: N/A
```

---

## 🔄 Suivi des Modifications

### 2025-10-11
- ✅ Création du projet
- ✅ Setup pubspec.yaml avec dépendances
- ✅ Configuration analysis_options.yaml
- ✅ README initial
- ✅ Documentation PLAN.md v2.0
- ✅ Documentation TODO.md (ce fichier)

---

## 📝 Notes & Décisions

### Choix Techniques

1. **Cryptographie**: Choix de `pointycastle` pour stabilité malgré performance moindre vs natives
2. **HTTP Client**: Choix de `dio` pour features avancées (interceptors, progress)
3. **Sérialisation**: Choix de `json_serializable` pour performance (génération compile-time)
4. **Tests**: Objectif 85% coverage (équilibre qualité/effort)

### Risques Identifiés

1. ⚠️ **Multiformat Dart**: Pas de packages matures → Implementation custom nécessaire
2. ⚠️ **CAR Format**: Complexité élevée, nécessite tests poussés
3. ⚠️ **UCAN Spec**: Spec en évolution, potentiel breaking changes
4. ⚠️ **API Storacha**: Documentation parfois incomplète

### Questions Ouvertes

- [ ] Stratégie de migration si UCAN spec change ?
- [ ] Support UnixFS v2 nécessaire ?
- [ ] Faut-il supporter dag-cbor en plus de raw ?
- [ ] Implémenter IPNS publish ?

---

**Prochaine Action**: Commencer Phase 0 - Créer CI/CD workflow

