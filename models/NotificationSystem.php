<?php
namespace App\Models;

use App\Utils\Auth;

/**
 * Système de notifications en temps réel pour LogiswayZ
 */
class NotificationSystem {
    
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }

    /**
     * Types de notifications selon le workflow
     */
    const NOTIFICATION_TYPES = [
        'NOUVELLE_COMMANDE' => 'nouvelle_commande',
        'COMMANDE_VALIDEE' => 'commande_validee',
        'COMMANDE_REFUSEE' => 'commande_refusee',
        'TRAJET_PLANIFIE' => 'trajet_planifie',
        'VEHICULE_MAINTENANCE' => 'vehicule_maintenance',
        'COUT_MAINTENANCE' => 'cout_maintenance',
        'COLIS_LIVRE' => 'colis_livre',
        'VEHICULE_AJOUTE' => 'vehicule_ajoute',
        'VEHICULE_SUPPRIME' => 'vehicule_supprime',
        'PLANIFICATION_CREEE' => 'planification_creee',
        'BUDGET_MODIFIE' => 'budget_modifie'
    ];

    /**
     * Destinataires par type de notification
     */
    const NOTIFICATION_RECIPIENTS = [
        'NOUVELLE_COMMANDE' => ['comptabilite'],
        'COMMANDE_VALIDEE' => ['chauffeur'],
        'COMMANDE_REFUSEE' => ['commercial'],
        'TRAJET_PLANIFIE' => ['commercial', 'comptabilite'],
        'VEHICULE_MAINTENANCE' => ['commercial', 'admin'],
        'COUT_MAINTENANCE' => ['comptabilite'],
        'COLIS_LIVRE' => ['admin', 'commercial', 'comptabilite', 'chauffeur'],
        'VEHICULE_AJOUTE' => ['commercial', 'chauffeur'],
        'VEHICULE_SUPPRIME' => ['commercial', 'chauffeur'],
        'PLANIFICATION_CREEE' => ['comptabilite', 'admin'],
        'BUDGET_MODIFIE' => ['comptabilite', 'admin']
    ];

    /**
     * Envoyer notification selon le workflow
     */
    public function sendWorkflowNotification($type, $data) {
        if (!isset(self::NOTIFICATION_RECIPIENTS[$type])) {
            throw new \Exception("Type de notification non reconnu: $type");
        }

        $recipients = self::NOTIFICATION_RECIPIENTS[$type];
        $message = $this->generateMessage($type, $data);
        
        foreach ($recipients as $role) {
            $this->sendNotificationToRole($role, $type, $message, $data);
        }

        // Sauvegarder en base
        $this->saveNotification($type, $message, $data, $recipients);
    }

    /**
     * Notification: Nouvelle commande enregistrée
     */
    public function notifyNewOrder($commandeData) {
        $message = "Nouvelle commande enregistrée";
        $data = [
            'commande_id' => $commandeData['id'],
            'numero_commande' => $commandeData['numero_commande'],
            'client_id' => $commandeData['client_id'],
            'client_nom' => $commandeData['client_nom'],
            'client_prenom' => $commandeData['client_prenom'],
            'client_email' => $commandeData['client_email'],
            'tarif' => $commandeData['tarif'],
            'poids' => $commandeData['poids'],
            'distance' => $commandeData['distance'],
            'adresse_depart' => $commandeData['adresse_depart'],
            'adresse_arrivee' => $commandeData['adresse_arrivee'],
            'date_creation' => $commandeData['date_creation']
        ];

        $this->sendWorkflowNotification('NOUVELLE_COMMANDE', $data);
    }

    /**
     * Notification: Commande validée par comptable
     */
    public function notifyOrderValidated($commandeData) {
        $message = "Commande validée - Planification requise";
        $data = [
            'commande_id' => $commandeData['id'],
            'numero_commande' => $commandeData['numero_commande'],
            'client_nom' => $commandeData['client_nom'],
            'tarif' => $commandeData['tarif'],
            'adresse_depart' => $commandeData['adresse_depart'],
            'adresse_arrivee' => $commandeData['adresse_arrivee'],
            'date_validation' => date('Y-m-d H:i:s')
        ];

        $this->sendWorkflowNotification('COMMANDE_VALIDEE', $data);
    }

    /**
     * Notification: Commande refusée par comptable
     */
    public function notifyOrderRejected($commandeData, $reason) {
        $message = "Commande refusée";
        $data = [
            'commande_id' => $commandeData['id'],
            'numero_commande' => $commandeData['numero_commande'],
            'client_nom' => $commandeData['client_nom'],
            'reason' => $reason,
            'date_refus' => date('Y-m-d H:i:s')
        ];

        $this->sendWorkflowNotification('COMMANDE_REFUSEE', $data);
    }

    /**
     * Notification: Véhicule en maintenance
     */
    public function notifyVehicleMaintenance($vehiculeData, $maintenanceData) {
        // Notification générale (sans coût)
        $message = "Véhicule en maintenance";
        $generalData = [
            'vehicule_id' => $vehiculeData['id'],
            'immatriculation' => $vehiculeData['immatriculation'],
            'type' => $maintenanceData['type'],
            'description' => $maintenanceData['description'],
            'date_debut' => $maintenanceData['date_debut'],
            'duree_estimee' => $maintenanceData['duree_estimee']
        ];

        $this->sendWorkflowNotification('VEHICULE_MAINTENANCE', $generalData);

        // Notification spéciale pour comptable (avec coût)
        $costMessage = "Coût de maintenance";
        $costData = array_merge($generalData, [
            'cout' => $maintenanceData['cout'],
            'fournisseur' => $maintenanceData['fournisseur'] ?? null
        ]);

        $this->sendWorkflowNotification('COUT_MAINTENANCE', $costData);
    }

    /**
     * Notification: Colis livré
     */
    public function notifyDeliveryCompleted($trajetData) {
        $message = "Colis livré";
        $data = [
            'trajet_id' => $trajetData['id'],
            'commande_id' => $trajetData['commande_id'],
            'numero_commande' => $trajetData['numero_commande'],
            'client_nom' => $trajetData['client_nom'],
            'chauffeur_nom' => $trajetData['chauffeur_nom'],
            'vehicule_immat' => $trajetData['vehicule_immat'],
            'date_livraison' => date('Y-m-d H:i:s'),
            'adresse_livraison' => $trajetData['adresse_arrivee']
        ];

        $this->sendWorkflowNotification('COLIS_LIVRE', $data);
    }

    /**
     * Notification: Véhicule ajouté/supprimé
     */
    public function notifyVehicleChange($action, $vehiculeData) {
        $type = $action === 'add' ? 'VEHICULE_AJOUTE' : 'VEHICULE_SUPPRIME';
        $message = $action === 'add' ? "Nouveau véhicule ajouté" : "Véhicule supprimé";
        
        $data = [
            'vehicule_id' => $vehiculeData['id'],
            'immatriculation' => $vehiculeData['immatriculation'],
            'marque' => $vehiculeData['marque'],
            'modele' => $vehiculeData['modele'],
            'capacite' => $vehiculeData['capacite'],
            'action' => $action,
            'date_action' => date('Y-m-d H:i:s')
        ];

        $this->sendWorkflowNotification($type, $data);
    }

    /**
     * Envoyer notification à un rôle spécifique
     */
    private function sendNotificationToRole($role, $type, $message, $data) {
        // Récupérer tous les utilisateurs de ce rôle
        $users = $this->getUsersByRole($role);
        
        foreach ($users as $user) {
            $this->sendNotificationToUser($user['id'], $type, $message, $data);
        }
    }

    /**
     * Envoyer notification à un utilisateur spécifique
     */
    private function sendNotificationToUser($userId, $type, $message, $data) {
        // Insérer en base
        $notificationId = $this->insertNotification($userId, $type, $message, $data);
        
        // Envoyer via WebSocket (simulation)
        $this->sendWebSocketNotification($userId, [
            'id' => $notificationId,
            'type' => $type,
            'message' => $message,
            'data' => $data,
            'timestamp' => date('Y-m-d H:i:s'),
            'read' => false
        ]);
    }

    /**
     * Générer message selon le type
     */
    private function generateMessage($type, $data) {
        switch ($type) {
            case 'NOUVELLE_COMMANDE':
                return "Nouvelle commande {$data['numero_commande']} de {$data['client_nom']} {$data['client_prenom']}";
                
            case 'COMMANDE_VALIDEE':
                return "Commande {$data['numero_commande']} validée - Planifiez le trajet";
                
            case 'COMMANDE_REFUSEE':
                return "Commande {$data['numero_commande']} refusée: {$data['reason']}";
                
            case 'VEHICULE_MAINTENANCE':
                return "Véhicule {$data['immatriculation']} en maintenance";
                
            case 'COUT_MAINTENANCE':
                return "Coût maintenance {$data['immatriculation']}: " . number_format($data['cout']) . " F CFA";
                
            case 'COLIS_LIVRE':
                return "Colis livré - Commande {$data['numero_commande']}";
                
            case 'VEHICULE_AJOUTE':
                return "Nouveau véhicule ajouté: {$data['immatriculation']}";
                
            case 'VEHICULE_SUPPRIME':
                return "Véhicule supprimé: {$data['immatriculation']}";
                
            default:
                return "Notification système";
        }
    }

    /**
     * Récupérer utilisateurs par rôle
     */
    private function getUsersByRole($role) {
        $query = "SELECT id, nom, prenom, email FROM users WHERE role = ? AND actif = 1";
        return $this->db->fetchAll($query, [$role]);
    }

    /**
     * Insérer notification en base
     */
    private function insertNotification($userId, $type, $message, $data) {
        $query = "INSERT INTO notifications (user_id, type, message, data, created_at) 
                  VALUES (?, ?, ?, ?, NOW())";
        
        return $this->db->insert($query, [
            $userId,
            $type,
            $message,
            json_encode($data)
        ]);
    }

    /**
     * Sauvegarder notification globale
     */
    private function saveNotification($type, $message, $data, $recipients) {
        $query = "INSERT INTO notification_logs (type, message, data, recipients, created_at) 
                  VALUES (?, ?, ?, ?, NOW())";
        
        $this->db->insert($query, [
            $type,
            $message,
            json_encode($data),
            json_encode($recipients)
        ]);
    }

    /**
     * Simulation WebSocket (à remplacer par vraie implémentation)
     */
    private function sendWebSocketNotification($userId, $notification) {
        // Pour l'instant, on stocke en session pour simulation
        if (!isset($_SESSION['pending_notifications'])) {
            $_SESSION['pending_notifications'] = [];
        }
        
        if (!isset($_SESSION['pending_notifications'][$userId])) {
            $_SESSION['pending_notifications'][$userId] = [];
        }
        
        $_SESSION['pending_notifications'][$userId][] = $notification;
        
        // En production, utiliser une vraie solution WebSocket comme Ratchet/ReactPHP
        // ou Socket.IO avec Node.js
    }

    /**
     * Récupérer notifications en attente pour un utilisateur
     */
    public function getPendingNotifications($userId) {
        $notifications = $_SESSION['pending_notifications'][$userId] ?? [];
        
        // Vider après récupération
        unset($_SESSION['pending_notifications'][$userId]);
        
        return $notifications;
    }

    /**
     * Marquer notification comme lue
     */
    public function markAsRead($notificationId, $userId) {
        $query = "UPDATE notifications SET read_at = NOW() 
                  WHERE id = ? AND user_id = ?";
        
        return $this->db->update($query, [$notificationId, $userId]);
    }

    /**
     * Récupérer historique des notifications
     */
    public function getNotificationHistory($userId, $limit = 50) {
        $query = "SELECT * FROM notifications 
                  WHERE user_id = ? 
                  ORDER BY created_at DESC 
                  LIMIT ?";
        
        return $this->db->fetchAll($query, [$userId, $limit]);
    }
}
?>
