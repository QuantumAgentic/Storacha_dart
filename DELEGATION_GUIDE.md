# Guide Complet des Délégations UCAN

Ce guide explique comment utiliser les délégations UCAN avec `storacha_dart` pour uploader vers Storacha Network.

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Formats supportés](#formats-supportés)
3. [Création de délégations avec Storacha CLI](#création-de-délégations)
4. [Utilisation en Dart](#utilisation-en-dart)
5. [Tests et Validation](#tests-et-validation)
6. [Troubleshooting](#troubleshooting)

## Vue d'ensemble

Les **délégations UCAN** permettent à un propriétaire de space (issuer) de déléguer certaines capacités à un agent (audience). C'est essentiel pour permettre à vos applications d'uploader vers Storacha sans avoir besoin de la clé privée du propriétaire.

### Processus complet

```
1. Créer un space sur Storacha ──────────┐
2. Générer un agent pour votre app      │
3. Créer une délégation (CLI)           │
4. Charger la délégation (Dart)         │
5. Uploader avec la délégation ─────────┘
```

## Formats supportés

Le package supporte **trois formats** de délégation :

### 1. JWT (JSON Web Token)
```
eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJpc3MiOi...
```
**Usage** : Format simple, utile pour les délégations basiques

### 2. CAR Binaire (Recommandé)
```bash
storacha delegation create <did> -c <cap> -o delegation.car
```
**Usage** : Format le plus efficace, recommandé pour la production

### 3. Identity CID Base64
```bash
storacha delegation create <did> -c <cap> --base64 > delegation.txt
```
**Usage** : Utile pour les variables d'environnement ou fichiers texte

## Création de délégations

### Étape 1 : Installation du CLI Storacha

```bash
npm install -g @storacha/cli
```

### Étape 2 : Login et création de space

```bash
# Se connecter
storacha login your@email.com

# Créer un space
storacha space create my-app-space

# Lister vos spaces
storacha space ls
```

### Étape 3 : Générer un agent DID

Dans votre application Dart, générez un agent :

```dart
import 'package:storacha_dart/storacha_dart.dart';

void main() async {
  final agent = await Ed25519Signer.generate();
  print('Agent DID: ${agent.did}');
  
  // Sauvegarder la clé privée pour réutilisation
  print('Private key: ${agent.toJson()}');
}
```

**Output exemple** :
```
Agent DID: did:key:z6MkpRVGT1EAzixwKvYfosT2uoLJestPeR7gtWyVPPSiseH8
```

### Étape 4 : Créer la délégation

#### Option A : Format CAR Binaire (Recommandé)

```bash
storacha delegation create did:key:z6MkpRVGT1EAzixwKvYfosT2uoLJestPeR7gtWyVPPSiseH8 \
  -c space/blob/add \
  -c space/index/add \
  -c upload/add \
  -o delegation.car
```

#### Option B : Format Identity CID (pour env vars)

```bash
storacha delegation create did:key:z6MkpRVGT1EAzixwKvYfosT2uoLJestPeR7gtWyVPPSiseH8 \
  -c space/blob/add \
  -c space/index/add \
  -c upload/add \
  --base64 > delegation.txt
```

### Capacités requises pour l'upload

Pour uploader des fichiers, vous avez besoin **au minimum** de ces 3 capacités :

- `space/blob/add` : Ajouter des blobs au space
- `space/index/add` : Indexer les données
- `upload/add` : Créer un upload

## Utilisation en Dart

### 1. Charger la délégation

```dart
import 'package:storacha_dart/storacha_dart.dart';
import 'dart:io';

// Le package détecte automatiquement le format
final delegation = await Delegation.fromFile('delegation.car');

print('Issuer: ${delegation.issuer}');
print('Audience: ${delegation.audience}');
print('Capabilities: ${delegation.capabilities.length}');
```

### 2. Créer le client avec la délégation

```dart
// Charger ou créer votre agent (doit correspondre à l'audience)
final agent = await Ed25519Signer.generate();

// Configuration du client
final config = ClientConfig(
  principal: agent,
  defaultProvider: 'did:web:up.storacha.network',
);

// Créer le client avec les délégations
final client = StorachaClient(
  config,
  delegations: [delegation],
);
```

### 3. Extraire le Space DID

```dart
// Extraire le space DID depuis les capacités
String? spaceDid;
for (final cap in delegation.capabilities) {
  if (cap.with_.startsWith('did:')) {
    spaceDid = cap.with_;
    break;
  }
}

if (spaceDid == null) {
  throw Exception('No space DID found in delegation');
}

print('Space DID: $spaceDid');
```

### 4. Configurer le space

```dart
// Créer une instance Space
final delegatedSpace = Space(
  did: spaceDid,
  name: 'Delegated Space',
  signer: agent,
  createdAt: DateTime.now(),
);

// Ajouter et activer le space
client.addSpace(delegatedSpace);
client.setCurrentSpace(spaceDid);
```

### 5. Uploader des fichiers

```dart
// Upload simple
final fileBytes = await File('photo.jpg').readAsBytes();
final cid = await client.uploadFile(
  MemoryFile(name: 'photo.jpg', bytes: fileBytes),
);

print('Uploaded! CID: $cid');
print('Gateway URL: https://w3s.link/ipfs/$cid');

// Upload avec progress
final cid2 = await client.uploadFile(
  MemoryFile(name: 'video.mp4', bytes: videoBytes),
  options: UploadFileOptions(
    onUploadProgress: (status) {
      final percent = status.percentage?.toStringAsFixed(1) ?? '0.0';
      print('Upload progress: $percent%');
    },
  ),
);
```

## Tests et Validation

### Vérifier une délégation

```dart
final delegation = await Delegation.fromFile('delegation.car');

// Vérifier la validité
print('Is valid: ${delegation.isValid}');
print('Is expired: ${delegation.isExpired}');
print('Expires at: ${delegation.expiration}');

// Vérifier l'audience
if (delegation.audience != agent.did) {
  print('⚠️  Warning: Delegation is for ${delegation.audience}');
  print('   but agent is ${agent.did}');
}

// Lister les capacités
for (final cap in delegation.capabilities) {
  print('✓ ${cap.can} on ${cap.with_}');
}
```

### Exemple complet

Voir `storacha_test_app/bin/upload_with_delegation.dart` pour un exemple complet et fonctionnel.

### Tests automatisés

Lancer les tests :

```bash
cd storacha_dart
dart test
```

Tous les tests incluent :
- ✅ Parsing de tous les formats
- ✅ Validation des DIDs
- ✅ Vérification des capacités
- ✅ Edge cases (expiration, tampering, etc.)

## Troubleshooting

### Erreur : "Delegation audience mismatch"

**Cause** : La délégation a été créée pour un autre agent DID

**Solution** :
1. Vérifier le DID de votre agent : `print(agent.did)`
2. Recréer la délégation avec le bon DID audience

### Erreur : "Space needs to be provisioned"

**Cause** : Le space n'est pas provisionné sur Storacha Network

**Solution** : Via le CLI Storacha :
```bash
storacha space provision my-space
```

### Erreur : "Missing capability: space/blob/add"

**Cause** : La délégation ne contient pas toutes les capacités requises

**Solution** : Recréer la délégation avec toutes les capacités :
```bash
storacha delegation create <did> \
  -c space/blob/add \
  -c space/index/add \
  -c upload/add \
  -o delegation.car
```

### Erreur : "Invalid root: not a CID"

**Cause** : Le fichier de délégation est corrompu ou dans un format non supporté

**Solution** :
1. Régénérer la délégation
2. Vérifier que le fichier n'est pas tronqué
3. Utiliser le format CAR binaire plutôt que base64

### DIDs incorrects (manque le préfixe 'z')

**Cause** : Ancien code de parsing

**Solution** : Mettre à jour vers la dernière version du package
```yaml
dependencies:
  storacha_dart: ^0.1.0  # ou plus récent
```

## Architecture Technique

### Format DAG-CBOR des délégations

Les délégations générées par Storacha CLI utilisent le format DAG-CBOR :

```
CAR Archive
├── Root Block (variant)
│   └── {'ucan@0.9.1': <CID-to-UCAN>}
└── UCAN Block (DAG-CBOR)
    ├── v: "0.9.1"
    ├── iss: <bytes> (multicodec DID)
    ├── aud: <bytes> (multicodec DID)
    ├── att: [capabilities]
    ├── exp: <timestamp>
    └── s: <signature>
```

### Décodage des DIDs

Les DIDs dans les délégations DAG-CBOR sont encodés comme **principals** avec multicodec :

- `0xed` = Ed25519 → `did:key:z...`
- `0x0d1d` = DID Core → `did:mailto:...`, etc.

Le package utilise une transcription exacte du client de référence JavaScript (`@ipld/dag-ucan`).

## Ressources

- [Documentation Storacha](https://docs.storacha.network/)
- [Spécification UCAN](https://ucan.xyz/)
- [Format CAR](https://ipld.io/specs/transport/car/)
- [Package `storacha_dart`](https://pub.dev/packages/storacha_dart)

## Support

Pour des questions ou des problèmes :
1. Vérifier ce guide
2. Consulter les tests : `storacha_dart/test/`
3. Créer une issue sur GitHub

