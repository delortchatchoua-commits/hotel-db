USE gestion_hotel;

-- =====================================================================
-- 05_tests.sql (L5) : preuves que les regles sont appliquees.
-- A executer APRES 01, 02, 03 (les identifiants viennent du jeu de test 03).
--
-- Principe :
--  * t_rejet : l'operation DOIT echouer avec un message contenant un
--    fragment attendu (un test ne "passe" donc pas pour une mauvaise raison).
--  * t_ok    : l'operation DOIT reussir.
--  * t_verif : verifie une condition (ex. un prix reste fige).
--  * Les tests qui ecrivent des donnees sont entoures de START TRANSACTION
--    ... ROLLBACK : rien ne reste dans la base.
--  * Seule exception (RG-15, bloc final) : enregistrer_paiement fait un COMMIT,
--    donc ce bloc est nettoye a la main (voir le commentaire).
--  * Les resultats s'affichent dans UN seul tableau a la fin du script.
-- =====================================================================

-- Version 4 : les resultats sont gardes dans la variable de session @log (JSON),
-- non transactionnelle : ils survivent aux ROLLBACK sans melanger les moteurs.
SET @log = JSON_ARRAY();

DROP PROCEDURE IF EXISTS t_log;
DROP PROCEDURE IF EXISTS t_rejet;
DROP PROCEDURE IF EXISTS t_ok;
DROP PROCEDURE IF EXISTS t_verif;

DELIMITER $$

CREATE PROCEDURE t_log(IN p_regle VARCHAR(20), IN p_nom VARCHAR(120),
                       IN p_res VARCHAR(10), IN p_detail TEXT)
BEGIN
  SET @log = JSON_ARRAY_APPEND(@log, '$',
    JSON_OBJECT('regle', p_regle, 'test', p_nom, 'resultat', p_res,
                'detail', LEFT(p_detail, 250)));
END$$

CREATE PROCEDURE t_rejet(IN p_regle VARCHAR(20), IN p_nom VARCHAR(120),
                         IN p_sql TEXT, IN p_fragment VARCHAR(100))
BEGIN
  DECLARE v_err INT DEFAULT 0;
  DECLARE v_msg TEXT DEFAULT '';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    -- GET DIAGNOSTICS doit etre la PREMIERE instruction du handler : toute
    -- autre instruction (SET, IF...) vide la zone de diagnostic.
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    SET v_err = 1;
  END;

  SET @sql_test = p_sql;
  PREPARE stmt_test FROM @sql_test;
  EXECUTE stmt_test;
  DEALLOCATE PREPARE stmt_test;

  IF v_err = 1 AND v_msg LIKE CONCAT('%', p_fragment, '%') THEN
    CALL t_log(p_regle, p_nom, 'PASS', LEFT(v_msg, 250));
  ELSEIF v_err = 1 THEN
    CALL t_log(p_regle, p_nom, 'ECHEC', LEFT(CONCAT('Rejet pour une autre raison : ', v_msg), 250));
  ELSE
    CALL t_log(p_regle, p_nom, 'ECHEC', 'Operation acceptee a tort');
  END IF;
END$$

CREATE PROCEDURE t_ok(IN p_regle VARCHAR(20), IN p_nom VARCHAR(120), IN p_sql TEXT)
BEGIN
  DECLARE v_err INT DEFAULT 0;
  DECLARE v_msg TEXT DEFAULT '';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    SET v_err = 1;
  END;

  SET @sql_test = p_sql;
  PREPARE stmt_test FROM @sql_test;
  EXECUTE stmt_test;
  DEALLOCATE PREPARE stmt_test;

  IF v_err = 0 THEN
    CALL t_log(p_regle, p_nom, 'PASS', 'Operation valide acceptee');
  ELSE
    CALL t_log(p_regle, p_nom, 'ECHEC', LEFT(CONCAT('Rejetee a tort : ', v_msg), 250));
  END IF;
END$$

CREATE PROCEDURE t_verif(IN p_regle VARCHAR(20), IN p_nom VARCHAR(120),
                         IN p_condition TINYINT, IN p_detail VARCHAR(200))
BEGIN
  CALL t_log(p_regle, p_nom, IF(IFNULL(p_condition, 0) = 1, 'PASS', 'ECHEC'), p_detail);
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- RG-05 : dates et capacite
-- ---------------------------------------------------------------------
CALL t_rejet('RG-05', 'Depart = arrivee',
  "INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes) VALUES (1,'2027-01-10','2027-01-10','en_attente',1)",
  'chk_reservation_dates');
CALL t_rejet('RG-05', 'Depart avant arrivee',
  "INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes) VALUES (1,'2027-01-10','2027-01-08','en_attente',1)",
  'chk_reservation_dates');
