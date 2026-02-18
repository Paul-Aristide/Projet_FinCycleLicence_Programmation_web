<?php
namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Models\Client;
use App\Models\Commande;
use App\Models\Facture;
use App\Models\Trajet;
use App\Models\Vehicule;
use Exception;

class DashboardController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
    }
    
    /**
     * Get dashboard statistics
     */
    public function getStats() {
        $stats = [];
        
        // Get user role to customize dashboard
        $userRole = $_SESSION['user_role'] ?? 'admin';
        
        try {
            // Common statistics
            $stats['commandes'] = $this->getCommandeStats();
            $stats['vehicules'] = $this->getVehiculeStats();
            
            // Role-specific statistics
            if (in_array($userRole, ['admin', 'commercial'])) {
                $stats['clients'] = $this->getClientStats();
                $stats['trajets'] = $this->getTrajetStats();
            }
            
            if (in_array($userRole, ['admin', 'comptabilite'])) {
                $stats['factures'] = $this->getFactureStats();
                $stats['revenus'] = $this->getRevenuStats();
            }

            // Admin-only financial statistics
            if ($userRole === 'admin') {
                $stats['depenses'] = $this->getDepenseStats();
                $stats['salaires'] = $this->getSalaireStats();
                $stats['revenus_quotidiens'] = $this->getRevenuQuotidienStats();
            }
            
            if ($userRole === 'chauffeur') {
                $stats['mes_trajets'] = $this->getMesTrajetsStats();
            }
            
            $this->successResponse($stats);
            
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du chargement des statistiques: ' . $e->getMessage(), 500);
        }
    }
    
    /**
     * Get recent activities
     */
    public function getRecentActivities() {
        $activities = [];
        $userRole = $_SESSION['user_role'] ?? 'admin';
        $limit = $_GET['limit'] ?? 10;
        
        try {
            if (in_array($userRole, ['admin', 'commercial'])) {
                $activities = array_merge($activities, $this->getRecentCommandes($limit));
                $activities = array_merge($activities, $this->getRecentTrajets($limit));
            }
            
            if (in_array($userRole, ['admin', 'comptabilite'])) {
                $activities = array_merge($activities, $this->getRecentFactures($limit));
            }
            
            // Sort by date
            usort($activities, function($a, $b) {
                return strtotime($b['date']) - strtotime($a['date']);
            });
            
            $activities = array_slice($activities, 0, $limit);
            
            $this->successResponse($activities);
            
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du chargement des activités: ' . $e->getMessage(), 500);
        }
    }
    
    /**
     * Get notifications
     */
    public function getNotifications() {
        $notifications = [];
        $userRole = $_SESSION['user_role'] ?? 'admin';
        
        try {
            // Vehicle maintenance alerts
            if (in_array($userRole, ['admin'])) {
                $notifications = array_merge($notifications, $this->getMaintenanceAlerts());
            }
            
            // Overdue invoices
            if (in_array($userRole, ['admin', 'comptabilite'])) {
                $notifications = array_merge($notifications, $this->getOverdueInvoiceAlerts());
            }
            
            // Late deliveries
            if (in_array($userRole, ['admin', 'commercial'])) {
                $notifications = array_merge($notifications, $this->getLateDeliveryAlerts());
            }
            
            $this->successResponse($notifications);
            
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du chargement des notifications: ' . $e->getMessage(), 500);
        }
    }
    
    /**
     * Get order statistics
     */
    private function getCommandeStats() {
        require_once 'models/Commande.php';
        $commandeModel = new Commande();
        
        return [
            'total' => $commandeModel->count(),
            'en_attente' => $commandeModel->countByStatus('en_attente'),
            'en_cours' => $commandeModel->countByStatus('en_cours'),
            'livrees' => $commandeModel->countByStatus('livree'),
            'ce_mois' => $commandeModel->countThisMonth()
        ];
    }
    
    /**
     * Get vehicle statistics
     */
    private function getVehiculeStats() {
        require_once 'models/Vehicule.php';
        $vehiculeModel = new Vehicule();
        
        return [
            'total' => $vehiculeModel->count(),
            'disponibles' => $vehiculeModel->countAvailable(),
            'en_mission' => $vehiculeModel->countInUse(),
            'maintenance' => $vehiculeModel->countInMaintenance()
        ];
    }
    
    /**
     * Get client statistics
     */
    private function getClientStats() {
        require_once 'models/Client.php';
        $clientModel = new Client();
        
        return [
            'total' => $clientModel->count(),
            'actifs' => $clientModel->countActive(),
            'nouveaux_ce_mois' => $clientModel->countNewThisMonth()
        ];
    }
    
    /**
     * Get route statistics
     */
    private function getTrajetStats() {
        require_once 'models/Trajet.php';
        $trajetModel = new Trajet();
        
        return [
            'total' => $trajetModel->count(),
            'planifies' => $trajetModel->countByStatus('planifie'),
            'en_cours' => $trajetModel->countByStatus('en_cours'),
            'termines' => $trajetModel->countByStatus('termine')
        ];
    }
    
    /**
     * Get invoice statistics
     */
    private function getFactureStats() {
        require_once 'models/Facture.php';
        $factureModel = new Facture();
        
        return [
            'total' => $factureModel->count(),
            'brouillons' => $factureModel->countByStatus('brouillon'),
            'envoyees' => $factureModel->countByStatus('envoyee'),
            'payees' => $factureModel->countByStatus('payee'),
            'en_retard' => $factureModel->countOverdue()
        ];
    }
    
    /**
     * Get revenue statistics
     */
    private function getRevenuStats() {
        require_once 'models/Facture.php';
        $factureModel = new Facture();
        
        return [
            'ca_mois' => $factureModel->getMonthlyRevenue(),
            'ca_annee' => $factureModel->getYearlyRevenue(),
            'en_attente' => $factureModel->getPendingAmount(),
            'croissance' => $factureModel->getGrowthRate()
        ];
    }
    
    /**
     * Get driver's route statistics
     */
    private function getMesTrajetsStats() {
        $chauffeurId = $_SESSION['user_id'];
        require_once 'models/Trajet.php';
        $trajetModel = new Trajet();

        $planifies = $trajetModel->countByChauffeurAndStatus($chauffeurId, 'planifie');
        $en_cours = $trajetModel->countByChauffeurAndStatus($chauffeurId, 'en_cours');
        $termines = $trajetModel->countByChauffeurAndStatus($chauffeurId, 'termine');
        $annules = $trajetModel->countByChauffeurAndStatus($chauffeurId, 'annule');
        $km_ce_mois = $trajetModel->getKmByChauffeurThisMonth($chauffeurId);
        $termines_ce_mois = $trajetModel->countByChauffeurThisMonth($chauffeurId);

        // Calcul de la ponctualité (exemple simple : % de trajets terminés sur total planifiés ce mois)
        $total_trajets = $planifies + $en_cours + $termines + $annules;
        $ponctualite = ($total_trajets > 0) ? round(($termines / $total_trajets) * 100, 1) : 0;

        return array(
            'planifies' => $planifies,
            'en_cours' => $en_cours,
            'termines' => $termines,
            'annules' => $annules,
            'km_ce_mois' => $km_ce_mois,
            'termines_ce_mois' => $termines_ce_mois,
            'ponctualite' => $ponctualite
        );
    }
    
    /**
     * Get recent orders
     */
    private function getRecentCommandes($limit) {
        require_once 'models/Commande.php';
        $commandeModel = new Commande();
        $commandes = $commandeModel->getRecent($limit);
        
        $activities = [];
        foreach ($commandes as $commande) {
            $activities[] = [
                'type' => 'commande',
                'title' => 'Nouvelle commande #' . $commande['numero_commande'],
                'description' => 'Client: ' . $commande['client_nom'],
                'date' => $commande['date_creation'],
                'status' => $commande['statut']
            ];
        }
        
        return $activities;
    }
    
    /**
     * Get recent routes
     */
    private function getRecentTrajets($limit) {
        require_once 'models/Trajet.php';
        $trajetModel = new Trajet();
        $trajets = $trajetModel->getRecent($limit);
        
        $activities = [];
        foreach ($trajets as $trajet) {
            $activities[] = [
                'type' => 'trajet',
                'title' => 'Trajet planifié',
                'description' => 'Chauffeur: ' . $trajet['chauffeur_nom'] . ', Véhicule: ' . $trajet['vehicule_immat'],
                'date' => $trajet['date_depart'],
                'status' => $trajet['statut']
            ];
        }
        
        return $activities;
    }
    
    /**
     * Get recent invoices
     */
    private function getRecentFactures($limit) {
        require_once 'models/Facture.php';
        $factureModel = new Facture();
        $factures = $factureModel->getRecent($limit);
        
        $activities = [];
        foreach ($factures as $facture) {
            $activities[] = [
                'type' => 'facture',
                'title' => 'Facture #' . $facture['numero_facture'],
                'description' => 'Client: ' . $facture['client_nom'] . ', Montant: ' . number_format($facture['montant_ttc'], 2) . '€',
                'date' => $facture['date_facture'],
                'status' => $facture['statut']
            ];
        }
        
        return $activities;
    }
    
    /**
     * Get maintenance alerts
     */
    private function getMaintenanceAlerts() {
        require_once 'models/Vehicule.php';
        $vehiculeModel = new Vehicule();
        $vehicles = $vehiculeModel->getMaintenanceAlerts();
        
        $alerts = [];
        foreach ($vehicles as $vehicle) {
            $alerts[] = [
                'type' => 'warning',
                'title' => 'Maintenance requise',
                'message' => 'Véhicule ' . $vehicle['immatriculation'] . ' nécessite une maintenance',
                'date' => date('Y-m-d H:i:s')
            ];
        }
        
        return $alerts;
    }
    
    /**
     * Get overdue invoice alerts
     */
    private function getOverdueInvoiceAlerts() {
        require_once 'models/Facture.php';
        $factureModel = new Facture();
        $overdueCount = $factureModel->countOverdue();
        
        $alerts = [];
        if ($overdueCount > 0) {
            $alerts[] = [
                'type' => 'danger',
                'title' => 'Factures en retard',
                'message' => $overdueCount . ' facture(s) en retard de paiement',
                'date' => date('Y-m-d H:i:s')
            ];
        }
        
        return $alerts;
    }
    
    /**
     * Get late delivery alerts
     */
    private function getLateDeliveryAlerts() {
        require_once 'models/Trajet.php';
        $trajetModel = new Trajet();
        $lateTrajets = $trajetModel->getLateDeliveries();
        
        $alerts = [];
        foreach ($lateTrajets as $trajet) {
            $alerts[] = [
                'type' => 'warning',
                'title' => 'Livraison en retard',
                'message' => 'Trajet prévu pour ' . date('d/m/Y', strtotime($trajet['date_arrivee_prevue'])),
                'date' => date('Y-m-d H:i:s')
            ];
        }
        
        return $alerts;
    }

    /**
     * Get expense statistics
     */
    private function getDepenseStats() {
        $db = $this->db;

        // Get current month expenses
        $currentMonth = date('Y-m');

        // Maintenance costs
        $maintenanceQuery = "SELECT COALESCE(SUM(cout), 0) as total FROM maintenances
                           WHERE DATE_FORMAT(date_maintenance, '%Y-%m') = ?";
        $maintenance = $db->fetch($maintenanceQuery, [$currentMonth])['total'];

        // Salary costs from transactions
        $salaireQuery = "SELECT COALESCE(SUM(montant), 0) as total FROM transactions
                        WHERE type = 'salaire' AND DATE_FORMAT(date_transaction, '%Y-%m') = ?";
        $salaires = $db->fetch($salaireQuery, [$currentMonth])['total'];

        // Fuel costs from transactions
        $carburantQuery = "SELECT COALESCE(SUM(montant), 0) as total FROM transactions
                          WHERE type = 'carburant' AND DATE_FORMAT(date_transaction, '%Y-%m') = ?";
        $carburant = $db->fetch($carburantQuery, [$currentMonth])['total'];

        // Other expenses from transactions
        $autresQuery = "SELECT COALESCE(SUM(montant), 0) as total FROM transactions
                       WHERE type NOT IN ('salaire', 'carburant', 'paiement_client')
                       AND DATE_FORMAT(date_transaction, '%Y-%m') = ?";
        $autres = $db->fetch($autresQuery, [$currentMonth])['total'];

        // Insurance estimate (fixed monthly cost)
        $assurance = 500000; // 500,000 F CFA per month estimate

        return [
            'total_mois' => $maintenance + $salaires + $carburant + $assurance + $autres,
            'maintenance' => $maintenance,
            'salaires' => $salaires,
            'carburant' => $carburant,
            'assurance' => $assurance,
            'autres' => $autres
        ];
    }

    /**
     * Get salary statistics
     */
    private function getSalaireStats() {
        $db = $this->db;

        // Get total monthly salaries from users table
        $salaireQuery = "SELECT COALESCE(SUM(salaire), 0) as total_mensuel, COUNT(*) as nombre_employes
                        FROM users WHERE actif = 1";
        $result = $db->fetch($salaireQuery);

        return [
            'total_mensuel' => $result['total_mensuel'],
            'nombre_employes' => $result['nombre_employes']
        ];
    }

    /**
     * Get daily revenue evolution statistics
     */
    private function getRevenuQuotidienStats() {
        $db = $this->db;
        $period = $_GET['period'] ?? '30'; // Default 30 days

        $query = "SELECT DATE(date_facture) as date, COALESCE(SUM(montant_ttc), 0) as montant
                 FROM factures
                 WHERE statut = 'payee'
                 AND date_facture >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
                 GROUP BY DATE(date_facture)
                 ORDER BY date ASC";

        $results = $db->fetchAll($query, [$period]);

        $dates = [];
        $montants = [];

        foreach ($results as $result) {
            $dates[] = date('d/m', strtotime($result['date']));
            $montants[] = (float)$result['montant'];
        }

        return [
            'dates' => $dates,
            'montants' => $montants
        ];
    }

    /**
     * Get revenue evolution for specific period (API endpoint)
     */
    public function getRevenueEvolution() {
        $period = $_GET['period'] ?? '30';

        try {
            $data = $this->getRevenuQuotidienStats();
            $this->successResponse(['data' => $data]);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du chargement des données de revenus: ' . $e->getMessage(), 500);
        }
    }
}
?>
