# Problème de Format de Délégation - Diagnostic Complet

## 🔍 Diagnostic

Après analyse approfondie avec le client de référence JavaScript, nous avons identifié le problème : **notre client utilise encore l'ancien format JWT, alors que le serveur Storacha attend le nouveau format IPLD `ucanto/message@7.0.0`**.

## 📊 Comparaison

### Client de Référence JavaScript (✅ Fonctionne)

**Structure du message:**
```json
{
  "ucanto/message@7.0.0": {
    "execute": [
      {"/": "bafyreifcyrdau3tyttvv4me35ryh5nhl2tfli5wdk4hbjvihrcpvngntay"}
    ]
  }
}
```

**Contenu du CAR:**
- Root CID: `bafyreigq6sgskph5jo5ltvk2llug37hnj2epombde5wpas2vyjkm7b6una`
- 7 blocs IPLD:
  1. `bafyreianbkb3ijnaydmte2z7ets3c7muuavgiqdinnakyspkumwogdxqd4` (285 bytes) - Proof 1
  2. `bafyreihxd3uwyaaf42sbhho52i6gcrwvhl3ehy5vidopibmxlljkywk7lu` (288 bytes) - Proof 2
  3. `bafyreibm5yw5rdorviimeppchjqu73xenvpaz5u7ybspzdcqgjyx44xlj4` (326 bytes) - Proof 3
  4. `bafyreiemi2byyz2gwplm2tgtlc3xaf5h65kifckah2razhaqgvffvi353u` (387 bytes) - Proof 4
  5. `bafyreigusu3mq3cwzij26jjjlkrxeslp7rmrnlwav42cmlaqsm6ooskphm` (547 bytes) - **UCAN principal**
  6. `bafyreifcyrdau3tyttvv4me35ryh5nhl2tfli5wdk4hbjvihrcpvngntay` (353 bytes) - **Invocation**
  7. `bafyreigq6sgskph5jo5ltvk2llug37hnj2epombde5wpas2vyjkm7b6una` (73 bytes) - **Message root**
- **Taille totale: 2583 bytes**

**Hiérarchie:**
```
Message (root)
  └─> execute[0] -> Invocation CID
        └─> proofs[0] -> Delegation CID
              └─> 5 blocs UCAN (proof chain)
```

### Notre Client Dart (❌ Ne fonctionne pas)

**Structure du message:**
```json
"eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJ2IjoiMC45LjEiLC..."
```
^ C'est un **JWT string**, pas un objet IPLD !

**Contenu du CAR:**
- Root CID: `bafkreib5bypgbcuknpdpgi275zeavyleyt4sertuhv22fzu2hh3ox3fwfi`
- 1 bloc:
  1. `bafkreib5bypgbcuknpdpgi275zeavyleyt4sertuhv22fzu2hh3ox3fwfi` (641 bytes) - **JWT string en CBOR**
- **Taille totale: 735 bytes**

**Le problème:** Le serveur reçoit un JWT string au lieu d'une structure IPLD, d'où l'erreur 500.

## 🔧 Solution Requise

### 1. Supprimer le format JWT

**Fichiers à modifier:**
- `lib/src/ucan/invocation.dart` - Supprimer la méthode `sign()` qui génère des JWT
- `lib/src/ucan/invocation_encoder.dart` - Remplacer `encodeInvocationToCar()` 

### 2. Implémenter le format IPLD

**Nouvelle structure nécessaire:**

```dart
// 1. Invocation en DAG-CBOR (pas JWT)
class UCANInvocation {
  final String issuer;      // DID bytes (multicodec)
  final String audience;    // DID bytes (multicodec)
  final List<Capability> capabilities;
  final List<CID> proofs;   // CIDs des délégations
  final int? expiration;
  final String? nonce;
  
  // Encoder en DAG-CBOR
  Uint8List toDAGCBOR() {
    return encodeDagCbor({
      'iss': parseDid(issuer),    // Bytes avec multicodec
      'aud': parseDid(audience),  // Bytes avec multicodec
      'att': capabilities.map((c) => c.toJson()).toList(),
      if (proofs.isNotEmpty) 'prf': proofs.map((p) => p.toBytes()).toList(),
      if (expiration != null) 'exp': expiration,
      if (nonce != null) 'nnc': nonce,
      's': signature,  // Signature Ed25519 des bytes
    });
  }
  
  // Calculer le CID de cette invocation
  CID get cid => CID.createV1(dagCborCode, sha256Hash(toDAGCBOR()));
}

// 2. Message IPLD
class UCNTOMessage {
  final List<UCANInvocation> invocations;
  
  Map<String, dynamic> toIPLD() {
    return {
      'ucanto/message@7.0.0': {
        'execute': invocations.map((inv) => {'/': inv.cid.toString()}).toList(),
      }
    };
  }
  
  // Collecter tous les blocs IPLD
  List<CARBlock> collectBlocks() {
    final blocks = <CARBlock>[];
    
    // Ajouter les blocs d'invocation
    for (final inv in invocations) {
      blocks.add(CARBlock(cid: inv.cid, bytes: inv.toDAGCBOR()));
      
      // Ajouter les blocs des proofs
      for (final proof in inv.proofArchives) {
        final carResult = readCar(proof);
        blocks.addAll(carResult.blocks);
      }
    }
    
    // Ajouter le bloc root (message)
    final rootBytes = encodeDagCbor(toIPLD());
    final rootCid = CID.createV1(dagCborCode, sha256Hash(rootBytes));
    blocks.add(CARBlock(cid: rootCid, bytes: rootBytes));
    
    return blocks;
  }
}
```

### 3. Nouvelle séquence d'encodage

```dart
// Ancienne méthode (JWT) - À SUPPRIMER
final jwt = await builder.sign();
final carBytes = encodeInvocationToCar(jwt);

// Nouvelle méthode (IPLD)
final invocation = await builder.buildIPLDInvocation();
final message = UCNTOMessage(invocations: [invocation]);
final blocks = message.collectBlocks();
final carBytes = encodeCar(
  roots: [message.rootCid],
  blocks: blocks,
);
```

## 📝 Références

**Code de référence JavaScript:**
- `@ucanto/core/src/message.js` - Construction du message IPLD
- `@ucanto/core/src/invocation.js` - Invocation builder
- `@ucanto/core/src/delegation.js` - `exportDAG()` pour les blocs

**Encodage DAG-CBOR:**
- DIDs encodés en bytes avec préfixe multicodec (0xed pour Ed25519, 0x0d1d pour DID Core)
- CIDs encodés comme objets CBOR tag 42
- Structure conforme à `@ipld/dag-ucan`

## 🎯 Prochaines Étapes

1. ✅ Diagnostic complet (FAIT)
2. ⏳ Implémenter `encodeDagCbor()` avec support CID et DIDs
3. ⏳ Refactoriser `InvocationBuilder` pour générer DAG-CBOR au lieu de JWT
4. ⏳ Implémenter `UCNTOMessage` avec structure `ucanto/message@7.0.0`
5. ⏳ Mettre à jour le transport pour utiliser le nouveau format
6. ⏳ Tester avec le serveur Storacha

## 📊 Impact

**Fichiers à modifier:**
- `lib/src/ucan/invocation.dart` (refactorisation majeure)
- `lib/src/ucan/invocation_encoder.dart` (nouveau format)
- `lib/src/core/encoding.dart` (ajouter encodeDagCbor avec CID/DID)
- `lib/src/transport/storacha_transport.dart` (utiliser nouveau builder)
- Tests à mettre à jour

**Estimation:** Refactorisation majeure, ~2-4h de travail