CALL t_rejet('RG-05', 'Nombre de personnes = 0',
  "INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes) VALUES (1,'2027-01-10','2027-01-12','en_attente',0)",
  'chk_reservation_personnes');

START TRANSACTION;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2027-03-01','2027-03-03','en_attente',3);
SET @r = LAST_INSERT_ID();
INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES (@r,1,25000);  -- chambre 101 : 1 place
CALL t_rejet('RG-05', '3 personnes dans une chambre de 1 place',
  'CALL verifier_capacite_reservation(@r)', 'RG-05');
CALL affecter_chambre(@r, 3);                                                                   -- + chambre 103 : 2 places
CALL t_ok('RG-05', '3 personnes dans 1+2 places (limite exacte)',
  'CALL verifier_capacite_reservation(@r)');
ROLLBACK;

CALL t_rejet('RG-05', 'Reservation 21 : passer a 5 personnes (4 places)',
  'UPDATE reservation SET nb_personnes = 5 WHERE id_reservation = 21', 'RG-05');
CALL t_rejet('RG-05', 'Reservation 21 : retirer une chambre (capacite 4 -> 2)',
  'DELETE FROM reservation_chambre WHERE id_reservation = 21 AND id_chambre = 4', 'RG-05');

-- ---------------------------------------------------------------------
-- RG-06 : statut et annulation
-- ---------------------------------------------------------------------
CALL t_rejet('RG-06', 'Annulee sans date d annulation',
  "UPDATE reservation SET statut = 'annulee' WHERE id_reservation = 19", 'chk_reservation_annulation');
CALL t_rejet('RG-06', 'Date d annulation sur une reservation non annulee',
  "UPDATE reservation SET annulee_le = NOW() WHERE id_reservation = 19", 'chk_reservation_annulation');

START TRANSACTION;
CALL t_ok('RG-06', 'Annulation valide (statut + date)',
  "UPDATE reservation SET statut = 'annulee', annulee_le = NOW() WHERE id_reservation = 19");
ROLLBACK;

-- ---------------------------------------------------------------------
-- RG-07 : chevauchements (reservation 18 = chambre 4, du 25 au 28 octobre 2026)
-- ---------------------------------------------------------------------
START TRANSACTION;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2026-10-26','2026-10-27','confirmee',1);
SET @r = LAST_INSERT_ID();
CALL t_rejet('RG-07', 'Chambre 4 : sejour inclus dans la reservation 18',
  'INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES (@r,4,42000)', 'RG-07');
ROLLBACK;

START TRANSACTION;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2026-10-24','2026-10-26','confirmee',1);
SET @r = LAST_INSERT_ID();
CALL t_rejet('RG-07', 'Chambre 4 : chevauchement partiel (24 au 26)',
  'INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES (@r,4,42000)', 'RG-07');
ROLLBACK;

START TRANSACTION;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2026-10-28','2026-10-30','confirmee',1);
SET @r = LAST_INSERT_ID();
CALL t_ok('RG-07', 'Chambre 4 : arrivee le jour du depart precedent (28)',
  'INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES (@r,4,42000)');
ROLLBACK;

-- Une annulation libere immediatement les chambres.
START TRANSACTION;
UPDATE reservation SET statut = 'annulee', annulee_le = NOW() WHERE id_reservation = 18;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2026-10-26','2026-10-27','confirmee',1);
SET @r = LAST_INSERT_ID();
CALL t_ok('RG-07', 'Apres annulation de la 18, la chambre 4 est libre',
  'INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES (@r,4,42000)');
-- ... et on ne peut plus "reactiver" la 18 sur des nuits reprises.
CALL t_rejet('RG-07', 'Reactiver la reservation 18 alors que la chambre est reprise',
  'UPDATE reservation SET statut = ''confirmee'', annulee_le = NULL WHERE id_reservation = 18', 'RG-07');
ROLLBACK;

-- Deplacer les dates d'une reservation vers un conflit.
START TRANSACTION;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2026-11-20','2026-11-22','confirmee',1);
SET @r = LAST_INSERT_ID();
INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES (@r,4,42000);
CALL t_rejet('RG-07', 'Deplacer une reservation vers des nuits deja prises',
  "UPDATE reservation SET date_arrivee = '2026-10-27' WHERE id_reservation = @r", 'RG-07');
ROLLBACK;

-- ---------------------------------------------------------------------
-- RG-08 : prix de la nuit fige
-- ---------------------------------------------------------------------
START TRANSACTION;
UPDATE chambre SET prix_base = 99999 WHERE id_chambre = 3;
SELECT prix_nuit_fige INTO @v FROM reservation_chambre WHERE id_reservation = 1 AND id_chambre = 3;
ROLLBACK;
CALL t_verif('RG-08', 'Changer prix_base ne modifie pas prix_nuit_fige',
  (@v = 40000), 'prix fige attendu : 40000');

