<?php
namespace App\Utils;

class Auth {
    
    /**
     * Generate JWT token
     */
    public static function generateToken($user) {
        $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
        
        $payload = json_encode([
            'user_id' => $user['id'],
            'email' => $user['email'],
            'role' => $user['role'],
            'iat' => time(),
            'exp' => time() + SESSION_LIFETIME
        ]);
        
        $base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
        $base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
        
        $signature = hash_hmac('sha256', $base64Header . "." . $base64Payload, JWT_SECRET, true);
        $base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
        
        return $base64Header . "." . $base64Payload . "." . $base64Signature;
    }
    
    /**
     * Verify JWT token
     */
    public static function verifyToken($token) {
        if (!$token) {
            return false;
        }
        
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return false;
        }
        
        list($header, $payload, $signature) = $parts;
        
        // Verify signature
        $validSignature = hash_hmac('sha256', $header . "." . $payload, JWT_SECRET, true);
        $validBase64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($validSignature));
        
        if (!hash_equals($signature, $validBase64Signature)) {
            return false;
        }
        
        // Decode payload
        $decodedPayload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $payload)), true);
        
        // Check expiration
        if ($decodedPayload['exp'] < time()) {
            return false;
        }
        
        return $decodedPayload;
    }
    
    /**
     * Get token from request headers
     */
    public static function getTokenFromRequest() {
        $headers = getallheaders();
        
        if (isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
            if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
                return $matches[1];
            }
        }
        
        return null;
    }
    
    /**
     * Get current user ID from session or token
     */
    public static function getCurrentUserId() {
        // First check session
        if (isset($_SESSION['user_id'])) {
            return $_SESSION['user_id'];
        }
        
        // Then check JWT token
        $token = self::getTokenFromRequest();
        if ($token) {
            $payload = self::verifyToken($token);
            if ($payload) {
                return $payload['user_id'];
            }
        }
        
        return null;
    }
    
    /**
     * Get current user role
     */
    public static function getCurrentUserRole() {
        // First check session
        if (isset($_SESSION['user_role'])) {
            return $_SESSION['user_role'];
        }
        
        // Then check JWT token
        $token = self::getTokenFromRequest();
        if ($token) {
            $payload = self::verifyToken($token);
            if ($payload) {
                return $payload['role'];
            }
        }
        
        return null;
    }
    
    /**
     * Check if user is authenticated
     */
    public static function isAuthenticated() {
        return self::getCurrentUserId() !== null;
    }
    
    /**
     * Check if user has required role
     */
    public static function hasRole($requiredRoles) {
        if (!is_array($requiredRoles)) {
            $requiredRoles = [$requiredRoles];
        }
        
        $userRole = self::getCurrentUserRole();
        return in_array($userRole, $requiredRoles);
    }
    
    /**
     * Hash password
     */
    public static function hashPassword($password) {
        return password_hash($password, PASSWORD_DEFAULT);
    }
    
    /**
     * Verify password
     */
    public static function verifyPassword($password, $hash) {
        return password_verify($password, $hash);
    }
    
    /**
     * Generate secure random token
     */
    public static function generateRandomToken($length = 32) {
        return bin2hex(random_bytes($length));
    }
    
    /**
     * Validate password strength
     */
    public static function validatePassword($password) {
        $errors = [];
        
        if (strlen($password) < PASSWORD_MIN_LENGTH) {
            $errors[] = 'Le mot de passe doit contenir au moins ' . PASSWORD_MIN_LENGTH . ' caractères';
        }
        
        if (!preg_match('/[A-Z]/', $password)) {
            $errors[] = 'Le mot de passe doit contenir au moins une majuscule';
        }
        
        if (!preg_match('/[a-z]/', $password)) {
            $errors[] = 'Le mot de passe doit contenir au moins une minuscule';
        }
        
        if (!preg_match('/[0-9]/', $password)) {
            $errors[] = 'Le mot de passe doit contenir au moins un chiffre';
        }
        
        return $errors;
    }
    
    /**
     * Logout user
     */
    public static function logout() {
        session_destroy();
        
        // Clear cookie if exists
        if (isset($_COOKIE[session_name()])) {
            setcookie(session_name(), '', time() - 3600, '/');
        }
    }
    
    /**
     * Check session validity
     */
    public static function checkSession() {
        if (isset($_SESSION['last_activity'])) {
            $inactiveTime = time() - $_SESSION['last_activity'];
            if ($inactiveTime > SESSION_LIFETIME) {
                self::logout();
                return false;
            }
        }
        
        $_SESSION['last_activity'] = time();
        return true;
    }
    
    /**
     * Get user permissions
     */
    public static function getUserPermissions($role) {
        $permissions = [
            'admin' => [
                'clients' => ['read', 'write', 'delete'],
                'commandes' => ['read', 'write', 'delete'],
                'vehicules' => ['read', 'write', 'delete'],
                'trajets' => ['read', 'write', 'delete'],
                'factures' => ['read', 'write', 'delete'],
                'users' => ['read', 'write', 'delete'],
                'dashboard' => ['read'],
                'reports' => ['read']
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
    
    /**
     * Check if user has permission for specific action
     */
    public static function hasPermission($module, $action) {
        $role = self::getCurrentUserRole();
        if (!$role) {
            return false;
        }
        
        $permissions = self::getUserPermissions($role);
        
        if (!isset($permissions[$module])) {
            return false;
        }
        
        return in_array($action, $permissions[$module]);
    }
}
?>
