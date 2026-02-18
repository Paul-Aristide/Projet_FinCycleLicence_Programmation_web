// Planification & Budget Component - Comptable uniquement
const PlanificationBudgetComponent = {
    template: `
    <div class="planification-budget fade-in">
        <!-- Page Header -->
        <div class="page-header planification-header">
            <h1>
                <i class="fas fa-calendar-alt me-2"></i>
                Planification & Budget
            </h1>
            <p class="text-muted">Gestion des projets, achats, voyages et budget prévisionnel</p>
            <div class="page-header-actions">
                <button @click="exportPlanification" class="btn btn-success">
                    <i class="fas fa-download me-2"></i>Exporter
                </button>
            </div>
        </div>

        <!-- Budget Summary Cards -->
        <div class="row mb-4" v-if="budgetPrevisionnel">
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card revenus">
                    <div class="stat-icon">
                        <i class="fas fa-arrow-up"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(budgetPrevisionnel.total_revenus || 0) }}</div>
                    <div class="stat-label">Revenus Prévisionnels</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-file-invoice me-1"></i>
                        Factures + Projets
                    </small>
                </div>
            </div>
            
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card depenses">
                    <div class="stat-icon">
                        <i class="fas fa-arrow-down"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(budgetPrevisionnel.total_depenses || 0) }}</div>
                    <div class="stat-label">Dépenses Prévisionnelles</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-receipt me-1"></i>
                        Toutes catégories
                    </small>
                </div>
            </div>
            
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card" :class="budgetPrevisionnel.resultat >= 0 ? 'benefice' : 'perte'">
                    <div class="stat-icon">
                        <i :class="budgetPrevisionnel.resultat >= 0 ? 'fas fa-chart-line' : 'fas fa-chart-line-down'"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(Math.abs(budgetPrevisionnel.resultat || 0)) }}</div>
                    <div class="stat-label">{{ budgetPrevisionnel.resultat >= 0 ? 'Bénéfice Prévu' : 'Perte Prévue' }}</div>
                    <small class="d-block mt-1">
                        <i :class="budgetPrevisionnel.resultat >= 0 ? 'fas fa-thumbs-up me-1' : 'fas fa-exclamation-triangle me-1'"></i>
                        Résultat prévisionnel
                    </small>
                </div>
            </div>
        </div>

        <!-- Planification Tabs -->
        <div class="card">
            <div class="card-header">
                <ul class="nav nav-tabs card-header-tabs" id="planificationTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="projets-tab" data-bs-toggle="tab" data-bs-target="#projets" type="button" role="tab">
                            <i class="fas fa-project-diagram me-2"></i>Projets à Venir
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="achats-tab" data-bs-toggle="tab" data-bs-target="#achats" type="button" role="tab">
                            <i class="fas fa-shopping-cart me-2"></i>Achats Prévus
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="voyages-tab" data-bs-toggle="tab" data-bs-target="#voyages" type="button" role="tab">
                            <i class="fas fa-plane me-2"></i>Voyages d'Affaires
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="budget-tab" data-bs-toggle="tab" data-bs-target="#budget" type="button" role="tab">
                            <i class="fas fa-chart-pie me-2"></i>Budget Détaillé
                        </button>
                    </li>
                </ul>
            </div>
            
            <div class="card-body">
                <div class="tab-content" id="planificationTabContent">
                    <!-- Projets à Venir -->
                    <div class="tab-pane fade show active" id="projets" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Projets à Venir</h6>
                            <button @click="addPlanification('projet')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Nouveau Projet
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Nom du Projet</th>
                                        <th>Date Début</th>
                                        <th>Date Fin</th>
                                        <th>Budget Estimé</th>
                                        <th>Priorité</th>
                                        <th>Statut</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="projet in planification.projets" :key="projet.id">
                                        <td><strong>{{ projet.nom }}</strong></td>
                                        <td>{{ formatDate(projet.date_debut) }}</td>
                                        <td>{{ formatDate(projet.date_fin) }}</td>
                                        <td>{{ formatCurrency(projet.budget_estime) }}</td>
                                        <td><span :class="'badge ' + getPriorityClass(projet.priorite)">{{ projet.priorite }}</span></td>
                                        <td><span :class="'badge ' + getStatusClass(projet.statut)">{{ projet.statut }}</span></td>
                                        <td>
                                            <button @click="editPlanification(projet)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deletePlanification(projet)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Achats Prévus -->
                    <div class="tab-pane fade" id="achats" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Achats Prévus</h6>
                            <button @click="addPlanification('achat')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Nouvel Achat
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Article</th>
                                        <th>Catégorie</th>
                                        <th>Date Prévue</th>
                                        <th>Quantité</th>
                                        <th>Prix Unitaire</th>
                                        <th>Total</th>
                                        <th>Actions</th>
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
                                        <td>
                                            <button @click="editPlanification(achat)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deletePlanification(achat)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Voyages d'Affaires -->
                    <div class="tab-pane fade" id="voyages" role="tabpanel">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6>Voyages d'Affaires</h6>
                            <button @click="addPlanification('voyage')" class="btn btn-success">
                                <i class="fas fa-plus"></i> Nouveau Voyage
                            </button>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Destination</th>
                                        <th>Employé</th>
                                        <th>Date Départ</th>
                                        <th>Date Retour</th>
                                        <th>Budget</th>
                                        <th>Statut</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="voyage in planification.voyages" :key="voyage.id">
                                        <td><strong>{{ voyage.destination }}</strong></td>
                                        <td>{{ voyage.employe_nom }}</td>
                                        <td>{{ formatDate(voyage.date_depart) }}</td>
                                        <td>{{ formatDate(voyage.date_retour) }}</td>
                                        <td>{{ formatCurrency(voyage.budget) }}</td>
                                        <td><span :class="'badge ' + getStatusClass(voyage.statut)">{{ voyage.statut }}</span></td>
                                        <td>
                                            <button @click="editPlanification(voyage)" class="btn btn-sm btn-outline-primary me-1">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button @click="deletePlanification(voyage)" class="btn btn-sm btn-outline-danger">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Budget Détaillé -->
                    <div class="tab-pane fade" id="budget" role="tabpanel">
                        <div class="row">
                            <div class="col-md-6">
                                <div class="card">
                                    <div class="card-header bg-success text-white">
                                        <h6 class="mb-0">
                                            <i class="fas fa-arrow-up me-2"></i>
                                            Revenus Prévisionnels
                                        </h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Factures en cours:</span>
                                            <strong class="text-success">{{ formatCurrency(budgetPrevisionnel.revenus_factures) }}</strong>
                                        </div>
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Projets prévus:</span>
                                            <strong class="text-success">{{ formatCurrency(budgetPrevisionnel.revenus_projets) }}</strong>
                                        </div>
                                        <hr>
                                        <div class="d-flex justify-content-between">
                                            <strong>Total Revenus:</strong>
                                            <strong class="text-success">{{ formatCurrency(budgetPrevisionnel.total_revenus) }}</strong>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="col-md-6">
                                <div class="card">
                                    <div class="card-header bg-danger text-white">
                                        <h6 class="mb-0">
                                            <i class="fas fa-arrow-down me-2"></i>
                                            Dépenses Prévisionnelles
                                        </h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Salaires:</span>
                                            <strong class="text-danger">{{ formatCurrency(budgetPrevisionnel.depenses_salaires) }}</strong>
                                        </div>
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Maintenances:</span>
                                            <strong class="text-danger">{{ formatCurrency(budgetPrevisionnel.depenses_maintenances) }}</strong>
                                        </div>
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Carburant:</span>
                                            <strong class="text-danger">{{ formatCurrency(budgetPrevisionnel.depenses_carburant) }}</strong>
                                        </div>
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Achats prévus:</span>
                                            <strong class="text-danger">{{ formatCurrency(budgetPrevisionnel.depenses_achats) }}</strong>
                                        </div>
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>Voyages:</span>
                                            <strong class="text-danger">{{ formatCurrency(budgetPrevisionnel.depenses_voyages) }}</strong>
                                        </div>
                                        <hr>
                                        <div class="d-flex justify-content-between">
                                            <strong>Total Dépenses:</strong>
                                            <strong class="text-danger">{{ formatCurrency(budgetPrevisionnel.total_depenses) }}</strong>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="row mt-3">
                            <div class="col-12">
                                <div class="card">
                                    <div class="card-body text-center">
                                        <h5>Résultat Prévisionnel</h5>
                                        <h3 :class="budgetPrevisionnel.resultat >= 0 ? 'text-success' : 'text-danger'">
                                            {{ formatCurrency(budgetPrevisionnel.resultat) }}
                                        </h3>
                                        <small class="text-muted">
                                            {{ budgetPrevisionnel.resultat >= 0 ? 'Bénéfice prévu' : 'Perte prévue' }}
                                        </small>
                                    </div>
                                </div>
                            </div>
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
            <p class="mt-2 text-muted">Chargement de la planification...</p>
        </div>
    </div>
    `,
    
    inject: ['showNotification', 'handleApiError', 'formatDate', 'formatCurrency', 'formatNumber', 'hasPermission', 'user'],
    
    data() {
        return {
            loading: true,
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
            }
        }
    },
    
    async mounted() {
        // Vérifier les permissions - Interdire l'accès aux administrateurs
        if (!this.hasPermission('planification', 'read') || this.user().role === 'admin') {
            this.$router.push('/dashboard');
            this.showNotification('Accès non autorisé - Page réservée aux comptables uniquement', 'error');
            return;
        }

        await this.loadPlanification();
        await this.calculateBudgetPrevisionnel();
        this.loading = false;
    },
    
    methods: {
        async loadPlanification() {
            try {
                // Charger les données de planification depuis l'API
                const response = await axios.get('/planification');

                if (response.data.success) {
                    const items = response.data.data;

                    // Organiser les données par type
                    this.planification = {
                        projets: items.filter(item => item.type === 'projet'),
                        achats: items.filter(item => item.type === 'achat'),
                        voyages: items.filter(item => item.type === 'voyage')
                    };
                } else {
                    throw new Error(response.data.error || 'Erreur lors du chargement');
                }
            } catch (error) {
                console.error('Erreur lors du chargement de la planification:', error);

                // En cas d'erreur, initialiser avec des tableaux vides
                this.planification = {
                    projets: [],
                    achats: [],
                    voyages: []
                };

                this.handleApiError(error, 'Erreur lors du chargement de la planification');
            }
        },
        
        async calculateBudgetPrevisionnel() {
            try {
                // Charger le budget prévisionnel depuis l'API
                const response = await axios.get('/planification/budget');

                if (response.data.success) {
                    this.budgetPrevisionnel = response.data.data;
                } else {
                    throw new Error(response.data.error || 'Erreur lors du calcul du budget');
                }
            } catch (error) {
                console.error('Erreur lors du calcul du budget:', error);

                // En cas d'erreur, calculer localement avec les données disponibles
                this.budgetPrevisionnel.revenus_projets = this.planification.projets.reduce((sum, p) => sum + parseFloat(p.budget_estime || 0), 0);
                this.budgetPrevisionnel.depenses_achats = this.planification.achats.reduce((sum, a) => sum + parseFloat(a.total || 0), 0);
                this.budgetPrevisionnel.depenses_voyages = this.planification.voyages.reduce((sum, v) => sum + parseFloat(v.budget || 0), 0);

                // Valeurs par défaut pour les autres éléments
                this.budgetPrevisionnel.revenus_factures = this.budgetPrevisionnel.revenus_factures || 0;
                this.budgetPrevisionnel.depenses_salaires = this.budgetPrevisionnel.depenses_salaires || 0;
                this.budgetPrevisionnel.depenses_maintenances = this.budgetPrevisionnel.depenses_maintenances || 0;
                this.budgetPrevisionnel.depenses_carburant = this.budgetPrevisionnel.depenses_carburant || 0;

                this.budgetPrevisionnel.total_revenus = this.budgetPrevisionnel.revenus_factures + this.budgetPrevisionnel.revenus_projets;
                this.budgetPrevisionnel.total_depenses =
                    this.budgetPrevisionnel.depenses_salaires +
                    this.budgetPrevisionnel.depenses_maintenances +
                    this.budgetPrevisionnel.depenses_carburant +
                    this.budgetPrevisionnel.depenses_achats +
                    this.budgetPrevisionnel.depenses_voyages;

                this.budgetPrevisionnel.resultat = this.budgetPrevisionnel.total_revenus - this.budgetPrevisionnel.total_depenses;

                this.handleApiError(error, 'Erreur lors du calcul du budget prévisionnel');
            }
        },
        
        addPlanification(type) {
            this.showNotification(`Fonctionnalité d'ajout pour ${type} en cours de développement`, 'info');
            // TODO: Implémenter un modal pour ajouter un nouvel élément
            // Exemple d'appel API:
            // const response = await axios.post('/api/planification', newItemData);
        },

        editPlanification(item) {
            this.showNotification(`Fonctionnalité de modification en cours de développement`, 'info');
            // TODO: Implémenter un modal pour modifier l'élément
            // Exemple d'appel API:
            // const response = await axios.put(`/api/planification/${item.id}`, updatedData);
        },

        async deletePlanification(item) {
            const name = item.nom || item.article || item.destination;
            if (!confirm(`Êtes-vous sûr de vouloir supprimer: ${name} ?`)) {
                return;
            }

            try {
                const response = await axios.delete(`/planification/${item.id}`);

                if (response.data.success) {
                    this.showNotification(`Élément ${name} supprimé avec succès`, 'success');

                    // Recharger les données
                    await this.loadPlanification();
                    await this.calculateBudgetPrevisionnel();
                } else {
                    throw new Error(response.data.error || 'Erreur lors de la suppression');
                }
            } catch (error) {
                console.error('Erreur lors de la suppression:', error);
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        async exportPlanification() {
            try {
                this.showNotification('Export de la planification en cours...', 'info');

                // Déclencher le téléchargement du fichier CSV
                const link = document.createElement('a');
                link.href = '/planification/export';
                link.download = `planification_${new Date().toISOString().split('T')[0]}.csv`;
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);

                this.showNotification('Export terminé avec succès', 'success');
            } catch (error) {
                console.error('Erreur lors de l\'export:', error);
                this.handleApiError(error, 'Erreur lors de l\'export');
            }
        },
        
        getPriorityClass(priority) {
            const classes = {
                'Haute': 'bg-danger',
                'Moyenne': 'bg-warning',
                'Basse': 'bg-info'
            };
            return classes[priority] || 'bg-secondary';
        },
        
        getStatusClass(status) {
            const classes = {
                'Planifié': 'bg-info',
                'En cours': 'bg-warning',
                'Terminé': 'bg-success',
                'Annulé': 'bg-danger',
                'Approuvé': 'bg-success',
                'En attente': 'bg-warning'
            };
            return classes[status] || 'bg-secondary';
        }
    }
};
