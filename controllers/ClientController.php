<?php
namespace App\Controllers;

use App\Models\Client;
use App\Models\Commande;
use App\Middleware\AuthMiddleware;
use App\Middleware\PermissionMiddleware;

class ClientController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
    }
    
    /**
     * Get all clients (Commercial + Comptable + Admin lecture)
     */
    public function index() {
        PermissionMiddleware::checkStrictPermission('clients', 'read');
        $clientModel = new Client();
        $clients = $clientModel->getAll();
        $this->successResponse($clients);
    }
    
    /**
     * Get client by ID
     */
    public function show($id) {
        PermissionMiddleware::checkStrictPermission('clients', 'read');
        $clientModel = new Client();
        $client = $clientModel->findById($id);
        
        if (!$client) {
            $this->errorResponse('Client non trouvé', 404);
        }
        
        $this->successResponse($client);
    }
    
    /**
     * Create new client (Commercial uniquement)
     */
    public function create() {
        PermissionMiddleware::checkStrictPermission('clients', 'create');
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['nom', 'email', 'telephone']);
        
        $data = $this->sanitizeInput($data);
        
        // Validate email format
        if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            $this->errorResponse('Format d\'email invalide');
        }
        
        $clientModel = new Client();
        
        // Check if client already exists
        if ($clientModel->findByEmail($data['email'])) {
            $this->errorResponse('Un client avec cet email existe déjà');
        }
        
        $clientId = $clientModel->create([
            'nom' => $data['nom'],
            'prenom' => $data['prenom'] ?? '',
            'entreprise' => $data['entreprise'] ?? '',
            'email' => $data['email'],
            'telephone' => $data['telephone'],
            'adresse' => $data['adresse'] ?? '',
            'ville' => $data['ville'] ?? '',
            'code_postal' => $data['code_postal'] ?? '',
            'notes' => $data['notes'] ?? ''
        ]);
        
        $client = $clientModel->findById($clientId);
        $this->successResponse($client, 'Client créé avec succès');
    }
    
    /**
     * Update client (Commercial uniquement)
     */
    public function update($id) {
        PermissionMiddleware::checkStrictPermission('clients', 'update');
        
        $clientModel = new Client();
        $client = $clientModel->findById($id);
        
        if (!$client) {
            $this->errorResponse('Client non trouvé', 404);
        }
        
        $data = $this->getRequestBody();
        $data = $this->sanitizeInput($data);
        
        // Validate email if provided
        if (isset($data['email']) && !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            $this->errorResponse('Format d\'email invalide');
        }
        
        // Check email uniqueness if changed
        if (isset($data['email']) && $data['email'] !== $client['email']) {
            if ($clientModel->findByEmail($data['email'])) {
                $this->errorResponse('Un client avec cet email existe déjà');
            }
        }
        
        $clientModel->update($id, $data);
        $updatedClient = $clientModel->findById($id);
        
        $this->successResponse($updatedClient, 'Client mis à jour avec succès');
    }
    
    /**
     * Delete client (Commercial uniquement)
     */
    public function delete($id) {
        PermissionMiddleware::checkStrictPermission('clients', 'delete');
        
        $clientModel = new Client();
        $client = $clientModel->findById($id);
        
        if (!$client) {
            $this->errorResponse('Client non trouvé', 404);
        }
        
        // Check if client has active orders
        require_once 'models/Commande.php';
        $commandeModel = new Commande();
        $activeOrders = $commandeModel->getActiveOrdersByClient($id);
        
        if (!empty($activeOrders)) {
            $this->errorResponse('Impossible de supprimer un client avec des commandes en cours');
        }
        
        $clientModel->delete($id);
        $this->successResponse(null, 'Client supprimé avec succès');
    }
    
    /**
     * Get client's order history
     */
    public function orderHistory($id) {
        $clientModel = new Client();
        $client = $clientModel->findById($id);
        
        if (!$client) {
            $this->errorResponse('Client non trouvé', 404);
        }
        
        require_once 'models/Commande.php';
        $commandeModel = new Commande();
        $orders = $commandeModel->getByClientId($id);
        
        $this->successResponse($orders);
    }
    
    /**
     * Search clients
     */
    public function search() {
        $query = $_GET['q'] ?? '';
        
        if (strlen($query) < 2) {
            $this->errorResponse('La recherche doit contenir au moins 2 caractères');
        }
        
        $clientModel = new Client();
        $clients = $clientModel->search($query);
        
        $this->successResponse($clients);
    }
}
?>
