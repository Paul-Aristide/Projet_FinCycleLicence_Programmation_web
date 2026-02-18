// Dashboard Comptable Component
const DashboardComptableComponent = {
    template: `
    <div class="dashboard fade-in">
        <!-- Page Header -->
        <div class="page-header dashboard-header">
            <h1>
                <i class="fas fa-tachometer-alt me-2"></i>
                Tableau de bord Comptabilité
            </h1>
            <p class="text-muted">Gestion des clients, factures et commandes</p>
        </div>
        
        <!-- Statistics Cards -->
        <div class="row mb-4" v-if="stats">
            <!-- Clients -->
            <div class="col-lg-3 col-md-6 mb-3">
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
            <div class="col-lg-3 col-md-6 mb-3">
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
            
            <!-- Factures -->
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card factures">
                    <div class="stat-icon">
                        <i class="fas fa-file-invoice"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.factures?.total || 0) }}</div>
                    <div class="stat-label">Factures</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-exclamation-triangle me-1"></i>
                        {{ stats.factures?.en_retard || 0 }} en retard
                    </small>
                </div>
            </div>
            
            <!-- Revenus -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="stats.revenus">
                <div class="stat-card revenus">
                    <div class="stat-icon">
                        <i class="fas fa-franc-sign"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.revenus.ca_mois || 0) }}</div>
                    <div class="stat-label">CA ce mois</div>
                    <small class="d-block mt-1">
                        <i :class="stats.revenus.croissance >= 0 ? 'fas fa-arrow-up text-success' : 'fas fa-arrow-down text-danger'"></i>
                        {{ Math.abs(stats.revenus.croissance || 0).toFixed(1) }}% vs mois dernier
                    </small>
                </div>
            </div>
        </div>
        
        <!-- Charts Row -->
        <div class="row mb-4">
            <!-- Factures Status Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-pie me-2"></i>
                            État des factures
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="facturesChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Revenue Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-line me-2"></i>
                            Évolution du CA
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="revenueChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Recent Activities and Quick Actions -->
        <div class="row">
            <!-- Recent Invoices -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-clock me-2"></i>
                            Factures récentes
                        </h5>
                        <router-link to="/factures" class="btn btn-sm btn-outline-primary">
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
                                <router-link to="/factures" class="btn btn-outline-primary w-100 btn-icon-right">
                                    <i class="fas fa-file-invoice"></i>
                                    Nouvelle facture
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/clients" class="btn btn-outline-success w-100 btn-icon-right">
                                    <i class="fas fa-user-plus"></i>
                                    Nouveau client
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/transactions" class="btn btn-outline-info w-100 btn-icon-right">
                                    <i class="fas fa-exchange-alt"></i>
                                    Transactions
                                </router-link>
                            </div>
                            <div class="col-6">
                                <router-link to="/planification" class="btn btn-outline-warning w-100 btn-icon-right">
                                    <i class="fas fa-calendar-alt"></i>
                                    Planification
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
            facturesChart: null,
            revenueChart: null
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
        if (this.facturesChart) {
            this.facturesChart.destroy();
        }
        if (this.revenueChart) {
            this.revenueChart.destroy();
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
            this.initFacturesChart();
            this.initRevenueChart();
        },
        
        initFacturesChart() {
            if (!this.$refs.facturesChart || !this.stats?.factures) return;
            
            const ctx = this.$refs.facturesChart.getContext('2d');
            
            this.facturesChart = new Chart(ctx, {
                type: 'pie',
                data: {
                    labels: ['Brouillon', 'Envoyées', 'Payées', 'En retard'],
                    datasets: [{
                        data: [
                            this.stats.factures.brouillon || 0,
                            this.stats.factures.envoyees || 0,
                            this.stats.factures.payees || 0,
                            this.stats.factures.en_retard || 0
                        ],
                        backgroundColor: [
                            '#6c757d',
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
        
        initRevenueChart() {
            if (!this.$refs.revenueChart || !this.stats?.revenus) return;
            
            const ctx = this.$refs.revenueChart.getContext('2d');
            
            this.revenueChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'],
                    datasets: [{
                        label: 'Chiffre d\'affaires',
                        data: this.stats.revenus.monthly || [0, 0, 0, 0, 0, 0],
                        borderColor: '#0d6efd',
                        backgroundColor: 'rgba(13, 110, 253, 0.1)',
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        },
        
        getStatusLabel(status) {
            const labels = {
                'brouillon': 'Brouillon',
                'envoyee': 'Envoyée',
                'payee': 'Payée',
                'en_retard': 'En retard'
            };
            
            return labels[status] || status;
        }
    }
};
