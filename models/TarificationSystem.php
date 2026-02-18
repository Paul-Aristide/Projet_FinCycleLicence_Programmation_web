<?php
namespace App\Models;

/**
 * Système de tarification automatique LogiswayZ
 * Calcul basé sur poids et distance
 * Exemple: 1 tonne sur 10km = 54,000 F CFA
 */
class TarificationSystem {
    
    /**
     * Tarif de base: 54,000 F CFA pour 1 tonne sur 10 km
     */
    const BASE_RATE = 54000; // F CFA
    const BASE_WEIGHT = 1000; // kg (1 tonne)
    const BASE_DISTANCE = 10; // km
    
    /**
     * Coefficients de tarification
     */
    const WEIGHT_COEFFICIENT = 1.0;    // Linéaire avec le poids
    const DISTANCE_COEFFICIENT = 1.0;  // Linéaire avec la distance
    
    /**
     * Tarifs par zone géographique (multiplicateurs)
     */
    const ZONE_MULTIPLIERS = [
        'urbain' => 1.0,        // Abidjan intra-muros
        'periurbain' => 1.2,    // Banlieue d'Abidjan
        'regional' => 1.5,      // Autres villes de Côte d'Ivoire
        'international' => 2.0   // Pays limitrophes
    ];
    
    /**
     * Tarifs par type de marchandise (multiplicateurs)
     */
    const CARGO_MULTIPLIERS = [
        'standard' => 1.0,      // Marchandises générales
        'fragile' => 1.3,       // Produits fragiles
        'dangereux' => 1.8,     // Matières dangereuses
        'refrigere' => 1.5,     // Produits réfrigérés
        'urgent' => 1.4,        // Livraison express
        'volumineux' => 1.2     // Encombrant
    ];
    
    /**
     * Frais fixes
     */
    const FRAIS_FIXES = [
        'assurance' => 2000,    // F CFA
        'manutention' => 1500,  // F CFA
        'documentation' => 500  // F CFA
    ];
    
    /**
     * Calculer le tarif principal
     */
    public static function calculateBasicRate($poids, $distance) {
        // Validation des paramètres
        if ($poids <= 0 || $distance <= 0) {
            throw new \InvalidArgumentException("Poids et distance doivent être positifs");
        }
        
        // Calcul proportionnel au tarif de base
        // Formule: (poids/base_poids) * (distance/base_distance) * tarif_base
        $weightRatio = $poids / self::BASE_WEIGHT;
        $distanceRatio = $distance / self::BASE_DISTANCE;
        
        $basicRate = $weightRatio * $distanceRatio * self::BASE_RATE;
        
        return round($basicRate);
    }
    
    /**
     * Calculer tarif complet avec tous les facteurs
     */
    public static function calculateFullRate($poids, $distance, $options = []) {
        // Tarif de base
        $basicRate = self::calculateBasicRate($poids, $distance);
        
        // Zone géographique
        $zone = $options['zone'] ?? 'urbain';
        $zoneMultiplier = self::ZONE_MULTIPLIERS[$zone] ?? 1.0;
        
        // Type de marchandise
        $cargoType = $options['cargo_type'] ?? 'standard';
        $cargoMultiplier = self::CARGO_MULTIPLIERS[$cargoType] ?? 1.0;
        
        // Calcul avec multiplicateurs
        $adjustedRate = $basicRate * $zoneMultiplier * $cargoMultiplier;
        
        // Frais fixes
        $fixedFees = array_sum(self::FRAIS_FIXES);
        
        // Remises éventuelles
        $discount = $options['discount_percent'] ?? 0;
        $discountAmount = ($adjustedRate * $discount) / 100;
        
        // Total
        $totalRate = $adjustedRate + $fixedFees - $discountAmount;
        
        return [
            'tarif_base' => round($basicRate),
            'zone_multiplier' => $zoneMultiplier,
            'cargo_multiplier' => $cargoMultiplier,
            'tarif_ajuste' => round($adjustedRate),
            'frais_fixes' => $fixedFees,
            'remise' => round($discountAmount),
            'tarif_total' => round($totalRate),
            'details' => [
                'poids' => $poids,
                'distance' => $distance,
                'zone' => $zone,
                'type_marchandise' => $cargoType,
                'remise_percent' => $discount
            ]
        ];
    }
    
    /**
     * Déterminer la zone automatiquement selon les adresses
     */
    public static function determineZone($adresseDepart, $adresseArrivee) {
        $depart = strtolower($adresseDepart);
        $arrivee = strtolower($adresseArrivee);
        
        // Villes principales de Côte d'Ivoire
        $villesAbidjan = ['abidjan', 'cocody', 'plateau', 'treichville', 'yopougon', 'adjame', 'marcory'];
        $villesBanlieue = ['grand-bassam', 'bingerville', 'anyama', 'songon'];
        $villesRegionales = ['bouake', 'yamoussoukro', 'korhogo', 'daloa', 'san-pedro', 'gagnoa', 'man'];
        
        $isDepartAbidjan = $this->containsAnyCity($depart, $villesAbidjan);
        $isArriveeAbidjan = $this->containsAnyCity($arrivee, $villesAbidjan);
        
        $isDepartBanlieue = $this->containsAnyCity($depart, $villesBanlieue);
        $isArriveeBanlieue = $this->containsAnyCity($arrivee, $villesBanlieue);
        
        $isDepartRegional = $this->containsAnyCity($depart, $villesRegionales);
        $isArriveeRegional = $this->containsAnyCity($arrivee, $villesRegionales);
        
        // Logique de détermination
        if ($isDepartAbidjan && $isArriveeAbidjan) {
            return 'urbain';
        } elseif (($isDepartAbidjan || $isArriveeAbidjan) && ($isDepartBanlieue || $isArriveeBanlieue)) {
            return 'periurbain';
        } elseif ($isDepartRegional || $isArriveeRegional) {
            return 'regional';
        } else {
            return 'regional'; // Par défaut
        }
    }
    
