// Trajets Component
const TrajetsComponent = {
    template: `
    <div class="trajets fade-in">
        <!-- Page Header -->
        <div class="page-header trajets-header">
            <h1>
                <i class="fas fa-route me-2"></i>
                Gestion des trajets
            </h1>
        </div>
        
        <div class="row mb-4">
            <div class="col-12 text-end">
                <button v-if="hasPermission('trajets', 'write')" 
                        @click="showCreateModal" 
                        class="btn btn-primary btn-icon-right">
                    <i class="fas fa-plus"></i>
                    Nouveau trajet
                </button>
            </div>
        </div>
        
        <!-- Filters -->
        <div class="card mb-4">
            <div class="card-body">
                <div class="row">
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterStatut" @change="filterTrajets">
                            <option value="">Tous les statuts</option>
                            <option value="planifie">Planifié</option>
                            <option value="en_cours">En cours</option>
                            <option value="termine">Terminé</option>
                            <option value="annule">Annulé</option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterChauffeur" @change="filterTrajets">
                            <option value="">Tous les chauffeurs</option>
                            <option v-for="chauffeur in chauffeurs" :key="chauffeur.id" :value="chauffeur.id">
                                {{ chauffeur.nom }} {{ chauffeur.prenom }}
                            </option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterVehicule" @change="filterTrajets">
                            <option value="">Tous les véhicules</option>
                            <option v-for="vehicule in vehicules" :key="vehicule.id" :value="vehicule.id">
                                {{ vehicule.immatriculation }} - {{ vehicule.marque }}
                            </option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <button @click="loadTrajets" class="btn btn-outline-secondary w-100">
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
                <div class="stat-card trajets">
                    <div class="stat-icon">
                        <i class="fas fa-calendar-alt"></i>
                    </div>
                    <div class="stat-number">{{ stats.planifies || 0 }}</div>
                    <div class="stat-label">Planifiés</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card commandes">
                    <div class="stat-icon">
                        <i class="fas fa-play"></i>
                    </div>
                    <div class="stat-number">{{ stats.en_cours || 0 }}</div>
                    <div class="stat-label">En cours</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card vehicules">
                    <div class="stat-icon">
                        <i class="fas fa-check-circle"></i>
                    </div>
                    <div class="stat-number">{{ stats.termines || 0 }}</div>
                    <div class="stat-label">Terminés</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card factures">
                    <div class="stat-icon">
                        <i class="fas fa-road"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.distance_totale || 0) }}</div>
                    <div class="stat-label">km total</div>
                </div>
            </div>
        </div>

        <!-- GPS Map Section -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-map-marked-alt me-2"></i>
                            Carte GPS des trajets
                        </h5>
                        <div class="btn-group btn-group-sm" role="group">
                            <button type="button" class="btn btn-outline-primary"
                                    :class="{ active: mapView === 'all' }"
                                    @click="changeMapView('all')">
                                <i class="fas fa-globe me-1"></i>Tous
                            </button>
                            <button type="button" class="btn btn-outline-success"
                                    :class="{ active: mapView === 'active' }"
                                    @click="changeMapView('active')">
                                <i class="fas fa-play me-1"></i>En cours
                            </button>
                            <button type="button" class="btn btn-outline-info"
                                    :class="{ active: mapView === 'planned' }"
                                    @click="changeMapView('planned')">
                                <i class="fas fa-calendar me-1"></i>Planifiés
                            </button>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div id="trajetsMap" style="height: 500px; width: 100%;"></div>
                    </div>
                    <div class="card-footer">
                        <div class="row text-center">
                            <div class="col-md-3">
                                <small class="text-muted">
                                    <i class="fas fa-circle text-primary me-1"></i>
                                    Départ
                                </small>
                            </div>
                            <div class="col-md-3">
                                <small class="text-muted">
                                    <i class="fas fa-circle text-danger me-1"></i>
                                    Arrivée
                                </small>
                            </div>
                            <div class="col-md-3">
                                <small class="text-muted">
                                    <i class="fas fa-route text-success me-1"></i>
                                    Itinéraire
                                </small>
                            </div>
                            <div class="col-md-3">
                                <small class="text-muted">
                                    <i class="fas fa-truck text-warning me-1"></i>
                                    Véhicule en cours
                                </small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Trajets Table -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">
                    <i class="fas fa-list me-2"></i>
                    Liste des trajets ({{ trajets.length }})
                </h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th>Commande</th>
                                <th>Chauffeur</th>
                                <th>Véhicule</th>
                                <th>Départ</th>
                                <th>Arrivée prévue</th>
                                <th>Distance</th>
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
                            <tr v-else-if="trajets.length === 0">
                                <td colspan="8" class="text-center py-4 text-muted">
                                    <i class="fas fa-route fa-3x mb-3 d-block"></i>
                                    Aucun trajet trouvé
                                </td>
                            </tr>
                            <tr v-else v-for="trajet in trajets" :key="trajet.id">
                                <td>
                                    <strong>{{ trajet.numero_commande }}</strong>
                                    <br>
                                    <small class="text-muted">{{ trajet.client_nom }}</small>
                                </td>
                                <td>
                                    <strong>{{ trajet.chauffeur_nom }} {{ trajet.chauffeur_prenom }}</strong>
                                </td>
                                <td>
                                    <strong>{{ trajet.vehicule_immat }}</strong>
                                    <br>
                                    <small class="text-muted">{{ trajet.vehicule_marque }} {{ trajet.vehicule_modele }}</small>
                                </td>
                                <td>
                                    {{ formatDate(trajet.date_depart, true) }}
                                </td>
                                <td>
                                    {{ formatDate(trajet.date_arrivee_prevue, true) }}
                                    <br>
                                    <small v-if="trajet.date_arrivee_reelle" class="text-success">
                                        Réel: {{ formatDate(trajet.date_arrivee_reelle, true) }}
                                    </small>
                                </td>
                                <td>
                                    {{ formatNumber(trajet.distance_km) }} km
                                </td>
                                <td>
                                    <span :class="'status-badge status-' + trajet.statut">
                                        {{ getStatusLabel(trajet.statut) }}
                                    </span>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button @click="viewTrajet(trajet)"
                                                class="btn btn-sm btn-outline-info"
                                                title="Voir détails">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        <button @click="showItinerary(trajet)"
                                                class="btn btn-sm btn-outline-success"
                                                title="Voir itinéraire">
                                            <i class="fas fa-route"></i>
                                        </button>
                                        <button v-if="hasPermission('trajets', 'write')"
                                                @click="editTrajet(trajet)"
                                                class="btn btn-sm btn-outline-primary"
                                                title="Modifier">
                                            <i class="fas fa-edit"></i>
                                        </button>
                                        <div v-if="hasPermission('trajets', 'write')" class="dropdown d-inline">
                                            <button class="btn btn-sm btn-outline-secondary dropdown-toggle"
                                                    type="button"
                                                    data-bs-toggle="dropdown">
                                                <i class="fas fa-cog"></i>
                                            </button>
                                            <ul class="dropdown-menu">
                                                <li><a class="dropdown-item" href="#" @click="updateStatus(trajet, 'en_cours')">
                                                    <i class="fas fa-play me-2"></i>Démarrer
                                                </a></li>
                                                <li><a class="dropdown-item" href="#" @click="updateStatus(trajet, 'termine')">
                                                    <i class="fas fa-check-circle me-2"></i>Terminer
                                                </a></li>
                                                <li><hr class="dropdown-divider"></li>
                                                <li><a class="dropdown-item text-danger" href="#" @click="updateStatus(trajet, 'annule')">
                                                    <i class="fas fa-times me-2"></i>Annuler
                                                </a></li>
                                            </ul>
                                        </div>
                                        <button v-if="hasPermission('trajets', 'delete')"
                                                @click="deleteTrajet(trajet)" 
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
        
        <!-- Trajet Modal -->
        <div class="modal fade" ref="trajetModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-route me-2"></i>
                            {{ modalMode === 'create' ? 'Nouveau trajet' : modalMode === 'edit' ? 'Modifier trajet' : 'Détails trajet' }}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form @submit.prevent="saveTrajet" v-if="modalMode !== 'view'">
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Commande *</label>
                                        <select class="form-select" v-model="currentTrajet.commande_id" required>
                                            <option value="">Sélectionner une commande</option>
                                            <option v-for="commande in commandes" :key="commande.id" :value="commande.id">
                                                {{ commande.numero_commande }} - {{ commande.client_nom }}
                                            </option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Véhicule *</label>
                                        <select class="form-select" v-model="currentTrajet.vehicule_id" required>
                                            <option value="">Sélectionner un véhicule</option>
                                            <option v-for="vehicule in vehiculesDisponibles" :key="vehicule.id" :value="vehicule.id">
                                                {{ vehicule.immatriculation }} - {{ vehicule.marque }} {{ vehicule.modele }}
                                            </option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Chauffeur *</label>
                                        <select class="form-select" v-model="currentTrajet.chauffeur_id" required>
                                            <option value="">Sélectionner un chauffeur</option>
                                            <option v-for="chauffeur in chauffeurs" :key="chauffeur.id" :value="chauffeur.id">
                                                {{ chauffeur.nom }} {{ chauffeur.prenom }}
                                            </option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Date/Heure de départ *</label>
                                        <input type="datetime-local" class="form-control" v-model="currentTrajet.date_depart" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Date/Heure d'arrivée prévue</label>
                                        <input type="datetime-local" class="form-control" v-model="currentTrajet.date_arrivee_prevue">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Distance (km)</label>
                                        <input type="number" step="0.1" class="form-control" v-model="currentTrajet.distance_km">
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Statut</label>
                                        <select class="form-select" v-model="currentTrajet.statut">
                                            <option value="planifie">Planifié</option>
                                            <option value="en_cours">En cours</option>
                                            <option value="termine">Terminé</option>
                                            <option value="annule">Annulé</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Notes</label>
                                <textarea class="form-control" rows="3" v-model="currentTrajet.notes"></textarea>
                            </div>
                        </form>
                        
                        <!-- View Mode -->
                        <div v-else>
                            <div class="row">
                                <div class="col-md-6">
                                    <h6>Informations générales</h6>
                                    <p><strong>Commande:</strong> {{ currentTrajet.numero_commande }}</p>
                                    <p><strong>Client:</strong> {{ currentTrajet.client_nom }} {{ currentTrajet.client_prenom }}</p>
                                    <p><strong>Chauffeur:</strong> {{ currentTrajet.chauffeur_nom }} {{ currentTrajet.chauffeur_prenom }}</p>
                                    <p><strong>Véhicule:</strong> {{ currentTrajet.vehicule_immat }} - {{ currentTrajet.vehicule_marque }} {{ currentTrajet.vehicule_modele }}</p>
                                    <p><strong>Statut:</strong> 
                                        <span :class="'status-badge status-' + currentTrajet.statut">
                                            {{ getStatusLabel(currentTrajet.statut) }}
                                        </span>
                                    </p>
                                </div>
                                <div class="col-md-6">
                                    <h6>Planning</h6>
                                    <p><strong>Départ:</strong> {{ formatDate(currentTrajet.date_depart, true) }}</p>
                                    <p><strong>Arrivée prévue:</strong> {{ formatDate(currentTrajet.date_arrivee_prevue, true) }}</p>
                                    <p v-if="currentTrajet.date_arrivee_reelle"><strong>Arrivée réelle:</strong> {{ formatDate(currentTrajet.date_arrivee_reelle, true) }}</p>
                                    <p><strong>Distance:</strong> {{ formatNumber(currentTrajet.distance_km) }} km</p>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <h6>Adresses</h6>
                                    <p><strong>Départ:</strong><br>{{ currentTrajet.adresse_depart }}</p>
                                    <p><strong>Arrivée:</strong><br>{{ currentTrajet.adresse_arrivee }}</p>
                                </div>
                                <div class="col-md-6">
                                    <h6>Description commande</h6>
                                    <p>{{ currentTrajet.commande_description || '-' }}</p>
                                </div>
                            </div>
                            
                            <div v-if="currentTrajet.notes" class="mt-3">
                                <h6>Notes</h6>
                                <p>{{ currentTrajet.notes }}</p>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            {{ modalMode === 'view' ? 'Fermer' : 'Annuler' }}
                        </button>
                        <button v-if="modalMode !== 'view'" 
                                type="submit" 
                                @click="saveTrajet"
                                class="btn btn-primary"
                                :disabled="saving">
                            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
                            {{ modalMode === 'create' ? 'Créer' : 'Sauvegarder' }}
                        </button>
                        <button v-if="modalMode === 'view' && currentTrajet.statut === 'planifie' && hasPermission('trajets', 'write')"
                                @click="updateStatus(currentTrajet, 'en_cours')"
                                class="btn btn-success btn-icon-right">
                            <i class="fas fa-play"></i>
                            Démarrer
                        </button>
                        <button v-if="modalMode === 'view' && currentTrajet.statut === 'en_cours' && hasPermission('trajets', 'write')"
                                @click="updateStatus(currentTrajet, 'termine')"
                                class="btn btn-success btn-icon-right">
                            <i class="fas fa-check-circle"></i>
                            Terminer
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
            trajets: [],
            commandes: [],
            vehicules: [],
            vehiculesDisponibles: [],
            chauffeurs: [],
            stats: null,
            loading: false,
            saving: false,
            filterStatut: '',
            filterChauffeur: '',
            filterVehicule: '',
            modalMode: 'view',
            currentTrajet: {},
            modal: null,
            map: null,
            mapView: 'all',
            mapMarkers: [],
            mapRoutes: []
        }
    },
    
    mounted() {
        this.loadTrajets();
        this.loadRelatedData();
        this.loadStats();
        this.modal = new bootstrap.Modal(this.$refs.trajetModal);

        // Make component globally accessible for map popups
        window.trajetsComponent = this;

        // Initialize map after DOM is ready
        this.$nextTick(() => {
            this.initializeMap();
        });
    },
    
    methods: {
        async loadTrajets() {
            this.loading = true;
            try {
                const params = {};
                if (this.filterStatut) params.statut = this.filterStatut;
                if (this.filterChauffeur) params.chauffeur_id = this.filterChauffeur;
                if (this.filterVehicule) params.vehicule_id = this.filterVehicule;

                const response = await axios.get('/trajets', { params });
                this.trajets = response.data.data;

                // Update map markers when data changes
                if (this.map) {
                    this.updateMapMarkers();
                }
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement des trajets');
            }
            this.loading = false;
        },
        
        async loadRelatedData() {
            try {
                // Load commandes
                const commandesResponse = await axios.get('/commandes');
                this.commandes = commandesResponse.data.data.filter(c => c.statut !== 'livree' && c.statut !== 'annulee');
                
                // Load véhicules
                const vehiculesResponse = await axios.get('/vehicules');
                this.vehicules = vehiculesResponse.data.data;
                this.vehiculesDisponibles = this.vehicules.filter(v => v.disponible);
                
                // Load chauffeurs
                const chauffeursResponse = await axios.get('/users');
                this.chauffeurs = chauffeursResponse.data.data.filter(u => u.role === 'chauffeur');
                
            } catch (error) {
                console.error('Erreur lors du chargement des données:', error);
            }
        },
        
        async loadStats() {
            try {
                const response = await axios.get('/trajets/stats');
                this.stats = response.data.data;
            } catch (error) {
                console.error('Erreur lors du chargement des statistiques:', error);
            }
        },
        
        async filterTrajets() {
            await this.loadTrajets();
        },
        
        showCreateModal() {
            this.modalMode = 'create';
            this.currentTrajet = {
                commande_id: '',
                vehicule_id: '',
                chauffeur_id: '',
                date_depart: '',
                date_arrivee_prevue: '',
                distance_km: 0,
                statut: 'planifie',
                notes: ''
            };
            this.modal.show();
        },
        
        viewTrajet(trajet) {
            this.modalMode = 'view';
            this.currentTrajet = { ...trajet };
            this.modal.show();
        },
        
        editTrajet(trajet) {
            this.modalMode = 'edit';
            this.currentTrajet = { ...trajet };
            // Convert dates for datetime-local input
            if (this.currentTrajet.date_depart) {
                this.currentTrajet.date_depart = this.formatDateTimeLocal(this.currentTrajet.date_depart);
            }
            if (this.currentTrajet.date_arrivee_prevue) {
                this.currentTrajet.date_arrivee_prevue = this.formatDateTimeLocal(this.currentTrajet.date_arrivee_prevue);
            }
            this.modal.show();
        },
        
        async saveTrajet() {
            this.saving = true;
            
            try {
                if (this.modalMode === 'create') {
                    await axios.post('/trajets', this.currentTrajet);
                    this.showNotification('Trajet créé avec succès', 'success');
                } else {
                    await axios.put(`/trajets/${this.currentTrajet.id}`, this.currentTrajet);
                    this.showNotification('Trajet modifié avec succès', 'success');
                }
                
                this.modal.hide();
                await this.loadTrajets();
                await this.loadStats();
                await this.loadRelatedData();
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la sauvegarde');
            }
            
            this.saving = false;
        },
        
        async updateStatus(trajet, newStatus) {
            try {
                await axios.put(`/trajets/${trajet.id}/status`, { statut: newStatus });
                this.showNotification('Statut mis à jour avec succès', 'success');
                await this.loadTrajets();
                await this.loadStats();
                await this.loadRelatedData();
                
                // Close modal if open
                if (this.modal._isShown) {
                    this.modal.hide();
                }
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la mise à jour du statut');
            }
        },
        
        async deleteTrajet(trajet) {
            if (!confirm(`Êtes-vous sûr de vouloir supprimer ce trajet ?`)) {
                return;
            }
            
            try {
                await axios.delete(`/trajets/${trajet.id}`);
                this.showNotification('Trajet supprimé avec succès', 'success');
                await this.loadTrajets();
                await this.loadStats();
                await this.loadRelatedData();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        getStatusLabel(status) {
            const labels = {
                'planifie': 'Planifié',
                'en_cours': 'En cours',
                'termine': 'Terminé',
                'annule': 'Annulé'
            };
            return labels[status] || status;
        },
        
        formatDateTimeLocal(dateString) {
            if (!dateString) return '';
            const date = new Date(dateString);
            return date.toISOString().slice(0, 16);
        },

        // GPS Map Methods
        initializeMap() {
            // Initialize Leaflet map centered on Côte d'Ivoire
            this.map = L.map('trajetsMap').setView([7.539989, -5.54708], 7);

            // Add OpenStreetMap tiles
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(this.map);

            // Load trajets on map
            this.updateMapMarkers();
        },

        async updateMapMarkers() {
            // Clear existing markers and routes
            this.clearMapMarkers();

            // Filter trajets based on current view
            let filteredTrajets = this.trajets;
            if (this.mapView === 'active') {
                filteredTrajets = this.trajets.filter(t => t.statut === 'en_cours');
            } else if (this.mapView === 'planned') {
                filteredTrajets = this.trajets.filter(t => t.statut === 'planifie');
            }

            // Add markers for each trajet
            for (const trajet of filteredTrajets) {
                await this.addTrajetToMap(trajet);
            }
        },

        async addTrajetToMap(trajet) {
            try {
                // Get coordinates for departure and arrival addresses
                const departCoords = await this.geocodeAddress(trajet.adresse_depart);
                const arriveeCoords = await this.geocodeAddress(trajet.adresse_arrivee);

                if (departCoords && arriveeCoords) {
                    // Create departure marker (blue)
                    const departMarker = L.marker([departCoords.lat, departCoords.lon], {
                        icon: this.createCustomIcon('blue', 'play')
                    }).addTo(this.map);

                    departMarker.bindPopup(`
                        <div class="map-popup">
                            <h6><i class="fas fa-play text-primary"></i> Départ</h6>
                            <p><strong>Commande:</strong> ${trajet.numero_commande}</p>
                            <p><strong>Client:</strong> ${trajet.client_nom}</p>
                            <p><strong>Chauffeur:</strong> ${trajet.chauffeur_nom} ${trajet.chauffeur_prenom}</p>
                            <p><strong>Véhicule:</strong> ${trajet.vehicule_immat}</p>
                            <p><strong>Adresse:</strong> ${trajet.adresse_depart}</p>
                            <button class="btn btn-sm btn-primary mt-2" onclick="window.trajetsComponent.showItinerary({id: ${trajet.id}})">
                                <i class="fas fa-route"></i> Voir itinéraire
                            </button>
                        </div>
                    `);

                    // Create arrival marker (red)
                    const arriveeMarker = L.marker([arriveeCoords.lat, arriveeCoords.lon], {
                        icon: this.createCustomIcon('red', 'flag-checkered')
                    }).addTo(this.map);

                    arriveeMarker.bindPopup(`
                        <div class="map-popup">
                            <h6><i class="fas fa-flag-checkered text-danger"></i> Arrivée</h6>
                            <p><strong>Commande:</strong> ${trajet.numero_commande}</p>
                            <p><strong>Client:</strong> ${trajet.client_nom}</p>
                            <p><strong>Adresse:</strong> ${trajet.adresse_arrivee}</p>
                            <p><strong>Statut:</strong> <span class="status-badge status-${trajet.statut}">${this.getStatusLabel(trajet.statut)}</span></p>
                        </div>
                    `);

                    this.mapMarkers.push(departMarker, arriveeMarker);

                    // Add vehicle marker if trajet is active
                    if (trajet.statut === 'en_cours') {
                        // For demo, place vehicle marker between departure and arrival
                        const vehicleLat = (departCoords.lat + arriveeCoords.lat) / 2;
                        const vehicleLon = (departCoords.lon + arriveeCoords.lon) / 2;

                        const vehicleMarker = L.marker([vehicleLat, vehicleLon], {
                            icon: this.createCustomIcon('orange', 'truck')
                        }).addTo(this.map);

                        vehicleMarker.bindPopup(`
                            <div class="map-popup">
                                <h6><i class="fas fa-truck text-warning"></i> Véhicule en cours</h6>
                                <p><strong>Immatriculation:</strong> ${trajet.vehicule_immat}</p>
                                <p><strong>Chauffeur:</strong> ${trajet.chauffeur_nom} ${trajet.chauffeur_prenom}</p>
                                <p><strong>Téléphone:</strong> ${trajet.chauffeur_telephone || 'N/A'}</p>
                                <p><strong>Commande:</strong> ${trajet.numero_commande}</p>
                            </div>
                        `);

                        this.mapMarkers.push(vehicleMarker);
                    }
                }
            } catch (error) {
                console.error('Erreur lors de l\'ajout du trajet sur la carte:', error);
            }
        },

        async showItinerary(trajetOrId) {
            try {
                // Clear existing routes
                this.clearMapRoutes();

                // Get trajet object
                let trajet = trajetOrId;
                if (typeof trajetOrId === 'object' && trajetOrId.id) {
                    trajet = this.trajets.find(t => t.id === trajetOrId.id);
                }

                if (!trajet) {
                    this.showNotification('Trajet non trouvé', 'error');
                    return;
                }

                // Get coordinates
                const departCoords = await this.geocodeAddress(trajet.adresse_depart);
                const arriveeCoords = await this.geocodeAddress(trajet.adresse_arrivee);

                if (departCoords && arriveeCoords) {
                    // Get route from routing service
                    const route = await this.getRoute(departCoords, arriveeCoords);

                    if (route) {
                        // Add route to map
                        const routeLine = L.polyline(route.coordinates, {
                            color: '#28a745',
                            weight: 4,
                            opacity: 0.8
                        }).addTo(this.map);

                        this.mapRoutes.push(routeLine);

                        // Fit map to show the route
                        this.map.fitBounds(routeLine.getBounds(), { padding: [20, 20] });

                        // Show route info
                        this.showNotification(
                            `Itinéraire affiché: ${route.distance} km, ${route.duration} min`,
                            'success'
                        );
                    }
                }
            } catch (error) {
                console.error('Erreur lors de l\'affichage de l\'itinéraire:', error);
                this.showNotification('Erreur lors de l\'affichage de l\'itinéraire', 'error');
            }
        },

        async geocodeAddress(address) {
            try {
                // Use Nominatim (OpenStreetMap) geocoding service
                const response = await fetch(
                    `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address + ', Côte d\'Ivoire')}&limit=1`
                );
                const data = await response.json();

                if (data && data.length > 0) {
                    return {
                        lat: parseFloat(data[0].lat),
                        lon: parseFloat(data[0].lon)
                    };
                }
                return null;
            } catch (error) {
                console.error('Erreur de géocodage:', error);
                return null;
            }
        },

        async getRoute(startCoords, endCoords) {
            try {
                // Use OpenRouteService for routing (free alternative)
                const response = await fetch(
                    `https://router.project-osrm.org/route/v1/driving/${startCoords.lon},${startCoords.lat};${endCoords.lon},${endCoords.lat}?overview=full&geometries=geojson`
                );
                const data = await response.json();

                if (data.routes && data.routes.length > 0) {
                    const route = data.routes[0];
                    const coordinates = route.geometry.coordinates.map(coord => [coord[1], coord[0]]);

                    return {
                        coordinates: coordinates,
                        distance: Math.round(route.distance / 1000), // Convert to km
                        duration: Math.round(route.duration / 60) // Convert to minutes
                    };
                }
                return null;
            } catch (error) {
                console.error('Erreur de calcul d\'itinéraire:', error);
                return null;
            }
        },

        createCustomIcon(color, iconName) {
            const iconColors = {
                blue: '#007bff',
                red: '#dc3545',
                green: '#28a745',
                orange: '#fd7e14',
                purple: '#6f42c1'
            };

            return L.divIcon({
                className: 'custom-map-marker',
                html: `
                    <div style="
                        background-color: ${iconColors[color] || '#007bff'};
                        width: 30px;
                        height: 30px;
                        border-radius: 50%;
                        border: 3px solid white;
                        box-shadow: 0 2px 5px rgba(0,0,0,0.3);
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        color: white;
                        font-size: 12px;
                    ">
                        <i class="fas fa-${iconName}"></i>
                    </div>
                `,
                iconSize: [30, 30],
                iconAnchor: [15, 15]
            });
        },

        changeMapView(view) {
            this.mapView = view;
            this.updateMapMarkers();
        },

        clearMapMarkers() {
            this.mapMarkers.forEach(marker => {
                this.map.removeLayer(marker);
            });
            this.mapMarkers = [];
        },

        clearMapRoutes() {
            this.mapRoutes.forEach(route => {
                this.map.removeLayer(route);
            });
            this.mapRoutes = [];
        },
    }
};
