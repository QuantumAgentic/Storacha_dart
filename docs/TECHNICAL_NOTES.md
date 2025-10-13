# Technical Notes - Storacha Dart Implementation

This document explains the technical details and compatibility fixes implemented to ensure `storacha_dart` works correctly with Storacha Network.

## IPLD Message Format (ucanto/message@7.0.0)

The package uses the `ucanto/message@7.0.0` format for communication with Storacha, NOT JWT tokens.

### Message Structure

```
{
  "ucanto/message@7.0.0": {
    "execute": [<invocation-cid>]
  }
}
```

This message is encoded as DAG-CBOR and packaged in a CAR file containing:
1. All delegation proofs (from the proof chain)
2. The invocation UCAN
3. The message root

## Critical Encoding Details

### 1. CID Encoding in DAG-CBOR

**CIDs MUST include a `0x00` multibase prefix:**

```dart
// WRONG
_encodeBytes(cid.bytes);

// CORRECT
final cidWithPrefix = Uint8List(cid.bytes.length + 1);
cidWithPrefix[0] = 0x00;  // Multibase identity prefix
cidWithPrefix.setRange(1, cidWithPrefix.length, cid.bytes);
_encodeBytes(cidWithPrefix);
```

This applies to:
- CIDs in DAG-CBOR maps (e.g., `prf` field)
- CIDs in CAR headers

Reference: `@ipld/dag-cbor/src/index.js` line 48-49

### 2. Signature Payload Encoding

The signature is computed over a **JWT-style string**, not the DAG-CBOR bytes:

```
signature = sign(base64url(header) + "." + base64url(payload))
```

**Critical**: The payload uses **IPLD JSON encoding** where bytes are encoded as:

```json
{
  "digest": {
    "/": {
      "bytes": "EiBxciklbFD6QDrLcIb+pVIcI6tnvYksug5wYfeqhtAa0Q"
    }
  }
}
```

**NOT** as an array of numbers!

The base64 encoding for bytes objects uses **standard base64** (with `+` and `/`), not base64url (with `-` and `_`), and **without padding** (`=`).

```dart
// Encode Uint8List in signature payload
final base64Str = base64.encode(value).replaceAll('=', '');  // Standard base64, no padding
return '{"/":{"bytes":"$base64Str"}}';
```

### 3. Canonical JSON Encoding

Both the JWT header and payload must use **canonical JSON encoding**:
- Keys in **alphabetical order**
- No whitespace
- Consistent formatting

```dart
// Example: header keys must be alphabetically ordered
{
  "alg": "EdDSA",   // a
  "typ": "JWT",     // t
  "ucv": "0.9.1"    // u
}
```

### 4. CAR Header Encoding

The CAR header must encode keys in alphabetical order:

```
{
  "roots": [<cid>],    // r comes before v
  "version": 1
}
```

**WRONG**: `{"version": 1, "roots": [...]}`  
**CORRECT**: `{"roots": [...], "version": 1}`

### 5. EdDSA Signature Format

Signatures are encoded with a multicodec prefix:

```
<varint(0xd0ed)> + <varint(signature.length)> + <signature-bytes>
```

Example for 64-byte signature:
```
ed a1 03 40 [64 bytes of signature]
```

Where:
- `ed a1 03` = varint encoding of 0xd0ed (EdDSA)
- `40` = varint encoding of 64 (signature length)

## Common Pitfalls

### ❌ Wrong: Using base64url for IPLD bytes
```dart
final base64Str = base64Url.encode(value);  // WRONG!
```

### ✅ Correct: Using standard base64 without padding
```dart
final base64Str = base64.encode(value).replaceAll('=', '');  // CORRECT
```

---

### ❌ Wrong: CID without 0x00 prefix
```dart
_encodeBytes(cid.bytes);  // WRONG!
```

### ✅ Correct: CID with 0x00 prefix
```dart
final cidWithPrefix = Uint8List(cid.bytes.length + 1);
cidWithPrefix[0] = 0x00;
cidWithPrefix.setRange(1, cidWithPrefix.length, cid.bytes);
_encodeBytes(cidWithPrefix);  // CORRECT
```

---

### ❌ Wrong: Signing DAG-CBOR bytes
```dart
final cborBytes = encodeDagCbor(invocation);
final signature = await signer.sign(cborBytes);  // WRONG!
```

### ✅ Correct: Signing JWT-style payload
```dart
final jwtPayload = encodeSignaturePayload(...);  // base64url(header).base64url(payload)
final signature = await signer.sign(jwtPayload);  // CORRECT
```

## Compatibility Matrix

| Feature | Dart Implementation | JS Reference | Status |
|---------|-------------------|--------------|--------|
| UCAN 0.9.1 | ✅ | ✅ | Compatible |
| DAG-CBOR encoding | ✅ | ✅ | Compatible |
| EdDSA signatures | ✅ | ✅ | Compatible |
| CAR format | ✅ | ✅ | Compatible |
| Binary CAR delegations | ✅ | ✅ | Compatible |
| Base64 identity CID | ✅ | ✅ | Compatible |
| ucanto/message@7.0.0 | ✅ | ✅ | Compatible |

## Testing

To verify compatibility with the JavaScript reference client:

```bash
# Generate identical CARs with fixed expiration
cd storacha_test_app
dart run test_dart_fixed_exp.dart
node test_with_fixed_exp.mjs

# Compare byte-by-byte
cmp dart_fixed_exp_invocation.car js_fixed_exp_invocation.car
# Should be identical!
```

## References

- `@ucanto/core` - Reference implementation
- `@ipld/dag-cbor` - CBOR encoding specification
- `@ipld/dag-json` - JSON encoding for signatures
- UCAN 0.9.1 specification

## Changelog

### v0.1.0 - Delegation Support

- ✅ Implemented CAR delegation parsing
- ✅ Implemented base64 identity CID parsing
- ✅ Fixed CID encoding (0x00 prefix)
- ✅ Fixed signature payload encoding (IPLD JSON format)
- ✅ Fixed CAR header field ordering
- ✅ Added support for ucanto/message@7.0.0 format
- ✅ Verified byte-for-byte compatibility with JS reference client

