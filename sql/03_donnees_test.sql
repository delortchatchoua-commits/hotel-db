USE gestion_hotel;

-- L5 : donnees de test deterministes. A executer apres 01 et 02.
-- Les dates sont fixees en 2026 afin que les resultats restent reproductibles.

INSERT INTO amenagement(libelle) VALUES
('Vue mer'), ('Balcon'), ('Baignoire'), ('Climatisation'), ('Wi-Fi'), ('Mini-bar');

INSERT INTO chambre(numero, etage, type_chambre, capacite, prix_base, etat) VALUES
('101',1,'simple',1,25000,'disponible'),
('102',1,'simple',1,26000,'disponible'),
('103',1,'double',2,40000,'disponible'),
('104',1,'double',2,42000,'disponible'),
('105',1,'familiale',4,65000,'disponible'),
('201',2,'simple',1,27000,'disponible'),
('202',2,'double',2,45000,'disponible'),
('203',2,'suite',2,85000,'disponible'),
('204',2,'familiale',5,75000,'disponible'),
('205',2,'double',2,47000,'disponible'),
('301',3,'simple',1,28000,'disponible'),
('302',3,'double',2,48000,'disponible'),
('303',3,'suite',2,95000,'disponible'),
('304',3,'familiale',4,80000,'disponible'),
('305',3,'double',2,50000,'hors_service');

INSERT INTO chambre_amenagement(id_chambre,id_amenagement)
SELECT c.id_chambre, a.id_amenagement
FROM chambre c CROSS JOIN amenagement a
WHERE (c.numero IN ('101','102','201','301') AND a.libelle IN ('Climatisation','Wi-Fi'))
   OR (c.numero IN ('103','104','202','205','302','305') AND a.libelle IN ('Balcon','Climatisation','Wi-Fi'))
   OR (c.numero IN ('105','204','304') AND a.libelle IN ('Balcon','Baignoire','Climatisation','Wi-Fi'))
   OR (c.numero IN ('203','303') AND a.libelle IN ('Vue mer','Balcon','Baignoire','Climatisation','Wi-Fi','Mini-bar'));