    /**
     * Vérifier si une adresse contient une ville
     */
    private static function containsAnyCity($address, $cities) {
        foreach ($cities as $city) {
            if (strpos($address, $city) !== false) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Calculer distance approximative entre deux villes ivoiriennes
     */
    public static function estimateDistance($adresseDepart, $adresseArrivee) {
        // Distances approximatives depuis Abidjan (en km)
        $distances = [
            'abidjan' => 0,
            'grand-bassam' => 40,
            'bingerville' => 25,
            'yamoussoukro' => 240,
            'bouake' => 350,
            'korhogo' => 635,
            'daloa' => 383,
            'san-pedro' => 340,
            'gagnoa' => 300,
            'man' => 585,
            'sassandra' => 280
        ];
        
        $depart = $this->extractMainCity(strtolower($adresseDepart));
        $arrivee = $this->extractMainCity(strtolower($adresseArrivee));
        
        $distanceDepart = $distances[$depart] ?? 0;
        $distanceArrivee = $distances[$arrivee] ?? 0;
        
        // Distance approximative
        $estimatedDistance = abs($distanceArrivee - $distanceDepart);
        
        // Minimum 5 km pour les trajets locaux
        return max($estimatedDistance, 5);
    }
    
    /**
     * Extraire la ville principale d'une adresse
     */
    private static function extractMainCity($address) {
        $cities = [
            'abidjan', 'cocody', 'plateau', 'treichville', 'yopougon', 'adjame', 'marcory',
            'grand-bassam', 'bingerville', 'yamoussoukro', 'bouake', 'korhogo', 
            'daloa', 'san-pedro', 'gagnoa', 'man', 'sassandra'
        ];
        
        foreach ($cities as $city) {
            if (strpos($address, $city) !== false) {
                return $city === 'cocody' || $city === 'plateau' || $city === 'treichville' || 
                       $city === 'yopougon' || $city === 'adjame' || $city === 'marcory' 
                       ? 'abidjan' : $city;
            }
        }
        
        return 'abidjan'; // Par défaut
    }
    
    /**
     * Générer devis détaillé
     */
    public static function generateQuote($poids, $adresseDepart, $adresseArrivee, $options = []) {
        // Estimation de la distance
        $distance = $options['distance'] ?? self::estimateDistance($adresseDepart, $adresseArrivee);
        
        // Détermination de la zone
        $zone = $options['zone'] ?? self::determineZone($adresseDepart, $adresseArrivee);
        $options['zone'] = $zone;
        
        // Calcul du tarif
        $tarification = self::calculateFullRate($poids, $distance, $options);
        
        // Informations supplémentaires
        $tarification['itineraire'] = [
            'depart' => $adresseDepart,
            'arrivee' => $adresseArrivee,
            'distance_estimee' => $distance,
            'zone' => $zone
        ];
        
        $tarification['duree_estimee'] = self::estimateDuration($distance, $zone);
        $tarification['date_devis'] = date('Y-m-d H:i:s');
        
        return $tarification;
    }
    
    /**
     * Estimer la durée du trajet
     */
    public static function estimateDuration($distance, $zone) {
        $vitesseMoyenne = [
            'urbain' => 25,      // km/h (trafic urbain)
            'periurbain' => 40,  // km/h
            'regional' => 60,    // km/h (routes nationales)
            'international' => 50 // km/h (frontières)
        ];
        
        $vitesse = $vitesseMoyenne[$zone] ?? 50;
        $dureeHeures = $distance / $vitesse;
        
        // Ajouter temps de chargement/déchargement
        $tempsManutention = 1; // heure
        
        return round($dureeHeures + $tempsManutention, 1);
    }
    
    /**
     * Valider les paramètres de tarification
     */
    public static function validateTarificationParams($poids, $adresseDepart, $adresseArrivee) {
        $errors = [];
        
        if (!$poids || $poids <= 0) {
            $errors[] = "Le poids doit être supérieur à 0";
        }
        
        if ($poids > 50000) { // 50 tonnes max
            $errors[] = "Poids maximum autorisé: 50 tonnes";
        }
        
        if (empty($adresseDepart)) {
            $errors[] = "Adresse de départ requise";
        }
        
        if (empty($adresseArrivee)) {
            $errors[] = "Adresse d'arrivée requise";
        }
        
        if ($adresseDepart === $adresseArrivee) {
            $errors[] = "Les adresses de départ et d'arrivée doivent être différentes";
        }
        
        return $errors;
    }
    
    /**
     * Obtenir grille tarifaire pour affichage
     */
    public static function getTariffGrid() {
        $grid = [];
        $weights = [100, 500, 1000, 2000, 5000, 10000]; // kg
        $distances = [10, 25, 50, 100, 200, 500]; // km
        
        foreach ($weights as $weight) {
            foreach ($distances as $distance) {
                $rate = self::calculateBasicRate($weight, $distance);
                $grid[] = [
                    'poids' => $weight,
                    'distance' => $distance,
                    'tarif' => $rate,
                    'tarif_tonne_km' => round($rate / ($weight/1000) / $distance)
                ];
            }
        }
        
        return $grid;
    }
}
?>
