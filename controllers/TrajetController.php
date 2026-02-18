<?php
namespace App\Controllers;

use App\Controllers\BaseController;
use App\Models\Trajet;
use App\Middleware\AuthMiddleware;
use App\Middleware\PermissionMiddleware;

class TrajetController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
    }
    
    /**
     * Get all routes (Chauffeur + Commercial + Admin)
     */
    public function index() {
        PermissionMiddleware::checkStrictPermission('trajets', 'read');
        $trajetModel = new Trajet();
        $statut = $_GET['statut'] ?? null;
        $chauffeurId = $_GET['chauffeur_id'] ?? null;
        $vehiculeId = $_GET['vehicule_id'] ?? null;
        
        if ($statut) {
            $trajets = $trajetModel->getByStatut($statut);
        } elseif ($chauffeurId) {
            $trajets = $trajetModel->getByChauffeurId($chauffeurId);
        } elseif ($vehiculeId) {
            $trajets = $trajetModel->getByVehiculeId($vehiculeId);
        } else {
            $trajets = $trajetModel->getAll();
        }
        
        $this->successResponse($trajets);
    }
    
    /**
     * Get route by ID
     */
    public function show($id) {
        PermissionMiddleware::checkStrictPermission('trajets', 'read');
        $trajetModel = new Trajet();
        $trajet = $trajetModel->findById($id);
        
        if (!$trajet) {
            $this->errorResponse('Trajet non trouvé', 404);
        }
        
        $this->successResponse($trajet);
    }
    
    /**
     * Create new route (Chauffeur uniquement)
     */
    public function create() {
        PermissionMiddleware::checkStrictPermission('trajets', 'create');
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['commande_id', 'vehicule_id', 'chauffeur_id', 'date_depart']);
        
        $data = $this->sanitizeInput($data);
        
        // Validate related entities exist
        $this->validateRelatedEntities($data);
        
        // Validate date format
        if (!$this->isValidDateTime($data['date_depart'])) {
            $this->errorResponse('Format de date/heure invalide (YYYY-MM-DD HH:MM:SS attendu)');
        }
        
        // Check vehicle availability
        require_once 'models/Vehicule.php';
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($data['vehicule_id']);
        if (!$vehicule['disponible']) {
            $this->errorResponse('Le véhicule sélectionné n\'est pas disponible');
        }
        
        // Check driver availability
        $trajetModel = new Trajet();
        if ($trajetModel->isChauffeurOccupy($data['chauffeur_id'], $data['date_depart'])) {
            $this->errorResponse('Le chauffeur est déjà assigné à un autre trajet à cette date');
        }
        
        $trajetId = $trajetModel->create([
            'commande_id' => $data['commande_id'],
            'vehicule_id' => $data['vehicule_id'],
            'chauffeur_id' => $data['chauffeur_id'],
            'date_depart' => $data['date_depart'],
            'date_arrivee_prevue' => $data['date_arrivee_prevue'] ?? null,
            'date_arrivee_reelle' => null,
            'distance_km' => $data['distance_km'] ?? 0,
            'statut' => 'planifie',
            'notes' => $data['notes'] ?? ''
        ]);
        
        // Update vehicle availability
        $vehiculeModel->updateDisponibilite($data['vehicule_id'], false);
        
        $trajet = $trajetModel->findById($trajetId);
        $this->successResponse($trajet, 'Trajet créé avec succès');
    }
    
    /**
     * Update route (Chauffeur uniquement)
     */
    public function update($id) {
        PermissionMiddleware::checkStrictPermission('trajets', 'update');
        
        $trajetModel = new Trajet();
        $trajet = $trajetModel->findById($id);
        
        if (!$trajet) {
            $this->errorResponse('Trajet non trouvé', 404);
        }
        
        $data = $this->getRequestBody();
        $data = $this->sanitizeInput($data);
        
        // Validate dates if provided
        if (isset($data['date_depart']) && !$this->isValidDateTime($data['date_depart'])) {
            $this->errorResponse('Format de date/heure de départ invalide');
        }
        
        if (isset($data['date_arrivee_prevue']) && !$this->isValidDateTime($data['date_arrivee_prevue'])) {
            $this->errorResponse('Format de date/heure d\'arrivée prévue invalide');
        }
        
        // Check driver availability if changed
        if (isset($data['chauffeur_id']) && $data['chauffeur_id'] != $trajet['chauffeur_id']) {
            $dateCheck = $data['date_depart'] ?? $trajet['date_depart'];
            if ($trajetModel->isChauffeurOccupy($data['chauffeur_id'], $dateCheck, $id)) {
                $this->errorResponse('Le chauffeur est déjà assigné à un autre trajet à cette date');
            }
        }
        
        $trajetModel->update($id, $data);
        $updatedTrajet = $trajetModel->findById($id);
        
        $this->successResponse($updatedTrajet, 'Trajet mis à jour avec succès');
    }
    
    /**
     * Update route status
     */
    public function updateStatut($id) {
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['statut']);
        
        $statut = $this->sanitizeInput($data['statut']);
        $validStatuts = ['planifie', 'en_cours', 'termine', 'annule'];
        
        if (!in_array($statut, $validStatuts)) {
            $this->errorResponse('Statut invalide');
        }
        
        $trajetModel = new Trajet();
        $trajet = $trajetModel->findById($id);
        
        if (!$trajet) {
            $this->errorResponse('Trajet non trouvé', 404);
        }
        
        // Handle status specific actions
        $updateData = ['statut' => $statut];
        
        if ($statut === 'termine') {
            $updateData['date_arrivee_reelle'] = date('Y-m-d H:i:s');
            
            // Free up the vehicle
            require_once 'models/Vehicule.php';
            $vehiculeModel = new Vehicule();
            $vehiculeModel->updateDisponibilite($trajet['vehicule_id'], true);
            
            // Update order status
            require_once 'models/Commande.php';
            $commandeModel = new Commande();
            $commandeModel->updateStatus($trajet['commande_id'], 'livree');
        }
        
        if ($statut === 'annule') {
            // Free up the vehicle
            require_once 'models/Vehicule.php';
            $vehiculeModel = new Vehicule();
            $vehiculeModel->updateDisponibilite($trajet['vehicule_id'], true);
        }
        
        $trajetModel->update($id, $updateData);
        $updatedTrajet = $trajetModel->findById($id);
        
        $this->successResponse($updatedTrajet, 'Statut du trajet mis à jour avec succès');
    }
    
    /**
     * Delete route (Chauffeur uniquement)
     */
    public function delete($id) {
        PermissionMiddleware::checkStrictPermission('trajets', 'delete');
        
        $trajetModel = new Trajet();
        $trajet = $trajetModel->findById($id);
        
        if (!$trajet) {
            $this->errorResponse('Trajet non trouvé', 404);
        }
        
        if ($trajet['statut'] === 'en_cours') {
            $this->errorResponse('Impossible de supprimer un trajet en cours');
        }
        
        // Free up the vehicle if it was reserved
        if ($trajet['statut'] === 'planifie') {
            require_once 'models/Vehicule.php';
            $vehiculeModel = new Vehicule();
            $vehiculeModel->updateDisponibilite($trajet['vehicule_id'], true);
        }
        
        $trajetModel->delete($id);
        $this->successResponse(null, 'Trajet supprimé avec succès');
    }
    
    /**
     * Get route statistics
     */
    public function getStats() {
        $trajetModel = new Trajet();
        $stats = $trajetModel->getStatistics();
        $this->successResponse($stats);
    }
    
    /**
     * Get routes for driver mobile view
     */
    public function getForDriver() {
        $chauffeurId = Auth::getCurrentUserId();
        $trajetModel = new Trajet();
        $trajets = $trajetModel->getByChauffeurId($chauffeurId);
        $this->successResponse($trajets);
    }
    
    /**
     * Validate related entities exist
     */
    private function validateRelatedEntities($data) {
        // Validate order exists
        require_once 'models/Commande.php';
        $commandeModel = new Commande();
        if (!$commandeModel->findById($data['commande_id'])) {
            $this->errorResponse('Commande non trouvée');
        }
        
        // Validate vehicle exists
        require_once 'models/Vehicule.php';
        $vehiculeModel = new Vehicule();
        if (!$vehiculeModel->findById($data['vehicule_id'])) {
            $this->errorResponse('Véhicule non trouvé');
        }
        
        // Validate driver exists
        require_once 'models/User.php';
        $userModel = new User();
        $chauffeur = $userModel->findById($data['chauffeur_id']);
        if (!$chauffeur || $chauffeur['role'] !== 'chauffeur') {
            $this->errorResponse('Chauffeur non trouvé');
        }
    }
    
    /**
     * Validate datetime format
     */
    private function isValidDateTime($datetime) {
        $d = DateTime::createFromFormat('Y-m-d H:i:s', $datetime);
        return $d && $d->format('Y-m-d H:i:s') === $datetime;
    }
}
?>
