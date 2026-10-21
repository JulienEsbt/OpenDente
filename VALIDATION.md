# Validation de l’édition personnelle

## État actuel — 0.6.0 (10), 21 octobre 2026

Cette section remplace l’état courant de 0.5.0 ci-dessous ; les essais précédents restent conservés comme historique. App installée dans `/Users/julienesbt/Applications/OpenDente.app`, service **1.7.0**, révision du build **27136a4864d8d0bb7e3489a56cec33141e26afac**. Les commits de compte rendu ultérieurs ne changent pas les binaires. MacBook Air M3, macOS 27.2 ; Xcode 27.1, SDK 27.0 et XcodeGen 2.46.0.

### Contrôles logiciels

| Contrôle | Résultat | Preuve |
|---|---|---|
| XCTest natif arm64 | **376/376**, aucun échec | `build/NativeTests-20261021-06.xcresult`, `build/validation/06-xctest.log` |
| Service complet, types Security/XPC | Réussite | `build/validation/06-helper/native-typecheck.log` |
| Bancs complémentaires | **36** : 17 récupération matérielle, 14 cycle de vie, 5 watchdog | `build/validation/06-helper.log`, sous-dossier `06-helper` |
| Release universelle | arm64 et x86_64 compilés ; arm64 exécuté | `build/validation/06-final-release.log` |
| Signatures app et service | Valides en vérification stricte ; certificat feuille identique | Apple Development, SHA-1 public `DDAA721FBC3F2B656F612F4E5988519B593F6DA9` |
| Paquet installé | Identique octet pour octet à la Release ; guide, licence et crédits inclus | `final-delivery.json`, archive app vérifiée |

Les nouvelles régressions couvrent le retour explicite au plafond, sa persistance et son annulation, les priorités thermique/100 %/stockage, la veille sans retrait de consigne, les phases des motifs MagSafe et la réutilisation du journal de récupération. Les journaux rouges attendus précèdent les corrections ; la suite complète finale passe. Les bancs matériels restent simulés. Le code de signature natif est vérifié par compilation complète et l’app réelle utilise le même certificat autorisé ; les bancs ne sont pas présentés comme une preuve de contrôle IOKit réel.

### Descente sur secteur et restitution à Apple

MagSafe reste branché, aucun calcul artificiel lancé pour consommer davantage. Les horodatages ci-dessous sont ceux de Paris.

| Heure | Observation |
|---|---|
| 17:32–17:34 | Ancienne app arrêtée ; limite Apple réglée à **80 %**, recharge optimisée laissée **activée** dans Réglages Système. Lecture PowerUI confirmant la cible 80 %. Cette valeur devient la référence de restauration de la nouvelle session. |
| 17:38:59 | Service **1.7.0** activé et connecté à l’app **0.6.0 (10)** ; les commandes sont refusées tant que l’ancien service 1.6.1 est encore présent. |
| 17:39 | Réglages quotidiens appliqués : **80 % / reprise sous 75 %**, pause thermique **40 °C**, prévention de veille désactivée. Retour au plafond activé explicitement. |
| 17:39:58 | Cible 80 % relue, batterie 96 %, MagSafe connecté ; courant encore nul pendant le délai du système. Une consigne acceptée ne vaut pas effet physique immédiat. |
| 17:40:35 | **Décharge sur secteur mesurée** : ExternalConnected=true, IsCharging=false, courant **−819 mA**, tension **12,368 V**, soit environ **10,1 W** fournis par la batterie. Cible native toujours 80 %. |
| 17:43:20–17:43:29 | Fermeture normale d’OpenDente, restauration confirmée par le service ; voyant rendu à macOS. App arrêtée, cible Apple **toujours 80 %**, MagSafe connecté, courant −757 mA. |
| 17:43 | Réglages Système relus hors d’OpenDente : curseur **80 %**, recharge optimisée **activée**. |
| 17:46:27 | App relancée : retour au plafond activé, seuils 80/75 et motifs conservés. Batterie descendue de 96 à **94 %** sur secteur ; cible 80 %, −1526 mA. |
| 17:46:57 → 17:51:47 | Veille réelle demandée par le propriétaire : 31 s de Software Sleep, DarkWake de maintenance pendant 10 s, puis 249 s de Maintenance Sleep avant réveil utilisateur. Watchdog suspendu puis repris ; aucune restauration à 100 % à l’endormissement. |
| 17:53:26 | Après réveil : cible **80 %**, batterie **93 %**, MagSafe connecté, IsCharging=false, courant **−842 mA** à 12,276 V. Le service reste connecté et les phases de voyant reprennent. |

