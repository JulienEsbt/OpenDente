<div align="center">

# OpenDente · Édition personnelle

**Prenez soin de la batterie de votre Mac, depuis la barre des menus.**

Choisir un plafond. Comprendre l’état de la batterie. Retrouver ses réglages au quotidien, en arrière-plan.

[English](README.md) · **Français**

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-24292f?logo=apple)](#compatibilité) [![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](project.yml) [![Version 0.7.2](https://img.shields.io/badge/version-0.8.0-299da4)](CHANGELOG-PERSONAL.md) [![GPL v3](https://img.shields.io/badge/licence-GPL--3.0-24292f)](LICENSE)

[Fonctionnalités](#fonctionnalités) · [Captures](#captures-décran) · [Installation](#compiler-et-lancer) · [Documentation](#documentation)

</div>

Une application native SwiftUI pour la batterie du Mac, maintenue par [JulienEsbt](https://github.com/JulienEsbt) à partir de [killerk3emstar/OpenDente](https://github.com/killerk3emstar/OpenDente). Cette édition ajoute une interface en français et en anglais, des profils quotidiens, la préparation au stockage, un affichage compact et un moteur natif de charge expérimental, tout en conservant l’historique et les crédits du projet d’origine.

<p align="center">
  <a href="docs/images/panel.png"><img src="docs/images/panel.png" width="330" alt="Panneau principal OpenDente à 80 %, avec profils quotidiens, préparation au stockage et charge ponctuelle complète"></a>
  <a href="docs/images/measurements.png"><img src="docs/images/measurements.png" width="330" alt="Mesures de la batterie et flux d’énergie dans le panneau OpenDente"></a>
</p>
<p align="center"><sub>Captures réelles d’OpenDente 0.7.2. Interface française illustrée ; la 0.8.0 propose aussi l’anglais et des couleurs adaptées au mode clair. Cliquer sur une image pour l’ouvrir en pleine résolution.</sub></p>

> [!IMPORTANT]
> **Le moteur natif de charge est expérimental.** Il utilise des interfaces privées Apple et a été testé sur un MacBook Air M3 sous macOS 27.2. La compatibilité et les délais varient. Le dépôt fournit les sources pour une signature locale, sans installateur public notarifié. Lire les [limites](#compatibilité) avant d’activer le contrôle de charge.

## Fonctionnalités

| Réglage ou mode | Ce qu’il fait |
|---|---|
| **Plafond et profils quotidiens** | Choisir une limite et passer entre Bureau, Quotidien et Mobilité. Le moteur natif accepte des demandes de 20 à 100 % ; les cibles sous la plage publique Apple de 80–100 % restent expérimentales. |
| **Seuil de reprise** | Reprendre la charge après une baisse naturelle sous le seuil inférieur, puis continuer jusqu’au plafond. Aucun cycle répété de décharge n’est imposé. |
| **Retour au plafond** | Autoriser une batterie déjà trop chargée à redescendre vers le plafond sur secteur, puis passer au maintien. |
| **Charge complète ponctuelle** | Demander temporairement 100 % sans remplacer les réglages quotidiens. Les pauses thermiques gardent la priorité. |
| **Préparation au stockage** | Utiliser une cible séparée de 50 %, en recharge ou en décharge selon le niveau. Les seuils quotidiens sont conservés ; débrancher et éteindre manuellement une fois le Mac prêt. |
| **Pause thermique supplémentaire** | Demander une pause à la température interne de batterie choisie. Reprendre après une baisse de 2 °C et au moins cinq minutes sans dépasser le seuil. |
| **Signaux MagSafe** | Associer vert, orange ou éteint, clignotements lents et alternance aux états de charge. Des aperçus de dix secondes permettent de vérifier chaque signal. |
| **Langue et apparence** | Suivre la langue du Mac ou choisir Français/English dans Général. Commandes, guide et notifications sont traduits ; les couleurs suivent les modes clair et sombre. |
| **Arrière-plan discret** | Démarrer à la connexion directement dans la barre des menus. Fermer une fenêtre laisse l’app active ; ouvrir le panneau seulement au besoin. |

L’affichage compact place le pourcentage **dans la batterie**, avec une jauge séparée et des indicateurs facultatifs de température, puissance et mode. La présentation classique reste disponible. Le panneau permet de choisir ses mesures, de consulter les flux d’énergie, de configurer les notifications, de rechercher dans le guide hors ligne et d’exporter un diagnostic local.

## Captures d’écran

<details>
<summary><strong>Découvrir la charge, MagSafe, l’affichage compact et le guide intégré</strong></summary>

<p align="center">
  <a href="docs/images/charge-settings.png"><img src="docs/images/charge-settings.png" width="380" alt="Réglages de charge avec moteur natif actif, plafond à 80 % et reprise sous 70 %"></a>
  <a href="docs/images/thermal-settings.png"><img src="docs/images/thermal-settings.png" width="380" alt="Pause thermique configurable, explication du refroidissement et prévention facultative de veille automatique"></a>
  <br><sub>Politique de charge et retour au plafond · Pause thermique supplémentaire</sub>
</p>
<p align="center">
  <a href="docs/images/magsafe-settings.png"><img src="docs/images/magsafe-settings.png" width="380" alt="Règles du voyant MagSafe pour la charge, le maintien, la décharge, la pause thermique et la charge complète ponctuelle"></a>
  <a href="docs/images/menu-bar-settings.png"><img src="docs/images/menu-bar-settings.png" width="380" alt="Aperçu de la barre compacte et indicateurs facultatifs de pourcentage, température, puissance et mode"></a>
  <br><sub>Couleurs et motifs MagSafe · Barre des menus compacte</sub>
</p>
<p align="center">
  <a href="docs/images/panel-settings.png"><img src="docs/images/panel-settings.png" width="380" alt="Réglages pour afficher, masquer et réordonner les mesures de batterie du panneau"></a>
  <a href="docs/images/offline-guide.png"><img src="docs/images/offline-guide.png" width="380" alt="Guide hors ligne avec recherche, expliquant les limites, les profils et les modes temporaires"></a>
  <br><sub>Choisir ses mesures · Trouver de l’aide sans quitter l’app</sub>
</p>

Ces captures non retouchées montrent des exemples de réglages : **80/70 % et 35 °C**. Ces choix sont personnalisables ; ils ne représentent ni des défauts imposés ni une preuve d’essai thermique. Le défaut thermique de l’app est de 40 °C et la validation quotidienne consignée utilise 80/75 %. Voir les [notes de capture](docs/images/README.md).

</details>

## Compatibilité

| Sujet | Périmètre actuel |
|---|---|
| Cible de compilation | macOS 14 ou ultérieur, Swift 6. La Release universelle compile pour arm64 et x86_64 ; seule l’exécution arm64 a été testée. |
| Validation matérielle | MacBook Air M3, 16 Go, macOS 27.2. Les essais réels de charge utilisent USB-C Power Delivery et MagSafe. |
| Moteur natif | Interfaces PowerUI privées, détectées à l’exécution, pour ce Mac qui n’expose plus les anciennes clés SMC de charge. |
| Moteur SMC d’origine | Conservé pour les machines compatibles. Ce fork ne revendique pas de nouvelle validation sur l’ensemble de ces modèles. |
| Distribution | Compilation depuis les sources et signature locale avec son propre certificat. L’app et le service privilégié doivent utiliser la même identité. |

**Une consigne n’est pas une coupure matérielle immédiate.** Les commandes natives peuvent prendre plusieurs minutes. macOS tolère quelques points autour du plafond et peut ponctuellement charger à 100 % pour maintenir sa jauge. Voir la [documentation Apple sur la limite de recharge](https://support.apple.com/fr-fr/102338).

En veille, macOS conserve la dernière cible native ; OpenDente ne surveille pas la température en continu et n’anime pas le voyant. Les contrôles reprennent au réveil. L’app ne peut pas fonctionner lorsque le Mac est éteint. La prévention facultative de veille automatique ne bloque ni la veille manuelle ni celle du capot.

À la fermeture de l’app, le service demande la restauration des réglages Apple sauvegardés et du voyant système. **La limite Apple et ce moteur natif partagent le même mécanisme** ; ce ne sont pas deux protections indépendantes. Configurer la politique Apple à restaurer avant d’activer le mode natif. Le défaut thermique de 40 °C est une précaution de l’app, pas un seuil interne prescrit par Apple ni une coupure de sécurité instantanée. Les protections Apple restent actives.

## Compiler et lancer

Installer et initialiser **Xcode complet** ; les Command Line Tools seuls ne suffisent pas. Il faut aussi **XcodeGen** et une identité Apple Development avec certificat et clé privée. Le service refuse une signature ad hoc.

```sh
git clone --branch feature/personal-battery-care https://github.com/JulienEsbt/OpenDente.git
cd OpenDente
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

bash scripts/build-local.sh "Apple Development: VOTRE NOM (IDENTIFIANT DU CERTIFICAT)" "TEAM_ID"
```

Cette édition se trouve actuellement sur `feature/personal-battery-care` ; utiliser `main` après sa fusion. Remplacer les paramètres de signature par sa propre identité. Le script génère le projet Xcode, exécute les tests natifs, produit une app Debug signée et vérifie que les certificats de l’app et du service sont identiques. Il n’installe et ne lance pas le service privilégié.

1. Copier `build/DerivedData/Build/Products/Debug/OpenDente.app` dans **Applications** et conserver une seule copie installée.
2. Lancer l’app, puis cliquer sur sa batterie dans la barre des menus.
3. Dans **Général**, choisir la langue, activer le service signé si nécessaire et **Ouvrir à la connexion** pour le démarrage discret. Valider les autorisations macOS directement sur le Mac.
4. Dans **Charge**, vérifier les seuils et activer explicitement le moteur natif s’il est proposé. Garder une seule app de contrôle de batterie active.

Pour une Release, les détails de signature et le dépannage, consulter le [guide de développement local](README-PERSONAL.md).

## Validation

La version **0.8.0 (16)** ajoute l’interface bilingue et les couleurs adaptatives ; ses contrôles logiciels figurent dans [VALIDATION.md](VALIDATION.md). Le dernier bilan physique de charge reste celui de **0.7.2 (15), 26 octobre 2026**.

| Contrôle | Résultat consigné |
|---|---|
| Tests natifs | **389 tests XCTest réussis** sur arm64. |
| Tests du service | **36 scénarios de récupération, cycle de vie et watchdog réussis**, avec accès matériels simulés et contrôle natif des types Security/XPC. |
| Charge | Maintien USB-C à 78 % ; reprise à 74 % pour la politique 80/75, poursuite après changement d’alimentation, puis arrêt mesuré et maintien à 80 %. |
| Politique thermique | Pause et reprise physiques vérifiées avec le vrai capteur et un seuil temporaire bas, sans chauffer le Mac. Ce n’est pas un essai à température réellement élevée. |

Les preuves physiques de veille/réveil, relance, restauration et motifs MagSafe sont consignées pour les versions précédentes. Aucune nouvelle veille 0.7.2 ni extinction complète contrôlée n’est revendiquée ; le démarrage de la dernière version pourra être observé au prochain redémarrage habituel. Les résultats sur un Mac ne constituent pas une certification matérielle universelle.

[Bilan complet de validation](VALIDATION.md) · [Portée et commandes des tests du service](tests/helper/README.md)

## Documentation

| Point d’entrée | Contenu |
|---|---|
| [Guide d’utilisation — Français](GUIDE-UTILISATION.md) | Commandes, usage quotidien, stockage, veille et sources sur la batterie. |
| [Développement et signature — Français](README-PERSONAL.md) | Installation Xcode, builds locaux et détails techniques. |
| [Comparatif — Français](COMPARATIF.md) / [English](docs/FEATURE-COMPARISON.md) | OpenDente d’origine, cette édition, AlDente et suites possibles. |
| [Spécification — Français](SPEC-PERSONAL.md) | Comportements attendus et contraintes. |
| [Langue et apparence — English](docs/LOCALIZATION.md) | Choix de langue, ressources de traduction, couleurs et contrôles ciblés. |
| [Journal des changements — Français](CHANGELOG-PERSONAL.md) | Historique des versions. |

Pour le contexte batterie, voir les [limites de recharge Apple](https://support.apple.com/fr-fr/102338) et les [conseils de stockage prolongé](https://www.apple.com/fr/batteries/maximizing-performance/). Aucun gain chiffré de durée de vie n’est promis. La planification, l’intégration Raccourcis et un parcours multiutilisateur validé ne font pas partie de cette édition.

## Architecture et contributions

L’app SwiftUI lit les mesures via IOKit, IORegistry et SMC, puis applique la politique quotidienne avec `ChargingManager`. Une connexion XPC authentifiée par certificat confie les opérations privilégiées au service, qui sélectionne le moteur SMC ou natif disponible. Un journal de récupération et un watchdog permettent de reprendre la restauration après un échec.

Aucun compte, service de télémétrie ou serveur de mise à jour n’est ajouté à l’app. Les exports de diagnostic restent locaux et facultatifs ; relire les identifiants matériels et les journaux avant un partage public.

Une contribution doit préciser le Mac, la version de macOS, le moteur actif et le comportement observé. Garder les modifications ciblées, lancer les tests natifs et du service concernés, et distinguer les simulations des mesures physiques. Les signalements de compatibilité avec étapes de reproduction sont les bienvenus.

## Crédits et licence

Ce projet repose sur **[killerk3emstar/OpenDente](https://github.com/killerk3emstar/OpenDente)**. La limite, le Sailing Mode, le contrôle SMC, les mesures, les notifications et l’architecture initiale viennent du projet amont. L’historique, la licence et les crédits sont conservés, ainsi que le [README d’origine](docs/UPSTREAM-README.md).

Remerciements complémentaires : [Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit), [SMCKit](https://github.com/beltex/SMCKit), [actuallymentor/battery](https://github.com/actuallymentor/battery), [batt](https://github.com/charlie0129/batt), et [Ampere / AZ Code Lab](https://github.com/az-code-lab/ampere) pour le mécanisme natif adapté.

**GPL-3.0.** Voir [LICENSE](LICENSE) et les [mentions tierces](THIRD-PARTY-NOTICES.md), dont l’attribution MIT du code adapté d’Ampere. OpenDente personnel n’est affilié ni à Apple ni à AppHouseKitchen.
