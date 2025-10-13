# Plan d'Implémentation : Délégations UCAN

## 🎯 Objectif

Implémenter le support complet des délégations UCAN pour permettre l'utilisation du package avec le vrai réseau Storacha.

**Timeline Estimée** : 7-11 jours  
**Priorité** : Haute  
**Version Cible** : v0.2.0

---

## 📊 État Actuel vs. Requis

### ✅ Actuellement Implémenté

```dart
// Ce qui fonctionne
final signer = await Ed25519Signer.generate();
final space = await client.createSpace('Local Space');
final cid = await client.uploadFile(file);
// ❌ Mais échoue avec 406 sur Storacha
```

### 🎯 Ce Qui Doit Fonctionner

```dart
// Workflow complet avec délégations
final signer = await Ed25519Signer.fromPrivateKey(privateKey);
final delegation = await Delegation.load('proof.ucan');  // ← À implémenter

final client = StorachaClient(
  config,
  delegations: [delegation],  // ← À implémenter
);

// Utilise le space délégué
await client.setCurrentSpace(delegation.spaceDid);
final cid = await client.uploadFile(file);  // ✅ Fonctionne !
```

---

## 🏗️ Architecture

### Nouveaux Composants

```
lib/src/ucan/
  ├── delegation.dart         ← NOUVEAU
  ├── delegation_parser.dart  ← NOUVEAU
  ├── proof.dart             ← NOUVEAU
  ├── proof_chain.dart       ← NOUVEAU
  └── ucan.dart              ← À ÉTENDRE

lib/src/client/
  └── storacha_client.dart   ← À MODIFIER (ajout delegations)

lib/src/transport/
  └── storacha_transport.dart ← À MODIFIER (include proofs)
```

---

## 📋 Phase 1 : Types de Base (1-2 jours)

### 1.1 Modèle `Delegation`

**Fichier** : `lib/src/ucan/delegation.dart`

```dart
/// Represents a UCAN delegation
@immutable
class Delegation {
  const Delegation({
    required this.issuer,
    required this.audience,
    required this.capabilities,
    required this.proofs,
    required this.expiration,
    this.notBefore,
    this.nonce,
    this.facts,
  });

  /// Issuer DID (who is delegating)
  final DID issuer;

  /// Audience DID (who receives the delegation)
  final DID audience;

  /// Capabilities being delegated
  final List<Capability> capabilities;

  /// Proof UCANs (delegation chain)
  final List<UCAN> proofs;

  /// Expiration timestamp
  final int expiration;

  /// Optional: not valid before
  final int? notBefore;

  /// Optional: nonce for uniqueness
  final String? nonce;

  /// Optional: additional facts
  final Map<String, dynamic>? facts;

  /// Load delegation from UCAN file
  static Future<Delegation> load(String path) async {
    final bytes = await File(path).readAsBytes();
    return Delegation.parse(bytes);
  }

  /// Parse delegation from bytes
  static Delegation parse(Uint8List bytes) {
    // TODO: Parse CAR file containing UCAN
    throw UnimplementedError();
  }

  /// Load delegation from base64 string
  static Delegation fromBase64(String base64) {
    final bytes = base64Decode(base64);
    return Delegation.parse(bytes);
  }

  /// Convert to UCAN
  UCAN toUCAN() {
    return UCAN(
      header: UCANHeader(
        alg: 'EdDSA',
        typ: 'JWT',
      ),
      payload: UCANPayload(
        iss: issuer.did(),
        aud: audience.did(),
        att: capabilities,
        exp: expiration,
        nbf: notBefore,
        nnc: nonce,
        fct: facts,
        prf: proofs.map((p) => p.toString()).toList(),
      ),
    );
  }

  /// Get the space DID from capabilities
  String? get spaceDid {
    for (final cap in capabilities) {
      if (cap.with_.startsWith('did:key:')) {
        return cap.with_;
      }
    }
    return null;
  }
}
```

**Tests** : `test/unit/ucan/delegation_test.dart`
- ✅ Parse UCAN from file
- ✅ Parse UCAN from base64
- ✅ Extract capabilities
- ✅ Extract space DID
- ✅ Convert to UCAN

---

### 1.2 Modèle `Proof`

**Fichier** : `lib/src/ucan/proof.dart`

