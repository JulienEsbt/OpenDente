# Changements de l’édition personnelle

## 0.7.2 — jauge visible et réapplication native corrigée, 26 octobre 2026

- Jauge de niveau séparée de la face des chiffres, portée à 2 points d’épaisseur et à la largeur de la batterie. Partie vide légèrement visible ; chiffres uniformes conservés, sans élargissement de la barre des menus.
- Correction du service 1.7.2 : l’activation à 80 % n’est plus répétée à chaque rafraîchissement d’une cible inférieure. L’état d’activation appartient à la session du helper, sans interprétation d’une énumération privée. Charge ponctuelle et restauration réarment correctement la prochaine activation.
- Rafraîchissement des cibles inchangées espacé de trois minutes, sans retarder les nouvelles consignes ni les reprises sur erreur.
- Cinq régressions de session/cadence ajoutées ; **389 XCTest natifs et 36 scénarios complémentaires du service réussis**. Nouveau service requis pour utiliser ce correctif. Journal de restauration et authentification XPC conservés.
- Validation matérielle suivie dans VALIDATION.md ; livraison et modifications restent locales, sans commit ni push.

## 0.7.1 — chiffres plus lisibles, 25 octobre 2026

- Face uniforme derrière le pourcentage : le niveau ne coupe plus les chiffres en deux contrastes. Police plus grande et grasse ; petite jauge inférieure indépendante, sans élargir l’icône compacte.
- Régression du rendu réel à 20, 50, 68 et 100 % : fond opaque des deux côtés, chiffres évidés et jauge distincte. **384 XCTest natifs réussis**, Release universelle signée.
- Service 1.7.0 et politique de charge inchangés. Livraison locale ; aucun commit ni push sans la clé du propriétaire.

## 0.7.0 — barre compacte et aide discrète, 25 octobre 2026

- Pourcentage dans la batterie ; température et puissance sur deux lignes. Le mode reste indiqué, le survol et l’accessibilité conservent les détails. Présentation classique toujours disponible dans Barre des menus, avec aperçu identique au rendu réel.
- La carte native permanente laisse place à une aide volontaire dans l’en-tête. Les erreurs de service, de consigne et de pause restent visibles.
- Rafraîchissement immédiat de la barre après modification des préférences. Trois régressions ajoutées : préférence persistante, encombrement réduit à informations égales et lecture absente sans faux 0 %.
- 383 XCTest natifs et 36 scénarios complémentaires du service réussis. Veille/réveil et reconnexion vérifiés, seuils 80/75 rétablis. Une pause à 66 % acceptée mais non confirmée physiquement est documentée sans revendication de réussite. Service 1.7.0 et politique de charge inchangés. Livraison locale ; commit signé et publication différés par le propriétaire.

## 0.6.2 — diagnostic natif et présentation publique, 21 octobre 2026

- L’export identifie maintenant PowerUI lorsqu’il est disponible, au lieu d’annoncer un moteur SMC non détecté. Il distingue disponibilité, activation choisie, cible acquittée et mesure physique.
- Le rapport inclut le retour au plafond, le stockage 50 %, les règles MagSafe natives et les éventuels problèmes de consigne. Les anciennes préférences sont explicitement marquées SMC.
- Trois régressions de diagnostic ajoutées ; 380 tests XCTest natifs réussis. Aucun changement de commande de charge, de seuil ni du service 1.7.0. App 0.6.2 (12).

- README anglais et français réécrits, cinq captures réelles, comparaison fonctionnelle et priorités documentées. README d’origine archivé avec ses crédits ; licence et historique conservés.

## 0.6.1 — lancement discret et installation unique, 21 octobre 2026

- Démarrage silencieux dans la barre des menus, y compris après mise à jour ; suppression de l’ouverture automatique du panneau au changement de build.
- Restauration automatique des fenêtres désactivée pour cette app. Fermer les fenêtres laisse explicitement le processus actif ; clic sur l’icône et réouverture manuelle disponibles.
- Application regroupée dans le dossier standard Applications ; sources Git conservées. Les anciennes copies et compilations vont dans la Corbeille sans effacement définitif.
- 377 tests natifs réussis, Release signée, démarrage silencieux et maintien sans fenêtre vérifiés. Enregistrement macOS actif rattaché à `/Applications/OpenDente.app` ; aucun nouveau redémarrage complet exécuté.
- App 0.6.1 (11), service 1.7.0 inchangé. Validation et portée des essais dans VALIDATION.md.

## 0.6.0 — retour au plafond, veille et signaux distincts, 21 octobre 2026

