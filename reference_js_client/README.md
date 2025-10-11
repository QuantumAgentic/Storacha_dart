# Référence Client JavaScript Storacha

Ce dossier contient le code source du client JavaScript officiel de Storacha, installé via npm pour servir de référence lors de l'implémentation du client Dart.

## 📦 Packages Installés

### @storacha/client (Principal)
- **Path**: `node_modules/@storacha/client/`
- **Version**: Vérifier `package.json`
- **Source TypeScript**: `src/` (si disponible)
- **Dist compilé**: `dist/`

### Dépendances Clés

1. **multiformats** (`node_modules/multiformats/`)
   - CID implementation
   - Multibase (base58, base32, base64, etc.)
   - Multihash (SHA-256, SHA-512)
   - Varint encoding
   - Source: `src/`

2. **@ucanto/client** (`node_modules/@ucanto/client/`)
   - UCAN client framework
   - Delegation management
   
3. **@ucanto/transport** (`node_modules/@ucanto/transport/`)
   - HTTP transport
   - CAR encoding

4. **@ipld/car** (`node_modules/@ipld/car/`)
   - CAR file format

5. **@ipld/dag-cbor** (`node_modules/@ipld/dag-cbor/`)
   - CBOR encoding for IPLD

## 🗂️ Structure du Client Principal

```
@storacha/client/dist/
├── client.js              # Client principal
├── account.js             # Gestion des comptes
├── space.js               # Gestion des espaces
├── delegation.js          # Délégations UCAN
├── capability/            # Capabilities UCAN
│   ├── space.js
│   ├── upload.js
│   ├── blob.js
│   └── ...
├── principal/             # Crypto/DID
│   ├── ed25519.js
│   └── rsa.js
└── stores/                # Stockage local
    ├── conf.js
    ├── memory.js
    └── indexeddb.js
```

## 🔍 Fichiers Clés à Étudier

### Pour l'Architecture Globale
- `dist/client.js` - Point d'entrée principal
- `dist/types.d.ts` - Définitions TypeScript
- `dist/service.js` - Configuration des services

### Pour l'Authentification
- `dist/account.js` - Login, gestion compte
- `dist/delegation.js` - Système de délégations

### Pour les Espaces
- `dist/space.js` - Création, gestion espaces
- `dist/capability/space.js` - Capabilities espace

### Pour l'Upload
- `dist/capability/upload.js` - Capabilities upload
- Voir aussi `@storacha/upload-client`

### Pour la Crypto
- `dist/principal/ed25519.js` - Signature Ed25519
- `dist/delegation.js` - UCAN tokens

### Pour le Stockage
- `dist/stores/conf.js` - Stockage configuration
- `dist/stores/memory.js` - Stockage mémoire
- `dist/stores/indexeddb.js` - Stockage IndexedDB

## 📚 Multiformats (Référence IPFS)

### CID
```
multiformats/src/cid.ts
```
- Implémentation CID v0/v1
- Parsing et sérialisation

### Multibase
```
multiformats/src/bases/
├── base58.ts       # Base58btc (Bitcoin)
├── base32.ts       # Base32 (CIDv1 default)
├── base64.ts       # Base64url
└── base.ts         # Interface de base
```

### Varint
```
multiformats/src/varint.ts
```
- Encodage entiers variables

### Hashes
```
multiformats/src/hashes/
├── digest.ts       # Multihash digest
├── sha2.ts         # SHA-256, SHA-512
└── interface.ts    # Types
```

## 🔎 Comment Explorer

### Lire les Définitions TypeScript
Les fichiers `.d.ts` contiennent les signatures de types :
```bash
cat node_modules/@storacha/client/dist/client.d.ts
```

### Lire le Code Source
Le code TypeScript source est dans `src/` quand disponible :
```bash
# Multiformats source
ls multiformats/src/

# CID implementation
cat multiformats/src/cid.ts
```

### Chercher des Patterns
```bash
# Trouver tous les fichiers qui utilisent Ed25519
grep -r "ed25519" node_modules/@storacha/

# Trouver implementation UCAN
grep -r "UCAN" node_modules/@ucanto/
```

## 🎯 Mapping JS → Dart

### Clients
| JavaScript | Dart (à implémenter) |
|------------|----------------------|
| `@storacha/client` | `package:storacha_dart` |
| `create()` | `StorachaClient.create()` |
| `login(email)` | `client.login(email)` |

### Crypto
| JavaScript | Dart |
|------------|------|
| `@ucanto/principal/ed25519` | `lib/src/crypto/ed25519_signer.dart` |
| `Signer` interface | `abstract class Signer` |

### Multiformats
| JavaScript | Dart |
|------------|------|
| `multiformats/cid` | `lib/src/ipfs/cid/cid.dart` |
| `multiformats/bases/base58` | `lib/src/ipfs/multiformats/multibase.dart` |
| `multiformats/varint` | `lib/src/ipfs/multiformats/varint.dart` |

## 📖 Documentation Officielle

- **API Docs**: https://docs.storacha.network/js-client/
- **GitHub**: https://github.com/storacha (organization)
- **NPM**: https://www.npmjs.com/package/@storacha/client

## 🔄 Mise à Jour

Pour mettre à jour les packages de référence :
```bash
cd reference_js_client
npm update
```

## ⚠️ Important : Ce Dossier N'est PAS Versionné

Les fichiers `node_modules/` et `package-lock.json` sont exclus du repo git via `.gitignore`.

**Pour installer après clonage :**
```bash
cd storacha_dart/reference_js_client
npm install
```

Cela re-téléchargera tous les packages de référence (~121 packages).

---

**Note**: Ce dossier est pour **référence locale uniquement**. Le code Dart est implémenté indépendamment dans `lib/`.

