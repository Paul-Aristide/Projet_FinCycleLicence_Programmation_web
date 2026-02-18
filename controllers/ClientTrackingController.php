<?php
namespace App\Controllers;

use App\Models\Database;
use App\Utils\Auth;

/**
 * Contrôleur pour l'interface client simplifiée
 * Permet aux clients de suivre leurs colis en temps réel
 */
class ClientTrackingController extends BaseController {
    
    protected $db;
    
    public function __construct() {
        parent::__construct();
        $this->db = Database::getInstance();
    }
    
    /**
     * Connexion client avec ID client ou numéro de commande
     */
    public function login() {
        $data = $this->getRequestBody();

        // Vérifier qu'au moins un des champs est fourni
        if (empty($data['email']) && empty($data['numero_commande'])) {
            $this->errorResponse('Veuillez fournir soit un email client soit un numéro de commande', 400);
        }

        $client = null;
        $commandeId = null;

        // Connexion avec numéro de commande
        if (!empty($data['numero_commande'])) {
            $numeroCommande = $this->sanitizeInput($data['numero_commande']);

            // Rechercher le client via le numéro de commande
            $result = $this->db->fetch(
                "SELECT c.*, cmd.id as commande_id FROM clients c
                 INNER JOIN commandes cmd ON c.id = cmd.client_id
                 WHERE cmd.numero_commande = ? AND c.actif = 1",
                [$numeroCommande]
            );

            if (!$result) {
                $this->errorResponse('Numéro de commande non trouvé ou client inactif', 404);
            }

            $client = $result;
            $commandeId = $result['commande_id'];
        }
        // Connexion avec email client
        else {
            $email = $this->sanitizeInput($data['email']);

            // Vérifier que le client existe
            $client = $this->db->fetch(
                "SELECT * FROM clients WHERE email = ? AND actif = 1",
                [$email]
            );

            if (!$client) {
                $this->errorResponse('Client non trouvé ou inactif', 404);
            }
        }

        // Créer session client
        session_start();
        $_SESSION['client_id'] = $client['id'];
        $_SESSION['client_nom'] = $client['nom'];
        $_SESSION['client_prenom'] = $client['prenom'];
        $_SESSION['client_email'] = $client['email'];
        $_SESSION['is_client'] = true;

        // Si connexion via numéro de commande, stocker l'ID de commande pour redirection
        if (!empty($data['numero_commande']) && $commandeId) {
            $_SESSION['focus_commande_id'] = $commandeId;
        }

        $this->successResponse([
            'client' => [
                'id' => $client['id'],
                'nom' => $client['nom'],
                'prenom' => $client['prenom'],
                'email' => $client['email']
            ],
            'focus_commande_id' => $commandeId ?? null,
            'numero_commande' => $data['numero_commande'] ?? null,
            'message' => 'Connexion réussie'
        ]);
    }
    
    /**
     * Déconnexion client
     */
    public function logout() {
        session_start();
        session_destroy();
        $this->successResponse(['message' => 'Déconnexion réussie']);
    }
    
