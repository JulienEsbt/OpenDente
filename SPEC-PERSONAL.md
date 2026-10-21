# OpenDente — version personnelle, première étape

Base : OpenDente GPL-3.0, commit `06c5a8199f5c0657374e667073b3aa6a75f50df8`.
Demande : une application macOS native, locale et personnalisable, centrée sur la gestion de la charge.

## Résultat attendu

- Conserver SwiftUI et le service matériel existant ; aucune télémétrie ou dépendance réseau ajoutée.
- Une interface principale française : pourcentage, état réel de la charge, plafond, seuil de reprise, température et actions explicites.
- Trois réglages rapides modifiables : Bureau 70 % / reprise sous 60 %, Quotidien 80 % / reprise sous 70 %, Mobilité 90 % / reprise sous 80 %. Ce sont des commodités, sans garantie chiffrée de durée de vie.
- Charge ponctuelle à 100 % jusqu'au débranchement ou à l'annulation ; le plafond habituel reste enregistré. La protection thermique conserve la priorité et la demande reprend après refroidissement.
- Aucun lancement automatique d'une décharge par les profils ; la décharge reste une option avancée explicite.

## Corrections nécessaires avant utilisation

1. Le service privilégié authentifie les messages par certificat et identifiant de l'application, sans contournement Debug.
2. Toute modification matérielle restrictive est précédée d'un état de récupération persistant. Une erreur partielle déclenche une restauration ; toutes les clés utiles sont tentées et les erreurs sont remontées.
3. La fin de la session de l'application efface la consigne de veille ; une ancienne connexion ne peut pas perturber une session plus récente.
4. Les arrêts pour température élevée et le délai de refroidissement passent par la vérification de l'arrêt effectif de la charge.
5. Le seuil bas reste au moins à 10 %, même avec un plafond bas et une large plage.

## Validation et limites

Tests de régression par injection d'échecs, exécutés sur les méthodes de production quand elles sont isolables sous Linux. Tests XCTest natifs fournis. Analyse syntaxique Swift de tous les fichiers modifiés.

Le conteneur de travail ne possède ni macOS, ni Xcode, ni le matériel SMC du Mac cible. Une compilation Xcode signée, le contrôle de la liaison XPC, et les essais réels de charge / débranchement / veille restent requis sur le Mac avant de qualifier la version comme prête à l'usage. La compilation locale doit utiliser le même certificat pour l'app et son service.

## Hors de cette première étape

Calibration automatique, programmation horaire, Raccourcis Apple, mise à jour automatique, publication et installation privilégiée. Ces éléments ne sont pas nécessaires pour rendre la limite, la reprise et les actions ponctuelles plus utiles et compréhensibles.

## Option native à vérifier sur le Mac cible

Apple propose une limite 80–100 % sur Apple Silicon avec macOS Tahoe 26.4 ou ultérieur : https://support.apple.com/en-us/102338 . Elle peut suffire au besoin simple de limitation ; une seule application doit gérer la politique de charge pendant les essais.
