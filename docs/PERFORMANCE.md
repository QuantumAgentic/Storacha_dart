# 📱 Performance Optimization for iOS & Android

> **Optimisations spécifiques pour garantir des performances maximales sur mobile**

## 🎯 Objectifs de Performance

- ⚡ **Uploads rapides** : Minimiser le temps d'upload même sur connexion mobile
- 🔋 **Économie de batterie** : Réduire la consommation CPU/réseau
- 💾 **Gestion mémoire** : Supporter des fichiers de plusieurs Go sans OOM
- 📶 **Réseau adaptatif** : S'adapter aux changements WiFi ↔ Cellular
- 🔄 **Background processing** : Continuer les uploads en arrière-plan

---

## 🏗️ Architecture pour Mobile

### 1. **Streaming & Chunking**

✅ **Déjà implémenté** : `BlobLike.stream()` pour lecture par chunks

```dart
// ✅ GOOD: Stream par chunks (pas de chargement complet en mémoire)
final blob = MemoryBlob(bytes: largeFileBytes);
await for (final chunk in blob.stream()) {
  // Traite chunk par chunk (256 KiB max)
}

// ❌ BAD: Charger tout en mémoire d'un coup
final allData = await file.readAsBytes(); // OOM sur gros fichiers !
```

**Impact iOS/Android** :
- iOS : Respecte les limites mémoire strictes (limite ~1.5 GB pour apps)
- Android : Évite les `OutOfMemoryError` sur devices low-end

### 2. **Isolates pour Opérations Lourdes**

🔄 **À implémenter** : Utiliser Dart Isolates pour :
- Hash SHA-256 de gros fichiers
- Encoding UnixFS DAG
- Compression CAR files

```dart
// Exemple futur pour hashing en isolate
Future<MultihashDigest> sha256HashIsolated(Uint8List data) async {
  return await compute(_sha256Worker, data);
}

MultihashDigest _sha256Worker(Uint8List data) {
  return sha256Hash(data); // Execute dans isolate séparé
}
```

**Impact iOS/Android** :
- iOS : Garde le UI thread responsive (60 FPS)
- Android : Évite les ANR (Application Not Responding)

### 3. **Gestion Adaptative du Réseau**

🔄 **À implémenter** : Détection et adaptation réseau

```dart
// Stratégie d'upload selon type de connexion
class NetworkAwareUploadOptions extends UploadOptions {
  final bool preferWiFi;           // Pause sur cellular si true
  final int maxCellularShardSize;  // Plus petit sur cellular
  final bool pauseOnBatteryLow;   // Pause si batterie < 20%
  
  const NetworkAwareUploadOptions({
    this.preferWiFi = true,
    this.maxCellularShardSize = 10 * 1024 * 1024, // 10 MB
    this.pauseOnBatteryLow = true,
    super.shardSize = 100 * 1024 * 1024, // 100 MB sur WiFi
  });
}
```

**Packages recommandés** :
- `connectivity_plus` : Détecter WiFi/Cellular/None
- `battery_plus` : Monitorer niveau batterie
- `network_info_plus` : Info détaillées réseau

### 4. **Background Processing**

🔄 **À implémenter** : Support uploads en arrière-plan

**iOS** :
- Utiliser `background_fetch` pour tasks périodiques
- `workmanager` pour uploads persistants

**Android** :
- `WorkManager` pour uploads robustes
- Foreground Service pour uploads visibles

```dart
// Exemple configuration WorkManager
await Workmanager().registerOneOffTask(
  'upload-task-$uuid',
  'storachaUpload',
  inputData: {
    'filePath': filePath,
    'spaceDid': spaceDid,
  },
  constraints: Constraints(
    networkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  ),
);
```

---

## 💾 Optimisations Mémoire

### Stratégies Implémentées

#### 1. **Streaming Architecture**
```dart
// ✅ Implémenté: Stream interface
abstract class BlobLike {
  Stream<Uint8List> stream(); // Pas de chargement complet
  int? get size;
}
```

#### 2. **Lazy Loading**
```dart
// Pour gros fichiers, créer un FileBlob qui lit depuis disque
class FileBlob implements BlobLike {
  final File file;
  
  @override
  Stream<Uint8List> stream() async* {
    final stream = file.openRead();
    await for (final chunk in stream) {
      yield Uint8List.fromList(chunk);
    }
  }
  
  @override
  int? get size => file.lengthSync();
}
```

