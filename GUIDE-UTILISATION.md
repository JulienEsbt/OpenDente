# Guide des commandes OpenDente — édition personnelle 0.5.0

Ce guide décrit le fonctionnement visé de cette édition et ses limites. La validation matérielle réellement effectuée figure dans VALIDATION.md.

## Panneau principal et modes

### Bureau · Quotidien · Mobilité

Appliquent respectivement 70/60, 80/70 et 90/80 : plafond / reprise sous le seuil bas. Ils activent la pause thermique, quittent le mode stockage et évitent une décharge automatique. Ce sont des points de départ modifiables.

### Limite habituelle de charge

Choisit le plafond quotidien entre 20 et 100 %. Une limite inférieure au niveau actuel suspend la recharge sans forcer la batterie à descendre. Modifier ce curseur quitte le mode stockage.

### Charger à 100 % cette fois

Demande une charge complète temporaire et conserve tes seuils quotidiens. Quitte le mode stockage. La demande attend si une pause thermique est active ; elle finit au débranchement, à l’annulation ou à l’arrêt de l’app.

### Revenir à ma limite

Annule la charge ponctuelle. Au-dessus de ton plafond, l’app demande de tenir le niveau courant, puis laisse la baisse naturelle à l’usage.

### Préparer le stockage à 50 %

Active une cible temporaire à 50 % sans écraser ton plafond habituel. Au-dessus, autorise explicitement une descente sur secteur ; en dessous, demande une recharge vers 50 %. Aucun calcul n’est lancé pour vider la batterie plus vite. L’effet dépend du service de macOS et s’affiche séparément de la demande.

### Arrêter le mode stockage

Annule la cible temporaire et revient à tes réglages quotidiens sauvegardés. Ce bouton permet d’arrêter un essai de préparation. La cible 50 % reste active tant que le mode est choisi, y compris après relancement de l’app.

### Réglages… · icône de curseurs

Ouvre les réglages. Fermer cette fenêtre ou le panneau ne quitte pas OpenDente : le suivi continue en arrière-plan.

### Quitter

Ferme réellement l’app et demande au service de restaurer le réglage Apple sauvegardé, ainsi que le voyant système. Le plafond 80 % d’OpenDente n’est plus maintenu par l’app après sa fermeture. Pendant nos essais, la valeur Apple sauvegardée est 100 %.

## Charge : ce que contrôlent les réglages

### Activer le contrôle de charge

Active le moteur expérimental de macOS 27. Désactivé, OpenDente reste un lecteur de batterie et restaure le réglage Apple sauvegardé ; le mode stockage est annulé. Une demande native peut prendre environ une minute et macOS peut dépasser une cible pour sa calibration.

### Arrêter à

Même plafond quotidien que le curseur du panneau. La cible temporaire de stockage reste distincte. Les boutons de profils quittent ce mode.

### Choisir quand la charge reprend · Reprendre sous

À 80/70, la recharge attend que le niveau passe sous 70 %, puis continue vers 80 %. Cela espace les reprises, sans imposer de descente de 80 à 70 sur secteur. Désactiver ce choix permet de reprendre dès que le niveau passe sous le plafond. Attendre 20 % n’est pas nécessaire à l’entretien de la batterie.

### Demander une pause si la batterie chauffe · Température

Compare le capteur interne au seuil choisi, entre 30 et 45 °C. La valeur 40 °C est un choix de précaution de l’app, pas un seuil interne officiel Apple. La reprise attend au moins 5 minutes sans dépassement et 2 °C de refroidissement. La charge ponctuelle et le stockage respectent cette priorité.

### Empêcher la veille automatique jusqu’à la limite

Retarde la veille pour inactivité pendant une charge vers la cible, ou pendant une préparation active si l’option s’applique. L’écran peut s’éteindre. Le Mac peut toujours être mis en veille manuellement et la fermeture du capot reste une demande de veille. L’option est libérée au plafond, au débranchement ou à l’arrêt de la charge. Elle consomme davantage que laisser le Mac dormir ; laisse-la désactivée si tu n’en as pas besoin.

### Pendant la veille

