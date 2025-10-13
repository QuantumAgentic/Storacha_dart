# TODO : Implémentation Délégations UCAN

**Version Cible** : v0.2.0  
**Timeline** : 7-11 jours  
**Priorité** : Haute

---

## 📊 Vue d'Ensemble

```
Progression Globale: ░░░░░░░░░░░░░░░░░░░░ 0/100 tests

Phase 1: Types de Base        ░░░░░░░░░░ 0/30 tests (0%)
Phase 2: Parsing UCAN          ░░░░░░░░░░ 0/25 tests (0%)
Phase 3: Intégration Client    ░░░░░░░░░░ 0/20 tests (0%)
Phase 4: Encoding Invocations  ░░░░░░░░░░ 0/15 tests (0%)
Phase 5: Tests E2E             ░░░░░░░░░░ 0/10 tests (0%)
Phase 6: Documentation         ░░░░░░░░░░ 0/4 docs (0%)
```

---

## Phase 1 : Types de Base (1-2 jours)

### 1.1 Modèle Delegation
- [ ] **delg-1.1.1** : Créer `lib/src/ucan/delegation.dart`
  - [ ] Class `Delegation` avec tous les champs
  - [ ] Factory `load(String path)`
  - [ ] Factory `parse(Uint8List bytes)`
  - [ ] Factory `fromBase64(String)`
  - [ ] Method `toUCAN()`
  - [ ] Getter `spaceDid`
  - **Tests** : 10 tests
  - **Durée** : 3h

### 1.2 Modèle Proof
- [ ] **delg-1.2.1** : Créer `lib/src/ucan/proof.dart`
  - [ ] Class `Proof` avec `cid` et `ucan`
  - [ ] Factory `fromJWT(String jwt)`
  - [ ] Method `toCARBlock()`
  - **Tests** : 10 tests
  - **Durée** : 2h

### 1.3 ProofChain
- [ ] **delg-1.3.1** : Créer `lib/src/ucan/proof_chain.dart`
  - [ ] Class `ProofChain`
  - [ ] Method `add(Proof)`
  - [ ] Method `getCIDs()`
  - [ ] Method `getUCANs()`
  - [ ] Method `validate()`
  - [ ] Method `toCARBlocks()`
  - **Tests** : 10 tests
  - **Durée** : 2h

### Phase 1 : Validation
- [ ] **delg-1.4.1** : Lancer tous les tests (30 tests)
- [ ] **delg-1.4.2** : `dart analyze` → 0 warnings
- [ ] **delg-1.4.3** : Commit `feat: add UCAN delegation types`

**Total Phase 1** : 30 tests, 7h

---

## Phase 2 : Parsing UCAN (2-3 jours)

### 2.1 CBOR Decoder
- [ ] **delg-2.1.1** : Créer `lib/src/core/cbor_decoder.dart`
  - [ ] Class `SimpleCborDecoder`
  - [ ] Support types : null, bool, int, string
  - [ ] Support types : bytes, array, map
  - [ ] Method `decode(Uint8List)`
  - **Tests** : 10 tests
  - **Durée** : 4h

### 2.2 CAR Decoder
- [ ] **delg-2.2.1** : Créer `lib/src/ipfs/car/car_decoder.dart`
  - [ ] Class `CARDecoder`
  - [ ] Method `decode(Uint8List)`
  - [ ] Method `_decodeCBORHeader()`
  - [ ] Class `CARFile` avec `header` et `blocks`
  - [ ] Method `findBlock(CID)`
  - [ ] Getter `root`
  - **Tests** : 10 tests
  - **Durée** : 5h

### 2.3 Delegation Parser
- [ ] **delg-2.3.1** : Créer `lib/src/ucan/delegation_parser.dart`
  - [ ] Class `DelegationParser`
  - [ ] Method `fromCAR(Uint8List)`
  - [ ] Method `fromJWT(String)`
  - [ ] Method `fromFile(String)`
  - **Tests** : 5 tests
  - **Durée** : 3h

### 2.4 Étendre UCAN.parse()
- [ ] **delg-2.4.1** : Modifier `lib/src/ucan/ucan.dart`
  - [ ] Ajouter `UCAN.parse(String jwt)`
  - [ ] Parser header JWT (Base64Url)
  - [ ] Parser payload JWT (Base64Url)
  - [ ] Parser signature JWT (Base64Url)
  - [ ] Valider format
  - **Tests** : Intégré dans tests existants
  - **Durée** : 2h

### Phase 2 : Validation
- [ ] **delg-2.5.1** : Lancer tous les tests (25 nouveaux)
- [ ] **delg-2.5.2** : `dart analyze` → 0 warnings
- [ ] **delg-2.5.3** : Test manuel : parser un vrai `.ucan`
- [ ] **delg-2.5.4** : Commit `feat: add UCAN parsing (CAR, JWT, CBOR)`

**Total Phase 2** : 25 tests, 14h

---

