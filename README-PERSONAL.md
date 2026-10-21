# OpenDente — édition personnelle

Version de développement **0.2.0**, préparée le 21 octobre 2026 à partir d’[OpenDente](https://github.com/killerk3emstar/OpenDente), révision `06c5a8199f5c0657374e667073b3aa6a75f50df8`.

Cette édition contient les sources modifiées, les tests et un script de compilation. **La compilation complète et les essais sur macOS restent à effectuer.** Aucun binaire macOS signé ou notarifié n’est fourni.

## Ce que cette version change

L’application conserve son interface native SwiftUI dans la barre de menus. Le panneau principal est en français, avec un pourcentage lisible, le plafond habituel, le seuil réel de reprise, les mesures de batterie disponibles et des messages expliquant pourquoi la charge est interrompue ou attendue. Un arrêt demandé reste distingué d’un arrêt confirmé par les données de la batterie.

| Profil | Plafond | Reprise lorsque le niveau passe sous |
|---|---:|---:|
| Bureau | 70 % | 60 % |
| Quotidien | 80 % | 70 % |
| Mobilité | 90 % | 80 % |

Ces profils sont des points de départ modifiables. Ils activent la protection thermique et la plage de reprise, et désactivent la décharge automatique. Ils ne constituent pas une promesse de durée de vie supplémentaire. Le réglage par défaut reste 80 % ; les valeurs libres existantes restent disponibles.

**« Charger à 100 % cette fois »** conserve le plafond habituel. La demande dure jusqu’au débranchement, à l’annulation, à l’arrêt de l’application ou au démarrage explicite d’une décharge. Elle attend pendant une pause thermique, puis reprend après refroidissement et expiration du délai. Annuler la charge ponctuelle n’annule pas la protection thermique. Une mesure de température perdue pendant cette pause ne suffit pas à autoriser la reprise.

La plage de reprise laisse le niveau baisser naturellement. Les profils ne provoquent pas de décharge forcée pour atteindre un plafond plus bas. La décharge manuelle reste accessible dans les actions secondaires.

Le compteur de cycles, la capacité, la température, la puissance et le schéma d’alimentation utilisent les données déjà disponibles dans OpenDente. Les valeurs absentes restent absentes. Aucun appel réseau, outil d’analytics ou système de mise à jour automatique n’a été ajouté.

## Corrections de l’audit

- **Authentification du service privilégié :** identifiant de l’app et certificat de signature identique à celui du service, contrôlés par l’API publique `NSXPCConnection.setCodeSigningRequirement`. Aucun contournement Debug. Une simple connexion ne devient pas un client actif ; les anciennes connexions ne doivent pas perturber la nouvelle.
- **Récupération matérielle :** l’intention restrictive est persistée avant l’écriture ; les valeurs sont relues ; une erreur partielle déclenche une restauration. Chaque clé de restauration est tentée, même si la première échoue. Les erreurs sont retournées au lieu d’un succès systématique.
- **Restauration incomplète :** le service conserve l’état de récupération et retente la restauration, y compris lorsque l’app répond encore au watchdog.
- **Veille :** la politique de veille est effacée au reset et à la déconnexion ; elle ne s’applique plus sans client actif. Une simple demande de veille annulable ne suspend plus le watchdog.
- **Température :** la vérification de l’arrêt réel de charge s’exécute aussi pendant les branches de chaleur et de refroidissement. Un échec de commande conserve la pause thermique.
- **Seuil bas :** il reste au minimum à 10 %, y compris avec un plafond de 20 % et une plage de 25 points.
- **Compatibilité du service :** les commandes de politique de charge attendent un handshake avec le service 1.4.0 ou ultérieur. Une ancienne version affiche une erreur explicite. Les commandes de restauration restent disponibles pour revenir aux réglages macOS.

Ces changements corrigent des chemins précis du code. Ils ne garantissent pas l’absence d’autres défauts ni la compatibilité avec un matériel non testé.

## Compiler et tester sur le Mac

### Prérequis

- Mac avec Xcode et compilateur Swift 6 ; le projet cible macOS 14 ou ultérieur.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), utilisé par le projet amont. Suivre son installation officielle si la commande `xcodegen` n’est pas disponible.
- Une **identité de signature avec certificat et clé privée** pour les deux cibles. Le Team ID de l’auteur amont a été retiré.

