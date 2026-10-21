USE gestion_hotel;

-- =====================================================================
-- 02_contraintes.sql  (L4) : contraintes metier, triggers, procedures
-- MySQL 8.0.16+ (les CHECK ne sont appliques qu'a partir de cette version).
-- A executer UNE seule fois, juste apres 01_schema.sql sur une base vide.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Seule modification de schema indispensable
-- RG-05 impose "nombre de personnes <= capacite totale des chambres".
-- Sans colonne pour stocker ce nombre, la regle est impossible a verifier.
-- ---------------------------------------------------------------------
ALTER TABLE reservation
  ADD COLUMN nb_personnes TINYINT UNSIGNED NOT NULL DEFAULT 1;

-- ---------------------------------------------------------------------
-- 2. Contraintes CHECK (regles qui ne concernent qu'une seule ligne)
-- ---------------------------------------------------------------------
ALTER TABLE chambre
  ADD CONSTRAINT chk_chambre_capacite CHECK (capacite > 0),
  ADD CONSTRAINT chk_chambre_prix CHECK (prix_base >= 0);

ALTER TABLE reservation
  ADD CONSTRAINT chk_reservation_personnes CHECK (nb_personnes > 0),               -- RG-05
  ADD CONSTRAINT chk_reservation_dates CHECK (date_depart > date_arrivee),         -- RG-05
  ADD CONSTRAINT chk_reservation_annulation CHECK (                                -- RG-06
    (statut = 'annulee' AND annulee_le IS NOT NULL)
    OR (statut <> 'annulee' AND annulee_le IS NULL));

ALTER TABLE reservation_chambre
  ADD CONSTRAINT chk_rc_prix CHECK (prix_nuit_fige >= 0);                          -- RG-08

ALTER TABLE avis
  ADD CONSTRAINT chk_avis_note CHECK (note BETWEEN 1 AND 5);                       -- RG-17

ALTER TABLE paiement
  ADD CONSTRAINT chk_paiement_montant CHECK (montant > 0);                         -- RG-14

ALTER TABLE ligne_facture
  ADD CONSTRAINT chk_ligne_quantite CHECK (quantite > 0),
  ADD CONSTRAINT chk_ligne_prix CHECK (prix_unitaire >= 0),
  ADD CONSTRAINT chk_ligne_taxe CHECK (taux_taxe BETWEEN 0 AND 100);               -- taux en %

ALTER TABLE consommation_service
  ADD CONSTRAINT chk_cons_quantite CHECK (quantite > 0),
  ADD CONSTRAINT chk_cons_prix CHECK (prix_unitaire_fige >= 0),
  ADD CONSTRAINT chk_cons_horaires CHECK (heure_fin > heure_debut);

ALTER TABLE service
  ADD CONSTRAINT chk_service_tarif CHECK (tarif >= 0),
  ADD CONSTRAINT chk_service_capacite CHECK (capacite_creneau > 0);

ALTER TABLE horaire_service
  ADD CONSTRAINT chk_horaire_jour CHECK (jour_semaine BETWEEN 1 AND 7),
  ADD CONSTRAINT chk_horaire_heures CHECK (heure_fin > heure_debut);

-- ---------------------------------------------------------------------
-- 3. Procedures et triggers
-- ---------------------------------------------------------------------
DELIMITER $$

-- RG-05 : capacite totale des chambres >= nombre de personnes.
-- MySQL n'a pas de contrainte "differee" : avec 2 chambres, la capacite
-- est insuffisante apres la 1re insertion. On controle donc par procedure
-- (a appeler une fois toutes les chambres affectees) et par triggers lors
-- des modifications/suppressions de chambres ou de nb_personnes.
CREATE PROCEDURE verifier_capacite_reservation(IN p_id_reservation INT UNSIGNED)
BEGIN
  DECLARE v_personnes INT;
  DECLARE v_statut VARCHAR(20);
  DECLARE v_capacite INT DEFAULT 0;

  SELECT nb_personnes, statut INTO v_personnes, v_statut
  FROM reservation WHERE id_reservation = p_id_reservation;

  IF v_statut IS NOT NULL AND v_statut <> 'annulee' THEN
    SELECT COALESCE(SUM(c.capacite), 0) INTO v_capacite
    FROM reservation_chambre rc
    JOIN chambre c ON c.id_chambre = rc.id_chambre
    WHERE rc.id_reservation = p_id_reservation;

    IF v_capacite < v_personnes THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RG-05 : capacite totale des chambres insuffisante';
    END IF;
  END IF;
END$$

-- RG-08 : affecte une chambre en figeant son prix de base du moment.
CREATE PROCEDURE affecter_chambre(IN p_id_reservation INT UNSIGNED, IN p_id_chambre INT UNSIGNED)
BEGIN
  INSERT INTO reservation_chambre(id_reservation, id_chambre, prix_nuit_fige)
  SELECT p_id_reservation, id_chambre, prix_base
  FROM chambre WHERE id_chambre = p_id_chambre;

  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chambre inexistante';
  END IF;
END$$

-- RG-07 : une chambre ne peut pas etre affectee a deux reservations non
-- annulees dont les nuits se chevauchent (depart = arrivee suivante : OK).
CREATE TRIGGER trg_rc_bi_verifier_chevauchement
BEFORE INSERT ON reservation_chambre
FOR EACH ROW
BEGIN
  DECLARE v_arrivee DATE;
  DECLARE v_depart DATE;
  DECLARE v_statut VARCHAR(20);
  DECLARE v_conflits INT DEFAULT 0;

  SELECT date_arrivee, date_depart, statut
    INTO v_arrivee, v_depart, v_statut
  FROM reservation
  WHERE id_reservation = NEW.id_reservation;

  IF v_statut <> 'annulee' THEN
    SELECT COUNT(*) INTO v_conflits
    FROM reservation_chambre rc
    JOIN reservation r ON r.id_reservation = rc.id_reservation
    WHERE rc.id_chambre = NEW.id_chambre
      AND rc.id_reservation <> NEW.id_reservation
      AND r.statut <> 'annulee'
      AND v_arrivee < r.date_depart
      AND v_depart > r.date_arrivee;

    IF v_conflits > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RG-07 : chevauchement de reservation pour cette chambre';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_rc_bu_verifier_chevauchement
BEFORE UPDATE ON reservation_chambre
FOR EACH ROW
BEGIN
  DECLARE v_arrivee DATE;
  DECLARE v_depart DATE;
  DECLARE v_statut VARCHAR(20);
  DECLARE v_conflits INT DEFAULT 0;

  SELECT date_arrivee, date_depart, statut
    INTO v_arrivee, v_depart, v_statut
  FROM reservation
  WHERE id_reservation = NEW.id_reservation;

  IF v_statut <> 'annulee' THEN
    SELECT COUNT(*) INTO v_conflits
    FROM reservation_chambre rc
    JOIN reservation r ON r.id_reservation = rc.id_reservation
    WHERE rc.id_chambre = NEW.id_chambre
      AND NOT (rc.id_reservation = OLD.id_reservation
               AND rc.id_chambre = OLD.id_chambre)
      AND rc.id_reservation <> NEW.id_reservation
      AND r.statut <> 'annulee'
      AND v_arrivee < r.date_depart
      AND v_depart > r.date_arrivee;

    IF v_conflits > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RG-07 : chevauchement de reservation pour cette chambre';
    END IF;
  END IF;
END$$

-- RG-05 : controle de capacite apres changement ou retrait d'une chambre.
-- (Les suppressions en cascade ne declenchent pas de trigger en MySQL.)
CREATE TRIGGER trg_rc_au_capacite
AFTER UPDATE ON reservation_chambre
FOR EACH ROW
BEGIN
  CALL verifier_capacite_reservation(NEW.id_reservation);
END$$

CREATE TRIGGER trg_rc_ad_capacite
AFTER DELETE ON reservation_chambre
FOR EACH ROW
BEGIN
  CALL verifier_capacite_reservation(OLD.id_reservation);
END$$

-- RG-07 / RG-05 / RG-16 / RG-17 : coherence lors de la modification d'une
-- reservation (dates, statut, nb_personnes). Evite par exemple de "reactiver"
-- une reservation annulee dont les chambres ont ete reprises entre-temps.
CREATE TRIGGER trg_resa_bu_verifier
BEFORE UPDATE ON reservation
FOR EACH ROW
BEGIN
  DECLARE v_conflits INT DEFAULT 0;
  DECLARE v_nb_chambres INT DEFAULT 0;
  DECLARE v_capacite INT DEFAULT 0;
  DECLARE v_avis INT DEFAULT 0;

  -- RG-07 : nouveaux dates/statut -> aucune chambre ne doit entrer en conflit
  IF NEW.statut <> 'annulee'
     AND (NEW.date_arrivee <> OLD.date_arrivee
          OR NEW.date_depart <> OLD.date_depart
          OR NEW.statut <> OLD.statut) THEN
    SELECT COUNT(*) INTO v_conflits
    FROM reservation_chambre mine
    JOIN reservation_chambre rc
      ON rc.id_chambre = mine.id_chambre
     AND rc.id_reservation <> NEW.id_reservation
    JOIN reservation r ON r.id_reservation = rc.id_reservation
    WHERE mine.id_reservation = NEW.id_reservation
      AND r.statut <> 'annulee'
      AND NEW.date_arrivee < r.date_depart
      AND NEW.date_depart > r.date_arrivee;

    IF v_conflits > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RG-07 : chevauchement de reservation pour cette chambre';
    END IF;
  END IF;

  -- RG-05 : nouveau nb_personnes <= capacite des chambres deja affectees
  IF NEW.statut <> 'annulee' AND NEW.nb_personnes <> OLD.nb_personnes THEN
    SELECT COUNT(*), COALESCE(SUM(c.capacite), 0) INTO v_nb_chambres, v_capacite
    FROM reservation_chambre rc
    JOIN chambre c ON c.id_chambre = rc.id_chambre
    WHERE rc.id_reservation = NEW.id_reservation;

    IF v_nb_chambres > 0 AND v_capacite < NEW.nb_personnes THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RG-05 : capacite totale des chambres insuffisante';
    END IF;
  END IF;

  -- RG-16 / RG-17 : une reservation qui a un avis doit rester terminee et
  -- ne pas avoir un depart posterieur a la date de l'avis.
  IF NEW.statut <> 'terminee' OR NEW.date_depart <> OLD.date_depart THEN
    SELECT COUNT(*) INTO v_avis
    FROM avis
    WHERE id_reservation = NEW.id_reservation
      AND (NEW.statut <> 'terminee' OR date_avis < NEW.date_depart);

    IF v_avis > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RG-16/RG-17 : un avis existe, la reservation doit rester terminee et le depart ne peut pas depasser la date de l avis';
    END IF;
  END IF;
END$$

-- RG-16 : un avis ne porte que sur une reservation terminee.
-- RG-17 : la date de l'avis est posterieure ou egale a la date de depart.
CREATE TRIGGER trg_avis_bi_date_depart
BEFORE INSERT ON avis
FOR EACH ROW
BEGIN
  DECLARE v_depart DATE;
  DECLARE v_statut VARCHAR(20);

  SELECT date_depart, statut INTO v_depart, v_statut
  FROM reservation
  WHERE id_reservation = NEW.id_reservation;

  IF NEW.date_avis < v_depart THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-17 : date avis anterieure au depart';
  END IF;

  IF v_statut <> 'terminee' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-16 : un avis ne peut concerner qu une reservation terminee';
  END IF;
END$$

CREATE TRIGGER trg_avis_bu_date_depart
BEFORE UPDATE ON avis
FOR EACH ROW
BEGIN
  DECLARE v_depart DATE;
  DECLARE v_statut VARCHAR(20);

  SELECT date_depart, statut INTO v_depart, v_statut
  FROM reservation
  WHERE id_reservation = NEW.id_reservation;

  IF NEW.date_avis < v_depart THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-17 : date avis anterieure au depart';
  END IF;

  IF v_statut <> 'terminee' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-16 : un avis ne peut concerner qu une reservation terminee';
  END IF;
END$$

-- RG-12 : un service se consomme pendant le sejour (jour de depart exclu),
-- dans les horaires d'ouverture du jour, et dans la limite de la capacite
-- du creneau (somme des quantites des creneaux qui se chevauchent).
CREATE TRIGGER trg_cons_bi_verifier_regles
BEFORE INSERT ON consommation_service
FOR EACH ROW
BEGIN
  DECLARE v_arrivee DATE;
  DECLARE v_depart DATE;
  DECLARE v_statut VARCHAR(20);
  DECLARE v_capacite INT;
  DECLARE v_ouverts INT DEFAULT 0;
  DECLARE v_reserve INT DEFAULT 0;

  SELECT r.date_arrivee, r.date_depart, r.statut
    INTO v_arrivee, v_depart, v_statut
  FROM reservation r
  WHERE r.id_reservation = NEW.id_reservation;

  IF v_statut = 'annulee' OR NEW.date_service < v_arrivee
     OR NEW.date_service >= v_depart THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-12 : le service doit etre consomme pendant le sejour';
  END IF;

  SELECT capacite_creneau INTO v_capacite
  FROM service WHERE id_service = NEW.id_service;

  SELECT COUNT(*) INTO v_ouverts
  FROM horaire_service
  WHERE id_service = NEW.id_service
    AND jour_semaine = WEEKDAY(NEW.date_service) + 1
    AND heure_debut <= NEW.heure_debut
    AND heure_fin >= NEW.heure_fin;

  IF v_ouverts = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-12 : horaire en dehors des heures d ouverture';
  END IF;

  SELECT COALESCE(SUM(quantite), 0) INTO v_reserve
  FROM consommation_service
  WHERE id_service = NEW.id_service
    AND date_service = NEW.date_service
    AND heure_debut < NEW.heure_fin
    AND heure_fin > NEW.heure_debut;

  IF v_reserve + NEW.quantite > v_capacite THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-12 : capacite du creneau depassee';
  END IF;
END$$

CREATE TRIGGER trg_cons_bu_verifier_regles
BEFORE UPDATE ON consommation_service
FOR EACH ROW
BEGIN
  DECLARE v_arrivee DATE;
  DECLARE v_depart DATE;
  DECLARE v_statut VARCHAR(20);
  DECLARE v_capacite INT;
  DECLARE v_ouverts INT DEFAULT 0;
  DECLARE v_reserve INT DEFAULT 0;

  SELECT r.date_arrivee, r.date_depart, r.statut
    INTO v_arrivee, v_depart, v_statut
  FROM reservation r
  WHERE r.id_reservation = NEW.id_reservation;

  IF v_statut = 'annulee' OR NEW.date_service < v_arrivee
     OR NEW.date_service >= v_depart THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-12 : le service doit etre consomme pendant le sejour';
  END IF;

  SELECT capacite_creneau INTO v_capacite
  FROM service WHERE id_service = NEW.id_service;

  SELECT COUNT(*) INTO v_ouverts
  FROM horaire_service
  WHERE id_service = NEW.id_service
    AND jour_semaine = WEEKDAY(NEW.date_service) + 1
    AND heure_debut <= NEW.heure_debut
    AND heure_fin >= NEW.heure_fin;

  IF v_ouverts = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-12 : horaire en dehors des heures d ouverture';
  END IF;

  SELECT COALESCE(SUM(quantite), 0) INTO v_reserve
  FROM consommation_service
  WHERE id_service = NEW.id_service
    AND date_service = NEW.date_service
    AND id_consommation <> OLD.id_consommation
    AND heure_debut < NEW.heure_fin
    AND heure_fin > NEW.heure_debut;

  IF v_reserve + NEW.quantite > v_capacite THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RG-12 : capacite du creneau depassee';
  END IF;
END$$

-- RG-14 / RG-15 : enregistrement d'un paiement dans une transaction qui met
-- a jour le statut de la facture. Total TTC = somme(quantite * prix * (1 + taux/100)).
-- Attention : START TRANSACTION valide (COMMIT implicite) toute transaction
-- deja ouverte par l'appelant.
CREATE PROCEDURE enregistrer_paiement(
  IN p_id_facture INT UNSIGNED,
  IN p_montant DECIMAL(10,2),
  IN p_methode VARCHAR(20)
)
BEGIN
  DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_paye DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_statut VARCHAR(30);
  DECLARE v_existe INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT COUNT(*) INTO v_existe
  FROM facture WHERE id_facture = p_id_facture
  FOR UPDATE;

  IF v_existe = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Facture inexistante';
  END IF;

  IF p_montant IS NULL OR p_montant <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Le montant du paiement doit etre positif';
  END IF;

  IF p_methode NOT IN ('especes', 'carte', 'mobile_money', 'virement') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Methode de paiement invalide';
  END IF;

  SELECT COALESCE(SUM(quantite * prix_unitaire * (1 + taux_taxe / 100)), 0)
    INTO v_total
  FROM ligne_facture WHERE id_facture = p_id_facture;

  SELECT COALESCE(SUM(montant), 0)
    INTO v_paye
  FROM paiement WHERE id_facture = p_id_facture;

  IF v_paye + p_montant > v_total THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Le paiement depasse le solde de la facture';
  END IF;

  INSERT INTO paiement(id_facture, montant, methode)
  VALUES (p_id_facture, p_montant, p_methode);

  SET v_paye = v_paye + p_montant;

  IF v_paye = 0 THEN
    SET v_statut = 'due';
  ELSEIF v_paye < v_total THEN
    SET v_statut = 'partiellement_payee';
  ELSE
    SET v_statut = 'payee';
  END IF;

  UPDATE facture SET statut = v_statut
  WHERE id_facture = p_id_facture;

  COMMIT;
END$$

DELIMITER ;
