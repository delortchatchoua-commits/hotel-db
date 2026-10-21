# Dictionnaire de données — Gestion d'un hôtel

Types et contraintes issus de `sql/01_schema.sql`. Les règles métier sont référencées par les identifiants du sujet. `nb_personnes` est ajouté au livrable L4 pour pouvoir vérifier RG-05.

| Table | Attribut | Type MySQL | Contraintes | Description / règle |
|---|---|---|---|---|
| amenagement | id_amenagement | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant de l'aménagement, RG-02 |
| amenagement | libelle | VARCHAR(60) | NOT NULL, UNIQUE | Nom de l'aménagement, RG-02 |
| chambre | id_chambre | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant interne |
| chambre | numero | VARCHAR(10) | NOT NULL, UNIQUE | Numéro unique, RG-01 |
| chambre | etage | SMALLINT | NOT NULL | Étage, RG-01 |
| chambre | type_chambre | ENUM | NOT NULL | simple, double, suite, familiale, RG-01 |
| chambre | capacite | TINYINT UNSIGNED | NOT NULL, CHECK > 0 | Capacité maximale, RG-01/RG-05 |
| chambre | prix_base | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | Prix de base par nuit, RG-01 |
| chambre | etat | ENUM | NOT NULL, défaut disponible | État opérationnel instantané; ne remplace pas le calcul des disponibilités, RG-03 |
| chambre_amenagement | id_chambre | INT UNSIGNED | PK composite, FK | Chambre concernée, RG-02 |
| chambre_amenagement | id_amenagement | INT UNSIGNED | PK composite, FK | Aménagement associé, RG-02 |
| client | id_client | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant client, RG-09 |
| client | nom | VARCHAR(80) | NOT NULL | Nom, RG-09 |
| client | prenom | VARCHAR(80) | NOT NULL | Prénom, RG-09 |
| client | telephone | VARCHAR(25) | NOT NULL, UNIQUE | Téléphone unique, RG-09 |
| client | email | VARCHAR(150) | NOT NULL, UNIQUE | Email unique, RG-09 |
| reservation | id_reservation | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant du séjour |
| reservation | id_client | INT UNSIGNED | FK, NOT NULL | Client, RG-04 |
| reservation | date_arrivee | DATE | NOT NULL | Début du séjour, RG-04/RG-05 |
| reservation | date_depart | DATE | NOT NULL, CHECK > arrivée | Fin exclusive du séjour, RG-05 |
| reservation | statut | ENUM | NOT NULL, défaut en_attente | en_attente, confirmee, annulee, terminee, RG-06/RG-07 |
| reservation | cree_le | DATETIME | NOT NULL, défaut courant | Date de création, RG-06 |
| reservation | annulee_le | DATETIME | NULL | Date d'annulation éventuelle, RG-06 |
| reservation | nb_personnes | TINYINT UNSIGNED | NOT NULL, défaut 1 | Nombre de personnes, ajout L4 pour RG-05 |
| reservation_chambre | id_reservation | INT UNSIGNED | PK composite, FK | Réservation concernée, RG-04 |
| reservation_chambre | id_chambre | INT UNSIGNED | PK composite, FK | Chambre réservée, RG-04/RG-07 |
| reservation_chambre | prix_nuit_fige | DECIMAL(10,2) | NOT NULL | Prix conservé au moment de la réservation, RG-08 |
| service | id_service | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant service, RG-11 |
| service | nom | VARCHAR(100) | NOT NULL, UNIQUE | Nom unique du service, RG-11 |
| service | description | TEXT | NOT NULL | Description, RG-11 |
| service | tarif | DECIMAL(10,2) | NOT NULL | Tarif courant, RG-11 |
| service | capacite_creneau | SMALLINT UNSIGNED | NOT NULL | Capacité par créneau, RG-11/RG-12 |
| horaire_service | id_horaire | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant horaire |
| horaire_service | id_service | INT UNSIGNED | FK, NOT NULL | Service concerné, RG-11 |
| horaire_service | jour_semaine | TINYINT UNSIGNED | 1 à 7 | 1=lundi, 7=dimanche, RG-11 |
| horaire_service | heure_debut / heure_fin | TIME | NOT NULL | Plage d'ouverture, RG-11/RG-12 |
| consommation_service | id_consommation | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant de consommation |
| consommation_service | id_reservation | INT UNSIGNED | FK, NOT NULL | Séjour du client, RG-12 |
| consommation_service | id_service | INT UNSIGNED | FK, NOT NULL | Service consommé, RG-12 |
| consommation_service | date_service | DATE | NOT NULL | Date de consommation, RG-12 |
| consommation_service | heure_debut / heure_fin | TIME | NOT NULL | Créneau demandé, RG-12 |
| consommation_service | quantite | SMALLINT UNSIGNED | NOT NULL, défaut 1 | Nombre d'unités, RG-12 |
| consommation_service | prix_unitaire_fige | DECIMAL(10,2) | NOT NULL | Tarif historique, RG-13 |
| facture | id_facture | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant facture, RG-13 |
| facture | id_reservation | INT UNSIGNED | FK, UNIQUE | Une facture par réservation, RG-13 |
| facture | emise_le | DATETIME | NOT NULL, défaut courant | Date d'émission |
| facture | statut | ENUM | NOT NULL, défaut due | due, partiellement_payee, payee; calculé par procédure, RG-15 |
| ligne_facture | id_ligne | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant de ligne, RG-13 |
| ligne_facture | id_facture | INT UNSIGNED | FK, NOT NULL | Facture parente, RG-13 |
| ligne_facture | libelle | VARCHAR(180) | NOT NULL | Nature de la ligne, RG-13 |
| ligne_facture | quantite | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Quantité facturée, RG-13 |
| ligne_facture | prix_unitaire | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | Prix unitaire figé, RG-13 |
| ligne_facture | taux_taxe | DECIMAL(5,2) | NOT NULL, défaut 0, CHECK 0–100 | Taux de taxe, RG-13 |
| paiement | id_paiement | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant paiement, RG-14 |
| paiement | id_facture | INT UNSIGNED | FK, NOT NULL | Facture réglée, RG-14 |
| paiement | date_paiement | DATETIME | NOT NULL, défaut courant | Date du paiement, RG-14 |
| paiement | montant | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Montant strictement positif, RG-14 |
| paiement | methode | ENUM | NOT NULL | especes, carte, mobile_money, virement, RG-14 |
| avis | id_avis | INT UNSIGNED | PK, AUTO_INCREMENT | Identifiant avis, RG-16 |
| avis | id_reservation | INT UNSIGNED | FK, UNIQUE | Un avis maximum par séjour, RG-16 |
| avis | note | TINYINT UNSIGNED | NOT NULL, CHECK 1–5 | Note globale, RG-17 |
| avis | commentaire | TEXT | NULL | Commentaire facultatif, RG-17 |
| avis | date_avis | DATE | NOT NULL | Date de l'avis, doit être >= départ, RG-17 |

