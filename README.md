# LogisWayZ – Mini-ERP de Gestion Logistique

## Description

LogisWayZ est une application web de gestion logistique destinée à la planification, au suivi et à l’optimisation des opérations de transport, de commandes, de facturation et de gestion des utilisateurs. Elle propose une interface moderne pour les administrateurs, commerciaux, comptables, chauffeurs et clients.

## Fonctionnalités principales

- **Authentification & gestion des utilisateurs** (admin, commercial, comptable, chauffeur, client)
- **Gestion des clients** (création, recherche, historique de commandes)
- **Gestion des commandes** (création, validation, rejet, suivi, tarification)
- **Gestion des véhicules** (ajout, modification, disponibilité, maintenance)
- **Gestion des trajets** (planification, suivi, statut)
- **Facturation** (création, export PDF, suivi des impayés)
- **Planification budgétaire** (prévisions, export, gestion par période)
- **Transactions financières** (enregistrement, export, statistiques)
- **Tableaux de bord** (statistiques, notifications, activités récentes)
- **Suivi client** (connexion, suivi de colis, historique)
- **API RESTful** pour toutes les entités principales

## Structure du projet

- `index.php` : point d’entrée principal, gestion du routage général
- `router.php` : routeur pour serveur PHP intégré
- `routes/api.php` : toutes les routes API REST
- `controllers/` : logique métier (un contrôleur par entité)
- `models/` : accès aux données et logique métier
- `middleware/` : gestion des permissions et de l’authentification
- `public/` : fichiers statiques (HTML, CSS, JS, images)
- `public/js/components/` : composants front-end modulaires
- `config/` : configuration générale et base de données
- `utils/` : utilitaires (auth, génération PDF, etc.)
- `vendor/` : dépendances Composer (ex: TCPDF pour PDF)

## Technologies utilisées

- **Backend** : PHP (POO, MVC simplifié)
- **Frontend** : HTML, CSS, JavaScript (composants modulaires)
- **Base de données** : MySQL (script fourni : `logistique_db.sql`)
- **PDF** : TCPDF (génération de factures)
- **Gestion des dépendances** : Composer

## Installation

1. **Cloner le dépôt**
2. **Configurer la base de données** : importer `logistique_db.sql` dans MySQL
3. **Configurer les variables d’environnement** (voir `config/DatabaseConfig.php` et `config/config.php`)
4. **Installer les dépendances** :
	```bash
	composer install
	```
5. **Lancer le serveur PHP** :
	```bash
	php -S localhost:5000 -t public router.php
	```
6. **Accéder à l’application** : [http://localhost:5000](http://localhost:5000)

## Utilisateurs de test

- **Administrateur** : admin@gmail.com / admin@gmail
- **Commercial** : commer@gmail.com / commerce@
- **Comptable** : compta@gmail.com / comptab@
- **Chauffeur** : chauff@gmail.com / chauffe@

## Contribution

1. Forker le projet
2. Créer une branche (`feature/ma-fonctionnalite`)
3. Committer vos modifications
4. Ouvrir une Pull Request

## Sécurité

- Authentification JWT
- Permissions par rôle
- Validation des entrées côté serveur

## Licence

Projet académique – Tous droits réservés.

## Auteurs

- [Ton nom ici]
- [Collaborateurs éventuels]