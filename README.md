# CAA 1.0 — Android

Projet CAA 1.0 préparé uniquement pour Android.

## Ce que GitHub Actions construit
- **APK** : installation directe sur un téléphone/tablette Android.
- **AAB** : format destiné à Google Play.

## Construction sans installer Flutter
1. Mettre ce projet dans le dépôt GitHub.
2. Aller dans **Actions**.
3. Ouvrir **Build CAA 1.0 Android**.
4. Cliquer sur **Run workflow**.
5. Attendre la fin de la compilation.
6. Ouvrir les **Artifacts**.
7. Télécharger **CAA-1.0-Android-APK**.
8. Décompresser le ZIP pour obtenir `app-release.apk`.

Pour Google Play, l'application devra ensuite être configurée et signée avec une clé de publication.
