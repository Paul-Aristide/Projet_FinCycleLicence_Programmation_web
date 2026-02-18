<?php
namespace App\Models;

class Commande {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Get all orders
     */
    public function getAll() {
        $sql = "SELECT c.*, 
                cl.nom as client_nom, 
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                CONCAT(cl.nom, ' ', cl.prenom) as client_nom_complet
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.active = 1
                ORDER BY c.date_creation DESC";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Find order by ID
     */
    public function findById($id) {
        $sql = "SELECT c.*, 
                cl.nom as client_nom, 
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                cl.email as client_email,
                cl.telephone as client_telephone,
                cl.adresse as client_adresse
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.id = ? AND c.active = 1";
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Find order by number
     */
    public function findByNumero($numero) {
        $sql = "SELECT * FROM commandes WHERE numero_commande = ? AND active = 1";
        return $this->db->fetch($sql, [$numero]);
    }
    
    /**
     * Get orders by client ID
     */
    public function getByClientId($clientId) {
        $sql = "SELECT c.* FROM commandes c 
                WHERE c.client_id = ? AND c.active = 1 
                ORDER BY c.date_creation DESC";
        return $this->db->fetchAll($sql, [$clientId]);
    }
    
    /**
     * Get orders by status
     */
    public function getByStatus($status) {
        $sql = "SELECT c.*, 
                cl.nom as client_nom, 
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.statut = ? AND c.active = 1
                ORDER BY c.date_creation DESC";
        return $this->db->fetchAll($sql, [$status]);
    }
    
    /**
     * Get active orders by client (for validation before client deletion)
     */
    public function getActiveOrdersByClient($clientId) {
        $sql = "SELECT id FROM commandes 
                WHERE client_id = ? AND statut IN ('en_attente', 'confirmee', 'en_cours') AND active = 1";
        return $this->db->fetchAll($sql, [$clientId]);
    }
    
    /**
     * Create new order
     */
    public function create($data) {
        $sql = "INSERT INTO commandes (
                    numero_commande, client_id, adresse_depart, adresse_arrivee,
                    date_prevue, heure_prevue, description, poids, volume, prix,
                    statut, notes, workflow_state, poids_kg, distance_km, zone_tarif,
                    cargo_type, tarif_auto, active, date_creation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())";

        return $this->db->insert($sql, [
            $data['numero_commande'],
            $data['client_id'],
            $data['adresse_depart'],
            $data['adresse_arrivee'],
            $data['date_prevue'],
            $data['heure_prevue'],
            $data['description'],
            $data['poids'],
            $data['volume'],
            $data['prix'],
            $data['statut'],
            $data['notes'],
            $data['workflow_state'] ?? 'created',
            $data['poids_kg'] ?? null,
            $data['distance_km'] ?? null,
            $data['zone_tarif'] ?? null,
            $data['cargo_type'] ?? 'standard',
            $data['tarif_auto'] ?? null
        ]);
    }
    
    /**
     * Update order
     */
    public function update($id, $data) {
        $fields = [];
        $params = [];
        
        $allowedFields = [
            'client_id', 'adresse_depart', 'adresse_arrivee', 'date_prevue',
            'heure_prevue', 'description', 'poids', 'volume', 'prix', 'statut', 'notes',
            'workflow_state', 'validated_by', 'validated_at', 'rejection_reason',
            'tarif_auto', 'poids_kg', 'distance_km', 'zone_tarif', 'cargo_type'
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
        $sql = "UPDATE commandes SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";
        
        return $this->db->execute($sql, $params);
    }
    
    /**
     * Update order status
     */
    public function updateStatus($id, $status) {
        $sql = "UPDATE commandes SET statut = ?, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$status, $id]);
    }
    
    /**
     * Delete order (soft delete)
     */
    public function delete($id) {
        $sql = "UPDATE commandes SET active = 0, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Generate unique order number
     */
    public function generateNumeroCommande() {
        $prefix = 'CMD';
        $year = date('Y');
        $month = date('m');
        
        // Get last order number for this month
        $sql = "SELECT numero_commande FROM commandes 
                WHERE numero_commande LIKE ? 
                ORDER BY id DESC LIMIT 1";
        
        $pattern = $prefix . $year . $month . '%';
        $lastOrder = $this->db->fetch($sql, [$pattern]);
        
        if ($lastOrder) {
            $lastNumber = intval(substr($lastOrder['numero_commande'], -4));
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }
        
        return $prefix . $year . $month . str_pad($newNumber, 4, '0', STR_PAD_LEFT);
    }
    
    /**
     * Get order statistics
     */
    public function getStatistics() {
        $sql = "SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN statut = 'en_attente' THEN 1 END) as en_attente,
                COUNT(CASE WHEN statut = 'confirmee' THEN 1 END) as confirmees,
                COUNT(CASE WHEN statut = 'en_cours' THEN 1 END) as en_cours,
                COUNT(CASE WHEN statut = 'livree' THEN 1 END) as livrees,
                COUNT(CASE WHEN statut = 'annulee' THEN 1 END) as annulees,
                AVG(prix) as prix_moyen,
                SUM(prix) as ca_total
                FROM commandes 
                WHERE active = 1";
        
        return $this->db->fetch($sql);
    }
    
    /**
     * Count orders
     */
    public function count() {
        $sql = "SELECT COUNT(*) as total FROM commandes WHERE active = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count orders by status
     */
    public function countByStatus($status) {
        $sql = "SELECT COUNT(*) as total FROM commandes WHERE statut = ? AND active = 1";
        $result = $this->db->fetch($sql, [$status]);
        return $result['total'];
    }
    
    /**
     * Count orders this month
     */
    public function countThisMonth() {
        $sql = "SELECT COUNT(*) as total FROM commandes 
                WHERE active = 1 AND MONTH(date_creation) = MONTH(NOW()) AND YEAR(date_creation) = YEAR(NOW())";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Get recent orders
     */
    public function getRecent($limit = 10) {
        $sql = "SELECT c.*, 
                cl.nom as client_nom, 
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.active = 1
                ORDER BY c.date_creation DESC
                LIMIT ?";
        return $this->db->fetchAll($sql, [$limit]);
    }
    
    /**
     * Get orders by date range
     */
    public function getByDateRange($dateDebut, $dateFin) {
        $sql = "SELECT c.*, 
                cl.nom as client_nom, 
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.active = 1 AND DATE(c.date_creation) BETWEEN ? AND ?
                ORDER BY c.date_creation DESC";
        return $this->db->fetchAll($sql, [$dateDebut, $dateFin]);
    }
    
    /**
     * Get monthly revenue
     */
    public function getMonthlyRevenue() {
        $sql = "SELECT 
                YEAR(date_creation) as annee,
                MONTH(date_creation) as mois,
                COUNT(*) as nb_commandes,
                SUM(prix) as ca
                FROM commandes 
                WHERE active = 1 AND statut = 'livree'
                GROUP BY YEAR(date_creation), MONTH(date_creation)
                ORDER BY annee DESC, mois DESC
                LIMIT 12";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Search orders
     */
    public function search($query) {
        $sql = "SELECT c.*, 
                cl.nom as client_nom, 
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.active = 1 AND (
                    c.numero_commande LIKE ? OR
                    c.description LIKE ? OR
                    c.adresse_depart LIKE ? OR
                    c.adresse_arrivee LIKE ? OR
                    cl.nom LIKE ? OR
                    cl.entreprise LIKE ?
                )
                ORDER BY c.date_creation DESC
                LIMIT 50";
        
        $searchTerm = "%$query%";
        return $this->db->fetchAll($sql, array_fill(0, 6, $searchTerm));
    }

    /**
     * Get orders by workflow state
     */
    public function getByWorkflowState($workflowState) {
        $sql = "SELECT c.*,
                cl.nom as client_nom,
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                cl.email as client_email,
                cl.telephone as client_telephone
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                WHERE c.workflow_state = ? AND c.active = 1
                ORDER BY c.date_creation DESC";
        return $this->db->fetchAll($sql, [$workflowState]);
    }

    /**
     * Get all orders with details (including workflow info)
     */
    public function getAllWithDetails() {
        $sql = "SELECT c.*,
                cl.nom as client_nom,
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                cl.email as client_email,
                cl.telephone as client_telephone,
                CONCAT(cl.nom, ' ', cl.prenom) as client_nom_complet,
                u.nom as validated_by_nom,
                u.prenom as validated_by_prenom
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                LEFT JOIN users u ON c.validated_by = u.id
                WHERE c.active = 1
                ORDER BY c.date_creation DESC";
        return $this->db->fetchAll($sql);
    }

    /**
     * Find order by ID with all details
     */
    public function findByIdWithDetails($id) {
        $sql = "SELECT c.*,
                cl.nom as client_nom,
                cl.prenom as client_prenom,
                cl.entreprise as client_entreprise,
                cl.email as client_email,
                cl.telephone as client_telephone,
                cl.adresse as client_adresse,
                u.nom as validated_by_nom,
                u.prenom as validated_by_prenom
                FROM commandes c
                INNER JOIN clients cl ON c.client_id = cl.id
                LEFT JOIN users u ON c.validated_by = u.id
                WHERE c.id = ? AND c.active = 1";
        return $this->db->fetch($sql, [$id]);
    }

    /**
     * Get orders pending validation (workflow_state = 'created')
     */
    public function getPendingValidation() {
        return $this->getByWorkflowState('created');
    }

    /**
     * Get validated orders (workflow_state = 'validated')
     */
    public function getValidatedOrders() {
        return $this->getByWorkflowState('validated');
    }

    /**
     * Get rejected orders (workflow_state = 'rejected')
     */
    public function getRejectedOrders() {
        return $this->getByWorkflowState('rejected');
    }

    /**
     * Update workflow state
     */
    public function updateWorkflowState($id, $state, $userId = null, $reason = null) {
        $fields = ['workflow_state = ?'];
        $params = [$state];

        if ($userId) {
            $fields[] = 'validated_by = ?';
            $params[] = $userId;
            $fields[] = 'validated_at = NOW()';
        }

        if ($reason) {
            $fields[] = 'rejection_reason = ?';
            $params[] = $reason;
        }

        $params[] = $id;
        $sql = "UPDATE commandes SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";

        return $this->db->execute($sql, $params);
    }

    /**
     * Get workflow statistics
     */
    public function getWorkflowStatistics() {
        $sql = "SELECT
                COUNT(*) as total,
                COUNT(CASE WHEN workflow_state = 'created' THEN 1 END) as created,
                COUNT(CASE WHEN workflow_state = 'validated' THEN 1 END) as validated,
                COUNT(CASE WHEN workflow_state = 'rejected' THEN 1 END) as rejected,
                COUNT(CASE WHEN workflow_state = 'planned' THEN 1 END) as planned,
                COUNT(CASE WHEN workflow_state = 'in_transit' THEN 1 END) as in_transit,
                COUNT(CASE WHEN workflow_state = 'delivered' THEN 1 END) as delivered,
                COUNT(CASE WHEN workflow_state = 'cancelled' THEN 1 END) as cancelled
                FROM commandes
                WHERE active = 1";

        return $this->db->fetch($sql);
    }
}
?>
