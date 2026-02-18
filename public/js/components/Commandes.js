// Commandes Component
const CommandesComponent = {
    template: `
    <div class="commandes fade-in">
        <!-- Page Header -->
        <div class="page-header commands-header">
            <h1>
                <i class="fas fa-clipboard-list me-2">
                Gestion des commandes
            </h1>
            <div class="page-header-actions">
                <button v-if="hasPermission('commandes', 'write')" 
                        @click="showCreateModal" 
                        class="btn btn-primary btn-icon-right">
                    <i class="fas fa-plus"></i>
                    Nouvelle commande
                </button>
            </div>
        </div>
        
        <!-- Filters and Search -->
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
                                   placeholder="Rechercher une commande..."
                                   v-model="searchQuery"
                                   @input="searchCommandes">
                        </div>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterStatus" @change="filterCommandes">
                            <option value="">Tous les statuts</option>
                            <option value="en_attente">En attente</option>
                            <option value="confirmee">Confirmée</option>
                            <option value="en_cours">En cours</option>
                            <option value="livree">Livrée</option>
                            <option value="annulee">Annulée</option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" v-model="filterClient" @change="filterCommandes">
                            <option value="">Tous les clients</option>
                            <option v-for="client in clients" :key="client.id" :value="client.id">
                                {{ client.nom }} {{ client.prenom }}
                            </option>
                        </select>
                    </div>
                    <div class="col-md-2">
                        <button @click="loadCommandes" class="btn btn-outline-secondary w-100">
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
                <div class="stat-card commandes">
                    <div class="stat-icon">
                        <i class="fas fa-clock"></i>
                    </div>
                    <div class="stat-number">{{ stats.en_attente || 0 }}</div>
                    <div class="stat-label">En attente</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card trajets">
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
                        <i class="fas fa-check"></i>
                    </div>
                    <div class="stat-number">{{ stats.livrees || 0 }}</div>
                    <div class="stat-label">Livrées</div>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card revenus">
                    <div class="stat-icon">
                        <i class="fas fa-franc-sign"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.ca_total || 0) }}</div>
                    <div class="stat-label">CA Total</div>
                </div>
            </div>
        </div>
        
        <!-- Commandes Table -->
        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">
                    <i class="fas fa-list me-2"></i>
                    Liste des commandes ({{ commandes.length }})
                </h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th>N° Commande</th>
                                <th>Client</th>
                                <th>Trajet</th>
                                <th>Date prévue</th>
                                <th>Prix</th>
                                <th>Statut</th>
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
                            <tr v-else-if="commandes.length === 0">
                                <td colspan="7" class="text-center py-4 text-muted">
                                    <i class="fas fa-clipboard-list fa-3x mb-3 d-block"></i>
                                    Aucune commande trouvée
                                </td>
                            </tr>
                            <tr v-else v-for="commande in commandes" :key="commande.id">
                                <td>
                                    <strong>{{ commande.numero_commande }}</strong>
                                    <br>
                                    <small class="text-muted">{{ formatDate(commande.date_creation) }}</small>
                                </td>
                                <td>
                                    <strong>{{ commande.client_nom_complet }}</strong>
                                    <br>
                                    <small class="text-muted">{{ commande.client_entreprise || '-' }}</small>
                                </td>
                                <td>
                                    <div class="small">
                                        <i class="fas fa-map-marker-alt text-success me-1"></i>
                                        {{ truncateText(commande.adresse_depart, 30) }}
                                    </div>
                                    <div class="small">
                                        <i class="fas fa-map-marker-alt text-danger me-1"></i>
                                        {{ truncateText(commande.adresse_arrivee, 30) }}
                                    </div>
                                </td>
                                <td>
                                    {{ formatDate(commande.date_prevue) }}
                                    <br>
                                    <small class="text-muted">{{ commande.heure_prevue || '-' }}</small>
                                </td>
                                <td>
                                    <strong>{{ formatCurrency(commande.prix) }}</strong>
                                    <br>
                                    <small class="text-muted">
                                        {{ commande.poids ? commande.poids + ' kg' : '' }}
                                        {{ commande.volume ? commande.volume + ' m³' : '' }}
                                    </small>
                                </td>
                                <td>
                                    <span :class="'status-badge status-' + commande.statut">
                                        {{ getStatusLabel(commande.statut) }}
                                    </span>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button @click="viewCommande(commande)" 
                                                class="btn btn-sm btn-outline-info" 
                                                title="Voir détails">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        <button v-if="hasPermission('commandes', 'write')"
                                                @click="editCommande(commande)" 
                                                class="btn btn-sm btn-outline-primary" 
                                                title="Modifier">
                                            <i class="fas fa-edit"></i>
                                        </button>
                                        <div v-if="hasPermission('commandes', 'write')" class="dropdown d-inline">
                                            <button class="btn btn-sm btn-outline-secondary dropdown-toggle"
                                                    type="button"
                                                    data-bs-toggle="dropdown">
                                                <i class="fas fa-cog"></i>
                                            </button>
                                            <ul class="dropdown-menu">
                                                <li><a class="dropdown-item" href="#" @click="updateStatus(commande, 'confirmee')">
                                                    <i class="fas fa-check me-2"></i>Confirmer
                                                </a></li>
                                                <li><a class="dropdown-item" href="#" @click="updateStatus(commande, 'en_cours')">
                                                    <i class="fas fa-play me-2"></i>En cours
                                                </a></li>
                                                <li><a class="dropdown-item" href="#" @click="updateStatus(commande, 'livree')">
                                                    <i class="fas fa-check-circle me-2"></i>Livrée
                                                </a></li>
                                                <li><hr class="dropdown-divider"></li>
                                                <li><a class="dropdown-item text-danger" href="#" @click="updateStatus(commande, 'annulee')">
                                                    <i class="fas fa-times me-2"></i>Annuler
                                                </a></li>
                                            </ul>
                                        </div>
                                        <button v-if="hasPermission('commandes', 'delete')"
                                                @click="deleteCommande(commande)" 
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
        
        <!-- Commande Modal -->
        <div class="modal fade" ref="commandeModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-clipboard-list me-2"></i>
                            {{ modalMode === 'create' ? 'Nouvelle commande' : modalMode === 'edit' ? 'Modifier commande' : 'Détails commande' }}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form @submit.prevent="saveCommande" v-if="modalMode !== 'view'">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Client *</label>
                                        <select class="form-select" v-model="currentCommande.client_id" required>
                                            <option value="">Sélectionner un client</option>
                                            <option v-for="client in clients" :key="client.id" :value="client.id">
                                                {{ client.nom }} {{ client.prenom }} - {{ client.entreprise }}
                                            </option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Date prévue *</label>
                                        <input type="date" class="form-control" v-model="currentCommande.date_prevue" required>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Adresse de départ *</label>
                                        <textarea class="form-control" rows="2" v-model="currentCommande.adresse_depart" required></textarea>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Adresse d'arrivée *</label>
                                        <textarea class="form-control" rows="2" v-model="currentCommande.adresse_arrivee" required></textarea>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="row">
                                <div class="col-md-3">
                                    <div class="mb-3">
                                        <label class="form-label">Heure prévue</label>
                                        <input type="time" class="form-control" v-model="currentCommande.heure_prevue">
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="mb-3">
                                        <label class="form-label">Poids (kg)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentCommande.poids">
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="mb-3">
                                        <label class="form-label">Volume (m³)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentCommande.volume">
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="mb-3">
                                        <label class="form-label">Prix (F CFA)</label>
                                        <input type="number" step="0.01" class="form-control" v-model="currentCommande.prix">
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Description</label>
                                <textarea class="form-control" rows="3" v-model="currentCommande.description"></textarea>
                            </div>
                            
                            <div class="mb-3">
                                <label class="form-label">Notes</label>
                                <textarea class="form-control" rows="2" v-model="currentCommande.notes"></textarea>
                            </div>
                        </form>
                        
                        <!-- View Mode -->
                        <div v-else class="row">
                            <div class="col-md-6">
                                <h6>Informations générales</h6>
                                <p><strong>N° Commande:</strong> {{ currentCommande.numero_commande }}</p>
                                <p><strong>Client:</strong> {{ currentCommande.client_nom_complet }}</p>
                                <p><strong>Entreprise:</strong> {{ currentCommande.client_entreprise || '-' }}</p>
                                <p><strong>Date création:</strong> {{ formatDate(currentCommande.date_creation, true) }}</p>
                                <p><strong>Date prévue:</strong> {{ formatDate(currentCommande.date_prevue) }} {{ currentCommande.heure_prevue || '' }}</p>
                                <p><strong>Statut:</strong> 
                                    <span :class="'status-badge status-' + currentCommande.statut">
                                        {{ getStatusLabel(currentCommande.statut) }}
                                    </span>
                                </p>
                            </div>
                            <div class="col-md-6">
                                <h6>Détails transport</h6>
                                <p><strong>Départ:</strong><br>{{ currentCommande.adresse_depart }}</p>
                                <p><strong>Arrivée:</strong><br>{{ currentCommande.adresse_arrivee }}</p>
                                <p><strong>Poids:</strong> {{ currentCommande.poids || '-' }} kg</p>
                                <p><strong>Volume:</strong> {{ currentCommande.volume || '-' }} m³</p>
                                <p><strong>Prix:</strong> {{ formatCurrency(currentCommande.prix) }}</p>
                            </div>
                            <div class="col-12" v-if="currentCommande.description">
                                <h6>Description</h6>
                                <p>{{ currentCommande.description }}</p>
                            </div>
                            <div class="col-12" v-if="currentCommande.notes">
                                <h6>Notes</h6>
                                <p>{{ currentCommande.notes }}</p>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            {{ modalMode === 'view' ? 'Fermer' : 'Annuler' }}
                        </button>
                        <button v-if="modalMode !== 'view'" 
                                type="submit" 
                                @click="saveCommande"
                                class="btn btn-primary"
                                :disabled="saving">
                            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
                            {{ modalMode === 'create' ? 'Créer' : 'Sauvegarder' }}
                        </button>
                        <button v-if="modalMode === 'view' && hasPermission('trajets', 'write')"
                                @click="planTrajet"
                                class="btn btn-success btn-icon-right">
                            <i class="fas fa-route"></i>
                            Planifier trajet
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
            commandes: [],
            clients: [],
            stats: null,
            loading: false,
            saving: false,
            searchQuery: '',
            filterStatus: '',
            filterClient: '',
            modalMode: 'view',
            currentCommande: {},
            modal: null
        }
    },
    
    mounted() {
        this.loadCommandes();
        this.loadClients();
        this.loadStats();
        this.modal = new bootstrap.Modal(this.$refs.commandeModal);
    },
    
    methods: {
        async loadCommandes() {
            this.loading = true;
            try {
                const params = {};
                if (this.filterStatus) params.status = this.filterStatus;
                if (this.filterClient) params.client_id = this.filterClient;
                
                const response = await axios.get('/commandes', { params });
                this.commandes = response.data.data;
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement des commandes');
            }
            this.loading = false;
        },
        
        async loadClients() {
            try {
                const response = await axios.get('/clients');
                this.clients = response.data.data;
            } catch (error) {
                console.error('Erreur lors du chargement des clients:', error);
            }
        },
        
        async loadStats() {
            try {
                const response = await axios.get('/commandes/stats');
                this.stats = response.data.data;
            } catch (error) {
                console.error('Erreur lors du chargement des statistiques:', error);
            }
        },
        
        async searchCommandes() {
            // Implement search logic here
            await this.loadCommandes();
        },
        
        async filterCommandes() {
            await this.loadCommandes();
        },
        
        showCreateModal() {
            this.modalMode = 'create';
            this.currentCommande = {
                client_id: '',
                date_prevue: '',
                heure_prevue: '',
                adresse_depart: '',
                adresse_arrivee: '',
                description: '',
                poids: 0,
                volume: 0,
                prix: 0,
                notes: ''
            };
            this.modal.show();
        },
        
        viewCommande(commande) {
            this.modalMode = 'view';
            this.currentCommande = { ...commande };
            this.modal.show();
        },
        
        editCommande(commande) {
            this.modalMode = 'edit';
            this.currentCommande = { ...commande };
            this.modal.show();
        },
        
        async saveCommande() {
            this.saving = true;
            
            try {
                if (this.modalMode === 'create') {
                    await axios.post('/commandes', this.currentCommande);
                    this.showNotification('Commande créée avec succès', 'success');
                } else {
                    await axios.put(`/commandes/${this.currentCommande.id}`, this.currentCommande);
                    this.showNotification('Commande modifiée avec succès', 'success');
                }
                
                this.modal.hide();
                await this.loadCommandes();
                await this.loadStats();
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la sauvegarde');
            }
            
            this.saving = false;
        },
        
        async updateStatus(commande, newStatus) {
            try {
                await axios.put(`/commandes/${commande.id}/status`, { statut: newStatus });
                this.showNotification('Statut mis à jour avec succès', 'success');
                await this.loadCommandes();
                await this.loadStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la mise à jour du statut');
            }
        },
        
        async deleteCommande(commande) {
            if (!confirm(`Êtes-vous sûr de vouloir supprimer la commande "${commande.numero_commande}" ?`)) {
                return;
            }
            
            try {
                await axios.delete(`/commandes/${commande.id}`);
                this.showNotification('Commande supprimée avec succès', 'success');
                await this.loadCommandes();
                await this.loadStats();
            } catch (error) {
                this.handleApiError(error, 'Erreur lors de la suppression');
            }
        },
        
        planTrajet() {
            this.$router.push(`/trajets?commande_id=${this.currentCommande.id}`);
            this.modal.hide();
        },
        
        getStatusLabel(status) {
            const labels = {
                'en_attente': 'En attente',
                'confirmee': 'Confirmée',
                'en_cours': 'En cours',
                'livree': 'Livrée',
                'annulee': 'Annulée'
            };
            return labels[status] || status;
        },
        
        truncateText(text, maxLength) {
            if (!text) return '-';
            return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
        }
    }
};
