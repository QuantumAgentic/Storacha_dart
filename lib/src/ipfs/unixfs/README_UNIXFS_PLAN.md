# UnixFS Implementation Plan

## 📋 Status: IN PROGRESS (Phase 5.3)

**Current State**: Basic types defined, encoder implementation pending

---

## 🎯 What is UnixFS?

UnixFS est le format utilisé par IPFS pour représenter fichiers et répertoires dans un DAG (Directed Acyclic Graph). Il permet de :
- Découper de gros fichiers en chunks
- Créer une arborescence de blocks IPLD
- Supporter fichiers, répertoires, symlinks
- Gérer le sharding pour gros répertoires (>1000 items)

---

## ✅ Completed

### 1. Types de Base (`unixfs_types.dart`)
- ✅ `UnixFSType` enum (file, directory, symlink)
- ✅ `UnixFSNode` (métadonnées)
- ✅ `IPLDBlock` (CID + bytes)
- ✅ `UnixFSEncodeResult` (rootCID + blocks)
- ✅ `UnixFSEncodeOptions` (configuration)

---

## 🔄 TODO: Core Implementation

### 2. Protobuf Encoding (`unixfs_pb.dart`) 
**Priorité**: HIGH | **Difficulté**: MEDIUM

UnixFS utilise Protocol Buffers pour encoder les métadonnées.

```protobuf
message Data {
  enum DataType {
    Raw = 0;
    Directory = 1;
    File = 2;
    Metadata = 3;
    Symlink = 4;
    HAMTShard = 5;
  }
  required DataType Type = 1;
  optional bytes Data = 2;
  optional uint64 filesize = 3;
  repeated uint64 blocksizes = 4;
  optional uint64 hashType = 5;
  optional uint64 fanout = 6;
}

message PBLink {
  optional bytes Hash = 1;
  optional string Name = 2;
  optional uint64 Tsize = 3;
}

message PBNode {
  repeated PBLink Links = 2;
  optional bytes Data = 1;
}
```

**Tasks**:
- [ ] Créer `unixfs_pb.dart` avec les structures Protobuf
- [ ] Implémenter `encodeData(UnixFSNode) -> Uint8List`
- [ ] Implémenter `encodePBNode(links, data) -> Uint8List`
- [ ] Tests : encoder/decoder roundtrip

**Alternative**: Utiliser `package:protobuf` si disponible

---

### 3. File Chunker (`file_chunker.dart`)
**Priorité**: HIGH | **Difficulté**: LOW

Découpe un fichier en chunks de taille fixe.

```dart
Stream<Uint8List> chunkFile(
  BlobLike file,
  {int chunkSize = 256 * 1024}
) async* {
  await for (final chunk in file.stream()) {
    // Yield chunks of specified size
  }
}
```

**Tasks**:
- [ ] Créer `FileChunker` class
- [ ] Méthode `chunk(BlobLike) -> Stream<Uint8List>`
- [ ] Support tailles variables (256 KiB, 1 MiB, etc.)
- [ ] Tests : chunking de fichiers de différentes tailles

---

### 4. UnixFS Encoder (`unixfs_encoder.dart`)
**Priorité**: HIGH | **Difficulté**: HIGH

Encode un fichier en DAG UnixFS.

**Algorithm** (Simplified Balanced Tree):
```
1. Si fichier < chunkSize:
   - Créer un seul block (raw ou dag-pb)
   - Return root CID

2. Si fichier >= chunkSize:
   - Découper en N chunks
   - Créer N leaf blocks (raw codec)
   - Créer root block (dag-pb) qui référence les leafs
   - Return root CID
   
3. Si trop de leafs (> maxChildrenPerNode):
   - Créer intermediate nodes (balanced tree)
   - Root node -> intermediate nodes -> leaf nodes
```

**Tasks**:
- [ ] `encodeFile(BlobLike, options) -> Future<UnixFSEncodeResult>`
- [ ] Cas 1: Small file (single block)
- [ ] Cas 2: Chunked file (multiple leaf blocks + root)
- [ ] Cas 3: Large file (balanced tree with intermediate nodes)
- [ ] Calculer `filesize` et `blocksizes` correctement
- [ ] Tests : files de 1 KB, 1 MB, 10 MB, 100 MB

**Référence JS**:
```javascript
// node_modules/@storacha/upload-client/dist/unixfs.js
export async function encodeFile(blob, options) {
    const readable = createFileEncoderStream(blob, options);
    const blocks = await collect(readable);
    return { cid: blocks.at(-1).cid, blocks };
}
```

---

### 5. Directory Encoder (`directory_encoder.dart`)
**Priorité**: MEDIUM | **Difficulté**: MEDIUM

Encode un répertoire en DAG UnixFS.

**Algorithm**:
```
1. Pour chaque file:
   - Encoder le file -> get CID
   
2. Créer directory node:
   - Links vers tous les files (name -> CID)
   - Type = Directory
   
3. Si > 1000 entries:
   - Use HAMT sharding (optional, can defer)
```

**Tasks**:
- [ ] `encodeDirectory(List<FileLike>, options) -> Future<UnixFSEncodeResult>`
- [ ] Créer PBLinks pour chaque file
- [ ] Gérer les noms et paths
- [ ] Tests : directories with 1, 10, 100 files

**Defer**: HAMT sharding (only needed for >1000 files)

---

## 🔧 Integration avec StorachaClient

### 6. Update `uploadFile` Implementation
**Priorité**: HIGH | **Difficulté**: LOW

