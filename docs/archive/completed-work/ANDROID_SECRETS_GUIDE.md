# GitHub Secrets à ajouter pour Android Build

Aller sur https://github.com/pistisAI/pistisai-app/settings/secrets/actions

Ajouter ces 4 secrets:

| Nom | Valeur |
|-----|--------|
| `ANDROID_KEYSTORE_B64` | Le contenu du fichier (base64 du keystore) — voir ci-dessous |
| `ANDROID_STORE_PASSWORD` | `Pistisai!2026` |
| `ANDROID_KEY_PASSWORD` | `Pistisai!2026` |
| `ANDROID_KEY_ALIAS` | `zoidbot-release` |

## Pour ANDROID_KEYSTORE_B64

> **Note**: Les mots de passe ci-dessus ont été renommés de `Cloud2LocalLLM!2026` à `Pistisai!2026`.
> Le keystore doit être **régénéré** avec le nouveau mot de passe avant le prochain build Android signé.
> Voir la section régénération ci-dessous.

Sur RIGHT-PC:
```bash
base64 -w0 ~/Pistisai/android/release-keystore.jks | wl-copy  # ou xclip
```

Puis coller dans le champ GitHub.

## Prochain push sur main

Après ça, n'importe quel push sur `main` qui touche `lib/` va trigger le deployment workflow complet — Linux, Windows, **et Android APK** dans les releases.

## Régénérer le keystore avec le nouveau mot de passe

```bash
keytool -genkey -v -keystore ~/Pistisai/android/release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias zoidbot-release \
  -storepass 'Pistisai!2026' -keypass 'Pistisai!2026' \
  -dname "CN=Pistisai, O=Pistisai, C=CA"
```

Puis re-encoder en base64 et mettre à jour le secret `ANDROID_KEYSTORE_B64` sur GitHub.