    /**
     * Obtenir les trajets du client connecté
     */
    public function getMyShipments() {
        $this->requireClientAuth();
        
        $clientId = $_SESSION['client_id'];
        
        // Récupérer toutes les commandes du client avec leurs trajets
        $query = "
            SELECT 
                c.id as commande_id,
                c.numero_commande,
                c.adresse_depart,
                c.adresse_arrivee,
                c.date_prevue,
                c.statut,
                c.workflow_state,
                c.poids_kg,
                c.distance_km,
                c.tarif_auto,
                c.created_at,
                t.id as trajet_id,
                t.date_depart_prevue,
                t.date_arrivee_prevue,
                t.date_depart_reelle,
                t.date_arrivee_reelle,
                t.statut as trajet_statut,
                v.immatriculation,
                v.marque,
                v.modele,
                CONCAT(u.nom, ' ', u.prenom) as chauffeur_nom,
                u.telephone as chauffeur_telephone
            FROM commandes c
            LEFT JOIN trajets t ON c.id = t.commande_id
            LEFT JOIN vehicules v ON t.vehicule_id = v.id
            LEFT JOIN users u ON t.chauffeur_id = u.id
            WHERE c.client_id = ?
            ORDER BY c.created_at DESC, t.date_depart_prevue DESC
        ";
        
        $shipments = $this->db->fetchAll($query, [$clientId]);
        
        // Grouper par commande
        $groupedShipments = [];
        foreach ($shipments as $shipment) {
            $commandeId = $shipment['commande_id'];
            
            if (!isset($groupedShipments[$commandeId])) {
                $groupedShipments[$commandeId] = [
                    'commande' => [
                        'id' => $shipment['commande_id'],
                        'numero_commande' => $shipment['numero_commande'],
                        'adresse_depart' => $shipment['adresse_depart'],
                        'adresse_arrivee' => $shipment['adresse_arrivee'],
                        'date_prevue' => $shipment['date_prevue'],
                        'statut' => $shipment['statut'],
                        'workflow_state' => $shipment['workflow_state'],
                        'poids_kg' => $shipment['poids_kg'],
                        'distance_km' => $shipment['distance_km'],
                        'tarif_auto' => $shipment['tarif_auto'],
                        'created_at' => $shipment['created_at']
                    ],
                    'trajets' => []
                ];
            }
            
            if ($shipment['trajet_id']) {
                $groupedShipments[$commandeId]['trajets'][] = [
                    'id' => $shipment['trajet_id'],
                    'date_depart_prevue' => $shipment['date_depart_prevue'],
                    'date_arrivee_prevue' => $shipment['date_arrivee_prevue'],
                    'date_depart_reelle' => $shipment['date_depart_reelle'],
                    'date_arrivee_reelle' => $shipment['date_arrivee_reelle'],
                    'statut' => $shipment['trajet_statut'],
                    'vehicule' => [
                        'immatriculation' => $shipment['immatriculation'],
                        'marque' => $shipment['marque'],
                        'modele' => $shipment['modele']
                    ],
                    'chauffeur' => [
                        'nom' => $shipment['chauffeur_nom'],
                        'telephone' => $shipment['chauffeur_telephone']
                    ]
                ];
            }
        }
        
        $this->successResponse(array_values($groupedShipments));
    }
    
    /**
     * Obtenir le détail d'un trajet spécifique
     */
    public function getShipmentDetails($commandeId) {
        $this->requireClientAuth();
        
        $clientId = $_SESSION['client_id'];
        
        // Vérifier que la commande appartient au client
        $commande = $this->db->fetch(
            "SELECT * FROM commandes WHERE id = ? AND client_id = ?",
            [$commandeId, $clientId]
        );
        
        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }
        
        // Récupérer les détails complets
        $query = "
            SELECT 
                c.*,
                t.id as trajet_id,
                t.date_depart_prevue,
                t.date_arrivee_prevue,
                t.date_depart_reelle,
                t.date_arrivee_reelle,
                t.statut as trajet_statut,
                t.distance_km as trajet_distance,
                t.duree_estimee_heures,
                v.immatriculation,
                v.marque,
                v.modele,
                v.capacite,
                CONCAT(u.nom, ' ', u.prenom) as chauffeur_nom,
                u.telephone as chauffeur_telephone,
                u.email as chauffeur_email
            FROM commandes c
            LEFT JOIN trajets t ON c.id = t.commande_id
            LEFT JOIN vehicules v ON t.vehicule_id = v.id
            LEFT JOIN users u ON t.chauffeur_id = u.id
            WHERE c.id = ? AND c.client_id = ?
        ";
        
        $details = $this->db->fetch($query, [$commandeId, $clientId]);
        
        if (!$details) {
            $this->errorResponse('Détails non trouvés', 404);
        }
        
