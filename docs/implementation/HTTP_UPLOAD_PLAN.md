# HTTP Upload Implementation Plan

## 📋 Objectif

Implémenter l'upload réseau des fichiers vers Storacha en utilisant :
- **UCAN** pour l'authentification
- **HTTP** via Dio pour le transport
- **Capabilities** : `space/blob/add` et `upload/add`

## 🏗️ Architecture Storacha Upload

### Workflow Complet

```
1. Local Encoding (✅ DONE)
   File → UnixFS DAG → CAR file

2. Blob Add (🔜 TODO)
   invoke space/blob/add(digest, size)
   → receive allocation {url, headers}

3. Blob Upload (🔜 TODO)
   PUT CAR to allocation.url
   → blob stored

4. Upload Add (🔜 TODO)
   invoke upload/add(root, shards)
   → DAG registered

5. Return CID
   → root CID returned to client
```

### Capabilities Nécessaires

#### 1. `space/blob/add`
```typescript
{
  with: "did:key:zAlice...",  // Space DID
  can: "space/blob/add",
  nb: {
    blob: {
      digest: Uint8Array,  // Multihash du CAR (SHA-256)
      size: number         // Taille du CAR en bytes
    }
  }
}
```

**Response:**
```typescript
{
  ok: {
    allocated: true,  // ou false si déjà présent
    site: {
      url: string,    // URL pour PUT
      headers: object // Headers requis
    }
  }
}
```

#### 2. `upload/add`
```typescript
{
  with: "did:key:zAlice...",  // Space DID
  can: "upload/add",
  nb: {
    root: CID,        // Root CID du DAG
    shards: [CID]     // CIDs des CAR files (shards)
  }
}
```

**Response:**
```typescript
{
  ok: {
    root: CID,
    shards: [CID]
  }
}
```

## 🔐 UCAN Invocation Format

### Structure d'une Invocation

```json
{
  "v": "0.9.1",
  "iss": "did:key:zAgent...",     // Issuer (agent)
  "aud": "did:web:up.storacha.network",  // Audience (service)
  "att": [{                        // Capabilities
    "with": "did:key:zSpace...",
    "can": "space/blob/add",
    "nb": { ... }
  }],
  "prf": ["base64url..."],         // Proofs (delegations)
  "exp": 1234567890,               // Expiration
  "s": {                           // Signature
    "/": { "bytes": "base64url..." }
  }
}
```

### Signature Process

1. **Encode Header + Payload**
   ```dart
   final header = {'alg': 'EdDSA', 'typ': 'JWT'};
   final payload = {...invocation};
   final toSign = '${base64url(header)}.${base64url(payload)}';
   ```

2. **Sign with Ed25519**
   ```dart
   final signature = await signer.sign(utf8.encode(toSign));
   ```

3. **Create JWT**
   ```dart
   final jwt = '$toSign.${base64url(signature)}';
   ```

## 📡 HTTP Transport

### Endpoint

```
POST https://up.storacha.network
Content-Type: application/car
```

### Request Format

```
CAR file containing:
- UCAN invocation as CBOR block
- Any linked data
```

### Response Format

```json
{
  "ok": { ... }  // Success response
}
```

ou

```json
{
  "error": {
    "name": "ErrorName",
    "message": "Error message"
  }
}
```

## 🛠️ Implementation Tasks

### Phase 6.1: UCAN Invocation Builder
- [ ] `InvocationBuilder` class
- [ ] Encode capabilities
- [ ] Create UCAN JWT
- [ ] Sign with Ed25519Signer

### Phase 6.2: HTTP Transport
- [ ] `UcanTransport` class with Dio
- [ ] Encode invocations to CAR
- [ ] POST to Storacha endpoint
- [ ] Parse responses

### Phase 6.3: Blob Upload
- [ ] `space/blob/add` invocation
- [ ] Parse allocation response
- [ ] PUT CAR to allocation URL
- [ ] Handle deduplication

### Phase 6.4: Upload Registration
- [ ] `upload/add` invocation  
- [ ] Link root CID with shards
- [ ] Return final result

### Phase 6.5: Integration in StorachaClient
- [ ] Update `uploadFile()` to use network
- [ ] Add retry logic (use ExponentialBackoffRetry)
- [ ] Progress tracking for network upload
- [ ] Error handling

### Phase 6.6: Tests
- [ ] Mock HTTP tests
- [ ] Integration tests with real network (if possible)
- [ ] Error scenarios tests

## 🔍 Key Files to Create

```
lib/src/ucan/
├── invocation.dart         # UCAN invocation builder
└── capability_builder.dart # Helpers for capabilities

lib/src/transport/
├── ucan_transport.dart     # HTTP transport for UCAN
└── allocation.dart         # Blob allocation handling

lib/src/client/
└── blob_uploader.dart      # High-level blob upload logic
```

## 📚 References

- **UCAN Spec**: https://github.com/ucan-wg/spec
- **Storacha API**: https://docs.storacha.network/
- **@ucanto/client**: `reference_js_client/node_modules/@ucanto/client/`
- **@storacha/capabilities**: `reference_js_client/node_modules/@storacha/capabilities/`

## ⚠️ Notes

- Le système utilise maintenant `space/blob/*` au lieu de `store/*` (deprecated)
- Les blobs sont identifiés par leur multihash (digest SHA-256)
- Les CAR files sont uploadés via PUT HTTP classique
- Les invocations UCAN sont envoyées en POST sous forme de CAR

## 🎯 Success Criteria

- ✅ File uploaded to Storacha network
- ✅ CID returned matches local encoding
- ✅ File retrievable via IPFS gateway
- ✅ All tests passing
- ✅ No lint warnings

