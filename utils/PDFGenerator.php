<?php
namespace App\Utils;

use TCPDF;

class PDFGenerator {
    private $pdf;

    // Couleurs du thème (vert/turquoise comme dans l'image)
    private $primaryColor = [74, 155, 142]; // #4A9B8E
    private $lightGray = [245, 245, 245];
    private $darkGray = [128, 128, 128];

    public function __construct() {
        $this->pdf = new TCPDF(PDF_PAGE_ORIENTATION, PDF_UNIT, PDF_PAGE_FORMAT, true, 'UTF-8', false);
        $this->setupPDF();
    }

    /**
     * Setup PDF configuration
     */
    private function setupPDF() {
        // Set document information
        $this->pdf->SetCreator('LogisWayZ');
        $this->pdf->SetAuthor(PDF_COMPANY_NAME);
        $this->pdf->SetTitle('Facture');
        $this->pdf->SetSubject('Facture de transport');

        // Désactiver l'en-tête et le pied de page par défaut
        $this->pdf->setPrintHeader(false);
        $this->pdf->setPrintFooter(false);

        // Set margins
        $this->pdf->SetMargins(15, 15, 15);

        // Set auto page breaks
        $this->pdf->SetAutoPageBreak(TRUE, 25);

        // Set image scale factor
        $this->pdf->setImageScale(PDF_IMAGE_SCALE_RATIO);

        // Set font
        $this->pdf->SetFont('helvetica', '', 10);
    }
    
    /**
     * Generate invoice PDF
     */
    public function generateInvoice($facture) {
        $this->pdf->AddPage();

        // En-tête avec fond coloré
        $this->addStyledHeader($facture);

        // Informations de facturation
        $this->addInvoiceInfo($facture);

        // Informations client
        $this->addStyledClientInfo($facture);

        // Tableau des articles
        $this->addStyledInvoiceItems($facture);

        // Totaux stylés
        $this->addStyledTotals($facture);

        // Pied de page
        $this->addStyledFooter($facture);

        return $this->pdf->Output('', 'S');
    }
    
    /**
     * Add styled header with colored background
     */
    private function addStyledHeader($facture) {
        // En-tête avec fond coloré
        $this->pdf->SetFillColor($this->primaryColor[0], $this->primaryColor[1], $this->primaryColor[2]);
        $this->pdf->Rect(0, 0, 210, 50, 'F'); // Rectangle coloré sur toute la largeur

        // Titre FACTURE en blanc et centré
        $this->pdf->SetTextColor(255, 255, 255);
        $this->pdf->SetFont('helvetica', 'B', 28);
        $this->pdf->SetXY(15, 15);
        $this->pdf->Cell(180, 12, 'FACTURE', 0, 1, 'C');

        // Informations de l'entreprise en blanc (côté droit)
        $this->pdf->SetFont('helvetica', '', 9);
        $this->pdf->SetXY(120, 12);

        $companyInfo = "LogisWayZ\n";
        $companyInfo .= "Facongo Palomata\n";
        $companyInfo .= "Commune Abobo, Quartier 20, Rue 89\n";
        $companyInfo .= "info@cvexample.com\n";
        $companyInfo .= "Ville, Pays";

        $this->pdf->MultiCell(75, 5, $companyInfo, 0, 'L', false, 1, 0, 0, true, 0, false, true, 0, 'T');

        // Retour au noir pour le reste du document
        $this->pdf->SetTextColor(0, 0, 0);
        $this->pdf->SetY(60);
    }

    /**
     * Add invoice information section
     */
    private function addInvoiceInfo($facture) {
        $this->pdf->SetFont('helvetica', 'B', 10);

        // Numéro de facture
        $this->pdf->Cell(0, 6, 'N de facture : ' . $facture['numero_facture'], 0, 1, 'L');

        // Date de facturation
        $this->pdf->Cell(0, 6, 'Date de facturation : ' . date('d/m/Y', strtotime($facture['date_facture'])), 0, 1, 'L');

        $this->pdf->Ln(15);
    }
    