```dart
/// Represents a UCAN proof
@immutable
class Proof {
  const Proof({
    required this.cid,
    required this.ucan,
  });

  /// CID of the proof UCAN
  final CID cid;

  /// The UCAN itself
  final UCAN ucan;

  /// Parse proof from JWT string
  static Future<Proof> fromJWT(String jwt) async {
    final ucan = await UCAN.parse(jwt);
    
    // Calculate CID of the JWT
    final jwtBytes = utf8.encode(jwt);
    final digest = sha256Hash(jwtBytes);
    final cid = CID.createV1(rawCode, digest);
    
    return Proof(cid: cid, ucan: ucan);
  }

  /// Encode proof to CAR block
  CARBlock toCARBlock() {
    final jwtString = ucan.encode();
    final jwtBytes = utf8.encode(jwtString);
    
    return CARBlock(
      cid: cid,
      bytes: jwtBytes,
    );
  }
}
```

**Tests** : `test/unit/ucan/proof_test.dart`
- ✅ Create from JWT
- ✅ Calculate CID
- ✅ Convert to CAR block

---

### 1.3 Chaîne de Preuves

**Fichier** : `lib/src/ucan/proof_chain.dart`

```dart
/// Manages a chain of UCAN proofs
class ProofChain {
  ProofChain(this.proofs);

  final List<Proof> proofs;

  /// Add a proof to the chain
  void add(Proof proof) {
    proofs.add(proof);
  }

  /// Get all proof CIDs
  List<CID> getCIDs() {
    return proofs.map((p) => p.cid).toList();
  }

  /// Get all proof UCANs
  List<UCAN> getUCANs() {
    return proofs.map((p) => p.ucan).toList();
  }

  /// Validate the proof chain
  bool validate({
    required DID issuer,
    required DID audience,
  }) {
    // Validate each proof in the chain
    for (final proof in proofs) {
      if (!proof.ucan.verify()) {
        return false;
      }
    }

    // Validate delegation chain
    // The chain should connect issuer → ... → audience
    // TODO: Implement chain validation logic
    
    return true;
  }

  /// Convert to CAR blocks
  List<CARBlock> toCARBlocks() {
    return proofs.map((p) => p.toCARBlock()).toList();
  }
}
```

**Tests** : `test/unit/ucan/proof_chain_test.dart`
- ✅ Add proofs
- ✅ Get CIDs
- ✅ Get UCANs
- ✅ Validate chain
- ✅ Convert to CAR blocks

---

## 📋 Phase 2 : Parsing UCAN (2-3 jours)

### 2.1 Parser CAR avec UCANs

**Fichier** : `lib/src/ipfs/car/car_decoder.dart` (NOUVEAU)

```dart
/// Decodes CAR (Content Addressable aRchive) files
class CARDecoder {
  /// Decode a CAR file from bytes
  static CARFile decode(Uint8List bytes) {
    var offset = 0;

    // 1. Read header length (varint)
    final headerLengthResult = varint.decode(bytes, offset);
    final headerLength = headerLengthResult.value;
    offset = headerLengthResult.offset;

    // 2. Read header (CBOR)
    final headerBytes = bytes.sublist(offset, offset + headerLength);
    final header = _decodeCBORHeader(headerBytes);
    offset += headerLength;

    // 3. Read blocks
    final blocks = <CARBlock>[];
    while (offset < bytes.length) {
      // Block length
      final lengthResult = varint.decode(bytes, offset);
      final blockLength = lengthResult.value;
      offset = lengthResult.offset;

      // Block data
      final blockData = bytes.sublist(offset, offset + blockLength);
      offset += blockLength;

      // Parse CID and bytes
      final cidResult = CID.decodeFirst(blockData);
      final cid = cidResult.cid;
      final dataOffset = cidResult.offset;
      final data = blockData.sublist(dataOffset);

      blocks.add(CARBlock(cid: cid, bytes: data));
    }

    return CARFile(header: header, blocks: blocks);
  }

  static CARHeader _decodeCBORHeader(Uint8List bytes) {
    // Simple CBOR decoder for CAR header
    // Format: {version: 1, roots: [CID, ...]}
    
    // TODO: Implement CBOR decoder
    throw UnimplementedError('CBOR decoder');
  }
}

/// Represents a decoded CAR file
class CARFile {
  const CARFile({
    required this.header,
    required this.blocks,
  });

  final CARHeader header;
  final List<CARBlock> blocks;

  /// Find block by CID
  CARBlock? findBlock(CID cid) {
    return blocks.firstWhere(
      (b) => b.cid == cid,
      orElse: () => throw StateError('Block not found: $cid'),
    );
  }

  /// Get root block
  CARBlock get root {
    if (header.roots.isEmpty) {
      throw StateError('No root CID in CAR header');
    }
    return findBlock(header.roots.first);
  }
}
```

