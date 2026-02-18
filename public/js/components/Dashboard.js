// Dashboard Component
const DashboardComponent = {
    template: `
    <div class="dashboard fade-in">
        <!-- Role-specific dashboards -->
        <dashboard-commercial-component v-if="user().role === 'commercial'"></dashboard-commercial-component>
        <dashboard-comptable-component v-if="user().role === 'comptabilite'"></dashboard-comptable-component>
        <dashboard-chauffeur-component v-if="user().role === 'chauffeur'"></dashboard-chauffeur-component>

        <!-- Admin Dashboard (default) -->
        <div v-if="user().role === 'admin'">
            <!-- Page Header -->
            <div class="page-header dashboard-header">
                <h1>
                    <i class="fas fa-tachometer-alt me-2"></i>
                    Tableau de bord Administrateur
                </h1>
                <p class="text-muted">Vue d'ensemble complète du système</p>
            </div>
        
        <!-- Statistics Cards -->
        <div class="row mb-4" v-if="stats">
            <!-- Clients -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="hasPermission('clients', 'read')">
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
            <div class="col-lg-3 col-md-6 mb-3" v-if="hasPermission('commandes', 'read')">
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
            <div class="col-lg-3 col-md-6 mb-3" v-if="hasPermission('vehicules', 'read')">
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
            
            <!-- Trajets -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="hasPermission('trajets', 'read')">
                <div class="stat-card trajets">
                    <div class="stat-icon">
                        <i class="fas fa-route"></i>
                    </div>
                    <div class="stat-number">{{ formatNumber(stats.trajets?.total || 0) }}</div>
                    <div class="stat-label">Trajets</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-play-circle me-1"></i>
                        {{ stats.trajets?.en_cours || 0 }} en cours
                    </small>
                </div>
            </div>
            
            <!-- Factures (Admin/Comptabilité) -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="hasPermission('factures', 'read')">
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
            
            <!-- Revenus (Admin/Comptabilité) -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="hasPermission('factures', 'read') && stats.revenus">
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

            <!-- Dépenses Totales (Admin uniquement) -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="user().role === 'admin' && stats.depenses">
                <div class="stat-card depenses">
                    <div class="stat-icon">
                        <i class="fas fa-money-bill-wave"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.depenses.total_mois || 0) }}</div>
                    <div class="stat-label">Dépenses ce mois</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-tools me-1"></i>
                        {{ formatCurrency(stats.depenses.maintenance || 0) }} maintenance
                    </small>
                </div>
            </div>

            <!-- Salaires Totaux (Admin uniquement) -->
            <div class="col-lg-3 col-md-6 mb-3" v-if="user().role === 'admin' && stats.salaires">
                <div class="stat-card salaires">
                    <div class="stat-icon">
                        <i class="fas fa-users-cog"></i>
                    </div>
                    <div class="stat-number">{{ formatCurrency(stats.salaires.total_mensuel || 0) }}</div>
                    <div class="stat-label">Masse salariale</div>
                    <small class="d-block mt-1">
                        <i class="fas fa-user me-1"></i>
                        {{ stats.salaires.nombre_employes || 0 }} employés actifs
                    </small>
                </div>
            </div>
            
            <!-- Mes trajets (Chauffeur) -->
            <div class="col-lg-6 col-md-6 mb-3" v-if="user().role === 'chauffeur' && stats.mes_trajets">
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
        </div>
        
        <!-- Charts Row -->
        <div class="row mb-4" v-if="hasPermission('dashboard', 'read')">
            <!-- Order Status Chart -->
            <div class="col-lg-6 mb-3" v-if="hasPermission('commandes', 'read')">
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
            <div class="col-lg-6 mb-3" v-if="hasPermission('vehicules', 'read')">
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

        <!-- Financial Charts Row (Admin only) -->
        <div class="row mb-4" v-if="user().role === 'admin' && hasPermission('dashboard', 'read')">
            <!-- Expenses Breakdown Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-bar me-2"></i>
                            Répartition des dépenses
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="expensesChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Daily Revenue Evolution Chart -->
            <div class="col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-chart-line me-2"></i>
                            Évolution des gains quotidiens
                        </h5>
                        <div class="btn-group btn-group-sm" role="group">
                            <button type="button" class="btn btn-outline-primary"
                                    :class="{ active: revenueChartPeriod === '7' }"
                                    @click="changeRevenueChartPeriod('7')">7j</button>
                            <button type="button" class="btn btn-outline-primary"
                                    :class="{ active: revenueChartPeriod === '30' }"
                                    @click="changeRevenueChartPeriod('30')">30j</button>
                            <button type="button" class="btn btn-outline-primary"
                                    :class="{ active: revenueChartPeriod === '90' }"
                                    @click="changeRevenueChartPeriod('90')">90j</button>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="chart-container chart-small">
                            <canvas ref="revenueChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Recent Activities -->
        <div class="row">
            <!-- Recent Orders -->
            <div class="col-lg-6 mb-3" v-if="hasPermission('commandes', 'read')">
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
                            <div class="col-6" v-if="hasPermission('clients', 'write')">
                                <router-link to="/clients" class="btn btn-outline-primary w-100 btn-icon-right">
                                    <i class="fas fa-user-plus"></i>
                                    Nouveau client
                                </router-link>
                            </div>
                            <div class="col-6" v-if="hasPermission('commandes', 'write')">
                                <router-link to="/commandes" class="btn btn-outline-success w-100 btn-icon-right">
                                    <i class="fas fa-plus"></i>
                                    Nouvelle commande
                                </router-link>
                            </div>
                            <div class="col-6" v-if="hasPermission('trajets', 'write')">
                                <router-link to="/trajets" class="btn btn-outline-info w-100 btn-icon-right">
                                    <i class="fas fa-route"></i>
                                    Planifier trajet
                                </router-link>
                            </div>
                            <div class="col-6" v-if="hasPermission('factures', 'write')">
                                <router-link to="/factures" class="btn btn-outline-warning w-100 btn-icon-right">
                                    <i class="fas fa-file-invoice"></i>
                                    Nouvelle facture
                                </router-link>
                            </div>
                        </div>
                        
                        <!-- Driver specific actions -->
                        <div v-if="user().role === 'chauffeur'" class="mt-3">
                            <router-link to="/trajets" class="btn btn-primary w-100">
                                <i class="fas fa-route me-2"></i>
                                Voir mes trajets
                            </router-link>
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
    </div>
    `,

    components: {
        'dashboard-commercial-component': DashboardCommercialComponent,
        'dashboard-comptable-component': DashboardComptableComponent,
        'dashboard-chauffeur-component': DashboardChauffeurComponent
    },
    
    inject: ['showNotification', 'handleApiError', 'formatDate', 'formatCurrency', 'formatNumber', 'hasPermission', 'user'],
    
    data() {
        return {
            loading: true,
            stats: null,
            recentActivities: [],
            ordersChart: null,
            vehiclesChart: null,
            expensesChart: null,
            revenueChart: null,
            revenueChartPeriod: '30'
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
        if (this.expensesChart) {
            this.expensesChart.destroy();
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
            this.initOrdersChart();
            this.initVehiclesChart();
            if (this.user().role === 'admin') {
                this.initExpensesChart();
                this.initRevenueChart();
            }
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

        initExpensesChart() {
            if (!this.$refs.expensesChart || !this.stats?.depenses) return;

            const ctx = this.$refs.expensesChart.getContext('2d');

            this.expensesChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: ['Maintenance', 'Carburant', 'Salaires', 'Assurance', 'Autres'],
                    datasets: [{
                        label: 'Montant (F CFA)',
                        data: [
                            this.stats.depenses.maintenance || 0,
                            this.stats.depenses.carburant || 0,
                            this.stats.depenses.salaires || 0,
                            this.stats.depenses.assurance || 0,
                            this.stats.depenses.autres || 0
                        ],
                        backgroundColor: [
                            '#dc3545',
                            '#fd7e14',
                            '#6f42c1',
                            '#0dcaf0',
                            '#6c757d'
                        ],
                        borderColor: [
                            '#dc3545',
                            '#fd7e14',
                            '#6f42c1',
                            '#0dcaf0',
                            '#6c757d'
                        ],
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            callbacks: {
                                label: (context) => {
                                    return context.dataset.label + ': ' + this.formatCurrency(context.parsed.y);
                                }
                            }
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                callback: (value) => {
                                    return this.formatCurrency(value);
                                }
                            }
                        }
                    }
                }
            });
        },

        initRevenueChart() {
            if (!this.$refs.revenueChart || !this.stats?.revenus_quotidiens) return;

            const ctx = this.$refs.revenueChart.getContext('2d');

            this.revenueChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: this.stats.revenus_quotidiens.dates || [],
                    datasets: [{
                        label: 'Gains quotidiens',
                        data: this.stats.revenus_quotidiens.montants || [],
                        borderColor: '#198754',
                        backgroundColor: 'rgba(25, 135, 84, 0.1)',
                        borderWidth: 2,
                        fill: true,
                        tension: 0.4,
                        pointBackgroundColor: '#198754',
                        pointBorderColor: '#fff',
                        pointBorderWidth: 2,
                        pointRadius: 4,
                        pointHoverRadius: 6
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            callbacks: {
                                label: (context) => {
                                    return 'Gains: ' + this.formatCurrency(context.parsed.y);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            grid: {
                                display: false
                            }
                        },
                        y: {
                            beginAtZero: true,
                            grid: {
                                color: 'rgba(0,0,0,0.1)'
                            },
                            ticks: {
                                callback: (value) => {
                                    return this.formatCurrency(value);
                                }
                            }
                        }
                    },
                    interaction: {
                        intersect: false,
                        mode: 'index'
                    }
                }
            });
        },

        async changeRevenueChartPeriod(period) {
            this.revenueChartPeriod = period;

            try {
                // Reload revenue data for the new period
                const response = await axios.get(`/dashboard/revenue-evolution?period=${period}`);
                this.stats.revenus_quotidiens = response.data.data;

                // Update the chart
                if (this.revenueChart) {
                    this.revenueChart.destroy();
                }
                this.$nextTick(() => {
                    this.initRevenueChart();
                });

            } catch (error) {
                this.handleApiError(error, 'Erreur lors du chargement des données de revenus');
            }
        },

        getStatusLabel(status) {
            const labels = {
                'en_attente': 'En attente',
                'confirmee': 'Confirmée',
                'en_cours': 'En cours',
                'livree': 'Livrée',
                'annulee': 'Annulée',
                'planifie': 'Planifié',
                'termine': 'Terminé',
                'annule': 'Annulé',
                'brouillon': 'Brouillon',
                'envoyee': 'Envoyée',
                'payee': 'Payée'
            };
            
            return labels[status] || status;
        }
    }
};
