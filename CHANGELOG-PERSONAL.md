# Changements de l’édition personnelle

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