La descente est réelle. L’essai court ne prétend pas avoir attendu l’arrivée à 80 % depuis 96 % ni une nouvelle recharge complète 75→80. Les essais de reprise réelle de 0.4.1 restent documentés plus bas ; la nouvelle priorité de retour au plafond est couverte séparément par les régressions et cette mesure sur secteur. La préparation au stockage 50 % conserve son essai matériel de 0.5.0.

### Motifs MagSafe

Le préréglage distinct est appliqué : charge normale orange clignotant, maintien vert clignotant, descente sur secteur alternance vert/orange, charge ponctuelle orange fixe puis vert fixe à 100 %, pause thermique éteinte. L’animation réutilise la mesure toutes les deux secondes ; aucun timer supplémentaire ni maintien en éveil n’est ajouté pour le voyant.

Les journaux du contrôleur confirment les séquences **3/1** (vert/éteint), **4/1** (orange/éteint) et **3/4** (alternance), avec retour à la règle après les aperçus de dix secondes. Des lectures ACLC indépendantes confirment les couleurs présentes. Aucune erreur de couleur ou restauration de charge parasite dans ce lot. Seules les commandes connues **0, 1, 3 et 4** sont envoyées ; aucun code matériel de défaut/clignotement d’erreur n’est utilisé. Le propriétaire confirme ensuite : **« Oui, les trois motifs sont visibles »**. Les traces d’avant veille montrent la restitution automatique du voyant ; celles d’après réveil montrent la reprise de l’alternance. La confirmation du contrôleur et la confirmation visuelle du câble sont donc toutes deux acquises.

### Configuration laissée après les essais

App 0.6.0 (10) lancée, service 1.7.0 connecté ; ouverture à la connexion activée, contrôle natif actif, plafond **80 %**, reprise sous **75 %**, **retour au plafond sur secteur activé**, pause supplémentaire **40 °C**, stockage arrêté, prévention de veille automatique désactivée. Signaux MagSafe distincts activés. Limite Apple de référence **80 %**, recharge optimisée activée, restauration lors de la fermeture vérifiée. AlDente reste arrêté et son fonctionnement en arrière-plan désactivé.

### Portée et repères

La limite Apple et le moteur natif d’OpenDente partagent le même mécanisme : ce ne sont pas deux plafonds indépendants. Le réglage Apple de référence à 80 % est restauré quand l’app rend la main. L’endormissement conserve la dernière consigne ; les mesures et la pause thermique personnalisée ne sont pas exécutées en continu pendant la vraie veille. Le voyant revient alors au système. Une extinction complète n’est pas simulée par une simple fermeture de l’app et n’est pas revendiquée comme un essai matériel nouveau.

