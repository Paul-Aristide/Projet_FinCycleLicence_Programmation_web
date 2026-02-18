<?php
namespace App\Middleware;

use App\Utils\Auth;
use App\Models\Trajet;

class AuthMiddleware {
    
    /**
     * Require authentication
     */
    public static function requireAuth() {
        if (!Auth::isAuthenticated()) {
            http_response_code(401);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Authentication requise']);
            exit();
        }
        
        // Check session validity
        if (!Auth::checkSession()) {
            http_response_code(401);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Session expirée']);
            exit();
        }
    }
    
    /**
     * Require specific role(s)
     */
    public static function requireRole($roles) {
        self::requireAuth();
        
        if (!Auth::hasRole($roles)) {
            http_response_code(403);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Accès non autorisé']);
            exit();
        }
    }
    
    /**
     * Require specific permission
     */
    public static function requirePermission($module, $action) {
        self::requireAuth();
        
        if (!Auth::hasPermission($module, $action)) {
            http_response_code(403);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Permission insuffisante']);
            exit();
        }
    }
    
    /**
     * Optional authentication (sets user context if authenticated)
     */
    public static function optionalAuth() {
        if (Auth::isAuthenticated()) {
            Auth::checkSession();
        }
    }
    
    /**
     * Admin only access
     */
    public static function adminOnly() {
        self::requireRole(['admin']);
    }
    
    /**
     * Staff only access (admin, commercial, comptabilite)
     */
    public static function staffOnly() {
        self::requireRole(['admin', 'commercial', 'comptabilite']);
    }
    
    /**
     * Driver access check
     */
    public static function driverOnly() {
        self::requireRole(['chauffeur']);
    }
    
    /**
     * Check if user can access resource
     */
    public static function canAccessResource($resourceType, $resourceId = null) {
        $userId = Auth::getCurrentUserId();
        $userRole = Auth::getCurrentUserRole();
        
        // Admin can access everything
        if ($userRole === 'admin') {
            return true;
        }
        
        // Role-specific access rules
        switch ($resourceType) {
            case 'client':
                return in_array($userRole, ['commercial', 'comptabilite', 'chauffeur']);

            case 'commande':
                return in_array($userRole, ['commercial', 'comptabilite']);

            case 'vehicule':
                return in_array($userRole, ['commercial', 'chauffeur']);

            case 'trajet':
                return in_array($userRole, ['chauffeur']);

            case 'facture':
                return in_array($userRole, ['comptabilite']);

            default:
                return false;
        }
    }
    
    /**
     * API rate limiting
     */
    public static function rateLimit($maxRequests = 100, $timeWindow = 3600) {
        $userId = Auth::getCurrentUserId();
        $key = 'rate_limit_' . ($userId ?? $_SERVER['REMOTE_ADDR']);
        
        if (!isset($_SESSION[$key])) {
            $_SESSION[$key] = [
                'count' => 1,
                'reset_time' => time() + $timeWindow
            ];
            return true;
        }
        
        $rateData = $_SESSION[$key];
        
        // Reset if time window has passed
        if (time() > $rateData['reset_time']) {
            $_SESSION[$key] = [
                'count' => 1,
                'reset_time' => time() + $timeWindow
            ];
            return true;
        }
        
        // Check if limit exceeded
        if ($rateData['count'] >= $maxRequests) {
            http_response_code(429);
            header('Content-Type: application/json');
            echo json_encode([
                'error' => 'Limite de requêtes dépassée',
                'retry_after' => $rateData['reset_time'] - time()
            ]);
            exit();
        }
        
        // Increment counter
        $_SESSION[$key]['count']++;
        return true;
    }
    
    /**
     * CSRF protection
     */
    public static function csrfProtect() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST' || $_SERVER['REQUEST_METHOD'] === 'PUT' || $_SERVER['REQUEST_METHOD'] === 'DELETE') {
            $token = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
            $sessionToken = $_SESSION['csrf_token'] ?? '';
            
            if (!$token || !$sessionToken || !hash_equals($sessionToken, $token)) {
                http_response_code(403);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Token CSRF invalide']);
                exit();
            }
        }
    }
    
    /**
     * Generate CSRF token
     */
    public static function generateCsrfToken() {
        if (!isset($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }
        return $_SESSION['csrf_token'];
    }
    
    /**
     * Log security event
     */
    private static function logSecurityEvent($event, $details = []) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'event' => $event,
            'user_id' => Auth::getCurrentUserId(),
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
            'details' => $details
        ];
        
        // In a real application, you would log this to a file or database
        error_log('Security Event: ' . json_encode($logEntry));
    }
}
?>
