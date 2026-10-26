# OpenDente personnel et AlDente

Comparaison relue le **26 octobre 2026**, avec les [notes officielles AlDente 1.40](https://github.com/AppHouseKitchen/AlDente-Battery_Care_and_Monitoring/releases/tag/1.40), à partir des [fonctions publiées par AppHouseKitchen](https://apphousekitchen.com/fr/aldente/fonctionnalites/). La colonne AlDente décrit les annonces de l’éditeur, pas un essai comparatif sur ce Mac. La colonne personnelle décrit le moteur natif testé sur le MacBook Air M3 sous macOS 27.2 ; le moteur SMC d’origine a un périmètre distinct.

[README français](README.fr.md) · [Comparison in English](docs/FEATURE-COMPARISON.md)

## Fonctions présentes et écarts

| Fonction | OpenDente personnel 0.7.2, moteur natif | Offre publiée d’AlDente |
|---|---|---|
| Limite de charge | Oui ; cible native différée, état mesuré présenté séparément | Free / Pro |
| Seuil de reprise / Mode Voile | Oui ; baisse naturelle, puis recharge jusqu’au plafond | Pro |
| Décharge automatique vers le plafond | Oui, sur activation explicite et persistante | Pro |
| Décharge manuelle | Stockage temporaire à 50 % ou retour facultatif au plafond choisi ; pas de décharge SMC arbitraire revendiquée sur ce Mac | Free / Pro |
| Recharge complète ponctuelle | Oui ; la pause thermique garde sa priorité | Pro |
| Protection thermique | Pause supplémentaire différée, Mac éveillé ; pas de coupure matérielle immédiate | Pro |
| LED MagSafe | Couleurs fixes, clignotements lents, alternance et aperçus ; retour au système pendant la veille | Pro ; clignotement pendant la décharge également proposé sur MagSafe 3 |
| Empêcher la veille jusqu’à la limite | Assertion facultative contre l’inactivité ; veille manuelle et capot conservés | Pro |
| Maintien éveillé à la demande, indépendant de la charge | Absent ; l’option existante concerne la charge vers le plafond | Pro, ajouté en 1.40, avec durée et arrêt à batterie basse |
| Après une calibration macOS | Le retour au plafond traite déjà un niveau trop élevé, Mac éveillé ; pas de parcours complet de calibration | Pro : retour au plafond ou poursuite de calibration, choix ajouté en 1.40 |
| Arrêt spécifique pendant la veille | Dernière cible native conservée par macOS ; pas de surveillance thermique applicative continue | Pro |
| Arrêter la charge quand l’app est fermée | Restauration du réglage Apple sauvegardé ; pas d’arrêt indéfini séparé laissé par l’app | Pro |
| Icônes d’état en direct | Oui | Pro |
| Flux de puissance | Affichage simple ; pas de Sankey animé | Pro |
| Pourcentage matériel | Mesure informative si disponible ; régulation native fondée sur le pourcentage macOS | Pro ; la documentation actuelle régule aussi sur le pourcentage macOS |
| Permutation rapide d’utilisateur | Non validée ; pas de garantie d’arbitrage entre sessions | Free / Pro |
| Planification | Absente | Pro ; jours choisis et prochaine exécution en 1.40 |
| Intégration Raccourcis | Absente | Pro |
| Calibration guidée | Absente | Pro |

OpenDente propose aussi un mode de stockage temporaire autour de 50 %, un guide français hors ligne et un export local de diagnostic. Compter les fonctions ne prouve ni une équivalence, ni une consommation inférieure, ni une meilleure fiabilité ou durée de vie.

## Les ajouts utiles à envisager

| Priorité | Piste | Utilité | Conditions avant livraison |
|---|---|---|---|
| 1 | **Actions Raccourcis** : plafond, charge ponctuelle, stockage | Réutiliser les modes depuis un raccourci clavier ou une automatisation | Conserver activation explicite et priorité thermique ; signaler les refus et commandes indisponibles |
| 2 | **Planification facultative** d’une charge ponctuelle | Préparer une journée prévue loin du secteur | Définir le rattrapage des tâches et la veille ; ne pas promettre un pourcentage exact à l’heure du départ |
| 3 | **Compatibilité et sessions supplémentaires** | Priorité pour diffuser au-delà de la machine initiale | Autres Mac/macOS, autres alimentations USB-C, extinction et changement de compte ; l’essai USB-C 20 W du M3 ne valide pas toutes les configurations |
| 4 | **Distribution publique notarifiée** | Simplifier l’installation par d’autres personnes | Travail distinct de signature, notarification et validation de livraison ; aucun installateur public annoncé actuellement |

Le maintien éveillé temporisé est une autre commodité possible pour un long calcul, avec arrêt à batterie basse. Il ne préserve pas la batterie par lui-même ; il reste distinct du contrôle de charge. Les exports compressés et informations de dernière charge complète sont des améliorations de confort, de priorité moindre.

Ces pistes sont des propositions, pas des réglages cachés ni des fonctions déjà livrées. Elles ne sont pas nécessaires à l’usage actuel du plafond quotidien et des modes temporaires sur le Mac testé.

## Ce qu’il ne faut pas reprendre automatiquement

**La calibration par décharge profonde régulière.** Le calendrier proposé par AlDente est celui de son éditeur, pas une recommandation Apple pour chaque batterie de Mac. [Apple décrit les cycles cumulés](https://www.apple.com/batteries/why-lithium-ion/) sans imposer une décharge complète avant recharge. Sa [limite native](https://support.apple.com/en-us/102338) prévoit déjà des charges occasionnelles complètes pour la jauge. OpenDente n’impose pas de cycle profond mensuel et ne désactive pas sa pause supplémentaire pour en effectuer un.

**Un seuil interne déduit de la température de la pièce.** Le capteur de batterie est distinct de la [plage ambiante recommandée par Apple](https://support.apple.com/en-us/102336). Le défaut de 40 °C est présenté comme une précaution de l’app, pas comme une consigne Apple pour ce capteur.

**Un contrôle continu pendant l’extinction ou la vraie veille.** L’app ne tourne pas lorsque le Mac est éteint. La cible native peut rester confiée au système pendant la veille ; les décisions personnalisées reprennent au réveil. Le [bilan de validation](VALIDATION.md) distingue les observations physiques des politiques testées.

## Ce qui vient de l’original et ce qui change

La base possède déjà limite, Sailing Mode, logique thermique, décharge SMC, charge ponctuelle, voyant, mesures, diagnostics locaux et notifications. Le fork ajoute la présentation française, les profils, le moteur PowerUI du Mac testé, les intentions temporaires séparées, la préparation à 50 %, les motifs natifs du voyant, des corrections de récupération et d’authentification, le lancement discret et le diagnostic natif corrigé.

L’original examiné est le commit [`06c5a8199f5c0657374e667073b3aa6a75f50df8`](https://github.com/killerk3emstar/OpenDente/tree/06c5a8199f5c0657374e667073b3aa6a75f50df8). Son auteur annonçait une bêta testée sur un M4/Tahoe ; cela n’est pas transformé en validation matérielle de ce fork. L’historique, la GPL et les crédits restent conservés.

Sources : code original au commit ci-dessus, [documentation AlDente](https://apphousekitchen.com/fr/aldente/fonctionnalites/) et documentation Apple liée. Les fonctions AlDente dépendent du modèle et de la version. OpenDente est un fork GPL-3.0 indépendant, sans affiliation à Apple ni AppHouseKitchen.