START TRANSACTION;
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,nb_personnes)
VALUES (1,'2027-05-01','2027-05-03','en_attente',1);
SET @r = LAST_INSERT_ID();
CALL affecter_chambre(@r, 1);
SELECT prix_nuit_fige INTO @v FROM reservation_chambre WHERE id_reservation = @r AND id_chambre = 1;
ROLLBACK;
CALL t_verif('RG-08', 'affecter_chambre copie prix_base dans prix_nuit_fige',
  (@v = 25000), 'prix attendu : 25000');

CALL t_rejet('RG-08', 'Prix fige negatif',
  'UPDATE reservation_chambre SET prix_nuit_fige = -1 WHERE id_reservation = 1 AND id_chambre = 3', 'chk_rc_prix');

-- ---------------------------------------------------------------------
-- RG-09 : email et telephone uniques
-- ---------------------------------------------------------------------
CALL t_rejet('RG-09', 'Email deja utilise',
  "INSERT INTO client(nom,prenom,telephone,email) VALUES ('TEST','Email','699999991','alice.mbog@example.com')",
  'Duplicate entry');
CALL t_rejet('RG-09', 'Telephone deja utilise',
  "INSERT INTO client(nom,prenom,telephone,email) VALUES ('TEST','Tel','690000001','test.tel@example.com')",
  'Duplicate entry');

-- ---------------------------------------------------------------------
-- RG-12 : services (reservation 1 : 3 au 6 janvier 2026 ; reservation 3 : 2 au 5 fevrier)
-- ---------------------------------------------------------------------
CALL t_rejet('RG-12', 'Service la veille de l arrivee',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,1,'2026-01-02','12:00:00','13:00:00',1,12000)",
  'pendant le sejour');
CALL t_rejet('RG-12', 'Service le jour du depart (exclu)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,1,'2026-01-06','12:00:00','13:00:00',1,12000)",
  'pendant le sejour');
CALL t_rejet('RG-12', 'Service sur une reservation annulee (17)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (17,1,'2026-09-02','12:00:00','13:00:00',1,12000)",
  'pendant le sejour');
CALL t_rejet('RG-12', 'Spa ferme le dimanche (4 janvier 2026)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,2,'2026-01-04','10:00:00','11:00:00',1,18000)",
  'horaire');
CALL t_rejet('RG-12', 'Spa avant l ouverture (08h-09h, ouvre a 09h)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,2,'2026-01-05','08:00:00','09:00:00',1,18000)",
  'horaire');
CALL t_rejet('RG-12', 'Restaurant au-dela de la fermeture (21h30-23h le lundi)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,1,'2026-01-05','21:30:00','23:00:00',1,12000)",
  'horaire');
CALL t_rejet('RG-12', 'Heure de fin avant l heure de debut',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,1,'2026-01-05','13:00:00','12:00:00',1,12000)",
  'chk_cons_horaires');

