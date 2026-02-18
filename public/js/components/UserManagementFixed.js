// UserManagement.js - Version corrigée
const UserManagementComponent = {
    template: `
    <div class="container-fluid">
        <!-- Page Header with Background Image -->
        <div class="page-header users-header mb-3" style="background-image: linear-gradient(rgba(0,0,0,0.5), rgba(0,0,0,0.5)), url('images/utilisateur.jpg'); background-size: cover; background-position: center; border-radius: 10px; padding: 2rem; color: white;">
            <div class="text-center">
                <h1 class="mb-2">
                    <i class="fas fa-users me-2"></i>
                    Gestion des Utilisateurs
                </h1>
                <p class="mb-0 opacity-75">Gérez les comptes utilisateurs et leurs permissions</p>
            </div>
        </div>

        <!-- Action Buttons -->
        <div class="d-flex justify-content-end mb-4">
            <button class="btn btn-info me-2" @click="loadStatistics">
                <i class="fas fa-chart-bar"></i> Statistiques
            </button>
            <button class="btn btn-primary" @click="openCreateModal">
                <i class="fas fa-plus"></i> Nouvel Utilisateur
            </button>
        </div>

        <div class="row mb-3">
            <div class="col-md-6">
                <div class="input-group">
                    <span class="input-group-text"><i class="fas fa-search"></i></span>
                    <input 
                        type="text" 
                        class="form-control" 
                        placeholder="Rechercher un utilisateur..."
                        v-model="searchQuery"
                        @input="searchUsers"
                    >
                </div>
            </div>
            <div class="col-md-3">
                <select class="form-select" v-model="filterRole" @change="filterUsers">
                    <option value="">Tous les rôles</option>
                    <option value="admin">Administrateur</option>
                    <option value="commercial">Commercial</option>
                    <option value="chauffeur">Chauffeur</option>
                    <option value="comptabilite">Comptabilité</option>
                </select>
            </div>
            <div class="col-md-3">
                <button class="btn btn-outline-secondary" @click="resetFilters">
                    <i class="fas fa-undo"></i> Réinitialiser
                </button>
            </div>
        </div>

        <div v-if="showStatistics" class="row mb-4">
            <div class="col-md-3" v-for="stat in statistics.by_role" :key="stat.role">
                <div class="card text-center">
                    <div class="card-body">
                        <h5 class="card-title">{{ getRoleLabel(stat.role) }}</h5>
                        <p class="card-text">
                            <strong>{{ stat.count }}</strong> utilisateur(s)<br>
                            <small class="text-muted">
                                Salaire moyen: {{ formatCurrency(stat.salaire_moyen) }}
                            </small>
                        </p>
                    </div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h5 class="mb-0">Liste des Utilisateurs ({{ filteredUsers.length }})</h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="table-dark">
                            <tr>
                                <th>Nom Complet</th>
                                <th>Email</th>
                                <th>Rôle</th>
                                <th>Salaire</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="user in filteredUsers" :key="user.id">
                                <td>
                                    <strong>{{ user.nom }} {{ user.prenom }}</strong>
                                    <br>
                                    <small class="text-muted">ID: {{ user.id }}</small>
                                </td>
                                <td>{{ user.email }}</td>
                                <td>
                                    <span :class="getRoleBadgeClass(user.role)">
                                        {{ getRoleLabel(user.role) }}
                                    </span>
                                </td>
                                <td>
                                    <div class="input-group input-group-sm" style="width: 150px;">
                                        <input 
                                            type="number" 
                                            v-model="user.salaire" 
                                            @change="updateSalary(user)" 
                                            class="form-control"
                                            step="0.01"
                                            min="0"
                                        >
                                        <span class="input-group-text">F CFA</span>
                                    </div>
                                </td>
                                <td>
                                    <div class="btn-group btn-group-sm">
                                        <button 
                                            class="btn btn-outline-primary" 
                                            @click="openEditModal(user)"
                                            title="Modifier"
                                        >
                                            <i class="fas fa-edit"></i>
                                        </button>
                                        <button 
                                            class="btn btn-outline-warning" 
                                            @click="openResetPasswordModal(user)"
                                            title="Réinitialiser mot de passe"
                                        >
                                            <i class="fas fa-key"></i>
                                        </button>
                                        <button 
                                            v-if="user.actif" 
                                            class="btn btn-outline-danger" 
                                            @click="deactivateUser(user)"
                                            title="Désactiver"
                                            :disabled="user.id == currentUserId"
                                        >
                                            <i class="fas fa-ban"></i>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div v-if="showUserModal" class="modal d-block" style="background: rgba(0,0,0,0.5)">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <span v-if="isEditMode">Modifier utilisateur</span>
                            <span v-else>Créer un utilisateur</span>
                        </h5>
                        <button type="button" class="btn-close" @click="closeUserModal"></button>
                    </div>
                    <div class="modal-body">
                        <form @submit.prevent="saveUser">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Nom *</label>
                                        <input 
                                            v-model="userForm.nom" 
                                            type="text" 
                                            class="form-control" 
                                            required
                                        >
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Prénom *</label>
                                        <input 
                                            v-model="userForm.prenom" 
                                            type="text" 
                                            class="form-control" 
                                            required
                                        >
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Email *</label>
                                        <input 
                                            v-model="userForm.email" 
                                            type="email" 
                                            class="form-control" 
                                            required
                                        >
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Rôle *</label>
                                        <select v-model="userForm.role" class="form-select" required>
                                            <option value="">Sélectionner un rôle</option>
                                            <option value="admin">Administrateur</option>
                                            <option value="commercial">Commercial</option>
                                            <option value="chauffeur">Chauffeur</option>
                                            <option value="comptabilite">Comptabilité</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Salaire (F CFA)</label>
                                        <input 
                                            v-model="userForm.salaire" 
                                            type="number" 
                                            class="form-control"
                                            step="0.01"
                                            min="0"
                                        >
                                    </div>
                                </div>
                                <div class="col-md-6" v-if="!isEditMode">
                                    <div class="mb-3">
                                        <label class="form-label">Mot de passe *</label>
                                        <input 
                                            v-model="userForm.password" 
                                            type="password" 
                                            class="form-control" 
                                            :required="!isEditMode"
                                            minlength="8"
                                        >
                                    </div>
                                </div>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="button" class="btn btn-secondary me-2" @click="closeUserModal">
                                    Annuler
                                </button>
                                <button type="submit" class="btn btn-primary" :disabled="loading">
                                    <span v-if="loading" class="spinner-border spinner-border-sm me-2"></span>
                                    <span v-if="isEditMode">Modifier</span>
                                    <span v-else>Créer</span>
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </div>
    `,
    data() {
        return {
            users: [],
            filteredUsers: [],
            searchQuery: '',
            filterRole: '',
            showStatistics: false,
            statistics: { by_role: [], total_users: 0, total_salary: 0, average_salary: 0 },
            showUserModal: false,
            isEditMode: false,
            selectedUser: null,
            loading: false,
            currentUserId: null,
            userForm: {
                nom: '',
                prenom: '',
                email: '',
                role: '',
                salaire: 0,
                password: ''
            }
        }
    },
    methods: {
        async loadUsers() {
            try {
                const response = await fetch('/api/users', {
                    method: 'GET',
                    credentials: 'include',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });
                const data = await response.json();
                if (data.success) {
                    this.users = data.data;
                    this.filteredUsers = [...this.users];
                } else {
                    this.showAlert('Erreur lors du chargement des utilisateurs', 'danger');
                }
            } catch (error) {
                this.showAlert('Erreur de connexion', 'danger');
            }
        },

        async loadStatistics() {
            try {
                const response = await fetch('/api/users/statistics', {
                    method: 'GET',
                    credentials: 'include',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });
                const data = await response.json();
                if (data.success) {
                    this.statistics = data.data;
                    this.showStatistics = !this.showStatistics;
                } else {
                    this.showAlert('Erreur lors du chargement des statistiques', 'danger');
                }
            } catch (error) {
                this.showAlert('Erreur de connexion', 'danger');
            }
        },

        searchUsers() {
            this.filterUsers();
        },

        filterUsers() {
            let filtered = [...this.users];

            if (this.searchQuery.trim()) {
                const query = this.searchQuery.toLowerCase();
                filtered = filtered.filter(user =>
                    user.nom.toLowerCase().includes(query) ||
                    user.prenom.toLowerCase().includes(query) ||
                    user.email.toLowerCase().includes(query)
                );
            }

            if (this.filterRole) {
                filtered = filtered.filter(user => user.role === this.filterRole);
            }

            this.filteredUsers = filtered;
        },

        resetFilters() {
            this.searchQuery = '';
            this.filterRole = '';
            this.filteredUsers = [...this.users];
        },

        openCreateModal() {
            this.isEditMode = false;
            this.userForm = {
                nom: '',
                prenom: '',
                email: '',
                role: '',
                salaire: 0,
                password: ''
            };
            this.showUserModal = true;
        },

        openEditModal(user) {
            this.isEditMode = true;
            this.selectedUser = user;
            this.userForm = {
                nom: user.nom,
                prenom: user.prenom,
                email: user.email,
                role: user.role,
                salaire: user.salaire || 0,
                password: ''
            };
            this.showUserModal = true;
        },

        closeUserModal() {
            this.showUserModal = false;
            this.selectedUser = null;
            this.isEditMode = false;
        },

        async saveUser() {
            this.loading = true;
            try {
                const url = this.isEditMode ? '/api/users/' + this.selectedUser.id : '/api/users';
                const method = this.isEditMode ? 'PUT' : 'POST';

                const response = await fetch(url, {
                    method: method,
                    credentials: 'include',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body: JSON.stringify(this.userForm)
                });

                const data = await response.json();
                if (data.success) {
                    this.showAlert(
                        this.isEditMode ? 'Utilisateur modifié avec succès' : 'Utilisateur créé avec succès',
                        'success'
                    );
                    this.closeUserModal();
                    await this.loadUsers();
                } else {
                    this.showAlert(data.message || 'Erreur lors de la sauvegarde', 'danger');
                }
            } catch (error) {
                this.showAlert('Erreur de connexion', 'danger');
            } finally {
                this.loading = false;
            }
        },

        async updateSalary(user) {
            try {
                const response = await fetch('/api/users/' + user.id + '/salary', {
                    method: 'PUT',
                    credentials: 'include',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body: JSON.stringify({ salaire: user.salaire })
                });

                const data = await response.json();
                if (data.success) {
                    this.showAlert('Salaire mis à jour avec succès', 'success');
                } else {
                    this.showAlert(data.message || 'Erreur lors de la mise à jour du salaire', 'danger');
                    await this.loadUsers();
                }
            } catch (error) {
                this.showAlert('Erreur de connexion', 'danger');
                await this.loadUsers();
            }
        },

        openResetPasswordModal(user) {
            // Placeholder for password reset functionality
            this.showAlert('Fonctionnalité de réinitialisation de mot de passe à implémenter', 'info');
        },

        async deactivateUser(user) {
            const message = 'Êtes-vous sûr de vouloir désactiver ' + user.nom + ' ' + user.prenom + ' ?';
            if (!confirm(message)) {
                return;
            }

            try {
                const response = await fetch('/api/users/' + user.id + '/deactivate', {
                    method: 'PUT',
                    credentials: 'include',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });

                const data = await response.json();
                if (data.success) {
                    this.showAlert('Utilisateur désactivé avec succès', 'success');
                    await this.loadUsers();
                } else {
                    this.showAlert(data.message || 'Erreur lors de la désactivation', 'danger');
                }
            } catch (error) {
                this.showAlert('Erreur de connexion', 'danger');
            }
        },

        getRoleLabel(role) {
            const labels = {
                'admin': 'Administrateur',
                'commercial': 'Commercial',
                'chauffeur': 'Chauffeur',
                'comptabilite': 'Comptabilité'
            };
            return labels[role] || role;
        },

        getRoleBadgeClass(role) {
            const classes = {
                'admin': 'badge bg-danger',
                'commercial': 'badge bg-primary',
                'chauffeur': 'badge bg-warning',
                'comptabilite': 'badge bg-success'
            };
            return classes[role] || 'badge bg-secondary';
        },

        formatCurrency(amount) {
            if (!amount) return '0 F CFA';
            const formatted = new Intl.NumberFormat('fr-FR').format(amount);
            return formatted + ' F CFA';
        },

        showAlert(message, type) {
            if (this.$parent && this.$parent.addNotification) {
                this.$parent.addNotification(message, type);
            } else {
                alert(message);
            }
        }
    },

    async mounted() {
        const user = JSON.parse(localStorage.getItem('user') || '{}');
        this.currentUserId = user.id;
        await this.loadUsers();
    }
};
