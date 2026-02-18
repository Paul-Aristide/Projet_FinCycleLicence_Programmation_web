<?php
namespace App\Controllers;

use App\Controllers\BaseController;
use App\Models\User;
use App\Middleware\AuthMiddleware;

class UserController extends BaseController {

    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
    }

    /**
     * Get all users (admin only)
     */
    public function index() {
        AuthMiddleware::requireRole(['admin']);

        $userModel = new User();
        $users = $userModel->getAll();

        // Remove password from response
        foreach ($users as &$user) {
            unset($user['password']);
        }

        $this->successResponse($users);
    }

    /**
     * Get user by ID (admin only)
     */
    public function show($id) {
        AuthMiddleware::requireRole(['admin']);

        $userModel = new User();
        $user = $userModel->findById($id);

        if (!$user) {
            $this->errorResponse('Utilisateur non trouvé', 404);
        }

        unset($user['password']);
        $this->successResponse($user);
    }

    /**
     * Create new user (admin only)
     */
    public function create() {
        AuthMiddleware::requireRole(['admin']);

        $data = $this->getRequestBody();
        $this->validateRequired($data, ['nom', 'prenom', 'email', 'password', 'role']);

        $data = $this->sanitizeInput($data);

        // Validate email format
        if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            $this->errorResponse('Format d\'email invalide');
        }

        // Validate password length
        if (strlen($data['password']) < PASSWORD_MIN_LENGTH) {
            $this->errorResponse('Le mot de passe doit contenir au moins ' . PASSWORD_MIN_LENGTH . ' caractères');
        }

        // Validate role
        $validRoles = ['admin', 'commercial', 'chauffeur', 'comptabilite'];
        if (!in_array($data['role'], $validRoles)) {
            $this->errorResponse('Rôle invalide');
        }

        // Validate salary if provided
        if (isset($data['salaire']) && (!is_numeric($data['salaire']) || $data['salaire'] < 0)) {
            $this->errorResponse('Le salaire doit être un nombre positif');
        }

        $userModel = new User();

        // Check if email already exists
        if ($userModel->emailExists($data['email'])) {
            $this->errorResponse('Un utilisateur avec cet email existe déjà');
        }

        // Hash password
        $data['password'] = password_hash($data['password'], PASSWORD_DEFAULT);

        $userId = $userModel->create($data);
        $newUser = $userModel->findById($userId);
        unset($newUser['password']);

        $this->successResponse($newUser, 'Utilisateur créé avec succès', 201);
    }

    /**
     * Update user (admin only)
     */
    public function update($id) {
        AuthMiddleware::requireRole(['admin']);

        $data = $this->getRequestBody();
        $data = $this->sanitizeInput($data);

        $userModel = new User();
        $user = $userModel->findById($id);

        if (!$user) {
            $this->errorResponse('Utilisateur non trouvé', 404);
        }

        // Validate email if provided
        if (isset($data['email'])) {
            if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
                $this->errorResponse('Format d\'email invalide');
            }

            if ($userModel->emailExists($data['email'], $id)) {
                $this->errorResponse('Un utilisateur avec cet email existe déjà');
            }
        }

        // Validate role if provided
        if (isset($data['role'])) {
            $validRoles = ['admin', 'commercial', 'chauffeur', 'comptabilite'];
            if (!in_array($data['role'], $validRoles)) {
                $this->errorResponse('Rôle invalide');
            }
        }

        // Validate salary if provided
        if (isset($data['salaire']) && (!is_numeric($data['salaire']) || $data['salaire'] < 0)) {
            $this->errorResponse('Le salaire doit être un nombre positif');
        }

        $userModel->update($id, $data);
        $updatedUser = $userModel->findById($id);
        unset($updatedUser['password']);

        $this->successResponse($updatedUser, 'Utilisateur mis à jour avec succès');
    }

    /**
     * Update user salary (admin only)
     */
    public function updateSalary($id) {
        AuthMiddleware::requireRole(['admin']);

        $data = $this->getRequestBody();
        $this->validateRequired($data, ['salaire']);

        if (!is_numeric($data['salaire']) || $data['salaire'] < 0) {
            $this->errorResponse('Le salaire doit être un nombre positif');
        }

        $userModel = new User();
        $user = $userModel->findById($id);

        if (!$user) {
            $this->errorResponse('Utilisateur non trouvé', 404);
        }

        $userModel->updateSalary($id, $data['salaire']);

        $this->successResponse(null, 'Salaire mis à jour avec succès');
    }

    /**
     * Deactivate user (admin only)
     */
    public function deactivate($id) {
        AuthMiddleware::requireRole(['admin']);

        $userModel = new User();
        $user = $userModel->findById($id);

        if (!$user) {
            $this->errorResponse('Utilisateur non trouvé', 404);
        }

        // Prevent admin from deactivating themselves
        $currentUserId = $_SESSION['user_id'] ?? null;
        if ($id == $currentUserId) {
            $this->errorResponse('Vous ne pouvez pas désactiver votre propre compte');
        }

        $userModel->deactivate($id);

        $this->successResponse(null, 'Utilisateur désactivé avec succès');
    }

    /**
     * Activate user (admin only)
     */
    public function activate($id) {
        AuthMiddleware::requireRole(['admin']);

        $userModel = new User();
        $userModel->activate($id);

        $this->successResponse(null, 'Utilisateur activé avec succès');
    }

    /**
     * Reset user password (admin only)
     */
    public function resetPassword($id) {
        AuthMiddleware::requireRole(['admin']);

        $data = $this->getRequestBody();
        $this->validateRequired($data, ['password']);

        if (strlen($data['password']) < PASSWORD_MIN_LENGTH) {
            $this->errorResponse('Le mot de passe doit contenir au moins ' . PASSWORD_MIN_LENGTH . ' caractères');
        }

        $userModel = new User();
        $user = $userModel->findById($id);

        if (!$user) {
            $this->errorResponse('Utilisateur non trouvé', 404);
        }

        $hashedPassword = password_hash($data['password'], PASSWORD_DEFAULT);
        $userModel->updatePassword($id, $hashedPassword);

        $this->successResponse(null, 'Mot de passe réinitialisé avec succès');
    }

    /**
     * Get users by role (admin only)
     */
    public function getByRole($role) {
        AuthMiddleware::requireRole(['admin']);

        $validRoles = ['admin', 'commercial', 'chauffeur', 'comptabilite'];
        if (!in_array($role, $validRoles)) {
            $this->errorResponse('Rôle invalide');
        }

        $userModel = new User();
        $users = $userModel->getByRole($role);

        $this->successResponse($users);
    }

    /**
     * Search users (admin only)
     */
    public function search() {
        AuthMiddleware::requireRole(['admin']);

        $query = $_GET['q'] ?? '';
        if (strlen($query) < 2) {
            $this->errorResponse('La recherche doit contenir au moins 2 caractères');
        }

        $userModel = new User();
        $users = $userModel->search($query);

        $this->successResponse($users);
    }

    /**
     * Get users statistics (admin only)
     */
    public function getStatistics() {
        AuthMiddleware::requireRole(['admin']);

        $userModel = new User();
        $stats = $userModel->getStatistics();

        // Calculate total statistics
        $totalUsers = 0;
        $totalSalary = 0;

        foreach ($stats as $stat) {
            $totalUsers += $stat['count'];
            $totalSalary += $stat['masse_salariale'];
        }

        $result = [
            'by_role' => $stats,
            'total_users' => $totalUsers,
            'total_salary' => $totalSalary,
            'average_salary' => $totalUsers > 0 ? $totalSalary / $totalUsers : 0
        ];

        $this->successResponse($result);
    }
}