# Changements de l’édition personnelle

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
