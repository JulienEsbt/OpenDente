# Régressions du helper

Ces tests ne touchent pas la batterie et ne nécessitent pas les droits root.

```sh
python3 tests/helper/run_tests.py
```

Le compilateur `swiftc` doit être dans le PATH. On peut aussi fournir `SWIFTC`.
`--output /chemin/absolu` conserve les journaux, le code extrait et son manifeste
de hachages. `--suite hardware|lifecycle|watchdog` exécute seulement un groupe.

## Ce qui est effectivement exécuté

- **17 tests de récupération** : compilation des fichiers de production
  `ChargingHardwareController.swift` et `BatteryState.swift`, avec SMC et stockage
  remplacés par des dépendances en mémoire. Les deux familles de clés sont
  exercées, notamment les écritures partielles, le retour matériel incohérent,
  l'échec d'écriture du marqueur, les restaurations partielles et leur reprise.
- **8 tests de cycle de vie** : méthodes du vrai `HelperDelegate.swift`, extraites
  automatiquement ; les frontières macOS sont simulées. Connexion inactive,
  déconnexion, ancienne connexion, arrêt explicite, politique de veille et valeurs
  de LED sont vérifiés. L'authentification cryptographique est explicitement
  exclue de cette extraction et n'est donc pas validée par ces tests.
- **3 tests de watchdog** : logique réelle de `Watchdog.swift` et contrôleur réel.
  Une restauration échouée est reprise même si l'app continue ses heartbeats ;
  une inhibition volontaire reste en place ; la reprise cesse après succès.

Swift 6 et `-strict-concurrency=minimal` sont utilisés. Deux avertissements de
variables inutilisées dans l'extrait du délégué proviennent du retrait d'`os.log`.
Ils ne concernent pas le fichier de production.

## Contrôle natif du helper sur macOS

Sur macOS, la suite complète vérifie aussi les types des sources intégrales du
helper avec le SDK installé, y compris Security.framework et NSXPCConnection.
Aucun code du helper n'est exécuté ; le SMC reste inaccessible à ce contrôle.
Pour ne lancer que cette vérification :

```sh
python3 tests/helper/run_tests.py --suite native --output .build/helper-native
```

Le journal `native-typecheck.log` conserve le diagnostic. Ce contrôle a reproduit
l'erreur `SecCode` / `SecStaticCode` masquée par l'extraction portable, puis validé
sa correction. Il ne prouve ni la signature, ni le rejet d'un client tiers, ni
l'enregistrement du service, ni la réussite de la suite XCTest.

## Changements de sécurité

Le helper exige l'identifiant de l'application **et le même certificat de
signature que le helper installé**, y compris en Debug. L'exigence est appliquée
par `NSXPCConnection.setCodeSigningRequirement` avant `resume()`, puis contrôlée
par Foundation sur les messages. Aucun contrôle par PID ni accès privé à
`auditToken` n'est utilisé. Une connexion n'acquiert les réglages de batterie
qu'après réception d'une requête vérifiée par Foundation.

Un certificat local de signature de code peut servir à signer les deux cibles.
Une signature ad hoc (`codesign -s -`) ne possède aucun certificat et est refusée.
Changer de certificat demande de reconstruire et remplacer les deux composants.
La compatibilité effective d'une identité locale avec l'enregistrement
SMAppService reste à vérifier sur le Mac de destination.

La langue d'exigences d'Apple encode une empreinte de certificat SHA-1 : le code
utilise ce format imposé pour sélectionner le certificat existant. Il ne crée
aucune base de confiance supplémentaire et n'utilise pas SHA-1 pour un mot de
passe. La signature du code reste contrôlée par les API macOS.

Les écritures qui restreignent l'alimentation sont précédées d'un marqueur
persistant ; un échec provoque un retour aux réglages par défaut. Chaque clé de
restauration est tentée même si une précédente échoue. Les réponses de succès
supposent que les écritures et leurs relectures ont réussi. Le marqueur reste
actif jusqu'à restauration complète. Les règles de veille sont effacées à la
déconnexion/à l'arrêt et ne s'appliquent pas sans client actif.

## Validation macOS encore nécessaire

La compilation complète, l'enregistrement du service, le comportement de
`NSXPCConnection`, Security.framework, le stockage root et les clés SMC n'ont pas
été exécutés dans l'environnement Linux de préparation. Avant usage quotidien,
vérifier sur le Mac cible :

1. Compilation des cibles Debug et Release, et signature des deux avec la même
   identité. La connexion normale doit réussir.
2. Rejet d'un client ad hoc qui reprend `com.opendente.app`, puis d'un client
   signé avec un autre certificat ; le rejeu doit être refusé aussi en Debug.
3. Quitter l'app avec une inhibition en cours, puis provoquer une veille : la
   charge doit revenir au comportement macOS et ne pas être réinhibée.
4. Reconnexion rapide : une ancienne déconnexion ne doit pas annuler les réglages
   du nouveau client.
5. Retour aux réglages macOS après échec/reprise du helper, et vérification de la
   limite, de la température et des transitions veille/réveil sur le matériel.

Les relectures SMC prouvent ici le retour des clés au niveau logiciel, pas une
garantie sur le courant physique ou sur la durée de vie de la batterie. Une
panne électrique et la durabilité du système de fichiers ne sont pas simulées.

## Sources Apple consultées

- [NSXPCConnection.setCodeSigningRequirement](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:)) — disponible depuis macOS 13 selon les métadonnées DocC Apple.
- [NSXPCConnection.current](https://developer.apple.com/documentation/foundation/nsxpcconnection/current()).
- [Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).
- [kSecCodeInfoCertificates](https://developer.apple.com/documentation/security/kseccodeinfocertificates).
- [TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
