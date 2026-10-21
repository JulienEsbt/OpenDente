# OpenDente — édition personnelle

Version de développement **0.4.1 expérimentale**, préparée le 21 octobre 2026 à partir d’[OpenDente](https://github.com/killerk3emstar/OpenDente), révision `06c5a8199f5c0657374e667073b3aa6a75f50df8`.

Cette édition contient les sources modifiées, les tests et un script de compilation. **Les 361 tests XCTest réussissent sur le MacBook Air M3 sous macOS 27.2 ; les cibles Debug et Release compilent.** La Release locale est signée Apple Development, avec le même certificat pour l’app et le service. Elle n’est pas notarifiée. Les observations matérielles restent détaillées dans `VALIDATION.md`.

## macOS 27 : mode natif expérimental

Sur le Mac cible, les clés SMC CHTE/CH0B/CH0C sont absentes, même depuis le service root. Le moteur SMC d’origine ne peut donc pas suspendre la charge. Le service 1.5.2 propose un autre moteur, activé explicitement dans **Réglages > Charge > Activer le contrôle de charge**. Sans cette activation, l’app reste un outil de suivi.

Ce moteur transmet un plafond au service PowerUI de macOS. Il utilise des interfaces et préférences Apple privées, susceptibles de changer ; sa disponibilité est contrôlée à l’exécution. Il ne modifie pas les autorisations Apple, les archives de politiques powerd ou les règles sudoers. Les mécanismes adaptés d’Ampere et leur licence MIT figurent dans `THIRD-PARTY-NOTICES.md`, également embarqué dans l’app avec la licence GPL.

Différences avec le moteur SMC décrit plus bas :

- La consigne est appliquée par macOS, avec un délai pouvant atteindre environ une minute. La confirmation des préférences ne prouve pas l’arrêt du courant ; le panneau continue d’afficher l’état réel de la batterie.
- Le seuil de reprise personnalisé est réglable, y compris à 20 % pour une limite de 80 %. Pendant l’attente, OpenDente ajuste le plafond au niveau courant ; une fois sous le seuil bas, il demande le plafond habituel jusqu’à la fin du cycle. Cette régulation dépend de macOS et reste approximative, notamment pendant la veille ou une calibration. Elle ne coupe pas le chargeur et ne force pas une décharge.
- La pause thermique supplémentaire est réglable de 30 à 45 °C. Le défaut de 40 °C est un choix de précaution de l’app, pas une recommandation Apple pour ce capteur interne. La pause reste demandée jusqu’à au moins 5 minutes sans dépassement et 2 °C de refroidissement. Une mesure perdue ne lève pas une pause. Les protections Apple restent actives ; aucun arrêt immédiat ou surveillance pendant le sommeil du Mac n’est garanti. Le maintien natif ne descend pas sous 20 %.
- macOS peut temporairement dépasser le plafond pour calibrer sa mesure de batterie, jusqu’à 100 %. OpenDente ne supprime pas cette politique système.
- Hors mode stockage explicite à 50 %, le service refuse une consigne inférieure au niveau qu’il vient de lire : le firmware peut décharger activement vers un plafond inférieur. Si le niveau dépasse la limite habituelle, l’app demande de tenir le niveau actuel ; après débranchement la consigne descend avec le niveau vers la limite habituelle. Les profils ne coupent jamais le chargeur.
- La charge ponctuelle demande 100 %. L’annulation ou le débranchement efface cette demande sans écraser la limite habituelle ; une consigne adaptée au niveau courant évite de demander une décharge après la charge complète.
- Le réglage Apple précédent est sauvegardé dans un journal root avant la première modification. Désactivation, arrêt de l’app, perte du client, watchdog et redémarrage du service passent par sa restauration. Un échec conserve le journal pour réessayer.

Ce mode est expérimental. La plage 20–100 % correspond aux consignes admises par ce backend privé, et non à la plage 80–100 % du curseur public Apple. Seuls les essais matériels consignés dans `VALIDATION.md` établissent ce qui a été observé sur ce Mac.

## Réglages conseillés et interface

Pour un Mac souvent branché, le bouton **80 % / reprise sous 75 %** se rapproche du comportement natif documenté par Apple. Ce n’est pas un seuil de reprise imposé par le constructeur. La plage 20–80 % reste disponible au choix ; la batterie lithium-ion n’a pas besoin d’être déchargée à 20 % pour son entretien. Une recharge partielle n’est pas à elle seule un cycle complet.

Apple recommande une pièce entre 10 et 35 °C, une surface ventilée et l’absence d’exposition prolongée à la chaleur. Cette plage ambiante ne doit pas être utilisée comme un seuil de capteur interne. Une charge occasionnelle à 100 % reste utile pour l’autonomie et est aussi déclenchée par macOS pour sa jauge. Aucune décharge périodique d’entretien n’est ajoutée. Pour un stockage prolongé, Apple conseille environ 50 % de charge, Mac éteint, au frais.

Sources consultées le 21 octobre 2026 : [limite et reprise Apple](https://support.apple.com/en-us/102338), [cycles lithium-ion Apple](https://www.apple.com/batteries/why-lithium-ion/), [température du Mac](https://support.apple.com/en-us/102336), [conservation Apple](https://www.apple.com/batteries/maximizing-performance/), [Battery University / Cadex](https://www.batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries). Les tendances générales de vieillissement ne donnent pas de gain chiffré garanti sur la batterie de ce Mac.

La section Charge propose des contrôles modifiables pour la limite, la reprise, la température et la veille automatique. Les options non portées au moteur natif sont expliquées dans un groupe replié : décharge libre vers un plafond quelconque, pourcentage matériel pour la régulation et pause dédiée à la veille. Les réglages SMC d’origine restent conservés pour le matériel compatible.

## Préparer un stockage prolongé et choisir le chargeur

Dans **Réglages > Charge > Stockage prolongé**, un guide suit le niveau mesuré et explique la préparation autour de 50 %, le débranchement et l’extinction manuelle. La zone 45–55 % est un repère pratique de l’interface, pas une plage prescrite par Apple. Les indications restent consultables ; le nouveau bouton de mode demande réellement une cible temporaire à 50 % sans écraser le plafond quotidien, comme détaillé ci-dessous. Aucune extinction automatique. Mac éteint, aucune app ne peut surveiller ou maintenir la charge : prévoir un contrôle et une recharge autour de 50 % tous les six mois en cas de stockage très long, dans un lieu frais et sec à moins de 32 °C.

Le même écran explique MagSafe et USB-C. Le moteur régule la batterie interne et est conçu pour les deux alimentations, avec un chargeur USB-C Power Delivery de puissance adaptée. Cette séance ne dispose que du câble MagSafe : le comportement USB-C n’est pas validé physiquement. Le voyant reste piloté par macOS par défaut. La section Voyant MagSafe propose une personnalisation explicite : vert, orange, éteint ou automatique, avec règles séparées pour charge mesurée, pause, préparation au stockage et pause thermique. Les aperçus durent 10 secondes. Chaque écriture est journalisée puis relue ; la restitution à macOS est tentée à la veille, au débranchement, à la fermeture et en récupération. Aucun clignotement personnalisé n’est ajouté.

## Modes et guide des commandes

**Préparer le stockage à 50 %** active une cible temporaire sans écraser les seuils quotidiens. Au-dessus de 50 %, cette action autorise explicitement une descente sur secteur ; au-dessous, elle demande une recharge vers 50 %. L’app ne lance aucun calcul pour consommer davantage et n’éteint jamais le Mac. Le panneau distingue la demande de la décharge mesurée. Le bouton d’arrêt, un profil ou une charge ponctuelle quittent ce mode. La politique thermique garde sa priorité et son délai. La commande privilégiée est dédiée à 50 %, sans cible arbitraire.

L’onglet **Guide** contient une aide hors ligne avec recherche pour les boutons, réglages et limites. Le même contenu est disponible dans [GUIDE-UTILISATION.md](GUIDE-UTILISATION.md). [COMPARATIF.md](COMPARATIF.md) distingue les fonctions héritées d’OpenDente, les ajouts personnels et les fonctions annoncées par AlDente Free/Pro. La validation physique de chaque nouveauté est consignée dans VALIDATION.md ; des tests simulés ne remplacent pas une mesure sur la batterie.

Sources : [stockage Apple](https://www.apple.com/fr/batteries/maximizing-performance/), [MagSafe et USB-C](https://support.apple.com/fr-fr/102397), [voyant MagSafe](https://support.apple.com/fr-fr/102372). Les essais de reprise et de veille sont détaillés dans `VALIDATION.md`.

## Profils et politique du moteur SMC

L’application conserve son interface native SwiftUI dans la barre de menus. Le panneau principal est en français, avec un pourcentage lisible, le plafond habituel, le seuil réel de reprise, les mesures de batterie disponibles et des messages expliquant pourquoi la charge est interrompue ou attendue. Un arrêt demandé reste distingué d’un arrêt confirmé par les données de la batterie.

| Profil | Plafond | Reprise lorsque le niveau passe sous |
|---|---:|---:|
| Bureau | 70 % | 60 % |
| Quotidien | 80 % | 70 % |
| Mobilité | 90 % | 80 % |

Ces profils sont des points de départ modifiables. Ils activent la protection thermique et la plage de reprise, et désactivent la décharge automatique. Ils ne constituent pas une promesse de durée de vie supplémentaire. Le réglage par défaut reste 80 % ; les valeurs libres existantes restent disponibles.

**« Charger à 100 % cette fois »** conserve le plafond habituel. La demande dure jusqu’au débranchement, à l’annulation, à l’arrêt de l’application ou au démarrage explicite d’une décharge. En mode natif, les demandes de pause ont les limites décrites plus haut. Elle attend pendant une pause thermique, puis reprend après refroidissement et expiration du délai. Annuler la charge ponctuelle n’annule pas la protection thermique. Une mesure de température perdue pendant cette pause ne suffit pas à autoriser la reprise.

La plage de reprise laisse le niveau baisser naturellement. Les profils ne provoquent pas de décharge forcée pour atteindre un plafond plus bas. La décharge libre reste réservée aux Mac compatibles avec le moteur SMC. Le mode stockage natif fournit uniquement une cible explicite à 50 %.

Le compteur de cycles, la capacité, la température, la puissance et le schéma d’alimentation utilisent les données déjà disponibles dans OpenDente. Les valeurs absentes restent absentes. Aucun appel réseau, outil d’analytics ou système de mise à jour automatique n’a été ajouté.

## Corrections de l’audit

- **Authentification du service privilégié :** identifiant de l’app et certificat de signature identique à celui du service, contrôlés par l’API publique `NSXPCConnection.setCodeSigningRequirement`. Aucun contournement Debug. Une simple connexion ne devient pas un client actif ; les anciennes connexions ne doivent pas perturber la nouvelle.
- **Récupération matérielle :** l’intention restrictive est persistée avant l’écriture ; les valeurs sont relues ; une erreur partielle déclenche une restauration. Chaque clé de restauration est tentée, même si la première échoue. Les erreurs sont retournées au lieu d’un succès systématique.
- **Restauration incomplète :** le service conserve l’état de récupération et retente la restauration, y compris lorsque l’app répond encore au watchdog.
- **Veille :** la politique de veille est effacée au reset et à la déconnexion ; elle ne s’applique plus sans client actif. Une simple demande de veille annulable ne suspend plus le watchdog.
- **Température :** la vérification de l’arrêt réel de charge s’exécute aussi pendant les branches de chaleur et de refroidissement. Un échec de commande conserve la pause thermique.
- **Seuil bas :** il reste au minimum à 10 %, y compris avec un plafond de 20 % et une plage de 25 points.
- **Compatibilité du service :** les commandes de politique de charge attendent un handshake avec le service 1.6.0 ou ultérieur. Une ancienne version affiche une erreur explicite. Les commandes de restauration restent disponibles pour revenir aux réglages macOS.

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

### Xcode complet et accès au Trousseau

Les Command Line Tools seuls ne suffisent pas à exécuter ce projet et XCTest.
Si `xcode-select -p` pointe encore vers les Command Line Tools, sélectionner Xcode
ou préciser son emplacement pour la commande locale :

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash scripts/build-local.sh "Nom exact du certificat" "TEAMID"
```

Xcode demande les composants nécessaires au premier lancement. Pour cette app,
macOS suffit ; les composants iOS, watchOS, tvOS et visionOS restent facultatifs
et peuvent être ajoutés plus tard.

Le Trousseau peut demander le mot de passe de session pour laisser l’outil Apple
`codesign` utiliser la clé du certificat choisi. Une autorisation ponctuelle peut
être redemandée pour chaque cible. « Toujours autoriser » accorde à cet outil un
accès durable à cette clé de signature ; ce choix se fait dans la fenêtre macOS,
pour le certificat attendu. L’utilisation normale d’OpenDente ne signe pas de code
et ne doit pas demander cette clé.

Pour exécuter uniquement les tests avant de disposer d’un certificat :

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project OpenDente.xcodeproj -scheme OpenDente \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO
```

Ce mode valide la compilation et XCTest, pas l’identité de signature ni le
service. Le marqueur `OPENDENTE_TESTING=1`, réservé à l’action Test du schéma,
empêche l’app hôte de démarrer les services réels de batterie.

### Fork personnel

Le développement se poursuit sur `feature/personal-battery-care` dans le fork
[JulienEsbt/OpenDente](https://github.com/JulienEsbt/OpenDente). Les remotes sont :

```text
origin    https://github.com/JulienEsbt/OpenDente.git
upstream  https://github.com/killerk3emstar/OpenDente.git
```

Le bundle d’origine reste dans l’archive de sources. L’historique amont, sa
licence et ses crédits sont conservés ; le remote `origin` ne désigne plus le
bundle.

### Essais natifs avant usage quotidien

Le modèle, la puce et la version exacte de macOS doivent être consignés. Le projet amont est une bêta dont la documentation cite un test sur M4/Tahoe ; les essais portables n’élargissent pas cette compatibilité.

1. Faire réussir les tests Xcode et vérifier le rendu du panneau, les réglages, le clavier et les tailles de texte.
2. Placer l’app construite à son emplacement définitif avant le premier lancement. Vérifier l’autorisation de son service dans les éléments d’ouverture de macOS. En cas d’ancien service, utiliser **Réinstaller le service** dans les réglages de cette édition.
3. Vérifier qu’un seul outil gère la politique de charge pendant les essais. L’app signale un conflit avec la limite native lorsqu’elle le détecte ; le mode natif expérimental est une exception explicite : il sauvegarde, applique puis restaure le réglage Apple.
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
