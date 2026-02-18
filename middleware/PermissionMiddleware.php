<?php
namespace App\Middleware;

use App\Utils\Auth;

/**
 * Middleware de permissions strictes selon les règles métier LogiswayZ
 */
class PermissionMiddleware {
    
    /**
     * Permissions strictes par module et rôle
     */
    private static $permissions = [
        'commandes' => [
            'create' => ['commercial'],
            'read' => ['commercial', 'comptabilite', 'chauffeur', 'admin'],
            'update' => ['commercial'],
            'delete' => ['commercial'],
            'validate' => ['comptabilite'],
            'reject' => ['comptabilite']
        ],
        'factures' => [
            'create' => ['comptabilite'],
            'read' => ['comptabilite', 'admin'],
            'update' => ['comptabilite'],
            'delete' => ['comptabilite'],
            'validate' => ['comptabilite'],
            'reject' => ['comptabilite']
        ],
        'transactions' => [
            'create' => ['comptabilite'],
            'read' => ['comptabilite', 'admin'],
            'update' => ['comptabilite'],
            'delete' => ['comptabilite']
        ],
        'trajets' => [
            'create' => ['chauffeur'],
            'read' => ['chauffeur', 'commercial', 'admin'],
            'update' => ['chauffeur'],
            'delete' => ['chauffeur'],
            'plan' => ['chauffeur']
        ],
        'vehicules' => [
            'create' => ['admin'],
            'read' => ['admin', 'chauffeur', 'commercial'],
            'update' => ['chauffeur'], // Maintenance, statut
            'delete' => ['admin'],
            'maintenance' => ['chauffeur']
        ],
        'planification' => [
            'create' => ['comptabilite'], // Comptable uniquement
            'read' => ['comptabilite','admin'], // Comptable uniquement
            'update' => ['comptabilite'], // Comptable uniquement
            'delete' => ['comptabilite'] // Comptable uniquement
        ],
        'budget' => [
            'create' => ['admin', 'comptabilite'],
            'read' => ['admin', 'comptabilite'],
            'update' => ['admin', 'comptabilite'],
            'delete' => ['admin', 'comptabilite']
        ],
        'clients' => [
            'create' => ['commercial'],
            'read' => ['commercial', 'chauffeur','comptabilite' , 'admin'],
            'update' => ['commercial'],
            'delete' => ['commercial']
        ],
        'users' => [
            'create' => ['admin'],
            'read' => ['admin'],
            'update' => ['admin'],
            'delete' => ['admin']
        ],
        'dashboard' => [
            'read' => ['admin', 'commercial', 'comptabilite', 'chauffeur']
        ],
        'notifications' => [
            'read' => ['admin', 'commercial', 'comptabilite', 'chauffeur'],
            'create' => ['system'] // Système uniquement
        ]
    ];

    /**
     * Vérifier permission stricte
     */
    public static function checkStrictPermission($module, $action) {
        AuthMiddleware::requireAuth();
        
        $userRole = Auth::getCurrentUserRole();
        
        // Vérifier si le module existe
        if (!isset(self::$permissions[$module])) {
            self::denyAccess("Module '$module' non reconnu");
            return false;
        }
        
        // Vérifier si l'action existe pour ce module
        if (!isset(self::$permissions[$module][$action])) {
            self::denyAccess("Action '$action' non autorisée pour le module '$module'");
            return false;
        }
        
        // Vérifier si le rôle a la permission
        $allowedRoles = self::$permissions[$module][$action];
        if (!in_array($userRole, $allowedRoles)) {
            self::denyAccess("Rôle '$userRole' non autorisé pour '$module.$action'");
            return false;
        }
        
        return true;
    }

    /**
     * Middleware pour les commandes (Commercial uniquement)
     */
    public static function commercialOnly($action = 'read') {
        return self::checkStrictPermission('commandes', $action);
    }

    /**
     * Middleware pour les factures (Comptable uniquement)
     */
    public static function comptableOnly($action = 'read') {
        return self::checkStrictPermission('factures', $action);
    }

