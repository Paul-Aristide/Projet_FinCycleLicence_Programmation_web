// Simple version of UserManagement component for testing
const UserManagementSimpleComponent = {
    template: `
    <div class="container-fluid">
        <!-- Page Header with Background Image -->
        <div class="page-header users-header mb-3" style="background-image: linear-gradient(rgba(0,0,0,0.5), rgba(0,0,0,0.5)), url('public/images/utilisateur.jpg'); background-size: cover; background-position: center; border-radius: 10px; padding: 2rem; color: white;">
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
            <button class="btn btn-primary" @click="openCreateModal">
                <i class="fas fa-plus"></i> Nouvel Utilisateur
            </button>
        </div>

        <div class="card">
            <div class="card-header">
                <h5 class="mb-0">Liste des Utilisateurs ({{ users.length }})</h5>
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
                            <tr v-for="user in users" :key="user.id">
                                <td>{{ user.nom }} {{ user.prenom }}</td>
                                <td>{{ user.email }}</td>
                                <td>{{ user.role }}</td>
                                <td>{{ user.salaire || 0 }} F CFA</td>
                                <td>
                                    <button class="btn btn-sm btn-primary" @click="editUser(user)">
                                        Modifier
                                    </button>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Simple Modal -->
        <div v-if="showModal" class="modal d-block" style="background: rgba(0,0,0,0.5)">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Gestion Utilisateur</h5>
                        <button type="button" class="btn-close" @click="closeModal"></button>
                    </div>
                    <div class="modal-body">
                        <p>Fonctionnalité en cours de développement...</p>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" @click="closeModal">
                            Fermer
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    `,
    data() {
        return {
            users: [
                { id: 1, nom: 'Doe', prenom: 'John', email: 'john@example.com', role: 'admin', salaire: 5000 },
                { id: 2, nom: 'Smith', prenom: 'Jane', email: 'jane@example.com', role: 'commercial', salaire: 3500 }
            ],
            showModal: false
        }
    },
    methods: {
        openCreateModal() {
            this.showModal = true;
        },
        closeModal() {
            this.showModal = false;
        },
        editUser(user) {
            console.log('Edit user:', user);
            this.showModal = true;
        }
    },
    mounted() {
        console.log('UserManagementSimple component mounted');
    }
};
