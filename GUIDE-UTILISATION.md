# Guide d’utilisation — OpenDente personnel

Aide embarquée hors ligne dans Réglages > Guide. Édition 0.6.1.

## Panneau principal et modes

### Bureau · Quotidien · Mobilité

Appliquent respectivement 70/60, 80/70 et 90/80 : plafond / reprise sous le seuil bas. Ils activent la pause thermique et quittent le mode stockage. Le retour sur secteur respecte son option dédiée ; aucun cycle continu n’est forcé.

### Limite habituelle de charge

Choisit le plafond quotidien entre 20 et 100 %. Si Redescendre au plafond sur secteur est activé, un niveau déjà supérieur descend vers ce plafond ; sinon il reste maintenu et baisse naturellement. Modifier le curseur quitte le mode stockage.

### Charger à 100 % cette fois

Demande une charge complète temporaire et conserve tes seuils quotidiens. Quitte le mode stockage. La demande attend si une pause thermique est active ; elle finit au débranchement, à l’annulation ou à l’arrêt de l’app.

### Revenir à ma limite

Annule la charge ponctuelle. Si le retour au plafond sur secteur est activé, demande une descente vers ce plafond. Sinon, maintien au niveau courant puis baisse naturelle.

### Préparer le stockage à 50 %

Active une cible temporaire à 50 % sans écraser ton plafond habituel. Au-dessus, autorise explicitement une descente sur secteur ; en dessous, demande une recharge vers 50 %. Aucun calcul n’est lancé pour vider la batterie plus vite. L’effet dépend du service de macOS et s’affiche séparément de la demande.

### Arrêter le mode stockage

Annule la cible 50 % et retrouve les seuils quotidiens. Si le retour au plafond sur secteur est activé, la descente peut alors continuer vers le plafond habituel ; désactive cette option pour maintenir le niveau courant. La cible de stockage choisie persiste après relancement.

### Réglages… · icône de curseurs

Ouvre les réglages. Fermer cette fenêtre ou le panneau ne quitte pas OpenDente : le suivi continue en arrière-plan.

### Quitter

Ferme réellement l’app et demande la restauration du réglage Apple sauvegardé et du voyant système. La politique personnalisée n’est plus évaluée. Pour ce Mac, la configuration de repli conseillée est une limite Apple à 80 % avec recharge optimisée, configurée pendant que l’app est quittée.

## Charge : ce que contrôlent les réglages

### Activer le contrôle de charge

Active le moteur expérimental de macOS 27. Désactivé, OpenDente reste un lecteur de batterie et restaure le réglage Apple sauvegardé ; le mode stockage est annulé. Une demande native peut prendre environ une minute et macOS peut dépasser une cible pour sa calibration.

### Arrêter à

Même plafond quotidien que le curseur du panneau. La cible temporaire de stockage reste distincte. Les boutons de profils quittent ce mode.

### Redescendre au plafond sur secteur

Au lancement, au branchement ou après une modification, un niveau supérieur au plafond utilise la batterie pour y redescendre. À la cible, la décharge volontaire s’arrête. Pas de cycles 70→80→70 imposés. Une pause thermique et la charge ponctuelle restent prioritaires. Arrêter la décharge désactive cette option.

### Choisir quand la charge reprend · Reprendre sous

À 80/70, la recharge attend que le niveau passe sous 70 %, puis continue vers 80 %. Cela espace les reprises, sans imposer de descente de 80 à 70 sur secteur. Désactiver ce choix permet de reprendre dès que le niveau passe sous le plafond. Attendre 20 % n’est pas nécessaire à l’entretien de la batterie.

### Demander une pause si la batterie chauffe · Température

Compare le capteur interne au seuil choisi, entre 30 et 45 °C. La valeur 40 °C est un choix de précaution de l’app, pas un seuil interne officiel Apple. La reprise attend au moins 5 minutes sans dépassement et 2 °C de refroidissement. La charge ponctuelle et le stockage respectent cette priorité.

### Empêcher la veille automatique jusqu’à la limite

Option facultative qui retarde la veille pour inactivité pendant une charge ou décharge vers la cible ; l’écran peut s’éteindre. Elle n’est pas nécessaire pour conserver la consigne native déjà confiée à macOS. La veille manuelle et la fermeture du capot restent possibles. Elle est libérée à la cible, au débranchement ou à l’arrêt de l’action. Laisse-la désactivée pour autoriser le sommeil normal du Mac.