**Tests** : `test/unit/ipfs/car_decoder_test.dart`
- ✅ Decode simple CAR
- ✅ Decode CAR with multiple blocks
- ✅ Find block by CID
- ✅ Get root block
- ✅ Handle invalid CAR

---

### 2.2 Parser JWT UCAN

**Fichier** : `lib/src/ucan/delegation_parser.dart`

```dart
/// Parses UCAN delegations from various formats
class DelegationParser {
  /// Parse delegation from CAR file
  static Delegation fromCAR(Uint8List carBytes) {
    final car = CARDecoder.decode(carBytes);
    
    // Root block contains the delegation JWT
    final rootBlock = car.root;
    final jwt = utf8.decode(rootBlock.bytes);
    
    // Parse JWT to UCAN
    final ucan = UCAN.parse(jwt);
    
    // Extract proofs from other blocks
    final proofs = <UCAN>[];
    for (final block in car.blocks) {
      if (block.cid != car.root.cid) {
        final proofJwt = utf8.decode(block.bytes);
        proofs.add(UCAN.parse(proofJwt));
      }
    }
    
    return Delegation(
      issuer: DIDKey(ucan.payload.iss),
      audience: DIDKey(ucan.payload.aud),
      capabilities: ucan.payload.att,
      proofs: proofs,
      expiration: ucan.payload.exp,
      notBefore: ucan.payload.nbf,
      nonce: ucan.payload.nnc,
      facts: ucan.payload.fct,
    );
  }

  /// Parse delegation from JWT string
  static Delegation fromJWT(String jwt) {
    final ucan = UCAN.parse(jwt);
    
    return Delegation(
      issuer: DIDKey(ucan.payload.iss),
      audience: DIDKey(ucan.payload.aud),
      capabilities: ucan.payload.att,
      proofs: [], // No embedded proofs in single JWT
      expiration: ucan.payload.exp,
      notBefore: ucan.payload.nbf,
      nonce: ucan.payload.nnc,
      facts: ucan.payload.fct,
    );
  }

  /// Parse delegation from file
  static Future<Delegation> fromFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    
    // Try to parse as CAR first
    try {
      return fromCAR(bytes);
    } catch (e) {
      // Try as JWT
      final content = await file.readAsString();
      return fromJWT(content.trim());
    }
  }
}
```

**Tests** : `test/unit/ucan/delegation_parser_test.dart`
- ✅ Parse from CAR file
- ✅ Parse from JWT string
- ✅ Parse from file (.ucan)
- ✅ Parse from file (.jwt)
- ✅ Handle invalid formats

---

## 📋 Phase 3 : Intégration Client (1-2 jours)

### 3.1 Modifier `StorachaClient`

**Fichier** : `lib/src/client/storacha_client.dart`

```dart
class StorachaClient {
  StorachaClient(
    ClientConfig config, {
    StorachaTransport? transport,
    List<Delegation>? delegations,  // ← NOUVEAU
  })  : _config = config,
        _http = Dio(...),
        _transport = transport ?? StorachaTransport(),
        _delegations = delegations ?? [];  // ← NOUVEAU

  final List<Delegation> _delegations;  // ← NOUVEAU

  /// Add a delegation
  void addDelegation(Delegation delegation) {
    _delegations.add(delegation);
    
    // Auto-add space from delegation if available
    final spaceDid = delegation.spaceDid;
    if (spaceDid != null) {
      // Create space object from delegation
      final space = Space(
        did: spaceDid,
        name: 'Delegated Space',
        signer: _config.principal,  // Use principal as signer
        createdAt: DateTime.now(),
      );
      
      // Add to spaces if not already present
      if (!_spaces.any((s) => s.did == spaceDid)) {
        _spaces.add(space);
        _currentSpace ??= space;
      }
    }
  }

  /// Load delegation from file
  Future<void> loadDelegation(String path) async {
    final delegation = await DelegationParser.fromFile(path);
    addDelegation(delegation);
  }

  /// Get all delegations
  List<Delegation> get delegations => List.unmodifiable(_delegations);

  // ... reste du code
}
```

