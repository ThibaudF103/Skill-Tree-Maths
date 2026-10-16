# Verger sur iPad avec TestFlight

La CI compile l'appli iPad sur une machine macOS de GitHub, la signe et
l'envoie à TestFlight à chaque fusion dans `main`. Pas besoin de Mac : la
configuration ci-dessous se fait une seule fois, depuis Windows et un
navigateur.

Identifiant de l'appli (*bundle ID*) : `io.github.thibaudf103.verger`.

## 1. Compte Apple Developer

1. S'inscrire au programme sur <https://developer.apple.com/programs/enroll/>
   (99 € par an, en tant que particulier). La validation peut prendre
   jusqu'à 48 heures.
2. Team ID : `B37Y3K6Z76`, déjà inscrit dans la CI (`.github/workflows/ci.yml`).

## 2. Identifiant de l'appli

<https://developer.apple.com/account/resources/identifiers/list> → **+** →
*App IDs* → *App* :

- Description : `Verger`
- Bundle ID : *Explicit*, `io.github.thibaudf103.verger`
- Aucune option à cocher → *Register*.

## 3. Fiche de l'appli dans App Store Connect

<https://appstoreconnect.apple.com/apps> → **+** → *Nouvelle app* :

- Plateforme : iOS
- Nom : un nom libre sur l'App Store (« Verger » est peut-être pris :
  essayez par exemple « Verger – Agrégation »). Il n'apparaît que dans
  TestFlight tant que l'appli n'est pas publiée.
- Langue principale : français
- Bundle ID : celui de l'étape 2
- SKU : `verger`
- Accès : complet.

## 4. Certificat de distribution (depuis Windows)

Dans **Git Bash** (installé avec Git), à la racine du dépôt :

```bash
tools/ios/certificat.sh demande
```

Le script crée `verger.key` (clé privée, à garder pour vous) et
`verger.csr` dans le dossier `~/verger-ios`.

1. <https://developer.apple.com/account/resources/certificates/list> → **+**
   → *Apple Distribution* → téléverser `verger.csr` → télécharger le
   certificat (`distribution.cer`).
2. De retour dans Git Bash :

   ```bash
   tools/ios/certificat.sh p12 ~/Downloads/distribution.cer
   ```

   Le script affiche le mot de passe du certificat (secret
   `IOS_P12_PASSWORD`) et crée `verger.p12`.

## 5. Profil de provisionnement

<https://developer.apple.com/account/resources/profiles/list> → **+** →
*Distribution* → *App Store Connect* :

- App ID : `io.github.thibaudf103.verger`
- Certificat : celui de l'étape 4
- Nom du profil : **`Verger App Store`** (exactement : la CI le cherche
  sous ce nom)
- Télécharger le fichier `.mobileprovision`.

## 6. Clé d'API App Store Connect

<https://appstoreconnect.apple.com/access/integrations/api> → onglet
*Clés d'équipe* (demander l'accès la première fois) → **+** :

- Nom : `CI Verger`
- Accès : *App Manager*
- Télécharger la clé `AuthKey_XXXXXXXXXX.p8` (une seule fois possible).
- Noter l'**ID de clé** et l'**ID de l'émetteur** (*Issuer ID*, en haut de
  la page).

## 7. Secrets GitHub

<https://github.com/ThibaudF103/Skill-Tree-Maths/settings/secrets/actions>
→ *New repository secret*, pour chacun :

| Secret | Valeur |
|---|---|
| `IOS_P12_BASE64` | sortie de `tools/ios/certificat.sh base64 ~/verger-ios/verger.p12` |
| `IOS_P12_PASSWORD` | mot de passe affiché à l'étape 4 |
| `IOS_PROFILE_BASE64` | sortie de `tools/ios/certificat.sh base64 ~/Downloads/Verger_App_Store.mobileprovision` |
| `ASC_KEY_ID` | ID de clé (étape 6) |
| `ASC_ISSUER_ID` | ID de l'émetteur (étape 6) |
| `ASC_KEY_P8` | contenu complet du fichier `.p8` (l'ouvrir avec le Bloc-notes, tout copier, lignes `BEGIN` / `END` comprises) |

## 8. Premier envoi

<https://github.com/ThibaudF103/Skill-Tree-Maths/actions/workflows/ci.yml>
→ *Run workflow* (branche `main`). Le job « TestFlight (iPad) » dure
environ 20 minutes. Ensuite, chaque fusion dans `main` envoie une nouvelle
version.

Apple traite la version en 5 à 30 minutes. Puis, dans App Store Connect →
votre appli → **TestFlight** :

1. *Testeurs internes* → **+** → créer un groupe et vous y ajouter.
2. Sur l'iPad : installer l'appli **TestFlight** depuis l'App Store, se
   connecter avec le même identifiant Apple, puis installer Verger.

Les versions suivantes arrivent toutes seules dans TestFlight (une
notification propose la mise à jour). Une version de test expire au bout
de 90 jours ; chaque fusion en produit une nouvelle.

## En cas d'échec

- **Profil ou certificat introuvable** : vérifier le nom exact du profil
  (`Verger App Store`) et que le profil utilise bien le certificat de
  l'étape 4.
- **Certificat expiré** (après un an) : refaire les étapes 4, 5 et 7.
- **Envoi refusé pour un numéro de version déjà utilisé** : relancer le
  workflow (le numéro suit celui de l'exécution de la CI).
