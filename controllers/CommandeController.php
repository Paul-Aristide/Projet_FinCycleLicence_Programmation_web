<?php
namespace App\Controllers;

use App\Models\Commande;
use App\Models\Client;
use App\Models\Trajet;
use App\Models\NotificationSystem;
use App\Models\TarificationSystem;
use App\Middleware\AuthMiddleware;
use App\Middleware\PermissionMiddleware;
use App\Utils\Auth;
use DateTime;

class CommandeController extends BaseController {

    private $notificationSystem;

    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
        $this->notificationSystem = new NotificationSystem();
    }

    /**
     * Get all orders (Commercial + Comptable)
     */
    public function index() {
        PermissionMiddleware::checkStrictPermission('commandes', 'read');

        $commandeModel = new Commande();
        $status = $_GET['status'] ?? null;
        $clientId = $_GET['client_id'] ?? null;
        $workflowState = $_GET['workflow_state'] ?? null;

        // Filtres selon les paramètres
        if ($workflowState) {
            $commandes = $commandeModel->getByWorkflowState($workflowState);
        } elseif ($status) {
            $commandes = $commandeModel->getByStatus($status);
        } elseif ($clientId) {
            $commandes = $commandeModel->getByClientId($clientId);
        } else {
            $commandes = $commandeModel->getAllWithDetails();
        }

        $this->successResponse($commandes);
    }
    
    /**
     * Get order by ID
     */
    public function show($id) {
        PermissionMiddleware::checkStrictPermission('commandes', 'read');
        $commandeModel = new Commande();
        $commande = $commandeModel->findById($id);
        
        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }
        
        $this->successResponse($commande);
    }
    
    /**
     * Create new order (Commercial uniquement)
     */
    public function create() {
        PermissionMiddleware::commercialOnly('create');

        $data = $this->getRequestBody();
        $this->validateRequired($data, ['client_id', 'adresse_depart', 'adresse_arrivee', 'date_prevue']);

        $data = $this->sanitizeInput($data);

        // Validate client exists
        $clientModel = new Client();
        $client = $clientModel->findById($data['client_id']);
        if (!$client) {
            $this->errorResponse('Client non trouvé');
        }

        // Validate date format
        if (!$this->isValidDate($data['date_prevue'])) {
            $this->errorResponse('Format de date invalide (YYYY-MM-DD attendu)');
        }

        // Calcul automatique du tarif si poids fourni
        $tarificationData = null;
        if (isset($data['poids_kg']) && $data['poids_kg'] > 0) {
            // Validation des paramètres de tarification
            $errors = TarificationSystem::validateTarificationParams(
                $data['poids_kg'],
                $data['adresse_depart'],
                $data['adresse_arrivee']
            );

            if (!empty($errors)) {
                $this->errorResponse('Erreurs de tarification: ' . implode(', ', $errors));
            }

            // Calcul du tarif
            $tarificationData = TarificationSystem::generateQuote(
                $data['poids_kg'],
                $data['adresse_depart'],
                $data['adresse_arrivee'],
                [
                    'cargo_type' => $data['cargo_type'] ?? 'standard',
                    'discount_percent' => $data['discount_percent'] ?? 0
                ]
            );
        }

        $commandeModel = new Commande();
        $numeroCommande = $commandeModel->generateNumeroCommande();

        $commandeData = [
            'numero_commande' => $numeroCommande,
            'client_id' => $data['client_id'],
            'adresse_depart' => $data['adresse_depart'],
            'adresse_arrivee' => $data['adresse_arrivee'],
            'date_prevue' => $data['date_prevue'],
            'heure_prevue' => $data['heure_prevue'] ?? null,
            'description' => $data['description'] ?? '',
            'poids' => $data['poids'] ?? 0, // Ancien champ pour compatibilité
            'volume' => $data['volume'] ?? 0,
            'prix' => $data['prix'] ?? ($tarificationData['tarif_total'] ?? 0),
            'statut' => 'en_attente',
            'workflow_state' => 'created',
            'notes' => $data['notes'] ?? '',
            // Nouveaux champs de tarification
            'poids_kg' => $data['poids_kg'] ?? null,
            'distance_km' => $tarificationData['details']['distance'] ?? null,
            'zone_tarif' => $tarificationData['details']['zone'] ?? null,
            'cargo_type' => $data['cargo_type'] ?? 'standard',
            'tarif_auto' => $tarificationData['tarif_total'] ?? null
        ];

        $commandeId = $commandeModel->create($commandeData);

        // Sauvegarder l'historique de tarification si calculé
        if ($tarificationData) {
            $this->saveTarificationHistory($commandeId, $tarificationData);
        }

        // Récupérer la commande créée avec tous les détails
        $commande = $commandeModel->findByIdWithDetails($commandeId);

        // Envoyer notification au comptable
        $this->sendNewOrderNotification($commande, $client);

        $this->successResponse($commande, 'Commande créée avec succès');
    }
    
    /**
     * Update order (Commercial uniquement)
     */
    public function update($id) {
        PermissionMiddleware::commercialOnly('update');
        
        $commandeModel = new Commande();
        $commande = $commandeModel->findById($id);
        
        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }
        
        $data = $this->getRequestBody();
        $data = $this->sanitizeInput($data);
        
        // Validate date if provided
        if (isset($data['date_prevue']) && !$this->isValidDate($data['date_prevue'])) {
            $this->errorResponse('Format de date invalide (YYYY-MM-DD attendu)');
        }
        
        // Validate client if provided
        if (isset($data['client_id'])) {
            require_once 'models/Client.php';
            $clientModel = new Client();
            if (!$clientModel->findById($data['client_id'])) {
                $this->errorResponse('Client non trouvé');
            }
        }
        
        $commandeModel->update($id, $data);
        $updatedCommande = $commandeModel->findById($id);
        
        $this->successResponse($updatedCommande, 'Commande mise à jour avec succès');
    }
    
    /**
     * Update order status
     */
    public function updateStatus($id) {
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['statut']);
        
        $statut = $this->sanitizeInput($data['statut']);
        $validStatuts = ['en_attente', 'confirmee', 'en_cours', 'livree', 'annulee'];
        
        if (!in_array($statut, $validStatuts)) {
            $this->errorResponse('Statut invalide');
        }
        
        $commandeModel = new Commande();
        $commande = $commandeModel->findById($id);
        
        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }
        
        $commandeModel->updateStatus($id, $statut);
        $updatedCommande = $commandeModel->findById($id);
        
        $this->successResponse($updatedCommande, 'Statut mis à jour avec succès');
    }
    
    /**
     * Validate order (Comptable uniquement)
     */
    public function validate($id) {
        PermissionMiddleware::comptableOnly('validate');

        $commandeModel = new Commande();
        $commande = $commandeModel->findByIdWithDetails($id);

        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }

        if ($commande['workflow_state'] !== 'created') {
            $this->errorResponse('Seules les commandes en attente peuvent être validées');
        }

        $userId = Auth::getCurrentUserId();

        // Mettre à jour le statut
        $commandeModel->update($id, [
            'workflow_state' => 'validated',
            'statut' => 'confirmee',
            'validated_by' => $userId,
            'validated_at' => date('Y-m-d H:i:s')
        ]);

        // Créer la transaction de paiement
        $this->createPaymentTransaction($commande);

        // Récupérer la commande mise à jour
        $updatedCommande = $commandeModel->findByIdWithDetails($id);

        // Envoyer notification au chauffeur
        $this->notificationSystem->notifyOrderValidated($updatedCommande);

        $this->successResponse($updatedCommande, 'Commande validée avec succès');
    }

    /**
     * Reject order (Comptable uniquement)
     */
    public function reject($id) {
        PermissionMiddleware::comptableOnly('reject');

        $data = $this->getRequestBody();
        $this->validateRequired($data, ['reason']);

        $commandeModel = new Commande();
        $commande = $commandeModel->findByIdWithDetails($id);

        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }

        if ($commande['workflow_state'] !== 'created') {
            $this->errorResponse('Seules les commandes en attente peuvent être refusées');
        }

        $reason = $this->sanitizeInput($data['reason']);

        // Mettre à jour le statut
        $commandeModel->update($id, [
            'workflow_state' => 'rejected',
            'statut' => 'annulee',
            'rejection_reason' => $reason,
            'validated_by' => Auth::getCurrentUserId(),
            'validated_at' => date('Y-m-d H:i:s')
        ]);

        // Récupérer la commande mise à jour
        $updatedCommande = $commandeModel->findByIdWithDetails($id);

        // Envoyer notification au commercial
        $this->notificationSystem->notifyOrderRejected($updatedCommande, $reason);

        $this->successResponse($updatedCommande, 'Commande refusée');
    }

    /**
     * Delete order (Commercial uniquement)
     */
    public function delete($id) {
        PermissionMiddleware::commercialOnly('delete');

        $commandeModel = new Commande();
        $commande = $commandeModel->findById($id);

        if (!$commande) {
            $this->errorResponse('Commande non trouvée', 404);
        }

        // Vérifier que la commande n'est pas validée
        if ($commande['workflow_state'] === 'validated' || $commande['workflow_state'] === 'in_transit') {
            $this->errorResponse('Impossible de supprimer une commande validée ou en cours');
        }

        // Check if order has associated routes
        $trajetModel = new Trajet();
        $trajets = $trajetModel->getByCommandeId($id);

        if (!empty($trajets)) {
            $this->errorResponse('Impossible de supprimer une commande avec des trajets associés');
        }

        $commandeModel->delete($id);
        $this->successResponse(null, 'Commande supprimée avec succès');
    }
    
    /**
     * Get dashboard statistics
     */
    public function getStats() {
        $commandeModel = new Commande();
        $stats = $commandeModel->getStatistics();
        $this->successResponse($stats);
    }
    
    /**
     * Calculate tariff for order
     */
    public function calculateTariff() {
        PermissionMiddleware::commercialOnly('read');

        $data = $this->getRequestBody();
        $this->validateRequired($data, ['poids_kg', 'adresse_depart', 'adresse_arrivee']);

        try {
            $tarification = TarificationSystem::generateQuote(
                $data['poids_kg'],
                $data['adresse_depart'],
                $data['adresse_arrivee'],
                [
                    'cargo_type' => $data['cargo_type'] ?? 'standard',
                    'discount_percent' => $data['discount_percent'] ?? 0
                ]
            );

            $this->successResponse($tarification);
        } catch (Exception $e) {
            $this->errorResponse('Erreur de calcul: ' . $e->getMessage());
        }
    }

    /**
     * Get pending orders for validation (Comptable uniquement)
     */
    public function getPendingValidation() {
        PermissionMiddleware::comptableOnly('read');

        $commandeModel = new Commande();
        $commandes = $commandeModel->getByWorkflowState('created');

        $this->successResponse($commandes);
    }

    /**
     * Envoyer notification nouvelle commande
     */
    private function sendNewOrderNotification($commande, $client) {
        $notificationData = [
            'id' => $commande['id'],
            'numero_commande' => $commande['numero_commande'],
            'client_id' => $client['id'],
            'client_nom' => $client['nom'],
            'client_prenom' => $client['prenom'],
            'client_email' => $client['email'],
            'tarif' => $commande['tarif_auto'] ?? $commande['prix'],
            'poids' => $commande['poids_kg'],
            'distance' => $commande['distance_km'],
            'adresse_depart' => $commande['adresse_depart'],
            'adresse_arrivee' => $commande['adresse_arrivee'],
            'date_creation' => $commande['created_at']
        ];

        $this->notificationSystem->notifyNewOrder($notificationData);
    }

    /**
     * Créer transaction de paiement
     */
    private function createPaymentTransaction($commande) {
        // Créer automatiquement la transaction de paiement
        $transactionData = [
            'commande_id' => $commande['id'],
            'type' => 'paiement_client',
            'montant' => $commande['tarif_auto'] ?? $commande['prix'],
            'description' => "Paiement commande {$commande['numero_commande']}",
            'statut' => 'en_attente',
            'date_transaction' => date('Y-m-d H:i:s')
        ];

        // Insérer en base (à implémenter dans le modèle Transaction)
        $this->db->insert('transactions', $transactionData);
    }

    /**
     * Sauvegarder historique de tarification
     */
    private function saveTarificationHistory($commandeId, $tarificationData) {
        $historyData = [
            'commande_id' => $commandeId,
            'poids' => $tarificationData['details']['poids'],
            'distance' => $tarificationData['details']['distance'],
            'zone' => $tarificationData['details']['zone'],
            'cargo_type' => $tarificationData['details']['type_marchandise'],
            'tarif_base' => $tarificationData['tarif_base'],
            'tarif_total' => $tarificationData['tarif_total'],
            'details' => json_encode($tarificationData)
        ];

        $this->db->insert('tarification_history', $historyData);
    }

    /**
     * Validate date format
     */
    private function isValidDate($date) {
        $d = DateTime::createFromFormat('Y-m-d', $date);
        return $d && $d->format('Y-m-d') === $date;
    }
}
?>
