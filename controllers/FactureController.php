<?php
namespace App\Controllers;

use App\Models\Facture;
use App\Models\Client;
use App\Utils\PDFGenerator;
use App\Middleware\AuthMiddleware;
use App\Middleware\PermissionMiddleware;
use Exception;

class FactureController extends BaseController {
    
    public function __construct() {
        parent::__construct();
        AuthMiddleware::requireAuth();
    }
    
    /**
     * Get all invoices (Comptable uniquement)
     */
    public function index() {
        PermissionMiddleware::checkStrictPermission('factures', 'read');
        $factureModel = new Facture();
        $statut = $_GET['statut'] ?? null;
        $clientId = $_GET['client_id'] ?? null;
        
        if ($statut) {
            $factures = $factureModel->getByStatut($statut);
        } elseif ($clientId) {
            $factures = $factureModel->getByClientId($clientId);
        } else {
            $factures = $factureModel->getAll();
        }
        
        $this->successResponse($factures);
    }
    
    /**
     * Get invoice by ID
     */
    public function show($id) {
        PermissionMiddleware::checkStrictPermission('factures', 'read');
        $factureModel = new Facture();
        $facture = $factureModel->findById($id);
        
        if (!$facture) {
            $this->errorResponse('Facture non trouvée', 404);
        }
        
        $this->successResponse($facture);
    }
    
    /**
     * Create new invoice (Comptable uniquement)
     */
    public function create() {
        PermissionMiddleware::checkStrictPermission('factures', 'create');
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['client_id', 'montant_ht']);
        
        $data = $this->sanitizeInput($data);
        
        // Validate client exists
        require_once 'models/Client.php';
        $clientModel = new Client();
        if (!$clientModel->findById($data['client_id'])) {
            $this->errorResponse('Client non trouvé');
        }
        
        // Validate amounts
        if ($data['montant_ht'] <= 0) {
            $this->errorResponse('Le montant HT doit être positif');
        }
        
        $factureModel = new Facture();
        $numeroFacture = $factureModel->generateNumeroFacture();
        
        $tauxTva = $data['taux_tva'] ?? 20; // Default TVA 20%
        $montantTva = $data['montant_ht'] * ($tauxTva / 100);
        $montantTtc = $data['montant_ht'] + $montantTva;
        
        $factureId = $factureModel->create([
            'numero_facture' => $numeroFacture,
            'client_id' => $data['client_id'],
            'commande_id' => $data['commande_id'] ?? null,
            'date_facture' => date('Y-m-d'),
            'date_echeance' => $data['date_echeance'] ?? date('Y-m-d', strtotime('+30 days')),
            'montant_ht' => $data['montant_ht'],
            'taux_tva' => $tauxTva,
            'montant_tva' => $montantTva,
            'montant_ttc' => $montantTtc,
            'statut' => 'brouillon',
            'description' => $data['description'] ?? '',
            'notes' => $data['notes'] ?? ''
        ]);
        
