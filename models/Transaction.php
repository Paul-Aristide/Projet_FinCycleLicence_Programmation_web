<?php
namespace App\Models;

use PDO;

class Transaction extends BaseModel {
    protected $table = 'transactions';

    protected $fillable = [
        'type',
        'reference',
        'date_transaction',
        'montant',
        'description',
        'statut',
        'client_id',
        'facture_id',
        'vehicule_id',
        'employe_id',
        'mode_paiement',
        'quantite',
        'prix_unitaire',
        'categorie',
        'periode',
        'type_maintenance',
        'actif'
    ];

    /**
     * Override create method to handle date field mapping
     */
    public function create($data) {
        // Map 'date' to 'date_transaction' for compatibility
        if (isset($data['date'])) {
            $data['date_transaction'] = $data['date'];
            unset($data['date']);
        }

        // Set default values
        $data['actif'] = 1;
        $data['statut'] = $data['statut'] ?? 'valide';

        // Filter data to only include fillable fields
        $filteredData = array_intersect_key($data, array_flip($this->fillable));

        // Add timestamps using the existing table structure
        $filteredData['date_creation'] = date('Y-m-d H:i:s');
        $filteredData['date_modification'] = date('Y-m-d H:i:s');

        $fields = array_keys($filteredData);
        $placeholders = ':' . implode(', :', $fields);

        $sql = "INSERT INTO {$this->table} (" . implode(', ', $fields) . ") VALUES (" . $placeholders . ")";

        $stmt = $this->db->prepare($sql);

        foreach ($filteredData as $field => $value) {
            $stmt->bindValue(':' . $field, $value);
        }

        if ($stmt->execute()) {
            return $this->db->lastInsertId();
        }

        return false;
    }
    
    /**
     * Get transactions by type
     */
    public function getByType($type, $limit = 50, $offset = 0) {
        $sql = "SELECT t.*,
                       c.nom as client_nom, c.prenom as client_prenom,
                       f.numero_facture,
                       v.immatriculation as vehicule_immatriculation,
                       u.nom as employe_nom, u.prenom as employe_prenom
                FROM {$this->table} t
                LEFT JOIN clients c ON t.client_id = c.id
                LEFT JOIN factures f ON t.facture_id = f.id
                LEFT JOIN vehicules v ON t.vehicule_id = v.id
                LEFT JOIN users u ON t.employe_id = u.id
                WHERE t.type = :type AND t.actif = 1
                ORDER BY t.date_transaction DESC, t.date_creation DESC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':type', $type);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get all transactions with related data
     */
    public function getAll($limit = 50, $offset = 0) {
        $sql = "SELECT t.*,
                       c.nom as client_nom, c.prenom as client_prenom,
                       f.numero_facture,
                       v.immatriculation as vehicule_immatriculation,
                       u.nom as employe_nom, u.prenom as employe_prenom
                FROM {$this->table} t
                LEFT JOIN clients c ON t.client_id = c.id
                LEFT JOIN factures f ON t.facture_id = f.id
                LEFT JOIN vehicules v ON t.vehicule_id = v.id
                LEFT JOIN users u ON t.employe_id = u.id
                WHERE t.actif = 1
                ORDER BY t.date_transaction DESC, t.date_creation DESC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get total amount by type
     */
    public function getTotalByType($type) {
        $sql = "SELECT COALESCE(SUM(montant), 0) as total 
                FROM {$this->table} 
                WHERE type = :type";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':type', $type);
        $stmt->execute();
        
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result['total'] ?? 0;
    }
    
    /**
     * Get count of transactions this month by type
     */
    public function getCountThisMonth($type) {
        $sql = "SELECT COUNT(*) as count
                FROM {$this->table}
                WHERE type = :type
                AND actif = 1
                AND YEAR(date_transaction) = YEAR(CURDATE())
                AND MONTH(date_transaction) = MONTH(CURDATE())";

        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':type', $type);
        $stmt->execute();

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result['count'] ?? 0;
    }
    