START TRANSACTION;
CALL t_ok('RG-12', 'Restaurant lundi 12h-13h pendant le sejour',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (1,1,'2026-01-05','12:00:00','13:00:00',1,12000)");
ROLLBACK;

-- Capacite du spa = 8 ; le creneau du 3 fevrier 15h-16h contient deja 1 personne.
CALL t_rejet('RG-12', 'Spa : 8 personnes de plus (1 + 8 > 8)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (3,2,'2026-02-03','15:00:00','16:00:00',8,18000)",
  'capacite');
START TRANSACTION;
CALL t_ok('RG-12', 'Spa : 7 personnes de plus (1 + 7 = 8, limite exacte)',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (3,2,'2026-02-03','15:00:00','16:00:00',7,18000)");
CALL t_rejet('RG-12', 'Spa : une personne de plus sur un creneau plein',
  "INSERT INTO consommation_service(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige) VALUES (3,2,'2026-02-03','15:30:00','16:30:00',1,18000)",
  'capacite');
ROLLBACK;

-- ---------------------------------------------------------------------
-- RG-13 / RG-14 : facture unique, paiements
-- ---------------------------------------------------------------------
CALL t_rejet('RG-13', 'Deuxieme facture pour la reservation 1',
  'INSERT INTO facture(id_reservation) VALUES (1)', 'Duplicate entry');
CALL t_rejet('RG-14', 'Paiement direct de montant 0',
  "INSERT INTO paiement(id_facture,montant,methode) VALUES (9,0,'carte')", 'chk_paiement_montant');
CALL t_rejet('RG-14', 'Paiement negatif via la procedure',
  "CALL enregistrer_paiement(9,-5,'carte')", 'positif');
CALL t_rejet('RG-14', 'Facture inexistante',
  "CALL enregistrer_paiement(9999,1000,'carte')", 'inexistante');
CALL t_rejet('RG-14', 'Surpaiement d une facture deja payee (2)',
  "CALL enregistrer_paiement(2,1,'carte')", 'depasse');
CALL t_rejet('RG-14', 'Surpaiement d une facture due (9, total 71550)',
  "CALL enregistrer_paiement(9,71550.01,'carte')", 'depasse');

-- Les statuts de facture du jeu de test (RG-15).
SELECT COUNT(*) INTO @nb_payee FROM facture WHERE statut = 'payee';
SELECT COUNT(*) INTO @nb_partielle FROM facture WHERE statut = 'partiellement_payee';
SELECT COUNT(*) INTO @nb_due FROM facture WHERE statut = 'due';
CALL t_verif('RG-15', 'Jeu de test : au moins une facture payee',
  (@nb_payee >= 1), CONCAT('payees = ', @nb_payee));
CALL t_verif('RG-15', 'Jeu de test : au moins une facture partiellement payee',
  (@nb_partielle >= 1), CONCAT('partielles = ', @nb_partielle));
CALL t_verif('RG-15', 'Jeu de test : au moins une facture due',
  (@nb_due >= 1), CONCAT('dues = ', @nb_due));

-- ---------------------------------------------------------------------
-- RG-16 / RG-17 : avis
-- ---------------------------------------------------------------------
CALL t_rejet('RG-16', 'Avis sur une reservation confirmee (18)',
  "INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES (18,4,'Trop tot','2026-11-01')", 'RG-16');
CALL t_rejet('RG-16', 'Deuxieme avis sur la reservation 1',
  "INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES (1,4,'Doublon','2026-01-08')", 'Duplicate entry');
CALL t_rejet('RG-17', 'Note 6',
  "INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES (7,6,'Note trop haute','2026-04-06')", 'chk_avis_note');
CALL t_rejet('RG-17', 'Note 0',
  "INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES (7,0,'Note trop basse','2026-04-06')", 'chk_avis_note');
CALL t_rejet('RG-17', 'Avis date avant le depart (4 avril, depart le 5)',
  "INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES (7,4,'Trop tot','2026-04-04')", 'RG-17');
CALL t_rejet('RG-16', 'Annuler une reservation qui a deja un avis',
  "UPDATE reservation SET statut = 'annulee', annulee_le = NOW() WHERE id_reservation = 1", 'RG-16');

START TRANSACTION;
CALL t_ok('RG-17', 'Avis valide (note 5, date = lendemain du depart)',
  "INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES (7,5,NULL,'2026-04-06')");
ROLLBACK;

-- ---------------------------------------------------------------------
-- RG-15 : paiement partiel puis complet (bloc NON transactionnel).
-- enregistrer_paiement fait un COMMIT : on utilise la facture 10 (due, total
-- 62010,00, aucun paiement dans le jeu de test) puis on nettoie nous-memes.
-- ---------------------------------------------------------------------
CALL enregistrer_paiement(10, 10000.00, 'especes');
SELECT statut INTO @s1 FROM facture WHERE id_facture = 10;
CALL t_verif('RG-15', 'Paiement partiel -> partiellement_payee',
  (@s1 = 'partiellement_payee'), CONCAT('statut obtenu : ', @s1));

CALL enregistrer_paiement(10, 52010.00, 'mobile_money');
SELECT statut INTO @s2 FROM facture WHERE id_facture = 10;
CALL t_verif('RG-15', 'Solde complet -> payee',
  (@s2 = 'payee'), CONCAT('statut obtenu : ', @s2));

-- Nettoyage : seuls les 2 paiements ci-dessus existent pour la facture 10.
DELETE FROM paiement WHERE id_facture = 10;
UPDATE facture SET statut = 'due' WHERE id_facture = 10;

-- ---------------------------------------------------------------------
-- Resultats
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS t_rejet;
DROP PROCEDURE IF EXISTS t_ok;
DROP PROCEDURE IF EXISTS t_verif;
DROP PROCEDURE IF EXISTS t_log;

SELECT j.n, j.regle, j.test, j.resultat, j.detail
FROM JSON_TABLE(@log, '$[*]' COLUMNS (
       n FOR ORDINALITY,
       regle VARCHAR(20) PATH '$.regle',
       test VARCHAR(120) PATH '$.test',
       resultat VARCHAR(10) PATH '$.resultat',
       detail VARCHAR(250) PATH '$.detail')) AS j
ORDER BY j.n;

SELECT j.resultat, COUNT(*) AS nombre
FROM JSON_TABLE(@log, '$[*]' COLUMNS (
       resultat VARCHAR(10) PATH '$.resultat')) AS j
GROUP BY j.resultat;
