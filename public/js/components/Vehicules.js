// Vehicules Component
const VehiculesComponent = {
    template: `
    <div class="vehicules fade-in">
        <!-- Page Header -->
        <div class="page-header vehicles-header">
            <div class="header-logo-container">
                <img src="/images/logo.png" alt="LogisWayZ Logo" class="header-logo">
            </div>
            <h1>
                <i class="fas fa-truck me-2"></i>
                Gestion des véhicules
            </h1>
            <div class="page-header-actions">
                <button v-if="hasPermission('vehicules', 'write')" 
                        @click="showCreateModal" 
                        class="btn btn-primary btn-icon-right">
                    <i class="fas fa-plus"></i>
                    Nouveau véhicule
                </button>
            </div>
        </div>
        
        <!-- Filters -->
        <div class="card mb-4">
            <div class="card-body">
                <div class="row">
                    <div class="col-md-4">
                        <div class="input-group">
                            <span class="input-group-text">
                                <i class="fas fa-search"></i>
                            </span>
                            <input type="text" 
                                   class="form-control" 
                                   placeholder="Rechercher un véhicule..."
                                   v-model="searchQuery"
                                   @input="searchVehicules">
                        </div>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterDisponibilite" @change="filterVehicules">
                            <option value="">Toutes disponibilités</option>
                            <option value="1">Disponibles</option>
                            <option value="0">Non disponibles</option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterType" @change="filterVehicules">
                            <option value="">Tous les types</option>
                            <option value="camion">Camion</option>
                            <option value="camionnette">Camionnette</option>
                            <option value="fourgon">Fourgon</option>
                            <option value="semi_remorque">Semi-remorque</option>
                        </select>
                    </div>
                    <div class="col-md-2">
                        <button @click="loadVehicules" class="btn btn-outline-secondary w-100">
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
                <div class="stat-card vehicules">
                    <div class="stat-icon">
                        <i class="fas fa-truck"></i>
                    </div>
                    <div class="stat-number">{{ stats.total || 0 }}</div>
                    <div class="stat-label">Total véhicules</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card clients">
                    <div class="stat-icon">
                        <i class="fas fa-check-circle"></i>
                    </div>
                    <div class="stat-number">{{ stats.disponibles || 0 }}</div>
                    <div class="stat-label">Disponibles</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card commandes">
                    <div class="stat-icon">
                        <i class="fas fa-route"></i>
                    </div>
                    <div class="stat-number">{{ stats.en_mission || 0 }}</div>
                    <div class="stat-label">En mission</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card factures">
                    <div class="stat-icon">
                        <i class="fas fa-wrench"></i>
                    </div>
                    <div class="stat-number">{{ stats.maintenance || 0 }}</div>
                    <div class="stat-label">Maintenance</div>
                </div>
            </div>
        </div>
        
        <!-- Vehicules Table -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">
                    <i class="fas fa-list me-2"></i>
                    Liste des véhicules ({{ vehicules.length }})
                </h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th>Immatriculation</th>
                                <th>Véhicule</th>
                                <th>Type</th>
                                <th>Capacité</th>
                                <th>Statut</th>
                                <th>Disponibilité</th>
                                <th width="150">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-if="loading">
                                <td colspan="7" class="text-center py-4">
                                    <div class="spinner-border text-primary" role="status">
                                        <span class="visually-hidden">Chargement...</span>
                                    </div>
                                </td>
                            </tr>
                            <tr v-else-if="vehicules.length === 0">
                                <td colspan="7" class="text-center py-4 text-muted">
                                    <i class="fas fa-truck fa-3x mb-3 d-block"></i>
                                    Aucun véhicule trouvé
                                </td>
                            </tr>
                            <tr v-else v-for="vehicule in vehicules" :key="vehicule.id">
                                <td>
                                    <strong>{{ vehicule.immatriculation }}</strong>
                                    <br>
                                    <small class="text-muted">{{ vehicule.annee || '-' }}</small>
                                </td>
                                <td>
                                    <strong>{{ vehicule.marque }} {{ vehicule.modele }}</strong>
                                    <br>
                                    <small class="text-muted">{{ formatNumber(vehicule.consommation) }} L/100km</small>
                                </td>
                                <td>
                                    <span class="badge bg-secondary">{{ getTypeLabel(vehicule.type) }}</span>
                                </td>
                                <td>
                                    <div class="small">
                                        <i class="fas fa-weight-hanging me-1"></i>
                                        {{ formatNumber(vehicule.capacite_poids) }} kg
                                    </div>
                                    <div class="small">
                                        <i class="fas fa-cube me-1"></i>
                                        {{ formatNumber(vehicule.capacite_volume) }} m³
                                    </div>
                                </td>
                                <td>
                                    <span :class="'status-badge status-' + vehicule.statut">
                                        {{ getStatutLabel(vehicule.statut) }}
                                    </span>
                                </td>
                                <td>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" 
                                               type="checkbox" 
                                               :checked="vehicule.disponible"
                                               @change="toggleDisponibilite(vehicule)"
                                               :disabled="!hasPermission('vehicules', 'write')">
                                        <label class="form-check-label">
                                            {{ vehicule.disponible ? 'Disponible' : 'Indisponible' }}
                                        </label>
                                    </div>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button @click="viewVehicule(vehicule)" 
                                                class="btn btn-sm btn-outline-info" 
                                                title="Voir détails">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        <button v-if="hasPermission('vehicules', 'write')"
                                                @click="editVehicule(vehicule)" 
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
                                                <li><a class="dropdown-item" href="#" @click="viewMaintenance(vehicule)">
                                                    <i class="fas fa-wrench me-2"></i>Maintenance
                                                </a></li>
                                                <li><a class="dropdown-item" href="#" @click="addMaintenance(vehicule)">
                                                    <i class="fas fa-plus me-2"></i>Ajouter maintenance
                                                </a></li>
                                            </ul>
                                        </div>
                                        <button v-if="hasPermission('vehicules', 'delete')"
                                                @click="deleteVehicule(vehicule)" 
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
        
        <!-- Vehicule Modal -->
        <div class="modal fade" ref="vehiculeModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-truck me-2"></i>
                            {{ modalMode === 'create' ? 'Nouveau véhicule' : modalMode === 'edit' ? 'Modifier véhicule' : 'Détails véhicule' }}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form @submit.prevent="saveVehicule" v-if="modalMode !== 'view'">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Immatriculation *</label>
                                        <input type="text" class="form-control" v-model="currentVehicule.immatriculation" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Type *</label>
                                        <select class="form-select" v-model="currentVehicule.type" required>
                                            <option value="">Sélectionner un type</option>
                                            <option value="camion">Camion</option>
                                            <option value="camionnette">Camionnette</option>
                                            <option value="fourgon">Fourgon</option>
                                            <option value="semi_remorque">Semi-remorque</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Marque *</label>
                                        <input type="text" class="form-control" v-model="currentVehicule.marque" required>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Modèle *</label>
                                        <input type="text" class="form-control" v-model="currentVehicule.modele" required>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Année</label>
                                        <input type="number" class="form-control" v-model="currentVehicule.annee" min="1990" :max="new Date().getFullYear()">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Capacité poids (kg)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentVehicule.capacite_poids">
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Capacité volume (m³)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentVehicule.capacite_volume">
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Consommation (L/100km)</label>
                                        <input type="number" step="0.1" class="form-control" v-model="currentVehicule.consommation">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Statut</label>
                                        <select class="form-select" v-model="currentVehicule.statut">
                                            <option value="actif">Actif</option>
                                            <option value="maintenance">Maintenance</option>
                                            <option value="hors_service">Hors service</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <div class="form-check form-switch mt-4">
                                            <input class="form-check-input" type="checkbox" v-model="currentVehicule.disponible">
                                            <label class="form-check-label">Disponible</label>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Notes</label>
                                <textarea class="form-control" rows="3" v-model="currentVehicule.notes"></textarea>
                            </div>
                        </form>
                        
                        <!-- View Mode -->
                        <div v-else>
                            <div class="row">
                                <div class="col-md-6">
                                    <h6>Informations générales</h6>
                                    <p><strong>Immatriculation:</strong> {{ currentVehicule.immatriculation }}</p>
                                    <p><strong>Véhicule:</strong> {{ currentVehicule.marque }} {{ currentVehicule.modele }}</p>
                                    <p><strong>Type:</strong> {{ getTypeLabel(currentVehicule.type) }}</p>
                                    <p><strong>Année:</strong> {{ currentVehicule.annee || '-' }}</p>
                                    <p><strong>Statut:</strong> 
                                        <span :class="'status-badge status-' + currentVehicule.statut">
                                            {{ getStatutLabel(currentVehicule.statut) }}
                                        </span>
                                    </p>
                                    <p><strong>Disponibilité:</strong> 
                                        <span :class="currentVehicule.disponible ? 'text-success' : 'text-danger'">
                                            {{ currentVehicule.disponible ? 'Disponible' : 'Indisponible' }}
                                        </span>
                                    </p>
                                </div>
                                <div class="col-md-6">
                                    <h6>Capacités</h6>
                                    <p><strong>Poids:</strong> {{ formatNumber(currentVehicule.capacite_poids) }} kg</p>
                                    <p><strong>Volume:</strong> {{ formatNumber(currentVehicule.capacite_volume) }} m³</p>
                                    <p><strong>Consommation:</strong> {{ formatNumber(currentVehicule.consommation) }} L/100km</p>
                                    
                                    <h6 class="mt-3">Statistiques</h6>
                                    <p><strong>Trajets total:</strong> {{ currentVehicule.nb_trajets_total || 0 }}</p>
                                    <p><strong>Trajets en cours:</strong> {{ currentVehicule.nb_trajets_en_cours || 0 }}</p>
                                </div>
                            </div>
                            
                            <div v-if="currentVehicule.notes" class="mt-3">
                                <h6>Notes</h6>
                                <p>{{ currentVehicule.notes }}</p>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            {{ modalMode === 'view' ? 'Fermer' : 'Annuler' }}
                        </button>
                        <button v-if="modalMode !== 'view'" 
                                type="submit" 
                                @click="saveVehicule"
                                class="btn btn-primary"
                                :disabled="saving">
                            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
                            {{ modalMode === 'create' ? 'Créer' : 'Sauvegarder' }}
                        </button>
                        <button v-if="modalMode === 'view'"
                                @click="viewMaintenance(currentVehicule)"
                                class="btn btn-warning btn-icon-right">
                            <i class="fas fa-wrench"></i>
                            Maintenance
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
            vehicules: [],
            stats: null,
            loading: false,
            saving: false,
            searchQuery: '',
            filterDisponibilite: '',
            filterType: '',
            modalMode: 'view',
            currentVehicule: {},
            modal: null
        }
    },
    
    mounted() {
        this.loadVehicules();
        this.loadStats();
        this.modal = new bootstrap.Modal(this.$refs.vehiculeModal);
    },
    
    methods: {
        async loadVehicules() {
            this.loading = true;
            try {
                const params = {};
                if (this.filterDisponibilite !== '') params.disponible = this.filterDisponibilite;
                
                const response = await axios.get('/vehicules', { params });
                this.vehicules = response.data.data;
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement des véhicules');
            }
            this.loading = false;
        },
        
        async loadStats() {
            try {
                const response = await axios.get('/vehicules/stats');
                this.stats = response.data.data;
            } catch (error) {
                console.error('Erreur lors du chargement des statistiques:', error);
            }
        },
        
        async searchVehicules() {
            // Implement search logic
            await this.loadVehicules();
        },
        
        async filterVehicules() {
            await this.loadVehicules();
        },
        
        showCreateModal() {
            this.modalMode = 'create';
            this.currentVehicule = {
                immatriculation: '',
                marque: '',
                modele: '',
                annee: new Date().getFullYear(),
                type: '',
                capacite_poids: 0,
                capacite_volume: 0,
                consommation: 0,
                statut: 'actif',
                disponible: true,
                notes: ''
            };
            this.modal.show();
        },
        
        viewVehicule(vehicule) {
            this.modalMode = 'view';
            this.currentVehicule = { ...vehicule };
            this.modal.show();
        },
        
        editVehicule(vehicule) {
            this.modalMode = 'edit';
            this.currentVehicule = { ...vehicule };
            this.modal.show();
        },
        
        async saveVehicule() {
            this.saving = true;
            
            try {
                if (this.modalMode === 'create') {
                    await axios.post('/vehicules', this.currentVehicule);
                    this.showNotification('Véhicule créé avec succès', 'success');
                } else {
                    await axios.put(`/vehicules/${this.currentVehicule.id}`, this.currentVehicule);
                    this.showNotification('Véhicule modifié avec succès', 'success');
                }
                
                this.modal.hide();
                await this.loadVehicules();
                await this.loadStats();
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la sauvegarde');
            }
            
            this.saving = false;
        },
        
        async toggleDisponibilite(vehicule) {
            try {
                await axios.put(`/vehicules/${vehicule.id}/disponibilite`, {
                    disponible: !vehicule.disponible
                });
                vehicule.disponible = !vehicule.disponible;
                this.showNotification('Disponibilité mise à jour', 'success');
                await this.loadStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la mise à jour');
            }
        },
        
        async deleteVehicule(vehicule) {
            if (!confirm(`Êtes-vous sûr de vouloir supprimer le véhicule "${vehicule.immatriculation}" ?`)) {
                return;
            }
            
            try {
                await axios.delete(`/vehicules/${vehicule.id}`);
                this.showNotification('Véhicule supprimé avec succès', 'success');
                await this.loadVehicules();
                await this.loadStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        viewMaintenance(vehicule) {
            // Navigate to maintenance view or show maintenance modal
            this.showNotification('Fonctionnalité de maintenance à implémenter', 'info');
        },
        
        addMaintenance(vehicule) {
            // Show add maintenance modal
            this.showNotification('Fonctionnalité d\'ajout de maintenance à implémenter', 'info');
        },
        
        getTypeLabel(type) {
            const labels = {
                'camion': 'Camion',
                'camionnette': 'Camionnette',
                'fourgon': 'Fourgon',
                'semi_remorque': 'Semi-remorque'
            };
            return labels[type] || type;
        },
        
        getStatutLabel(statut) {
            const labels = {
                'actif': 'Actif',
                'maintenance': 'Maintenance',
                'hors_service': 'Hors service'
            };
            return labels[statut] || statut;
        }
    }
};
