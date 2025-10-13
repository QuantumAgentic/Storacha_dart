# État du support des délégations

## ✅ Fonctionnel

### Création programmatique de délégations
Le package supporte complètement la création de délégations en Dart :

```dart
import 'package:storacha_dart/storacha_dart.dart';

// Créer une délégation programmatiquement
final issuer = await Ed25519Signer.generate();
final audience = await Ed25519Signer.generate();

final delegation = await UCAN.build(
  issuer: issuer,
  audience: audience.did(),
  capabilities: [
    Capability(
      with_: 'did:key:z6Mkk...',  // Space DID
      can: 'space/blob/add',
    ),
    Capability(
      with_: 'did:key:z6Mkk...',
      can: 'upload/add',
    ),
  ],
  expiration: DateTime.now().add(Duration(days: 30)),
);

// Utiliser avec le client
final client = StorachaClient(config);
client.addDelegation(Delegation(ucan: delegation));
```

## ⚠️ En cours de développement

### Chargement de délégations depuis le CLI Storacha

Le chargement de délégations créées par `storacha delegation create` nécessite un décodeur DAG-CBOR/UCAN complet.

**Format utilisé par le CLI** :
- **Sans `--base64`** : Fichier CAR avec UCANs encodés en DAG-CBOR
- **Avec `--base64`** : Identity CID contenant un CAR avec UCANs en DAG-CBOR

**État actuel** :
- ✅ Décodeur CAR fonctionnel (basé sur @ipld/car)
- ✅ Décodeur DAG-CBOR basique (pour headers CAR)
- ❌ Décodeur UCAN DAG-CBOR complet (nécessaire pour lire les UCANs)

**Raison** : Les UCANs du CLI Storacha sont encodés en DAG-CBOR, pas en JWT. Cela nécessite un décodeur UCAN DAG-CBOR complet qui peut :
1. Décoder la structure CBOR de l'UCAN
2. Extraire et vérifier les signatures  
3. Reconstruire la chaîne de preuves

## 🎯 Recommandation actuelle

**Pour l'instant, créez vos délégations directement en Dart plutôt que via le CLI.**

Avantages :
- ✅ Contrôle total sur les délégations
- ✅ Pas de dépendance au CLI
- ✅ Plus simple et plus rapide
- ✅ Fonctionne sur toutes les plateformes (mobile, web, desktop)

## 🚀 Prochaines étapes

Pour supporter complètement le chargement depuis le CLI :

1. Implémenter un décodeur UCAN DAG-CBOR complet
2. Gérer la validation des signatures Ed25519 en CBOR
3. Supporter la reconstruction de la chaîne de preuves
4. Tester avec divers types de délégations

**Estimation** : 1-2 jours de travail supplémentaire

## 📚 Références

- Format DAG-CBOR : https://ipld.io/specs/codecs/dag-cbor/
- UCAN Spec : https://github.com/ucan-wg/spec
- @ipld/dag-ucan : https://github.com/web3-storage/ucanto/tree/main/packages/core
- Client de référence : Voir `reference_js_client/` dans ce projet

