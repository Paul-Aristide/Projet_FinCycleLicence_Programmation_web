<?php
session_start();
// API routing system for Mini-ERP

use App\Controllers\AuthController;
use App\Controllers\ClientController;
use App\Controllers\ClientTrackingController;
use App\Controllers\CommandeController;
use App\Controllers\DashboardController;
use App\Controllers\FactureController;
use App\Controllers\PlanificationController;
use App\Controllers\TrajetController;
use App\Controllers\TransactionsController;
use App\Controllers\VehiculeController;
use App\Controllers\UserController;

// Remove the /api prefix from the URI
$uri = str_replace('/api', '', $uri);
$method = $_SERVER['REQUEST_METHOD'];

// Handle preflight OPTIONS requests
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Auth routes
    if ($uri === '/auth/login' && $method === 'POST') {
        $controller = new AuthController();
        $controller->login();
    }

    elseif ($uri === '/auth/register' && $method === 'POST') {
        $controller = new AuthController();
        $controller->register();
    }
    
    elseif ($uri === '/auth/logout' && $method === 'POST') {
        $controller = new AuthController();
        $controller->logout();
    }
    
    elseif ($uri === '/auth/me' && $method === 'GET') {
        $controller = new AuthController();
        $controller->me();
    }
    
    elseif ($uri === '/auth/change-password' && $method === 'POST') {
        $controller = new AuthController();
        $controller->changePassword();
    }
    
    // Dashboard routes
    elseif ($uri === '/dashboard/stats' && $method === 'GET') {
        $controller = new DashboardController();
        $controller->getStats();
    }
    
    elseif ($uri === '/dashboard/activities' && $method === 'GET') {
        $controller = new DashboardController();
        $controller->getRecentActivities();
    }
    
    elseif ($uri === '/dashboard/notifications' && $method === 'GET') {
        $controller = new DashboardController();
        $controller->getNotifications();
    }

    elseif ($uri === '/dashboard/revenue-evolution' && $method === 'GET') {
        $controller = new DashboardController();
        $controller->getRevenueEvolution();
    }

    // Client tracking routes
    elseif ($uri === '/client/login' && $method === 'POST') {
        $controller = new ClientTrackingController();
        $controller->login();
    }

    elseif ($uri === '/client/logout' && $method === 'POST') {
        $controller = new ClientTrackingController();
        $controller->logout();
    }

    elseif ($uri === '/client/info' && $method === 'GET') {
        $controller = new ClientTrackingController();
        $controller->getClientInfo();
    }

    elseif ($uri === '/client/shipments' && $method === 'GET') {
        $controller = new ClientTrackingController();
        $controller->getMyShipments();
    }

    elseif (preg_match('/^\/client\/shipments\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new ClientTrackingController();
        $controller->getShipmentDetails($matches[1]);
    }
    
    // Client routes
    elseif ($uri === '/clients' && $method === 'GET') {
        $controller = new ClientController();
        $controller->index();
    }
    
    elseif ($uri === '/clients' && $method === 'POST') {
        $controller = new ClientController();
        $controller->create();
    }
    
    elseif ($uri === '/clients/search' && $method === 'GET') {
        $controller = new ClientController();
        $controller->search();
    }
    
    elseif (preg_match('/^\/clients\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new ClientController();
        $controller->show($matches[1]);
    }
    
    elseif (preg_match('/^\/clients\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new ClientController();
        $controller->update($matches[1]);
    }
    
    elseif (preg_match('/^\/clients\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new ClientController();
        $controller->delete($matches[1]);
    }
    
    elseif (preg_match('/^\/clients\/(\d+)\/orders$/', $uri, $matches) && $method === 'GET') {
        $controller = new ClientController();
        $controller->orderHistory($matches[1]);
    }
    
    // Order routes
    elseif ($uri === '/commandes' && $method === 'GET') {
        $controller = new CommandeController();
        $controller->index();
    }
    
    elseif ($uri === '/commandes' && $method === 'POST') {
        $controller = new CommandeController();
        $controller->create();
    }
    
    elseif ($uri === '/commandes/stats' && $method === 'GET') {
        $controller = new CommandeController();
        $controller->getStats();
    }
    
    elseif (preg_match('/^\/commandes\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new CommandeController();
        $controller->show($matches[1]);
    }
    
    elseif (preg_match('/^\/commandes\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new CommandeController();
        $controller->update($matches[1]);
    }
    
    elseif (preg_match('/^\/commandes\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new CommandeController();
        $controller->delete($matches[1]);
    }
    
    elseif (preg_match('/^\/commandes\/(\d+)\/status$/', $uri, $matches) && $method === 'PUT') {
        $controller = new CommandeController();
        $controller->updateStatus($matches[1]);
    }

    // Nouvelles routes workflow commandes
    elseif (preg_match('/^\/commandes\/(\d+)\/validate$/', $uri, $matches) && $method === 'POST') {
        $controller = new CommandeController();
        $controller->validate($matches[1]);
    }

    elseif (preg_match('/^\/commandes\/(\d+)\/reject$/', $uri, $matches) && $method === 'POST') {
        $controller = new CommandeController();
        $controller->reject($matches[1]);
    }

    elseif ($uri === '/commandes/calculate-tariff' && $method === 'POST') {
        $controller = new CommandeController();
        $controller->calculateTariff();
    }

    elseif ($uri === '/commandes/pending-validation' && $method === 'GET') {
        $controller = new CommandeController();
        $controller->getPendingValidation();
    }

    // Vehicle routes
    elseif ($uri === '/vehicules' && $method === 'GET') {
        $controller = new VehiculeController();
        $controller->index();
    }
    
    elseif ($uri === '/vehicules' && $method === 'POST') {
        $controller = new VehiculeController();
        $controller->create();
    }
    
    elseif ($uri === '/vehicules/stats' && $method === 'GET') {
        $controller = new VehiculeController();
        $controller->getStats();
    }
    
    elseif (preg_match('/^\/vehicules\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new VehiculeController();
        $controller->show($matches[1]);
    }
    
    elseif (preg_match('/^\/vehicules\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new VehiculeController();
        $controller->update($matches[1]);
    }
    
    elseif (preg_match('/^\/vehicules\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new VehiculeController();
        $controller->delete($matches[1]);
    }
    
    elseif (preg_match('/^\/vehicules\/(\d+)\/disponibilite$/', $uri, $matches) && $method === 'PUT') {
        $controller = new VehiculeController();
        $controller->updateDisponibilite($matches[1]);
    }
    
    elseif (preg_match('/^\/vehicules\/(\d+)\/maintenance$/', $uri, $matches) && $method === 'GET') {
        $controller = new VehiculeController();
        $controller->maintenanceHistory($matches[1]);
    }
    
    elseif (preg_match('/^\/vehicules\/(\d+)\/maintenance$/', $uri, $matches) && $method === 'POST') {
        $controller = new VehiculeController();
        $controller->addMaintenance($matches[1]);
    }
    
    // Route routes
    elseif ($uri === '/trajets' && $method === 'GET') {
        $controller = new TrajetController();
        $controller->index();
    }
    
    elseif ($uri === '/trajets' && $method === 'POST') {
        $controller = new TrajetController();
        $controller->create();
    }
    
    elseif ($uri === '/trajets/stats' && $method === 'GET') {
        $controller = new TrajetController();
        $controller->getStats();
    }
    
    elseif ($uri === '/trajets/driver' && $method === 'GET') {
        $controller = new TrajetController();
        $controller->getForDriver();
    }
    
    elseif (preg_match('/^\/trajets\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new TrajetController();
        $controller->show($matches[1]);
    }
    
    elseif (preg_match('/^\/trajets\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new TrajetController();
        $controller->update($matches[1]);
    }
    
    elseif (preg_match('/^\/trajets\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new TrajetController();
        $controller->delete($matches[1]);
    }
    
    elseif (preg_match('/^\/trajets\/(\d+)\/status$/', $uri, $matches) && $method === 'PUT') {
        $controller = new TrajetController();
        $controller->updateStatut($matches[1]);
    }
    
    // Invoice routes
    elseif ($uri === '/factures' && $method === 'GET') {
        $controller = new FactureController();
        $controller->index();
    }
    
    elseif ($uri === '/factures' && $method === 'POST') {
        $controller = new FactureController();
        $controller->create();
    }
    
    elseif ($uri === '/factures/stats' && $method === 'GET') {
        $controller = new FactureController();
        $controller->getStats();
    }
    
    elseif ($uri === '/factures/overdue' && $method === 'GET') {
        $controller = new FactureController();
        $controller->getOverdue();
    }
    
    elseif ($uri === '/factures/export' && $method === 'GET') {
        $controller = new FactureController();
        $controller->exportComptabilite();
    }
    
    elseif (preg_match('/^\/factures\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new FactureController();
        $controller->show($matches[1]);
    }
    
    elseif (preg_match('/^\/factures\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new FactureController();
        $controller->update($matches[1]);
    }
    
    elseif (preg_match('/^\/factures\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new FactureController();
        $controller->delete($matches[1]);
    }
    
    elseif (preg_match('/^\/factures\/(\d+)\/status$/', $uri, $matches) && $method === 'PUT') {
        $controller = new FactureController();
        $controller->updateStatut($matches[1]);
    }
    
    elseif (preg_match('/^\/factures\/(\d+)\/pdf$/', $uri, $matches) && $method === 'GET') {
        $controller = new FactureController();
        $controller->generatePDF($matches[1]);
    }

    // Planification routes (comptable only)
    elseif ($uri === '/planification' && $method === 'GET') {
        $controller = new PlanificationController();
        $controller->index();
    }

    elseif ($uri === '/planification' && $method === 'POST') {
        $controller = new PlanificationController();
        $controller->create();
    }

    elseif ($uri === '/planification/budget' && $method === 'GET') {
        $controller = new PlanificationController();
        $controller->getBudgetPrevisionnel();
    }

    elseif ($uri === '/planification/export' && $method === 'GET') {
        $controller = new PlanificationController();
        $controller->export();
    }

    elseif ($uri === '/planification/date-range' && $method === 'GET') {
        $controller = new PlanificationController();
        $controller->getByDateRange();
    }

    elseif (preg_match('/^\/planification\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new PlanificationController();
        $controller->show($matches[1]);
    }

    elseif (preg_match('/^\/planification\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new PlanificationController();
        $controller->update($matches[1]);
    }

    elseif (preg_match('/^\/planification\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new PlanificationController();
        $controller->delete($matches[1]);
    }

    // Transactions routes (comptable only)
    elseif ($uri === '/transactions' && $method === 'GET') {
        $controller = new TransactionsController();
        $controller->index();
    }

    elseif ($uri === '/transactions' && $method === 'POST') {
        $controller = new TransactionsController();
        $controller->create();
    }

    elseif ($uri === '/transactions/stats' && $method === 'GET') {
        $controller = new TransactionsController();
        $controller->getStats();
    }

    elseif ($uri === '/transactions/export' && $method === 'GET') {
        $controller = new TransactionsController();
        $controller->export();
    }

    elseif (preg_match('/^\/transactions\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new TransactionsController();
        $controller->show($matches[1]);
    }

    elseif (preg_match('/^\/transactions\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new TransactionsController();
        $controller->update($matches[1]);
    }

    elseif (preg_match('/^\/transactions\/(\d+)$/', $uri, $matches) && $method === 'DELETE') {
        $controller = new TransactionsController();
        $controller->delete($matches[1]);
    }

    // User management routes (admin only)
    elseif ($uri === '/users' && $method === 'GET') {
        $controller = new UserController();
        $controller->index();
    }

    elseif ($uri === '/users' && $method === 'POST') {
        $controller = new UserController();
        $controller->create();
    }

    elseif ($uri === '/users/statistics' && $method === 'GET') {
        $controller = new UserController();
        $controller->getStatistics();
    }

    elseif ($uri === '/users/search' && $method === 'GET') {
        $controller = new UserController();
        $controller->search();
    }

    elseif (preg_match('/^\/users\/role\/([a-zA-Z]+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new UserController();
        $controller->getByRole($matches[1]);
    }

    elseif (preg_match('/^\/users\/(\d+)$/', $uri, $matches) && $method === 'GET') {
        $controller = new UserController();
        $controller->show($matches[1]);
    }

    elseif (preg_match('/^\/users\/(\d+)$/', $uri, $matches) && $method === 'PUT') {
        $controller = new UserController();
        $controller->update($matches[1]);
    }

    elseif (preg_match('/^\/users\/(\d+)\/salary$/', $uri, $matches) && $method === 'PUT') {
        $controller = new UserController();
        $controller->updateSalary($matches[1]);
    }

    elseif (preg_match('/^\/users\/(\d+)\/reset-password$/', $uri, $matches) && $method === 'PUT') {
        $controller = new UserController();
        $controller->resetPassword($matches[1]);
    }

    elseif (preg_match('/^\/users\/(\d+)\/deactivate$/', $uri, $matches) && $method === 'PUT') {
        $controller = new UserController();
        $controller->deactivate($matches[1]);
    }

    elseif (preg_match('/^\/users\/(\d+)\/activate$/', $uri, $matches) && $method === 'PUT') {
        $controller = new UserController();
        $controller->activate($matches[1]);
    }
    
    else {
        // Route not found
        http_response_code(404);
        echo json_encode(['error' => 'Route API non trouvée']);
    }
    
} catch (Exception $e) {
    // Handle exceptions
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => APP_ENV === 'development' ? $e->getMessage() : 'Une erreur inattendue s\'est produite'
    ]);
}
?>
