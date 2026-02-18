// Transactions Component - Comptable uniquement
const TransactionsComponent = {
    template: `
    <div class="transactions fade-in">
        <!-- Page Header -->
        <div class="page-header transactions-header">
            <h1>
                <i class="fas fa-exchange-alt me-2"></i>
                Gestion des Transactions
            </h1>
            <p class="text-muted">Suivi des paiements, salaires, maintenances et autres dépenses</p>
            <div class="page-header-actions">
                <button @click="exportTransactions" class="btn btn-success">
                    <i class="fas fa-download me-2"></i>Exporter
                </button>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="row mb-4" v-if="stats">
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card paiements">
                    <div class="stat-icon">
                        <i class="fas fa-credit-card"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.total_paiements || 0) }}</div>
                    <div class="stat-label">Paiements reçus</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-calendar me-1"></i>
                        {{ stats.paiements_ce_mois || 0 }} ce mois
                    </small>
                </div>
            </div>
            
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card salaires">
                    <div class="stat-icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.total_salaires || 0) }}</div>
                    <div class="stat-label">Salaires payés</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-calendar me-1"></i>
                        {{ stats.salaires_ce_mois || 0 }} ce mois
                    </small>
                </div>
            </div>
            
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card maintenances">
                    <div class="stat-icon">
                        <i class="fas fa-tools"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.total_maintenances || 0) }}</div>
                    <div class="stat-label">Maintenances</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-calendar me-1"></i>
                        {{ stats.maintenances_ce_mois || 0 }} ce mois
                    </small>
                </div>
            </div>
            
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card autres">
                    <div class="stat-icon">
                        <i class="fas fa-receipt"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.total_autres || 0) }}</div>
                    <div class="stat-label">Autres dépenses</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-calendar me-1"></i>
                        {{ stats.autres_ce_mois || 0 }} ce mois
                    </small>
                </div>
            </div>
        </div>

        <!-- Transactions Tabs -->
        <div class="card">
            <div class="card-header">
                <ul class="nav nav-tabs card-header-tabs" id="transactionsTabs" role="tablist">
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
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="maintenances-tab" data-bs-toggle="tab" data-bs-target="#maintenances" type="button" role="tab">
                            <i class="fas fa-tools me-2"></i>Maintenances
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="carburant-tab" data-bs-toggle="tab" data-bs-target="#carburant" type="button" role="tab">
                            <i class="fas fa-gas-pump me-2"></i>Carburant
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="autres-depenses-tab" data-bs-toggle="tab" data-bs-target="#autres-depenses" type="button" role="tab">
                            <i class="fas fa-receipt me-2"></i>Autres Dépenses
                        </button>
                    </li>
                </ul>
            </div>
            
            <div class="card-body">
                <div class="tab-content" id="transactionsTabContent">
                    <!-- Paiements Clients -->
                    <div class="tab-pane fade show active" id="paiements" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Paiements des Clients</h6>
                            <button @click="addTransaction('paiement')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Ajouter Paiement
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Référence</th>
                                        <th>Client</th>
                                        <th>Facture</th>
                                        <th>Montant</th>
                                        <th>Mode</th>
                                        <th>Actions</th>
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
                                        <td>
                                            <button @click="editTransaction(transaction)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deleteTransaction(transaction)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Salaires -->
                    <div class="tab-pane fade" id="salaires" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Paiements des Salaires</h6>
                            <button @click="addTransaction('salaire')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Ajouter Salaire
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Référence</th>
                                        <th>Employé</th>
                                        <th>Période</th>
                                        <th>Montant</th>
                                        <th>Statut</th>
                                        <th>Actions</th>
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
                                        <td>
                                            <button @click="editTransaction(transaction)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deleteTransaction(transaction)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Maintenances -->
                    <div class="tab-pane fade" id="maintenances" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Dépenses de Maintenance</h6>
                            <button @click="addTransaction('maintenance')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Ajouter Maintenance
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Référence</th>
                                        <th>Véhicule</th>
                                        <th>Type</th>
                                        <th>Description</th>
                                        <th>Montant</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="transaction in transactions.maintenances" :key="transaction.id">
                                        <td>{{ formatDate(transaction.date) }}</td>
                                        <td><strong>{{ transaction.reference }}</strong></td>
                                        <td>{{ transaction.vehicule_immatriculation }}</td>
                                        <td><span class="badge bg-warning">{{ transaction.type_maintenance }}</span></td>
                                        <td>{{ transaction.description }}</td>
                                        <td class="text-danger">{{ formatCurrency(transaction.montant) }}</td>
                                        <td>
                                            <button @click="editTransaction(transaction)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deleteTransaction(transaction)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Carburant -->
                    <div class="tab-pane fade" id="carburant" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Achats de Carburant</h6>
                            <button @click="addTransaction('carburant')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Ajouter Achat
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Référence</th>
                                        <th>Véhicule</th>
                                        <th>Quantité (L)</th>
                                        <th>Prix/L</th>
                                        <th>Montant Total</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="transaction in transactions.carburant" :key="transaction.id">
                                        <td>{{ formatDate(transaction.date) }}</td>
                                        <td><strong>{{ transaction.reference }}</strong></td>
                                        <td>{{ transaction.vehicule_immatriculation }}</td>
                                        <td>{{ transaction.quantite }}</td>
                                        <td>{{ formatCurrency(transaction.prix_unitaire) }}</td>
                                        <td class="text-danger">{{ formatCurrency(transaction.montant) }}</td>
                                        <td>
                                            <button @click="editTransaction(transaction)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deleteTransaction(transaction)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Autres Dépenses -->
                    <div class="tab-pane fade" id="autres-depenses" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Autres Dépenses</h6>
                            <button @click="addTransaction('autre')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Ajouter Dépense
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Référence</th>
                                        <th>Catégorie</th>
                                        <th>Description</th>
                                        <th>Montant</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="transaction in transactions.autres" :key="transaction.id">
                                        <td>{{ formatDate(transaction.date) }}</td>
                                        <td><strong>{{ transaction.reference }}</strong></td>
                                        <td><span class="badge bg-secondary">{{ transaction.categorie }}</span></td>
                                        <td>{{ transaction.description }}</td>
                                        <td class="text-danger">{{ formatCurrency(transaction.montant) }}</td>
                                        <td>
                                            <button @click="editTransaction(transaction)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deleteTransaction(transaction)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Loading State -->
        <div v-if="loading" class="text-center py-5">
            <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">Chargement...</span>
            </div>
            <p class="mt-2 text-muted">Chargement des transactions...</p>
        </div>
    </div>
    `,
    
    inject: ['showNotification', 'handleApiError', 'formatDate', 'formatCurrency', 'formatNumber', 'hasPermission', 'user'],
    
    data() {
        return {
            loading: true,
            stats: null,
            transactions: {
                paiements: [],
                salaires: [],
                maintenances: [],
                carburant: [],
                autres: []
            }
        }
    },
    
    async mounted() {
        // Vérifier les permissions
        if (!this.hasPermission('transactions', 'read')) {
            this.$router.push('/dashboard');
            this.showNotification('Accès non autorisé', 'error');
            return;
        }

        await this.loadTransactions();
        await this.loadStats();
        this.loading = false;
    },
    
    methods: {
        async loadTransactions() {
            try {
                // Charger les transactions depuis l'API
                const response = await axios.get('/transactions');

                if (response.data.success) {
                    const allTransactions = response.data.data;

                    // Organiser les transactions par type
                    this.transactions = {
                        paiements: allTransactions.filter(t => t.type === 'paiement'),
                        salaires: allTransactions.filter(t => t.type === 'salaire'),
                        maintenances: allTransactions.filter(t => t.type === 'maintenance'),
                        carburant: allTransactions.filter(t => t.type === 'carburant'),
                        autres: allTransactions.filter(t => t.type === 'autre')
                    };
                } else {
                    throw new Error(response.data.error || 'Erreur lors du chargement');
                }
            } catch (error) {
                console.error('Erreur lors du chargement des transactions:', error);

                // En cas d'erreur, initialiser avec des tableaux vides
                this.transactions = {
                    paiements: [],
                    salaires: [],
                    maintenances: [],
                    carburant: [],
                    autres: []
                };

                this.handleApiError(error, 'Erreur lors du chargement des transactions');
            }
        },
        
        async loadStats() {
            try {
                // Charger les statistiques depuis l'API
                const response = await axios.get('/transactions/stats');

                if (response.data.success) {
                    this.stats = response.data.data;
                } else {
                    throw new Error(response.data.error || 'Erreur lors du calcul des statistiques');
                }
            } catch (error) {
                console.error('Erreur lors du chargement des statistiques:', error);

                // En cas d'erreur, calculer localement avec les données disponibles
                this.stats = {
                    total_paiements: this.transactions.paiements.reduce((sum, t) => sum + parseFloat(t.montant || 0), 0),
                    total_salaires: this.transactions.salaires.reduce((sum, t) => sum + parseFloat(t.montant || 0), 0),
                    total_maintenances: this.transactions.maintenances.reduce((sum, t) => sum + parseFloat(t.montant || 0), 0),
                    total_carburant: this.transactions.carburant.reduce((sum, t) => sum + parseFloat(t.montant || 0), 0),
                    total_autres: this.transactions.autres.reduce((sum, t) => sum + parseFloat(t.montant || 0), 0),
                    paiements_ce_mois: this.transactions.paiements.length,
                    salaires_ce_mois: this.transactions.salaires.length,
                    maintenances_ce_mois: this.transactions.maintenances.length,
                    autres_ce_mois: this.transactions.autres.length
                };

                this.handleApiError(error, 'Erreur lors du calcul des statistiques');
            }
        },
        
        addTransaction(type) {
            this.showNotification(`Fonctionnalité d'ajout pour ${type} en cours de développement`, 'info');
            // TODO: Implémenter un modal pour ajouter une nouvelle transaction
            // Exemple d'appel API:
            // const response = await axios.post('/api/transactions', newTransactionData);
        },

        editTransaction(transaction) {
            this.showNotification(`Fonctionnalité de modification en cours de développement`, 'info');
            // TODO: Implémenter un modal pour modifier la transaction
            // Exemple d'appel API:
            // const response = await axios.put(`/api/transactions/${transaction.id}`, updatedData);
        },

        async deleteTransaction(transaction) {
            if (!confirm(`Êtes-vous sûr de vouloir supprimer la transaction ${transaction.reference} ?`)) {
                return;
            }

            try {
                const response = await axios.delete(`/transactions/${transaction.id}`);

                if (response.data.success) {
                    this.showNotification(`Transaction ${transaction.reference} supprimée avec succès`, 'success');

                    // Recharger les données
                    await this.loadTransactions();
                    await this.loadStats();
                } else {
                    throw new Error(response.data.error || 'Erreur lors de la suppression');
                }
            } catch (error) {
                console.error('Erreur lors de la suppression:', error);
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        async exportTransactions() {
            try {
                this.showNotification('Export des transactions en cours...', 'info');

                // Déclencher le téléchargement du fichier CSV
                const link = document.createElement('a');
                link.href = '/transactions/export';
                link.download = `transactions_${new Date().toISOString().split('T')[0]}.csv`;
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);

                this.showNotification('Export terminé avec succès', 'success');
            } catch (error) {
                console.error('Erreur lors de l\'export:', error);
                this.handleApiError(error, 'Erreur lors de l\'export');
            }
        }
    }
};