La valeur 80 % / reprise sous 75 % est un choix pratique proche du comportement décrit par [Apple](https://support.apple.com/en-us/102338), qui reprend après une baisse de plus de cinq points et peut charger occasionnellement à 100 % pour l’estimation de charge. Ce n’est pas un optimum universel démontré pour la cellule de ce Mac. [Apple explique](https://www.apple.com/batteries/why-lithium-ion/) qu’un cycle correspond à l’utilisation cumulée de 100 % de capacité, sans nécessité de décharge complète. Le [résumé de l’étude de Keil et al., 2016](https://portal.fis.tum.de/de/publications/calendar-aging-of-lithium-ion-batteries-i-impact-of-the-graphite-/) relie le vieillissement calendaire au niveau et à la température ; il porte sur trois types de cellules 18650 et ne détermine pas un seuil précis pour ce Mac. Aucun gain chiffré de durée de vie n’est promis.

Le maintien sur secteur n’impose pas de cycles répétés : un courant de batterie nul a déjà été observé lors des essais précédents. La descente volontaire au plafond répond au choix du propriétaire lorsqu’il reprend un Mac déjà trop chargé ; elle n’est pas présentée comme une décharge périodique nécessaire à l’entretien. USB-C n’est pas testé physiquement pendant cette séance. La chauffe volontaire et la coupure thermique immédiate ne sont pas revendiquées. L’interface PowerUI privée reste expérimentale et l’app n’est pas notarifiée.

---

## Historique — 0.5.0


### Livraison 0.5.0 (9), 21 octobre 2026

Cette section remplace l’état courant de 0.4.1 ci-dessous ; les observations anciennes sont conservées comme historique. App installée dans `/Users/julienesbt/Applications/OpenDente.app`, service **1.6.1**, sources de l’app `9d5d5cf266e7b639c9634ded151e920fe8b0a81f`. Le code du service et l’app gardent le même certificat Apple Development, empreinte publique `DDAA721FBC3F2B656F612F4E5988519B593F6DA9`. Aucun export de clé privée, changement d’authentification ou contournement de signature.

### Compilation et tests

| Contrôle | Résultat | Preuve |
|---|---|---|
| XCTest natif arm64 | **363/363**, aucun échec | `build/NativeTests-20261021-led-fixed.xcresult`, `modes-led-fixed-xctest.log` |
| Service complet, types Security/XPC | Réussite | `build/validation/modes-led-final-helper/native-typecheck.log` |
| Bancs complémentaires du service | **35** : 17 récupération, 13 cycle de vie, 5 watchdog | `build/validation/modes-led-final-helper.log` |
| Release universelle | arm64 et x86_64 compilés ; seule l’architecture arm64 exécutée | `modes-led-fixed-release.log` |
| Signatures strictes app et service | Valides, même certificat feuille | certificats publics de contrôle ; aucun secret dans le lot |
| Guide et crédits dans le bundle | JSON chargé et recherché dans l’app installée ; LICENSE et notices présents | régression BundledGuideTests et contrôle du paquet final |

Les tests des politiques et du service utilisent du matériel simulé. Une première Release avait révélé le guide absent du paquet : le test de ressources reproduit cet échec, puis passe après correction de la déclaration XcodeGen. Les tests et la nouvelle Release ont été exécutés après cette correction. Le dernier lot de 363 tests couvre aussi les deux régressions de réponse du voyant. Les avertissements AppIntents sans dépendance ne sont pas des erreurs de charge.

### Mesures réelles du nouveau mode stockage

MagSafe connecté pendant l’essai ; niveau initial **93 %**. Aucun calcul ni charge artificielle lancé pour vider la batterie.

| Heure de Paris | Observation |
|---|---|
| 16:16:46 | Après le redémarrage du propriétaire, l’app et le service 0.4.1 ont démarré automatiquement. Batterie 93 %, chargeur alors débranché. |
| 16:38:28 | MagSafe rebranché par le propriétaire, ExternalConnected=true, IsCharging=false, 0 mA. |
| 16:47:09 | Premier service 1.6.0 connecté après réenregistrement ; app 0.5.0 build 8 affichée et ouverture à la connexion activée. |
| 16:47:28 | Clic sur Préparer le stockage à 50 %. Consigne 50 % confirmée par le service ; état initial encore à 0 mA. |
| 16:48:46 | **Décharge sur secteur confirmée** : ExternalConnected=true, source AC Power, IsCharging=false, courant **−758 mA**, tension 12,381 V, soit environ **9,4 W** fournis par la batterie. Le panneau affiche la descente mesurée. |
| 16:49:00 | Arrêt du mode stockage ; retour demandé au maintien du niveau courant, paramètres quotidiens toujours 80 % / reprise sous 70 %. |
| 16:49:59 | **Annulation physiquement confirmée** : courant 0 mA, IsCharging=false, MagSafe toujours connecté. |

La descente et son annulation sont observées. Il n’a pas été nécessaire d’attendre plusieurs heures jusqu’à 50 %. L’arrêt exact à 50 %, une recharge depuis un niveau inférieur à 50 % et le maintien prolongé à cette cible restent couverts par les politiques testées mais **pas observés matériellement dans cet essai court**. La surveillance thermique à chaud n’est pas testée en chauffant volontairement le Mac.

### Voyant et interface

La commande ACLC est disponible sur ce Mac indépendamment des anciennes commandes de charge. Les valeurs écrites restent automatique (0), éteint (1), vert (3), orange (4). La valeur 2 n’est pas utilisée ; aucun clignotement personnalisé.

**Incident corrigé pendant la séance.** Avec le build 8, le propriétaire a vu une couleur trop brève suivie d’une erreur. La lecture immédiatement après la commande de retour automatique ne renvoie pas nécessairement zéro : elle indique aussi la couleur courante du système. La comparaison erronée a maintenu une récupération en boucle ; cette récupération générale pouvait restaurer le réglage Apple à 100 % et relancer la charge. Cet incident invalide les premières confirmations de voyant comme preuve d’un usage stable. Il a été reproduit par deux tests rouges puis corrigé avant livraison. Aucun échec n’est masqué : les journaux de la première version sont conservés.

Le build **9**, service **1.6.1**, attend brièvement la confirmation d’une couleur. Pour le retour automatique, le succès de l’écriture est l’accusé de libération et la lecture doit rester une valeur connue, sans exiger zéro. La récupération d’un voyant seul n’efface plus la politique de charge d’un client actif. Une perte de heartbeat restaure toujours tous les contrôles.

| Heure de Paris | Contrôle après correction |
|---|---|
| 17:01:07 | Service 1.6.1 connecté, cible de maintien 96 % acceptée. |
| 17:01:29 | Aperçu vert, ACLC lu à 3. |
| 17:01:43–17:01:47 | Aperçu orange, ACLC lu à 4. |
| 17:02:06 | Aperçu éteint, ACLC lu à 1 ; IsCharging=false, courant 0 mA. |
| Après ces aperçus | Propriétaire : « Les trois états tiennent correctement ». Confirmation visuelle sur son câble. |
| 17:03:31 | Bouton Rendre le voyant à macOS sans erreur ; lecture de couleur système 3, aucun impératif de zéro ; charge toujours arrêtée, courant 0 mA. |

Les couleurs par mode sont ensuite réactivées. Les traces montrent la fin des aperçus et le retour à la règle. Les tests couvrent journalisation avant écriture, réponse différée, échec de relecture, restauration partielle et reprise, perte du client, veille sans anciennes clés de charge, fin d’aperçu, séparation voyant/charge et restauration générale après perte de heartbeat.

Le guide hors ligne affiche les modes, les commandes de service, les réglages, le stockage, les LED et la comparaison. La recherche « veille automatique » est vérifiée dans l’app installée et son rendu relu visuellement. Le panneau et Charge montrent la préparation active puis le bouton de démarrage après annulation.

### Configuration et portée

Contrôle natif actif, **80 % / reprise sous 70 %**, pause supplémentaire **40 °C**, stockage arrêté, prévention de veille automatique désactivée, ouverture à la connexion activée. Voyant personnalisé : orange pendant charge mesurée, vert pendant pause, orange pour stockage, éteint pour pause thermique. Retour au contrôle système disponible à tout moment. AlDente reste arrêté et son fonctionnement en arrière-plan désactivé.

Le maintien final est confirmé à 96 %, courant nul et chargeur connecté. Le mode stockage demeure arrêté. Les essais de reprise et de veille de 27 s de la séance 0.4.1 ci-dessous restent les preuves de la politique quotidienne inchangée. Le redémarrage a été observé avec 0.4.1 avant cette mise à jour ; aucun nouveau redémarrage de 0.5.0 n’est revendiqué. La nouvelle récupération LED pendant la veille est testée sur le banc, pas présentée comme un nouvel essai physique de sommeil. USB-C n’est pas testé matériellement. Le moteur PowerUI privé reste expérimental et ne garantit pas une coupure thermique immédiate. L’app n’est pas notarifiée.

---

## Historique jusqu’à 0.4.1

# Bilan de validation — 21 octobre 2026

## Livraison 0.4.1 (7), service 1.5.2

MacBook Air M3 (`Mac15,12`), arm64, 16 Go, macOS 27.2 (`26B118`). Xcode 27.1 (`27A9275`), SDK macOS 27.0, Swift 6.4, XcodeGen 2.46.0. Les commandes Xcode utilisent `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Contrôle exécuté | Résultat | Portée |
|---|---:|---|
| Suite XCTest native arm64 finale | **339/339**, aucun échec ni test ignoré | `build/NativeTests-20261021-daily.xcresult` ; services matériels inertes |
| Banc portable final | **30/30** | Méthodes de production extraites, nouveau type de politique inclus |
| Récupération / cycle de vie / watchdog | **28/28** | Matériel et XPC simulés ; typecheck du helper complet sur le SDK Apple |
| Release 0.4.1 universelle | Réussite | arm64 et x86_64 compilés ; exécution réelle arm64 uniquement |
| Signature app et service | Réussite | Apple Development, vérification stricte et certificat identique ; aucune notarification |
| Client ad hoc reprenant l’identifiant de l’app | Rejeté | Probe getVersion uniquement, après connexion positive de l’app signée ; aucun contournement Debug |

La suite finale ajoute les transitions 80/20, le maintien pendant l’attente, la poursuite d’un cycle jusqu’au plafond, la priorité thermique sur le Top Up, la baisse de 2 °C et le délai de 5 min, les températures absentes/non finies, le redémarrage du délai lors d’un pic, les erreurs de commande, la prévention de veille, et la restauration même sans lecture de batterie. Quatre tests supplémentaires vérifient qu’un onduleur listé en premier ne remplace pas la batterie interne, et que des données absentes, ambiguës ou incohérentes bloquent la commande. La valeur interne réelle a été lue : Type=InternalBattery, Current Capacity=99, Max Capacity=100. Le helper 1.5.2 renforce uniquement cette sélection, sans changer les commandes PowerUI. Les deux scénarios demandés (reprise à 20 % et maintien thermique natif) échouaient avant implémentation dans `native-policy-red.log`, puis réussissent. Les scénarios thermiques historiques conservent leurs assertions avec un seuil explicitement fixé à 35 °C ; le nouveau défaut de 40 °C est testé séparément.

Les derniers journaux sont `build/validation/daily-xctest.log` et `daily-release.log`. Les bancs complémentaires inchangés restent dans `final-portable/` et `final-helper/`. Aucun avertissement Swift de concurrence dans les sources de production. Les avertissements AppIntents sans dépendance et les diagnostics système com.apple.linkd.autoShortcut ne sont pas des échecs de charge.

## Essais de reprise et de veille du 21 octobre, après-midi

Le propriétaire est présent et effectue les débranchements et le réveil. App de contrôle 0.4.0 (6), service 1.5.2 ; aucun changement de la politique de charge dans 0.4.1. Configuration initialement relue : plafond 80 %, reprise sous 70 %, pause thermique 40 °C activée, ouverture à la connexion activée. Les essais utilisent temporairement un plafond de 100 % et une reprise sous 98 %, afin de limiter la baisse naturelle à deux points. Aucune décharge forcée et aucune charge CPU artificielle.

| Heure locale (CEST) | Observation réelle |
|---|---|
| 15:12–15:15 | MagSafe détecté, maintien natif 99 %, IsCharging=false, courant 0 mA |
| 15:14:16 → 15:14:43 | `Software Sleep` puis `Wake from Deep Idle`, durée réelle 27 secondes ; watchdog suspendu puis repris |
| 15:15:03 | Après réveil : MagSafe détecté, maintien 99 %, IsCharging=false, 0 mA ; app et service toujours connectés |
| 15:15–15:21 | Débranchement et baisse naturelle de 99 à 97 % ; lecture IOPS interne et IORegistry concordantes |
| 15:20:39 | Demande de plafond 100 % sous le seuil 98 % ; retrait de la limite bloquante |
| 15:21:32 | Rebranchement MagSafe détecté ; reprise demandée par l’app |
| 15:22:32–15:22:54 | IsCharging=true, NotChargingReason=0 ; courant +1684 mA à 12,914 V, soit environ 21,7 W à 97 % |
| 15:32:10 | Retour à 98 % avec IsCharging=true, +754 mA, NotChargingReason=0 ; consigne 100 % conservée : le cycle continue à la remontée dans la plage |
| 15:33:36 | Après retour aux réglages 80 % / reprise sous 70 % : maintien natif 98 %, IsCharging=false, 0 mA, NotChargingReason=16777216 |
| 15:36:33 | App 0.4.1 installée et relancée : service toujours connecté, maintien 98 %, IsCharging=false, 0 mA |

Le délai entre détection du branchement et courant positif approche une minute. Une consigne acceptée n’a donc pas été assimilée à un arrêt ou une reprise instantanée. Les mesures de la séance et l’extrait veille/réveil sont conservés dans le lot de preuves livré. Cette petite plage valide une reprise réelle après passage sous le seuil, sans revendiquer un cycle complet 80→70→80 ou 80→20→80.

La nouvelle suite 0.4.1 réussit **339/339** (`build/validation/daily-xctest.log`). Le guide de stockage suit le niveau disponible, ne change aucun réglage, ne décharge pas et n’éteint pas le Mac. La zone pratique 45–55 % est distinguée de la recommandation Apple « environ 50 % ». Le voyant natif reste géré par macOS. Seul MagSafe est disponible : aucun essai matériel USB-C n’est déclaré.

## Configuration laissée à la fin de la séance

OpenDente **0.4.1 (7)** est installé et lancé dans `/Users/julienesbt/Applications/OpenDente.app`. Contrôle natif activé, plafond habituel **80 %**, reprise sous **70 %**, pause thermique activée à **40 °C**, prévention de veille automatique désactivée, ouverture à la connexion activée. Les choix personnels d’affichage de la barre des menus sont conservés. Le niveau réel reste 98 % après l’essai : maintien au niveau courant, puis baisse naturelle à l’usage ; aucun ordre de décharge vers 80 %.

Le build livré porte `OpenDenteSourceRevision=0955eec21591de2d4bbfe86cda702b1319af76f8`. L’app installée et le build livré sont identiques fichier par fichier. Le service embarqué est identique au binaire déjà installé : aucune nouvelle installation privilégiée nécessaire. Les deux signatures sont valides avec le même certificat public ; l’app reste non notarifiée.

Le guide et les explications de chargeur sont vérifiés dans l’app installée : le propriétaire a ouvert les deux rubriques, puis leur contenu a été relu par accessibilité et leur rendu contrôlé visuellement. Le guide affiche correctement le niveau courant 98 % et les étapes de stockage. Général confirme 0.4.1 (7), « Connecté — mode natif disponible » et ouverture à la connexion activée. Le lot de preuves joint contient les mesures horodatées, les événements de charge, l’extrait de veille et les journaux de build/tests.

## Observations matérielles

1. Les clés CHTE, CH0B, CH0C et CH0I sont absentes même depuis le helper root. CHIE et ACLC existent. Le contrôle de charge SMC d’origine est donc indisponible ; aucun succès SMC n’est revendiqué.
2. L’app et son service signés communiquent réellement. L’ancienne version du service est refusée ; la mise à jour vers 1.5.1 a été effectuée par SMAppService. Le premier refus d’installation a été résolu par l’action Activer le service après désenregistrement, sans contourner les autorisations macOS.
3. Le premier backend 0.3.0 écrivait un état de préférence supposé actif et recevait une relecture concordante, sans plafond enregistré dans powerd. Cet essai a échoué. Le correctif appelle le setter PowerUI plutôt que de deviner l’énumération privée de l’état.
4. Avec le helper corrigé 1.5.1 et la batterie à 99 %, le plafond natif 99 est enregistré par macOS (pmset battlimit), `ExternalConnected=Yes`, `IsCharging=No`, `Amperage=0`, `NotChargingReason=16777216`. PowerUI indique PausedForMCL.
5. La charge ponctuelle à 100 % retire ce plafond : batterie toujours à 99 %, `ExternalConnected=Yes`, `IsCharging=Yes`, `Amperage=1274` mA, puissance batterie d’environ 16,5 W, NotChargingReason=0. L’annulation rétablit le plafond 99 et le courant nul. Ce contrôle aller-retour permet de distinguer la pause d’une simple fin de charge normale.
6. Désactiver le contrôle retire le plafond enregistré : pmset ne rapporte plus de limite. Le service ne remonte pas d’erreur de restauration. Le réglage natif sauvegardé était 100 % pour ces essais ; il est restauré en quittant le contrôle.

Ces observations de charge concernent le service 1.5.1 dans l’app 0.3.1. Le même service, le même certificat et le chemin de consigne restent utilisés par 0.4.0. La politique de reprise/thermique ajoutée dans 0.4.0 est vérifiée par les tests et les contrôles d’interface, avec les limites matérielles ci-dessous.

## Interface et configuration avant la séance de l’après-midi

La version 0.4.0 est installée dans `/Users/julienesbt/Applications/OpenDente.app` avec sauvegarde de la précédente. Dans la section Charge, le curseur de reprise a été placé à 20 % et la température à 41 °C, puis les valeurs finales ont été appliquées : plafond 80 %, reprise sous 75 %, pause supplémentaire activée à 40 °C. Les champs sont actifs ; le texte suit les valeurs. L’ouverture à la connexion est enregistrée : l’interface confirme le statut enabled de SMAppService.mainApp, pas seulement une préférence locale.

Avec le build 5 de 0.4.0 et le service 1.5.1, le maintien 99 % est de nouveau observé chargeur branché, IsCharging=No et courant nul. Un client ad hoc est rejeté pendant que la véritable app est connectée. Le build 6 embarque la garde de sélection interne et exige le service 1.5.2.

AlDente est arrêté et son autorisation de fonctionnement en arrière-plan a été désactivée avec validation locale du propriétaire ; l’app reste installée. La configuration Apple initiale était 80 % avec recharge optimisée. Pour les essais, la limite Apple a été passée à 100 % et la recharge optimisée suspendue temporairement jusqu’à 06:00. Le moteur natif restaure la limite 100 % sauvegardée lorsqu’il est désactivé : ce choix d’essai n’est pas le plafond habituel 80 % stocké dans OpenDente.

## Éléments qui restent à observer en usage réel

- Descente naturelle depuis le plafond jusqu’au seuil bas, puis retour au plafond : ni 80/75 ni 80/20 n’ont fait l’objet d’un cycle physique complet durant cette séance.
- Pause lors d’une température réellement élevée et reprise après refroidissement : pas de chauffe volontaire du Mac. Les transitions et erreurs sont simulées dans XCTest ; l’action native de maintien est celle observée à 99 %.
- Ouverture après déconnexion/reconnexion de session : l’enregistrement du démarrage automatique est contrôlé dans l’interface ; ce n’est pas une exécution après reconnexion. La veille/réveil réelle de 27 secondes est validée dans la séance de l’après-midi.
- Comportement pendant une calibration firmware, après redémarrage complet, sous charge prolongée et sur x86_64. Rejet d’un client signé avec un autre certificat non testé ; le test négatif ad hoc est distinct.

Le précédent essai de débranchement n’avait pas pu être réalisé ; la séance de l’après-midi ajoute les mesures de reprise et de veille décrites plus haut. La version reste expérimentale et ne garantit pas un arrêt thermique immédiat. Une consigne privée peut changer de comportement lors d’une mise à jour de macOS.

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