    /**
     * Add styled client information
     */
    private function addStyledClientInfo($facture) {
        // Titre des sections
        $this->pdf->SetFont('helvetica', 'B', 11);
        $this->pdf->Cell(95, 8, 'Facturé à', 0, 0, 'L');
        $this->pdf->Cell(95, 8, 'Envoyé à', 0, 1, 'L');

        // Informations de l'entreprise (gauche)
        $this->pdf->SetFont('helvetica', '', 9);
        $companyInfo = '';
        if (!empty($facture['client_entreprise'])) {
            $companyInfo .= $facture['client_entreprise'] . "\n";
        }
        $companyInfo .= $facture['client_nom'] . ' ' . $facture['client_prenom'] . "\n";
        if (!empty($facture['client_adresse'])) {
            $companyInfo .= $facture['client_adresse'] . "\n";
        }
        if (!empty($facture['client_ville'])) {
            $companyInfo .= $facture['client_code_postal'] . ' ' . $facture['client_ville'];
        }

        // Informations d'envoi (droite) - même que facturé à dans ce cas
        $envoyeInfo = '';
        if (!empty($facture['client_entreprise'])) {
            $envoyeInfo .= $facture['client_entreprise'] . "\n";
        }
        $envoyeInfo .= $facture['client_nom'] . ' ' . $facture['client_prenom'] . "\n";
        if (!empty($facture['client_adresse'])) {
            $envoyeInfo .= $facture['client_adresse'] . "\n";
        }
        if (!empty($facture['client_ville'])) {
            $envoyeInfo .= $facture['client_code_postal'] . ' ' . $facture['client_ville'];
        }

        // Affichage des informations avec espacement correct
        $currentY = $this->pdf->GetY();

        // Colonne gauche
        $this->pdf->SetXY(15, $currentY);
        $this->pdf->MultiCell(85, 5, $companyInfo, 0, 'L', false, 0);

        // Colonne droite
        $this->pdf->SetXY(110, $currentY);
        $this->pdf->MultiCell(85, 5, $envoyeInfo, 0, 'L', false, 0);

        $this->pdf->Ln(25);
    }
    
    /**
     * Add styled invoice items table
     */
    private function addStyledInvoiceItems($facture) {
        // En-tête du tableau avec fond coloré
        $this->pdf->SetFont('helvetica', 'B', 9);
        $this->pdf->SetFillColor($this->primaryColor[0], $this->primaryColor[1], $this->primaryColor[2]);
        $this->pdf->SetTextColor(255, 255, 255);

        $this->pdf->Cell(20, 10, 'QTE', 1, 0, 'C', true);
        $this->pdf->Cell(90, 10, 'DESIGNATION', 1, 0, 'C', true);
        $this->pdf->Cell(35, 10, 'PRIX UNIT HT', 1, 0, 'C', true);
        $this->pdf->Cell(35, 10, 'MONTANT HT', 1, 1, 'C', true);

        // Retour au noir pour le contenu
        $this->pdf->SetTextColor(0, 0, 0);
        $this->pdf->SetFont('helvetica', '', 8);

        // Ligne de service principal
        $description = !empty($facture['description']) ? $facture['description'] : 'Service de transport et logistique';
        if (!empty($facture['numero_commande'])) {
            $description = 'Facture pour commande ' . $facture['numero_commande'] . ' Prix transport: ' . $description;
        }

        // Alternance de couleurs pour les lignes
        $this->pdf->SetFillColor(250, 250, 250);

        $this->pdf->Cell(20, 12, '1', 1, 0, 'C', true);

        // Utiliser MultiCell pour la description longue
        $currentY = $this->pdf->GetY();
        $this->pdf->MultiCell(90, 12, $description, 1, 'L', true, 0, '', '', true, 0, false, true, 12, 'M');

        // Repositionner pour les autres colonnes
        $this->pdf->SetXY(125, $currentY);
        $this->pdf->Cell(35, 12, number_format($facture['montant_ht'], 2, ',', ' ') . ' F CFA', 1, 0, 'R', true);
        $this->pdf->Cell(35, 12, number_format($facture['montant_ht'], 2, ',', ' ') . ' F CFA', 1, 1, 'R', true);

        $this->pdf->Ln(15);
    }
    
    /**
     * Add styled totals section
     */
    private function addStyledTotals($facture) {
        // Position à droite avec plus d'espace
        $x = $this->pdf->GetPageWidth() - 15 - 90;
        $currentY = $this->pdf->GetY();

        // Section MONTANT HT
        $this->pdf->SetFont('helvetica', 'B', 10);
        $this->pdf->SetFillColor($this->lightGray[0], $this->lightGray[1], $this->lightGray[2]);
        $this->pdf->SetXY($x, $currentY);
        $this->pdf->Cell(45, 8, 'MONTANT HT', 1, 0, 'C', true);
        $this->pdf->Cell(45, 8, number_format($facture['montant_ht'], 2, ',', ' ') . ' F CFA', 1, 1, 'R', true);

        // Section TVA
        $this->pdf->SetXY($x, $this->pdf->GetY());
        $this->pdf->Cell(45, 8, 'TVA  ' . $facture['taux_tva'] . '%', 1, 0, 'C', true);
        $this->pdf->Cell(45, 8, number_format($facture['montant_tva'], 2, ',', ' ') . ' F CFA', 1, 1, 'R', true);

        // Section TOTAL TTC avec fond coloré
        $this->pdf->SetFont('helvetica', 'B', 11);
        $this->pdf->SetFillColor($this->primaryColor[0], $this->primaryColor[1], $this->primaryColor[2]);
        $this->pdf->SetTextColor(255, 255, 255);
        $this->pdf->SetXY($x, $this->pdf->GetY());
        $this->pdf->Cell(90, 10, 'TOTAL TTC', 1, 1, 'C', true);

        // Montant total TTC
        $this->pdf->SetFont('helvetica', 'B', 14);
        $this->pdf->SetXY($x, $this->pdf->GetY());
        $this->pdf->Cell(90, 12, number_format($facture['montant_ttc'], 2, ',', ' ') . ' F CFA', 1, 1, 'C', true);

        // Retour au noir
        $this->pdf->SetTextColor(0, 0, 0);
        $this->pdf->Ln(20);
    }
    