### Limites Mémoire par Platform

| Platform | Limite Typique | Recommandation Chunk Size |
|----------|----------------|---------------------------|
| iOS      | ~1.5 GB        | 256 KiB - 1 MB           |
| Android  | ~512 MB - 2 GB | 256 KiB - 512 KiB        |

---

## 🔋 Économie de Batterie

### Stratégies

#### 1. **Batching Réseau**
```dart
// Grouper les petits uploads en un seul batch
class BatchedUploadStrategy {
  final List<BlobLike> _pendingUploads = [];
  Timer? _batchTimer;
  
  void scheduleUpload(BlobLike blob) {
    _pendingUploads.add(blob);
    
    // Batch après 5 secondes ou 10 fichiers
    _batchTimer ??= Timer(Duration(seconds: 5), _executeBatch);
    if (_pendingUploads.length >= 10) {
      _executeBatch();
    }
  }
}
```

#### 2. **Wake Lock Intelligent**
```dart
// Utiliser wake_lock uniquement pendant upload actif
import 'package:wake_lock/wake_lock.dart';

Future<void> uploadWithWakeLock(BlobLike blob) async {
  await WakeLock.enable();
  try {
    await client.uploadFile(blob);
  } finally {
    await WakeLock.disable();
  }
}
```

#### 3. **Compression Adaptative**
```dart
// Compresser davantage sur cellular pour économiser data/batterie
UploadOptions getAdaptiveOptions(ConnectivityResult connectivity) {
  if (connectivity == ConnectivityResult.mobile) {
    return UploadOptions(
      shardSize: 10 * 1024 * 1024,  // 10 MB
      dedupe: true,                  // Crucial sur cellular
    );
  }
  return UploadOptions(
    shardSize: 100 * 1024 * 1024, // 100 MB
  );
}
```

---

## 📶 Gestion Réseau

### Retry Strategy

```dart
class ExponentialBackoffRetry {
  static const maxRetries = 5;
  static const baseDelay = Duration(seconds: 1);
  
  static Future<T> execute<T>(Future<T> Function() action) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        
        // Backoff exponentiel: 1s, 2s, 4s, 8s, 16s
        final delay = baseDelay * (1 << attempt);
        await Future.delayed(delay);
      }
    }
  }
}
```

### Timeouts Adaptatifs

```dart
Duration getTimeout(ConnectivityResult connectivity) {
  switch (connectivity) {
    case ConnectivityResult.wifi:
      return Duration(seconds: 30);
    case ConnectivityResult.mobile:
      return Duration(seconds: 60);  // Plus lent sur 4G
    case ConnectivityResult.ethernet:
      return Duration(seconds: 20);
    default:
      return Duration(seconds: 45);
  }
}
```

---

## 🎨 UI/UX Performance

### 1. **Progress Updates Throttlés**

```dart
// Limiter les updates UI à 60 FPS max
class ThrottledProgressCallback {
  DateTime? _lastUpdate;
  static const _minInterval = Duration(milliseconds: 16); // ~60 FPS
  
  void Function(ProgressStatus) call(
    void Function(ProgressStatus) callback,
  ) {
    return (status) {
      final now = DateTime.now();
      if (_lastUpdate == null || 
          now.difference(_lastUpdate!) >= _minInterval) {
        callback(status);
        _lastUpdate = now;
      }
    };
  }
}

// Usage
final throttled = ThrottledProgressCallback();
await client.uploadFile(
  file,
  options: UploadFileOptions(
    onUploadProgress: throttled((status) {
      setState(() => progress = status.percentage ?? 0);
    }),
  ),
);
```

### 2. **Notification Persistence**

```dart
// Afficher notification pendant upload background
class UploadNotification {
  static Future<void> show(String fileName, double progress) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: fileName.hashCode,
        channelKey: 'storacha_uploads',
        title: 'Uploading $fileName',
        body: '${progress.toStringAsFixed(0)}% complete',
        notificationLayout: NotificationLayout.ProgressBar,
        progress: progress.toInt(),
        locked: true, // Empêche dismiss pendant upload
      ),
    );
  }
}
```

