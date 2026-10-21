# Bilan de validation — 21 octobre 2026

## Reprise et validation natives sur le Mac cible

Machine vérifiée : MacBook Air M3 (`Mac15,12`), arm64, 16 Go de mémoire,
macOS 27.2, build `26B118`. Xcode 27.1 (`27A9275`) installé depuis l’App Store,
SDK macOS 27.0 et Swift 6.4. XcodeGen 2.46.0 installé. Les Command Line Tools
préexistants fournissent aussi Swift 6.4.2 ; les commandes Xcode de cette reprise
utilisent explicitement `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Vérification exécutée | Résultat | Portée |
|---|---:|---|
| Projet XcodeGen et schéma Test | Réussite | Tests inclus ; marqueur d’isolation absent de l’action Run |
| XCTest sur macOS arm64 | 313/313, aucun échec | Suite complète, avec accès matériels simulés et hôte sans services réels |
| Workflow local signé Debug | Réussite | Compilation, XCTest, vérification stricte app/helper et certificats identiques |
| Compilation Xcode Release 0.3.0 | Réussite | arm64/x86_64, signature Apple Development, vérification stricte et certificat app/helper identique |
| Scénarios portables exécutés sur Mac | 30/30 | Méthodes de production extraites, frontières macOS inertes |
| Récupération/cycle de vie/watchdog sur Mac | 28/28 | Dépendances matérielles simulées |
| Helper complet avec API macOS | Réussite | Vérification des types, dont Security et XPC, sans exécuter le helper |

La compilation native a révélé un passage de `SecCode` à une API exigeant
`SecStaticCode`. Le contrôle ajouté aux sources complètes du helper échoue avant
la correction, puis réussit après conversion explicite et validation du code en
mémoire et sur disque. Les contrôles extraits masquaient auparavant ce défaut.

Le premier workflow signé a ensuite révélé une syntaxe incorrecte du préfixe
`codesign --extract-certificates`. La correction utilise
`--extract-certificates=préfixe`. Le script complet termine désormais avec le
code 0 et confirme la présence et l’égalité des certificats feuilles.

Les fixtures XCTest utilisent les points d’entrée `setUp` / `tearDown`
asynchrones sur le MainActor ; les tests de vues sont eux aussi isolés sur le
MainActor. Les 299 méthodes et leurs assertions sont conservées. Après correction,
aucun avertissement Swift de concurrence n’est présent dans le journal de tests.
Xcode émet encore son avertissement d’extraction AppIntents sans dépendance
AppIntents et des diagnostics système `com.apple.linkd.autoShortcut` ; ils
n’empêchent pas la réussite de la suite et ne sont pas des résultats de charge.

Une identité Apple Development a été créée par Xcode avec l’autorisation du
propriétaire. Les signatures Debug sont valides sur disque et satisfont leurs
exigences désignées. La clé privée reste gérée par le Trousseau ; aucune clé privée
n’est stockée dans le dépôt. Une signature valide ne prouve pas à elle seule le
rejet d’un client tiers ni la fiabilité des commandes matérielles.

Les preuves locales sont conservées dans `build/validation/` et les résultats
XCTest dans `build/NativeTests-20261021-concurrency.xcresult` ainsi que
`build/DerivedData/Logs/Test/`. Les journaux et sorties de compilation sont ignorés
par Git. Les commandes de reproduction figurent dans `README-PERSONAL.md` et
`scripts/build-local.sh`.

### Diagnostic matériel et extension expérimentale

Le service 1.4.0 a effectivement tourné en tant que root (PID 16383). Il a confirmé l’absence de CHTE, CH0B, CH0C et CH0I ; CHIE et ACLC existent. Le contrôle SMC de charge est donc indisponible sur ce firmware. Aucune commande de décharge par coupure d’adaptateur n’a été ajoutée.

Le panneau et les réglages ont été vus sur le Mac, avec les mesures réelles et les commandes désactivées. L’état « service absent » était resté figé après l’approbation macOS. Le correctif publie l’état du service et actualise la connexion au retour dans l’app et pendant l’affichage des réglages. Le cas notFound vérifie aussi les fichiers du bundle au lieu de conclure directement qu’ils sont absents.

La Release signée 0.3.0 installée a obtenu la version 1.4.0 du service actif, puis a correctement refusé d’utiliser ce service trop ancien. Un client ad hoc reprenant l’identifiant com.opendente.app a reçu « Couldn’t communicate with a helper application » et terminé avec le code 0 du test négatif. Le premier outil de test négatif avait lui-même échoué sur une assertion d’isolation de thread ; ses callbacks ont été corrigés, et seul le nouveau résultat est retenu. Le refus d’un autre certificat et toutes les variantes Debug/Release ne sont pas encore revendiqués.

Le propriétaire a choisi le mode natif expérimental pour macOS 27. Le code utilise PowerUI, un journal root et la même authentification XPC. Les 14 nouveaux tests natifs vérifient notamment l’opt-in, l’absence de commandes SMC sur ce backend, le maintien au niveau courant au-dessus du plafond, l’absence de fausse pause thermique, le Top Up, la restauration et les échecs de journal/écriture/récupération. Ils n’exécutent pas PowerUI et ne prouvent pas un arrêt physique.

Résultat final : 313 tests réussis dans `build/NativeTests-20261021-native-final.xcresult`, 30 scénarios portables, 28 scénarios de helper, typecheck du service complet et Release signée. Les journaux courants sont `build/validation/native-final-*` et `native-mode-portable/`.

**Essais matériels du mode natif encore en cours :** remplacement du service 1.4.0 par le 1.5.0, activation native, limite atteinte, reprise, charge ponctuelle, annulation, restauration réelle et ouverture à la connexion. Le Mac s’est verrouillé avant le remplacement du service ; l’app 0.3.0 est installée mais le mode natif reste désactivé. Aucun succès de gestion de charge 0.3.0 n’est encore revendiqué.

Au début de la reprise, Apple était réglé à 80 % avec recharge optimisée activée. Pour les essais, une remise d’AlDente à 100 % a été demandée puis l’app a été arrêtée. La charge normale a repris. La limite Apple et la recharge optimisée ont ensuite été suspendues temporairement par le propriétaire jusqu’à 06:00 ; ce n’est pas une désactivation permanente. Le chargeur a été débranché puis rebranché pendant le travail. La restauration de la configuration finale et les essais veille/réveil/reconnexion utilisateur restent à consigner.

## Validation initiale portable, conservée pour provenance

## Périmètre

Base amont : `06c5a8199f5c0657374e667073b3aa6a75f50df8`.
Environnement exécuté : Linux x86_64, compilateur officiel Swift 6.4.1, vérifié par SHA-256 et signature PGP Swift 6.x.

**La version préparée contient des sources de développement. La compilation de l’application entière, la signature et le comportement sur un vrai Mac n’ont pas été validés ici.**

## Vérifications exécutées

| Vérification | Résultat | Portée |
|---|---:|---|
| Logique de charge extraite de la production | 30/30 scénarios réussis | Limites, températures, refroidissement, Top Up, profils, erreurs asynchrones, contrôle LED |
| Récupération du contrôleur matériel de production | 17/17 réussis | Deux familles de clés, erreurs d’écriture/relecture/persistance, restaurations partielles |
| Cycle de vie du vrai délégué extrait | 8/8 réussis | Clients actifs/obsolètes, déconnexion, veille, validation des valeurs LED ; frontière XPC simulée |
| Watchdog et contrôleur réels | 3/3 réussis | Reprise d’une restauration échouée malgré un heartbeat actif |
| Analyse syntaxique Swift | 34 fichiers, aucune erreur | App, helper, code partagé et XCTest ; ce n’est pas une compilation/typecheck macOS |
| Configuration | YAML/plist lus, `bash -n` réussi, `git diff --check` propre | Structure et syntaxe ; XcodeGen et Xcode non exécutés |

Les **58 scénarios ciblés** réussis ne sont pas la suite XCTest native complète. Le projet contient désormais 299 méthodes XCTest, dont 26 ajoutées ; **aucune réussite de ces 299 méthodes sur macOS n’est revendiquée**.

Une boucle de vérification des 1 944 combinaisons de plafond/plage est incluse dans un seul scénario, sans multiplier artificiellement le nombre de tests.

## Contrôle négatif sur les sources d’origine

Le banc de charge a aussi été exécuté contre la révision amont auditée : **19 scénarios communs, 13 échecs attendus et 6 réussites**. Les contrôles positifs confirment que le banc n’échoue pas systématiquement. Les fonctionnalités nouvelles absentes de la version d’origine sont testées séparément sur la version modifiée.

Les erreurs reproduisent notamment : l’absence de vérification thermique, le seuil de reprise nul, la perte du Top Up, le démarrage à chaud, la température manquante et le contournement du contrôle de disponibilité pour la LED.

Le contrôle négatif termine avec le code 1 attendu. Son runtime Swift Linux émet ensuite des avertissements de fermeture relatifs à des fichiers de statut de threads indisponibles. Les 19 résultats JSON sont complets ; ces messages sont conservés dans les preuves. Le banc de la version modifiée termine avec le code 0 et sans sortie d’erreur d’exécution.

## Ce qui n’est pas testé par ces bancs

- Rendu SwiftUI/AppKit, interactions clavier et VoiceOver, intégration Combine.
- Compilation et exécution complètes avec le SDK macOS et Xcode.
- Exigence cryptographique de signature, rejet réel d’un client tiers par NSXPCConnection, installation SMAppService et permissions du Trousseau.
- Persistance dans le répertoire root réel et permissions effectives du système de fichiers.
- Courant physique, commandes SMC, firmware, charge réelle, débranchement, veille/réveil ou comportement thermique du Mac cible.
- Évolution de l’usure de la batterie à long terme.

Les tests de récupération compilent le véritable contrôleur. Les tests du délégué retirent explicitement la construction de l’exigence cryptographique et remplacent les frontières macOS ; ils ne constituent donc pas une validation de sécurité de la signature.

## Relecture indépendante

Une relecture des modifications a identifié un passage résiduel des réglages de veille/LED vers un ancien helper et un échec silencieux de la seconde étape du handshake. Ils ont été corrigés par les gardes de disponibilité, la remontée d’erreur, un identifiant de tentative et un délai d’expiration. La relecture a également conduit à conserver le refroidissement après un échec de commande et à borner les tentatives de reconnexion, avec remise à zéro après un handshake réussi.

Cette relecture et les tests réduisent des risques identifiés. La validation macOS décrite dans `README-PERSONAL.md` et `tests/helper/README.md` reste nécessaire avant usage quotidien.

## Preuves et reproduction

L’archive de livraison contient les journaux, le code extrait, les manifestes de hachages, un patch par rapport à la base et un bundle Git. Les scripts `tests/portable/run.py` et `tests/helper/run_tests.py` reproduisent les tests sans droits root ni accès matériel.

Les empreintes portent sur les sources exactes, pas sur une affirmation de sécurité absolue. Le bundle permet de retrouver la révision d’origine et de rejouer le contrôle négatif.