    /**
     * Add styled footer
     */
    private function addStyledFooter($facture) {
        // Conditions et modalités de paiement
        $this->pdf->SetFont('helvetica', 'B', 10);
        $this->pdf->SetTextColor($this->primaryColor[0], $this->primaryColor[1], $this->primaryColor[2]);
        $this->pdf->Cell(0, 6, 'Conditions et modalités de paiement', 0, 1, 'L');

        $this->pdf->SetTextColor(0, 0, 0);
        $this->pdf->SetFont('helvetica', '', 9);
        $paymentTerms = "Le paiement est dû dans 30 jours";
        $this->pdf->Cell(0, 5, $paymentTerms, 0, 1, 'L');

        $this->pdf->Ln(10);

        // Informations bancaires (si nécessaire)
        $this->pdf->SetFont('helvetica', '', 8);
        $this->pdf->SetTextColor($this->darkGray[0], $this->darkGray[1], $this->darkGray[2]);

        $bankInfo = "TELE : 00212535-06-06-06 | FAX : 00212535-00-00-00\n";
        $bankInfo .= "IBAN : FR15 1265 9574 | SWIFT/BIC : XXXXXXXXX";

        $this->pdf->MultiCell(0, 4, $bankInfo, 0, 'C');

        // Message de remerciement
        $this->pdf->Ln(5);
        $this->pdf->SetFont('helvetica', 'I', 10);
        $this->pdf->SetTextColor($this->primaryColor[0], $this->primaryColor[1], $this->primaryColor[2]);
        $this->pdf->Cell(0, 5, 'Merci de Votre Confiance', 0, 1, 'C');

        // Notes personnalisées si présentes
        if (!empty($facture['notes'])) {
            $this->pdf->Ln(5);
            $this->pdf->SetTextColor(0, 0, 0);
            $this->pdf->SetFont('helvetica', 'B', 9);
            $this->pdf->Cell(0, 5, 'Notes:', 0, 1, 'L');
            $this->pdf->SetFont('helvetica', '', 8);
            $this->pdf->MultiCell(0, 4, $facture['notes'], 0, 'L');
        }
    }
    
    /**
     * Generate delivery receipt
     */
    public function generateDeliveryReceipt($trajet) {
        $this->pdf->AddPage();
        
        // Title
        $this->pdf->SetFont('helvetica', 'B', 18);
        $this->pdf->Cell(0, 10, 'BON DE LIVRAISON', 0, 1, 'C');
        $this->pdf->Ln(10);
        
        // Document info
        $this->pdf->SetFont('helvetica', 'B', 10);
        $this->pdf->Cell(100, 6, 'Numéro: BL' . str_pad($trajet['id'], 6, '0', STR_PAD_LEFT), 0, 0, 'L');
        $this->pdf->Cell(0, 6, 'Date: ' . date('d/m/Y H:i'), 0, 1, 'R');
        $this->pdf->Ln(10);
        
        // Transport details
        $this->pdf->SetFont('helvetica', 'B', 10);
        $this->pdf->Cell(0, 6, 'DÉTAILS DU TRANSPORT', 0, 1, 'L');
        $this->pdf->SetFont('helvetica', '', 9);
        
        $details = "Commande: " . $trajet['numero_commande'] . "\n";
        $details .= "Départ: " . $trajet['adresse_depart'] . "\n";
        $details .= "Arrivée: " . $trajet['adresse_arrivee'] . "\n";
        $details .= "Véhicule: " . $trajet['vehicule_immat'] . " (" . $trajet['vehicule_marque'] . " " . $trajet['vehicule_modele'] . ")\n";
        $details .= "Chauffeur: " . $trajet['chauffeur_nom'] . " " . $trajet['chauffeur_prenom'];
        
        $this->pdf->MultiCell(0, 5, $details, 1, 'L');
        $this->pdf->Ln(10);
        
        // Signature area
        $this->pdf->SetFont('helvetica', 'B', 10);
        $this->pdf->Cell(95, 6, 'SIGNATURE EXPÉDITEUR', 1, 0, 'C');
        $this->pdf->Cell(95, 6, 'SIGNATURE DESTINATAIRE', 1, 1, 'C');
        
        $this->pdf->Cell(95, 30, '', 1, 0, 'C');
        $this->pdf->Cell(95, 30, '', 1, 1, 'C');
        
        return $this->pdf->Output('', 'S');
    }
}