### Pendant la veille

Panneau fermé : le suivi continue en arrière-plan. Mac réellement en veille : l’app ne mesure plus la température, mais macOS garde la dernière consigne transmise. La veille ne retire pas le plafond et ne demande pas 100 %. Au réveil, les mesures et décisions reprennent. Le firmware conserve ses exceptions de calibration ; un arrêt à 80 % strict n’est pas garanti.

### Appliquer 80 % / reprise sous 75 %

Applique ce couple pratique proche du comportement Apple, active la plage de reprise et quitte le mode stockage. Le retour au plafond sur secteur conserve son choix ; aucun cycle continu n’est imposé.

### Autres commandes du moteur SMC

Sur ce Mac, la régulation par pourcentage matériel et la pause SMC dédiée à la veille ne sont pas proposées. Le stockage à 50 % et le retour au plafond quotidien utilisent maintenant des commandes natives dédiées.

### Mac éteint et limite Apple de repli

Une app ne tourne pas quand le Mac est éteint. Pour conserver une politique système, quitte OpenDente puis règle la limite Apple à 80 % et laisse la recharge optimisée activée. Relance ensuite l’app : cette valeur devient son état Apple à restaurer. Les deux réglages utilisent le même mécanisme natif ; ce ne sont pas deux plafonds indépendants. Le comportement après extinction complète n’est pas assimilé à notre essai de veille.

