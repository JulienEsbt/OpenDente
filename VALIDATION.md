# Bilan de validation — 21 octobre 2026

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