## Phase 3 : Intégration Client (1-2 jours)

### 3.1 StorachaClient avec Delegations
- [ ] **delg-3.1.1** : Modifier `lib/src/client/storacha_client.dart`
  - [ ] Ajouter paramètre `List<Delegation>? delegations`
  - [ ] Field `_delegations`
  - [ ] Method `addDelegation(Delegation)`
  - [ ] Method `loadDelegation(String path)`
  - [ ] Getter `delegations`
  - [ ] Auto-add space from delegation
  - **Tests** : 10 tests
  - **Durée** : 3h

### 3.2 InvocationBuilder avec Proofs
- [ ] **delg-3.2.1** : Modifier `lib/src/ucan/invocation.dart`
  - [ ] Ajouter field `List<UCAN> proofs`
  - [ ] Method `addProof(UCAN)`
  - [ ] Method `addProofs(List<UCAN>)`
  - [ ] Include proofs in `build()`
  - **Tests** : 5 tests
  - **Durée** : 2h

### 3.3 StorachaTransport avec Proofs
- [ ] **delg-3.3.1** : Modifier `lib/src/transport/storacha_transport.dart`
  - [ ] Ajouter param `List<Delegation>?` à `invokeBlobAdd`
  - [ ] Ajouter param `List<Delegation>?` à `invokeUploadAdd`
  - [ ] Auto-inject proofs from delegations
  - **Tests** : 5 tests
  - **Durée** : 2h

### Phase 3 : Validation
- [ ] **delg-3.4.1** : Lancer tous les tests (20 nouveaux)
- [ ] **delg-3.4.2** : `dart analyze` → 0 warnings
- [ ] **delg-3.4.3** : Tests d'intégration avec mock
- [ ] **delg-3.4.4** : Commit `feat: integrate delegations into client`

**Total Phase 3** : 20 tests, 7h

---

## Phase 4 : Encoding Invocations (1-2 jours)

### 4.1 Encoder avec Proofs
- [ ] **delg-4.1.1** : Modifier `lib/src/ucan/invocation_encoder.dart`
  - [ ] Function `encodeInvocationWithProofs()`
  - [ ] Encoder JWT principal
  - [ ] Encoder chaque proof en CBOR
  - [ ] Créer CAR multi-blocks
  - [ ] JWT comme root, proofs comme blocks
  - **Tests** : 10 tests
  - **Durée** : 4h

### 4.2 Intégrer dans Transport
- [ ] **delg-4.2.1** : Modifier `storacha_transport.dart`
  - [ ] Utiliser `encodeInvocationWithProofs()` si proofs présents
  - [ ] Fallback sur `encodeInvocationToCar()` sinon
  - **Tests** : 5 tests
  - **Durée** : 2h

### Phase 4 : Validation
- [ ] **delg-4.3.1** : Lancer tous les tests (15 nouveaux)
- [ ] **delg-4.3.2** : `dart analyze` → 0 warnings
- [ ] **delg-4.3.3** : Vérifier format CAR généré
- [ ] **delg-4.3.4** : Commit `feat: encode invocations with proof chain`

**Total Phase 4** : 15 tests, 6h

---

## Phase 5 : Tests E2E (1 jour)

### 5.1 Setup Infrastructure
- [ ] **delg-5.1.1** : Créer `storacha_test_app/scripts/setup_delegation.sh`
  - [ ] Check w3 CLI installed
  - [ ] Login/whoami
  - [ ] Create/select space
  - [ ] Get space DID
  - [ ] Get agent DID from logs
  - [ ] Create delegation
  - [ ] Output instructions
  - **Durée** : 2h

### 5.2 Tests E2E Réels
- [ ] **delg-5.2.1** : Créer `storacha_test_app/test/e2e_with_delegation_test.dart`
  - [ ] Load delegation from file
  - [ ] Initialize client with delegation
  - [ ] Test: upload small file
  - [ ] Test: upload large file
  - [ ] Test: verify via IPFS gateway
  - [ ] Test: multiple uploads
  - [ ] Test: progress tracking
  - **Tests** : 10 tests E2E
  - **Durée** : 4h

### 5.3 CI/CD
- [ ] **delg-5.3.1** : Créer `.github/workflows/e2e.yml`
  - [ ] Setup Dart
  - [ ] Setup Node + w3 CLI
  - [ ] Run E2E tests
  - **Durée** : 1h

### Phase 5 : Validation
- [ ] **delg-5.4.1** : Lancer tests E2E localement (10 tests)
- [ ] **delg-5.4.2** : Vérifier upload réel sur Storacha
- [ ] **delg-5.4.3** : Vérifier retrieval via w3s.link
- [ ] **delg-5.4.4** : Commit `test: add E2E tests with real Storacha`

**Total Phase 5** : 10 tests E2E, 7h

---

## Phase 6 : Documentation (1 jour)

