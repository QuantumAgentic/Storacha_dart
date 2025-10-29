# JS FFI Uploader - Intégration temporaire du client officiel

## Vue d'ensemble

Solution temporaire pour utiliser le client JS officiel `@storacha/client` via un CLI Node, en attendant la parité complète du client Dart natif.

**Objectif**: Uploads fonctionnels avec retrieval immédiat, changements minimaux dans l'app.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Application Dart (quantum_agents)                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  StorachaClient (API publique inchangée)             │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Feature Flag: USE_JS_UPLOADER                 │  │   │
│  │  │  ├─ true  → JsUploadAdapter                    │  │   │
│  │  │  └─ false → Native Dart Upload (actuel)        │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  JsUploadAdapter (Dart)                                     │
│  • Lance process Node: storacha-uploader.mjs                │
│  • Envoie JSON via stdin (params + data base64)             │
│  • Parse JSON stdout (root CID, shards, errors)             │
│  • Map erreurs → exceptions Dart                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  storacha-uploader.mjs (Node CLI)                           │
│  • Commandes: upload-file, upload-car                       │
│  • Utilise @storacha/client directement                     │
│  • Output: JSON strict { root, shards, error? }            │
└─────────────────────────────────────────────────────────────┘
```

## Contrat CLI

### Input (stdin JSON)

```json
{
  "command": "upload-file",
  "key": "MgCZT5vOnYZoTacEP1aRo...",
  "spaceDid": "did:key:z6Mkk...",
  "data": "base64_encoded_bytes",
  "options": {
    "chunkSize": 262144,
    "pieceHasher": true
  }
}
```

### Output (stdout JSON)

**Succès:**
```json
{
  "success": true,
  "root": "bafybei...",
  "shards": ["bagbaiera..."],
  "duration_ms": 1234
}
```

**Erreur:**
```json
{
  "success": false,
  "error": {
    "code": "UPLOAD_FAILED",
    "message": "Failed to upload: network timeout",
    "details": {}
  }
}
```

### Exit codes

- `0`: Succès
- `1`: Erreur générique
- `2`: Arguments invalides
- `3`: Authentification échouée
- `4`: Réseau/timeout

## Activation

### Via environnement

```bash
export USE_JS_UPLOADER=true
export KEY="MgCZT5vOnYZoTacEP1aRo..."
dart run example/test_truly_unique.dart
```

### Via code

```dart
final client = await StorachaClient.create(
  principal: signer,
  store: store,
  config: ClientConfig(
    useJsUploader: true, // Feature flag
  ),
);
```

## Dépendances

### Node (>=18)

```bash
node --version  # v18.0.0+
```

### Packages JS

```bash
cd storacha_dart/tool/js_uploader
npm install
# Installe: @storacha/client, @storacha/upload-client
```

## Développement

### Test rapide du CLI

```bash
cd storacha_dart/tool/js_uploader
echo '{"command":"upload-file","key":"...","spaceDid":"...","data":"SGVsbG8gV29ybGQ="}' | node storacha-uploader.mjs
```

### Test de l'adapter Dart

```dart
final adapter = JsUploadAdapter();
final result = await adapter.uploadFile(
  bytes: utf8.encode('Hello World'),
  key: 'MgCZT5v...',
  spaceDid: 'did:key:z6Mkk...',
);
print('Root CID: ${result.root}');
```

## Mapping d'erreurs

| Exit Code | Dart Exception | Description |
|-----------|----------------|-------------|
| 0 | - | Succès |
| 1 | `StorachaException` | Erreur générique |
| 2 | `ArgumentError` | Params invalides |
| 3 | `AuthenticationException` | Clé/proofs invalides |
| 4 | `NetworkException` | Timeout/réseau |

## Limitations

- **Performance**: Overhead process spawn (~50-100ms)
- **Proofs**: Seules les délégations via fichiers supportées initialement
- **Progress**: Callbacks de progression non supportés (v1)
- **Concurrence**: Un upload à la fois par process

## Roadmap

1. ✅ CLI minimal (upload-file)
2. ⏳ Adapter Dart + feature flag
3. ⏳ Test e2e avec retrieval immédiat
4. ⏳ Support upload-car
5. ⏳ Gestion proofs/delegations
6. ⏳ Progress callbacks via events JSON
7. ⏳ Pool de process pour concurrence
8. 🔜 Migration progressive vers Dart natif

## Fallback

Si Node indisponible ou CLI échoue:
```dart
if (config.useJsUploader && !jsUploaderAvailable) {
  print('⚠️  JS uploader unavailable, falling back to Dart');
  return _uploadFileDart(file);
}
```

## Notes

- Le CLI est **temporaire** - objectif: parité Dart complète
- Les CARs/index générés par Dart sont corrects (vérifié)
- Le problème actuel est dans le flow UCAN Dart (ucan/conclude, timing)
- Cette solution permet de débloquer l'app pendant qu'on finalise Dart