[Consulter la source](https://support.apple.com/fr-fr/102338)

### Maintien, cycles et vieillissement

Le secteur peut alimenter le Mac avec un courant de batterie nul. La reprise espacée évite de multiplier les recharges ; le maintien ne signifie pas des coupures rapides permanentes. Les recherches décrivent l’effet du niveau de charge et de la température, sans définir un seuil universel optimal pour les cellules non publiées de ce Mac. Le choix 80 % et reprise sous 75 % suit de près la politique Apple.

[Consulter la source](https://portal.fis.tum.de/de/publications/calendar-aging-of-lithium-ion-batteries-i-impact-of-the-graphite-/)

## Voyant MagSafe

### Adapter le voyant aux modes

Active les règles de couleur de l’app. Ce réglage change uniquement le voyant, pas le plafond ou la vitesse de charge. Il est indépendant de l’ancienne préférence du moteur SMC et reste désactivé au départ.

### Appliquer les signaux distincts

Active : charge normale orange clignotant, maintien vert clignotant, décharge sur secteur en alternance vert/orange, pause thermique éteinte, charge ponctuelle orange fixe puis vert fixe à 100 %. Cela ne change pas les seuils ni la puissance de charge.

### Charge confirmée · Pause confirmée

Choisissent la couleur quand la batterie reçoit encore du courant ou lorsque la pause est mesurée. Une simple demande de pause n’affiche pas prématurément la couleur de pause.

### Décharge sur secteur · Pause thermique

Choisissent le signal pendant une décharge de stockage ou de retour au plafond, et pendant une pause thermique. Une charge encore mesurée conserve d’abord son signal de charge : une couleur ne prouve jamais un arrêt.

### Vert (10 s) · Orange (10 s) · Éteint (10 s)

Aperçu temporaire du voyant, sans modifier tes seuils de batterie. Après environ dix secondes, retour aux règles choisies ou à macOS si la personnalisation est désactivée. Le matériel doit confirmer l’écriture ; une erreur est affichée dans la rubrique.

### Rendre le voyant à macOS

Interrompt l’aperçu, désactive la personnalisation et demande le retour au contrôle système, y compris après un essai échoué. L’app rétablit aussi ce contrôle au débranchement, à la veille, à la fermeture et en récupération après perte du client.

### Couleurs et clignotement

Les motifs alternent uniquement vert, orange et éteint, environ deux secondes par phase sur le rythme de mesure déjà existant. Aucun timer supplémentaire ni code de défaut du chargeur. Pendant la veille, au débranchement, à l’arrêt de l’app ou sur perte de client, restitution au système. Le voyant n’est pas RGB.

[Consulter la source](https://support.apple.com/fr-fr/102372)

### Charge ponctuelle vers 100 % · 100 % ponctuel atteint

Deux signaux distincts pour le remplissage ponctuel et sa fin, par défaut orange fixe puis vert fixe. Le mode de maintien quotidien peut ainsi clignoter vert sans être confondu avec 100 %. Les clignotements ne sont animés que lorsque le Mac est éveillé.

### Vert clignotant · Orange clignotant · Alternance (10 s)

Aperçus temporaires des motifs. Attends plusieurs secondes pour voir une période complète ; au terme des dix secondes, retour au signal choisi. Le retour au voyant macOS désactive tous les motifs.

## Général : lancement et service

### Ouvrir à la connexion

Démarre discrètement dans la barre des menus, sans ouvrir le panneau ni les réglages. Fermer une fenêtre laisse l’app en arrière-plan ; clique sur son icône pour le panneau. Enregistre l’app auprès de macOS pour qu’elle démarre après ouverture de ta session. Cela ne maintient pas l’app active lorsque le Mac est éteint. Le démarrage a été observé après ton redémarrage du 21 octobre.

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

Apple conseille environ 50 %, appareil éteint, dans un lieu frais et sec à moins de 32 °C. Pour un stockage dépassant six mois, recharge autour de 50 % tous les six mois. La zone 45–55 % du guide est un repère pratique, pas une plage officielle Apple.

[Consulter la source](https://www.apple.com/fr/batteries/maximizing-performance/)

### MagSafe et USB-C

La politique vise la batterie interne et est conçue pour les deux ports, avec une alimentation USB-C Power Delivery adaptée. Les essais matériels de cette séance utilisent MagSafe ; l’USB-C n’est pas présenté comme testé. Un chargeur trop faible peut ne pas couvrir la consommation du Mac.

[Consulter la source](https://support.apple.com/fr-fr/102397)

## Par rapport à OpenDente d’origine

### Fonctions déjà présentes

La base possède déjà limite, reprise, chaleur, décharge SMC, charge ponctuelle, voyant, notifications et personnalisation des mesures. Ces fonctions ne sont pas toutes des ajouts personnels.

### Ce que l’édition personnelle ajoute ou renforce

Interface française, profils Bureau/Quotidien/Mobilité, moteur expérimental macOS 27 sur ce Mac, modes temporaires séparés des seuils quotidiens, stockage à 50 %, règles MagSafe et aperçus, explications, signature identique app/service et récupération après erreurs.

### Ce que nous ne prétendons pas avoir

Aucune calibration forcée, programmation horaire, intégration Raccourcis, mise à jour automatique ou promesse de gain chiffré de durée de vie. Les fonctions SMC de la base restent conservées pour les Mac compatibles ; elles ne deviennent pas disponibles par un simple réglage sur ce Mac.

### Source de comparaison

Base examinée : killerk3emstar/OpenDente, commit 06c5a8199f5c0657374e667073b3aa6a75f50df8. Licence GPL et crédits conservés.

[Consulter la source](https://github.com/killerk3emstar/OpenDente/tree/06c5a8199f5c0657374e667073b3aa6a75f50df8)

## Par rapport à AlDente

### Free / Pro

La documentation distingue une édition gratuite avec limite et décharge, et des fonctions Pro : reprise, chaleur, voyant, charge ponctuelle, calendrier, Raccourcis et calibration.

### Différences utiles ici

Notre version ajoute un mode stockage à 50 %, un retour au plafond facultatif et des motifs de voyant animés par l’app éveillée. AlDente possède aussi décharge et retour automatique. Les mécanismes et leur portée pendant la veille diffèrent ; les essais sur notre Mac restent consignés.

### Compatibilité et portée

AlDente 1.39 annonce le support macOS 27. Cela ne constitue pas un essai comparatif sur ce Mac. Notre moteur reste expérimental ; aucune supériorité de fiabilité ou d’autonomie n’est revendiquée.

[Consulter la source](https://github.com/AppHouseKitchen/AlDente-Battery_Care_and_Monitoring/releases/tag/1.39)

### Documentation consultée le 21 octobre 2026

Comparaison fonctionnelle des produits ; les disponibilités dépendent du modèle et de la version.

[Consulter la source](https://apphousekitchen.com/aldente-overview/features/)
