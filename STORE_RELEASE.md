# CAA 1.0 — préparation à la publication

## Identité
Nom public : CAA 1.0
Version : 1.0.0
Catégorie : Accessibilité / Communication

## Android / Google Play
Publier un Android App Bundle (AAB) :
`flutter build appbundle --release`

Un compte Google Play Console et une signature de publication sont requis.

## Windows / Microsoft Store
Construire la version Windows :
`flutter build windows --release`

Pour le Microsoft Store, préparer ensuite un paquet MSIX signé et la fiche Store.

## iOS / App Store
Le projet Flutter doit être ouvert sur macOS avec Xcode pour générer l'archive iOS.
Une signature Apple Developer et une soumission App Store Connect sont nécessaires.

## Important
Les pictogrammes ARASAAC restent soumis à leurs conditions de licence et d'attribution. Vérifier les droits des ressources utilisées avant une publication commerciale.