- Retour automatique au plafond sur secteur, sur activation explicite : une batterie au-dessus du plafond y redescend au lancement ou au branchement, puis maintien sans cycles forcés. Commande distincte du maintien ordinaire et du stockage 50 %, journalisée et authentifiée.
- Priorité de la pause thermique, du stockage et de la charge ponctuelle conservée. Arrêter la décharge désactive le retour automatique sans écraser le plafond.
- Explication de la veille : l’app suspend ses mesures, macOS conserve la consigne ; aucune restauration vers 100 % n’est demandée à l’endormissement. Reprise des contrôles au réveil couverte par régression.
- Signalisation distincte : orange clignotant en charge normale, vert clignotant en maintien, alternance en décharge, orange fixe puis vert fixe pour 100 %, extinction en pause thermique. Motifs sur le rythme de mesure existant, sans timer supplémentaire ni codes matériels de défaut. Journal de récupération réutilisé entre les phases.
- 376 tests XCTest et 36 scénarios complémentaires réussis. Descente réelle 96→93 % sur secteur, fermeture avec restauration Apple 80 %, relance et veille/réveil validées. Trois motifs confirmés visuellement par le propriétaire.
- Configuration quotidienne laissée à 80 % / reprise sous 75 %, retour au plafond activé ; limite Apple de repli à 80 % avec recharge optimisée. App 0.6.0 (10), service 1.7.0 ; portée exacte des essais dans VALIDATION.md.

## 0.5.0 — stockage, voyant et guide, 21 octobre 2026

- Mode stockage temporaire à 50 %, indépendant des seuils quotidiens. Au-dessus de 50 %, commande dédiée autorisant explicitement la descente sur secteur ; au-dessous, recharge vers 50 %. Aucun calcul lancé pour consommer davantage. Arrêt manuel, profil quotidien ou charge ponctuelle quittent ce mode.
- Commandes ordinaires toujours protégées contre une cible inférieure au niveau courant. Nouvelle commande du service 1.6.1 limitée à la préparation à 50 %, authentifiée et journalisée avant écriture.
- Les changements de mode conservent la pause thermique et son délai de refroidissement. Nouveaux tests de transitions et de récupération ; les mesures matérielles sont détaillées séparément dans VALIDATION.md.

- Correction de l’essai sur câble : la lecture de la couleur système n’est plus confondue avec la commande de retour automatique. La confirmation de couleur attend brièvement le firmware. La récupération du voyant ne restaure plus le plafond de charge d’un client actif ; une perte de heartbeat conserve la restauration générale.
- Voyant natif : réglages par état réel, vert/orange/éteint/automatique et aperçus de 10 secondes. Propriété du voyant journalisée avant écriture, restitution indépendante de la disponibilité des anciennes commandes de charge. Aucun clignotement ajouté.
- Onglet Guide hors ligne avec recherche : chaque famille de commandes expliquée, limites et comparaison de l’original avec l’édition personnelle et AlDente. Guide Markdown et tableau comparatif conservés dans le dépôt.
- 363 tests XCTest natifs réussis ; 35 scénarios complémentaires du service. App 0.5.0 (9), service 1.6.1.

## 0.4.1 — préparation au stockage et essais réels, 21 octobre 2026

- Guide de stockage prolongé dans Charge, avec niveau de batterie courant et étapes Apple autour de 50 %. Aucun changement automatique des réglages, décharge forcée ou extinction.
- Explications MagSafe/USB-C et voyant : contrôle de la batterie indépendant du port, puissance adaptée, voyant système conservé en mode natif et absence de clignotement personnalisé.
- Essai réel : maintien à 99 %, veille de 27 secondes puis maintien retrouvé ; descente naturelle à 97 % sous le seuil temporaire de 98 %, puis courant de charge positif après rebranchement MagSafe, poursuite en repassant à 98 % et retour confirmé au maintien après restauration des réglages 80 % / 70 %. Voir VALIDATION.md pour la portée exacte.
- App 0.4.1 (7), même service 1.5.2 et même politique de charge. Suite native : **339/339** sans échec. Aucun essai USB-C matériel, aucun gain de durée de vie chiffré promis.

## 0.4.0 — réglages natifs et pause thermique, 21 octobre 2026

- Reprise personnalisée disponible dans le moteur natif, y compris 20 % avec un plafond de 80 %. Maintien au niveau courant pendant l’attente, puis charge jusqu’au plafond ; aucun profil ne force une décharge.
- Pause thermique supplémentaire configurable, prioritaire sur la charge ponctuelle. Reprise après 5 min sans dépassement et 2 °C de refroidissement ; une mesure perdue ne lève pas une pause. Défaut 40 °C présenté comme une précaution de l’app, distinct de la température ambiante recommandée par Apple.
- État physique visible : demande de pause distincte de l’arrêt mesuré, avertissement après 90 s si la charge continue ; limites pendant la veille et sous 20 % explicites.
- Section Charge réorganisée : contrôles disponibles activables, commandes SMC non portées regroupées à part. Bouton 80 % / reprise sous 75 % et liens vers les recommandations consultées.
- Prévention facultative de veille automatique rétablie sur le moteur natif. Ouverture à la connexion fondée sur l’état réellement enregistré par macOS, avec erreurs visibles.
- Réouverture du panneau en relançant l’app ; point d’entrée visible après mise à jour. Restauration possible même si la mesure de batterie est perdue ; erreur XPC de restauration remontée.
- Lecture réservée à la batterie interne : un onduleur listé en premier ne peut plus fausser la garde contre une consigne inférieure au niveau actuel. Données incohérentes ou ambiguës refusées.
- App 0.4.0 (6), service 1.5.2. **339 tests XCTest natifs réussis**, 30 scénarios portables, 28 scénarios de helper et Release universelle signée. Voir VALIDATION.md pour les essais physiques et ceux encore non réalisés.