Remplacer `throw UnimplementedError` par :

```dart
Future<CID> uploadFile(
  BlobLike file, {
  UploadFileOptions? options,
}) async {
  if (_currentSpace == null) {
    throw StateError('No space selected');
  }

  // 1. Encode file to UnixFS
  final encoded = await UnixFSEncoder.encodeFile(
    file,
    options: UnixFSEncodeOptions(chunkSize: options?.chunkSize ?? 256 * 1024),
  );

  // 2. Create CAR file from blocks
  final car = await CAREncoder.encode(encoded.blocks);

  // 3. Upload CAR to Storacha
  // TODO: Implement HTTP upload logic

  return encoded.rootCID;
}
```

---

## 📦 Dependencies Needed

### Protobuf
```yaml
dependencies:
  protobuf: ^3.1.0  # For UnixFS protobuf encoding
```

**Alternative**: Implement basic protobuf encoder manually (simpler)

### DAG-PB Codec
UnixFS uses `dag-pb` codec (0x70) for directory nodes.

- Either implement manually (simple varint + protobuf)
- Or extract from JS reference

---

## 🧪 Testing Strategy

### Unit Tests
- [ ] UnixFS protobuf encoding/decoding
- [ ] File chunking (various sizes)
- [ ] Small file encoding (< chunkSize)
- [ ] Medium file encoding (2-10 chunks)
- [ ] Large file encoding (balanced tree)
- [ ] Directory encoding (1, 10, 100 files)

### Integration Tests
- [ ] Upload real file and verify CID matches JS client
- [ ] Upload directory and verify structure
- [ ] Test with various file sizes (1 KB → 100 MB)

### Performance Tests
- [ ] Benchmark chunking speed
- [ ] Memory usage during encoding
- [ ] Compare with JS client performance

---

## 📚 References

### JS Client
- `reference_js_client/node_modules/@storacha/upload-client/dist/unixfs.js`
- `reference_js_client/node_modules/@ipld/unixfs/`

### IPFS Specs
- UnixFS: https://github.com/ipfs/specs/blob/main/UNIXFS.md
- DAG-PB: https://github.com/ipld/specs/blob/master/block-layer/codecs/dag-pb.md

### Protobuf Definition
- https://github.com/ipfs/go-unixfs/blob/master/pb/unixfs.proto

---

## 🎯 Milestones

### Milestone 1: Basic File Upload ✅
- [x] Types defined
- [ ] Protobuf encoding
- [ ] File chunker
- [ ] Simple file encoder (no balanced tree)
- [ ] Integration test: upload 1 MB file

### Milestone 2: Complete File Upload
- [ ] Balanced tree for large files
- [ ] Memory-efficient streaming
- [ ] Progress callbacks integration
- [ ] Integration test: upload 100 MB file

### Milestone 3: Directory Upload
- [ ] Directory encoder
- [ ] Path handling
- [ ] Integration test: upload directory with 10 files

### Milestone 4: Production Ready
- [ ] CAR encoding integration
- [ ] HTTP upload to Storacha
- [ ] Retry logic
- [ ] Full E2E tests

---

## 💡 Implementation Notes

### Simplified Approach (Recommended for MVP)

Pour une première version fonctionnelle, on peut simplifier :

1. **Single-level chunking** : Pas de balanced tree
   - Limite : ~174 chunks × 256 KiB = ~44 MB
   - Suffisant pour 90% des cas d'usage
   
2. **No HAMT sharding** : Directories < 1000 files
   - Directories avec >1000 files sont rares
   
3. **Manual protobuf** : Pas de dépendance externe
   - UnixFS protobuf est simple
   - ~50 lignes de code

### Full Implementation (For Production)

Pour une version complète :

1. **Balanced tree** : Support fichiers >100 MB
2. **HAMT sharding** : Support gros directories
3. **Streaming** : Pas de loading complet en mémoire
4. **Protobuf package** : Plus robuste

---

## 🚦 Next Steps

**Immediate** (Current Session):
1. ✅ Create basic types
2. ⏸️ Document plan (this file)
3. ⏸️ Commit progress

**Next Session**:
1. Implement protobuf encoding
2. Implement file chunker
3. Implement simple file encoder
4. Write tests
5. Integrate with uploadFile()

**Future Sessions**:
1. CAR encoding
2. HTTP upload to Storacha
3. Directory encoding
4. Complete E2E flow

---

## 📊 Estimated Effort

| Component | Lines of Code | Time | Complexity |
|-----------|---------------|------|------------|
| Protobuf encoding | ~100 | 2h | Medium |
| File chunker | ~50 | 1h | Low |
| Simple file encoder | ~150 | 3h | Medium |
| Balanced tree | ~200 | 4h | High |
| Directory encoder | ~150 | 3h | Medium |
| Tests | ~400 | 4h | Medium |
| **TOTAL** | **~1050** | **~17h** | **Medium-High** |

---

## ✅ Success Criteria

UnixFS implementation sera considérée complète quand :

1. ✅ On peut encoder un fichier simple (< 256 KiB)
2. ✅ On peut encoder un fichier chunked (> 256 KiB)
3. ✅ Le CID généré matche le JS client
4. ✅ On peut encoder un directory
5. ✅ Tous les tests passent
6. ✅ dart analyze : 0 errors
7. ✅ Documentation complète

---

**Status**: 📝 Plan documenté | 🔨 Ready for implementation
**Next Implementer**: Peut reprendre à partir de "TODO: Core Implementation"