macOS conserve le dernier plafond transmis. OpenDente ne continue pas à mesurer la température pendant le sommeil du Mac ; il réévalue au réveil. La pause supplémentaire n’est pas une coupure de sécurité immédiate.

### Appliquer 80 % / reprise sous 75 %

Applique ce couple conseillé pour un Mac souvent branché, active la plage de reprise et désactive la décharge automatique. Quitte le mode stockage. C’est un choix pratique proche du comportement natif, pas une obligation Apple.

### Autres commandes du moteur SMC

Rubrique d’information sur les anciens Mac compatibles. Sur ce Mac sous macOS 27, la décharge libre vers n’importe quel plafond, la régulation par pourcentage matériel et la pause dédiée à la veille ne passent pas par les anciennes commandes SMC. Le stockage explicite à 50 % utilise un autre mécanisme.

## Voyant MagSafe

### Adapter le voyant aux modes

Active les règles de couleur de l’app. Ce réglage change uniquement le voyant, pas le plafond ou la vitesse de charge. Il est indépendant de l’ancienne préférence du moteur SMC et reste désactivé au départ.

### Charge confirmée · Pause confirmée

Choisissent la couleur quand la batterie reçoit encore du courant ou lorsque la pause est mesurée. Une simple demande de pause n’affiche pas prématurément la couleur de pause.

### Descente en mode stockage · Pause thermique

Choisissent la couleur de ces modes quand la batterie ne charge plus. Le panneau indique séparément si un courant de décharge est réellement observé.

### Vert (10 s) · Orange (10 s) · Éteint (10 s)

Aperçu temporaire du voyant, sans modifier tes seuils de batterie. Après environ dix secondes, retour aux règles choisies ou à macOS si la personnalisation est désactivée. Le matériel doit confirmer l’écriture ; une erreur est affichée dans la rubrique.

### Rendre le voyant à macOS

Interrompt l’aperçu, désactive la personnalisation et demande le retour au contrôle système, y compris après un essai échoué. L’app rétablit aussi ce contrôle au débranchement, à la veille, à la fermeture et en récupération après perte du client.

### Couleurs et clignotement

