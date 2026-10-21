# Gestion d'un hôtel — MySQL 8 / InnoDB

Projet individuel de conception et d'implémentation d'une base de données de gestion hôtelière.

## Prérequis

- MySQL Server 8.0 (recommandé : 8.0.16 ou supérieur pour les contraintes `CHECK`).
- MySQL Workbench.
- Git pour le dépôt distant.

## Arborescence

```text
hotel-db/
├── README.md
├── docs/
│   ├── erd.png
│   └── dictionnaire.md
└── sql/
    ├── 01_schema.sql
    ├── 02_contraintes.sql
    ├── 03_donnees_test.sql
    ├── 04_requetes.sql
    └── 05_tests.sql
```

## Ordre d'exécution

Les scripts sont conçus pour une base vide et doivent être exécutés dans l'ordre 01 à 05.

1. `sql/01_schema.sql` — crée le schéma et les tables. **Attention : ce script contient `DROP SCHEMA IF EXISTS gestion_hotel`; il efface la base `gestion_hotel` si elle existe déjà.**
2. `sql/02_contraintes.sql` — ajoute les contraintes, triggers et procédures.
3. `sql/03_donnees_test.sql` — insère les données de test et appelle la procédure de paiement.
4. `sql/04_requetes.sql` — exécute les six requêtes analytiques.
5. `sql/05_tests.sql` — vérifie plusieurs violations attendues.

### Dans MySQL Workbench

1. Décompressez le ZIP.
2. Dans Workbench, ouvrez `sql/01_schema.sql` via **File > Open SQL Script**.
3. Exécutez avec l'icône éclair. Vérifiez l'onglet **Action Output**.
4. Répétez dans l'ordre avec les scripts 02, 03, 04 et 05.
5. Pour chaque script, attendez la fin de l'exécution et contrôlez les messages d'erreur avant de continuer.

Ne réexécutez pas le script 01 si vous souhaitez conserver vos données. Les scripts 02 et 03 ne sont pas conçus pour être rejoués sans nettoyage préalable.

## Contrôles rapides

```sql
USE gestion_hotel;
SHOW TABLES;
SELECT COUNT(*) AS chambres FROM chambre;
SELECT COUNT(*) AS clients FROM client;
SELECT COUNT(*) AS reservations FROM reservation;
SELECT COUNT(*) AS services FROM service;
SELECT COUNT(*) AS factures FROM facture;
SELECT COUNT(*) AS avis FROM avis;
```

Volumes attendus au minimum : 15 chambres, 10 clients, 20 réservations, 4 services, 10 factures et 6 avis.

## Règles couvertes

- RG-01/RG-02 : caractéristiques des chambres et aménagements.
- RG-03 : état opérationnel distinct de la disponibilité calculée sur les réservations.
- RG-04/RG-05 : client, dates, chambres et nombre de personnes.
- RG-06/RG-07 : statuts, annulation et absence de chevauchement.
- RG-08 : prix par nuit figé dans `reservation_chambre`.
- RG-09/RG-10 : clients uniques; historique obtenu par requête.
- RG-11/RG-12 : services, horaires et consommations.
- RG-13/RG-15 : facture, lignes, paiements et statut.
- RG-16/RG-17 : avis uniques et note de 1 à 5.

## Modèle ERD

Le schéma d'origine a été généré par MySQL Workbench. Pour exporter l'ERD :

1. Ouvrez `sql/01_schema.sql` et exécutez-le.
2. Choisissez **Database > Reverse Engineer**.
3. Sélectionnez votre connexion MySQL locale, puis le schéma `gestion_hotel`.
4. Suivez l'assistant pour importer les tables.
5. Dans le modèle EER, arrangez les tables et les relations pour rendre le diagramme lisible.
6. Choisissez **File > Export > Export as PNG** (le libellé peut varier selon la version).
7. Enregistrez l'image sous `docs/erd.png`.

Si le menu Reverse Engineer n'est pas accessible, ouvrez un modèle EER via **File > New Model**, puis ajoutez un diagramme EER et utilisez la fonction d'import depuis le serveur.

## Paiements

Utilisez la procédure stockée plutôt que d'insérer directement dans `paiement` :

```sql
CALL enregistrer_paiement(1, 10000.00, 'mobile_money');
```

Le montant doit être positif et ne peut pas dépasser le solde de la facture. Le statut est recalculé à partir des lignes TTC et des paiements.

## Choix de conception et limites

- **Seule modification de schéma** : `reservation.nb_personnes`, ajoutée dans `02_contraintes.sql`, car RG-05 (nombre de personnes <= capacité totale) est impossible à vérifier sans cette donnée.
- **RG-05 (capacité totale)** : MySQL n'a pas de contrainte différée. Avec plusieurs chambres, la capacité est insuffisante après la première insertion. Elle est donc vérifiée par la procédure `verifier_capacite_reservation(id)`, à appeler une fois toutes les chambres affectées, et par des triggers lors d'un changement de `nb_personnes` ou du retrait/changement d'une chambre.
- **RG-07** : triggers sur `reservation_chambre` (insertion, modification) et sur `reservation` (dates, statut). Une réservation annulée libère ses chambres ; le jour du départ peut être le jour d'arrivée de la réservation suivante.
- **RG-03** : les requêtes de disponibilité et d'occupation (L6) se basent sur les réservations, pas sur `chambre.etat`.
- **RG-12** : le jour du départ est exclu du séjour ; un créneau est défini par `date_service` + `heure_debut` / `heure_fin` ; la capacité est la somme des `quantite` des créneaux qui se chevauchent.
- **Taxes** : `taux_taxe` est un pourcentage (19,25 = 19,25 %).
- **Suppression en cascade** : MySQL n'exécute pas les triggers pour les actions `ON DELETE CASCADE`.
- **`enregistrer_paiement`** fait un `COMMIT` (transaction propre) : ne pas l'appeler au milieu d'une transaction à annuler.
- **ERD** : `docs/erd.png` est à exporter depuis MySQL Workbench (voir plus haut).

## Tests

`05_tests.sql` affiche un tableau PASS / ECHEC. Les tests qui écrivent des données sont encadrés par `START TRANSACTION` ... `ROLLBACK`. Un seul bloc (paiements de la facture 10) est nettoyé manuellement car la procédure de paiement valide sa transaction.

## Git : commits progressifs

Exemple d'historique de travail :
1. `Initialisation du schéma hôtel`
2. `Ajout des contraintes métier`
3. `Ajout des données de test`
4. `Création des requêtes analytiques`
5. `Ajout des tests et de la documentation`

Effectuez réellement ces commits à mesure que vous finalisez les fichiers; ne créez pas un historique artificiel rétroactivement.
