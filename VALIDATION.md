# Bilan de validation — 21 octobre 2026

## État actuel : version 0.4.0 (6), service 1.5.2

MacBook Air M3 (`Mac15,12`), arm64, 16 Go, macOS 27.2 (`26B118`). Xcode 27.1 (`27A9275`), SDK macOS 27.0, Swift 6.4, XcodeGen 2.46.0. Les commandes Xcode utilisent `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Contrôle exécuté | Résultat | Portée |
|---|---:|---|
| Suite XCTest native arm64 finale | **339/339**, aucun échec ni test ignoré | `build/NativeTests-20261021-final.xcresult` ; services matériels inertes |
| Banc portable final | **30/30** | Méthodes de production extraites, nouveau type de politique inclus |
| Récupération / cycle de vie / watchdog | **28/28** | Matériel et XPC simulés ; typecheck du helper complet sur le SDK Apple |
| Release 0.4.0 universelle | Réussite | arm64 et x86_64 compilés ; exécution réelle arm64 uniquement |
| Signature app et service | Réussite | Apple Development, vérification stricte et certificat identique ; aucune notarification |
| Client ad hoc reprenant l’identifiant de l’app | Rejeté | Probe getVersion uniquement, après connexion positive de l’app signée ; aucun contournement Debug |

La suite finale ajoute les transitions 80/20, le maintien pendant l’attente, la poursuite d’un cycle jusqu’au plafond, la priorité thermique sur le Top Up, la baisse de 2 °C et le délai de 5 min, les températures absentes/non finies, le redémarrage du délai lors d’un pic, les erreurs de commande, la prévention de veille, et la restauration même sans lecture de batterie. Quatre tests supplémentaires vérifient qu’un onduleur listé en premier ne remplace pas la batterie interne, et que des données absentes, ambiguës ou incohérentes bloquent la commande. La valeur interne réelle a été lue : Type=InternalBattery, Current Capacity=99, Max Capacity=100. Le helper 1.5.2 renforce uniquement cette sélection, sans changer les commandes PowerUI. Les deux scénarios demandés (reprise à 20 % et maintien thermique natif) échouaient avant implémentation dans `native-policy-red.log`, puis réussissent. Les scénarios thermiques historiques conservent leurs assertions avec un seuil explicitement fixé à 35 °C ; le nouveau défaut de 40 °C est testé séparément.

Les journaux finaux sont `build/validation/final-xctest.log`, `final-release.log`, `final-portable/` et `final-helper/`. Aucun avertissement Swift de concurrence dans les sources de production. Les avertissements AppIntents sans dépendance et les diagnostics système com.apple.linkd.autoShortcut ne sont pas des échecs de charge.

## Observations matérielles

1. Les clés CHTE, CH0B, CH0C et CH0I sont absentes même depuis le helper root. CHIE et ACLC existent. Le contrôle de charge SMC d’origine est donc indisponible ; aucun succès SMC n’est revendiqué.
2. L’app et son service signés communiquent réellement. L’ancienne version du service est refusée ; la mise à jour vers 1.5.1 a été effectuée par SMAppService. Le premier refus d’installation a été résolu par l’action Activer le service après désenregistrement, sans contourner les autorisations macOS.
3. Le premier backend 0.3.0 écrivait un état de préférence supposé actif et recevait une relecture concordante, sans plafond enregistré dans powerd. Cet essai a échoué. Le correctif appelle le setter PowerUI plutôt que de deviner l’énumération privée de l’état.
4. Avec le helper corrigé 1.5.1 et la batterie à 99 %, le plafond natif 99 est enregistré par macOS (pmset battlimit), `ExternalConnected=Yes`, `IsCharging=No`, `Amperage=0`, `NotChargingReason=16777216`. PowerUI indique PausedForMCL.
5. La charge ponctuelle à 100 % retire ce plafond : batterie toujours à 99 %, `ExternalConnected=Yes`, `IsCharging=Yes`, `Amperage=1274` mA, puissance batterie d’environ 16,5 W, NotChargingReason=0. L’annulation rétablit le plafond 99 et le courant nul. Ce contrôle aller-retour permet de distinguer la pause d’une simple fin de charge normale.
6. Désactiver le contrôle retire le plafond enregistré : pmset ne rapporte plus de limite. Le service ne remonte pas d’erreur de restauration. Le réglage natif sauvegardé était 100 % pour ces essais ; il est restauré en quittant le contrôle.

Ces observations de charge concernent le service 1.5.1 dans l’app 0.3.1. Le même service, le même certificat et le chemin de consigne restent utilisés par 0.4.0. La politique de reprise/thermique ajoutée dans 0.4.0 est vérifiée par les tests et les contrôles d’interface, avec les limites matérielles ci-dessous.

## Interface et configuration retenue

La version 0.4.0 est installée dans `/Users/julienesbt/Applications/OpenDente.app` avec sauvegarde de la précédente. Dans la section Charge, le curseur de reprise a été placé à 20 % et la température à 41 °C, puis les valeurs finales ont été appliquées : plafond 80 %, reprise sous 75 %, pause supplémentaire activée à 40 °C. Les champs sont actifs ; le texte suit les valeurs. L’ouverture à la connexion est enregistrée : l’interface confirme le statut enabled de SMAppService.mainApp, pas seulement une préférence locale.

Avec le build 5 de 0.4.0 et le service 1.5.1, le maintien 99 % est de nouveau observé chargeur branché, IsCharging=No et courant nul. Un client ad hoc est rejeté pendant que la véritable app est connectée. Le build 6 embarque la garde de sélection interne et exige le service 1.5.2.

AlDente est arrêté et son autorisation de fonctionnement en arrière-plan a été désactivée avec validation locale du propriétaire ; l’app reste installée. La configuration Apple initiale était 80 % avec recharge optimisée. Pour les essais, la limite Apple a été passée à 100 % et la recharge optimisée suspendue temporairement jusqu’à 06:00. Le moteur natif restaure la limite 100 % sauvegardée lorsqu’il est désactivé : ce choix d’essai n’est pas le plafond habituel 80 % stocké dans OpenDente.

## Éléments qui restent à observer en usage réel

- Descente naturelle depuis le plafond jusqu’au seuil bas, puis retour au plafond : ni 80/75 ni 80/20 n’ont fait l’objet d’un cycle physique complet durant cette séance.
- Pause lors d’une température réellement élevée et reprise après refroidissement : pas de chauffe volontaire du Mac. Les transitions et erreurs sont simulées dans XCTest ; l’action native de maintien est celle observée à 99 %.
- Veille/réveil complète et ouverture après déconnexion/reconnexion de session : pas de suspension ou fermeture de session imposée pendant l’usage du propriétaire. L’enregistrement du démarrage automatique est contrôlé dans l’interface ; ce n’est pas une exécution après reconnexion.
- Comportement pendant une calibration firmware, après redémarrage complet, sous charge prolongée et sur x86_64. Rejet d’un client signé avec un autre certificat non testé ; le test négatif ad hoc est distinct.

Le propriétaire n’était pas disponible pour le précédent essai de débranchement de cinq minutes ; aucune réussite n’en est déduite. La version reste expérimentale et ne garantit pas un arrêt thermique immédiat. Une consigne privée peut changer de comportement lors d’une mise à jour de macOS.

## Provenance et préparation conservées

Les corrections initiales ont porté sur la conversion SecCode/SecStaticCode, la vérification du service complet plutôt que de seules extractions, l’isolation de l’hôte XCTest, les fixtures MainActor, la détection de Xcode complet et la syntaxe `codesign --extract-certificates=préfixe`. La suite initiale 299 tests est conservée.

L’identité Apple Development a été créée dans Xcode avec l’autorisation du propriétaire, sans export de clé privée. Les certificats app/helper correspondent. La signature de code et la signature Git avec clé matérielle sont deux mécanismes distincts.

Le fork JulienEsbt/OpenDente est relié à origin ; upstream reste killerk3emstar/OpenDente. Le bundle, la base amont, la licence GPL et les crédits ont été conservés. Les mécanismes adaptés d’Ampere sont crédités avec leur licence MIT dans THIRD-PARTY-NOTICES.md et dans l’app.

La section suivante reproduit le bilan Linux de la préparation initiale. Ses limites « Xcode non exécuté » décrivent cette étape historique, pas l’état actuel ci-dessus.

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