**Tests** : `test/unit/client/storacha_client_delegation_test.dart`
- ✅ Add delegation
- ✅ Load delegation from file
- ✅ Auto-add space from delegation
- ✅ Use delegated space for upload

---

### 3.2 Modifier `InvocationBuilder`

**Fichier** : `lib/src/ucan/invocation.dart`

```dart
class InvocationBuilder {
  InvocationBuilder({
    required this.signer,
    this.audience,
    this.expiration,
    this.nonce,
    this.proofs = const [],  // ← NOUVEAU
  });

  final Signer signer;
  String? audience;
  int? expiration;
  String? nonce;
  List<UCAN> proofs;  // ← NOUVEAU
  
  final List<Capability> _capabilities = [];
  final List<Map<String, dynamic>> _facts = [];

  /// Add a proof UCAN
  InvocationBuilder addProof(UCAN proof) {  // ← NOUVEAU
    proofs.add(proof);
    return this;
  }

  /// Add multiple proofs
  InvocationBuilder addProofs(List<UCAN> proofList) {  // ← NOUVEAU
    proofs.addAll(proofList);
    return this;
  }

  /// Build the invocation
  UcanInvocation build() {
    if (_capabilities.isEmpty) {
      throw StateError('At least one capability is required');
    }

    final now = DateTime.now();
    final exp = expiration ?? now.add(const Duration(minutes: 5));

    return UcanInvocation(
      issuer: signer.did().did(),
      audience: audience ?? defaultAudience,
      capabilities: List.unmodifiable(_capabilities),
      expiration: exp.millisecondsSinceEpoch ~/ 1000,
      nonce: nonce,
      facts: _facts.isEmpty ? null : List.unmodifiable(_facts),
      proofs: proofs.map((p) => p.encode()).toList(),  // ← NOUVEAU
    );
  }

  // ... reste du code
}
```

**Tests** : `test/unit/ucan/invocation_builder_delegation_test.dart`
- ✅ Add single proof
- ✅ Add multiple proofs
- ✅ Build invocation with proofs
- ✅ Proofs included in JWT

---

### 3.3 Modifier `StorachaTransport`

**Fichier** : `lib/src/transport/storacha_transport.dart`

```dart
class StorachaTransport {
  // ... code existant

  Future<BlobAllocation> invokeBlobAdd({
    required DID spaceDid,
    required BlobDescriptor blob,
    required InvocationBuilder builder,
    List<Delegation>? delegations,  // ← NOUVEAU
  }) async {
    // Add proofs from delegations
    if (delegations != null) {  // ← NOUVEAU
      for (final delegation in delegations) {
        final delegationUCAN = delegation.toUCAN();
        builder.addProof(delegationUCAN);
        
        // Also add proofs from the delegation itself
        builder.addProofs(delegation.proofs);
      }
    }

    builder.addCapability(
      Capability(
        with_: spaceDid.did(),
        can: 'space/blob/add',
        nb: blob.toJson(),
      ),
    );

    final response = await invokeCapability(builder);
    return BlobAllocation.fromJson(response);
  }

  // Similar changes for invokeUploadAdd
  // ...
}
```

---

## 📋 Phase 4 : Encoder Invocations avec Preuves (1-2 jours)

### 4.1 Modifier `InvocationEncoder`

**Fichier** : `lib/src/ucan/invocation_encoder.dart`

```dart
/// Encodes invocations with proofs into CAR format
Uint8List encodeInvocationWithProofs({
  required String jwt,
  required List<UCAN> proofs,
}) {
  // 1. Encode main JWT as CBOR
  final jwtCborBytes = encodeCbor(jwt);
  final jwtDigest = sha256Hash(jwtCborBytes);
  final jwtCid = CID.createV1(rawCode, jwtDigest);
  final jwtBlock = CARBlock(cid: jwtCid, bytes: jwtCborBytes);

  // 2. Encode each proof as CBOR
  final proofBlocks = <CARBlock>[];
  for (final proof in proofs) {
    final proofJwt = proof.encode();
    final proofCborBytes = encodeCbor(proofJwt);
    final proofDigest = sha256Hash(proofCborBytes);
    final proofCid = CID.createV1(rawCode, proofDigest);
    
    proofBlocks.add(CARBlock(
      cid: proofCid,
      bytes: proofCborBytes,
    ));
  }

  // 3. Combine into CAR with JWT as root
  final allBlocks = [jwtBlock, ...proofBlocks];
  
  return encodeCar(
    roots: [jwtCid],
    blocks: allBlocks,
  );
}
```

