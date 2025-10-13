# Analyse du Format de Délégation Storacha CLI

## 🔍 Format Découvert

Le format `--base64` du CLI Storacha utilise **DAG-CBOR/UCAN**, pas des JWTs simples.

### Structure du CAR

```
delegation.txt (multibase 'm' + base64)
  |
  └─> CAR file décodé
        |
        ├─> Header CAR (CBOR)
        │     - version: 1
        │     - roots: [CID du variant]
        |
        └─> Blocs
              ├─> Bloc Root (variant CBOR)
              │     { 'ucan@0.9.1': <CID-link-to-UCAN> }
              │
              ├─> Bloc UCAN (DAG-UCAN en CBOR)
              │     - Peut aussi être en format JWT encodé
              │
              └─> Blocs de Preuves (UCANs parents)
                    - Chain de délégations
```

### Référence Code (@ucanto/core/src/delegation.js)

```javascript
export const extract = async archive => {
  try {
    const { roots, blocks } = CAR.decode(archive)
    const [root] = roots
    if (root == null) {
      return Schema.error('CAR archive does not contain a root block')
    }
    const { bytes } = root
    const variant = CBOR.decode(bytes)  // Décode le variant
    const [, link] = ArchiveSchema.match(variant)  // Extrait 'ucan@0.9.1'
    return ok(view({ root: link, blocks }))
  } catch (cause) {
    return error(cause)
  }
}

export const ArchiveSchema = Schema.variant({
  'ucan@0.9.1': Schema.link({ version: 1 })
})
```

## ❌ Problème Actuel

Notre parser `Delegation.fromCarBytes()` attend :
- CAR header
- Bloc root = JWT direct

Mais le format réel est :
- CAR header
- Bloc root = variant CBOR `{'ucan@0.9.1': <link>}`  
- Bloc UCAN = format DAG-UCAN (CBOR)

## ✅ Solution

### Option A: Parser DAG-CBOR complet
Implémenter :
1. Décodeur CBOR variant
2. Extracteur de 'ucan@0.9.1'
3. Résolution du link vers le bloc UCAN
4. Parser DAG-UCAN (format CBOR, pas JWT)

**Complexité**: Élevée (~1-2 jours)
**Avantage**: Support natif du format CLI

### Option B: Bridge Node.js
Créer un utilitaire qui convertit :
```bash
# Convertir delegation.txt en JWT simple
node convert_delegation.js delegation.txt > delegation.jwt
```

**Complexité**: Faible (~30 minutes)
**Avantage**: Rapide, fonctionne immédiatement
**Inconvénient**: Nécessite Node.js installé

### Option C: Documenter l'alternative
Créer des délégations programmatiquement en Dart :
```dart
// Pas de CLI nécessaire
final delegation = await Delegation.create(
  issuer: spaceSigner,
  audience: agentDid,
  capabilities: [
    Capability(
      with_: spaceDid,
      can: 'space/blob/add',
    ),
  ],
);
```

**Complexité**: Déjà implémenté !
**Avantage**: Contrôle total en Dart
**Inconvénient**: Pas d'interop avec CLI existant

## 🎯 Recommandation

**Pour l'instant (v0.2.0)** : Option B (Bridge Node.js)
- Permet de tester immédiatement avec votre delegation.txt
- Simple et rapide à implémenter

**Pour le futur (v0.3.0)** : Option A (Parser DAG-CBOR)
- Support natif complet
- Pas de dépendances externes
- Meilleure intégration

## 📚 Références

- **@ucanto/core**: `node_modules/@ucanto/core/src/delegation.js`
- **Format UCAN**: https://github.com/ucan-wg/spec
- **DAG-CBOR**: https://ipld.io/specs/codecs/dag-cbor/
- **CAR**: https://ipld.io/specs/transport/car/

## ✅ Ce qui fonctionne déjà

- ✅ Création de délégations programmatiques en Dart
- ✅ Upload avec UCANs
- ✅ Parsing JWT UCANs simples
- ✅ Toutes les fonctionnalités IPFS/CAR/UnixFS
- ✅ 581 tests unitaires passent

## ❌ Ce qui reste à faire

- ❌ Parser format DAG-CBOR/UCAN du CLI
- ❌ Résolution des proof chains complexes
- ❌ Support natif `delegation.txt` --base64

