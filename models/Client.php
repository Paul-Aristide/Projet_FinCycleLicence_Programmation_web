<?php
namespace App\Models;

class Client {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Get all clients
     */
    public function getAll() {
        $sql = "SELECT c.*, 
                COUNT(cmd.id) as nb_commandes,
                MAX(cmd.date_creation) as derniere_commande
                FROM clients c
                LEFT JOIN commandes cmd ON c.id = cmd.client_id
                WHERE c.actif = 1
                GROUP BY c.id
                ORDER BY c.nom, c.prenom";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Find client by ID
     */
    public function findById($id) {
        $sql = "SELECT * FROM clients WHERE id = ? AND actif = 1";
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Find client by email
     */
    public function findByEmail($email) {
        $sql = "SELECT * FROM clients WHERE email = ? AND actif = 1";
        return $this->db->fetch($sql, [$email]);
    }
    
    /**
     * Create new client
     */
    public function create($data) {
        $sql = "INSERT INTO clients (nom, prenom, entreprise, email, telephone, adresse, ville, code_postal, notes, actif, date_creation) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())";
        
        return $this->db->insert($sql, [
            $data['nom'],
            $data['prenom'] ?? '',
            $data['entreprise'] ?? '',
            $data['email'],
            $data['telephone'],
            $data['adresse'] ?? '',
            $data['ville'] ?? '',
            $data['code_postal'] ?? '',
            $data['notes'] ?? ''
        ]);
    }
    
    /**
     * Update client
     */
    public function update($id, $data) {
        $fields = [];
        $params = [];
        
        $allowedFields = ['nom', 'prenom', 'entreprise', 'email', 'telephone', 'adresse', 'ville', 'code_postal', 'notes'];
        
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
        $sql = "UPDATE clients SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";
        
        return $this->db->execute($sql, $params);
    }
    
    /**
     * Delete client (soft delete)
     */
    public function delete($id) {
        $sql = "UPDATE clients SET actif = 0, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Search clients
     */
    public function search($query) {
        $sql = "SELECT c.*, 
                COUNT(cmd.id) as nb_commandes
                FROM clients c
                LEFT JOIN commandes cmd ON c.id = cmd.client_id
                WHERE c.actif = 1 AND (
                    c.nom LIKE ? OR 
                    c.prenom LIKE ? OR 
                    c.entreprise LIKE ? OR 
                    c.email LIKE ? OR
                    c.telephone LIKE ?
                )
                GROUP BY c.id
                ORDER BY c.nom, c.prenom 
                LIMIT 50";
        
        $searchTerm = "%$query%";
        return $this->db->fetchAll($sql, array_fill(0, 5, $searchTerm));
    }
    
    /**
     * Count total clients
     */
    public function count() {
        $sql = "SELECT COUNT(*) as total FROM clients WHERE actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count active clients (with orders in last 6 months)
     */
    public function countActive() {
        $sql = "SELECT COUNT(DISTINCT c.id) as total 
                FROM clients c
                INNER JOIN commandes cmd ON c.id = cmd.client_id
                WHERE c.actif = 1 AND cmd.date_creation >= DATE_SUB(NOW(), INTERVAL 6 MONTH)";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Count new clients this month
     */
    public function countNewThisMonth() {
        $sql = "SELECT COUNT(*) as total 
                FROM clients 
                WHERE actif = 1 AND MONTH(date_creation) = MONTH(NOW()) AND YEAR(date_creation) = YEAR(NOW())";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Get client statistics
     */
    public function getClientStats($id) {
        $sql = "SELECT 
                COUNT(cmd.id) as total_commandes,
                COUNT(CASE WHEN cmd.statut = 'livree' THEN 1 END) as commandes_livrees,
                SUM(CASE WHEN f.statut = 'payee' THEN f.montant_ttc ELSE 0 END) as ca_realise,
                SUM(CASE WHEN f.statut IN ('brouillon', 'envoyee') THEN f.montant_ttc ELSE 0 END) as ca_en_attente,
                MIN(cmd.date_creation) as premiere_commande,
                MAX(cmd.date_creation) as derniere_commande
                FROM clients c
                LEFT JOIN commandes cmd ON c.id = cmd.client_id
                LEFT JOIN factures f ON cmd.id = f.commande_id
                WHERE c.id = ? AND c.actif = 1";
        
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Get top clients by revenue
     */
    public function getTopClients($limit = 10) {
        $sql = "SELECT c.*, 
                COUNT(cmd.id) as nb_commandes,
                COALESCE(SUM(f.montant_ttc), 0) as ca_total
                FROM clients c
                LEFT JOIN commandes cmd ON c.id = cmd.client_id
                LEFT JOIN factures f ON cmd.id = f.commande_id AND f.statut = 'payee'
                WHERE c.actif = 1
                GROUP BY c.id
                ORDER BY ca_total DESC, nb_commandes DESC
                LIMIT ?";
        
        return $this->db->fetchAll($sql, [$limit]);
    }
    
    /**
     * Get clients with overdue invoices
     */
    public function getClientsWithOverdueInvoices() {
        $sql = "SELECT DISTINCT c.*, 
                COUNT(f.id) as factures_en_retard,
                SUM(f.montant_ttc) as montant_en_retard
                FROM clients c
                INNER JOIN factures f ON c.id = f.client_id
                WHERE c.actif = 1 
                AND f.statut IN ('brouillon', 'envoyee') 
                AND f.date_echeance < CURDATE()
                GROUP BY c.id
                ORDER BY montant_en_retard DESC";
        
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Export clients data
     */
    public function exportData() {
        $sql = "SELECT 
                nom,
                prenom,
                entreprise,
                email,
                telephone,
                adresse,
                ville,
                code_postal,
                date_creation,
                COUNT(cmd.id) as nb_commandes,
                COALESCE(SUM(f.montant_ttc), 0) as ca_total
                FROM clients c
                LEFT JOIN commandes cmd ON c.id = cmd.client_id
                LEFT JOIN factures f ON cmd.id = f.commande_id AND f.statut = 'payee'
                WHERE c.actif = 1
                GROUP BY c.id
                ORDER BY c.nom, c.prenom";
        
        return $this->db->fetchAll($sql);
    }
}
?>