**Tests** : `test/unit/ucan/invocation_encoder_proofs_test.dart`
- ✅ Encode with single proof
- ✅ Encode with multiple proofs
- ✅ Verify CAR structure
- ✅ Verify root CID
- ✅ Decode and validate

---

## 📋 Phase 5 : Tests E2E (1 jour)

### 5.1 Setup avec Storacha CLI

**Script** : `storacha_test_app/scripts/setup_delegation.sh`

```bash
#!/bin/bash

# Setup delegation for E2E tests

echo "🔧 Storacha Delegation Setup"
echo ""

# 1. Check if w3 CLI is installed
if ! command -v w3 &> /dev/null; then
    echo "❌ Storacha CLI not found"
    echo "Install with: npm install -g @storacha/cli"
    exit 1
fi

# 2. Login (if not already)
echo "📧 Login to Storacha..."
w3 whoami || w3 login

# 3. Create or select space
echo ""
echo "📦 Creating test space..."
w3 space create "storacha-dart-e2e-test" || true

# 4. Get space DID
SPACE_DID=$(w3 space ls | grep "storacha-dart-e2e-test" | awk '{print $1}')
echo "Space DID: $SPACE_DID"

# 5. Get agent DID from env.local
AGENT_DID=$(grep "Client DID" ../logs/last_test.log | awk '{print $3}')
echo "Agent DID: $AGENT_DID"

# 6. Create delegation
echo ""
echo "🎫 Creating delegation..."
w3 delegation create \
  --can space/blob/add \
  --can upload/add \
  --audience "$AGENT_DID" \
  > delegation.ucan

echo ""
echo "✅ Delegation created: delegation.ucan"
echo ""
echo "Next steps:"
echo "1. Add to .env.local:"
echo "   STORACHA_DELEGATION_FILE=scripts/delegation.ucan"
echo "2. Run tests: dart test"
```

---

### 5.2 Tests E2E avec Délégation

**Fichier** : `storacha_test_app/test/e2e_with_delegation_test.dart`

```dart
void main() {
  final env = DotEnv()..load(['.env.local']);
  
  final delegationFile = env['STORACHA_DELEGATION_FILE'];
  if (delegationFile == null) {
    print('⚠️  No delegation file configured');
    print('Run: ./scripts/setup_delegation.sh');
    return;
  }

  group('E2E with Delegation', () {
    late StorachaClient client;

    setUpAll(() async {
      // Load signer
      final privateKey = base64Decode(env['STORACHA_PRIVATE_KEY']!);
      final signer = await Ed25519Signer.import(privateKey);

      // Load delegation
      final delegation = await DelegationParser.fromFile(delegationFile);

      // Create client with delegation
      final config = ClientConfig(
        principal: signer,
        endpoints: StorachaEndpoints.production,
      );
      client = StorachaClient(
        config,
        delegations: [delegation],
      );

      print('✅ Client initialized with delegation');
      print('   Space DID: ${delegation.spaceDid}');
    });

    test('uploads file with delegation', () async {
      final file = MemoryFile(
        name: 'test.txt',
        bytes: Uint8List.fromList(utf8.encode('Hello with delegation!')),
      );

      // ✅ Should succeed now!
      final cid = await client.uploadFile(file);

      expect(cid, isNotNull);
      print('✅ Uploaded! CID: $cid');

      // Verify via gateway
      final response = await http.get(
        Uri.parse('https://w3s.link/ipfs/$cid'),
      );
      expect(response.statusCode, equals(200));
      expect(response.body, equals('Hello with delegation!'));
    });
  });
}
```

---

## 📋 Phase 6 : Documentation (1 jour)

### 6.1 Guide Utilisateur

**Fichier** : `storacha_dart/docs/DELEGATION_GUIDE.md`

Contenu :
- Pourquoi les délégations sont nécessaires
- Comment obtenir une délégation (CLI)
- Comment charger une délégation (code)
- Exemples complets
- Troubleshooting

### 6.2 Mise à Jour README

Ajouter section :
```markdown
## 🎫 Using with Storacha Network

To upload to Storacha, you need a delegation...
```

