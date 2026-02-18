<?php
namespace App\Models;

class Vehicule {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Get all vehicles
     */
    public function getAll() {
        $sql = "SELECT v.*,
                COUNT(t.id) as nb_trajets_total,
                COUNT(CASE WHEN t.statut = 'en_cours' THEN 1 END) as nb_trajets_en_cours
                FROM vehicules v
                LEFT JOIN trajets t ON v.id = t.vehicule_id
                WHERE v.actif = 1
                GROUP BY v.id
                ORDER BY v.immatriculation";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Find vehicle by ID
     */
    public function findById($id) {
        $sql = "SELECT * FROM vehicules WHERE id = ? AND actif = 1";
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Find vehicle by license plate
     */
    public function findByImmatriculation($immatriculation) {
        $sql = "SELECT * FROM vehicules WHERE immatriculation = ? AND actif = 1";
        return $this->db->fetch($sql, [$immatriculation]);
    }
    
    /**
     * Get vehicles by availability
     */
    public function getByDisponibilite($disponible) {
        $sql = "SELECT * FROM vehicules WHERE disponible = ? AND actif = 1 ORDER BY immatriculation";
        return $this->db->fetchAll($sql, [$disponible ? 1 : 0]);
    }
    
    /**
     * Create new vehicle
     */
    public function create($data) {
        $sql = "INSERT INTO vehicules (
                    immatriculation, marque, modele, annee, type, 
                    capacite_poids, capacite_volume, consommation, 
                    statut, disponible, notes, actif, date_creation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())";
        
        return $this->db->insert($sql, [
            $data['immatriculation'],
            $data['marque'],
            $data['modele'],
            $data['annee'],
            $data['type'],
            $data['capacite_poids'],
            $data['capacite_volume'],
            $data['consommation'],
            $data['statut'],
            $data['disponible'],
            $data['notes']
        ]);
    }
    
    /**
     * Update vehicle
     */
    public function update($id, $data) {
        $fields = [];
        $params = [];
        
        $allowedFields = [
            'immatriculation', 'marque', 'modele', 'annee', 'type',
            'capacite_poids', 'capacite_volume', 'consommation', 'statut', 'notes'
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
        $sql = "UPDATE vehicules SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";
        
        return $this->db->execute($sql, $params);
    }
    
    /**
     * Update vehicle availability
     */
    public function updateDisponibilite($id, $disponible) {
        $sql = "UPDATE vehicules SET disponible = ?, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$disponible ? 1 : 0, $id]);
    }
    
    /**
     * Delete vehicle (soft delete)
     */
    public function delete($id) {
        $sql = "UPDATE vehicules SET actif = 0, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Count vehicles
     */
    public function count() {
        $sql = "SELECT COUNT(*) as total FROM vehicules WHERE actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count available vehicles
     */
    public function countAvailable() {
        $sql = "SELECT COUNT(*) as total FROM vehicules WHERE disponible = 1 AND actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count vehicles in use
     */
    public function countInUse() {
        $sql = "SELECT COUNT(*) as total FROM vehicules WHERE disponible = 0 AND actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count vehicles in maintenance
     */
    public function countInMaintenance() {
        $sql = "SELECT COUNT(*) as total FROM vehicules WHERE statut = 'maintenance' AND actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Get vehicle statistics
     */
    public function getStatistics() {
        $sql = "SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN disponible = 1 THEN 1 END) as disponibles,
                COUNT(CASE WHEN disponible = 0 THEN 1 END) as en_mission,
                COUNT(CASE WHEN statut = 'maintenance' THEN 1 END) as maintenance,
                COUNT(CASE WHEN type = 'camion' THEN 1 END) as camions,
                COUNT(CASE WHEN type = 'camionnette' THEN 1 END) as camionnettes,
                COUNT(CASE WHEN type = 'fourgon' THEN 1 END) as fourgons,
                AVG(capacite_poids) as capacite_moyenne,
                AVG(consommation) as consommation_moyenne
                FROM vehicules 
                WHERE actif = 1";
        
        return $this->db->fetch($sql);
    }
    
    /**
     * Get maintenance history for a vehicle
     */
    public function getMaintenanceHistory($vehiculeId) {
        $sql = "SELECT * FROM maintenances 
                WHERE vehicule_id = ? 
                ORDER BY date_maintenance DESC";
        return $this->db->fetchAll($sql, [$vehiculeId]);
    }
    
    /**
     * Add maintenance record
     */
    public function addMaintenance($vehiculeId, $data) {
        $sql = "INSERT INTO maintenances (
                    vehicule_id, date_maintenance, type_maintenance, 
                    description, cout, garage, date_creation
                ) VALUES (?, ?, ?, ?, ?, ?, NOW())";
        
        return $this->db->insert($sql, [
            $vehiculeId,
            $data['date_maintenance'],
            $data['type_maintenance'],
            $data['description'],
            $data['cout'],
            $data['garage']
        ]);
    }
    
    /**
     * Get vehicles needing maintenance
     */
    public function getMaintenanceAlerts() {
        // This is a simplified version - in real world, you'd have more complex logic
        // based on kilometers, dates, etc.
        $sql = "SELECT v.* FROM vehicules v
                LEFT JOIN maintenances m ON v.id = m.vehicule_id
                WHERE v.actif = 1 
                AND (
                    m.date_maintenance IS NULL 
                    OR m.date_maintenance < DATE_SUB(NOW(), INTERVAL 6 MONTH)
                )
                GROUP BY v.id
                ORDER BY COALESCE(MAX(m.date_maintenance), v.date_creation) ASC";
        
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Get vehicle utilization report
     */
    public function getUtilizationReport($dateDebut, $dateFin) {
        $sql = "SELECT v.*,
                COUNT(t.id) as nb_trajets,
                SUM(t.distance_km) as km_total,
                AVG(t.distance_km) as km_moyen,
                COUNT(CASE WHEN t.statut = 'termine' THEN 1 END) as trajets_termines
                FROM vehicules v
                LEFT JOIN trajets t ON v.id = t.vehicule_id 
                    AND DATE(t.date_depart) BETWEEN ? AND ?
                WHERE v.actif = 1
                GROUP BY v.id
                ORDER BY nb_trajets DESC, km_total DESC";
        
        return $this->db->fetchAll($sql, [$dateDebut, $dateFin]);
    }
    
    /**
     * Search vehicles
     */
    public function search($query) {
        $sql = "SELECT * FROM vehicules 
                WHERE actif = 1 AND (
                    immatriculation LIKE ? OR
                    marque LIKE ? OR
                    modele LIKE ? OR
                    type LIKE ?
                )
                ORDER BY immatriculation
                LIMIT 20";
        
        $searchTerm = "%$query%";
        return $this->db->fetchAll($sql, array_fill(0, 4, $searchTerm));
    }
}
?>
