const RegisterComponent = {
    template: `
        <div class="container mt-5">
            <div class="row justify-content-center">
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header">
                            <h3 class="text-center">Inscription</h3>
                        </div>
                        <div class="card-body">
                            <form @submit.prevent="register">
                                <div class="mb-3">
                                    <label for="nom" class="form-label">Nom</label>
                                    <input type="text" id="nom" v-model="nom" class="form-control" required>
                                </div>
                                <div class="mb-3">
                                    <label for="prenom" class="form-label">Prénom</label>
                                    <input type="text" id="prenom" v-model="prenom" class="form-control" required>
                                </div>
                                <div class="mb-3">
                                    <label for="email" class="form-label">Email</label>
                                    <input type="email" id="email" v-model="email" class="form-control" required>
                                </div>
                                <div class="mb-3">
                                    <label for="password" class="form-label">Mot de passe</label>
                                    <input type="password" id="password" v-model="password" class="form-control" required>
                                </div>
                                <div class="mb-3">
                                    <label for="telephone" class="form-label">Téléphone</label>
                                    <input type="tel" id="telephone" v-model="telephone" class="form-control" required>
                                </div>
                                <div v-if="error" class="alert alert-danger">{{ error }}</div>
                                <div class="d-grid">
                                    <button type="submit" class="btn btn-primary">S'inscrire</button>
                                </div>
                            </form>
                        </div>
                        <div class="card-footer text-center">
                            <p>Déjà un compte? <a href="#" @click.prevent="$emit('show-login')">Se connecter</a></p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `,
    data() {
        return {
            nom: '',
            prenom: '',
            email: '',
            password: '',
            telephone: '',
            error: null
        };
    },
    methods: {
        async register() {
            this.error = null;
            try {
                const response = await axios.post('/api/auth/register', {
                    nom: this.nom,
                    prenom: this.prenom,
                    email: this.email,
                    password: this.password,
                    telephone: this.telephone
                });
                if (response.data.data && response.data.data.userId) {
                    this.$emit('show-login');
                }
            } catch (error) {
                this.error = error.response?.data?.message || 'Une erreur est survenue.';
            }
        }
    }
};