---

## 📅 Timeline Détaillée

| Phase | Tâches | Durée | Dépendances |
|-------|--------|-------|-------------|
| **Phase 1** | Types de base | 1-2 jours | - |
| **Phase 2** | Parsing UCAN | 2-3 jours | Phase 1 |
| **Phase 3** | Intégration client | 1-2 jours | Phase 1, 2 |
| **Phase 4** | Encoder invocations | 1-2 jours | Phase 3 |
| **Phase 5** | Tests E2E | 1 jour | Phase 4 |
| **Phase 6** | Documentation | 1 jour | Phase 5 |
| **Total** | | **7-11 jours** | |

---

## ✅ Checklist d'Implémentation

### Phase 1 : Types de Base
- [ ] `Delegation` class
- [ ] `Proof` class
- [ ] `ProofChain` class
- [ ] Tests unitaires (30 tests)

### Phase 2 : Parsing
- [ ] `CARDecoder` class
- [ ] `DelegationParser` class
- [ ] CBOR decoder basique
- [ ] Tests unitaires (25 tests)

### Phase 3 : Intégration
- [ ] Modifier `StorachaClient`
- [ ] Modifier `InvocationBuilder`
- [ ] Modifier `StorachaTransport`
- [ ] Tests unitaires (20 tests)

### Phase 4 : Encoding
- [ ] Modifier `InvocationEncoder`
- [ ] Support multi-blocks CAR
- [ ] Tests unitaires (15 tests)

### Phase 5 : Tests E2E
- [ ] Script setup délégation
- [ ] Tests E2E réels
- [ ] Validation complète (10 tests)

### Phase 6 : Documentation
- [ ] Guide délégations
- [ ] Mise à jour README
- [ ] Exemples code
- [ ] Troubleshooting guide

---

## 🎯 Critères de Succès

### Fonctionnel
- ✅ Upload vers vrai Storacha fonctionne
- ✅ Délégations chargées depuis fichier
- ✅ Preuves incluses dans invocations
- ✅ Validation complète E2E

### Qualité
- ✅ 100 nouveaux tests unitaires
- ✅ 10 tests E2E
- ✅ 0 erreurs `dart analyze`
- ✅ Documentation complète

### Performance
- ✅ Parsing délégation < 10ms
- ✅ Overhead < 5% sur upload
- ✅ Memory footprint raisonnable

---

## 🚀 Quick Start (après implémentation)

```bash
# 1. Obtenir délégation
npm install -g @storacha/cli
w3 login
w3 space create my-app
w3 delegation create --can space/blob/add --audience did:key:z6Mk... > proof.ucan

# 2. Utiliser dans le code
final client = StorachaClient(config);
await client.loadDelegation('proof.ucan');
final cid = await client.uploadFile(file);  // ✅ Fonctionne!
```

---

## 📚 Ressources Nécessaires

### Documentation
- [UCAN Spec](https://github.com/ucan-wg/spec)
- [Storacha Docs](https://storacha.network/docs)
- [W3 Protocol](https://github.com/web3-storage/w3protocol)
- [CAR Format](https://ipld.io/specs/transport/car/)

### Outils
- Storacha CLI (`@storacha/cli`)
- IPFS Desktop (pour tests)
- Postman (pour debug API)

### Dépendances Dart
- Aucune nouvelle dépendance requise
- Tout peut être fait avec les packages existants

---

## 💡 Notes d'Implémentation

### Complexité CBOR
Le décodage CBOR peut être simplifié :
- Utiliser `package:cbor` si disponible
- Sinon, implémenter uniquement les types nécessaires pour CAR headers

### Validation des Chaînes
La validation complète des chaînes de délégation est complexe :
- Phase 1 : Validation basique (signatures valides)
- Phase 2 : Validation de la chaîne (issuer → audience)
- Phase 3 : Validation des capabilities (atténuation)

### Performance
Optimisations possibles :
- Cache des délégations parsées
- Pool de signatures Ed25519
- Stream processing pour gros fichiers

---

## 🎉 Après l'Implémentation

Le package sera **100% production-ready** pour Storacha :
- ✅ Upload vers réseau réel
- ✅ Gestion complète des délégations
- ✅ Support multi-spaces
- ✅ Tests E2E complets
- ✅ Documentation exhaustive

**Version** : v0.2.0  
**Status** : Production Ready pour Storacha 🚀

