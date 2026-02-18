// Dashboard Commercial Component
const DashboardCommercialComponent = {
    template: `
    <div class="dashboard fade-in">
        <!-- Page Header -->
        <div class="page-header dashboard-header">
            <h1>
                <i class="fas fa-tachometer-alt me-2"></i>
                Tableau de bord Commercial
            </h1>
            <p class="text-muted">Gestion des clients, véhicules et commandes</p>
        </div>
        
        <!-- Statistics Cards -->
        <div class="row mb-4" v-if="stats">
            <!-- Clients -->
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card clients">
                    <div class="stat-icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.clients?.total || 0) }}</div>
                    <div class="stat-label">Clients</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-plus me-1"></i>
                        {{ stats.clients?.nouveaux_ce_mois || 0 }} nouveaux ce mois
                    </small>
                </div>
            </div>
            
            <!-- Commandes -->
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card commandes">
                    <div class="stat-icon">
                        <i class="fas fa-clipboard-list"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.commandes?.total || 0) }}</div>
                    <div class="stat-label">Commandes</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-clock me-1"></i>
                        {{ stats.commandes?.en_attente || 0 }} en attente
                    </small>
                </div>
            </div>
            
            <!-- Véhicules -->
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card vehicules">
                    <div class="stat-icon">
                        <i class="fas fa-truck"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.vehicules?.total || 0) }}</div>
                    <div class="stat-label">Véhicules</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-check-circle me-1"></i>
                        {{ stats.vehicules?.disponibles || 0 }} disponibles
                    </small>
                </div>
            </div>
        </div>
        
        <!-- Charts Row -->
        <div class="row mb-4">
            <!-- Order Status Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-pie me-2"></i>
                            Répartition des commandes
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="ordersChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Vehicle Status Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-doughnut me-2"></i>
                            État de la flotte
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="vehiclesChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Recent Activities and Quick Actions -->
        <div class="row">
            <!-- Recent Orders -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-clock me-2"></i>
                            Commandes récentes
                        </h5>
                        <router-link to="/commandes" class="btn btn-sm btn-outline-primary">
                            Voir tout
                        </router-link>
                    </div>
                    <div class="card-body">
                        <div v-if="recentActivities.length === 0" class="text-center text-muted py-3">
                            Aucune activité récente
                        </div>
                        <div v-else>
                            <div v-for="activity in recentActivities.slice(0, 5)" :key="activity.id" 
                                 class="d-flex justify-content-between align-items-center py-2 border-bottom">
                                <div>
                                    <strong>{{ activity.title }}</strong>
                                    <br>
                                    <small class="text-muted">{{ activity.description }}</small>
                                </div>
                                <div class="text-end">
                                    <span :class="'status-badge status-' + activity.status">
                                        {{ getStatusLabel(activity.status) }}
                                    </span>
                                    <br>
                                    <small class="text-muted">{{ formatDate(activity.date) }}</small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Quick Actions -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-bolt me-2"></i>
                            Actions rapides
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="row g-2">
                            <div class="col-6">
                                <router-link to="/clients" class="btn btn-outline-primary w-100 btn-icon-right">
                                    <i class="fas fa-user-plus"></i>
                                    Nouveau client
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/commandes" class="btn btn-outline-success w-100 btn-icon-right">
                                    <i class="fas fa-plus"></i>
                                    Nouvelle commande
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/vehicules" class="btn btn-outline-info w-100 btn-icon-right">
                                    <i class="fas fa-truck"></i>
                                    Gérer véhicules
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/clients" class="btn btn-outline-warning w-100 btn-icon-right">
                                    <i class="fas fa-search"></i>
                                    Rechercher client
                                </router-link>
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
            <p class="mt-2 text-muted">Chargement du tableau de bord...</p>
        </div>
    </div>
    `,
    
    inject: ['showNotification', 'handleApiError', 'formatDate', 'formatCurrency', 'formatNumber', 'hasPermission', 'user'],
    
    data() {
        return {
            loading: true,
            stats: null,
            recentActivities: [],
            ordersChart: null,
            vehiclesChart: null
        }
    },
    
    async mounted() {
        await this.loadDashboardData();
        this.loading = false;
        
        // Initialize charts after DOM is ready
        this.$nextTick(() => {
            this.initializeCharts();
        });
    },
    
    beforeUnmount() {
        // Destroy charts to prevent memory leaks
        if (this.ordersChart) {
            this.ordersChart.destroy();
        }
        if (this.vehiclesChart) {
            this.vehiclesChart.destroy();
        }
    },
    
    methods: {
        async loadDashboardData() {
            try {
                // Load statistics
                const statsResponse = await axios.get('/dashboard/stats');
                this.stats = statsResponse.data.data;
                
                // Load recent activities
                const activitiesResponse = await axios.get('/dashboard/activities?limit=10');
                this.recentActivities = activitiesResponse.data.data;
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement du tableau de bord');
            }
        },
        
        initializeCharts() {
            this.initOrdersChart();
            this.initVehiclesChart();
        },
        
        initOrdersChart() {
            if (!this.$refs.ordersChart || !this.stats?.commandes) return;
            
            const ctx = this.$refs.ordersChart.getContext('2d');
            
            this.ordersChart = new Chart(ctx, {
                type: 'pie',
                data: {
                    labels: ['En attente', 'En cours', 'Livrées', 'Annulées'],
                    datasets: [{
                        data: [
                            this.stats.commandes.en_attente || 0,
                            this.stats.commandes.en_cours || 0,
                            this.stats.commandes.livrees || 0,
                            this.stats.commandes.annulees || 0
                        ],
                        backgroundColor: [
                            '#ffc107',
                            '#0dcaf0',
                            '#198754',
                            '#dc3545'
                        ],
                        borderWidth: 2,
                        borderColor: '#fff'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        }
                    }
                }
            });
        },
        
        initVehiclesChart() {
            if (!this.$refs.vehiclesChart || !this.stats?.vehicules) return;
            
            const ctx = this.$refs.vehiclesChart.getContext('2d');
            
            this.vehiclesChart = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: ['Disponibles', 'En mission', 'Maintenance'],
                    datasets: [{
                        data: [
                            this.stats.vehicules.disponibles || 0,
                            this.stats.vehicules.en_mission || 0,
                            this.stats.vehicules.maintenance || 0
                        ],
                        backgroundColor: [
                            '#198754',
                            '#0dcaf0',
                            '#ffc107'
                        ],
                        borderWidth: 2,
                        borderColor: '#fff'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        }
                    }
                }
            });
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
        }
    }
};
