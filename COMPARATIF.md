# OpenDente personnel et applications de référence

État examiné le 21 octobre 2026. L’original est celui du commit `06c5a8199f5c0657374e667073b3aa6a75f50df8`. La colonne personnelle décrit le MacBook Air M3 sous macOS 27.2 et le moteur natif expérimental, pas toutes les machines. Les fonctions AlDente sont celles annoncées par son éditeur ; leur présence ne constitue pas un essai comparatif sur ce Mac.

| Fonction | OpenDente d’origine | Édition personnelle 0.6.0 sur ce Mac | AlDente |
|---|---|---|---|
| Plafond de charge | Oui, moteur SMC | Oui, moteur natif macOS ; effet différé | Free et Pro |
| Reprise sous un seuil inférieur | Oui, Sailing Mode | Oui, modifiable, par exemple 80/70 ou 80/75 ; pas de décharge imposée par les profils | Pro |
| Charge ponctuelle à 100 % | Oui, déjà dans le code | Oui, annulation et priorité thermique conservées | Pro |
| Pause thermique | Oui, SMC | Demande de maintien, délai possible, pas d’arrêt immédiat garanti ni surveillance pendant la veille | Pro |
| Décharge sur secteur | Oui, libre vers la limite SMC | Stockage à 50 % et retour automatique au plafond choisi sur activation explicite | Free ; automatisation en Pro |
| Préparer un stockage autour de 50 % | Possible avec les commandes générales | Mode temporaire dédié, seuils quotidiens conservés, état mesuré et annulation | Réglages de charge/décharge ; pas de comparaison d’un assistant dédié |
| Voyant MagSafe | Oui, selon le mode | Couleurs fixes, clignotement lent et alternance animés par l’app éveillée, aperçus de 10 s | Pro, également clignotement orange sur MagSafe 3 |
| Limiter la veille automatique | Oui | Facultatif pendant charge/décharge vers la limite ; veille manuelle et capot conservés | Pro |
| Arrêt spécifique de charge pendant le sommeil | Oui, SMC | Dernier plafond confié à macOS ; pas de contrôle thermique applicatif pendant le sommeil | Pro |
| Affichage, puissance, température, cycles, notifications | Oui | Conservés ; interface française, profils et explications détaillées | Plusieurs fonctions avancées Pro |
| Programmation horaire / Raccourcis / calibration guidée | Absents | Absents | Pro |
| Codes sources / abonnement | GPL-3.0, pas de palier payant | Fork GPL-3.0 personnel, sans palier payant | Offre Free et offre Pro commerciale |
| Compatibilité annoncée | Bêta testée par l’auteur sur M4/Tahoe | Essais consignés sur ce M3/macOS 27.2 ; API privée expérimentale | Support macOS 27 annoncé dans 1.39 |

## Ce qui change réellement par rapport à la base

Les limites, Sailing Mode, la chaleur, la charge ponctuelle, les LED et les mesures existaient déjà. L’édition personnelle ajoute l’interface française et ses profils, le moteur de remplacement pour ce Mac sans anciennes clés de charge, le mode temporaire 50 %, les aperçus du voyant, un guide consultable, ainsi que des corrections d’authentification, de récupération et de politique thermique. Elle conserve la licence, l’historique et les crédits d’origine.

Un nombre de tests supérieur ne prouve pas une meilleure fiabilité qu’AlDente. La pause native peut être retardée, et macOS peut faire une recharge de calibration à 100 %. Une consigne et une couleur ne remplacent pas les mesures de courant. Les essais réellement exécutés et les limites restantes figurent dans VALIDATION.md.

Sources : [README original](https://github.com/killerk3emstar/OpenDente/blob/06c5a8199f5c0657374e667073b3aa6a75f50df8/README.md), code original au même commit, [fonctions AlDente](https://apphousekitchen.com/aldente-overview/features/), [annonce AlDente 1.39](https://github.com/AppHouseKitchen/AlDente-Battery_Care_and_Monitoring/releases/tag/1.39). Le tableau résume les fonctions sans reprendre les recommandations de calibration de l’éditeur comme une consigne Apple.
