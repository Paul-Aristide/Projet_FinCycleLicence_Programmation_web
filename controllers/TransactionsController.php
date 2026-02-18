<?php
namespace App\Controllers;

use App\Models\Transaction;
use App\Utils\Auth;
use App\Middleware\AuthMiddleware;

class TransactionsController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
        
        // Vérifier que l'utilisateur est comptable
        $userRole = Auth::getCurrentUserRole();
        if ($userRole !== 'comptabilite' && $userRole !== 'admin') {
            $this->errorResponse('Accès non autorisé', 403);
            exit;
        }
    }
    
    /**
     * Get all transactions
     */
    public function index() {
        try {
            $transactionModel = new Transaction();
            $type = $this->getQueryParam('type', null);
            $limit = $this->getQueryParam('limit', 50);
            $offset = $this->getQueryParam('offset', 0);
            
            if ($type) {
                $transactions = $transactionModel->getByType($type, $limit, $offset);
            } else {
                $transactions = $transactionModel->getAll($limit, $offset);
            }
            
            $this->successResponse($transactions);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la récupération des transactions: ' . $e->getMessage());
        }
    }
    
    /**
     * Get transaction statistics
     */
    public function getStats() {
        try {
            $transactionModel = new Transaction();
            
            $stats = [
                'total_paiements' => $transactionModel->getTotalByType('paiement'),
                'total_salaires' => $transactionModel->getTotalByType('salaire'),
                'total_maintenances' => $transactionModel->getTotalByType('maintenance'),
                'total_carburant' => $transactionModel->getTotalByType('carburant'),
                'total_autres' => $transactionModel->getTotalByType('autre'),
                'paiements_ce_mois' => $transactionModel->getCountThisMonth('paiement'),
                'salaires_ce_mois' => $transactionModel->getCountThisMonth('salaire'),
                'maintenances_ce_mois' => $transactionModel->getCountThisMonth('maintenance'),
                'autres_ce_mois' => $transactionModel->getCountThisMonth('autre')
            ];
            
            $this->successResponse($stats);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du calcul des statistiques: ' . $e->getMessage());
        }
    }
    
    /**
     * Create a new transaction
     */
    public function create() {
        try {
            $data = $this->getJsonInput();
            
            // Validation des données
            $requiredFields = ['type', 'montant', 'date', 'description'];
            foreach ($requiredFields as $field) {
                if (!isset($data[$field]) || empty($data[$field])) {
                    $this->errorResponse("Le champ '$field' est requis", 400);
                    return;
                }
            }
            
            // Générer une référence unique
            $data['reference'] = $this->generateReference($data['type']);
            $data['created_by'] = Auth::getCurrentUserId();
            
            $transactionModel = new Transaction();
            $transactionId = $transactionModel->create($data);
            
            if ($transactionId) {
                $transaction = $transactionModel->findById($transactionId);
                $this->successResponse($transaction, 'Transaction créée avec succès');
            } else {
                $this->errorResponse('Erreur lors de la création de la transaction');
            }
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la création: ' . $e->getMessage());
        }
    }
    
    /**
     * Update a transaction
     */
    public function update($id) {
        try {
            $data = $this->getJsonInput();
            $data['updated_by'] = Auth::getCurrentUserId();
            $data['updated_at'] = date('Y-m-d H:i:s');
            
            $transactionModel = new Transaction();
            $success = $transactionModel->update($id, $data);
            
            if ($success) {
                $transaction = $transactionModel->findById($id);
                $this->successResponse($transaction, 'Transaction mise à jour avec succès');
            } else {
                $this->errorResponse('Transaction non trouvée ou erreur lors de la mise à jour', 404);
            }
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la mise à jour: ' . $e->getMessage());
        }
    }
    
    /**
     * Delete a transaction
     */
    public function delete($id) {
        try {
            $transactionModel = new Transaction();
            $transaction = $transactionModel->findById($id);
            
            if (!$transaction) {
                $this->errorResponse('Transaction non trouvée', 404);
                return;
            }
            
            $success = $transactionModel->delete($id);
            
            if ($success) {
                $this->successResponse(null, 'Transaction supprimée avec succès');
            } else {
                $this->errorResponse('Erreur lors de la suppression');
            }
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la suppression: ' . $e->getMessage());
        }
    }
    
    /**
     * Export transactions
     */
    public function export() {
        try {
            $type = $this->getQueryParam('type', null);
            $dateDebut = $this->getQueryParam('date_debut', null);
            $dateFin = $this->getQueryParam('date_fin', null);
            
            $transactionModel = new Transaction();
            $transactions = $transactionModel->getForExport($type, $dateDebut, $dateFin);
            
            // Générer le CSV
            $filename = 'transactions_' . date('Y-m-d') . '.csv';
            
            header('Content-Type: text/csv');
            header('Content-Disposition: attachment; filename="' . $filename . '"');
            
            $output = fopen('php://output', 'w');
            
            // En-têtes CSV
            fputcsv($output, [
                'Date',
                'Référence',
                'Type',
                'Description',
                'Montant',
                'Statut'
            ]);
            
            // Données
            foreach ($transactions as $transaction) {
                fputcsv($output, [
                    $transaction['date'],
                    $transaction['reference'],
                    $transaction['type'],
                    $transaction['description'],
                    $transaction['montant'],
                    $transaction['statut'] ?? 'Terminé'
                ]);
            }
            
            fclose($output);
            exit;
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de l\'export: ' . $e->getMessage());
        }
    }
    
    /**
     * Generate unique reference for transaction
     */
    private function generateReference($type) {
        $prefix = [
            'paiement' => 'PAY',
            'salaire' => 'SAL',
            'maintenance' => 'MAINT',
            'carburant' => 'CARB',
            'autre' => 'AUTRE'
        ];
        
        $typePrefix = $prefix[$type] ?? 'TXN';
        $year = date('Y');
        $timestamp = time();
        
        return $typePrefix . '-' . $year . '-' . substr($timestamp, -6);
    }
    
    /**
     * Get transactions by date range
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
            
            $transactionModel = new Transaction();
            $transactions = $transactionModel->getByDateRange($dateDebut, $dateFin, $type);
            
            $this->successResponse($transactions);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la récupération: ' . $e->getMessage());
        }
    }
    
    /**
     * Get monthly summary
     */
    public function getMonthlySummary() {
        try {
            $year = $this->getQueryParam('year', date('Y'));
            $month = $this->getQueryParam('month', date('m'));
            
            $transactionModel = new Transaction();
            $summary = $transactionModel->getMonthlySummary($year, $month);
            
            $this->successResponse($summary);
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors du calcul du résumé: ' . $e->getMessage());
        }
    }
}
?>