## 0.3.1 — correction du backend PowerUI, 21 octobre 2026

- Activation par le setter PowerUI 80–100 % au lieu de supposer la valeur de l’état privé. Préférence de cible seule pour les valeurs inférieures à 80 % ; aucun appel dangereux du setter sous 80 %.
- Journal de l’ensemble des préférences MCL, valeurs temporaires comprises ; libération de la politique active avant restauration du journal.
- Arrêt natif, reprise à 100 %, annulation et retrait du plafond observés sur le Mac à 99 % avec le service 1.5.1. L’essai de préférence seule en 0.3.0 ne constituait pas un contrôle effectif de charge.

## 0.3.0 — mode natif expérimental, 21 octobre 2026

- Nouveau backend PowerUI pour les firmwares sans CHTE/CH0B/CH0C, sur activation explicite. Interface privée détectée à l’exécution ; aucune modification des autorisations Apple ou des archives powerd.
- Plafond et charge ponctuelle à 100 %, sans coupure de l’adaptateur. Les cibles inférieures au niveau courant sont refusées côté service.
- Sauvegarde du réglage Apple avant modification ; restauration sur désactivation, perte de connexion, watchdog et redémarrage. Un échec conserve le journal.
- Limites visibles : application différée, reprise firmware, calibration pouvant dépasser le plafond ; seuil de reprise et arrêt thermique personnalisés désactivés sur ce backend.
- Correction de l’état de service resté figé après approbation macOS. Une présence effective des fichiers est vérifiée avant d’annoncer un service manquant.
- Service 1.5.0 ; version de l’app 0.3.0 (3). Les licences GPL et MIT ainsi que les crédits adaptés d’Ampere sont inclus dans le bundle.
- 313 tests XCTest réussis, dont 14 nouveaux tests de politique native et de restauration. Compilation Release signée réussie.

## Après reprise sur Mac — 21 octobre 2026

### Corrections

- Extraction des certificats avec la syntaxe `--extract-certificates=préfixe` :
  le contrôle des signatures ne traite plus le préfixe temporaire comme un fichier
  de code à vérifier.
- Fixtures XCTest exécutées sur le MainActor via les points d'entrée asynchrones ;
  tests de vues isolés sur le MainActor. Les 299 tests natifs réussissent sans
  avertissement Swift de concurrence, avec les mêmes assertions.
- Arrêt explicite du script lorsque Xcode complet n'est pas initialisé/sélectionné,
  avant la génération du projet.
- Marqueur de lancement réservé à l'action XCTest du schéma pour désactiver les
  services réels dans l'app hôte, avec détection des deux variables XCTest usuelles.
- Compilation du service : conversion explicite du code courant en `SecStaticCode`
  avant lecture du certificat, avec validation du code en mémoire et sur disque.
- Ajout d'un contrôle macOS des sources intégrales du helper, incluant les API
  Security et XPC exclues des tests portables. Le contrôle échoue avant la
  correction et réussit après, sans exécuter le service.

## 0.2.0 — développement, 21 octobre 2026

### Ajouts

- Panneau SwiftUI français, plafond visible, seuil de reprise explicite, actions courantes accessibles.
- Profils Bureau, Quotidien et Mobilité, modifiables et sans décharge automatique.
- Demande de charge ponctuelle conservée pendant une pause thermique.
- Instructions et script de compilation/signature locale ; suite XCTest explicitement incluse dans le schéma.

### Corrections

- Vérification de l’arrêt réel de charge pendant la chaleur et le refroidissement.
- Maintien de la protection thermique après un échec de commande ou une mesure de température manquante.
- Seuil bas de reprise au minimum à 10 %.
- Réponses d’erreur explicites et restauration de toutes les clés utiles après une écriture matérielle partielle.
- Fin de la politique de veille après reset/déconnexion et protection contre les anciennes connexions.
- Handshake borné, rejet des anciennes versions du service pour le contrôle, reconnexion et réinstallation explicites.

### Sécurité

- Authentification des messages XPC par identifiant et certificat, sans exception Debug.
- Marqueur de récupération persistant avant les opérations restrictives et reprise indépendante des heartbeats après restauration échouée.
- Contrôle du type/propriétaire du stockage existant et validation des valeurs LED acceptées.

### Validation

58 scénarios Swift ciblés passent dans un environnement Linux avec les frontières macOS simulées. Voir `VALIDATION.md` pour les contrôles négatifs et les limites. Le build natif, le rendu et les tests matériels restent à réaliser sur Mac.
