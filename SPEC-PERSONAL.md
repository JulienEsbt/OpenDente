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

## Extension expérimentale autorisée le 21 octobre 2026

Après constat de l’absence des clés SMC de contrôle sur le MacBook Air M3 sous macOS 27.2, le propriétaire a choisi de préparer un mode natif expérimental, avec ses limites clairement affichées.

- Activation explicite, désactivée par défaut ; helper 1.5.0 signé et authentifié.
- Plafond transmis à PowerUI, sans coupure de l’adaptateur, sans modification d’archives powerd ni d’autorisations privées.
- Refus côté service d’une cible inférieure au niveau courant ; conservation du réglage Apple avant toute modification, récupération persistante et restauration sur toutes les sorties normales/erreurs.
- Affichage de la consigne séparé des mesures réelles. Délai possible d’environ une minute ; reprise et calibration décidées par macOS.
- Seuil de reprise et protection thermique personnalisés désactivés dans ce mode ; aucune promesse d’arrêt thermique immédiat. Les profils choisissent le plafond et ne forcent pas de décharge.
- Les protections SMC précédentes restent en place sur le matériel exposant encore les anciennes clés.

Debug/Release compilent, la Release est signée, et 313 tests XCTest réussissent (299 précédents conservés, 14 supplémentaires). La validation matérielle effective est suivie dans `VALIDATION.md`. Le paragraphe suivant décrit la préparation Linux initiale, pas l’état actuel de la compilation native.

## Validation et limites

Tests de régression par injection d'échecs, exécutés sur les méthodes de production quand elles sont isolables sous Linux. Tests XCTest natifs fournis. Analyse syntaxique Swift de tous les fichiers modifiés.

Le conteneur de travail ne possède ni macOS, ni Xcode, ni le matériel SMC du Mac cible. Une compilation Xcode signée, le contrôle de la liaison XPC, et les essais réels de charge / débranchement / veille restent requis sur le Mac avant de qualifier la version comme prête à l'usage. La compilation locale doit utiliser le même certificat pour l'app et son service.

## Hors de cette première étape

Calibration automatique, programmation horaire, Raccourcis Apple, mise à jour automatique, publication et installation privilégiée. Ces éléments ne sont pas nécessaires pour rendre la limite, la reprise et les actions ponctuelles plus utiles et compréhensibles.

## Option native à vérifier sur le Mac cible

Apple propose une limite 80–100 % sur Apple Silicon avec macOS Tahoe 26.4 ou ultérieur : https://support.apple.com/en-us/102338 . Elle peut suffire au besoin simple de limitation ; une seule application doit gérer la politique de charge pendant les essais.
