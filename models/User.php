<?php
namespace App\Models;

class User {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Find user by email
     */
    public function findByEmail($email) {
        $sql = "SELECT * FROM users WHERE email = ? AND actif = 1";
        return $this->db->fetch($sql, [$email]);
    }
    
    /**
     * Find user by ID
     */
    public function findById($id) {
        $sql = "SELECT * FROM users WHERE id = ? AND actif = 1";
        return $this->db->fetch($sql, [$id]);
    }
    
    /**
     * Create new user
     */
    public function create($data) {
        $sql = "INSERT INTO users (nom, prenom, email, password, role, salaire, telephone, actif, date_creation)
                VALUES (?, ?, ?, ?, ?, ?, ?, 1, NOW())";

        return $this->db->insert($sql, [
            $data['nom'],
            $data['prenom'],
            $data['email'],
            $data['password'],
            $data['role'],
            $data['salaire'] ?? 0.00,
            $data['telephone'] ?? null
        ]);
    }
    
    /**
     * Update user
     */
    public function update($id, $data) {
        $fields = [];
        $params = [];

        foreach ($data as $key => $value) {
            if (in_array($key, ['nom', 'prenom', 'email', 'telephone', 'role', 'salaire'])) {
                $fields[] = "$key = ?";
                $params[] = $value;
            }
        }

        if (empty($fields)) {
            return false;
        }

        $params[] = $id;
        $sql = "UPDATE users SET " . implode(', ', $fields) . ", date_modification = NOW() WHERE id = ?";

        return $this->db->execute($sql, $params);
    }
    
    /**
     * Update password
     */
    public function updatePassword($id, $hashedPassword) {
        $sql = "UPDATE users SET password = ?, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$hashedPassword, $id]);
    }
    
    /**
     * Update last login
     */
    public function updateLastLogin($id) {
        $sql = "UPDATE users SET derniere_connexion = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Get all users
     */
    public function getAll() {
        $sql = "SELECT id, nom, prenom, email, role, salaire, telephone, actif, date_creation, derniere_connexion
                FROM users WHERE actif = 1 ORDER BY nom, prenom";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Get users by role
     */
    public function getByRole($role) {
        $sql = "SELECT id, nom, prenom, email, salaire, telephone, date_creation, derniere_connexion
                FROM users WHERE role = ? AND actif = 1 ORDER BY nom, prenom";
        return $this->db->fetchAll($sql, [$role]);
    }
    
    /**
     * Get drivers (chauffeurs)
     */
    public function getDrivers() {
        return $this->getByRole('chauffeur');
    }
    
    /**
     * Deactivate user (soft delete)
     */
    public function deactivate($id) {
        $sql = "UPDATE users SET actif = 0, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Activate user
     */
    public function activate($id) {
        $sql = "UPDATE users SET actif = 1, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$id]);
    }
    
    /**
     * Count total users
     */
    public function count() {
        $sql = "SELECT COUNT(*) as total FROM users WHERE actif = 1";
        $result = $this->db->fetch($sql);
        return $result['total'];
    }
    
    /**
     * Search users
     */
    public function search($query) {
        $sql = "SELECT id, nom, prenom, email, role, salaire, telephone
                FROM users
                WHERE actif = 1 AND (
                    nom LIKE ? OR
                    prenom LIKE ? OR
                    email LIKE ?
                )
                ORDER BY nom, prenom
                LIMIT 20";

        $searchTerm = "%$query%";
        return $this->db->fetchAll($sql, [$searchTerm, $searchTerm, $searchTerm]);
    }

    /**
     * Update user salary
     */
    public function updateSalary($id, $salaire) {
        $sql = "UPDATE users SET salaire = ?, date_modification = NOW() WHERE id = ?";
        return $this->db->execute($sql, [$salaire, $id]);
    }

    /**
     * Get users statistics
     */
    public function getStatistics() {
        $sql = "SELECT
                    role,
                    COUNT(*) as count,
                    AVG(salaire) as salaire_moyen,
                    SUM(salaire) as masse_salariale
                FROM users
                WHERE actif = 1
                GROUP BY role";
        return $this->db->fetchAll($sql);
    }
    
    /**
     * Check if email exists
     */
    public function emailExists($email, $excludeId = null) {
        $sql = "SELECT id FROM users WHERE email = ? AND actif = 1";
        $params = [$email];
        
        if ($excludeId) {
            $sql .= " AND id != ?";
            $params[] = $excludeId;
        }
        
        $result = $this->db->fetch($sql, $params);
        return !empty($result);
    }
    
    /**
     * Get user permissions based on role
     */
    public function getPermissions($role) {
        $permissions = [
            'admin' => [
                'clients' => ['read', 'write', 'delete'],
                'commandes' => ['read', 'write', 'delete'],
                'vehicules' => ['read', 'write', 'delete'],
                'trajets' => ['read', 'write', 'delete'],
                'factures' => ['read', 'write', 'delete'],
                'users' => ['read', 'write', 'delete'],
                'dashboard' => ['read']
            ],
            'commercial' => [
                'clients' => ['read', 'write', 'delete'],
                'commandes' => ['read', 'write', 'delete'],
                'vehicules' => ['read', 'write', 'delete'],
                'dashboard' => ['read']
            ],
            'comptabilite' => [
                'clients' => ['read', 'write', 'delete'],
                'commandes' => ['read', 'write', 'delete'],
                'factures' => ['read', 'write', 'delete'],
                'transactions' => ['read', 'write', 'delete'],
                'planification' => ['read', 'write', 'delete'],
                'dashboard' => ['read']
            ],
            'chauffeur' => [
                'clients' => ['read', 'write', 'delete'],
                'vehicules' => ['read', 'write', 'delete'],
                'trajets' => ['read', 'write', 'delete'],
                'dashboard' => ['read']
            ]
        ];
        
        return $permissions[$role] ?? [];
    }
}