        $facture = $factureModel->findById($factureId);
        $this->successResponse($facture, 'Facture créée avec succès');
    }
    
    /**
     * Update invoice (Comptable uniquement)
     */
    public function update($id) {
        PermissionMiddleware::checkStrictPermission('factures', 'update');
        
        $factureModel = new Facture();
        $facture = $factureModel->findById($id);
        
        if (!$facture) {
            $this->errorResponse('Facture non trouvée', 404);
        }
        
        if ($facture['statut'] === 'payee') {
            $this->errorResponse('Impossible de modifier une facture payée');
        }
        
        $data = $this->getRequestBody();
        $data = $this->sanitizeInput($data);
        
        // Recalculate amounts if montant_ht or taux_tva changed
        if (isset($data['montant_ht']) || isset($data['taux_tva'])) {
            $montantHt = $data['montant_ht'] ?? $facture['montant_ht'];
            $tauxTva = $data['taux_tva'] ?? $facture['taux_tva'];
            
            if ($montantHt <= 0) {
                $this->errorResponse('Le montant HT doit être positif');
            }
            
            $data['montant_tva'] = $montantHt * ($tauxTva / 100);
            $data['montant_ttc'] = $montantHt + $data['montant_tva'];
        }
        
        $factureModel->update($id, $data);
        $updatedFacture = $factureModel->findById($id);
        
        $this->successResponse($updatedFacture, 'Facture mise à jour avec succès');
    }
    
    /**
     * Update invoice status (Comptable uniquement)
     */
    public function updateStatut($id) {
        PermissionMiddleware::checkStrictPermission('factures', 'update');
        
        $data = $this->getRequestBody();
        $this->validateRequired($data, ['statut']);
        
        $statut = $this->sanitizeInput($data['statut']);
        $validStatuts = ['brouillon', 'envoyee', 'payee', 'annulee'];
        
        if (!in_array($statut, $validStatuts)) {
            $this->errorResponse('Statut invalide');
        }
        
        $factureModel = new Facture();
        $facture = $factureModel->findById($id);
        
        if (!$facture) {
            $this->errorResponse('Facture non trouvée', 404);
        }
        
        $updateData = ['statut' => $statut];
        
        if ($statut === 'payee') {
            $updateData['date_paiement'] = date('Y-m-d H:i:s');
        }
        
        $factureModel->update($id, $updateData);
        $updatedFacture = $factureModel->findById($id);
        
        $this->successResponse($updatedFacture, 'Statut de la facture mis à jour avec succès');
    }
    
    /**
     * Generate invoice PDF
     */
    public function generatePDF($id) {
        $factureModel = new Facture();
        $facture = $factureModel->findById($id);
        
        if (!$facture) {
            $this->errorResponse('Facture non trouvée', 404);
        }
        
        try {
            $pdfGenerator = new PDFGenerator();
            $pdfContent = $pdfGenerator->generateInvoice($facture);
            
            // Update invoice status if it's still draft
            if ($facture['statut'] === 'brouillon') {
                $factureModel->updateStatut($id, 'envoyee');
            }
            
            header('Content-Type: application/pdf');
            header('Content-Disposition: attachment; filename="facture_' . $facture['numero_facture'] . '.pdf"');
            header('Content-Length: ' . strlen($pdfContent));
            
            echo $pdfContent;
            exit();
            
        } catch (Exception $e) {
            $this->errorResponse('Erreur lors de la génération du PDF: ' . $e->getMessage(), 500);
        }
    }
    
    /**
     * Delete invoice (Comptable uniquement)
     */
    public function delete($id) {
        PermissionMiddleware::checkStrictPermission('factures', 'delete');
        
        $factureModel = new Facture();
        $facture = $factureModel->findById($id);
        
        if (!$facture) {
            $this->errorResponse('Facture non trouvée', 404);
        }
        
        if ($facture['statut'] === 'payee') {
            $this->errorResponse('Impossible de supprimer une facture payée');
        }
        
        $factureModel->delete($id);
        $this->successResponse(null, 'Facture supprimée avec succès');
    }
    
    /**
     * Get invoice statistics (Comptable uniquement)
     */
    public function getStats() {
        PermissionMiddleware::checkStrictPermission('factures', 'read');
        
        $factureModel = new Facture();
        $stats = $factureModel->getStatistics();
        $this->successResponse($stats);
    }
    
    /**
     * Get overdue invoices (Comptable uniquement)
     */
    public function getOverdue() {
        PermissionMiddleware::checkStrictPermission('factures', 'read');
        
        $factureModel = new Facture();
        $overdueInvoices = $factureModel->getOverdue();
        $this->successResponse($overdueInvoices);
    }
    
    /**
     * Export invoices for accounting (Comptable uniquement)
     */
    public function exportComptabilite() {
        PermissionMiddleware::checkStrictPermission('factures', 'read');
        
        $dateDebut = $_GET['date_debut'] ?? date('Y-m-01');
        $dateFin = $_GET['date_fin'] ?? date('Y-m-t');
        
        $factureModel = new Facture();
        $factures = $factureModel->getForExport($dateDebut, $dateFin);
        
        $csv = "Numéro Facture;Date;Client;Montant HT;TVA;Montant TTC;Statut\n";
        
        foreach ($factures as $facture) {
            $csv .= sprintf(
                "%s;%s;%s;%.2f;%.2f;%.2f;%s\n",
                $facture['numero_facture'],
                $facture['date_facture'],
                $facture['client_nom'],
                $facture['montant_ht'],
                $facture['montant_tva'],
                $facture['montant_ttc'],
                $facture['statut']
            );
        }
        
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="export_factures_' . date('Y-m-d') . '.csv"');
        
        echo "\xEF\xBB\xBF"; // UTF-8 BOM
        echo $csv;
        exit();
    }
}
?>
