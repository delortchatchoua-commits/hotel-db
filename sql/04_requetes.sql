USE gestion_hotel;

-- L6.1 : chambres disponibles pour un type et une periode.
-- RG-03 : la disponibilite se deduit des reservations, pas de chambre.etat.
-- Une chambre est donc disponible si aucun sejour non annule ne chevauche
-- la periode demandee. (Pour exclure aussi les chambres hors service, ajouter
-- la condition  AND c.etat <> 'hors_service'.)
SET @date_debut = '2026-10-24';
SET @date_fin = '2026-10-29';
SET @type_demande = 'double';

SELECT c.id_chambre, c.numero, c.etage, c.type_chambre, c.capacite, c.prix_base
FROM chambre c
WHERE c.type_chambre = @type_demande
  AND @date_fin > @date_debut
  AND NOT EXISTS (
    SELECT 1
    FROM reservation_chambre rc
    JOIN reservation r ON r.id_reservation = rc.id_reservation
    WHERE rc.id_chambre = c.id_chambre
      AND r.statut <> 'annulee'
      AND r.date_arrivee < @date_fin
      AND r.date_depart > @date_debut
  )
ORDER BY c.prix_base;

-- L6.2 : taux d'occupation par mois (nuits vendues / nuits disponibles).
-- RG-03 : toutes les chambres comptent dans les nuits disponibles (l'etat
-- instantane n'intervient pas dans le calcul sur une periode).
WITH RECURSIVE calendrier AS (
  SELECT DATE('2026-01-01') AS jour
  UNION ALL
  SELECT jour + INTERVAL 1 DAY FROM calendrier
  WHERE jour < '2026-12-31'
),
nuits_vendues AS (
  SELECT DATE_FORMAT(cal.jour,'%Y-%m') AS mois,
         COUNT(DISTINCT CONCAT(rc.id_chambre,'-',cal.jour)) AS nuits_vendues
  FROM calendrier cal
  JOIN reservation r
    ON cal.jour >= r.date_arrivee AND cal.jour < r.date_depart
  JOIN reservation_chambre rc ON rc.id_reservation = r.id_reservation
  WHERE r.statut <> 'annulee'
  GROUP BY DATE_FORMAT(cal.jour,'%Y-%m')
),
nuits_disponibles AS (
  SELECT DATE_FORMAT(cal.jour,'%Y-%m') AS mois,
         COUNT(*) AS nuits_disponibles
  FROM calendrier cal
  CROSS JOIN chambre c
  GROUP BY DATE_FORMAT(cal.jour,'%Y-%m')
)
SELECT nd.mois, COALESCE(nv.nuits_vendues,0) AS nuits_vendues,
       nd.nuits_disponibles,
       ROUND(100 * COALESCE(nv.nuits_vendues,0) / NULLIF(nd.nuits_disponibles,0),2) AS taux_occupation_pct
FROM nuits_disponibles nd
LEFT JOIN nuits_vendues nv ON nv.mois=nd.mois
ORDER BY nd.mois;

-- L6.3 : chiffre d'affaires mensuel, separe hebergement et services.
-- CA facture = lignes de facture hors doublons; categorie determinee par libelle.
SELECT DATE_FORMAT(f.emise_le,'%Y-%m') AS mois,
       ROUND(SUM(CASE WHEN lf.libelle LIKE 'Hebergement%' 
                      THEN lf.quantite*lf.prix_unitaire*(1+lf.taux_taxe/100) ELSE 0 END),2) AS ca_hebergement,
       ROUND(SUM(CASE WHEN lf.libelle LIKE 'Service :%' 
                      THEN lf.quantite*lf.prix_unitaire*(1+lf.taux_taxe/100) ELSE 0 END),2) AS ca_services,
       ROUND(SUM(lf.quantite*lf.prix_unitaire*(1+lf.taux_taxe/100)),2) AS ca_total
FROM facture f
JOIN ligne_facture lf ON lf.id_facture=f.id_facture
GROUP BY DATE_FORMAT(f.emise_le,'%Y-%m')
ORDER BY mois;

-- L6.4 : factures non soldees, montant restant du, de la plus ancienne a la plus recente.
WITH totaux AS (
  SELECT f.id_facture, f.emise_le, f.statut,
         COALESCE(SUM(lf.quantite*lf.prix_unitaire*(1+lf.taux_taxe/100)),0) AS total_ttc
  FROM facture f LEFT JOIN ligne_facture lf ON lf.id_facture=f.id_facture
  GROUP BY f.id_facture, f.emise_le, f.statut
),
paiements AS (
  SELECT id_facture, SUM(montant) AS total_paye
  FROM paiement GROUP BY id_facture
)
SELECT t.id_facture, t.emise_le, t.statut, ROUND(t.total_ttc,2) AS total_ttc,
       ROUND(t.total_ttc-COALESCE(p.total_paye,0),2) AS reste_a_payer
FROM totaux t LEFT JOIN paiements p ON p.id_facture=t.id_facture
WHERE t.total_ttc > COALESCE(p.total_paye,0)
ORDER BY t.emise_le ASC;

-- L6.5 : note moyenne et nombre d'avis par type de chambre.
-- On rattache chaque avis aux types de chambres du sejour correspondant.
SELECT c.type_chambre, ROUND(AVG(a.note),2) AS note_moyenne,
       COUNT(a.id_avis) AS nombre_avis
FROM avis a
JOIN reservation_chambre rc ON rc.id_reservation=a.id_reservation
JOIN chambre c ON c.id_chambre=rc.id_chambre
GROUP BY c.type_chambre
ORDER BY c.type_chambre;

-- L6.6 : les 5 clients ayant depense le plus et leur nombre de sejours.
WITH depenses AS (
  SELECT r.id_client,
         SUM(lf.quantite*lf.prix_unitaire*(1+lf.taux_taxe/100)) AS total_facture
  FROM reservation r
  JOIN facture f ON f.id_reservation=r.id_reservation
  JOIN ligne_facture lf ON lf.id_facture=f.id_facture
  GROUP BY r.id_client
),
sejours AS (
  SELECT id_client, COUNT(*) AS nombre_sejours
  FROM reservation
  WHERE statut IN ('terminee','confirmee')
  GROUP BY id_client
)
SELECT cl.id_client, cl.nom, cl.prenom, ROUND(d.total_facture,2) AS total_depense,
       COALESCE(s.nombre_sejours,0) AS nombre_sejours
FROM depenses d
JOIN client cl ON cl.id_client=d.id_client
LEFT JOIN sejours s ON s.id_client=cl.id_client
ORDER BY total_depense DESC
LIMIT 5;
