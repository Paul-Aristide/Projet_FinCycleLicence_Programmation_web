// Dashboard Chauffeur Component
const DashboardChauffeurComponent = {
    template: `
    <div class="dashboard fade-in">
        <!-- Page Header -->
        <div class="page-header dashboard-header">
            <h1>
                <i class="fas fa-tachometer-alt me-2"></i>
                Tableau de bord Chauffeur
            </h1>
            <p class="text-muted">Gestion des véhicules, trajets et clients</p>
        </div>
        
        <!-- Statistics Cards -->
        <div class="row mb-4" v-if="stats && stats.mes_trajets">
            <!-- Mes trajets -->
            <div class="col-lg-4 col-md-6 mb-3">
                <div class="stat-card trajets">
                    <div class="stat-icon">
                        <i class="fas fa-user-truck"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.mes_trajets.planifies || 0) }}</div>
                    <div class="stat-label">Mes trajets planifiés</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-road me-1"></i>
                        {{ formatNumber(stats.mes_trajets.km_ce_mois || 0) }} km ce mois
                    </small>
                </div>
            </div>
            
            <!-- Véhicules -->
            <div class="col-lg-4 col-md-6 mb-3" v-if="stats.vehicules">
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
            
            <!-- Clients -->
            <div class="col-lg-4 col-md-6 mb-3" v-if="stats.clients">
                <div class="stat-card clients">
                    <div class="stat-icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.clients?.total || 0) }}</div>
                    <div class="stat-label">Clients</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-handshake me-1"></i>
                        {{ stats.clients?.actifs || 0 }} actifs
                    </small>
                </div>
            </div>
        </div>
        
        <!-- Charts Row -->
        <div class="row mb-4">
            <!-- Trajets Status Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-pie me-2"></i>
                            État de mes trajets
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="trajetsChart"></canvas>
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
            <!-- Mes trajets récents -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-clock me-2"></i>
                            Mes trajets récents
                        </h5>
                        <router-link to="/trajets" class="btn btn-sm btn-outline-primary">
                            Voir tout
                        </router-link>
                    </div>
                    <div class="card-body">
                        <div v-if="recentActivities && recentActivities.length === 0" class="text-center text-muted py-3">
                            Aucun trajet récent
                        </div>
                        <div v-else>
                            <div v-for="activity in (recentActivities || []).slice(0, 5)" :key="activity.id" 
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
                            <div class="col-12 mb-2">
                                <router-link to="/trajets" class="btn btn-primary w-100">
                                    <i class="fas fa-route me-2"></i>
                                    Voir mes trajets
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/vehicules" class="btn btn-outline-info w-100 btn-icon-right">
                                    <i class="fas fa-truck"></i>
                                    Véhicules
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/clients" class="btn btn-outline-success w-100 btn-icon-right">
                                    <i class="fas fa-users"></i>
                                    Clients
                                </router-link>
                            </div>
                        </div>
                        
                        <!-- Performance du mois -->
                        <div class="mt-3 p-3 bg-light rounded" v-if="stats.mes_trajets">
                            <h6 class="mb-2">
                                <i class="fas fa-trophy me-2 text-warning"></i>
                                Performance ce mois
                            </h6>
                            <div class="row text-center">
                                <div class="col-4">
                                    <div class="fw-bold text-primary">{{ stats.mes_trajets.termines || 0 }}</div>
                                    <small class="text-muted">Terminés</small>
                                </div>
                                <div class="col-4">
                                    <div class="fw-bold text-success">{{ formatNumber(stats.mes_trajets.km_ce_mois || 0) }}</div>
                                    <small class="text-muted">Km</small>
                                </div>
                                <div class="col-4">
                                    <div class="fw-bold text-info">{{ stats.mes_trajets.ponctualite || 0 }}%</div>
                                    <small class="text-muted">Ponctualité</small>
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
            trajetsChart: null,
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
        if (this.trajetsChart) {
            this.trajetsChart.destroy();
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
                
                // Load recent activities (trajets for driver)
                const activitiesResponse = await axios.get('/dashboard/activities?limit=10&type=trajets');
                this.recentActivities = activitiesResponse.data.data;
                
            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement du tableau de bord');
            }
        },
        
        initializeCharts() {
            this.initTrajetsChart();
            this.initVehiclesChart();
        },
        
        initTrajetsChart() {
            if (!this.$refs.trajetsChart || !this.stats?.mes_trajets) return;
            
            const ctx = this.$refs.trajetsChart.getContext('2d');
            
            this.trajetsChart = new Chart(ctx, {
                type: 'pie',
                data: {
                    labels: ['Planifiés', 'En cours', 'Terminés', 'Annulés'],
                    datasets: [{
                        data: [
                            this.stats.mes_trajets.planifies || 0,
                            this.stats.mes_trajets.en_cours || 0,
                            this.stats.mes_trajets.termines || 0,
                            this.stats.mes_trajets.annules || 0
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
                'planifie': 'Planifié',
                'en_cours': 'En cours',
                'termine': 'Terminé',
                'annule': 'Annulé'
            };
            
            return labels[status] || status;
        }
    }
};
