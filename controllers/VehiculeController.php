<?php
namespace App\Controllers;

use App\Controllers\BaseController;
use App\Models\Vehicule;
use App\Middleware\AuthMiddleware;

class VehiculeController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
    }
    
    /**
     * Get all vehicles
     */
    public function index() {
        $vehiculeModel = new Vehicule();
        $disponible = $_GET['disponible'] ?? null;
        
        if ($disponible !== null) {
            $vehicules = $vehiculeModel->getByDisponibilite($disponible === '1');
        } else {
            $vehicules = $vehiculeModel->getAll();
        }
        
        $this->successResponse($vehicules);
    }
    
    /**
     * Get vehicle by ID
     */
    public function show($id) {
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($id);
        
        if (!$vehicule) {
            $this->errorResponse('Véhicule non trouvé', 404);
        }
        
        $this->successResponse($vehicule);
    }
    
    /**
     * Create new vehicle
     */
    public function create() {
        AuthMiddleware::requireRole(['admin']);
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['immatriculation', 'marque', 'modele', 'type']);
        
        $data = $this->sanitizeInput($data);
        
        $vehiculeModel = new Vehicule();
        
        // Check if vehicle with same license plate exists
        if ($vehiculeModel->findByImmatriculation($data['immatriculation'])) {
            $this->errorResponse('Un véhicule avec cette immatriculation existe déjà');
        }
        
        // Validate vehicle type
        $validTypes = ['camion', 'camionnette', 'fourgon', 'semi_remorque'];
        if (!in_array($data['type'], $validTypes)) {
            $this->errorResponse('Type de véhicule invalide');
        }
        
        $vehiculeId = $vehiculeModel->create([
            'immatriculation' => strtoupper($data['immatriculation']),
            'marque' => $data['marque'],
            'modele' => $data['modele'],
            'annee' => $data['annee'] ?? null,
            'type' => $data['type'],
            'capacite_poids' => $data['capacite_poids'] ?? 0,
            'capacite_volume' => $data['capacite_volume'] ?? 0,
            'consommation' => $data['consommation'] ?? 0,
            'statut' => $data['statut'] ?? 'actif',
            'disponible' => true,
            'notes' => $data['notes'] ?? ''
        ]);
        
        $vehicule = $vehiculeModel->findById($vehiculeId);
        $this->successResponse($vehicule, 'Véhicule créé avec succès');
    }
    
    /**
     * Update vehicle
     */
    public function update($id) {
        AuthMiddleware::requireRole(['admin']);
        
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($id);
        
        if (!$vehicule) {
            $this->errorResponse('Véhicule non trouvé', 404);
        }
        
        $data = $this->getRequestBody();
        $data = $this->sanitizeInput($data);
        
        // Check license plate uniqueness if changed
        if (isset($data['immatriculation'])) {
            $data['immatriculation'] = strtoupper($data['immatriculation']);
            if ($data['immatriculation'] !== $vehicule['immatriculation']) {
                if ($vehiculeModel->findByImmatriculation($data['immatriculation'])) {
                    $this->errorResponse('Un véhicule avec cette immatriculation existe déjà');
                }
            }
        }
        
        // Validate vehicle type if provided
        if (isset($data['type'])) {
            $validTypes = ['camion', 'camionnette', 'fourgon', 'semi_remorque'];
            if (!in_array($data['type'], $validTypes)) {
                $this->errorResponse('Type de véhicule invalide');
            }
        }
        
        $vehiculeModel->update($id, $data);
        $updatedVehicule = $vehiculeModel->findById($id);
        
        $this->successResponse($updatedVehicule, 'Véhicule mis à jour avec succès');
    }
    
    /**
     * Update vehicle availability
     */
    public function updateDisponibilite($id) {
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['disponible']);
        
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($id);
        
        if (!$vehicule) {
            $this->errorResponse('Véhicule non trouvé', 404);
        }
        
        $disponible = (bool)$data['disponible'];
        $vehiculeModel->updateDisponibilite($id, $disponible);
        
        $updatedVehicule = $vehiculeModel->findById($id);
        $this->successResponse($updatedVehicule, 'Disponibilité mise à jour avec succès');
    }
    
    /**
     * Delete vehicle
     */
    public function delete($id) {
        AuthMiddleware::requireRole(['admin']);
        
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($id);
        
        if (!$vehicule) {
            $this->errorResponse('Véhicule non trouvé', 404);
        }
        
        // Check if vehicle has active routes
        require_once 'models/Trajet.php';
        $trajetModel = new Trajet();
        $activeTrajets = $trajetModel->getActiveByVehiculeId($id);
        
        if (!empty($activeTrajets)) {
            $this->errorResponse('Impossible de supprimer un véhicule avec des trajets en cours');
        }
        
        $vehiculeModel->delete($id);
        $this->successResponse(null, 'Véhicule supprimé avec succès');
    }
    
    /**
     * Get vehicle maintenance history
     */
    public function maintenanceHistory($id) {
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($id);
        
        if (!$vehicule) {
            $this->errorResponse('Véhicule non trouvé', 404);
        }
        
        $maintenances = $vehiculeModel->getMaintenanceHistory($id);
        $this->successResponse($maintenances);
    }
    
    /**
     * Add maintenance record
     */
    public function addMaintenance($id) {
        AuthMiddleware::requireRole(['admin']);
        
        $vehiculeModel = new Vehicule();
        $vehicule = $vehiculeModel->findById($id);
        
        if (!$vehicule) {
            $this->errorResponse('Véhicule non trouvé', 404);
        }
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['date_maintenance', 'type_maintenance', 'cout']);
        
        $data = $this->sanitizeInput($data);
        
        if (!$this->isValidDate($data['date_maintenance'])) {
            $this->errorResponse('Format de date invalide (YYYY-MM-DD attendu)');
        }
        
        $maintenanceId = $vehiculeModel->addMaintenance($id, [
            'date_maintenance' => $data['date_maintenance'],
            'type_maintenance' => $data['type_maintenance'],
            'description' => $data['description'] ?? '',
            'cout' => $data['cout'],
            'garage' => $data['garage'] ?? ''
        ]);
        
        $this->successResponse(['id' => $maintenanceId], 'Maintenance ajoutée avec succès');
    }
    
    /**
     * Get vehicle statistics
     */
    public function getStats() {
        $vehiculeModel = new Vehicule();
        $stats = $vehiculeModel->getStatistics();
        $this->successResponse($stats);
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