---

## 🔍 Monitoring & Profiling

### Métriques à Tracker

```dart
class UploadMetrics {
  final Duration duration;
  final int bytesTransferred;
  final int retries;
  final String networkType;
  final double batteryLevel;
  
  double get throughput => 
      bytesTransferred / duration.inSeconds; // bytes/sec
  
  double get efficiency => 
      bytesTransferred / (batteryLevel * 100); // bytes per % battery
}
```

### Outils Recommandés

- **Flutter DevTools** : Memory profiler, Timeline
- **Xcode Instruments** (iOS) : Time Profiler, Allocations
- **Android Studio Profiler** : Memory, CPU, Network
- **Firebase Performance Monitoring** : Métriques en production

---

## 📋 Checklist Performance Mobile

### Phase Implémentation

- [x] Streaming architecture (BlobLike.stream)
- [x] Options configurables (chunk size, dedupe)
- [ ] Isolates pour hashing SHA-256
- [ ] Isolates pour UnixFS encoding
- [ ] FileBlob pour lecture depuis disque
- [ ] Network detection (WiFi/Cellular)
- [ ] Battery monitoring
- [ ] Background upload support
- [ ] Wake lock management
- [ ] Retry avec exponential backoff
- [ ] Progress throttling
- [ ] Upload queue management

### Phase Testing

- [ ] Test avec fichiers 1 GB+ sur iPhone SE (low memory)
- [ ] Test avec fichiers 5 GB+ sur Android (SD card)
- [ ] Test uploads simultanés (3-5 fichiers)
- [ ] Test passage WiFi → Cellular pendant upload
- [ ] Test background upload (app minimisée)
- [ ] Test avec batterie faible (<20%)
- [ ] Profile memory avec Flutter DevTools
- [ ] Vérifier pas de memory leaks
- [ ] Benchmark temps upload vs JS client

### Phase Production

- [ ] Documentation API mobile-specific
- [ ] Exemples iOS/Android dans `/example`
- [ ] CI/CD avec tests iOS/Android
- [ ] Performance monitoring (Firebase/Sentry)
- [ ] Crash reporting
- [ ] Analytics uploads (success rate, durée moyenne)

---

## 🎯 Benchmarks Cibles

| Métrique | iOS | Android | Note |
|----------|-----|---------|------|
| **Upload 100 MB** | < 30s | < 35s | WiFi |
| **Upload 1 GB** | < 5 min | < 6 min | WiFi |
| **Memory peak** | < 50 MB | < 80 MB | Pendant upload |
| **CPU usage** | < 30% | < 40% | Moyenne |
| **Battery drain** | < 5% | < 8% | Par GB uploadé |
| **Success rate** | > 99% | > 98% | Sur connexion stable |

---

## 📚 Ressources

### Packages Recommandés

- `connectivity_plus`: Network detection
- `battery_plus`: Battery monitoring  
- `workmanager`: Background tasks
- `wake_lock`: Keep device awake
- `path_provider`: File system access
- `shared_preferences`: Settings persistence
- `flutter_local_notifications`: Upload notifications

### Documentation

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf)
- [iOS Background Execution](https://developer.apple.com/documentation/backgroundtasks)
- [Android WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager)
- [Dart Isolates](https://dart.dev/guides/language/concurrency)

---

## 💡 Notes de Design

### Pourquoi Dart/Flutter est Idéal pour Storacha Mobile

1. **Single Codebase** : iOS + Android avec une seule implémentation
2. **Performance Native** : AOT compilation → performance proche du natif
3. **Isolates** : Threading efficace pour CPU-intensive tasks
4. **Async/Await** : Gestion élégante des opérations I/O
5. **Hot Reload** : Développement rapide
6. **Null Safety** : Moins de crashes en production

### Trade-offs

| Aspect | Avantage | Limitation |
|--------|----------|------------|
| Memory | Stream architecture efficace | Peak memory pour hashing |
| CPU | Isolates pour parallélisme | Overhead context switching |
| Network | Dio pour HTTP performant | Pas de contrôle TCP bas niveau |
| Storage | Platform channels pour natif | Complexité cross-platform |

---

**Dernière mise à jour** : 2025-10-11  
**Prochaine révision** : Après implémentation UnixFS/CAR

