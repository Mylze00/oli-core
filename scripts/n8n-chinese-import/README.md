# 🤖 Import Automatique de Produits Chinois vers Oli via n8n

Ce dossier (`scripts/n8n-chinese-import/`) contient tout le nécessaire pour automatiser la création de produits sur Oli à partir de simples captures d'écran de sites fournisseurs chinois (1688, Taobao, Alibaba).

## ✨ Fonctionnalités
- 👁️ **IA Vision (GPT-4o-mini)** : Analyse les captures d'écran pour extraire : Nom, Prix public (CNY), Description, Poids estimé, Catégorie.
- 🧮 **Calculateur de Fret Intelligent** : Convertit le prix en USD, ajoute votre marge commerciale (30%), et calcule le fret selon le poids (Aérien si < 10kg, Maritime si >= 10kg).
- 🖼️ **Association Automatique d'Images** : Lie le screenshot à ses photos propres de présentation situées dans le même dossier.
- ☁️ **Upload Cloudinary** : Envoie les photos propres sur le cloud et récupère les URLs.
- 📡 **Publication Directe** : Appelle l'API Oli pour créer le produit en temps réel.

---

## 🚀 Guide d'Installation

### 1. Prérequis
- n8n installé en local ou sur un serveur (Docker recommandé) accessible à ce dossier source (`/home/paolice-mylze/capture pindou/1`).
- Un compte OpenRouter (ou OpenAI direct) avec du crédit (coûte < 0.005$ par image avec gpt-4o-mini).
- Les accès Cloudinary de votre app Oli.

### 2. Importer le Workflow
1. Ouvrir votre interface n8n.
2. Cliquer sur **"Workflows"** -> **"Add Workflow"**.
3. En haut à droite de l'écran principal, cliquer sur les trois petits points `...` -> **"Import from File"**.
4. Sélectionner le fichier `workflow.json` contenu dans ce dossier.

### 3. Configurer les Credentials dans n8n
Une fois le workflow importé, vous verrez des nœuds d'erreur rouges car n8n a besoin de vos mots de passe :
1. **Node OpenAI (OpenRouter)** : Créer un "Header Auth Credential".
   - Name: `Authorization`
   - Value: `Bearer sk-or-v1-VOTRE_CLE_OPENROUTER`
2. **Node Cloudinary ("☁️ Préparer Upload")** : Les clés sont actuellement "hardcodées" dans le script JS. N'oubliez pas de configurer un **"Upload Preset"** "Unsigned" nommé `oli_n8n_import` dans les paramètres Cloudinary de votre compte. 

### 4. Configurer le Backend Oli
Afin que l'API Oli accepte les requêtes de n8n, nous avons créé une route `/api/n8n/import-product`.
Cette route est sécurisée par un secret.

Dans le fichier `.env` de votre projet `oli-core`, ajoutez :
```env
# Sécurité pour l'import automatisé n8n
N8N_WEBHOOK_SECRET=oli_n8n_secret_2024
```
*(C'est la même valeur que celle configurée dans le node "📡 Publier sur Oli" dans n8n. Si vous la changez ici, changez-la dans n8n aussi).*

---

## 📁 Comment organiser vos dossiers

Le workflow lit le dossier configuré : `/home/paolice-mylze/capture pindou/1`.

**Convention de nommage OBLIGATOIRE :**
- 📱 **Screenshot (pour l'IA)** : Mettez le mot `capture` dans le nom du fichier (ex: `capture_samsung_zflip.jpg`).
- 🖼️ **Images propres (pour la boutique Oli)** : Le nom du fichier DOIT commencer par `IMG_` (ex: `IMG_7684.JPG`). Ces images doivent être dans le MÊME dossier que la capture.

**Cycle de vie :**
1. L'IA lit `capture_samsung_zflip.jpg`.
2. Le script trouve toutes les photos `IMG_*.JPG` du même dossier.
3. Le produit est publié sur Oli avec ces photos `IMG_*.JPG`.
4. La capture d'écran est déplacée dans le sous-dossier `/traites/` pour ne pas être publiée en double la prochaine fois.

---

## 🧮 Configuration des Tarifs Fret

Pour modifier les tarifs sans toucher au code complexe de n8n, éditez le fichier `freight_config.json` dans ce dossier.
Le workflow calcule :
`Prix Vente Final USD = (Prix Fournisseur USD + Fret) * (1 + 30%_marge)`

Si le produit fait plus de 10kg, le fret maritime (calculé au m³) est automatiquement appliqué.
