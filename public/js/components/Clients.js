// Clients Component
const ClientsComponent = {
    template: `
    <div class="clients fade-in">
        <!-- Page Header -->
        <div class="page-header clients-header">
            <h1>
                <i class="fas fa-users me-2"></i>
                Gestion des clients
            </h1>
            <div class="page-header-actions">
                <button v-if="hasPermission('clients', 'write')" 
                        @click="showCreateModal" 
                        class="btn btn-primary btn-icon-right">
                    <i class="fas fa-plus"></i>
                    Nouveau client
                </button>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="row mb-4">
            <div class="col-xl-3 col-md-6 mb-4">
                <div class="card border-left-primary shadow h-100 py-2">
                    <div class="card-body">
                        <div class="row no-gutters align-items-center">
                            <div class="col mr-2">
                                <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">
                                    Total Clients
                                </div>
                                <div class="h5 mb-0 font-weight-bold text-gray-800">
                                    {{ clientStats.totalClients }}
                                </div>
                            </div>
                            <div class="col-auto">
                                <i class="fas fa-users fa-2x text-gray-300"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-md-6 mb-4">
                <div class="card border-left-success shadow h-100 py-2">
                    <div class="card-body">
                        <div class="row no-gutters align-items-center">
                            <div class="col mr-2">
                                <div class="text-xs font-weight-bold text-success text-uppercase mb-1">
                                    Clients Actifs
                                </div>
                                <div class="h5 mb-0 font-weight-bold text-gray-800">
                                    {{ clientStats.clientsActifs }}
                                </div>
                                <div class="text-xs text-muted">
                                    ({{ clientStats.pourcentageActifs }}% du total)
                                </div>
                            </div>
                            <div class="col-auto">
                                <i class="fas fa-user-check fa-2x text-gray-300"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-md-6 mb-4">
                <div class="card border-left-info shadow h-100 py-2">
                    <div class="card-body">
                        <div class="row no-gutters align-items-center">
                            <div class="col mr-2">
                                <div class="text-xs font-weight-bold text-info text-uppercase mb-1">
                                    Nouveaux ce mois
                                </div>
                                <div class="h5 mb-0 font-weight-bold text-gray-800">
                                    {{ clientStats.nouveauxCeMois }}
                                </div>
                                <div class="text-xs" :class="clientStats.evolutionCouleur">
                                    <i :class="clientStats.evolutionIcone"></i>
                                    {{ clientStats.evolutionTexte }}
                                </div>
                            </div>
                            <div class="col-auto">
                                <i class="fas fa-user-plus fa-2x text-gray-300"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-md-6 mb-4">
                <div class="card border-left-warning shadow h-100 py-2">
                    <div class="card-body">
                        <div class="row no-gutters align-items-center">
                            <div class="col mr-2">
                                <div class="text-xs font-weight-bold text-warning text-uppercase mb-1">
                                    Chiffre d'Affaires
                                </div>
                                <div class="h5 mb-0 font-weight-bold text-gray-800">
                                    {{ formatCurrency(clientStats.chiffreAffaires) }}
                                </div>
                                <div class="text-xs text-muted">
                                    Moyenne: {{ formatCurrency(clientStats.moyenneParClient) }}/client
                                </div>
                            </div>
                            <div class="col-auto">
                                <i class="fas fa-franc-sign fa-2x text-gray-300"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Top Clients Cards -->
        <div class="row mb-4">
            <div class="col-lg-6 mb-4">
                <div class="card shadow">
                    <div class="card-header py-3 d-flex flex-row align-items-center justify-content-between">
                        <h6 class="m-0 font-weight-bold text-primary">
                            <i class="fas fa-crown me-2"></i>Top 5 Clients (Commandes)
                        </h6>
                    </div>
                    <div class="card-body">
                        <div v-if="clientStats.topClientsCommandes.length === 0" class="text-center text-muted py-3">
                            <i class="fas fa-chart-bar fa-2x mb-2"></i>
                            <p>Aucune donnée disponible</p>
                        </div>
                        <div v-else>
                            <div v-for="(client, index) in clientStats.topClientsCommandes" :key="client.id" class="d-flex align-items-center mb-3">
                                <div class="me-3">
                                    <div class="icon-circle" :class="getTopClientClass(index)">
                                        {{ index + 1 }}
                                    </div>
                                </div>
                                <div class="flex-grow-1">
                                    <div class="small font-weight-bold">{{ client.nom }} {{ client.prenom }}</div>
                                    <div class="text-muted small">{{ client.entreprise || 'Particulier' }}</div>
                                </div>
                                <div class="text-end">
                                    <div class="font-weight-bold text-primary">{{ client.nb_commandes }}</div>
                                    <div class="text-muted small">commandes</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-lg-6 mb-4">
                <div class="card shadow">
                    <div class="card-header py-3 d-flex flex-row align-items-center justify-content-between">
                        <h6 class="m-0 font-weight-bold text-success">
                            <i class="fas fa-chart-line me-2"></i>Répartition par Ville
                        </h6>
                    </div>
                    <div class="card-body">
                        <div v-if="clientStats.repartitionVilles.length === 0" class="text-center text-muted py-3">
                            <i class="fas fa-map-marker-alt fa-2x mb-2"></i>
                            <p>Aucune donnée disponible</p>
                        </div>
                        <div v-else>
                            <div v-for="ville in clientStats.repartitionVilles" :key="ville.nom" class="d-flex align-items-center mb-3">
                                <div class="me-3">
                                    <i class="fas fa-map-marker-alt text-success"></i>
                                </div>
                                <div class="flex-grow-1">
                                    <div class="small font-weight-bold">{{ ville.nom || 'Non spécifiée' }}</div>
                                    <div class="progress" style="height: 6px;">
                                        <div class="progress-bar bg-success"
                                             :style="{ width: ville.pourcentage + '%' }">
                                        </div>
                                    </div>
                                </div>
                                <div class="text-end">
                                    <div class="font-weight-bold text-success">{{ ville.count }}</div>
                                    <div class="text-muted small">{{ ville.pourcentage }}%</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Search and Filters -->
        <div class="card mb-4">
            <div class="card-body">
                <div class="row">
                    <div class="col-md-6">
                        <div class="input-group">
                            <span class="input-group-text">
                                <i class="fas fa-search"></i>
                            </span>
                            <input type="text" 
                                   class="form-control" 
                                   placeholder="Rechercher un client..."
                                   v-model="searchQuery"
                                   @input="searchClients">
                        </div>
                    </div>
                    <div class="col-md-6">
                        <button @click="loadClients" class="btn btn-outline-secondary">
                            <i class="fas fa-sync-alt me-2"></i>
                            Actualiser
                        </button>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Clients Table -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">
                    <i class="fas fa-list me-2"></i>
                    Liste des clients ({{ clients.length }})
                </h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th>Nom</th>
                                <th>Entreprise</th>
                                <th>Contact</th>
                                <th>Commandes</th>
                                <th>Dernière commande</th>
                                <th width="150">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="loading">
                                <td colspan="6" class="text-center py-4">
                                    <div class="spinner-border text-primary" role="status">
                                        <span class="visually-hidden">Chargement...</span>
                                    </div>
                                </td>
                            </tr>
                            <tr v-else-if="clients.length === 0">
                                <td colspan="6" class="text-center py-4 text-muted">
                                    <i class="fas fa-users fa-3x mb-3 d-block"></i>
                                    Aucun client trouvé
                                </td>
                            </tr>
                            <tr v-else v-for="client in clients" :key="client.id">
                                <td>
                                    <strong>{{ client.nom }} {{ client.prenom }}</strong>
                                    <br>
                                    <small class="text-muted">{{ client.email }}</small>
                                </td>
                                <td>{{ client.entreprise || '-' }}</td>
                                <td>
                                    <div>
                                        <i class="fas fa-phone me-1"></i>
                                        {{ client.telephone || '-' }}
                                    </div>
                                    <div v-if="client.ville">
                                        <i class="fas fa-map-marker-alt me-1"></i>
                                        {{ client.ville }}
                                    </div>
                                </td>
                                <td>
                                    <span class="badge bg-primary">{{ client.nb_commandes || 0 }}</span>
                                </td>
                                <td>{{ formatDate(client.derniere_commande) }}</td>
                                <td>
                                    <div class="action-buttons">
                                        <button @click="viewClient(client)" 
                                                class="btn btn-sm btn-outline-info" 
                                                title="Voir détails">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        <button v-if="hasPermission('clients', 'write')"
                                                @click="editClient(client)" 
                                                class="btn btn-sm btn-outline-primary" 
                                                title="Modifier">
                                            <i class="fas fa-edit"></i>
                                        </button>
                                        <button v-if="hasPermission('clients', 'delete')"
                                                @click="deleteClient(client)" 
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
        
        <!-- Client Modal -->
        <div class="modal fade" ref="clientModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-user me-2"></i>
                            {{ modalMode === 'create' ? 'Nouveau client' : modalMode === 'edit' ? 'Modifier client' : 'Détails client' }}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form @submit.prevent="saveClient" v-if="modalMode !== 'view'">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Nom *</label>
                                        <input type="text" class="form-control" v-model="currentClient.nom" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Prénom</label>
                                        <input type="text" class="form-control" v-model="currentClient.prenom">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Entreprise</label>
                                <input type="text" class="form-control" v-model="currentClient.entreprise">
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Email *</label>
                                        <input type="email" class="form-control" v-model="currentClient.email" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Téléphone *</label>
                                        <input type="tel" class="form-control" v-model="currentClient.telephone" required>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Adresse</label>
                                <textarea class="form-control" rows="2" v-model="currentClient.adresse"></textarea>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Code postal</label>
                                        <input type="text" class="form-control" v-model="currentClient.code_postal">
                                    </div>
                                </div>
                                <div class="col-md-8">
                                    <div class="mb-3">
                                        <label class="form-label">Ville</label>
                                        <input type="text" class="form-control" v-model="currentClient.ville">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Notes</label>
                                <textarea class="form-control" rows="3" v-model="currentClient.notes"></textarea>
                            </div>
                        </form>
                        
                        <!-- View Mode -->
                        <div v-else>
                            <div class="row">
                                <div class="col-md-6">
                                    <h6>Informations personnelles</h6>
                                    <p><strong>Nom:</strong> {{ currentClient.nom }} {{ currentClient.prenom }}</p>
                                    <p><strong>Entreprise:</strong> {{ currentClient.entreprise || '-' }}</p>
                                    <p><strong>Email:</strong> {{ currentClient.email }}</p>
                                    <p><strong>Téléphone:</strong> {{ currentClient.telephone }}</p>
                                </div>
                                <div class="col-md-6">
                                    <h6>Adresse</h6>
                                    <p>{{ currentClient.adresse || '-' }}</p>
                                    <p>{{ currentClient.code_postal }} {{ currentClient.ville }}</p>
                                    
                                    <h6 class="mt-3">Statistiques</h6>
                                    <p><strong>Commandes:</strong> {{ currentClient.nb_commandes || 0 }}</p>
                                    <p><strong>Dernière commande:</strong> {{ formatDate(currentClient.derniere_commande) }}</p>
                                </div>
                            </div>
                            
                            <div v-if="currentClient.notes" class="mt-3">
                                <h6>Notes</h6>
                                <p>{{ currentClient.notes }}</p>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            {{ modalMode === 'view' ? 'Fermer' : 'Annuler' }}
                        </button>
                        <button v-if="modalMode !== 'view'" 
                                type="submit" 
                                form="clientForm"
                                @click="saveClient"
                                class="btn btn-primary"
                                :disabled="saving">
                            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
                            {{ modalMode === 'create' ? 'Créer' : 'Sauvegarder' }}
                        </button>
                        <button v-if="modalMode === 'view' && hasPermission('commandes', 'read')"
                                @click="viewClientOrders"
                                class="btn btn-info btn-icon-right">
                            <i class="fas fa-list"></i>
                            Voir commandes
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    `,
    
    inject: ['showNotification', 'handleApiError', 'formatDate', 'formatCurrency', 'formatNumber', 'hasPermission'],
    
    data() {
        return {
            clients: [],
            loading: false,
            saving: false,
            searchQuery: '',
            modalMode: 'view', // 'create', 'edit', 'view'
            currentClient: {},
            modal: null,
            clientStats: {
                totalClients: 0,
                clientsActifs: 0,
                pourcentageActifs: 0,
                nouveauxCeMois: 0,
                evolutionTexte: '',
                evolutionCouleur: '',
                evolutionIcone: '',
                chiffreAffaires: 0,
                moyenneParClient: 0,
                topClientsCommandes: [],
                repartitionVilles: []
            }
        }
    },
    
    mounted() {
        this.loadClients();
        this.loadClientStats();
        this.modal = new bootstrap.Modal(this.$refs.clientModal);
    },
    
    methods: {
        async loadClients() {
            this.loading = true;
            try {
                const response = await axios.get('/clients');
                this.clients = response.data.data || [];
                this.calculateClientStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement des clients');
                this.clients = [];
            }
            this.loading = false;
        },



        loadClientStats() {
            try {
                this.calculateClientStats();
            } catch (error) {
                console.error('Erreur lors du chargement des statistiques:', error);
            }
        },

        calculateClientStats() {
            if (!this.clients || this.clients.length === 0) {
                this.clientStats = {
                    totalClients: 0,
                    clientsActifs: 0,
                    pourcentageActifs: 0,
                    nouveauxCeMois: 0,
                    evolutionTexte: 'Aucune donnée',
                    evolutionCouleur: 'text-muted',
                    evolutionIcone: 'fas fa-minus',
                    chiffreAffaires: 0,
                    moyenneParClient: 0,
                    topClientsCommandes: [],
                    repartitionVilles: []
                };
                return;
            }

            // Calculs de base
            this.clientStats.totalClients = this.clients.length;

            // Clients actifs (ayant au moins une commande)
            const clientsActifs = this.clients.filter(client => (client.nb_commandes || 0) > 0);
            this.clientStats.clientsActifs = clientsActifs.length;
            this.clientStats.pourcentageActifs = this.clientStats.totalClients > 0
                ? Math.round((this.clientStats.clientsActifs / this.clientStats.totalClients) * 100)
                : 0;

            // Nouveaux clients ce mois (à calculer avec de vraies données)
            this.clientStats.nouveauxCeMois = 0;
            this.clientStats.evolutionTexte = 'Données non disponibles';
            this.clientStats.evolutionCouleur = 'text-muted';
            this.clientStats.evolutionIcone = 'fas fa-minus';

            // Chiffre d'affaires (à calculer avec de vraies données)
            this.clientStats.chiffreAffaires = 0;
            this.clientStats.moyenneParClient = 0;

            // Top 5 clients par nombre de commandes
            this.clientStats.topClientsCommandes = [...this.clients]
                .filter(client => (client.nb_commandes || 0) > 0)
                .sort((a, b) => (b.nb_commandes || 0) - (a.nb_commandes || 0))
                .slice(0, 5);

            // Répartition par ville
            const villesCount = {};
            this.clients.forEach(client => {
                const ville = client.ville || 'Non spécifiée';
                villesCount[ville] = (villesCount[ville] || 0) + 1;
            });

            this.clientStats.repartitionVilles = Object.entries(villesCount)
                .map(([nom, count]) => ({
                    nom,
                    count,
                    pourcentage: Math.round((count / this.clientStats.totalClients) * 100)
                }))
                .sort((a, b) => b.count - a.count)
                .slice(0, 5);
        },

        getTopClientClass(index) {
            const classes = ['bg-warning', 'bg-info', 'bg-success', 'bg-secondary', 'bg-dark'];
            return classes[index] || 'bg-secondary';
        },
        
        async searchClients() {
            if (this.searchQuery.length < 2) {
                await this.loadClients();
                return;
            }
            
            try {
                const response = await axios.get('/clients/search', {
                    params: { q: this.searchQuery }
                });
                this.clients = response.data.data;
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la recherche');
            }
        },
        
        showCreateModal() {
            this.modalMode = 'create';
            this.currentClient = {
                nom: '',
                prenom: '',
                entreprise: '',
                email: '',
                telephone: '',
                adresse: '',
                ville: '',
                code_postal: '',
                notes: ''
            };
            this.modal.show();
        },
        
        viewClient(client) {
            this.modalMode = 'view';
            this.currentClient = { ...client };
            this.modal.show();
        },
        
        editClient(client) {
            this.modalMode = 'edit';
            this.currentClient = { ...client };
            this.modal.show();
        },
        
        async saveClient() {
            this.saving = true;
            
            try {
                if (this.modalMode === 'create') {
                    await axios.post('/clients', this.currentClient);
                    this.showNotification('Client créé avec succès', 'success');
                } else {
                    await axios.put(`/clients/${this.currentClient.id}`, this.currentClient);
                    this.showNotification('Client modifié avec succès', 'success');
                }
                
                this.modal.hide();
                await this.loadClients();
                this.calculateClientStats();
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la sauvegarde');
            }
            
            this.saving = false;
        },
        
        async deleteClient(client) {
            if (!confirm(`Êtes-vous sûr de vouloir supprimer le client "${client.nom} ${client.prenom}" ?`)) {
                return;
            }
            
            try {
                await axios.delete(`/clients/${client.id}`);
                this.showNotification('Client supprimé avec succès', 'success');
                await this.loadClients();
                this.calculateClientStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        viewClientOrders() {
            // Navigate to orders filtered by this client
            this.$router.push(`/commandes?client_id=${this.currentClient.id}`);
            this.modal.hide();
        }
    }
};