INSERT INTO client(nom,prenom,telephone,email) VALUES
('MBOG','Alice','690000001','alice.mbog@example.com'),
('TCHOUA','David','690000002','david.tchoua@example.com'),
('NGONO','Sarah','690000003','sarah.ngono@example.com'),
('FOTSO','Paul','690000004','paul.fotso@example.com'),
('ESSOMBA','Marie','690000005','marie.essomba@example.com'),
('KAMGA','Jean','690000006','jean.kamga@example.com'),
('NDONGO','Esther','690000007','esther.ndongo@example.com'),
('MBALLA','Eric','690000008','eric.mballa@example.com'),
('TALLA','Ruth','690000009','ruth.talla@example.com'),
('MANGA','Joel','690000010','joel.manga@example.com'),
-- Client 11 : volontairement sans aucune reservation (exige par l'enonce).
('LOGO','Nadine','690000011','nadine.logo@example.com');

-- 21 reservations : 20 avec une chambre, la reservation 21 porte sur 2 chambres.
-- Les dates se chevauchent entre chambres differentes, jamais sur une meme chambre.
INSERT INTO reservation(id_client,date_arrivee,date_depart,statut,cree_le,annulee_le,nb_personnes) VALUES
(1,'2026-01-03','2026-01-06','terminee','2025-12-20 10:00:00',NULL,2),
(2,'2026-01-10','2026-01-12','terminee','2025-12-22 11:00:00',NULL,1),
(3,'2026-02-02','2026-02-05','terminee','2026-01-10 09:00:00',NULL,2),
(4,'2026-02-10','2026-02-12','terminee','2026-01-20 12:00:00',NULL,2),
(5,'2026-03-01','2026-03-04','terminee','2026-02-01 08:30:00',NULL,4),
(6,'2026-03-10','2026-03-12','terminee','2026-02-15 14:00:00',NULL,1),
(7,'2026-04-02','2026-04-05','terminee','2026-03-01 10:00:00',NULL,2),
(8,'2026-04-10','2026-04-13','terminee','2026-03-15 10:00:00',NULL,2),
(9,'2026-05-01','2026-05-03','terminee','2026-04-01 11:00:00',NULL,2),
(10,'2026-05-10','2026-05-12','terminee','2026-04-15 13:00:00',NULL,1),
(1,'2026-06-02','2026-06-05','terminee','2026-05-01 09:00:00',NULL,2),
(2,'2026-06-10','2026-06-12','terminee','2026-05-15 09:00:00',NULL,2),
(3,'2026-07-01','2026-07-04','terminee','2026-06-01 09:00:00',NULL,4),
(4,'2026-07-10','2026-07-12','terminee','2026-06-15 09:00:00',NULL,2),
(5,'2026-08-01','2026-08-03','terminee','2026-07-01 09:00:00',NULL,2),
(6,'2026-08-10','2026-08-12','terminee','2026-07-15 09:00:00',NULL,1),
(7,'2026-09-01','2026-09-03','annulee','2026-08-01 09:00:00','2026-08-10 10:00:00',2),
(8,'2026-10-25','2026-10-28','confirmee','2026-10-01 09:00:00',NULL,2),
(9,'2026-11-02','2026-11-05','en_attente','2026-10-10 09:00:00',NULL,2),
(10,'2026-11-10','2026-11-12','confirmee','2026-10-12 09:00:00',NULL,1),
-- Reservation 21 : 4 personnes, 2 chambres de 2 places (cas multi-chambres).
(2,'2026-12-01','2026-12-04','confirmee','2026-10-20 09:00:00',NULL,4);

-- Affectations chambre / reservation.
INSERT INTO reservation_chambre(id_reservation,id_chambre,prix_nuit_fige) VALUES
(1,3,40000),(2,1,25000),(3,4,42000),(4,7,45000),(5,5,65000),
(6,6,27000),(7,8,85000),(8,10,47000),(9,11,28000),(10,2,26000),
(11,12,48000),(12,13,95000),(13,9,75000),(14,14,80000),(15,3,40000),
(16,1,25000),(17,2,26000),(18,4,42000),(19,6,27000),(20,11,28000),
(21,3,40000),(21,4,42000);

INSERT INTO service(nom,description,tarif,capacite_creneau) VALUES
('Restaurant','Repas et restauration',12000,30),
('Spa','Soins et relaxation',18000,8),
('Salle de sport','Acces aux equipements sportifs',5000,12),
('Blanchisserie','Lavage et repassage',4000,10);

-- Horaires differents selon le jour (1=lundi ... 7=dimanche).
-- Restaurant (1) : 07-22h en semaine, 08-23h le week-end.
-- Spa (2) : 09-19h du lundi au samedi, ferme le dimanche.
-- Salle de sport (3) : 06-22h en semaine, 08-20h le week-end.
-- Blanchisserie (4) : 08-17h du lundi au samedi, fermee le dimanche.
INSERT INTO horaire_service(id_service,jour_semaine,heure_debut,heure_fin) VALUES
(1,1,'07:00:00','22:00:00'),(1,2,'07:00:00','22:00:00'),(1,3,'07:00:00','22:00:00'),
(1,4,'07:00:00','22:00:00'),(1,5,'07:00:00','22:00:00'),
(1,6,'08:00:00','23:00:00'),(1,7,'08:00:00','23:00:00'),
(2,1,'09:00:00','19:00:00'),(2,2,'09:00:00','19:00:00'),(2,3,'09:00:00','19:00:00'),
(2,4,'09:00:00','19:00:00'),(2,5,'09:00:00','19:00:00'),(2,6,'09:00:00','19:00:00'),
(3,1,'06:00:00','22:00:00'),(3,2,'06:00:00','22:00:00'),(3,3,'06:00:00','22:00:00'),
(3,4,'06:00:00','22:00:00'),(3,5,'06:00:00','22:00:00'),
(3,6,'08:00:00','20:00:00'),(3,7,'08:00:00','20:00:00'),
(4,1,'08:00:00','17:00:00'),(4,2,'08:00:00','17:00:00'),(4,3,'08:00:00','17:00:00'),
(4,4,'08:00:00','17:00:00'),(4,5,'08:00:00','17:00:00'),(4,6,'08:00:00','17:00:00');

INSERT INTO consommation_service
(id_reservation,id_service,date_service,heure_debut,heure_fin,quantite,prix_unitaire_fige)
VALUES
(1,1,'2026-01-04','12:00','13:00',2,12000),
(3,2,'2026-02-03','15:00','16:00',1,18000),
(5,1,'2026-03-02','12:00','13:00',4,12000),
(7,3,'2026-04-03','09:00','10:00',2,5000),
(9,4,'2026-05-02','10:00','11:00',1,4000),
(11,1,'2026-06-03','13:00','14:00',2,12000);

-- Une facture unique par reservation. Lignes d'hebergement et de services.
INSERT INTO facture(id_reservation,emise_le,statut) VALUES
(1,'2026-01-06 12:00:00','due'),
(2,'2026-01-12 12:00:00','due'),
(3,'2026-02-05 12:00:00','due'),
(4,'2026-02-12 12:00:00','due'),
(5,'2026-03-04 12:00:00','due'),
(6,'2026-03-12 12:00:00','due'),
(7,'2026-04-05 12:00:00','due'),
(8,'2026-04-13 12:00:00','due'),
(9,'2026-05-03 12:00:00','due'),
(10,'2026-05-12 12:00:00','due');

INSERT INTO ligne_facture(id_facture,libelle,quantite,prix_unitaire,taux_taxe)
SELECT f.id_facture,
       CONCAT('Hebergement chambre ', c.numero),
       DATEDIFF(r.date_depart,r.date_arrivee),
       rc.prix_nuit_fige, 19.25
FROM facture f
JOIN reservation r ON r.id_reservation=f.id_reservation
JOIN reservation_chambre rc ON rc.id_reservation=r.id_reservation
JOIN chambre c ON c.id_chambre=rc.id_chambre;

INSERT INTO ligne_facture(id_facture,libelle,quantite,prix_unitaire,taux_taxe)
SELECT f.id_facture, CONCAT('Service : ',s.nom), cs.quantite,
       cs.prix_unitaire_fige, 19.25
FROM facture f
JOIN consommation_service cs ON cs.id_reservation=f.id_reservation
JOIN service s ON s.id_service=cs.id_service;

-- Paiements saisis via la procedure pour appliquer RG-15.
CALL enregistrer_paiement(1,100000,'mobile_money');
-- Facture 2 : total TTC 59625,00 -> deux paiements, statut final 'payee'.
CALL enregistrer_paiement(2,50000,'especes');
CALL enregistrer_paiement(2,9625.00,'carte');
CALL enregistrer_paiement(3,100000,'carte');
CALL enregistrer_paiement(4,50000,'virement');
CALL enregistrer_paiement(5,100000,'mobile_money');
CALL enregistrer_paiement(6,10000,'especes');
CALL enregistrer_paiement(7,100000,'carte');
CALL enregistrer_paiement(8,50000,'mobile_money');

-- Avis seulement sur des reservations terminees, au plus un par reservation.
INSERT INTO avis(id_reservation,note,commentaire,date_avis) VALUES
(1,5,'Excellent sejour','2026-01-07'),
(2,4,'Bon accueil','2026-01-13'),
(3,5,'Tres confortable','2026-02-06'),
(4,3,'Sejour correct','2026-02-13'),
(5,4,'Chambre familiale agreable','2026-03-05'),
(6,2,'Service a ameliorer','2026-03-13');

-- Controle rapide des volumes.
SELECT 'chambres' AS entite, COUNT(*) AS total FROM chambre
UNION ALL SELECT 'clients', COUNT(*) FROM client
UNION ALL SELECT 'reservations', COUNT(*) FROM reservation
UNION ALL SELECT 'services', COUNT(*) FROM service
UNION ALL SELECT 'factures', COUNT(*) FROM facture
UNION ALL SELECT 'avis', COUNT(*) FROM avis;