        // Formater la réponse
        $response = [
            'commande' => [
                'id' => $details['id'],
                'numero_commande' => $details['numero_commande'],
                'adresse_depart' => $details['adresse_depart'],
                'adresse_arrivee' => $details['adresse_arrivee'],
                'date_prevue' => $details['date_prevue'],
                'statut' => $details['statut'],
                'workflow_state' => $details['workflow_state'],
                'poids_kg' => $details['poids_kg'],
                'distance_km' => $details['distance_km'],
                'tarif_auto' => $details['tarif_auto'],
                'created_at' => $details['created_at']
            ],
            'trajet' => null,
            'timeline' => $this->getShipmentTimeline($commandeId)
        ];
        
        if ($details['trajet_id']) {
            $response['trajet'] = [
                'id' => $details['trajet_id'],
                'date_depart_prevue' => $details['date_depart_prevue'],
                'date_arrivee_prevue' => $details['date_arrivee_prevue'],
                'date_depart_reelle' => $details['date_depart_reelle'],
                'date_arrivee_reelle' => $details['date_arrivee_reelle'],
                'statut' => $details['trajet_statut'],
                'distance_km' => $details['trajet_distance'],
                'duree_estimee_heures' => $details['duree_estimee_heures'],
                'vehicule' => [
                    'immatriculation' => $details['immatriculation'],
                    'marque' => $details['marque'],
                    'modele' => $details['modele'],
                    'capacite' => $details['capacite']
                ],
                'chauffeur' => [
                    'nom' => $details['chauffeur_nom'],
                    'telephone' => $details['chauffeur_telephone'],
                    'email' => $details['chauffeur_email']
                ]
            ];
        }
        
        $this->successResponse($response);
    }
    
    /**
     * Obtenir la timeline d'une commande
     */
    private function getShipmentTimeline($commandeId) {
        $query = "
            SELECT 
                state,
                previous_state,
                reason,
                created_at,
                CONCAT(u.nom, ' ', u.prenom) as changed_by_name
            FROM workflow_states ws
            LEFT JOIN users u ON ws.changed_by = u.id
            WHERE ws.commande_id = ?
            ORDER BY ws.created_at ASC
        ";
        
        $states = $this->db->fetchAll($query, [$commandeId]);
        
        $timeline = [];
        foreach ($states as $state) {
            $timeline[] = [
                'state' => $state['state'],
                'state_label' => $this->getStateLabel($state['state']),
                'previous_state' => $state['previous_state'],
                'reason' => $state['reason'],
                'date' => $state['created_at'],
                'changed_by' => $state['changed_by_name']
            ];
        }
        
        return $timeline;
    }
    
    /**
     * Obtenir le libellé d'un état
     */
    private function getStateLabel($state) {
        $labels = [
            'created' => 'Commande créée',
            'validated' => 'Commande validée',
            'rejected' => 'Commande refusée',
            'planned' => 'Trajet planifié',
            'in_transit' => 'En cours de livraison',
            'delivered' => 'Livré',
            'cancelled' => 'Annulé'
        ];
        
        return $labels[$state] ?? $state;
    }
    
    /**
     * Vérifier l'authentification client
     */
    private function requireClientAuth() {
        session_start();
        
        if (!isset($_SESSION['is_client']) || !isset($_SESSION['client_id'])) {
            http_response_code(401);
            echo json_encode([
                'success' => false,
                'error' => 'Authentification requise',
                'message' => 'Veuillez vous connecter avec votre ID client'
            ]);
            exit();
        }
    }
    
    /**
     * Obtenir les informations du client connecté
     */
    public function getClientInfo() {
        $this->requireClientAuth();
        
        $this->successResponse([
            'client' => [
                'id' => $_SESSION['client_id'],
                'nom' => $_SESSION['client_nom'],
                'prenom' => $_SESSION['client_prenom'],
                'email' => $_SESSION['client_email']
            ]
        ]);
    }
}
?>
