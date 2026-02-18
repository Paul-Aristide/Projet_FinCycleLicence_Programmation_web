// Factures Component
const FacturesComponent = {
    template: `
    <div class="factures fade-in">
        <!-- Page Header -->
        <div class="page-header factures-header">
            <h1>
                <i class="fas fa-file-invoice me-2"></i>
                Gestion des factures
            </h1>
            <div class="page-header-actions">
                <button v-if="hasPermission('factures', 'write')"
                        @click="showCreateModal"
                        class="btn btn-primary btn-icon-right">
                    <i class="fas fa-plus"></i>
                    Nouvelle facture
                </button>
                <button style="background-color:green; color:white;" class="btn btn-outline-secondary ms-2" @click="exportFactures">
                    <i class="fas fa-download me-2"></i>
                    Exporter
                </button>
            </div>
        </div>
        
        <!-- Filters -->
        <div class="card mb-4">
            <div class="card-body">
                <div class="row">
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterStatut" @change="filterFactures">
                            <option value="">Tous les statuts</option>
                            <option value="brouillon">Brouillon</option>
                            <option value="envoyee">Envoyée</option>
                            <option value="payee">Payée</option>
                            <option value="annulee">Annulée</option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterClient" @change="filterFactures">
                            <option value="">Tous les clients</option>
                            <option v-for="client in clients" :key="client.id" :value="client.id">
                                {{ client.nom }} {{ client.prenom }}
                            </option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <input type="month" class="form-control" v-model="filterMois" @change="filterFactures">
                    </div>
                    <div class="col-md-3">
                        <button @click="loadFactures" class="btn btn-outline-secondary w-100">
                            <i class="fas fa-sync-alt me-2"></i>
                            Actualiser
                        </button>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Statistics Cards -->
        <div class="row mb-4" v-if="stats">
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card factures">
                    <div class="stat-icon">
                        <i class="fas fa-file-invoice"></i>
                    </div>
                    <div class="stat-number">{{ stats.total || 0 }}</div>
                    <div class="stat-label">Total factures</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card commandes">
                    <div class="stat-icon">
                        <i class="fas fa-paper-plane"></i>
                    </div>
                    <div class="stat-number">{{ stats.envoyees || 0 }}</div>
                    <div class="stat-label">Envoyées</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card vehicules">
                    <div class="stat-icon">
                        <i class="fas fa-check-circle"></i>
                    </div>
                    <div class="stat-number">{{ stats.payees || 0 }}</div>
                    <div class="stat-label">Payées</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card revenus">
                    <div class="stat-icon">
                        <i class="fas fa-franc-sign"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.ca_realise || 0) }}</div>
                    <div class="stat-label">CA réalisé</div>
                </div>
            </div>
        </div>

        <!-- Admin Actions (only for administrators) -->
        <div v-if="user().role === 'admin'" class="row mb-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h6 class="card-title mb-0">
                            <i class="fas fa-tools me-2"></i>
                            Actions Administrateur
                        </h6>
                    </div>
                    <div class="card-body">
                        <div class="row g-2">
                            <div class="col-md-6">
                                <button @click="showTransactionsModal" class="btn btn-info w-100 btn-icon-right">
                                    <i class="fas fa-exchange-alt"></i>
                                    Gestion des Transactions
                                </button>
                            </div>
                            <div class="col-md-6">
                                <button @click="showPlanificationModal" class="btn btn-warning w-100 btn-icon-right">
                                    <i class="fas fa-calendar-alt"></i>
                                    Planification & Budget
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Overdue Invoices Alert -->
        <div v-if="Array.isArray(overdueInvoices) && overdueInvoices.length > 0" class="alert alert-warning">
            <h6><i class="fas fa-exclamation-triangle me-2"></i>Factures en retard</h6>
            <p class="mb-0">
                {{ overdueInvoices.length }} facture(s) en retard de paiement.
                <button @click="showOverdueModal" class="btn btn-sm btn-outline-warning ms-2">
                    Voir détails
                </button>
            </p>
        </div>
        
        <!-- Factures Table -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">
                    <i class="fas fa-list me-2"></i>
                    Liste des factures ({{ factures.length }})
                </h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th>N° Facture</th>
                                <th>Client</th>
                                <th>Date</th>
                                <th>Échéance</th>
                                <th>Montant HT</th>
                                <th>Montant TTC</th>
                                <th>Statut</th>
                                <th width="150">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="loading">
                                <td colspan="8" class="text-center py-4">
                                    <div class="spinner-border text-primary" role="status">
                                        <span class="visually-hidden">Chargement...</span>
                                    </div>
                                </td>
                            </tr>
                            <tr v-else-if="factures.length === 0">
                                <td colspan="8" class="text-center py-4 text-muted">
                                    <i class="fas fa-file-invoice fa-3x mb-3 d-block"></i>
                                    Aucune facture trouvée
                                </td>
                            </tr>
                            <tr v-else v-for="facture in factures" :key="facture.id" 
                                :class="{ 'table-warning': isOverdue(facture) }">
                                <td>
                                    <strong>{{ facture.numero_facture }}</strong>
                                    <br>
                                    <small class="text-muted">{{ facture.numero_commande || '-' }}</small>
                                </td>
                                <td>
                                    <strong>{{ facture.client_nom }} {{ facture.client_prenom }}</strong>
                                    <br>
                                    <small class="text-muted">{{ facture.client_entreprise || '-' }}</small>
                                </td>
                                <td>{{ formatDate(facture.date_facture) }}</td>
                                <td>
                                    {{ formatDate(facture.date_echeance) }}
                                    <br>
                                    <small v-if="isOverdue(facture)" class="text-danger">
                                        <i class="fas fa-exclamation-triangle me-1"></i>
                                        En retard
                                    </small>
                                </td>
                                <td>{{ formatCurrency(facture.montant_ht) }}</td>
                                <td>
                                    <strong>{{ formatCurrency(facture.montant_ttc) }}</strong>
                                    <br>
                                    <small class="text-muted">TVA {{ facture.taux_tva }}%</small>
                                </td>
                                <td>
                                    <span :class="'status-badge status-' + facture.statut">
                                        {{ getStatusLabel(facture.statut) }}
                                    </span>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button @click="viewFacture(facture)" 
                                                class="btn btn-sm btn-outline-info" 
                                                title="Voir détails">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        <button v-if="hasPermission('factures', 'write')"
                                                @click="editFacture(facture)" 
                                                class="btn btn-sm btn-outline-primary" 
                                                title="Modifier">
                                            <i class="fas fa-edit"></i>
                                        </button>
                                        <div class="dropdown d-inline">
                                            <button class="btn btn-sm btn-outline-secondary dropdown-toggle"
                                                    type="button"
                                                    data-bs-toggle="dropdown">
                                                <i class="fas fa-cog"></i>
                                            </button>
                                            <ul class="dropdown-menu">
                                                <li><a class="dropdown-item" href="#" @click="downloadPDF(facture)">
                                                    <i class="fas fa-file-pdf me-2"></i>Télécharger PDF
                                                </a></li>
                                                <li v-if="hasPermission('factures', 'write')"><a class="dropdown-item" href="#" @click="updateStatus(facture, 'envoyee')">
                                                    <i class="fas fa-paper-plane me-2"></i>Marquer envoyée
                                                </a></li>
                                                <li v-if="hasPermission('factures', 'write')"><a class="dropdown-item" href="#" @click="updateStatus(facture, 'payee')">
                                                    <i class="fas fa-check-circle me-2"></i>Marquer payée
                                                </a></li>
                                                <li v-if="hasPermission('factures', 'write')"><hr class="dropdown-divider"></li>
                                                <li v-if="hasPermission('factures', 'write')"><a class="dropdown-item text-danger" href="#" @click="updateStatus(facture, 'annulee')">
                                                    <i class="fas fa-times me-2"></i>Annuler
                                                </a></li>
                                            </ul>
                                        </div>
                                        <button v-if="hasPermission('factures', 'delete') && facture.statut !== 'payee'"
                                                @click="deleteFacture(facture)" 
                                                class="btn btn-sm btn-outline-danger" 
                                                title="Supprimer">
                                            <i class="fas fa-trash"></i>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <!-- Facture Modal -->
        <div class="modal fade" ref="factureModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-file-invoice me-2"></i>
                            {{ modalMode === 'create' ? 'Nouvelle facture' : modalMode === 'edit' ? 'Modifier facture' : 'Détails facture' }}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form @submit.prevent="saveFacture" v-if="modalMode !== 'view'">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Client *</label>
                                        <select class="form-select" v-model="currentFacture.client_id" required>
                                            <option value="">Sélectionner un client</option>
                                            <option v-for="client in clients" :key="client.id" :value="client.id">
                                                {{ client.nom }} {{ client.prenom }} - {{ client.entreprise }}
                                            </option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Commande</label>
                                        <select class="form-select" v-model="currentFacture.commande_id">
                                            <option value="">Aucune commande liée</option>
                                            <option v-for="commande in commandes" :key="commande.id" :value="commande.id">
                                                {{ commande.numero_commande }} - {{ commande.client_nom }}
                                            </option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Date facture *</label>
                                        <input type="date" class="form-control" v-model="currentFacture.date_facture" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Date échéance *</label>
                                        <input type="date" class="form-control" v-model="currentFacture.date_echeance" required>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Montant HT (F CFA) *</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentFacture.montant_ht" @input="calculateTotals" required>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Taux TVA (%)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentFacture.taux_tva" @input="calculateTotals">
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Montant TTC (F CFA)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentFacture.montant_ttc" readonly>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Description</label>
                                <textarea class="form-control" rows="3" v-model="currentFacture.description"></textarea>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Notes</label>
                                <textarea class="form-control" rows="2" v-model="currentFacture.notes"></textarea>
                            </div>
                        </form>
                        
                        <!-- View Mode -->
                        <div v-else>
                            <div class="row">
                                <div class="col-md-6">
                                    <h6>Informations générales</h6>
                                    <p><strong>N° Facture:</strong> {{ currentFacture.numero_facture }}</p>
                                    <p><strong>Client:</strong> {{ currentFacture.client_nom }} {{ currentFacture.client_prenom }}</p>
                                    <p><strong>Entreprise:</strong> {{ currentFacture.client_entreprise || '-' }}</p>
                                    <p><strong>Commande:</strong> {{ currentFacture.numero_commande || '-' }}</p>
                                    <p><strong>Date facture:</strong> {{ formatDate(currentFacture.date_facture) }}</p>
                                    <p><strong>Date échéance:</strong> {{ formatDate(currentFacture.date_echeance) }}</p>
                                    <p><strong>Statut:</strong> 
                                        <span :class="'status-badge status-' + currentFacture.statut">
                                            {{ getStatusLabel(currentFacture.statut) }}
                                        </span>
                                    </p>
                                </div>
                                <div class="col-md-6">
                                    <h6>Montants</h6>
                                    <p><strong>Montant HT:</strong> {{ formatCurrency(currentFacture.montant_ht) }}</p>
                                    <p><strong>TVA ({{ currentFacture.taux_tva }}%):</strong> {{ formatCurrency(currentFacture.montant_tva) }}</p>
                                    <p><strong>Montant TTC:</strong> {{ formatCurrency(currentFacture.montant_ttc) }}</p>
                                    
                                    <h6 class="mt-3">Paiement</h6>
                                    <p v-if="currentFacture.date_paiement"><strong>Date paiement:</strong> {{ formatDate(currentFacture.date_paiement) }}</p>
                                    <p v-else-if="isOverdue(currentFacture)" class="text-danger">
                                        <i class="fas fa-exclamation-triangle me-1"></i>
                                        Facture en retard
                                    </p>
                                </div>
                            </div>
                            
                            <div v-if="currentFacture.description" class="mt-3">
                                <h6>Description</h6>
                                <p>{{ currentFacture.description }}</p>
                            </div>
                            
                            <div v-if="currentFacture.notes" class="mt-3">
                                <h6>Notes</h6>
                                <p>{{ currentFacture.notes }}</p>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            {{ modalMode === 'view' ? 'Fermer' : 'Annuler' }}
                        </button>
                        <button v-if="modalMode !== 'view'" 
                                type="submit" 
                                @click="saveFacture"
                                class="btn btn-primary"
                                :disabled="saving">
                            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
                            {{ modalMode === 'create' ? 'Créer' : 'Sauvegarder' }}
                        </button>
                        <button v-if="modalMode === 'view'"
                                @click="downloadPDF(currentFacture)"
                                class="btn btn-success btn-icon-right">
                            <i class="fas fa-file-pdf"></i>
                            Télécharger PDF
                        </button>
                        <button v-if="modalMode === 'view' && currentFacture.statut === 'brouillon' && hasPermission('factures', 'write')"
                                @click="updateStatus(currentFacture, 'envoyee')"
                                class="btn btn-warning btn-icon-right">
                            <i class="fas fa-paper-plane"></i>
                            Envoyer
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Loading State -->
        <div v-if="loading" class="text-center py-5">
            <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">Chargement...</span>
            </div>
            <p class="mt-2 text-muted">Chargement des factures...</p>
        </div>

        <!-- Transactions Modal (Admin only) -->
        <div v-if="user().role === 'admin'" class="modal fade" id="transactionsModal" ref="transactionsModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-exchange-alt me-2"></i>
                            Gestion des Transactions
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <!-- Transactions Tabs -->
                        <ul class="nav nav-tabs" id="transactionsTabs" role="tablist">
                            <li class="nav-item" role="presentation">
                                <button class="nav-link active" id="paiements-tab" data-bs-toggle="tab" data-bs-target="#paiements" type="button" role="tab">
                                    <i class="fas fa-credit-card me-2"></i>Paiements Clients
                                </button>
                            </li>
                            <li class="nav-item" role="presentation">
                                <button class="nav-link" id="salaires-tab" data-bs-toggle="tab" data-bs-target="#salaires" type="button" role="tab">
                                    <i class="fas fa-users me-2"></i>Salaires
                                </button>
                            </li>
                        </ul>

                        <div class="tab-content mt-3" id="transactionsTabContent">
                            <!-- Paiements Clients -->
                            <div class="tab-pane fade show active" id="paiements" role="tabpanel">
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Date</th>
                                                <th>Référence</th>
                                                <th>Client</th>
                                                <th>Facture</th>
                                                <th>Montant</th>
                                                <th>Mode</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr v-for="transaction in transactions.paiements" :key="transaction.id">
                                                <td>{{ formatDate(transaction.date) }}</td>
                                                <td><strong>{{ transaction.reference }}</strong></td>
                                                <td>{{ transaction.client_nom }}</td>
                                                <td>{{ transaction.facture_numero }}</td>
                                                <td class="text-success">{{ formatCurrency(transaction.montant) }}</td>
                                                <td><span class="badge bg-info">{{ transaction.mode_paiement }}</span></td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                            <!-- Salaires -->
                            <div class="tab-pane fade" id="salaires" role="tabpanel">
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Date</th>
                                                <th>Référence</th>
                                                <th>Employé</th>
                                                <th>Période</th>
                                                <th>Montant</th>
                                                <th>Statut</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr v-for="transaction in transactions.salaires" :key="transaction.id">
                                                <td>{{ formatDate(transaction.date) }}</td>
                                                <td><strong>{{ transaction.reference }}</strong></td>
                                                <td>{{ transaction.employe_nom }}</td>
                                                <td>{{ transaction.periode }}</td>
                                                <td class="text-danger">{{ formatCurrency(transaction.montant) }}</td>
                                                <td><span :class="'badge ' + (transaction.statut === 'paye' ? 'bg-success' : 'bg-warning')">{{ transaction.statut }}</span></td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Fermer</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Planification Modal (Admin only) -->
        <div v-if="user().role === 'admin'" class="modal fade" id="planificationModal" ref="planificationModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-calendar-alt me-2"></i>
                            Planification & Budget
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <!-- Budget Summary -->
                        <div class="row mb-3">
                            <div class="col-md-4">
                                <div class="card text-center">
                                    <div class="card-body">
                                        <h6 class="text-success">Revenus Prévisionnels</h6>
                                        <h4 class="text-success">{{ formatCurrency(budgetPrevisionnel.total_revenus) }}</h4>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="card text-center">
                                    <div class="card-body">
                                        <h6 class="text-danger">Dépenses Prévisionnelles</h6>
                                        <h4 class="text-danger">{{ formatCurrency(budgetPrevisionnel.total_depenses) }}</h4>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="card text-center">
                                    <div class="card-body">
                                        <h6 :class="budgetPrevisionnel.resultat >= 0 ? 'text-success' : 'text-danger'">Résultat</h6>
                                        <h4 :class="budgetPrevisionnel.resultat >= 0 ? 'text-success' : 'text-danger'">{{ formatCurrency(budgetPrevisionnel.resultat) }}</h4>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Planification Tabs -->
                        <ul class="nav nav-tabs" id="planificationTabs" role="tablist">
                            <li class="nav-item" role="presentation">
                                <button class="nav-link active" id="projets-tab" data-bs-toggle="tab" data-bs-target="#projets" type="button" role="tab">
                                    <i class="fas fa-project-diagram me-2"></i>Projets
                                </button>
                            </li>
                            <li class="nav-item" role="presentation">
                                <button class="nav-link" id="achats-tab" data-bs-toggle="tab" data-bs-target="#achats" type="button" role="tab">
                                    <i class="fas fa-shopping-cart me-2"></i>Achats
                                </button>
                            </li>
                            <li class="nav-item" role="presentation">
                                <button class="nav-link" id="voyages-tab" data-bs-toggle="tab" data-bs-target="#voyages" type="button" role="tab">
                                    <i class="fas fa-plane me-2"></i>Voyages
                                </button>
                            </li>
                        </ul>

                        <div class="tab-content mt-3" id="planificationTabContent">
                            <!-- Projets -->
                            <div class="tab-pane fade show active" id="projets" role="tabpanel">
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Nom du Projet</th>
                                                <th>Date Début</th>
                                                <th>Date Fin</th>
                                                <th>Budget Estimé</th>
                                                <th>Priorité</th>
                                                <th>Statut</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr v-for="projet in planification.projets" :key="projet.id">
                                                <td><strong>{{ projet.nom }}</strong></td>
                                                <td>{{ formatDate(projet.date_debut) }}</td>
                                                <td>{{ formatDate(projet.date_fin) }}</td>
                                                <td>{{ formatCurrency(projet.budget_estime) }}</td>
                                                <td><span :class="'badge bg-' + (projet.priorite === 'Haute' ? 'danger' : projet.priorite === 'Moyenne' ? 'warning' : 'info')">{{ projet.priorite }}</span></td>
                                                <td><span class="badge bg-info">{{ projet.statut }}</span></td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                            <!-- Achats -->
                            <div class="tab-pane fade" id="achats" role="tabpanel">
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Article</th>
                                                <th>Catégorie</th>
                                                <th>Date Prévue</th>
                                                <th>Quantité</th>
                                                <th>Prix Unitaire</th>
                                                <th>Total</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr v-for="achat in planification.achats" :key="achat.id">
                                                <td><strong>{{ achat.article }}</strong></td>
                                                <td><span class="badge bg-info">{{ achat.categorie }}</span></td>
                                                <td>{{ formatDate(achat.date_prevue) }}</td>
                                                <td>{{ achat.quantite }}</td>
                                                <td>{{ formatCurrency(achat.prix_unitaire) }}</td>
                                                <td>{{ formatCurrency(achat.total) }}</td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                            <!-- Voyages -->
                            <div class="tab-pane fade" id="voyages" role="tabpanel">
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Destination</th>
                                                <th>Employé</th>
                                                <th>Date Départ</th>
                                                <th>Date Retour</th>
                                                <th>Budget</th>
                                                <th>Statut</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr v-for="voyage in planification.voyages" :key="voyage.id">
                                                <td><strong>{{ voyage.destination }}</strong></td>
                                                <td>{{ voyage.employe_nom }}</td>
                                                <td>{{ formatDate(voyage.date_depart) }}</td>
                                                <td>{{ formatDate(voyage.date_retour) }}</td>
                                                <td>{{ formatCurrency(voyage.budget) }}</td>
                                                <td><span class="badge bg-success">{{ voyage.statut }}</span></td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Fermer</button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    `,

    
    inject: ['showNotification', 'handleApiError', 'formatDate', 'formatCurrency', 'formatNumber', 'hasPermission', 'user'],
    
    data() {
        return {
            factures: [],
            clients: [],
            commandes: [],
            stats: null,
            overdueInvoices: [], // This is already properly initialized
            loading: false,
            saving: false,
            filterStatut: '',
            filterClient: '',
            filterMois: '',
            modalMode: 'view',
            currentFacture: {},
            modal: null,
            // Données pour les modales admin
            transactions: {
                paiements: [],
                salaires: [],
                maintenances: [],
                carburant: [],
                autres: []
            },
            planification: {
                projets: [],
                achats: [],
                voyages: []
            },
            budgetPrevisionnel: {
                revenus_factures: 0,
                revenus_projets: 0,
                total_revenus: 0,
                depenses_salaires: 0,
                depenses_maintenances: 0,
                depenses_carburant: 0,
                depenses_achats: 0,
                depenses_voyages: 0,
                total_depenses: 0,
                resultat: 0
            },
            transactionsModal: null,
            planificationModal: null
        }
    },
    
    mounted() {
        this.loadFactures();
        this.loadRelatedData();
        this.loadStats();
        this.loadOverdueInvoices();
        this.modal = new bootstrap.Modal(this.$refs.factureModal);

        // Initialiser les modales admin si l'utilisateur est admin
        if (this.user().role === 'admin') {
            this.transactionsModal = new bootstrap.Modal(this.$refs.transactionsModal);
            this.planificationModal = new bootstrap.Modal(this.$refs.planificationModal);
        }
    },
    
    methods: {
        async loadFactures() {
            this.loading = true;
            try {
                const params = {};
                if (this.filterStatut) params.statut = this.filterStatut;
                if (this.filterClient) params.client_id = this.filterClient;
                
                const response = await axios.get('/factures', { params });
                this.factures = response.data.data;
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement des factures');
            }
            this.loading = false;
        },
        
        async loadRelatedData() {
            try {
                // Load clients
                const clientsResponse = await axios.get('/clients');
                this.clients = clientsResponse.data.data;
                
                // Load commandes
                const commandesResponse = await axios.get('/commandes');
                this.commandes = commandesResponse.data.data;
                
            } catch (error) {
                console.error('Erreur lors du chargement des données:', error);
            }
        },
        
        async loadStats() {
            try {
                const response = await axios.get('/factures/stats');
                this.stats = response.data.data;
            } catch (error) {
                console.error('Erreur lors du chargement des statistiques:', error);
            }
        },
        
        async loadOverdueInvoices() {
            this.overdueInvoices = []; // Ensure it's always an array
            try {
                const response = await axios.get('/factures/overdue');
                this.overdueInvoices = Array.isArray(response.data?.data) ? response.data.data : [];
            } catch (error) {
                console.error('Erreur lors du chargement des factures en retard:', error);
                this.overdueInvoices = []; // Set empty array on error
            }
        },
        
        async filterFactures() {
            await this.loadFactures();
        },
        
        showCreateModal() {
            this.modalMode = 'create';
            this.currentFacture = {
                client_id: '',
                commande_id: '',
                date_facture: new Date().toISOString().split('T')[0],
                date_echeance: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
                montant_ht: 0,
                taux_tva: 20,
                montant_tva: 0,
                montant_ttc: 0,
                description: '',
                notes: ''
            };
            this.modal.show();
        },
        
        viewFacture(facture) {
            this.modalMode = 'view';
            this.currentFacture = { ...facture };
            this.modal.show();
        },
        
        editFacture(facture) {
            this.modalMode = 'edit';
            this.currentFacture = { ...facture };
            this.modal.show();
        },
        
        calculateTotals() {
            const montantHt = parseFloat(this.currentFacture.montant_ht) || 0;
            const tauxTva = parseFloat(this.currentFacture.taux_tva) || 0;
            
            this.currentFacture.montant_tva = (montantHt * tauxTva / 100).toFixed(2);
            this.currentFacture.montant_ttc = (montantHt + parseFloat(this.currentFacture.montant_tva)).toFixed(2);
        },
        
        async saveFacture() {
            this.saving = true;
            
            try {
                if (this.modalMode === 'create') {
                    await axios.post('/factures', this.currentFacture);
                    this.showNotification('Facture créée avec succès', 'success');
                } else {
                    await axios.put(`/factures/${this.currentFacture.id}`, this.currentFacture);
                    this.showNotification('Facture modifiée avec succès', 'success');
                }
                
                this.modal.hide();
                await this.loadFactures();
                await this.loadStats();
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la sauvegarde');
            }
            
            this.saving = false;
        },
        
        async updateStatus(facture, newStatus) {
            try {
                await axios.put(`/factures/${facture.id}/status`, { statut: newStatus });
                this.showNotification('Statut mis à jour avec succès', 'success');



                await this.loadFactures();
                await this.loadStats();
                await this.loadOverdueInvoices();

                // Close modal if open
                if (this.modal._isShown) {
                    this.modal.hide();
                }
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la mise à jour du statut');
            }
        },
        
        async deleteFacture(facture) {
            if (!confirm(`Êtes-vous sûr de vouloir supprimer la facture "${facture.numero_facture}" ?`)) {
                return;
            }
            
            try {
                await axios.delete(`/factures/${facture.id}`);
                this.showNotification('Facture supprimée avec succès', 'success');
                await this.loadFactures();
                await this.loadStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        async downloadPDF(facture) {
            try {
                const response = await axios.get(`/factures/${facture.id}/pdf`, {
                    responseType: 'blob'
                });
                
                const url = window.URL.createObjectURL(new Blob([response.data]));
                const link = document.createElement('a');
                link.href = url;
                link.setAttribute('download', `facture_${facture.numero_facture}.pdf`);
                document.body.appendChild(link);
                link.click();
                link.remove();
                window.URL.revokeObjectURL(url);
                
                this.showNotification('PDF téléchargé avec succès', 'success');
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du téléchargement du PDF');
            }
        },
        
        async exportFactures() {
            try {
                const response = await axios.get('/factures/export', {
                    responseType: 'blob'
                });
                
                const url = window.URL.createObjectURL(new Blob([response.data]));
                const link = document.createElement('a');
                link.href = url;
                link.setAttribute('download', `export_factures_${new Date().toISOString().split('T')[0]}.csv`);
                document.body.appendChild(link);
                link.click();
                link.remove();
                window.URL.revokeObjectURL(url);
                
                this.showNotification('Export généré avec succès', 'success');
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de l\'export');
            }
        },
        
        showOverdueModal() {
            this.showNotification('Fonctionnalité de gestion des retards à implémenter', 'info');
        },
        
        getStatusLabel(status) {
            const labels = {
                'brouillon': 'Brouillon',
                'envoyee': 'Envoyée',
                'payee': 'Payée',
                'annulee': 'Annulée'
            };
            return labels[status] || status;
        },
        
        isOverdue(facture) {
            if (facture.statut === 'payee' || facture.statut === 'annulee') {
                return false;
            }
            return new Date(facture.date_echeance) < new Date();
        },

        // ===== ADMIN MODAL METHODS =====
        showTransactionsModal() {
            this.loadTransactions();
            this.transactionsModal.show();
        },

        showPlanificationModal() {
            this.loadPlanification();
            this.calculateBudgetPrevisionnel();
            this.planificationModal.show();
        },

        async loadTransactions() {
            try {
                // Simuler le chargement des transactions (à remplacer par de vrais appels API)
                this.transactions = {
                    paiements: [
                        {
                            id: 1,
                            date: '2025-06-10',
                            reference: 'PAY-2025-001',
                            client_nom: 'SOCOCE',
                            facture_numero: 'FAC-2025-001',
                            montant: 2500000,
                            mode_paiement: 'Virement'
                        }
                    ],
                    salaires: [
                        {
                            id: 1,
                            date: '2025-06-01',
                            reference: 'SAL-2025-001',
                            employe_nom: 'Jean Kouassi',
                            periode: 'Mai 2025',
                            montant: 350000,
                            statut: 'paye'
                        }
                    ],
                    maintenances: [],
                    carburant: [],
                    autres: []
                };
            } catch (error) {
                console.error('Erreur lors du chargement des transactions:', error);
                this.showNotification('Erreur lors du chargement des transactions', 'error');
            }
        },

        async loadPlanification() {
            try {
                // Simuler le chargement de la planification (à remplacer par de vrais appels API)
                this.planification = {
                    projets: [
                        {
                            id: 1,
                            nom: 'Extension flotte véhicules',
                            date_debut: '2025-07-01',
                            date_fin: '2025-09-30',
                            budget_estime: 15000000,
                            priorite: 'Haute',
                            statut: 'Planifié'
                        }
                    ],
                    achats: [
                        {
                            id: 1,
                            article: 'Ordinateurs portables',
                            categorie: 'Informatique',
                            date_prevue: '2025-07-15',
                            quantite: 5,
                            prix_unitaire: 400000,
                            total: 2000000
                        }
                    ],
                    voyages: [
                        {
                            id: 1,
                            destination: 'Ouagadougou, Burkina Faso',
                            employe_nom: 'Directeur Commercial',
                            date_depart: '2025-07-10',
                            date_retour: '2025-07-15',
                            budget: 850000,
                            statut: 'Approuvé'
                        }
                    ]
                };
            } catch (error) {
                console.error('Erreur lors du chargement de la planification:', error);
                this.showNotification('Erreur lors du chargement de la planification', 'error');
            }
        },

        calculateBudgetPrevisionnel() {
            // Calculer les revenus prévisionnels
            this.budgetPrevisionnel.revenus_projets = this.planification.projets.reduce((sum, p) => sum + parseFloat(p.budget_estime || 0), 0);
            this.budgetPrevisionnel.revenus_factures = 5000000; // Simulation
            this.budgetPrevisionnel.total_revenus = this.budgetPrevisionnel.revenus_factures + this.budgetPrevisionnel.revenus_projets;

            // Calculer les dépenses prévisionnelles
            this.budgetPrevisionnel.depenses_salaires = 2100000; // Simulation
            this.budgetPrevisionnel.depenses_maintenances = 500000;
            this.budgetPrevisionnel.depenses_carburant = 300000;
            this.budgetPrevisionnel.depenses_achats = this.planification.achats.reduce((sum, a) => sum + parseFloat(a.total || 0), 0);
            this.budgetPrevisionnel.depenses_voyages = this.planification.voyages.reduce((sum, v) => sum + parseFloat(v.budget || 0), 0);

            this.budgetPrevisionnel.total_depenses =
                this.budgetPrevisionnel.depenses_salaires +
                this.budgetPrevisionnel.depenses_maintenances +
                this.budgetPrevisionnel.depenses_carburant +
                this.budgetPrevisionnel.depenses_achats +
                this.budgetPrevisionnel.depenses_voyages;

            // Calculer le résultat
            this.budgetPrevisionnel.resultat = this.budgetPrevisionnel.total_revenus - this.budgetPrevisionnel.total_depenses;
        }
    }
};