## Associations et cardinalités

- **Client — Réservation** : un client peut avoir 0 à N réservations; une réservation appartient à exactement 1 client (RG-04).
- **Réservation — Chambre** : une réservation porte sur 1 à N chambres et une chambre apparaît dans 0 à N réservations au fil du temps. La table `reservation_chambre` matérialise le N:N et conserve `prix_nuit_fige` (RG-04, RG-08).
- **Chambre — Aménagement** : N:N via `chambre_amenagement`; une chambre peut avoir plusieurs aménagements et un aménagement peut concerner plusieurs chambres (RG-02).
- **Réservation — Facture** : 1:0..1 dans la structure actuelle; chaque facture appartient à une réservation et l'unicité de `id_reservation` limite à une facture par réservation (RG-13).
- **Facture — Ligne facture** : une facture peut avoir plusieurs lignes; chaque ligne appartient à une facture (RG-13).
- **Facture — Paiement** : une facture peut recevoir 0 à N paiements; chaque paiement concerne une facture (RG-14).
- **Réservation — Consommation service** : une réservation peut comporter 0 à N consommations; chaque consommation se rattache à un seul séjour et à un service (RG-12).
- **Service — Horaire** : un service possède des horaires par jour; l'unicité service/jour/heure de début évite les doublons exacts (RG-11).
- **Réservation — Avis** : une réservation terminée peut avoir 0 ou 1 avis; l'unicité de `id_reservation` le garantit (RG-16).

## Points de conception à signaler

- Le schéma d'origine ne comporte pas `nb_personnes` ; le script `02_contraintes.sql` l'ajoute pour RG-05 (modification indispensable).
- Le contrôle de capacité totale multi-chambres passe par `verifier_capacite_reservation`, appelée après affectation de toutes les chambres, et par des triggers lors des modifications ultérieures.
- RG-16 et RG-17 sont appliquées par des triggers sur `avis` (réservation terminée, date >= départ) et par un trigger sur `reservation` qui empêche de rendre un avis incohérent après coup.
- `reservation.annulee_le` est renseignée si et seulement si le statut est `annulee` (CHECK `chk_reservation_annulation`, RG-06).
- `reservation_chambre.prix_nuit_fige` : CHECK >= 0 (RG-08).
