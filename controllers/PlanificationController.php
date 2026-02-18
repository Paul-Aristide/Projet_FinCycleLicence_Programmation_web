<?php
namespace App\Controllers;

use App\Models\Planification;
use App\Models\Facture;
use App\Utils\Auth;
use App\Middleware\AuthMiddleware;

class PlanificationController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();

        // Vérifier que l'utilisateur est comptable uniquement (admin exclu)
        $userRole = Auth::getCurrentUserRole();
        if ($userRole !== 'comptabilite') {
            $this->errorResponse('Accès non autorisé - Page réservée aux comptables uniquement', 403);
            exit;
        }
    }
    
    /**
     * Get all planification items
     */
    public function index() {
        try {
            $planificationModel = new Planification();
            $type = $this->getQueryParam('type', null);
            $limit = $this->getQueryParam('limit', 50);
            $offset = $this->getQueryParam('offset', 0);
            
            if ($type) {
                $items = $planificationModel->getByType($type, $limit, $offset);
            } else {
                $items = $planificationModel->getAll($limit, $offset);
            }
            
            $this->successResponse($items);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la récupération: ' . $e->getMessage());
        }
    }
    
    /**
     * Get budget prévisionnel
     */
    public function getBudgetPrevisionnel() {
        try {
            $planificationModel = new Planification();
            $factureModel = new Facture();
            
            // Calculer les revenus prévisionnels
            $facturesEnCours = $factureModel->getUnpaidInvoices();
            $revenus_factures = array_sum(array_column($facturesEnCours, 'montant_ttc'));
            
            $projets = $planificationModel->getByType('projet');
            $revenus_projets = array_sum(array_column($projets, 'budget_estime'));
            
            // Calculer les dépenses prévisionnelles
            $achats = $planificationModel->getByType('achat');
            $depenses_achats = array_sum(array_column($achats, 'total'));
            
            $voyages = $planificationModel->getByType('voyage');
            $depenses_voyages = array_sum(array_column($voyages, 'budget'));
            
            // Estimations fixes (à adapter selon vos besoins)
            $depenses_salaires = 2100000; // Estimation mensuelle
            $depenses_maintenances = 500000;
            $depenses_carburant = 300000;
            
            $total_revenus = $revenus_factures + $revenus_projets;
            $total_depenses = $depenses_salaires + $depenses_maintenances + 
                             $depenses_carburant + $depenses_achats + $depenses_voyages;
            
            $budget = [
                'revenus_factures' => $revenus_factures,
                'revenus_projets' => $revenus_projets,
                'total_revenus' => $total_revenus,
                'depenses_salaires' => $depenses_salaires,
                'depenses_maintenances' => $depenses_maintenances,
                'depenses_carburant' => $depenses_carburant,
                'depenses_achats' => $depenses_achats,
                'depenses_voyages' => $depenses_voyages,
                'total_depenses' => $total_depenses,
                'resultat' => $total_revenus - $total_depenses
            ];
            
            $this->successResponse($budget);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du calcul du budget: ' . $e->getMessage());
        }
    }
    
    /**
     * Create a new planification item
     */
    public function create() {
        try {
            $data = $this->getJsonInput();
            
            // Validation des données selon le type
            $requiredFields = ['type'];
            
            switch ($data['type']) {
                case 'projet':
                    $requiredFields = array_merge($requiredFields, [
                        'nom', 'date_debut', 'date_fin', 'budget_estime', 'priorite'
                    ]);
                    break;
                case 'achat':
                    $requiredFields = array_merge($requiredFields, [
                        'article', 'categorie', 'date_prevue', 'quantite', 'prix_unitaire'
                    ]);
                    // Calculer le total
                    $data['total'] = $data['quantite'] * $data['prix_unitaire'];
                    break;
                case 'voyage':
                    $requiredFields = array_merge($requiredFields, [
                        'destination', 'employe_nom', 'date_depart', 'date_retour', 'budget'
                    ]);
                    break;
            }
            
            foreach ($requiredFields as $field) {
                if (!isset($data[$field]) || empty($data[$field])) {
                    $this->errorResponse("Le champ '$field' est requis", 400);
                    return;
                }
            }
            
            $data['created_by'] = Auth::getCurrentUserId();
            $data['statut'] = $data['statut'] ?? 'Planifié';
            
            $planificationModel = new Planification();
            $itemId = $planificationModel->create($data);
            
            if ($itemId) {
                $item = $planificationModel->findById($itemId);
                $this->successResponse($item, 'Élément de planification créé avec succès');
            } else {
                $this->errorResponse('Erreur lors de la création');
            }
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la création: ' . $e->getMessage());
        }
    }
    
    /**
     * Update a planification item
     */
    public function update($id) {
        try {
            $data = $this->getJsonInput();
            
            // Recalculer le total pour les achats
            if (isset($data['type']) && $data['type'] === 'achat') {
                if (isset($data['quantite']) && isset($data['prix_unitaire'])) {
                    $data['total'] = $data['quantite'] * $data['prix_unitaire'];
                }
            }
            
            $data['updated_by'] = Auth::getCurrentUserId();
            $data['updated_at'] = date('Y-m-d H:i:s');
            
            $planificationModel = new Planification();
            $success = $planificationModel->update($id, $data);
            
            if ($success) {
                $item = $planificationModel->findById($id);
                $this->successResponse($item, 'Élément mis à jour avec succès');
            } else {
                $this->errorResponse('Élément non trouvé ou erreur lors de la mise à jour', 404);
            }
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la mise à jour: ' . $e->getMessage());
        }
    }
    
    /**
     * Delete a planification item
     */
    public function delete($id) {
        try {
            $planificationModel = new Planification();
            $item = $planificationModel->findById($id);
            
            if (!$item) {
                $this->errorResponse('Élément non trouvé', 404);
                return;
            }
            
            $success = $planificationModel->delete($id);
            
            if ($success) {
                $this->successResponse(null, 'Élément supprimé avec succès');
            } else {
                $this->errorResponse('Erreur lors de la suppression');
            }
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la suppression: ' . $e->getMessage());
        }
    }
    
    /**
     * Export planification
     */
    public function export() {
        try {
            $type = $this->getQueryParam('type', null);
            
            $planificationModel = new Planification();
            $items = $planificationModel->getForExport($type);
            
            // Générer le CSV
            $filename = 'planification_' . ($type ?? 'complete') . '_' . date('Y-m-d') . '.csv';
            
            header('Content-Type: text/csv');
            header('Content-Disposition: attachment; filename="' . $filename . '"');
            
            $output = fopen('php://output', 'w');
            
            // En-têtes CSV selon le type
            if ($type === 'projet') {
                fputcsv($output, ['Nom', 'Date Début', 'Date Fin', 'Budget Estimé', 'Priorité', 'Statut']);
                foreach ($items as $item) {
                    fputcsv($output, [
                        $item['nom'],
                        $item['date_debut'],
                        $item['date_fin'],
                        $item['budget_estime'],
                        $item['priorite'],
                        $item['statut']
                    ]);
                }
            } elseif ($type === 'achat') {
                fputcsv($output, ['Article', 'Catégorie', 'Date Prévue', 'Quantité', 'Prix Unitaire', 'Total']);
                foreach ($items as $item) {
                    fputcsv($output, [
                        $item['article'],
                        $item['categorie'],
                        $item['date_prevue'],
                        $item['quantite'],
                        $item['prix_unitaire'],
                        $item['total']
                    ]);
                }
            } elseif ($type === 'voyage') {
                fputcsv($output, ['Destination', 'Employé', 'Date Départ', 'Date Retour', 'Budget', 'Statut']);
                foreach ($items as $item) {
                    fputcsv($output, [
                        $item['destination'],
                        $item['employe_nom'],
                        $item['date_depart'],
                        $item['date_retour'],
                        $item['budget'],
                        $item['statut']
                    ]);
                }
            } else {
                // Export complet
                fputcsv($output, ['Type', 'Nom/Article/Destination', 'Date', 'Budget/Total', 'Statut']);
                foreach ($items as $item) {
                    $nom = $item['nom'] ?? $item['article'] ?? $item['destination'];
                    $date = $item['date_debut'] ?? $item['date_prevue'] ?? $item['date_depart'];
                    $montant = $item['budget_estime'] ?? $item['total'] ?? $item['budget'];
                    
                    fputcsv($output, [
                        $item['type'],
                        $nom,
                        $date,
                        $montant,
                        $item['statut']
                    ]);
                }
            }
            
            fclose($output);
            exit;
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de l\'export: ' . $e->getMessage());
        }
    }
    
    /**
     * Get planification by date range
     */
    public function getByDateRange() {
        try {
            $dateDebut = $this->getQueryParam('date_debut');
            $dateFin = $this->getQueryParam('date_fin');
            $type = $this->getQueryParam('type', null);
            
            if (!$dateDebut || !$dateFin) {
                $this->errorResponse('Les dates de début et fin sont requises', 400);
                return;
            }
            
            $planificationModel = new Planification();
            $items = $planificationModel->getByDateRange($dateDebut, $dateFin, $type);
            
            $this->successResponse($items);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la récupération: ' . $e->getMessage());
        }
    }
}
?>
