<?php
namespace App\Controllers;

use App\Models\User;
use App\Utils\Auth;
use App\Middleware\AuthMiddleware;

class AuthController extends BaseController {
    
    /**
     * Handle user login
     */
    public function login() {
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['email', 'password']);
        
        $email = $this->sanitizeInput($data['email']);
        $password = $data['password'];
        
        $userModel = new User();
        $user = $userModel->findByEmail($email);
        
        if (!$user || !password_verify($password, $user['password'])) {
            $this->errorResponse('Email ou mot de passe incorrect', 401);
        }
        
        // Update last login
        $userModel->updateLastLogin($user['id']);
        
        // Generate JWT token
        $token = Auth::generateToken($user);
        
        // Set session
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['user_role'] = $user['role'];
        
        $this->successResponse([
            'user' => [
                'id' => $user['id'],
                'nom' => $user['nom'],
                'prenom' => $user['prenom'],
                'email' => $user['email'],
                'role' => $user['role']
            ],
            'token' => $token
        ], 'Connexion réussie');
    }
    
    /**
     * Handle user logout
     */
    public function logout() {
        session_destroy();
        $this->successResponse(null, 'Déconnexion réussie');
    }
    
    /**
     * Get current user info
     */
    public function me() {
        $userId = Auth::getCurrentUserId();
        if (!$userId) {
            $this->errorResponse('Non authentifié', 401);
        }
        
        $userModel = new User();
        $user = $userModel->findById($userId);
        
        if (!$user) {
            $this->errorResponse('Utilisateur non trouvé', 404);
        }
        
        $this->successResponse([
            'id' => $user['id'],
            'nom' => $user['nom'],
            'prenom' => $user['prenom'],
            'email' => $user['email'],
            'role' => $user['role'],
            'derniere_connexion' => $user['derniere_connexion']
        ]);
    }
    
    /**
     * Change password
     */
    public function changePassword() {
        $userId = Auth::getCurrentUserId();
        if (!$userId) {
            $this->errorResponse('Non authentifié', 401);
        }
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['current_password', 'new_password']);
        
        $currentPassword = $data['current_password'];
        $newPassword = $data['new_password'];
        
        if (strlen($newPassword) < PASSWORD_MIN_LENGTH) {
            $this->errorResponse('Le mot de passe doit contenir au moins ' . PASSWORD_MIN_LENGTH . ' caractères');
        }
        
        $userModel = new User();
        $user = $userModel->findById($userId);
        
        if (!password_verify($currentPassword, $user['password'])) {
            $this->errorResponse('Mot de passe actuel incorrect', 401);
        }
        
        $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
        $userModel->updatePassword($userId, $hashedPassword);
        
        $this->successResponse(null, 'Mot de passe modifié avec succès');
    }
    /**
     * Handle user registration
     */
    public function register() {
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['nom', 'prenom', 'email', 'password', 'telephone']);

        $nom = $this->sanitizeInput($data['nom']);
        $prenom = $this->sanitizeInput($data['prenom']);
        $email = $this->sanitizeInput($data['email']);
        $password = $data['password'];
        $telephone = $this->sanitizeInput($data['telephone']);

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->errorResponse('Format d\'email invalide');
        }

        if (strlen($password) < PASSWORD_MIN_LENGTH) {
            $this->errorResponse('Le mot de passe doit contenir au moins ' . PASSWORD_MIN_LENGTH . ' caractères');
        }

        $userModel = new User();
        if ($userModel->emailExists($email)) {
            $this->errorResponse('Cet email est déjà utilisé');
        }

        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

        $userId = $userModel->create([
            'nom' => $nom,
            'prenom' => $prenom,
            'email' => $email,
            'password' => $hashedPassword,
            'telephone' => $telephone,
            'role' => 'commercial' // Rôle par défaut changé pour 'commercial' car 'client' n'est pas dans le schéma de la BDD.
                                   // TODO: Exécuter "ALTER TABLE users MODIFY role enum('admin','commercial','chauffeur','comptabilite','client') NOT NULL DEFAULT 'commercial';" sur la BDD et remettre 'client' ici.
        ]);

        if ($userId) {
            $this->successResponse(['userId' => $userId], 'Inscription réussie', 201);
        } else {
            $this->errorResponse('Erreur lors de l\'inscription');
        }
    }
/**
     * Create a new user (admin only)
     */
    public function createUser() {
        AuthMiddleware::requireRole(['admin']);
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['nom', 'prenom', 'email', 'password', 'role']);
        
        $data = $this->sanitizeInput($data);
        
        if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            $this->errorResponse('Format d\'email invalide');
        }
        
        if (strlen($data['password']) < PASSWORD_MIN_LENGTH) {
            $this->errorResponse('Le mot de passe doit contenir au moins ' . PASSWORD_MIN_LENGTH . ' caractères');
        }
        
        $userModel = new User();
        if ($userModel->emailExists($data['email'])) {
            $this->errorResponse('Un utilisateur avec cet email existe déjà');
        }
        
        $hashedPassword = password_hash($data['password'], PASSWORD_DEFAULT);
        
        $userId = $userModel->create([
            'nom' => $data['nom'],
            'prenom' => $data['prenom'],
            'email' => $data['email'],
            'password' => $hashedPassword,
            'role' => $data['role'],
            'telephone' => $data['telephone'] ?? null
        ]);
        
        $newUser = $userModel->findById($userId);
        unset($newUser['password']); // Do not expose password hash
        
        $this->successResponse($newUser, 'Utilisateur créé avec succès', 201);
    }
}
?>
