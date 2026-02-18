//Logistique - Main Application
const { createApp } = Vue;
const { createRouter, createWebHashHistory } = VueRouter;

// Configure Axios defaults
axios.defaults.baseURL = '/api';
axios.defaults.headers.common['Content-Type'] = 'application/json';

// Add request interceptor to include auth token
axios.interceptors.request.use(
    config => {
        const token = localStorage.getItem('auth_token');
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
    },
    error => Promise.reject(error)
);

// Add response interceptor to handle auth errors
axios.interceptors.response.use(
    response => response,
    error => {
        if (error.response?.status === 401) {
            localStorage.removeItem('auth_token');
            localStorage.removeItem('user');
            window.location.reload();
        }
        return Promise.reject(error);
    }
);

// Define routes
const routes = [
    { path: '/', redirect: '/dashboard' },
    { path: '/dashboard', component: DashboardComponent },
    { path: '/clients', component: ClientsComponent },
    { path: '/commandes', component: CommandesComponent },
    { path: '/vehicules', component: VehiculesComponent },
    { path: '/trajets', component: TrajetsComponent },
    { path: '/factures', component: FacturesComponent },
    { path: '/transactions', component: TransactionsComponent },
    { path: '/planification', component: PlanificationBudgetComponent },
    { path: '/users', component: UserManagementComponent },
    // Nouvelle page navigation pour chauffeur
    { path: '/navigation', component: NavigationChauffeurComponent }
];

// Create router
const router = createRouter({
    history: createWebHashHistory(),
    routes
});

// Main application
const app = createApp({
    data() {
        return {
            user: null,
            loading: false,
            notifications: [],
            permissions: {}
        }
    },
    
    mounted() {
        this.checkAuth();
        this.loadNotifications();
    },
    
    methods: {
        async checkAuth() {
            const token = localStorage.getItem('auth_token');
            const userData = localStorage.getItem('user');
            
            if (token && userData) {
                try {
                    const response = await axios.get('/auth/me');
                    this.user = response.data.data;
                    this.setPermissions();
                } catch (error) {
                    console.error('Auth check failed:', error);
                    this.logout();
                }
            }
        },
        
        handleLogin(userData) {
            this.user = userData.user;
            localStorage.setItem('auth_token', userData.token);
            localStorage.setItem('user', JSON.stringify(userData.user));
            this.setPermissions();
            this.$router.push('/dashboard');
        },
        
        setPermissions() {
            // Set permissions based on user role - NOUVELLES PERMISSIONS STRICTES
            const rolePermissions = {
                admin: {
                    commandes: ['read'], // Lecture uniquement
                    clients: ['read'], // Lecture uniquement
                    trajets: ['read'], // Lecture uniquement
                    factures: ['read'], // Lecture uniquement
                    vehicules: ['read', 'write', 'delete'], // Ajout/suppression uniquement
                    users: ['read', 'write', 'delete'], // CRUD complet
                    planification: ['read', 'write', 'delete'], // CRUD complet
                    budget: ['read', 'write', 'delete'], // CRUD complet
                    dashboard: ['read']
                },
                commercial: {
                    commandes: ['read', 'write', 'delete'], // CRUD complet
                    clients: ['read', 'write', 'delete'], // CRUD complet
                    trajets: ['read'], // Lecture uniquement
                    vehicules: ['read'], // Lecture uniquement
                    dashboard: ['read']
                },
                comptabilite: {
                    commandes: ['read', 'validate'], // Lecture + validation
                    clients: ['read'], // Lecture uniquement
                    factures: ['read', 'write', 'delete'], // CRUD complet
                    transactions: ['read', 'write', 'delete'], // CRUD complet
                    planification: ['read', 'write', 'delete'], // CRUD complet - Comptable uniquement
                    budget: ['read', 'write', 'delete'], // CRUD complet
                    dashboard: ['read']
                },
                chauffeur: {
                    commandes: ['read'], // Lecture uniquement
                    clients: ['read'], // Lecture uniquement
                    trajets: ['read', 'write', 'delete'], // CRUD complet
                    vehicules: ['read', 'maintenance'], // Lecture + maintenance
                    dashboard: ['read']
                }
            };

            this.permissions = rolePermissions[this.user?.role] || {};
        },
        
        hasPermission(module, action) {
            return this.permissions[module]?.includes(action) || false;
        },
        
        async logout() {
            try {
                await axios.post('/auth/logout');
            } catch (error) {
                console.error('Logout error:', error);
            }
            
            this.user = null;
            this.permissions = {};
            localStorage.removeItem('auth_token');
            localStorage.removeItem('user');
            this.$router.push('/');
        },
        
        async loadNotifications() {
            if (!this.user) return;
            
            try {
                const response = await axios.get('/dashboard/notifications');
                this.notifications = response.data.data.map((notif, index) => ({
                    ...notif,
                    id: index
                }));
            } catch (error) {
                console.error('Failed to load notifications:', error);
            }
        },
        
        dismissNotification(id) {
            this.notifications = this.notifications.filter(n => n.id !== id);
        },
        
        showNotification(message, type = 'info', title = '') {
            const notification = {
                id: Date.now(),
                title,
                message,
                type
            };

            this.notifications.push(notification);

            // Auto-dismiss after 5 seconds
            setTimeout(() => {
                this.dismissNotification(notification.id);
            }, 5000);
        },

        addNotification(message, type = 'info', title = '') {
            this.showNotification(message, type, title);
        },
        
        formatDate(date, includeTime = false) {
            if (!date) return '-';
            
            const d = new Date(date);
            const options = {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric'
            };
            
            if (includeTime) {
                options.hour = '2-digit';
                options.minute = '2-digit';
            }
            
            return d.toLocaleDateString('fr-FR', options);
        },
        
        formatCurrency(amount) {
            if (amount === null || amount === undefined) return '-';
            // Format avec F CFA au lieu du format par défaut XOF
            const formatted = new Intl.NumberFormat('fr-FR').format(amount);
            return formatted + ' F CFA';
        },
        
        formatNumber(number) {
            if (number === null || number === undefined) return '-';
            return new Intl.NumberFormat('fr-FR').format(number);
        },
        
        changePassword() {
            // This would open a modal for password change
            // For now, just show an alert
            alert('Fonctionnalité de changement de mot de passe à implémenter');
        },
        
        async handleApiError(error, defaultMessage = 'Une erreur est survenue') {
            let message = defaultMessage;
            
            if (error.response?.data?.error) {
                message = error.response.data.error;
            } else if (error.response?.data?.message) {
                message = error.response.data.message;
            } else if (error.message) {
                message = error.message;
            }
            
            this.showNotification(message, 'danger', 'Erreur');
            console.error('API Error:', error);
        }
    },
    
    provide() {
        return {
            showNotification: this.showNotification,
            handleApiError: this.handleApiError,
            formatDate: this.formatDate,
            formatCurrency: this.formatCurrency,
            formatNumber: this.formatNumber,
            hasPermission: this.hasPermission,
            user: () => this.user
        }
    }
});

// Global components
app.component('login-component', LoginComponent);
app.component('user-management', UserManagementComponent);
app.component('navigation-chauffeur', NavigationChauffeurComponent);

// Use router
app.use(router);

// Mount app
app.mount('#app');

// Global error handler
window.addEventListener('error', (event) => {
    console.error('Global error:', event.error);
});

// Handle unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', event.reason);
});