Les commandes utilisées proposent vert, orange, éteint et automatique. Le voyant n’est pas RGB. Cette version ne crée pas de clignotement personnalisé. Apple utilise notamment un clignotement orange répété pour signaler certains défauts de charge. [Source](https://support.apple.com/fr-fr/102372).

## Général : lancement et service

### Ouvrir à la connexion

Enregistre l’app auprès de macOS pour qu’elle démarre après ouverture de ta session. Cela ne maintient pas l’app active lorsque le Mac est éteint. Le démarrage a été observé après ton redémarrage du 21 octobre.

### Activer le service

Enregistre le service administrateur signé fourni dans l’app. Il est nécessaire pour appliquer les commandes matérielles ; macOS peut demander une validation locale.

### Ouvrir les Réglages Système

Affiché si macOS demande d’autoriser le service dans les éléments d’ouverture. Le bouton ouvre la page de réglages concernée.

### Réessayer la connexion

Refait la connexion et vérifie la version et la signature du service, sans changer tes seuils.

### Réinstaller le service

Demande d’abord la restauration, puis réenregistre le service embarqué. Sert à une mise à jour ou à une réparation, pas à l’usage quotidien. Les mots de passe ou Touch ID éventuels se saisissent directement dans macOS.

## Notifications, affichage et diagnostic

### Activer les notifications

Autorise les demandes de notifications de l’app. Leur affichage dépend aussi de l’autorisation macOS et des modes Concentration ; ce réglage ne change pas la charge.

### Limite atteinte · Charge ponctuelle terminée · Protection thermique · Décharge terminée

Permettent de choisir les événements annoncés. Les notifications ne remplacent pas l’état réel affiché dans le panneau. Le bouton de notification de test existe seulement dans les builds de développement.

### Barre des menus : pourcentage · température · consommation · icône du mode

Choisit les éléments visibles à côté de l’icône dans la barre du Mac. Ne change ni les seuils ni la puissance de charge.

### Panneau : Afficher les flux d’énergie

Affiche ou masque le schéma des puissances mesurées. Les valeurs absentes ne sont pas inventées ; ce schéma est une lecture, pas une commande.

### Panneau : boutons en forme d’œil · ordre des mesures

L’œil affiche ou masque une mesure dans le panneau. Déplacer les lignes dans la liste Affiché change leur ordre. Les mesures restent disponibles dans Batterie.

### Batterie : mesures, profils USB-PD, état du service

Affiche les valeurs disponibles : température interne, capacité, cycles, puissances, courant, tension et chargeur. Les profils USB-PD sont des informations lues ; cliquer ne change pas la tension ou la puissance du chargeur.

### Exporter un diagnostic…

Ouvre un choix de fichier pour enregistrer localement les mesures, réglages et journaux récents. Aucun envoi réseau automatique. Le fichier peut contenir des informations d’identification du Mac ou du chargeur ; il sert au dépannage.

## Stockage prolongé et alimentation

### Préparer le Mac puis l’éteindre

Le mode 50 % prépare la charge avant une longue inutilisation. Une fois autour de 50 %, débranche puis éteins depuis le menu Pomme. L’app ne fait pas d’extinction automatique et ne peut pas surveiller une batterie lorsque le Mac est éteint.

### Conservation

Apple conseille environ 50 %, appareil éteint, dans un lieu frais et sec à moins de 32 °C. Pour un stockage dépassant six mois, recharge autour de 50 % tous les six mois. La zone 45–55 % du guide est un repère pratique, pas une plage officielle Apple. [Source](https://www.apple.com/fr/batteries/maximizing-performance/).

### MagSafe et USB-C

La politique vise la batterie interne et est conçue pour les deux ports, avec une alimentation USB-C Power Delivery adaptée. Les essais matériels de cette séance utilisent MagSafe ; l’USB-C n’est pas présenté comme testé. Un chargeur trop faible peut ne pas couvrir la consommation du Mac. [Source](https://support.apple.com/fr-fr/102397).

## Par rapport à OpenDente d’origine

### Fonctions déjà présentes

La base possède déjà limite, reprise, chaleur, décharge SMC, charge ponctuelle, voyant, notifications et personnalisation des mesures. Ces fonctions ne sont pas toutes des ajouts personnels.

### Ce que l’édition personnelle ajoute ou renforce

Interface française, profils Bureau/Quotidien/Mobilité, moteur expérimental macOS 27 sur ce Mac, modes temporaires séparés des seuils quotidiens, stockage à 50 %, règles MagSafe et aperçus, explications, signature identique app/service et récupération après erreurs.

### Ce que nous ne prétendons pas avoir

Aucune calibration forcée, programmation horaire, intégration Raccourcis, mise à jour automatique ou promesse de gain chiffré de durée de vie. Les fonctions SMC de la base restent conservées pour les Mac compatibles ; elles ne deviennent pas disponibles par un simple réglage sur ce Mac.

### Source de comparaison

Base examinée : killerk3emstar/OpenDente, commit 06c5a8199f5c0657374e667073b3aa6a75f50df8. Licence GPL et crédits conservés. [Source](https://github.com/killerk3emstar/OpenDente/tree/06c5a8199f5c0657374e667073b3aa6a75f50df8).

## Par rapport à AlDente

### Free / Pro

La documentation distingue une édition gratuite avec limite et décharge, et des fonctions Pro : reprise, chaleur, voyant, charge ponctuelle, calendrier, Raccourcis et calibration.

### Différences utiles ici

Notre stockage a une cible dédiée à 50 %. AlDente propose aussi une décharge sur secteur et une décharge automatique. Son contrôle MagSafe 3 peut clignoter orange ; notre version conserve des couleurs fixes.

### Compatibilité et portée

AlDente 1.39 annonce le support macOS 27. Cela ne constitue pas un essai comparatif sur ce Mac. Notre moteur reste expérimental ; aucune supériorité de fiabilité ou d’autonomie n’est revendiquée. [Source](https://github.com/AppHouseKitchen/AlDente-Battery_Care_and_Monitoring/releases/tag/1.39).

### Documentation consultée le 21 octobre 2026

Comparaison fonctionnelle des produits ; les disponibilités dépendent du modèle et de la version. [Source](https://apphousekitchen.com/aldente-overview/features/).

