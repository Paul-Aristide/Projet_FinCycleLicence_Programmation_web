<?php
namespace App\Models;

use App\Models\Database;
use PDO;

/**
 * Base Model class providing common functionality for all models
 */
abstract class BaseModel {
    protected $db;
    protected $table;
    protected $fillable = [];
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Find a record by ID
     */
    public function findById($id) {
        $sql = "SELECT * FROM {$this->table} WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':id', $id, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Get all records
     */
    public function getAll($limit = 50, $offset = 0) {
        $sql = "SELECT * FROM {$this->table} ORDER BY created_at DESC LIMIT :limit OFFSET :offset";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    /**
     * Create a new record
     */
    public function create($data) {
        // Filter data to only include fillable fields
        $filteredData = array_intersect_key($data, array_flip($this->fillable));
        
        // Add timestamps
        $filteredData['created_at'] = date('Y-m-d H:i:s');
        $filteredData['updated_at'] = date('Y-m-d H:i:s');
        
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
     * Update a record
     */
    public function update($id, $data) {
        // Filter data to only include fillable fields
        $filteredData = array_intersect_key($data, array_flip($this->fillable));
        
        // Add updated timestamp
        $filteredData['updated_at'] = date('Y-m-d H:i:s');
        
        $fields = array_keys($filteredData);
        $setParts = [];
        foreach ($fields as $field) {
            $setParts[] = "$field = :$field";
        }
        $setClause = implode(', ', $setParts);
        
        $sql = "UPDATE {$this->table} SET " . $setClause . " WHERE id = :id";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':id', $id, PDO::PARAM_INT);
        
        foreach ($filteredData as $field => $value) {
            $stmt->bindValue(':' . $field, $value);
        }
        
        return $stmt->execute();
    }
    
    /**
     * Delete a record
     */
    public function delete($id) {
        $sql = "DELETE FROM {$this->table} WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':id', $id, PDO::PARAM_INT);
        
        return $stmt->execute();
    }
    
    /**
     * Soft delete a record (if the table has a 'deleted_at' or 'actif' field)
     */
    public function softDelete($id) {
        // Check if table has 'actif' field (common in this project)
        $sql = "UPDATE {$this->table} SET actif = 0, updated_at = NOW() WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':id', $id, PDO::PARAM_INT);
        
        return $stmt->execute();
    }
    
    /**
     * Count total records
     */
    public function count($conditions = []) {
        $sql = "SELECT COUNT(*) as total FROM {$this->table}";
        
        if (!empty($conditions)) {
            $whereClause = [];
            foreach ($conditions as $field => $value) {
                $whereClause[] = "$field = :$field";
            }
            $sql .= " WHERE " . implode(' AND ', $whereClause);
        }
        
        $stmt = $this->db->prepare($sql);
        
        foreach ($conditions as $field => $value) {
            $stmt->bindValue(':' . $field, $value);
        }
        
        $stmt->execute();
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $result['total'] ?? 0;
    }
    
    /**
     * Generate a unique reference number
     */
    protected function generateReference($prefix, $length = 6) {
        $year = date('Y');
        
        // Get the last reference for this prefix and year
        $sql = "SELECT reference FROM {$this->table} 
                WHERE reference LIKE :pattern 
                ORDER BY reference DESC 
                LIMIT 1";
        
        $pattern = $prefix . '-' . $year . '-%';
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':pattern', $pattern);
        $stmt->execute();
        
        $lastRef = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($lastRef) {
            // Extract the number from the last reference
            $parts = explode('-', $lastRef['reference']);
            $lastNumber = intval(end($parts));
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }
        
        return $prefix . '-' . $year . '-' . str_pad($newNumber, $length, '0', STR_PAD_LEFT);
    }
    
    /**
     * Sanitize input data
     */
    protected function sanitizeInput($data) {
        if (is_array($data)) {
            return array_map([$this, 'sanitizeInput'], $data);
        }
        
        return htmlspecialchars(strip_tags(trim($data)), ENT_QUOTES, 'UTF-8');
    }
    
    /**
     * Validate required fields
     */
    protected function validateRequired($data, $requiredFields) {
        $missing = [];
        
        foreach ($requiredFields as $field) {
            if (!isset($data[$field]) || empty($data[$field])) {
                $missing[] = $field;
            }
        }
        
        if (!empty($missing)) {
            throw new \InvalidArgumentException('Champs requis manquants: ' . implode(', ', $missing));
        }
        
        return true;
    }
}