    /**
     * Get transactions by date range
     */
    public function getByDateRange($dateDebut, $dateFin, $type = null) {
        $sql = "SELECT t.*, 
                       c.nom as client_nom, c.prenom as client_prenom,
                       f.numero_facture,
                       v.immatriculation as vehicule_immatriculation,
                       u.nom as employe_nom, u.prenom as employe_prenom
                FROM {$this->table} t
                LEFT JOIN clients c ON t.client_id = c.id
                LEFT JOIN factures f ON t.facture_id = f.id
                LEFT JOIN vehicules v ON t.vehicule_id = v.id
                LEFT JOIN users u ON t.employe_id = u.id
                WHERE t.date BETWEEN :date_debut AND :date_fin";
        
        if ($type) {
            $sql .= " AND t.type = :type";
        }
        
        $sql .= " ORDER BY t.date DESC";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':date_debut', $dateDebut);
        $stmt->bindParam(':date_fin', $dateFin);
        
        if ($type) {
            $stmt->bindParam(':type', $type);
        }
        
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get transactions for export
     */
    public function getForExport($type = null, $dateDebut = null, $dateFin = null) {
        $sql = "SELECT t.*, 
                       c.nom as client_nom, c.prenom as client_prenom,
                       f.numero_facture,
                       v.immatriculation as vehicule_immatriculation,
                       u.nom as employe_nom, u.prenom as employe_prenom
                FROM {$this->table} t
                LEFT JOIN clients c ON t.client_id = c.id
                LEFT JOIN factures f ON t.facture_id = f.id
                LEFT JOIN vehicules v ON t.vehicule_id = v.id
                LEFT JOIN users u ON t.employe_id = u.id
                WHERE 1=1";
        
        $params = [];
        
        if ($type) {
            $sql .= " AND t.type = :type";
            $params[':type'] = $type;
        }
        
        if ($dateDebut && $dateFin) {
            $sql .= " AND t.date BETWEEN :date_debut AND :date_fin";
            $params[':date_debut'] = $dateDebut;
            $params[':date_fin'] = $dateFin;
        }
        
        $sql .= " ORDER BY t.date DESC";
        
        $stmt = $this->db->prepare($sql);
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get monthly summary
     */
    public function getMonthlySummary($year, $month) {
        $sql = "SELECT 
                    type,
                    COUNT(*) as count,
                    SUM(montant) as total,
                    AVG(montant) as moyenne
                FROM {$this->table}
                WHERE YEAR(date) = :year AND MONTH(date) = :month
                GROUP BY type
                ORDER BY total DESC";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':year', $year, PDO::PARAM_INT);
        $stmt->bindParam(':month', $month, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Create payment transaction from invoice
     */
    public function createPaymentFromInvoice($factureId, $montant, $modePaiement = 'Non spécifié') {
        $data = [
            'type' => 'paiement',
            'reference' => $this->generatePaymentReference(),
            'date' => date('Y-m-d'),
            'montant' => $montant,
            'description' => 'Paiement de facture',
            'facture_id' => $factureId,
            'mode_paiement' => $modePaiement,
            'statut' => 'Terminé'
        ];
        
        return $this->create($data);
    }
    
    /**
     * Generate payment reference
     */
    private function generatePaymentReference() {
        $year = date('Y');
        $timestamp = time();
        return 'PAY-' . $year . '-' . substr($timestamp, -6);
    }
    
    /**
     * Get recent activities for dashboard
     */
    public function getRecentActivities($limit = 10) {
        $sql = "SELECT 
                    t.id,
                    t.reference as title,
                    CONCAT(t.type, ' - ', t.description) as description,
                    t.date,
                    'termine' as status
                FROM {$this->table} t
                ORDER BY t.date DESC, t.created_at DESC
                LIMIT :limit";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
