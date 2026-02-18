<?php
namespace App\Models;

class Trajet {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Get all routes
     */
    public function getAll() {
        $sql = "SELECT t.*,
                c.numero_commande,
                c.adresse_depart,
                c.adresse_arrivee,
                cl.nom as client_nom,
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                v.immatriculation as vehicule_immat,
                v.marque as vehicule_marque,
                v.modele as vehicule_modele,
                u.nom as chauffeur_nom,
                u.prenom as chauffeur_prenom
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                INNER JOIN users u ON t.chauffeur_id = u.id
                WHERE t.actif = 1
                ORDER BY t.date_depart DESC";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Find route by ID
     */
    public function findById($id) {
        $sql = "SELECT t.*,
                c.numero_commande,
                c.adresse_depart,
                c.adresse_arrivee,
                c.description as commande_description,
                cl.nom as client_nom,
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                v.immatriculation as vehicule_immat,
                v.marque as vehicule_marque,
                v.modele as vehicule_modele,
                u.nom as chauffeur_nom,
                u.prenom as chauffeur_prenom,
                u.telephone as chauffeur_telephone
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                INNER JOIN users u ON t.chauffeur_id = u.id
                WHERE t.id = ? AND t.actif = 1";
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Find route by order ID
     */
    public function findByCommandeId($commandeId) {
        $sql = "SELECT * FROM trajets WHERE commande_id = ? AND actif = 1";
        return $this->db->fetch($sql, [$commandeId]);
    }
    
    /**
     * Get routes by status
     */
    public function getByStatut($statut) {
        $sql = "SELECT t.*,
                c.numero_commande,
                cl.nom as client_nom,
                v.immatriculation as vehicule_immat,
                u.nom as chauffeur_nom,
                u.prenom as chauffeur_prenom
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                INNER JOIN users u ON t.chauffeur_id = u.id
                WHERE t.statut = ? AND t.actif = 1
                ORDER BY t.date_depart DESC";
        return $this->db->fetchAll($sql, [$statut]);
    }
    
    /**
     * Get routes by driver ID
     */
    public function getByChauffeurId($chauffeurId) {
        $sql = "SELECT t.*,
                c.numero_commande,
                c.adresse_depart,
                c.adresse_arrivee,
                cl.nom as client_nom,
                cl.prenom as client_prenom,
                v.immatriculation as vehicule_immat,
                v.marque as vehicule_marque
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                WHERE t.chauffeur_id = ? AND t.actif = 1
                ORDER BY t.date_depart DESC";
        return $this->db->fetchAll($sql, [$chauffeurId]);
    }
    
    /**
     * Get routes by vehicle ID
     */
    public function getByVehiculeId($vehiculeId) {
        $sql = "SELECT t.*,
                c.numero_commande,
                cl.nom as client_nom,
                u.nom as chauffeur_nom,
                u.prenom as chauffeur_prenom
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN users u ON t.chauffeur_id = u.id
                WHERE t.vehicule_id = ? AND t.actif = 1
                ORDER BY t.date_depart DESC";
        return $this->db->fetchAll($sql, [$vehiculeId]);
    }
    
    /**
     * Get routes by order ID
     */
    public function getByCommandeId($commandeId) {
        $sql = "SELECT t.*,
                v.immatriculation as vehicule_immat,
                u.nom as chauffeur_nom,
                u.prenom as chauffeur_prenom
                FROM trajets t
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                INNER JOIN users u ON t.chauffeur_id = u.id
                WHERE t.commande_id = ? AND t.actif = 1
                ORDER BY t.date_depart";
        return $this->db->fetchAll($sql, [$commandeId]);
    }
    
    /**
     * Get active routes by vehicle ID
     */
    public function getActiveByVehiculeId($vehiculeId) {
        $sql = "SELECT * FROM trajets 
                WHERE vehicule_id = ? AND statut IN ('planifie', 'en_cours') AND actif = 1";
        return $this->db->fetchAll($sql, [$vehiculeId]);
    }
    
    /**
     * Create new route
     */
    public function create($data) {
        $sql = "INSERT INTO trajets (
                    commande_id, vehicule_id, chauffeur_id, date_depart, 
                    date_arrivee_prevue, distance_km, statut, notes, actif, date_creation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())";
        
        return $this->db->insert($sql, [
            $data['commande_id'],
            $data['vehicule_id'],
            $data['chauffeur_id'],
            $data['date_depart'],
            $data['date_arrivee_prevue'],
            $data['distance_km'],
            $data['statut'],
            $data['notes']
        ]);
    }
    
    /**
     * Update route
     */
    public function update($id, $data) {
        $fields = [];
        $params = [];
        
        $allowedFields = [
            'commande_id', 'vehicule_id', 'chauffeur_id', 'date_depart',
            'date_arrivee_prevue', 'date_arrivee_reelle', 'distance_km', 'statut', 'notes'
        ];
        
        foreach ($data as $key => $value) {
            if (in_array($key, $allowedFields)) {
                $fields[] = "$key = ?";
                $params[] = $value;
            }
        }
        
        if (empty($fields)) {
            return false;
        }
        
        $params[] = $id;
        $sql = "UPDATE trajets SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";
        
        return $this->db->execute($sql, $params);
    }
    
    /**
     * Delete route (soft delete)
     */
    public function delete($id) {
        $sql = "UPDATE trajets SET actif = 0, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Check if driver is busy at given time
     */
    public function isChauffeurOccupy($chauffeurId, $dateDepart, $excludeTrajetId = null) {
        $sql = "SELECT COUNT(*) as count FROM trajets 
                WHERE chauffeur_id = ? 
                AND statut IN ('planifie', 'en_cours') 
                AND actif = 1
                AND DATE(date_depart) = DATE(?)";
        
        $params = [$chauffeurId, $dateDepart];
        
        if ($excludeTrajetId) {
            $sql .= " AND id != ?";
            $params[] = $excludeTrajetId;
        }
        
        $result = $this->db->fetch($sql, $params);
        return $result['count'] > 0;
    }
    
    /**
     * Get route statistics
     */
    public function getStatistics() {
        $sql = "SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN statut = 'planifie' THEN 1 END) as planifies,
                COUNT(CASE WHEN statut = 'en_cours' THEN 1 END) as en_cours,
                COUNT(CASE WHEN statut = 'termine' THEN 1 END) as termines,
                COUNT(CASE WHEN statut = 'annule' THEN 1 END) as annules,
                AVG(distance_km) as distance_moyenne,
                SUM(distance_km) as distance_totale
                FROM trajets 
                WHERE actif = 1";
        
        return $this->db->fetch($sql);
    }
    
    /**
     * Count routes
     */
    public function count() {
        $sql = "SELECT COUNT(*) as total FROM trajets WHERE actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count routes by status
     */
    public function countByStatus($status) {
        $sql = "SELECT COUNT(*) as total FROM trajets WHERE statut = ? AND actif = 1";
        $result = $this->db->fetch($sql, [$status]);
        return $result['total'];
    }
    
    /**
     * Count routes by driver and status
     */
    public function countByChauffeurAndStatus($chauffeurId, $status) {
        $sql = "SELECT COUNT(*) as total FROM trajets 
                WHERE chauffeur_id = ? AND statut = ? AND actif = 1";
        $result = $this->db->fetch($sql, [$chauffeurId, $status]);
        return $result['total'];
    }
    
    /**
     * Count routes by driver this month
     */
    public function countByChauffeurThisMonth($chauffeurId) {
        $sql = "SELECT COUNT(*) as total FROM trajets 
                WHERE chauffeur_id = ? AND actif = 1 
                AND MONTH(date_depart) = MONTH(NOW()) 
                AND YEAR(date_depart) = YEAR(NOW())";
        $result = $this->db->fetch($sql, [$chauffeurId]);
        return $result['total'];
    }
    
    /**
     * Get kilometers by driver this month
     */
    public function getKmByChauffeurThisMonth($chauffeurId) {
        $sql = "SELECT COALESCE(SUM(distance_km), 0) as total FROM trajets 
                WHERE chauffeur_id = ? AND actif = 1 AND statut = 'termine'
                AND MONTH(date_depart) = MONTH(NOW()) 
                AND YEAR(date_depart) = YEAR(NOW())";
        $result = $this->db->fetch($sql, [$chauffeurId]);
        return $result['total'];
    }
    
    /**
     * Get recent routes
     */
    public function getRecent($limit = 10) {
        $sql = "SELECT t.*,
                c.numero_commande,
                cl.nom as client_nom,
                v.immatriculation as vehicule_immat,
                u.nom as chauffeur_nom,
                u.prenom as chauffeur_prenom
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                INNER JOIN users u ON t.chauffeur_id = u.id
                WHERE t.actif = 1
                ORDER BY t.date_creation DESC
                LIMIT ?";
        return $this->db->fetchAll($sql, [$limit]);
    }
    
    /**
     * Get late deliveries
     */
    public function getLateDeliveries() {
        $sql = "SELECT t.*,
                c.numero_commande,
                cl.nom as client_nom,
                v.immatriculation as vehicule_immat
                FROM trajets t
                INNER JOIN commandes c ON t.commande_id = c.id
                INNER JOIN clients cl ON c.client_id = cl.id
                INNER JOIN vehicules v ON t.vehicule_id = v.id
                WHERE t.actif = 1 
                AND t.statut IN ('planifie', 'en_cours')
                AND t.date_arrivee_prevue < NOW()
                ORDER BY t.date_arrivee_prevue";
        return $this->db->fetchAll($sql);
    }
}
?>
