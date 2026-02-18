<?php
namespace App\Models;

class Facture {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Get all invoices
     */
    public function getAll() {
        $sql = "SELECT f.*, 
                c.nom as client_nom, 
                c.prenom as client_prenom,
                c.entreprise as client_entreprise,
                cmd.numero_commande
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                LEFT JOIN commandes cmd ON f.commande_id = cmd.id
                WHERE f.actif = 1
                ORDER BY f.date_creation DESC";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Find invoice by ID
     */
    public function findById($id) {
        $sql = "SELECT f.*, 
                c.nom as client_nom, 
                c.prenom as client_prenom,
                c.entreprise as client_entreprise,
                c.email as client_email,
                c.telephone as client_telephone,
                c.adresse as client_adresse,
                c.ville as client_ville,
                c.code_postal as client_code_postal,
                cmd.numero_commande,
                cmd.description as commande_description
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                LEFT JOIN commandes cmd ON f.commande_id = cmd.id
                WHERE f.id = ? AND f.actif = 1";
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Get invoices by status
     */
    public function getByStatut($statut) {
        $sql = "SELECT f.*, 
                c.nom as client_nom, 
                c.prenom as client_prenom,
                c.entreprise as client_entreprise
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                WHERE f.statut = ? AND f.actif = 1
                ORDER BY f.date_creation DESC";
        return $this->db->fetchAll($sql, [$statut]);
    }
    
    /**
     * Get invoices by client ID
     */
    public function getByClientId($clientId) {
        $sql = "SELECT f.* FROM factures f 
                WHERE f.client_id = ? AND f.actif = 1 
                ORDER BY f.date_creation DESC";
        return $this->db->fetchAll($sql, [$clientId]);
    }
    
    /**
     * Create new invoice
     */
    public function create($data) {
        $sql = "INSERT INTO factures (
                    numero_facture, client_id, commande_id, date_facture, date_echeance,
                    montant_ht, taux_tva, montant_tva, montant_ttc, statut, 
                    description, notes, actif, date_creation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())";
        
        return $this->db->insert($sql, [
            $data['numero_facture'],
            $data['client_id'],
            $data['commande_id'],
            $data['date_facture'],
            $data['date_echeance'],
            $data['montant_ht'],
            $data['taux_tva'],
            $data['montant_tva'],
            $data['montant_ttc'],
            $data['statut'],
            $data['description'],
            $data['notes']
        ]);
    }
    
    /**
     * Update invoice
     */
    public function update($id, $data) {
        $fields = [];
        $params = [];
        
        $allowedFields = [
            'client_id', 'commande_id', 'date_facture', 'date_echeance',
            'montant_ht', 'taux_tva', 'montant_tva', 'montant_ttc', 
            'statut', 'description', 'notes', 'date_paiement'
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
        $sql = "UPDATE factures SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";
        
        return $this->db->execute($sql, $params);
    }
    
    /**
     * Update invoice status
     */
    public function updateStatut($id, $statut) {
        $sql = "UPDATE factures SET statut = ?, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$statut, $id]);
    }
    
    /**
     * Delete invoice (soft delete)
     */
    public function delete($id) {
        $sql = "UPDATE factures SET actif = 0, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Generate unique invoice number
     */
    public function generateNumeroFacture() {
        $prefix = 'FACT';
        $year = date('Y');
        $month = date('m');
        
        // Get last invoice number for this month
        $sql = "SELECT numero_facture FROM factures 
                WHERE numero_facture LIKE ? 
                ORDER BY id DESC LIMIT 1";
        
        $pattern = $prefix . $year . $month . '%';
        $lastInvoice = $this->db->fetch($sql, [$pattern]);
        
        if ($lastInvoice) {
            $lastNumber = intval(substr($lastInvoice['numero_facture'], -4));
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }
        
        return $prefix . $year . $month . str_pad($newNumber, 4, '0', STR_PAD_LEFT);
    }
    
    /**
     * Get invoice statistics
     */
    public function getStatistics() {
        $sql = "SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN statut = 'brouillon' THEN 1 END) as brouillons,
                COUNT(CASE WHEN statut = 'envoyee' THEN 1 END) as envoyees,
                COUNT(CASE WHEN statut = 'payee' THEN 1 END) as payees,
                COUNT(CASE WHEN statut = 'annulee' THEN 1 END) as annulees,
                SUM(CASE WHEN statut = 'payee' THEN montant_ttc ELSE 0 END) as ca_realise,
                SUM(CASE WHEN statut IN ('brouillon', 'envoyee') THEN montant_ttc ELSE 0 END) as ca_en_attente,
                AVG(montant_ttc) as montant_moyen
                FROM factures 
                WHERE actif = 1";
        
        return $this->db->fetch($sql);
    }
    
    /**
     * Count invoices
     */
    public function count() {
        $sql = "SELECT COUNT(*) as total FROM factures WHERE actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count invoices by status
     */
    public function countByStatus($status) {
        $sql = "SELECT COUNT(*) as total FROM factures WHERE statut = ? AND actif = 1";
        $result = $this->db->fetch($sql, [$status]);
        return $result['total'];
    }
    
    /**
     * Count overdue invoices
     */
    public function countOverdue() {
        $sql = "SELECT COUNT(*) as total FROM factures 
                WHERE actif = 1 AND statut IN ('brouillon', 'envoyee') AND date_echeance < CURDATE()";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Get overdue invoices
     */
    public function getOverdue() {
        $sql = "SELECT f.*, 
                c.nom as client_nom, 
                c.prenom as client_prenom,
                c.entreprise as client_entreprise
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                WHERE f.actif = 1 
                AND f.statut IN ('brouillon', 'envoyee') 
                AND f.date_echeance < CURDATE()
                ORDER BY f.date_echeance ASC";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Get monthly revenue
     */
    public function getMonthlyRevenue() {
        $sql = "SELECT COALESCE(SUM(montant_ttc), 0) as total FROM factures 
                WHERE actif = 1 AND statut = 'payee' 
                AND MONTH(date_facture) = MONTH(NOW()) AND YEAR(date_facture) = YEAR(NOW())";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Get yearly revenue
     */
    public function getYearlyRevenue() {
        $sql = "SELECT COALESCE(SUM(montant_ttc), 0) as total FROM factures 
                WHERE actif = 1 AND statut = 'payee' AND YEAR(date_facture) = YEAR(NOW())";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Get pending amount
     */
    public function getPendingAmount() {
        $sql = "SELECT COALESCE(SUM(montant_ttc), 0) as total FROM factures
                WHERE actif = 1 AND statut IN ('brouillon', 'envoyee')";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }

    /**
     * Get unpaid invoices (for budget calculation)
     */
    public function getUnpaidInvoices() {
        $sql = "SELECT f.*,
                c.nom as client_nom,
                c.prenom as client_prenom,
                c.entreprise as client_entreprise
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                WHERE f.actif = 1 AND f.statut IN ('brouillon', 'envoyee')
                ORDER BY f.date_echeance ASC";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Get growth rate
     */
    public function getGrowthRate() {
        $currentMonth = "SELECT COALESCE(SUM(montant_ttc), 0) FROM factures 
                        WHERE actif = 1 AND statut = 'payee' 
                        AND MONTH(date_facture) = MONTH(NOW()) AND YEAR(date_facture) = YEAR(NOW())";
        
        $previousMonth = "SELECT COALESCE(SUM(montant_ttc), 0) FROM factures 
                         WHERE actif = 1 AND statut = 'payee' 
                         AND MONTH(date_facture) = MONTH(DATE_SUB(NOW(), INTERVAL 1 MONTH)) 
                         AND YEAR(date_facture) = YEAR(DATE_SUB(NOW(), INTERVAL 1 MONTH))";
        
        $current = $this->db->fetch($currentMonth)['COALESCE(SUM(montant_ttc), 0)'];
        $previous = $this->db->fetch($previousMonth)['COALESCE(SUM(montant_ttc), 0)'];
        
        if ($previous == 0) return 0;
        return (($current - $previous) / $previous) * 100;
    }
    
    /**
     * Get recent invoices
     */
    public function getRecent($limit = 10) {
        $sql = "SELECT f.*, 
                c.nom as client_nom, 
                c.prenom as client_prenom,
                c.entreprise as client_entreprise
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                WHERE f.actif = 1
                ORDER BY f.date_creation DESC
                LIMIT ?";
        return $this->db->fetchAll($sql, [$limit]);
    }
    
    /**
     * Get invoices for export
     */
    public function getForExport($dateDebut, $dateFin) {
        $sql = "SELECT f.*, 
                c.nom as client_nom, 
                c.prenom as client_prenom,
                c.entreprise as client_entreprise
                FROM factures f
                INNER JOIN clients c ON f.client_id = c.id
                WHERE f.actif = 1 AND DATE(f.date_facture) BETWEEN ? AND ?
                ORDER BY f.date_facture";
        return $this->db->fetchAll($sql, [$dateDebut, $dateFin]);
    }
}
?>