Une identité Apple Development existante convient à la préparation d’un build local. Une identité locale de signature de code peut également satisfaire l’exigence de certificat ; son fonctionnement avec SMAppService doit être vérifié sur le Mac. Apple décrit les identités locales dans [TN2206](https://developer.apple.com/library/archive/technotes/tn2206/). La signature ad hoc `-` est refusée par le service. Le script n’effectue aucune inscription payante et ne crée pas de certificat.

Lister les identités déjà disponibles :

```sh
security find-identity -v -p codesigning
```

Depuis le dossier des sources :

```sh
bash scripts/build-local.sh "Nom exact du certificat"
```

Avec une identité Apple nécessitant un Team ID :

```sh
bash scripts/build-local.sh "Apple Development: …" "TEAMID"
```

Le script génère le projet Xcode, lance la suite XCTest native, construit les deux cibles avec la même identité, vérifie leurs signatures et compare leurs certificats. Il ne lance pas l’application et n’enregistre pas le service privilégié. La première exécution Xcode peut nécessiter une autorisation d’accès à la clé privée dans le Trousseau.

L’application construite se trouve dans :

```text
build/DerivedData/Build/Products/Debug/OpenDente.app
```

Pour travailler dans Xcode : `xcodegen generate`, puis ouvrir `OpenDente.xcodeproj`. Sélectionner le schéma OpenDente et la même identité de signature pour l’application, le helper et les tests. Le numéro de build reste numérique ; un hash Git est enregistré séparément lorsqu’un dépôt Git est présent.

### Essais natifs avant usage quotidien

Le modèle, la puce et la version exacte de macOS doivent être consignés. Le projet amont est une bêta dont la documentation cite un test sur M4/Tahoe ; les essais portables n’élargissent pas cette compatibilité.

1. Faire réussir les tests Xcode et vérifier le rendu du panneau, les réglages, le clavier et les tailles de texte.
2. Placer l’app construite à son emplacement définitif avant le premier lancement. Vérifier l’autorisation de son service dans les éléments d’ouverture de macOS. En cas d’ancien service, utiliser **Réinstaller le service** dans les réglages de cette édition.
3. Vérifier qu’un seul outil gère la politique de charge pendant les essais. L’app signale un conflit avec la limite native lorsqu’elle le détecte ; elle ne modifie pas automatiquement les réglages de macOS.
4. Observer une limite atteinte, la baisse naturelle sous le seuil de reprise et la charge ponctuelle. Vérifier l’annulation et le débranchement. Utiliser les tests simulés pour les températures anormales ; il n’est pas nécessaire de chauffer volontairement le Mac.
5. Vérifier la veille, le réveil et l’arrêt de l’app : quitter doit demander le retour au comportement macOS, et une veille ultérieure ne doit pas réactiver l’ancienne politique.
6. Effectuer les contrôles d’identité du service décrits dans `tests/helper/README.md`, en Debug et Release. La validation des signatures locales ne remplace pas le test de rejet d’un autre client.

Si une commande reste sans effet, l’état réel et les diagnostics priment sur le mode demandé. Ne pas qualifier ce build de prêt à l’usage avant les essais natifs.

## Tests reproductibles sans matériel

Avec Python 3 et Swift 6 disponibles :

```sh
python3 tests/portable/run.py
python3 tests/helper/run_tests.py
```

Le premier banc extrait les méthodes de décision de production et remplace les frontières macOS par des collaborateurs inertes. Le second compile le contrôleur matériel de production et extrait les méthodes de cycle de vie du service. Chaque banc conserve les sources utilisées, leurs hachages et les résultats. Ils ne lancent aucun service et n’écrivent pas dans le SMC.

Le contrôle négatif sur la révision d’origine exige l’historique Git fourni dans le bundle de l’archive :

```sh
python3 tests/portable/run.py \
  --source-ref 06c5a8199f5c0657374e667073b3aa6a75f50df8 \
  --output .build/portable-baseline
```

Les échecs de ce contrôle négatif sont attendus : ils reproduisent les défauts précédents. Le bilan exact exécuté figure dans `VALIDATION.md` et dans les preuves jointes à l’archive.

## Option native et autres projets examinés

Sur Apple Silicon avec **macOS Tahoe 26.4 ou ultérieur**, Apple fournit une limite 80–100 %, une reprise après une baisse de plus de 5 points et une commande de charge complète ponctuelle. Cette option peut suffire au besoin simple de limitation : [documentation Apple](https://support.apple.com/en-us/102338).

La comparaison documentaire complémentaire a porté sur :

- [Battery Toolkit](https://github.com/mhaeuser/Battery-Toolkit) : libre, BSD-3-Clause, archivé le 21 mars 2026.
- [battery](https://github.com/actuallymentor/battery) : libre, MIT, interface Electron ; son README déclare des connexions d’analytics et de connectivité. Il s’agit d’un autre projet que `batt`.
- [bclm](https://github.com/zackelia/bclm) : libre, MIT ; son README indique une incompatibilité avec macOS 15 et ultérieur dans la configuration normale de sécurité.
- [BatFi](https://micropixels.software/batfi/) : la page actuelle annonce une licence à 15 dollars ; aucune base source libre à reprendre n’a été identifiée dans cette comparaison.

Cette comparaison n’est pas un audit de sécurité de ces quatre projets. Elle n’a pas mis en évidence une meilleure base pour cette personnalisation native d’OpenDente.

## Suite éventuelle

La planification horaire, les Raccourcis Apple et un historique de mesures pourront être ajoutés si l’usage les justifie. La calibration automatique n’est pas incluse dans cette étape ; elle ne doit pas être présentée comme une réparation de la batterie. L’objectif immédiat est une limite claire, une reprise compréhensible et des transitions fiables.

## Licence et provenance

Les sources et modifications sont distribuées sous la licence GNU GPL v3 du projet amont, conservée dans `LICENSE`. Les crédits amont sont conservés dans `README.md`. Cette édition personnelle n’est pas une publication officielle du mainteneur et n’est pas affiliée à AlDente. Aucun élément propriétaire d’AlDente n’est repris.
