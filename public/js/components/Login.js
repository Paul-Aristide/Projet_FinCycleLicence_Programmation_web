// Login Component
const LoginComponent = {
    template: `
    <div class="login-container">
        <div class="login-card card shadow">
            <div class="card-body">
                <div class="login-header">
                    <div class="login-logo">
                        <img src="images/logo.png" alt="Logo LogisWayZ" style="max-width: 300px; margin: 0 auto; border: 5px double skyblue;border-radius: 100%;">
                    </div>
                    <p class="text-muted">Connectez-vous à votre compte</p>
                </div>
                
                <form @submit.prevent="handleLogin">
                    <div class="mb-3">
                        <label for="email" class="form-label">Email</label>
                        <div class="input-group">
                            <span class="input-group-text">
                                <i class="fas fa-envelope"></i>
                            </span>
                            <input type="email" 
                                   id="email"
                                   class="form-control" 
                                   v-model="credentials.email" 
                                   placeholder="votre_email@gmail.com"
                                   required 
                                   :disabled="loading">
                        </div>
                    </div>
                    
                    <div class="mb-3">
                        <label for="password" class="form-label">Mot de passe</label>
                        <div class="input-group">
                            <span class="input-group-text">
                                <i class="fas fa-lock"></i>
                            </span>
                            <input :type="showPassword ? 'text' : 'password'" 
                                   id="password"
                                   class="form-control" 
                                   v-model="credentials.password" 
                                   placeholder="Votre mot de passe"
                                   required 
                                   :disabled="loading">
                            <button type="button" 
                                    class="btn btn-outline-secondary" 
                                    @click="togglePassword"
                                    :disabled="loading">
                                <i :class="showPassword ? 'fas fa-eye-slash' : 'fas fa-eye'"></i>
                            </button>
                        </div>
                    </div>
                    
                    <div class="mb-3 form-check">
                        <input type="checkbox" 
                               class="form-check-input" 
                               id="remember" 
                               v-model="credentials.remember"
                               :disabled="loading">
                        <label class="form-check-label" for="remember">
                            Se souvenir de moi
                        </label>
                    </div>
                    
                    <div v-if="error" class="alert alert-danger" role="alert">
                        <i class="fas fa-exclamation-triangle me-2"></i>
                        {{ error }}
                    </div>
                    
                    <button type="submit" 
                            class="btn btn-primary w-100 mb-3" 
                            :disabled="loading">
                        <span v-if="loading" class="spinner-border spinner-border-sm me-2" role="status"></span>
                        <i v-else class="fas fa-sign-in-alt me-2"></i>
                        {{ loading ? 'Connexion...' : 'Se connecter' }}
                    </button>
                </form>
                
                <div class="text-center">
                    <small class="text-muted">
                        Mot de passe oublié ?
                        <a href="#" @click="resetPassword" class="text-decoration-none">
                            Cliquez ici
                        </a>
                    </small>
                </div>

                <!-- Séparateur -->
                <div class="text-center my-4">
                    <hr class="my-3">
                    <span class="text-muted bg-white px-3">OU</span>
                </div>

                <div class="text-center mt-3">
                    <small class="text-muted">
                        <i class="fas fa-truck me-2"></i>
                        LOGISWAYZ VOTRE PARTENAIRE DE CONFIANCE
                    </small>
                </div>
            </div>
        </div>
    </div>
    `,
    
    emits: ['login', 'show-register'],
    
    data() {
        return {
            credentials: {
                email: '',
                password: '',
                remember: false
            },
            loading: false,
            error: '',
            showPassword: false,
            showDemoAccounts: true, // Set to true for development, false for production
            clientTracking: {
                numero_commande: ''
            },
            clientLoading: false,
            clientError: ''
        }
    },
    
    mounted() {
        // Check if user credentials are remembered
        const savedEmail = localStorage.getItem('remembered_email');
        if (savedEmail) {
            this.credentials.email = savedEmail;
            this.credentials.remember = true;
        }
        
        // Focus on email field
        this.$nextTick(() => {
            const emailInput = document.getElementById('email');
            if (emailInput) {
                emailInput.focus();
            }
        });
    },
    
    methods: {
        async handleLogin() {
            this.loading = true;
            this.error = '';
            
            try {
                // Validate inputs
                if (!this.credentials.email || !this.credentials.password) {
                    throw new Error('Veuillez remplir tous les champs');
                }
                
                // Validate email format
                const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                if (!emailRegex.test(this.credentials.email)) {
                    throw new Error('Format d\'email invalide');
                }
                
                // Make login request
                const response = await axios.post('/auth/login', {
                    email: this.credentials.email,
                    password: this.credentials.password
                });
                
                // Handle remember me
                if (this.credentials.remember) {
                    localStorage.setItem('remembered_email', this.credentials.email);
                } else {
                    localStorage.removeItem('remembered_email');
                }
                
                // Emit login event to parent
                this.$emit('login', response.data.data);
                
            } catch (error) {
                console.error('Login error:', error);
                
                if (error.response?.data?.error) {
                    this.error = error.response.data.error;
                } else if (error.message) {
                    this.error = error.message;
                } else {
                    this.error = 'Erreur de connexion. Veuillez réessayer.';
                }
                
                // Clear password on error
                this.credentials.password = '';
                
                // Focus back on password field
                this.$nextTick(() => {
                    const passwordInput = document.getElementById('password');
                    if (passwordInput) {
                        passwordInput.focus();
                    }
                });
            }
            
            this.loading = false;
        },
        
        togglePassword() {
            this.showPassword = !this.showPassword;
        },
        
        resetPassword() {
            alert('Fonctionnalité de réinitialisation du mot de passe non implémentée.\nContactez votre administrateur système.');
        },

        async handleClientTracking() {
            this.clientLoading = true;
            this.clientError = '';

            try {
                // Valider le numéro de commande
                if (!this.clientTracking.numero_commande) {
                    throw new Error('Veuillez saisir le numéro de votre commande');
                }

                const numeroCommande = this.clientTracking.numero_commande.trim().toUpperCase();
                if (numeroCommande.length < 3) {
                    throw new Error('Le numéro de commande doit contenir au moins 3 caractères');
                }

                // Faire la requête de connexion client
                const response = await axios.post('/api/client/login', {
                    numero_commande: numeroCommande
                });

                if (response.data.success) {
                    // Rediriger vers la page de suivi client
                    const focusCommande = response.data.data.focus_commande_id;
                    let redirectUrl = '/client-tracking.html';

                    if (focusCommande) {
                        redirectUrl += `?focus=${focusCommande}`;
                    }

                    window.location.href = redirectUrl;
                } else {
                    throw new Error(response.data.error || 'Erreur de connexion');
                }

            } catch (error) {
                console.error('Client tracking error:', error);

                if (error.response?.data?.error) {
                    this.clientError = error.response.data.error;
                } else if (error.message) {
                    this.clientError = error.message;
                } else {
                    this.clientError = 'Erreur lors de la recherche de votre commande. Veuillez réessayer.';
                }

                // Clear numero commande on error
                this.clientTracking.numero_commande = '';

                // Focus back on numero commande field
                this.$nextTick(() => {
                    const commandeInput = document.getElementById('numero_commande');
                    if (commandeInput) {
                        commandeInput.focus();
                    }
                });
            }

            this.clientLoading = false;
        }
    }
};
