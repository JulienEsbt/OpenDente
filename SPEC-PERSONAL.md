# OpenDente — édition personnelle 0.6.2

Base GPL-3.0 : killerk3emstar/OpenDente, commit `06c5a8199f5c0657374e667073b3aa6a75f50df8` ; reprise personnelle initiale `0f53a5e`. Développement local dans `/Users/julienesbt/Dev/OpenDente`, branche `feature/personal-battery-care`, fork JulienEsbt/OpenDente. Historique, licence et crédits conservés.

## Fonctions livrées

- App native SwiftUI dans la barre des menus, panneau français, état physique séparé des demandes, mesures disponibles sans valeurs inventées.
- Plafond modifiable, reprise configurable sous un seuil bas, dont 20 % pour un plafond de 80 %. Le retour au plafond sur secteur est une option explicite, conservée au relancement. Aucun cycle continu n’est forcé.
- Charge ponctuelle à 100 %, plafond habituel conservé ; fin au débranchement ou à l’annulation. Une pause thermique conserve la demande.
- Pause thermique supplémentaire configurable ; défaut de précaution à 40 °C, distinct des recommandations de température ambiante Apple. Ce seuil n’est pas certifié par Apple.
- Lancement silencieux dans la barre des menus, sans panneau de mise à jour ni restauration automatique des réglages. Fermer les fenêtres conserve le processus ; réouverture manuelle du panneau disponible. Fonctionnement panneau fermé, prévention facultative de la veille automatique et ouverture à la connexion enregistrée auprès de macOS. La fermeture du capot reste une demande de veille.
- Mode stockage explicite à 50 % : demande de décharge sur secteur au-dessus, recharge en dessous, conservation des seuils quotidiens et arrêt manuel. Aucun calcul pour accroître la consommation, aucune extinction automatique. Guide Apple pour la conservation après extinction.
- Règles MagSafe natives vert/orange/éteint/automatique, aperçus de 10 s et restitution journalisée indépendante des commandes de charge SMC. Motifs lents par alternance des commandes connues, sur le rythme de mesure existant ; retour au système pendant la veille. Guide hors ligne consultable et recherchable pour tous les réglages.
- Aucun réseau, analytics, mise à jour automatique ou nouvelle dépendance externe à l’exécution.

## Compatibilité et mécanismes

Le Mac cible est un MacBook Air M3, 16 Go, macOS 27.2 (26B118). Les anciennes clés SMC d’inhibition CHTE/CH0B/CH0C y sont absentes, y compris depuis le service root. Le moteur d’origine reste disponible sur les Mac qui les exposent.

Le propriétaire a autorisé un moteur natif expérimental. Le service 1.7.0 utilise les interfaces privées PowerUI détectées à l’exécution ; le setter Apple 80–100 % initialise correctement l’état natif. Sous 80 %, seule la préférence de cible est ensuite modifiée. Aucun appel du setter hors de sa plage, aucune archive powerd modifiée, aucune coupure CHIE de l’adaptateur, aucun changement d’autorisations Apple ou de sudoers.

Avant toute modification, un journal root conserve les préférences MCL, y compris les valeurs temporaires. Un plafond ordinaire inférieur au niveau fraîchement lu est refusé. Les commandes dédiées et authentifiées prepareStorage (50 %) et dischargeToLimit (20–100 %, cible au plus égale au niveau courant) autorisent la descente explicite sur secteur. Désactivation, déconnexion, watchdog et redémarrage du service demandent la restauration ; un échec conserve le journal et l’erreur. La désactivation fonctionne aussi sans lecture courante de batterie.

Le service authentifie l’identifiant de l’app et son certificat identique au sien par NSXPCConnection, sans exception Debug. Les deux cibles sont signées Apple Development. La clé privée reste dans le Trousseau.

## Limites explicites du moteur natif

- Une consigne acceptée n’est pas une preuve d’arrêt. Le panneau affiche si la batterie charge encore et signale une pause non confirmée après 90 secondes.
- Application pouvant approcher une minute ; le firmware garde son propre comportement et peut calibrer jusqu’à 100 %. Ni le seuil de reprise exact ni l’arrêt thermique immédiat ne sont garantis.
- Pendant l’attente, la consigne suit les baisses naturelles du niveau. Après passage sous le seuil bas, la charge peut continuer jusqu’au plafond. Aucun exercice de batterie n’est imposé.
- Pause thermique : reprise après au moins 5 minutes sans dépassement et 2 °C de refroidissement. Une mesure manquante ne suffit pas à lever la pause. Sous 20 %, le moteur ne peut pas maintenir exactement le niveau courant.
- Pendant la veille, le dernier plafond reste confié à macOS. Les décisions de seuil et de température reprennent au réveil ; il n’existe pas de surveillance applicative thermique continue pendant le sommeil du Mac.
- La régulation par pourcentage matériel et la pause dédiée à la veille restent réservées au moteur SMC. Le moteur natif permet le stockage à 50 % et le retour au plafond quotidien explicitement activé. Le voyant ACLC est contrôlé séparément des anciennes clés de charge.

## Validation

380 XCTest natifs réussis ; 36 scénarios de récupération/cycle de vie/watchdog ; contrôle des types du helper complet et Release universelle signée. Les bancs n’exécutent pas les accès matériels de production.

Des arrêts et reprises physiques ont été observés à 99 % avec le service 1.5.2, ainsi que le retrait du plafond lors de la restauration. Une veille réelle de 27 secondes avec maintien après réveil et une reprise après baisse naturelle de 99 à 97 % sont observées avec une plage temporaire 100/98, ainsi que la poursuite du cycle à 98 % et le retour au maintien après restauration 80 % / 70 %. Le passage complet 80 vers 75 ou 20, l’arrêt à chaud et un essai USB-C ne sont pas revendiqués. Voir VALIDATION.md pour les preuves et la configuration réellement laissée sur le Mac.

## Hors périmètre

Programmation horaire, Raccourcis, calibration forcée, télémétrie et mise à jour automatique. Le code macOS de contrôle matériel ne se porte pas directement à l’iPhone ou à l’Apple Watch.