### 6.1 Guide Délégations
- [ ] **delg-6.1.1** : Créer `storacha_dart/docs/DELEGATION_GUIDE.md`
  - [ ] Section: Pourquoi les délégations
  - [ ] Section: Obtenir une délégation (CLI)
  - [ ] Section: Charger une délégation (code)
  - [ ] Section: Exemples complets
  - [ ] Section: Troubleshooting
  - **Durée** : 2h

### 6.2 Mise à Jour README
- [ ] **delg-6.2.1** : Modifier `storacha_dart/README.md`
  - [ ] Section: Using with Storacha Network
  - [ ] Code example avec délégation
  - [ ] Link vers DELEGATION_GUIDE.md
  - **Durée** : 1h

### 6.3 API Documentation
- [ ] **delg-6.3.1** : Ajouter dartdocs
  - [ ] `Delegation` class
  - [ ] `Proof` class
  - [ ] `ProofChain` class
  - [ ] `DelegationParser` class
  - [ ] Methods dans `StorachaClient`
  - **Durée** : 2h

### 6.4 Examples
- [ ] **delg-6.4.1** : Créer `storacha_dart/example/delegation_example.dart`
  - [ ] Complete workflow
  - [ ] Load delegation
  - [ ] Upload file
  - [ ] Comments détaillés
  - **Durée** : 1h

### Phase 6 : Validation
- [ ] **delg-6.5.1** : Review complète documentation
- [ ] **delg-6.5.2** : Générer dartdoc HTML
- [ ] **delg-6.5.3** : Vérifier examples compile
- [ ] **delg-6.5.4** : Commit `docs: add delegation guide and examples`

**Total Phase 6** : 4 docs, 6h

---

## 🎯 Validation Finale

### Code Quality
- [ ] **delg-final-1** : Tous les tests passent (100 nouveaux)
- [ ] **delg-final-2** : `dart analyze` → 0 warnings
- [ ] **delg-final-3** : Coverage > 90%
- [ ] **delg-final-4** : Documentation complète

### Functional
- [ ] **delg-final-5** : Upload vers Storacha réel fonctionne
- [ ] **delg-final-6** : Retrieval via w3s.link fonctionne
- [ ] **delg-final-7** : Multiple spaces supportés
- [ ] **delg-final-8** : Progress tracking fonctionne

### Release
- [ ] **delg-final-9** : Update CHANGELOG.md
- [ ] **delg-final-10** : Update pubspec.yaml → v0.2.0
- [ ] **delg-final-11** : Git tag v0.2.0
- [ ] **delg-final-12** : Publish to pub.dev

---

## 📅 Planning Suggéré

### Semaine 1 (5 jours)
- **Jour 1-2** : Phase 1 (Types de Base)
- **Jour 3-5** : Phase 2 (Parsing UCAN)

### Semaine 2 (5 jours)
- **Jour 1-2** : Phase 3 (Intégration Client)
- **Jour 3-4** : Phase 4 (Encoding Invocations)
- **Jour 5** : Phase 5 (Tests E2E)

### Jour Bonus
- **Jour 11** : Phase 6 (Documentation)

---

## 🔥 Critical Path

Les tâches critiques (bloquantes) :

1. **delg-1.1.1** → Types `Delegation`
2. **delg-2.1.1** → CBOR Decoder
3. **delg-2.2.1** → CAR Decoder
4. **delg-2.3.1** → Delegation Parser
5. **delg-3.1.1** → Client integration
6. **delg-4.1.1** → Invocation encoder
7. **delg-5.2.1** → E2E tests

Tout le reste peut être fait en parallèle ou après.

---

## 📊 Métriques de Succès

### Quantitatives
- ✅ 100 nouveaux tests unitaires
- ✅ 10 tests E2E
- ✅ 0 erreurs `dart analyze`
- ✅ Coverage > 90%

### Qualitatives
- ✅ Upload vers Storacha fonctionne
- ✅ Documentation claire et complète
- ✅ API ergonomique
- ✅ Code maintenable

---

## 💡 Notes

### Dépendances
- Aucune nouvelle dépendance Dart requise
- Storacha CLI requis pour E2E tests
- Node.js requis pour CLI

### Risques
- **CBOR decoding** : Complexe, peut prendre plus de temps
- **Proof chain validation** : Logique subtile
- **CAR format** : Peut avoir des edge cases

### Optimisations Future
- Cache des délégations parsées
- Pool de workers pour validation
- Compression des proof chains

---

## ✅ Checklist Rapide

```bash
# Quick validation
□ Phase 1 : 30 tests pass
□ Phase 2 : 25 tests pass
□ Phase 3 : 20 tests pass
□ Phase 4 : 15 tests pass
□ Phase 5 : 10 E2E tests pass
□ Phase 6 : 4 docs created
□ dart analyze → 0 warnings
□ Upload to Storacha works ✅
```

---

**Status** : 📝 Planning Complete - Ready to Start  
**Next Action** : Begin Phase 1.1 - Create `Delegation` class