    /**
     * Middleware pour les trajets (Chauffeur uniquement)
     */
    public static function chauffeurOnly($action = 'read') {
        return self::checkStrictPermission('trajets', $action);
    }

    /**
     * Middleware pour les véhicules (règles spéciales)
     */
    public static function vehiculePermission($action = 'read') {
        AuthMiddleware::requireAuth();
        
        $userRole = Auth::getCurrentUserRole();
        
        switch ($action) {
            case 'create':
            case 'delete':
                return $userRole === 'admin';
                
            case 'update':
            case 'maintenance':
                return $userRole === 'chauffeur';
                
            case 'read':
                return in_array($userRole, ['admin', 'chauffeur', 'commercial']);
                
            default:
                self::denyAccess("Action véhicule '$action' non reconnue");
                return false;
        }
    }

    /**
     * Middleware pour planification/budget (Comptable uniquement)
     */
    public static function planificationPermission($action = 'read') {
        AuthMiddleware::requireAuth();

        $userRole = Auth::getCurrentUserRole();

        if ($userRole !== 'comptabilite') {
            self::denyAccess("Seuls les comptables peuvent gérer la planification");
            return false;
        }

        return true;
    }

    /**
     * Vérifier si l'utilisateur peut voir les coûts
     */
    public static function canViewCosts() {
        AuthMiddleware::requireAuth();
        
        $userRole = Auth::getCurrentUserRole();
        return in_array($userRole, ['admin', 'comptabilite', 'chauffeur']);
    }

    /**
     * Vérifier si l'utilisateur peut valider des commandes
     */
    public static function canValidateCommands() {
        AuthMiddleware::requireAuth();
        
        $userRole = Auth::getCurrentUserRole();
        return $userRole === 'comptabilite';
    }

    /**
     * Vérifier si l'utilisateur peut envoyer des notifications
     */
    public static function canSendNotifications() {
        AuthMiddleware::requireAuth();
        
        // Tous les rôles peuvent déclencher des notifications via leurs actions
        return true;
    }

    /**
     * Obtenir les permissions d'un rôle
     */
    public static function getRolePermissions($role) {
        $permissions = [];
        
        foreach (self::$permissions as $module => $actions) {
            foreach ($actions as $action => $allowedRoles) {
                if (in_array($role, $allowedRoles)) {
                    if (!isset($permissions[$module])) {
                        $permissions[$module] = [];
                    }
                    $permissions[$module][] = $action;
                }
            }
        }
        
        return $permissions;
    }

    /**
     * Vérifier permission avec logging
     */
    public static function checkPermissionWithLog($module, $action, $resourceId = null) {
        $result = self::checkStrictPermission($module, $action);
        
        // Log de l'accès
        self::logPermissionCheck($module, $action, $resourceId, $result);
        
        return $result;
    }

    /**
     * Refuser l'accès avec message détaillé
     */
    private static function denyAccess($reason) {
        http_response_code(403);
        header('Content-Type: application/json');
        
        $response = [
            'success' => false,
            'error' => 'Accès refusé',
            'message' => $reason,
            'user_role' => Auth::getCurrentUserRole(),
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        echo json_encode($response);
        
        // Log de sécurité
        self::logSecurityViolation($reason);
        
        exit();
    }

    /**
     * Logger les vérifications de permissions
     */
    private static function logPermissionCheck($module, $action, $resourceId, $granted) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'user_id' => Auth::getCurrentUserId(),
            'user_role' => Auth::getCurrentUserRole(),
            'module' => $module,
            'action' => $action,
            'resource_id' => $resourceId,
            'granted' => $granted,
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ];
        
        // En production, sauvegarder en base de données
        error_log('Permission Check: ' . json_encode($logEntry));
    }

    /**
     * Logger les violations de sécurité
     */
    private static function logSecurityViolation($reason) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'type' => 'PERMISSION_VIOLATION',
            'user_id' => Auth::getCurrentUserId(),
            'user_role' => Auth::getCurrentUserRole(),
            'reason' => $reason,
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
        ];
        
        error_log('Security Violation: ' . json_encode($logEntry));
    }
}
?>
