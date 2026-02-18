<?php
namespace App\Models;

use PDO;

class Planification extends BaseModel {
    protected $table = 'planification';
    
    protected $fillable = [
        'type',
        'nom',
        'description',
        'date_debut',
        'date_fin',
        'date_prevue',
        'date_depart',
        'date_retour',
        'budget_estime',
        'budget',
        'total',
        'priorite',
        'statut',
        'article',
        'categorie',
        'quantite',
        'prix_unitaire',
        'destination',
        'employe_nom',
        'employe_id',
        'created_by',
        'updated_by'
    ];
    
    /**
     * Get planification items by type
     */
    public function getByType($type, $limit = 50, $offset = 0) {
        $sql = "SELECT p.*, 
                       u.nom as created_by_nom, u.prenom as created_by_prenom
                FROM {$this->table} p
                LEFT JOIN users u ON p.created_by = u.id
                WHERE p.type = :type
                ORDER BY 
                    CASE 
                        WHEN p.type = 'projet' THEN p.date_debut
                        WHEN p.type = 'achat' THEN p.date_prevue
                        WHEN p.type = 'voyage' THEN p.date_depart
                        ELSE p.created_at
                    END ASC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':type', $type);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get all planification items
     */
    public function getAll($limit = 50, $offset = 0) {
        $sql = "SELECT p.*, 
                       u.nom as created_by_nom, u.prenom as created_by_prenom
                FROM {$this->table} p
                LEFT JOIN users u ON p.created_by = u.id
                ORDER BY p.created_at DESC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get planification items by date range
     */
    public function getByDateRange($dateDebut, $dateFin, $type = null) {
        $sql = "SELECT p.*, 
                       u.nom as created_by_nom, u.prenom as created_by_prenom
                FROM {$this->table} p
                LEFT JOIN users u ON p.created_by = u.id
                WHERE (
                    (p.type = 'projet' AND (p.date_debut BETWEEN :date_debut AND :date_fin OR p.date_fin BETWEEN :date_debut AND :date_fin))
                    OR (p.type = 'achat' AND p.date_prevue BETWEEN :date_debut AND :date_fin)
                    OR (p.type = 'voyage' AND (p.date_depart BETWEEN :date_debut AND :date_fin OR p.date_retour BETWEEN :date_debut AND :date_fin))
                )";
        
        if ($type) {
            $sql .= " AND p.type = :type";
        }
        
        $sql .= " ORDER BY 
                    CASE 
                        WHEN p.type = 'projet' THEN p.date_debut
                        WHEN p.type = 'achat' THEN p.date_prevue
                        WHEN p.type = 'voyage' THEN p.date_depart
                        ELSE p.created_at
                    END ASC";
        
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
     * Get items for export
     */
    public function getForExport($type = null) {
        $sql = "SELECT p.*, 
                       u.nom as created_by_nom, u.prenom as created_by_prenom
                FROM {$this->table} p
                LEFT JOIN users u ON p.created_by = u.id";
        
        if ($type) {
            $sql .= " WHERE p.type = :type";
        }
        
        $sql .= " ORDER BY 
                    CASE 
                        WHEN p.type = 'projet' THEN p.date_debut
                        WHEN p.type = 'achat' THEN p.date_prevue
                        WHEN p.type = 'voyage' THEN p.date_depart
                        ELSE p.created_at
                    END ASC";
        
        $stmt = $this->db->prepare($sql);
        
        if ($type) {
            $stmt->bindParam(':type', $type);
        }
        
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get projects summary
     */
    public function getProjectsSummary() {
        $sql = "SELECT 
                    COUNT(*) as total_projets,
                    SUM(CASE WHEN statut = 'Planifié' THEN 1 ELSE 0 END) as planifies,
                    SUM(CASE WHEN statut = 'En cours' THEN 1 ELSE 0 END) as en_cours,
                    SUM(CASE WHEN statut = 'Terminé' THEN 1 ELSE 0 END) as termines,
                    SUM(budget_estime) as budget_total,
                    AVG(budget_estime) as budget_moyen
                FROM {$this->table}
                WHERE type = 'projet'";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get purchases summary
     */
    public function getPurchasesSummary() {
        $sql = "SELECT 
                    COUNT(*) as total_achats,
                    SUM(total) as montant_total,
                    AVG(total) as montant_moyen,
                    COUNT(DISTINCT categorie) as categories_count
                FROM {$this->table}
                WHERE type = 'achat'";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get travels summary
     */
    public function getTravelsSummary() {
        $sql = "SELECT 
                    COUNT(*) as total_voyages,
                    SUM(budget) as budget_total,
                    AVG(budget) as budget_moyen,
                    SUM(CASE WHEN statut = 'Approuvé' THEN 1 ELSE 0 END) as approuves,
                    SUM(CASE WHEN statut = 'En attente' THEN 1 ELSE 0 END) as en_attente
                FROM {$this->table}
                WHERE type = 'voyage'";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get upcoming items (next 30 days)
     */
    public function getUpcomingItems($days = 30) {
        $sql = "SELECT p.*, 
                       u.nom as created_by_nom, u.prenom as created_by_prenom
                FROM {$this->table} p
                LEFT JOIN users u ON p.created_by = u.id
                WHERE (
                    (p.type = 'projet' AND p.date_debut BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL :days DAY))
                    OR (p.type = 'achat' AND p.date_prevue BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL :days DAY))
                    OR (p.type = 'voyage' AND p.date_depart BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL :days DAY))
                )
                ORDER BY 
                    CASE 
                        WHEN p.type = 'projet' THEN p.date_debut
                        WHEN p.type = 'achat' THEN p.date_prevue
                        WHEN p.type = 'voyage' THEN p.date_depart
                    END ASC";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':days', $days, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get overdue items
     */
    public function getOverdueItems() {
        $sql = "SELECT p.*, 
                       u.nom as created_by_nom, u.prenom as created_by_prenom
                FROM {$this->table} p
                LEFT JOIN users u ON p.created_by = u.id
                WHERE (
                    (p.type = 'projet' AND p.date_fin < CURDATE() AND p.statut != 'Terminé')
                    OR (p.type = 'achat' AND p.date_prevue < CURDATE() AND p.statut != 'Terminé')
                    OR (p.type = 'voyage' AND p.date_retour < CURDATE() AND p.statut != 'Terminé')
                )
                ORDER BY 
                    CASE 
                        WHEN p.type = 'projet' THEN p.date_fin
                        WHEN p.type = 'achat' THEN p.date_prevue
                        WHEN p.type = 'voyage' THEN p.date_retour
                    END ASC";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Update status
     */
    public function updateStatus($id, $status) {
        $sql = "UPDATE {$this->table} 
                SET statut = :status, updated_at = NOW() 
                WHERE id = :id";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':status', $status);
        $stmt->bindParam(':id', $id, PDO::PARAM_INT);
        
        return $stmt->execute();
    }
    
    /**
     * Get budget total by type
     */
    public function getBudgetTotalByType($type) {
        $field = '';
        switch ($type) {
            case 'projet':
                $field = 'budget_estime';
                break;
            case 'achat':
                $field = 'total';
                break;
            case 'voyage':
                $field = 'budget';
                break;
            default:
                return 0;
        }
        
        $sql = "SELECT COALESCE(SUM({$field}), 0) as total 
                FROM {$this->table} 
                WHERE type = :type";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':type', $type);
        $stmt->execute();
        
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result['total'] ?? 0;
    }
}
?>
