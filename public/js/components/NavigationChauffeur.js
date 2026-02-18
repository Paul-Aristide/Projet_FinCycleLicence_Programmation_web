// Navigation Chauffeur Component
const NavigationChauffeurComponent = {
    template: `
    <div class="navigation-chauffeur fade-in">
        <div class="page-header dashboard-header">
            <h1>
                <i class="fas fa-location-arrow me-2"></i>
                Navigation GPS
            </h1>
            <p class="text-muted">Suivi d'itinéraire en temps réel pour le chauffeur</p>
        </div>
        <div class="row">
            <div class="col-12 mb-3">
                <div id="map" style="height: 400px; width: 100%; border-radius: 10px;"></div>
            </div>
        </div>
        <div class="row">
            <div class="col-12">
                <div class="card p-3">
                    <h5>Votre position actuelle :</h5>
                    <p v-if="currentPosition">
                        Latitude : {{ currentPosition.lat }}<br>
                        Longitude : {{ currentPosition.lng }}
                    </p>
                    <p v-else class="text-muted">Localisation en cours...</p>
                    <button class="btn btn-primary mt-2" @click="centerOnUser">Centrer sur moi</button>
                </div>
            </div>
        </div>
    </div>
    `,
    data() {
        return {
            map: null,
            marker: null,
            currentPosition: null
        }
    },
    mounted() {
        this.initMap();
        this.trackPosition();
    },
    methods: {
        initMap() {
            this.map = L.map('map').setView([5.3599517, -4.0082563], 13); // Abidjan par défaut
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '© OpenStreetMap'
            }).addTo(this.map);
        },
        trackPosition() {
            if (navigator.geolocation) {
                navigator.geolocation.watchPosition(
                    (position) => {
                        this.currentPosition = {
                            lat: position.coords.latitude,
                            lng: position.coords.longitude
                        };
                        if (!this.marker) {
                            this.marker = L.marker([this.currentPosition.lat, this.currentPosition.lng]).addTo(this.map);
                        } else {
                            this.marker.setLatLng([this.currentPosition.lat, this.currentPosition.lng]);
                        }
                        this.map.setView([this.currentPosition.lat, this.currentPosition.lng], this.map.getZoom());
                    },
                    (error) => {
                        alert('Erreur de géolocalisation : ' + error.message);
                    },
                    { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 }
                );
            } else {
                alert('La géolocalisation n\'est pas supportée par ce navigateur.');
            }
        },
        centerOnUser() {
            if (this.currentPosition) {
                this.map.setView([this.currentPosition.lat, this.currentPosition.lng], 16);
            }
        }
    }
};
