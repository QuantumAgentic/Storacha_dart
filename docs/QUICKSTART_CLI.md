# 🚀 Storacha CLI - Quick Start

## ⚡ Setup (5 minutes)

### 1. Installer

```bash
npm install -g @storacha/cli
```

### 2. Se Connecter

```bash
w3 login votre@email.com
# Cliquez sur le lien dans votre email
```

### 3. Créer un Space

```bash
w3 space create "mon-premier-space"
```

### 4. Uploader

```bash
w3 up test.txt
```

### 5. Vérifier

Ouvrez l'URL affichée :
```
https://w3s.link/ipfs/bafybeib...
```

✅ Votre fichier est sur IPFS !

---

## 📁 Commandes Essentielles

```bash
# Upload
w3 up fichier.txt
w3 up ./dossier/
w3 up file1.txt file2.txt

# Lister
w3 ls                    # Tous les uploads
w3 space ls              # Tous les spaces

# Spaces
w3 space create "work"
w3 space use <space-did>

# Délégation (pour plus tard)
w3 delegation create \
  --can space/blob/add \
  --can upload/add \
  --audience <agent-did> \
  > delegation.ucan
```

---

## 🎯 Pour Votre App

### Générer un Agent

```bash
cd storacha_test_app
dart run bin/generate_key.dart
# Noter le DID affiché
```

### Créer une Délégation

```bash
# Script automatique
cd storacha_test_app/scripts
./setup_delegation.sh
```

Ou manuel :
```bash
w3 delegation create \
  --can space/blob/add \
  --can upload/add \
  --audience did:key:z6Mks... \
  > delegation.ucan
```

---

## 🐛 Problèmes Courants

### "w3: command not found"

```bash
npm install -g @storacha/cli
export PATH="$PATH:$(npm config get prefix)/bin"
```

### "401 Unauthorized"

```bash
w3 logout
w3 login votre@email.com
```

### "No space selected"

```bash
w3 space ls
w3 space use <space-did>
```

---

## 📚 Resources

- **Docs** : https://docs.storacha.network
- **CLI** : https://github.com/storacha/w3cli
- **Discord** : https://discord.gg/storacha

---

**Guide complet** : [../STORACHA_GUIDE.md](../../STORACHA_GUIDE.md)
