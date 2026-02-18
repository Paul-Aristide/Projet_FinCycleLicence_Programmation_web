-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Hôte : 127.0.0.1:3306
-- Généré le : sam. 21 juin 2025 à 10:18
-- Version du serveur : 9.1.0
-- Version de PHP : 8.3.14

DROP DATABASE IF EXISTS `logistique_db`;
CREATE DATABASE `logistique_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `logistique_db`;


SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `logistique_db`
--

DELIMITER $$
--
-- Procédures
--
DROP PROCEDURE IF EXISTS `cleanup_old_data`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `cleanup_old_data` (IN `days_to_keep` INT)  MODIFIES SQL DATA BEGIN
    DECLARE cutoff_date DATE;
    SET cutoff_date = DATE_SUB(CURDATE(), INTERVAL days_to_keep DAY);
    
    -- Archive old completed orders
    UPDATE commandes 
    SET active = 0 
    WHERE statut = 'livree' 
    AND date_creation < cutoff_date
    AND active = 1;
    
    -- Archive old completed routes
    UPDATE trajets 
    SET actif = 0 
    WHERE statut = 'termine' 
    AND date_creation < cutoff_date
    AND actif = 1;
    
    SELECT ROW_COUNT() as rows_affected;
END$$

DROP PROCEDURE IF EXISTS `generate_monthly_report`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `generate_monthly_report` (IN `year_param` INT, IN `month_param` INT)   BEGIN
    SELECT 
        COUNT(*) as total_commandes,
        SUM(CASE WHEN statut = 'livree' THEN 1 ELSE 0 END) as commandes_livrees,
        SUM(CASE WHEN statut = 'annulee' THEN 1 ELSE 0 END) as commandes_annulees,
        SUM(prix) as chiffre_affaires,
        (SELECT COUNT(*) FROM trajets WHERE YEAR(date_depart) = year_param AND MONTH(date_depart) = month_param) as total_trajets,
        (SELECT SUM(distance_km) FROM trajets WHERE YEAR(date_depart) = year_param AND MONTH(date_depart) = month_param) as km_parcourus
    FROM commandes
    WHERE YEAR(date_prevue) = year_param 
    AND MONTH(date_prevue) = month_param
    AND active = 1;
END$$

DROP PROCEDURE IF EXISTS `get_dashboard_stats`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_dashboard_stats` ()  READS SQL DATA BEGIN
    SELECT 
        (SELECT COUNT(*) FROM clients WHERE actif = 1) as total_clients,
        (SELECT COUNT(*) FROM clients WHERE actif = 1 AND MONTH(date_creation) = MONTH(NOW()) AND YEAR(date_creation) = YEAR(NOW())) as nouveaux_clients_mois,
        (SELECT COUNT(*) FROM commandes WHERE active = 1) as total_commandes,
        (SELECT COUNT(*) FROM commandes WHERE active = 1 AND statut = 'en_attente') as commandes_en_attente,
        (SELECT COUNT(*) FROM commandes WHERE active = 1 AND statut = 'en_cours') as commandes_en_cours,
        (SELECT COUNT(*) FROM commandes WHERE active = 1 AND statut = 'livree') as commandes_livrees,
        (SELECT COUNT(*) FROM vehicules WHERE actif = 1) as total_vehicules,
        (SELECT COUNT(*) FROM vehicules WHERE actif = 1 AND disponible = 1) as vehicules_disponibles,
        (SELECT COUNT(*) FROM vehicules WHERE actif = 1 AND disponible = 0) as vehicules_en_mission,
        (SELECT COUNT(*) FROM trajets WHERE actif = 1) as total_trajets,
        (SELECT COUNT(*) FROM trajets WHERE actif = 1 AND statut = 'planifie') as trajets_planifies,
        (SELECT COUNT(*) FROM trajets WHERE actif = 1 AND statut = 'en_cours') as trajets_en_cours,
        (SELECT COUNT(*) FROM factures WHERE actif = 1) as total_factures,
        (SELECT COUNT(*) FROM factures WHERE actif = 1 AND statut = 'payee') as factures_payees,
        (SELECT COUNT(*) FROM factures WHERE actif = 1 AND statut IN ('brouillon', 'envoyee') AND date_echeance < CURDATE()) as factures_en_retard,
        (SELECT COALESCE(SUM(montant_ttc), 0) FROM factures WHERE actif = 1 AND statut = 'payee' AND MONTH(date_facture) = MONTH(NOW()) AND YEAR(date_facture) = YEAR(NOW())) as ca_mois_courant;
END$$

--
-- Fonctions
--
DROP FUNCTION IF EXISTS `calculate_distance`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `calculate_distance` (`lat1` DECIMAL(10,6), `lng1` DECIMAL(10,6), `lat2` DECIMAL(10,6), `lng2` DECIMAL(10,6)) RETURNS DECIMAL(8,2) DETERMINISTIC READS SQL DATA BEGIN
    DECLARE distance DECIMAL(8,2);
    SET distance = (
        6371 * ACOS(
            COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * COS(RADIANS(lng2) - RADIANS(lng1)) +
            SIN(RADIANS(lat1)) * SIN(RADIANS(lat2))
        )
    );
    RETURN distance;
END$$

DROP FUNCTION IF EXISTS `get_next_invoice_number`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `get_next_invoice_number` (`year_param` INT, `month_param` INT) RETURNS VARCHAR(50) CHARSET utf8mb4 READS SQL DATA BEGIN
    DECLARE next_number INT DEFAULT 1;
    DECLARE prefix VARCHAR(10);
    DECLARE last_invoice VARCHAR(50);
    
    SET prefix = CONCAT('FACT', year_param, LPAD(month_param, 2, '0'));
    
    SELECT numero_facture INTO last_invoice 
    FROM factures 
    WHERE numero_facture LIKE CONCAT(prefix, '%') 
    ORDER BY id DESC 
    LIMIT 1;
    
    IF last_invoice IS NOT NULL THEN
        SET next_number = CAST(SUBSTRING(last_invoice, -4) AS UNSIGNED) + 1;
    END IF;
    
    RETURN CONCAT(prefix, LPAD(next_number, 4, '0'));
END$$

DROP FUNCTION IF EXISTS `get_next_order_number`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `get_next_order_number` (`year_param` INT, `month_param` INT) RETURNS VARCHAR(50) CHARSET utf8mb4 READS SQL DATA BEGIN
    DECLARE next_number INT DEFAULT 1;
    DECLARE prefix VARCHAR(10);
    DECLARE last_order VARCHAR(50);
    
    SET prefix = CONCAT('CMD', year_param, LPAD(month_param, 2, '0'));
    
    SELECT numero_commande INTO last_order 
    FROM commandes 
    WHERE numero_commande LIKE CONCAT(prefix, '%') 
    ORDER BY id DESC 
    LIMIT 1;
    
    IF last_order IS NOT NULL THEN
        SET next_number = CAST(SUBSTRING(last_order, -4) AS UNSIGNED) + 1;
    END IF;
    
    RETURN CONCAT(prefix, LPAD(next_number, 4, '0'));
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `clients`
--

DROP TABLE IF EXISTS `clients`;
CREATE TABLE IF NOT EXISTS `clients` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nom` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `prenom` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `entreprise` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `adresse` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ville` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `code_postal` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_nom` (`nom`),
  KEY `idx_entreprise` (`entreprise`),
  KEY `idx_actif` (`actif`)
) ENGINE=InnoDB AUTO_INCREMENT=197 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `clients`
--

INSERT INTO `clients` (`id`, `nom`, `prenom`, `entreprise`, `email`, `telephone`, `adresse`, `ville`, `code_postal`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 'Koffi1', 'Alain', 'PALMCI', 'alain.koffi1@client.ci', '0257347397', 'Rue 1, Bouaké', 'Bouaké', '4962', NULL, 1, '2024-11-30 00:00:00', NULL),
(2, 'Yao2', 'Ibrahim', NULL, 'ibrahim.yao2@client.ci', '0723519128', 'Rue 2, Bouaké', 'Bouaké', '1504', NULL, 1, '2024-11-16 00:00:00', NULL),
(3, 'Koné3', 'Emmanuel', 'BICICI', 'emmanuel.koné3@client.ci', '0320609660', 'Rue 3, Abidjan', 'Abidjan', '4868', NULL, 1, '2024-11-16 00:00:00', NULL),
(4, 'Traoré4', 'Kouadio', NULL, 'kouadio.traoré4@client.ci', '0337429352', 'Rue 4, Gagnoa', 'Gagnoa', '8284', NULL, 1, '2024-12-15 00:00:00', NULL),
(5, 'Ouattara5', 'Issiaka', 'SIFCA', 'issiaka.ouattara5@client.ci', '0533173848', 'Rue 5, Yamoussoukro', 'Yamoussoukro', '7693', NULL, 1, '2024-11-27 00:00:00', NULL),
(6, 'Bamba6', 'Moussa', 'MTN CI', 'moussa.bamba6@client.ci', '0560632282', 'Rue 6, Yamoussoukro', 'Yamoussoukro', '9462', NULL, 1, '2024-12-15 00:00:00', NULL),
(7, 'Doumbia7', 'Claude', 'SOLIBRA', 'claude.doumbia7@client.ci', '0229551107', 'Rue 7, Divo', 'Divo', '2504', NULL, 1, '2024-11-22 00:00:00', NULL),
(8, 'Coulibaly8', 'Adama', 'SGBCI', 'adama.coulibaly8@client.ci', '0389393967', 'Rue 8, Bouaké', 'Bouaké', '9769', NULL, 1, '2024-12-02 00:00:00', NULL),
(9, 'Fofana9', 'Koffi', 'SOLIBRA', 'koffi.fofana9@client.ci', '0347553483', 'Rue 9, Man', 'Man', '7525', NULL, 1, '2024-12-02 00:00:00', NULL),
(10, 'Diabaté10', 'Aminata', NULL, 'aminata.diabaté10@client.ci', '0122971148', 'Rue 10, San-Pédro', 'San-Pédro', '9008', NULL, 1, '2024-12-03 00:00:00', NULL),
(11, 'Sangaré11', 'Mariam', 'PALMCI', 'mariam.sangaré11@client.ci', '0178036762', 'Rue 11, Korhogo', 'Korhogo', '2736', NULL, 1, '2024-12-01 00:00:00', NULL),
(12, 'Cissé12', 'Michel', 'NESTLE CI', 'michel.cissé12@client.ci', '0767938501', 'Rue 12, Korhogo', 'Korhogo', '8853', NULL, 1, '2024-12-05 00:00:00', NULL),
(13, 'Konaté13', 'Bernard', 'SIFCA', 'bernard.konaté13@client.ci', '0732693084', 'Rue 13, Divo', 'Divo', '6111', NULL, 1, '2024-11-29 00:00:00', NULL),
(14, 'Diallo14', 'Lassina', 'CIE', 'lassina.diallo14@client.ci', '0115293675', 'Rue 14, Gagnoa', 'Gagnoa', '2167', NULL, 1, '2024-12-12 00:00:00', NULL),
(15, 'Camara15', 'Adama', 'PALMCI', 'adama.camara15@client.ci', '0349618443', 'Rue 15, Abidjan', 'Abidjan', '2524', NULL, 1, '2024-11-16 00:00:00', NULL),
(16, 'Keita16', 'Pierre', NULL, 'pierre.keita16@client.ci', '0299414322', 'Rue 16, Man', 'Man', '1844', NULL, 1, '2024-11-17 00:00:00', NULL),
(17, 'Sylla17', 'Michel', NULL, 'michel.sylla17@client.ci', '0114696980', 'Rue 17, Daloa', 'Daloa', '8907', NULL, 1, '2024-11-20 00:00:00', NULL),
(18, 'Barry18', 'Philippe', NULL, 'philippe.barry18@client.ci', '0589673788', 'Rue 18, Abidjan', 'Abidjan', '3815', NULL, 1, '2024-12-07 00:00:00', NULL),
(19, 'Sow19', 'Seydou', 'SOLIBRA', 'seydou.sow19@client.ci', '0349727149', 'Rue 19, Bouaké', 'Bouaké', '8222', NULL, 1, '2024-12-12 00:00:00', NULL),
(20, 'Assi20', 'Souleymane', 'SOLIBRA', 'souleymane.assi20@client.ci', '0124101256', 'Rue 20, Yamoussoukro', 'Yamoussoukro', '3916', NULL, 1, '2024-11-19 00:00:00', NULL),
(21, 'Akoto21', 'Moussa', 'SOLIBRA', 'moussa.akoto21@client.ci', '0221943408', 'Rue 21, Divo', 'Divo', '1874', NULL, 1, '2024-11-20 00:00:00', NULL),
(22, 'Adjoumani22', 'Ibrahim', 'SIFCA', 'ibrahim.adjoumani22@client.ci', '0320937900', 'Rue 22, Divo', 'Divo', '5304', NULL, 1, '2024-11-21 00:00:00', NULL),
(23, 'Ahoussou23', 'Adama', NULL, 'adama.ahoussou23@client.ci', '0212532115', 'Rue 23, Abidjan', 'Abidjan', '8343', NULL, 1, '2024-11-29 00:00:00', NULL),
(24, 'Aké24', 'Aminata', 'NESTLE CI', 'aminata.aké24@client.ci', '0563329102', 'Rue 24, San-Pédro', 'San-Pédro', '8206', NULL, 1, '2024-11-23 00:00:00', NULL),
(25, 'Amani25', 'Issiaka', NULL, 'issiaka.amani25@client.ci', '0149349025', 'Rue 25, Gagnoa', 'Gagnoa', '8603', NULL, 1, '2024-12-07 00:00:00', NULL),
(26, 'Anoh26', 'Brahima', 'Orange CI', 'brahima.anoh26@client.ci', '0219935860', 'Rue 26, Abidjan', 'Abidjan', '9717', NULL, 1, '2024-12-03 00:00:00', NULL),
(27, 'Assié27', 'Pierre', 'Orange CI', 'pierre.assié27@client.ci', '0125161221', 'Rue 27, Gagnoa', 'Gagnoa', '7725', NULL, 1, '2024-12-06 00:00:00', NULL),
(28, 'Atta28', 'Bernard', 'PALMCI', 'bernard.atta28@client.ci', '0536757593', 'Rue 28, Man', 'Man', '2887', NULL, 1, '2024-12-12 00:00:00', NULL),
(29, 'Bédié29', 'Bernard', NULL, 'bernard.bédié29@client.ci', '0315817576', 'Rue 29, Divo', 'Divo', '3316', NULL, 1, '2024-11-21 00:00:00', NULL),
(30, 'Beugré30', 'Brahima', 'SOLIBRA', 'brahima.beugré30@client.ci', '0116289145', 'Rue 30, Daloa', 'Daloa', '6513', NULL, 1, '2024-12-02 00:00:00', NULL),
(31, 'Brou31', 'Philippe', 'SGBCI', 'philippe.brou31@client.ci', '0729854239', 'Rue 31, Abidjan', 'Abidjan', '6480', NULL, 1, '2024-11-29 00:00:00', NULL),
(32, 'Dago32', 'Pierre', 'SODECI', 'pierre.dago32@client.ci', '0187653365', 'Rue 32, San-Pédro', 'San-Pédro', '6469', NULL, 1, '2024-11-22 00:00:00', NULL),
(33, 'Djédjé33', 'Koffi', 'MTN CI', 'koffi.djédjé33@client.ci', '0363101906', 'Rue 33, Gagnoa', 'Gagnoa', '2731', NULL, 1, '2024-11-24 00:00:00', NULL),
(34, 'Ehui34', 'Souleymane', 'SGBCI', 'souleymane.ehui34@client.ci', '0597789769', 'Rue 34, Daloa', 'Daloa', '2373', NULL, 1, '2024-12-05 00:00:00', NULL),
(35, 'Gnabeli35', 'Yao', NULL, 'yao.gnabeli35@client.ci', '0193173934', 'Rue 35, Divo', 'Divo', '1449', NULL, 1, '2024-11-16 00:00:00', NULL),
(36, 'Gnago36', 'Fatou', 'SOLIBRA', 'fatou.gnago36@client.ci', '0599170863', 'Rue 36, Korhogo', 'Korhogo', '5759', NULL, 1, '2024-11-30 00:00:00', NULL),
(37, 'Gnahoré37', 'Bernard', 'MTN CI', 'bernard.gnahoré37@client.ci', '0181232047', 'Rue 37, Korhogo', 'Korhogo', '5023', NULL, 1, '2024-11-20 00:00:00', NULL),
(38, 'Guéi38', 'Michel', NULL, 'michel.guéi38@client.ci', '0594529358', 'Rue 38, Daloa', 'Daloa', '2516', NULL, 1, '2024-11-29 00:00:00', NULL),
(39, 'Hien39', 'André', 'SGBCI', 'andré.hien39@client.ci', '0782603989', 'Rue 39, Korhogo', 'Korhogo', '8304', NULL, 1, '2024-12-12 00:00:00', NULL),
(40, 'Kakou40', 'Jean', 'MTN CI', 'jean.kakou40@client.ci', '0273653126', 'Rue 40, Abidjan', 'Abidjan', '6212', NULL, 1, '2024-12-06 00:00:00', NULL),
(41, 'Kanga41', 'Jean', 'SODECI', 'jean.kanga41@client.ci', '0341284860', 'Rue 41, Abidjan', 'Abidjan', '9897', NULL, 1, '2024-12-02 00:00:00', NULL),
(42, 'Kassi42', 'Mamadou', 'NESTLE CI', 'mamadou.kassi42@client.ci', '0750811937', 'Rue 42, Daloa', 'Daloa', '8651', NULL, 1, '2024-11-29 00:00:00', NULL),
(43, 'Kobenan43', 'Pierre', NULL, 'pierre.kobenan43@client.ci', '0758534692', 'Rue 43, Divo', 'Divo', '3650', NULL, 1, '2024-11-21 00:00:00', NULL),
(44, 'Konan44', 'Lassina', NULL, 'lassina.konan44@client.ci', '0265808780', 'Rue 44, Abidjan', 'Abidjan', '9040', NULL, 1, '2024-11-18 00:00:00', NULL),
(45, 'Kouadio45', 'Bakary', NULL, 'bakary.kouadio45@client.ci', '0540131804', 'Rue 45, Daloa', 'Daloa', '4721', NULL, 1, '2024-11-15 00:00:00', NULL),
(46, 'Kouamé46', 'Aminata', 'NESTLE CI', 'aminata.kouamé46@client.ci', '0172459469', 'Rue 46, Yamoussoukro', 'Yamoussoukro', '6618', NULL, 1, '2024-12-11 00:00:00', NULL),
(47, 'Kramo47', 'Philippe', 'PALMCI', 'philippe.kramo47@client.ci', '0315248336', 'Rue 47, Divo', 'Divo', '1102', NULL, 1, '2024-12-08 00:00:00', NULL),
(48, 'Lath48', 'Emmanuel', NULL, 'emmanuel.lath48@client.ci', '0346756057', 'Rue 48, Yamoussoukro', 'Yamoussoukro', '9988', NULL, 1, '2024-12-14 00:00:00', NULL),
(49, 'Loua49', 'Jean', 'PALMCI', 'jean.loua49@client.ci', '0543829917', 'Rue 49, Daloa', 'Daloa', '7969', NULL, 1, '2024-11-27 00:00:00', NULL),
(50, 'Mian50', 'Adama', 'SIFCA', 'adama.mian50@client.ci', '0764355144', 'Rue 50, Bouaké', 'Bouaké', '6795', NULL, 1, '2024-11-21 00:00:00', NULL),
(51, 'Niangoran51', 'Brahima', 'MTN CI', 'brahima.niangoran51@client.ci', '0387940010', 'Rue 51, Daloa', 'Daloa', '4301', NULL, 1, '2024-12-03 00:00:00', NULL),
(52, 'Ouégnin52', 'Koffi', NULL, 'koffi.ouégnin52@client.ci', '0728878813', 'Rue 52, Man', 'Man', '2036', NULL, 1, '2024-12-12 00:00:00', NULL),
(53, 'Séka53', 'Mamadou', 'Orange CI', 'mamadou.séka53@client.ci', '0245741546', 'Rue 53, Man', 'Man', '3226', NULL, 1, '2024-12-08 00:00:00', NULL),
(54, 'Tano54', 'Yao', 'MTN CI', 'yao.tano54@client.ci', '0121248810', 'Rue 54, San-Pédro', 'San-Pédro', '9367', NULL, 1, '2024-11-20 00:00:00', NULL),
(55, 'Téa55', 'Michel', 'NESTLE CI', 'michel.téa55@client.ci', '0122386230', 'Rue 55, Korhogo', 'Korhogo', '8488', NULL, 1, '2024-11-20 00:00:00', NULL),
(56, 'Tiémoko56', 'Souleymane', 'PALMCI', 'souleymane.tiémoko56@client.ci', '0778008995', 'Rue 56, Bouaké', 'Bouaké', '7333', NULL, 1, '2024-11-25 00:00:00', NULL),
(57, 'Toh57', 'Alain', 'SGBCI', 'alain.toh57@client.ci', '0757463780', 'Rue 57, Korhogo', 'Korhogo', '3538', NULL, 1, '2024-12-14 00:00:00', NULL),
(58, 'Yapo58', 'Yao', 'MTN CI', 'yao.yapo58@client.ci', '0796042068', 'Rue 58, Daloa', 'Daloa', '5818', NULL, 1, '2024-12-15 00:00:00', NULL),
(59, 'Yobouet59', 'Alain', 'MTN CI', 'alain.yobouet59@client.ci', '0560124333', 'Rue 59, Abidjan', 'Abidjan', '1998', NULL, 1, '2024-11-30 00:00:00', NULL),
(60, 'Zadi60', 'Kouadio', 'SGBCI', 'kouadio.zadi60@client.ci', '0297899261', 'Rue 60, Gagnoa', 'Gagnoa', '6100', NULL, 1, '2024-12-11 00:00:00', NULL),
(61, 'Zézé61', 'Philippe', 'SIFCA', 'philippe.zézé61@client.ci', '0146313938', 'Rue 61, Daloa', 'Daloa', '5166', NULL, 1, '2024-11-24 00:00:00', NULL),
(62, 'Abou62', 'Mamadou', 'NESTLE CI', 'mamadou.abou62@client.ci', '0347864777', 'Rue 62, Divo', 'Divo', '5933', NULL, 1, '2024-12-03 00:00:00', NULL),
(63, 'Adama63', 'Seydou', NULL, 'seydou.adama63@client.ci', '0310435656', 'Rue 63, San-Pédro', 'San-Pédro', '4446', NULL, 1, '2024-11-18 00:00:00', NULL),
(64, 'Adou64', 'Aminata', 'NESTLE CI', 'aminata.adou64@client.ci', '0117437338', 'Rue 64, Man', 'Man', '3404', NULL, 1, '2024-11-17 00:00:00', NULL),
(65, 'Agbré65', 'Michel', 'PALMCI', 'michel.agbré65@client.ci', '0155620486', 'Rue 65, Yamoussoukro', 'Yamoussoukro', '3849', NULL, 1, '2024-12-08 00:00:00', NULL),
(66, 'Ahizi66', 'Claude', NULL, 'claude.ahizi66@client.ci', '0718498512', 'Rue 66, Abidjan', 'Abidjan', '1284', NULL, 1, '2024-12-09 00:00:00', NULL),
(67, 'Ahoua67', 'François', 'MTN CI', 'françois.ahoua67@client.ci', '0579932785', 'Rue 67, Divo', 'Divo', '3638', NULL, 1, '2024-11-27 00:00:00', NULL),
(68, 'Alassane68', 'Jean', 'Orange CI', 'jean.alassane68@client.ci', '0292587819', 'Rue 68, San-Pédro', 'San-Pédro', '4327', NULL, 1, '2024-12-15 00:00:00', NULL),
(69, 'Amara69', 'André', NULL, 'andré.amara69@client.ci', '0591269684', 'Rue 69, Abidjan', 'Abidjan', '8433', NULL, 1, '2024-11-25 00:00:00', NULL),
(70, 'Kouassi70', 'Emmanuel', NULL, 'emmanuel.kouassi70@client.ci', '0766341244', 'Rue 70, Gagnoa', 'Gagnoa', '4884', NULL, 1, '2024-12-02 00:00:00', NULL),
(71, 'Koffi71', 'François', 'PALMCI', 'françois.koffi71@client.ci', '0155551074', 'Rue 71, Bouaké', 'Bouaké', '1687', NULL, 1, '2024-11-18 00:00:00', NULL),
(72, 'Yao72', 'Michel', 'SOLIBRA', 'michel.yao72@client.ci', '0368290568', 'Rue 72, Gagnoa', 'Gagnoa', '5533', NULL, 1, '2024-11-24 00:00:00', NULL),
(73, 'Koné73', 'Alain', 'SIFCA', 'alain.koné73@client.ci', '0244520587', 'Rue 73, Bouaké', 'Bouaké', '7572', NULL, 1, '2024-11-21 00:00:00', NULL),
(74, 'Traoré74', 'Koffi', 'CIE', 'koffi.traoré74@client.ci', '0171346720', 'Rue 74, Man', 'Man', '5345', NULL, 1, '2024-11-17 00:00:00', NULL),
(75, 'Ouattara75', 'Adama', NULL, 'adama.ouattara75@client.ci', '0326385200', 'Rue 75, Korhogo', 'Korhogo', '7599', NULL, 1, '2024-12-10 00:00:00', NULL),
(76, 'Bamba76', 'Adama', NULL, 'adama.bamba76@client.ci', '0743421484', 'Rue 76, Man', 'Man', '7065', NULL, 1, '2024-11-25 00:00:00', NULL),
(77, 'Doumbia77', 'Aminata', NULL, 'aminata.doumbia77@client.ci', '0376636390', 'Rue 77, Yamoussoukro', 'Yamoussoukro', '6499', NULL, 1, '2024-12-01 00:00:00', NULL),
(78, 'Coulibaly78', 'Marie', NULL, 'marie.coulibaly78@client.ci', '0599197179', 'Rue 78, Abidjan', 'Abidjan', '5154', NULL, 1, '2024-12-04 00:00:00', NULL),
(79, 'Fofana79', 'Ibrahim', 'SIFCA', 'ibrahim.fofana79@client.ci', '0599898386', 'Rue 79, Korhogo', 'Korhogo', '2654', NULL, 1, '2024-11-26 00:00:00', NULL),
(80, 'Diabaté80', 'Koffi', 'CIE', 'koffi.diabaté80@client.ci', '0382045024', 'Rue 80, Abidjan', 'Abidjan', '1350', NULL, 1, '2024-11-27 00:00:00', NULL),
(81, 'Sangaré81', 'Brahima', 'CIE', 'brahima.sangaré81@client.ci', '0267701493', 'Rue 81, Bouaké', 'Bouaké', '1893', NULL, 1, '2024-12-06 00:00:00', NULL),
(82, 'Cissé82', 'Michel', NULL, 'michel.cissé82@client.ci', '0159172998', 'Rue 82, Korhogo', 'Korhogo', '6129', NULL, 1, '2024-12-15 00:00:00', NULL),
(83, 'Konaté83', 'François', NULL, 'françois.konaté83@client.ci', '0350354385', 'Rue 83, Yamoussoukro', 'Yamoussoukro', '9627', NULL, 1, '2024-12-07 00:00:00', NULL),
(84, 'Diallo84', 'Adama', 'SIFCA', 'adama.diallo84@client.ci', '0174455733', 'Rue 84, Korhogo', 'Korhogo', '8943', NULL, 1, '2024-11-25 00:00:00', NULL),
(85, 'Camara85', 'André', 'CIE', 'andré.camara85@client.ci', '0759007406', 'Rue 85, Divo', 'Divo', '7179', NULL, 1, '2024-12-14 00:00:00', NULL),
(86, 'Keita86', 'Bakary', 'NESTLE CI', 'bakary.keita86@client.ci', '0750975117', 'Rue 86, Bouaké', 'Bouaké', '7116', NULL, 1, '2024-12-02 00:00:00', NULL),
(87, 'Sylla87', 'Emmanuel', 'MTN CI', 'emmanuel.sylla87@client.ci', '0727088681', 'Rue 87, Daloa', 'Daloa', '1124', NULL, 1, '2024-11-24 00:00:00', NULL),
(88, 'Barry88', 'Pierre', 'CIE', 'pierre.barry88@client.ci', '0720546339', 'Rue 88, Bouaké', 'Bouaké', '1552', NULL, 1, '2024-11-29 00:00:00', NULL),
(89, 'Sow89', 'Yao', 'Orange CI', 'yao.sow89@client.ci', '0312520126', 'Rue 89, Divo', 'Divo', '9112', NULL, 1, '2024-11-23 00:00:00', NULL),
(90, 'Assi90', 'Ibrahim', 'SGBCI', 'ibrahim.assi90@client.ci', '0341072138', 'Rue 90, Yamoussoukro', 'Yamoussoukro', '2929', NULL, 1, '2024-12-08 00:00:00', NULL),
(91, 'Akoto91', 'Issiaka', 'CIE', 'issiaka.akoto91@client.ci', '0123732485', 'Rue 91, Korhogo', 'Korhogo', '7937', NULL, 1, '2024-12-13 00:00:00', NULL),
(92, 'Adjoumani92', 'André', 'BICICI', 'andré.adjoumani92@client.ci', '0742800824', 'Rue 92, Yamoussoukro', 'Yamoussoukro', '8345', NULL, 1, '2024-11-23 00:00:00', NULL),
(93, 'Ahoussou93', 'Koffi', 'MTN CI', 'koffi.ahoussou93@client.ci', '0715332116', 'Rue 93, Abidjan', 'Abidjan', '2729', NULL, 1, '2024-12-11 00:00:00', NULL),
(94, 'Aké94', 'François', 'PALMCI', 'françois.aké94@client.ci', '0253162325', 'Rue 94, Bouaké', 'Bouaké', '4535', NULL, 1, '2024-11-27 00:00:00', NULL),
(95, 'Amani95', 'Souleymane', 'SODECI', 'souleymane.amani95@client.ci', '0134394752', 'Rue 95, Gagnoa', 'Gagnoa', '5204', NULL, 1, '2024-12-04 00:00:00', NULL),
(96, 'Anoh96', 'Aminata', NULL, 'aminata.anoh96@client.ci', '0767326556', 'Rue 96, Abidjan', 'Abidjan', '9782', NULL, 1, '2024-12-12 00:00:00', NULL),
(97, 'Assié97', 'Philippe', 'BICICI', 'philippe.assié97@client.ci', '0144615889', 'Rue 97, Bouaké', 'Bouaké', '3879', NULL, 1, '2024-11-26 00:00:00', NULL),
(98, 'Atta98', 'Michel', NULL, 'michel.atta98@client.ci', '0251323007', 'Rue 98, Gagnoa', 'Gagnoa', '3982', NULL, 1, '2024-11-26 00:00:00', NULL),
(99, 'Bédié99', 'Alain', 'SGBCI', 'alain.bédié99@client.ci', '0373839484', 'Rue 99, Daloa', 'Daloa', '9522', NULL, 1, '2024-11-23 00:00:00', NULL),
(100, 'Beugré100', 'Koffi', NULL, 'koffi.beugré100@client.ci', '0724731198', 'Rue 100, Bouaké', 'Bouaké', '2665', NULL, 1, '2024-12-08 00:00:00', NULL),
(101, 'Brou101', 'Lassina', 'NESTLE CI', 'lassina.brou101@client.ci', '0189391574', 'Rue 101, Abidjan', 'Abidjan', '6523', NULL, 1, '2024-11-17 00:00:00', NULL),
(102, 'Dago102', 'Bernard', 'SOLIBRA', 'bernard.dago102@client.ci', '0318615209', 'Rue 102, Yamoussoukro', 'Yamoussoukro', '3322', NULL, 1, '2024-12-07 00:00:00', NULL),
(103, 'Djédjé103', 'Issiaka', 'SGBCI', 'issiaka.djédjé103@client.ci', '0740432544', 'Rue 103, Daloa', 'Daloa', '4560', NULL, 1, '2024-12-02 00:00:00', NULL),
(104, 'Ehui104', 'Adama', 'SGBCI', 'adama.ehui104@client.ci', '0579172165', 'Rue 104, Abidjan', 'Abidjan', '4846', NULL, 1, '2024-12-14 00:00:00', NULL),
(105, 'Gnabeli105', 'Mariam', 'SOLIBRA', 'mariam.gnabeli105@client.ci', '0510141745', 'Rue 105, Bouaké', 'Bouaké', '4842', NULL, 1, '2024-12-07 00:00:00', NULL),
(106, 'Gnago106', 'Marie', NULL, 'marie.gnago106@client.ci', '0572110715', 'Rue 106, Daloa', 'Daloa', '3042', NULL, 1, '2024-12-03 00:00:00', NULL),
(107, 'Gnahoré107', 'Yao', NULL, 'yao.gnahoré107@client.ci', '0528222800', 'Rue 107, Divo', 'Divo', '7445', NULL, 1, '2024-12-02 00:00:00', NULL),
(108, 'Guéi108', 'Bakary', 'SOLIBRA', 'bakary.guéi108@client.ci', '0247680701', 'Rue 108, San-Pédro', 'San-Pédro', '1021', NULL, 1, '2024-12-15 00:00:00', NULL),
(109, 'Hien109', 'Emmanuel', NULL, 'emmanuel.hien109@client.ci', '0729787562', 'Rue 109, Divo', 'Divo', '1525', NULL, 1, '2024-12-04 00:00:00', NULL),
(110, 'Kakou110', 'Yao', 'BICICI', 'yao.kakou110@client.ci', '0124765261', 'Rue 110, Daloa', 'Daloa', '6976', NULL, 1, '2024-12-10 00:00:00', NULL),
(111, 'Kanga111', 'Issiaka', 'PALMCI', 'issiaka.kanga111@client.ci', '0277056481', 'Rue 111, Abidjan', 'Abidjan', '6871', NULL, 1, '2024-12-10 00:00:00', NULL),
(112, 'Kassi112', 'Moussa', 'BICICI', 'moussa.kassi112@client.ci', '0561822791', 'Rue 112, Bouaké', 'Bouaké', '1276', NULL, 1, '2024-11-16 00:00:00', NULL),
(113, 'Kobenan113', 'Kouadio', 'NESTLE CI', 'kouadio.kobenan113@client.ci', '0340059509', 'Rue 113, Man', 'Man', '7348', NULL, 1, '2024-11-15 00:00:00', NULL),
(114, 'Konan114', 'Ousmane', 'SODECI', 'ousmane.konan114@client.ci', '0518610029', 'Rue 114, Yamoussoukro', 'Yamoussoukro', '4107', NULL, 1, '2024-12-12 00:00:00', NULL),
(115, 'Kouadio115', 'Mamadou', 'BICICI', 'mamadou.kouadio115@client.ci', '0572661482', 'Rue 115, Daloa', 'Daloa', '7536', NULL, 1, '2024-12-05 00:00:00', NULL),
(116, 'Kouamé116', 'Jean', 'SGBCI', 'jean.kouamé116@client.ci', '0147105382', 'Rue 116, Daloa', 'Daloa', '5841', NULL, 1, '2024-12-11 00:00:00', NULL),
(117, 'Kramo117', 'Ibrahim', 'CIE', 'ibrahim.kramo117@client.ci', '0518982444', 'Rue 117, Man', 'Man', '4325', NULL, 1, '2024-11-15 00:00:00', NULL),
(118, 'Lath118', 'Mamadou', 'SIFCA', 'mamadou.lath118@client.ci', '0715783875', 'Rue 118, Korhogo', 'Korhogo', '7514', NULL, 1, '2024-11-21 00:00:00', NULL),
(119, 'Loua119', 'Ousmane', NULL, 'ousmane.loua119@client.ci', '0159534406', 'Rue 119, Man', 'Man', '7208', NULL, 1, '2024-12-11 00:00:00', NULL),
(120, 'Mian120', 'Issiaka', 'CIE', 'issiaka.mian120@client.ci', '0250962873', 'Rue 120, Bouaké', 'Bouaké', '9068', NULL, 1, '2024-12-05 00:00:00', NULL),
(121, 'Niangoran121', 'Lassina', NULL, 'lassina.niangoran121@client.ci', '0576367883', 'Rue 121, San-Pédro', 'San-Pédro', '6706', NULL, 1, '2024-12-02 00:00:00', NULL),
(122, 'Ouégnin122', 'Mariam', 'SOLIBRA', 'mariam.ouégnin122@client.ci', '0159281512', 'Rue 122, Divo', 'Divo', '7933', NULL, 1, '2024-12-05 00:00:00', NULL),
(123, 'Séka123', 'André', 'SGBCI', 'andré.séka123@client.ci', '0181850673', 'Rue 123, San-Pédro', 'San-Pédro', '2824', NULL, 1, '2024-12-09 00:00:00', NULL),
(124, 'Tano124', 'Kouadio', NULL, 'kouadio.tano124@client.ci', '0730731745', 'Rue 124, Korhogo', 'Korhogo', '5527', NULL, 1, '2024-11-15 00:00:00', NULL),
(125, 'Téa125', 'François', NULL, 'françois.téa125@client.ci', '0374920033', 'Rue 125, Gagnoa', 'Gagnoa', '1922', NULL, 1, '2024-11-22 00:00:00', NULL),
(126, 'Tiémoko126', 'Moussa', 'SOLIBRA', 'moussa.tiémoko126@client.ci', '0277534670', 'Rue 126, San-Pédro', 'San-Pédro', '2891', NULL, 1, '2024-12-15 00:00:00', NULL),
(127, 'Toh127', 'François', 'PALMCI', 'françois.toh127@client.ci', '0212720015', 'Rue 127, Korhogo', 'Korhogo', '5763', NULL, 1, '2024-11-21 00:00:00', NULL),
(128, 'Yapo128', 'Bakary', 'MTN CI', 'bakary.yapo128@client.ci', '0310366620', 'Rue 128, San-Pédro', 'San-Pédro', '9899', NULL, 1, '2024-11-30 00:00:00', NULL),
(129, 'Yobouet129', 'Lassina', NULL, 'lassina.yobouet129@client.ci', '0379807748', 'Rue 129, Divo', 'Divo', '3841', NULL, 1, '2024-12-02 00:00:00', NULL),
(130, 'Zadi130', 'Aminata', 'MTN CI', 'aminata.zadi130@client.ci', '0382023491', 'Rue 130, Gagnoa', 'Gagnoa', '9258', NULL, 1, '2024-12-07 00:00:00', NULL),
(131, 'Zézé131', 'André', 'Orange CI', 'andré.zézé131@client.ci', '0267646607', 'Rue 131, Korhogo', 'Korhogo', '1014', NULL, 1, '2024-12-03 00:00:00', NULL),
(132, 'Abou132', 'Brahima', NULL, 'brahima.abou132@client.ci', '0345681421', 'Rue 132, Gagnoa', 'Gagnoa', '7048', NULL, 1, '2024-12-08 00:00:00', NULL),
(133, 'Adama133', 'André', 'CIE', 'andré.adama133@client.ci', '0383528866', 'Rue 133, Yamoussoukro', 'Yamoussoukro', '7520', NULL, 1, '2024-11-30 00:00:00', NULL),
(134, 'Adou134', 'Lassina', 'CIE', 'lassina.adou134@client.ci', '0126560066', 'Rue 134, Korhogo', 'Korhogo', '1461', NULL, 1, '2024-11-23 00:00:00', NULL),
(135, 'Agbré135', 'Pierre', 'PALMCI', 'pierre.agbré135@client.ci', '0571143091', 'Rue 135, Abidjan', 'Abidjan', '7177', NULL, 1, '2024-11-22 00:00:00', NULL),
(136, 'Ahizi136', 'Mamadou', 'NESTLE CI', 'mamadou.ahizi136@client.ci', '0322961594', 'Rue 136, Daloa', 'Daloa', '1719', NULL, 1, '2024-11-30 00:00:00', NULL),
(137, 'Ahoua137', 'Brahima', 'MTN CI', 'brahima.ahoua137@client.ci', '0117606493', 'Rue 137, Divo', 'Divo', '5596', NULL, 1, '2024-12-10 00:00:00', NULL),
(138, 'Alassane138', 'Souleymane', NULL, 'souleymane.alassane138@client.ci', '0750707009', 'Rue 138, Korhogo', 'Korhogo', '5193', NULL, 1, '2024-11-16 00:00:00', NULL),
(139, 'Amara139', 'Pierre', NULL, 'pierre.amara139@client.ci', '0179129173', 'Rue 139, Abidjan', 'Abidjan', '8243', NULL, 1, '2024-11-21 00:00:00', NULL),
(140, 'Kouassi140', 'Philippe', NULL, 'philippe.kouassi140@client.ci', '0296514099', 'Rue 140, Gagnoa', 'Gagnoa', '2582', NULL, 1, '2024-11-18 00:00:00', NULL),
(141, 'Koffi141', 'Aminata', 'SIFCA', 'aminata.koffi141@client.ci', '0551257400', 'Rue 141, Abidjan', 'Abidjan', '5370', NULL, 1, '2024-11-16 00:00:00', NULL),
(142, 'Yao142', 'Adama', 'SODECI', 'adama.yao142@client.ci', '0260088574', 'Rue 142, Bouaké', 'Bouaké', '4988', NULL, 1, '2024-11-26 00:00:00', NULL),
(143, 'Koné143', 'Jean', NULL, 'jean.koné143@client.ci', '0144187563', 'Rue 143, Yamoussoukro', 'Yamoussoukro', '2466', NULL, 1, '2024-11-29 00:00:00', NULL),
(144, 'Traoré144', 'Jean', 'Orange CI', 'jean.traoré144@client.ci', '0730394420', 'Rue 144, Abidjan', 'Abidjan', '6317', NULL, 1, '2024-11-29 00:00:00', NULL),
(145, 'Ouattara145', 'Philippe', 'PALMCI', 'philippe.ouattara145@client.ci', '0573590359', 'Rue 145, Bouaké', 'Bouaké', '7495', NULL, 1, '2024-12-06 00:00:00', NULL),
(146, 'Bamba146', 'Alain', 'SODECI', 'alain.bamba146@client.ci', '0769567137', 'Rue 146, Gagnoa', 'Gagnoa', '1962', NULL, 1, '2024-11-18 00:00:00', NULL),
(147, 'Doumbia147', 'Philippe', NULL, 'philippe.doumbia147@client.ci', '0142338426', 'Rue 147, Daloa', 'Daloa', '3648', NULL, 1, '2024-11-28 00:00:00', NULL),
(148, 'Coulibaly148', 'Issiaka', 'Orange CI', 'issiaka.coulibaly148@client.ci', '0589688484', 'Rue 148, Divo', 'Divo', '2754', NULL, 1, '2024-11-19 00:00:00', NULL),
(149, 'Fofana149', 'Philippe', 'PALMCI', 'philippe.fofana149@client.ci', '0350109785', 'Rue 149, Man', 'Man', '4936', NULL, 1, '2024-12-15 00:00:00', NULL),
(150, 'Diabaté150', 'Philippe', NULL, 'philippe.diabaté150@client.ci', '0356157857', 'Rue 150, Yamoussoukro', 'Yamoussoukro', '3235', NULL, 1, '2024-11-16 00:00:00', NULL),
(151, 'Sangaré151', 'Mariam', 'Orange CI', 'mariam.sangaré151@client.ci', '0161369457', 'Rue 151, Abidjan', 'Abidjan', '1168', NULL, 1, '2024-11-17 00:00:00', NULL),
(152, 'Cissé152', 'Moussa', 'NESTLE CI', 'moussa.cissé152@client.ci', '0195286659', 'Rue 152, Divo', 'Divo', '8640', NULL, 1, '2024-11-30 00:00:00', NULL),
(153, 'Konaté153', 'Seydou', 'Orange CI', 'seydou.konaté153@client.ci', '0556732461', 'Rue 153, Divo', 'Divo', '5114', NULL, 1, '2024-11-17 00:00:00', NULL),
(154, 'Diallo154', 'Mariam', NULL, 'mariam.diallo154@client.ci', '0520368988', 'Rue 154, San-Pédro', 'San-Pédro', '8008', NULL, 1, '2024-12-03 00:00:00', NULL),
(155, 'Camara155', 'Emmanuel', 'Orange CI', 'emmanuel.camara155@client.ci', '0383532862', 'Rue 155, Abidjan', 'Abidjan', '5874', NULL, 1, '2024-11-18 00:00:00', NULL),
(156, 'Keita156', 'Claude', 'SOLIBRA', 'claude.keita156@client.ci', '0723462859', 'Rue 156, Divo', 'Divo', '6811', NULL, 1, '2024-12-11 00:00:00', NULL),
(157, 'Sylla157', 'Seydou', 'PALMCI', 'seydou.sylla157@client.ci', '0175623911', 'Rue 157, Daloa', 'Daloa', '9653', NULL, 1, '2024-11-22 00:00:00', NULL),
(158, 'Barry158', 'Issiaka', 'MTN CI', 'issiaka.barry158@client.ci', '0781565131', 'Rue 158, Bouaké', 'Bouaké', '2419', NULL, 1, '2024-12-09 00:00:00', NULL),
(159, 'Sow159', 'Pierre', 'MTN CI', 'pierre.sow159@client.ci', '0143357648', 'Rue 159, Divo', 'Divo', '9093', NULL, 1, '2024-11-30 00:00:00', NULL),
(160, 'Assi160', 'Souleymane', 'BICICI', 'souleymane.assi160@client.ci', '0262136687', 'Rue 160, Yamoussoukro', 'Yamoussoukro', '1862', NULL, 1, '2024-11-24 00:00:00', NULL),
(161, 'Akoto161', 'Jean', 'SGBCI', 'jean.akoto161@client.ci', '0518732605', 'Rue 161, Korhogo', 'Korhogo', '9859', NULL, 1, '2024-11-20 00:00:00', NULL),
(162, 'Adjoumani162', 'Marie', 'BICICI', 'marie.adjoumani162@client.ci', '0318611875', 'Rue 162, Bouaké', 'Bouaké', '7875', NULL, 1, '2024-12-06 00:00:00', NULL),
(163, 'Ahoussou163', 'François', 'CIE', 'françois.ahoussou163@client.ci', '0369928626', 'Rue 163, Korhogo', 'Korhogo', '9010', NULL, 1, '2024-12-13 00:00:00', NULL),
(164, 'Aké164', 'André', 'SIFCA', 'andré.aké164@client.ci', '0376387773', 'Rue 164, Daloa', 'Daloa', '8972', NULL, 1, '2024-11-27 00:00:00', NULL),
(165, 'Amani165', 'Mariam', 'CIE', 'mariam.amani165@client.ci', '0320199210', 'Rue 165, Korhogo', 'Korhogo', '1371', NULL, 1, '2024-12-02 00:00:00', NULL),
(166, 'Anoh166', 'Mariam', 'SGBCI', 'mariam.anoh166@client.ci', '0315444444', 'Rue 166, San-Pédro', 'San-Pédro', '3894', NULL, 1, '2024-12-13 00:00:00', NULL),
(167, 'Assié167', 'Claude', 'CIE', 'claude.assié167@client.ci', '0519966308', 'Rue 167, Yamoussoukro', 'Yamoussoukro', '9508', NULL, 1, '2024-12-01 00:00:00', NULL),
(168, 'Atta168', 'Michel', 'BICICI', 'michel.atta168@client.ci', '0327494418', 'Rue 168, Daloa', 'Daloa', '6234', NULL, 1, '2024-12-04 00:00:00', NULL),
(169, 'Bédié169', 'Ousmane', 'SODECI', 'ousmane.bédié169@client.ci', '0262870582', 'Rue 169, Divo', 'Divo', '6981', NULL, 1, '2024-12-14 00:00:00', NULL),
(170, 'Beugré170', 'Philippe', 'SGBCI', 'philippe.beugré170@client.ci', '0215727104', 'Rue 170, Daloa', 'Daloa', '5279', NULL, 1, '2024-11-18 00:00:00', NULL),
(171, 'Brou171', 'André', 'SODECI', 'andré.brou171@client.ci', '0536624374', 'Rue 171, San-Pédro', 'San-Pédro', '3036', NULL, 1, '2024-11-24 00:00:00', NULL),
(172, 'Dago172', 'Ibrahim', 'Orange CI', 'ibrahim.dago172@client.ci', '0257265797', 'Rue 172, Bouaké', 'Bouaké', '2495', NULL, 1, '2024-11-21 00:00:00', NULL),
(173, 'Djédjé173', 'Aminata', NULL, 'aminata.djédjé173@client.ci', '0324772358', 'Rue 173, Daloa', 'Daloa', '1922', NULL, 1, '2024-11-21 00:00:00', NULL),
(174, 'Ehui174', 'Bakary', NULL, 'bakary.ehui174@client.ci', '0726578304', 'Rue 174, Gagnoa', 'Gagnoa', '3970', NULL, 1, '2024-12-04 00:00:00', NULL),
(175, 'Gnabeli175', 'Moussa', 'NESTLE CI', 'moussa.gnabeli175@client.ci', '0588378276', 'Rue 175, Gagnoa', 'Gagnoa', '2106', NULL, 1, '2024-12-09 00:00:00', NULL),
(176, 'Gnago176', 'Souleymane', NULL, 'souleymane.gnago176@client.ci', '0270702201', 'Rue 176, Korhogo', 'Korhogo', '5840', NULL, 1, '2024-12-10 00:00:00', NULL),
(177, 'Gnahoré177', 'Lassina', 'SGBCI', 'lassina.gnahoré177@client.ci', '0133143939', 'Rue 177, Abidjan', 'Abidjan', '5720', NULL, 1, '2024-11-21 00:00:00', NULL),
(178, 'Guéi178', 'Brahima', 'NESTLE CI', 'brahima.guéi178@client.ci', '0792313807', 'Rue 178, Gagnoa', 'Gagnoa', '9659', NULL, 1, '2024-12-01 00:00:00', NULL),
(179, 'Hien179', 'Claude', 'SOLIBRA', 'claude.hien179@client.ci', '0151882566', 'Rue 179, San-Pédro', 'San-Pédro', '5545', NULL, 1, '2024-11-23 00:00:00', NULL),
(180, 'Kakou180', 'Claude', 'MTN CI', 'claude.kakou180@client.ci', '0230906833', 'Rue 180, Divo', 'Divo', '3615', NULL, 1, '2024-12-07 00:00:00', NULL),
(181, 'Kanga181', 'Yao', 'SGBCI', 'yao.kanga181@client.ci', '0269772691', 'Rue 181, Korhogo', 'Korhogo', '2023', NULL, 1, '2024-11-15 00:00:00', NULL),
(182, 'Kassi182', 'Pierre', 'CIE', 'pierre.kassi182@client.ci', '0398383444', 'Rue 182, Gagnoa', 'Gagnoa', '1756', NULL, 1, '2024-11-20 00:00:00', NULL),
(183, 'Kobenan183', 'Moussa', NULL, 'moussa.kobenan183@client.ci', '0789949217', 'Rue 183, Daloa', 'Daloa', '7888', NULL, 1, '2024-12-02 00:00:00', NULL),
(184, 'Konan184', 'François', 'PALMCI', 'françois.konan184@client.ci', '0153862338', 'Rue 184, Korhogo', 'Korhogo', '2303', NULL, 1, '2024-11-22 00:00:00', NULL),
(185, 'Kouadio185', 'Marie', 'BICICI', 'marie.kouadio185@client.ci', '0142658821', 'Rue 185, Yamoussoukro', 'Yamoussoukro', '6535', NULL, 1, '2024-12-01 00:00:00', NULL),
(186, 'Kouamé186', 'Adama', 'Orange CI', 'adama.kouamé186@client.ci', '0131499330', 'Rue 186, Gagnoa', 'Gagnoa', '7678', NULL, 1, '2024-12-03 00:00:00', NULL),
(187, 'Kramo187', 'Moussa', NULL, 'moussa.kramo187@client.ci', '0138790353', 'Rue 187, Man', 'Man', '5066', NULL, 1, '2024-12-11 00:00:00', NULL),
(188, 'Lath188', 'Bakary', NULL, 'bakary.lath188@client.ci', '0128671795', 'Rue 188, Daloa', 'Daloa', '7116', NULL, 1, '2024-11-27 00:00:00', NULL),
(189, 'Loua189', 'François', NULL, 'françois.loua189@client.ci', '0572695755', 'Rue 189, Yamoussoukro', 'Yamoussoukro', '6232', NULL, 1, '2024-12-01 00:00:00', NULL),
(190, 'Mian190', 'Mamadou', 'CIE', 'mamadou.mian190@client.ci', '0740200256', 'Rue 190, San-Pédro', 'San-Pédro', '6090', NULL, 1, '2024-11-26 00:00:00', NULL),
(191, 'Niangoran191', 'Jean', 'PALMCI', 'jean.niangoran191@client.ci', '0298430341', 'Rue 191, Man', 'Man', '8342', NULL, 1, '2024-12-06 00:00:00', NULL),
(192, 'Ouégnin192', 'Fatou', 'PALMCI', 'fatou.ouégnin192@client.ci', '0124333959', 'Rue 192, Divo', 'Divo', '2360', NULL, 1, '2024-12-05 00:00:00', NULL),
(193, 'Séka193', 'Adama', NULL, 'adama.séka193@client.ci', '0221965713', 'Rue 193, Yamoussoukro', 'Yamoussoukro', '6505', NULL, 1, '2024-12-02 00:00:00', NULL),
(194, 'Tano194', 'Seydou', NULL, 'seydou.tano194@client.ci', '0577458549', 'Rue 194, Yamoussoukro', 'Yamoussoukro', '5777', NULL, 1, '2024-12-08 00:00:00', NULL),
(195, 'Téa195', 'Alain', 'Orange CI', 'alain.téa195@client.ci', '0783667478', 'Rue 195, Yamoussoukro', 'Yamoussoukro', '7700', NULL, 1, '2024-12-04 00:00:00', NULL),
(196, 'Tiémoko196', 'Jean', 'SODECI', 'jean.tiémoko196@client.ci', '0749525171', 'Rue 196, Divo', 'Divo', '3704', NULL, 1, '2024-11-21 00:00:00', NULL);

-- --------------------------------------------------------

--
-- Structure de la table `commandes`
--

DROP TABLE IF EXISTS `commandes`;
CREATE TABLE IF NOT EXISTS `commandes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `numero_commande` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `client_id` int NOT NULL,
  `adresse_depart` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `adresse_arrivee` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_prevue` date NOT NULL,
  `heure_prevue` time DEFAULT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `poids` decimal(8,2) DEFAULT '0.00',
  `volume` decimal(8,2) DEFAULT '0.00',
  `prix` decimal(10,2) DEFAULT '0.00',
  `statut` enum('en_attente','confirmee','en_cours','livree','annulee') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'en_attente',
  `workflow_state` enum('created','validated','rejected','planned','in_transit','delivered','cancelled') COLLATE utf8mb4_unicode_ci DEFAULT 'created',
  `validated_by` int DEFAULT NULL,
  `validated_at` timestamp NULL DEFAULT NULL,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `tarif_auto` decimal(10,2) DEFAULT NULL,
  `poids_kg` decimal(10,2) DEFAULT NULL,
  `distance_km` decimal(10,2) DEFAULT NULL,
  `zone_tarif` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cargo_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'standard',
  `urgence` enum('normal','urgent','tres_urgent') COLLATE utf8mb4_unicode_ci DEFAULT 'normal',
  `priorite` tinyint DEFAULT '5',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `numero_commande` (`numero_commande`),
  KEY `fk_commandes_client` (`client_id`),
  KEY `idx_statut` (`statut`),
  KEY `idx_date_prevue` (`date_prevue`),
  KEY `idx_active` (`active`),
  KEY `idx_commandes_client_statut` (`client_id`,`statut`),
  KEY `idx_commandes_date_statut` (`date_prevue`,`statut`),
  KEY `idx_commandes_statut_date` (`statut`,`date_prevue`),
  KEY `idx_commandes_workflow_state` (`workflow_state`),
  KEY `idx_commandes_validated_by` (`validated_by`),
  KEY `idx_commandes_tarif_auto` (`tarif_auto`),
  KEY `idx_commandes_zone_tarif` (`zone_tarif`)
) ;

--
-- Déchargement des données de la table `commandes`
--

INSERT INTO `commandes` (`id`, `numero_commande`, `client_id`, `adresse_depart`, `adresse_arrivee`, `date_prevue`, `heure_prevue`, `description`, `poids`, `volume`, `prix`, `statut`, `workflow_state`, `validated_by`, `validated_at`, `rejection_reason`, `tarif_auto`, `poids_kg`, `distance_km`, `zone_tarif`, `cargo_type`, `urgence`, `priorite`, `notes`, `active`, `date_creation`, `date_modification`) VALUES
(1, 'CMD2025060001', 134, 'Centre-ville de Man', 'Gare Routière de Bouaké', '2025-05-03', '12:47:00', 'Produits cosmétiques', 108.40, 33.10, 49306.86, 'livree', 'created', NULL, NULL, NULL, 71960.30, 108.40, 43.00, 'regional', 'dangereux', 'normal', 4, NULL, 1, '2025-05-02 00:00:00', NULL),
(2, 'CMD2025060002', 149, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-05-10', '13:28:00', 'Produits pharmaceutiques', 215.18, 11.90, 233605.67, 'livree', 'created', NULL, NULL, NULL, 233605.66, 215.18, 152.00, 'urbain', 'fragile', 'tres_urgent', 4, NULL, 1, '2025-05-09 00:00:00', NULL),
(3, 'CMD2025060003', 152, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2024-12-18', '08:50:00', 'Textiles et vêtements', 109.36, 43.80, 182580.51, 'livree', 'created', NULL, NULL, NULL, 182580.50, 109.36, 168.00, 'urbain', 'dangereux', 'urgent', 5, NULL, 1, '2024-12-17 00:00:00', NULL),
(4, 'CMD2025060004', 128, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-03-20', '17:51:00', 'Textiles et vêtements', 126.29, 33.50, 29232.74, 'livree', 'created', NULL, NULL, NULL, 34279.29, 126.29, 37.00, 'periurbain', 'standard', 'tres_urgent', 9, NULL, 1, '2025-03-15 00:00:00', NULL),
(5, 'CMD2025060005', 116, 'Zone Industrielle de Yamoussoukro', 'Gare Routière de Bouaké', '2025-05-30', '17:04:00', 'Produits cosmétiques', 26.55, 15.60, 43785.18, 'livree', 'created', NULL, NULL, NULL, 51742.21, 26.55, 185.00, 'periurbain', 'refrigere', 'tres_urgent', 8, NULL, 1, '2025-05-25 00:00:00', NULL),
(6, 'CMD2025060006', 144, 'Gare Routière de Bouaké', 'Marché de Cocody, Abidjan', '2025-01-10', '15:24:00', 'Équipements électroniques', 134.08, 11.80, 385130.44, 'livree', 'created', NULL, NULL, NULL, 385130.44, 134.08, 376.00, 'urbain', 'urgent', 'urgent', 5, NULL, 1, '2025-01-05 00:00:00', NULL),
(7, 'CMD2025060007', 133, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-03-22', '09:30:00', 'Produits alimentaires', 184.22, 47.40, 254686.58, 'livree', 'created', NULL, NULL, NULL, 380029.86, 184.22, 210.00, 'regional', 'volumineux', 'normal', 5, NULL, 1, '2025-03-16 00:00:00', NULL),
(8, 'CMD2025060008', 60, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-02-16', '18:13:00', 'Pièces automobiles', 16.01, 10.70, 52967.55, 'livree', 'created', NULL, NULL, NULL, 52967.55, 16.01, 472.00, 'urbain', 'volumineux', 'tres_urgent', 7, NULL, 1, '2025-02-09 00:00:00', NULL),
(9, 'CMD2025060009', 154, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2024-12-06', '13:18:00', 'Mobilier et décoration', 116.03, 46.40, 219036.08, 'livree', 'created', NULL, NULL, NULL, 219036.08, 116.03, 286.00, 'urbain', 'volumineux', 'normal', 7, NULL, 1, '2024-12-02 00:00:00', NULL),
(10, 'CMD2025060010', 2, 'Marché de Korhogo', 'Port de San-Pédro', '2024-11-24', '12:28:00', 'Matériaux de construction', 118.20, 28.70, 38467.12, 'livree', 'created', NULL, NULL, NULL, 45360.54, 118.20, 45.00, 'periurbain', 'volumineux', 'urgent', 4, NULL, 1, '2024-11-18 00:00:00', NULL),
(11, 'CMD2025060011', 177, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2024-11-24', '11:37:00', 'Matériaux de construction', 72.22, 3.70, 128250.18, 'livree', 'created', NULL, NULL, NULL, 153100.23, 72.22, 177.00, 'periurbain', 'dangereux', 'tres_urgent', 7, NULL, 1, '2024-11-22 00:00:00', NULL),
(12, 'CMD2025060012', 82, 'Marché de Korhogo', 'Centre Commercial Playce, Marcory', '2025-02-23', '18:44:00', 'Équipements électroniques', 172.41, 17.90, 357040.51, 'livree', 'created', NULL, NULL, NULL, 357040.50, 172.41, 316.00, 'urbain', 'volumineux', 'normal', 8, NULL, 1, '2025-02-19 00:00:00', NULL),
(13, 'CMD2025060013', 10, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-04-17', '10:43:00', 'Équipements électroniques', 137.63, 42.20, 11803.62, 'livree', 'created', NULL, NULL, NULL, 15705.43, 137.63, 7.00, 'regional', 'refrigere', 'normal', 4, NULL, 1, '2025-04-10 00:00:00', NULL),
(14, 'CMD2025060014', 90, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-01-25', '17:09:00', 'Matériaux de construction', 63.15, 18.90, 16412.76, 'livree', 'created', NULL, NULL, NULL, 18895.31, 63.15, 26.00, 'periurbain', 'urgent', 'normal', 10, NULL, 1, '2025-01-20 00:00:00', NULL),
(15, 'CMD2025060015', 81, 'Gare Routière de Bouaké', 'Port de San-Pédro', '2025-05-15', '16:29:00', 'Mobilier et décoration', 10.92, 0.20, 56174.89, 'livree', 'created', NULL, NULL, NULL, 56174.89, 10.92, 632.00, 'urbain', 'urgent', 'tres_urgent', 4, NULL, 1, '2025-05-09 00:00:00', NULL),
(16, 'CMD2025060016', 59, 'Zone Industrielle Yopougon, Abidjan', 'Zone Industrielle de Yamoussoukro', '2025-05-29', '13:42:00', 'Équipements électroniques', 212.01, 40.70, 397600.81, 'livree', 'created', NULL, NULL, NULL, 397600.80, 212.01, 191.00, 'urbain', 'dangereux', 'urgent', 6, NULL, 1, '2025-05-23 00:00:00', NULL),
(17, 'CMD2025060017', 36, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2025-02-22', '15:25:00', 'Textiles et vêtements', 92.58, 27.20, 466537.09, 'livree', 'created', NULL, NULL, NULL, 697805.64, 92.58, 514.00, 'regional', 'dangereux', 'tres_urgent', 3, NULL, 1, '2025-02-20 00:00:00', NULL),
(18, 'CMD2025060018', 151, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-01-05', '14:32:00', 'Produits pharmaceutiques', 147.60, 1.00, 588389.73, 'livree', 'created', NULL, NULL, NULL, 705267.68, 147.60, 611.00, 'periurbain', 'volumineux', 'urgent', 8, NULL, 1, '2025-01-03 00:00:00', NULL),
(19, 'CMD2025060019', 98, 'Zone Industrielle Yopougon, Abidjan', 'Gare Routière de Bouaké', '2025-03-09', '08:03:00', 'Matériel informatique', 195.57, 24.50, 708404.03, 'livree', 'created', NULL, NULL, NULL, 849284.84, 195.57, 667.00, 'periurbain', 'standard', 'normal', 1, NULL, 1, '2025-03-04 00:00:00', NULL),
(20, 'CMD2025060020', 76, 'Centre-ville de Man', 'Port de San-Pédro', '2025-02-23', '17:31:00', 'Pièces automobiles', 242.08, 26.30, 908081.65, 'livree', 'created', NULL, NULL, NULL, 1360122.47, 242.08, 532.00, 'regional', 'fragile', 'normal', 8, NULL, 1, '2025-02-21 00:00:00', NULL),
(21, 'CMD2025060021', 35, 'Centre Commercial Playce, Marcory', 'Centre-ville de Man', '2025-01-31', '14:41:00', 'Produits alimentaires', 97.55, 5.40, 101979.22, 'livree', 'created', NULL, NULL, NULL, 121575.06, 97.55, 186.00, 'periurbain', 'standard', 'normal', 2, NULL, 1, '2025-01-25 00:00:00', NULL),
(22, 'CMD2025060022', 32, 'Zone Industrielle Yopougon, Abidjan', 'Marché Central de Daloa', '2025-03-30', '10:23:00', 'Pièces automobiles', 111.32, 26.30, 543211.82, 'livree', 'created', NULL, NULL, NULL, 543211.82, 111.32, 690.00, 'urbain', 'fragile', 'tres_urgent', 9, NULL, 1, '2025-03-23 00:00:00', NULL),
(23, 'CMD2025060023', 37, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-02-03', '16:14:00', 'Mobilier et décoration', 16.97, 3.90, 13072.16, 'livree', 'created', NULL, NULL, NULL, 17608.24, 16.97, 99.00, 'regional', 'standard', 'urgent', 2, NULL, 1, '2025-02-01 00:00:00', NULL),
(24, 'CMD2025060024', 78, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-04-24', '16:17:00', 'Textiles et vêtements', 247.02, 20.00, 465265.39, 'livree', 'created', NULL, NULL, NULL, 557518.47, 247.02, 266.00, 'periurbain', 'fragile', 'tres_urgent', 3, NULL, 1, '2025-04-20 00:00:00', NULL),
(25, 'CMD2025060025', 191, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2024-12-04', '14:19:00', 'Produits pharmaceutiques', 76.20, 44.40, 463952.34, 'livree', 'created', NULL, NULL, NULL, 555942.82, 76.20, 621.00, 'periurbain', 'dangereux', 'tres_urgent', 3, NULL, 1, '2024-12-03 00:00:00', NULL),
(26, 'CMD2025060026', 83, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2025-02-03', '13:07:00', 'Textiles et vêtements', 2.68, 26.30, 11945.13, 'livree', 'created', NULL, NULL, NULL, 13534.15, 2.68, 366.00, 'periurbain', 'refrigere', 'urgent', 10, NULL, 1, '2025-01-27 00:00:00', NULL),
(27, 'CMD2025060027', 7, 'Marché de Cocody, Abidjan', 'Centre-ville de Man', '2024-12-27', '11:42:00', 'Mobilier et décoration', 168.22, 35.20, 660219.49, 'livree', 'created', NULL, NULL, NULL, 988329.25, 168.22, 516.00, 'regional', 'urgent', 'tres_urgent', 5, NULL, 1, '2024-12-21 00:00:00', NULL),
(28, 'CMD2025060028', 122, 'Marché Central de Daloa', 'Gare Routière de Bouaké', '2025-03-10', '09:51:00', 'Mobilier et décoration', 207.58, 50.00, 755921.19, 'livree', 'created', NULL, NULL, NULL, 906305.42, 207.58, 516.00, 'periurbain', 'fragile', 'urgent', 4, NULL, 1, '2025-03-08 00:00:00', NULL),
(29, 'CMD2025060029', 109, 'Zone Industrielle Yopougon, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-04-21', '16:36:00', 'Mobilier et décoration', 11.58, 17.60, 14317.78, 'livree', 'created', NULL, NULL, NULL, 16381.33, 11.58, 110.00, 'periurbain', 'refrigere', 'urgent', 9, NULL, 1, '2025-04-16 00:00:00', NULL),
(30, 'CMD2025060030', 47, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-04-03', '18:15:00', 'Matériel informatique', 64.45, 42.90, 245811.24, 'livree', 'created', NULL, NULL, NULL, 366716.87, 64.45, 579.00, 'regional', 'volumineux', 'tres_urgent', 3, NULL, 1, '2025-03-28 00:00:00', NULL),
(31, 'CMD2025060031', 125, 'Centre-ville de Man', 'Port de San-Pédro', '2025-01-25', '10:36:00', 'Matériaux de construction', 13.64, 11.30, 33079.39, 'livree', 'created', NULL, NULL, NULL, 47619.08, 13.64, 329.00, 'regional', 'volumineux', 'urgent', 6, NULL, 1, '2025-01-20 00:00:00', NULL),
(32, 'CMD2025060032', 31, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2025-03-17', '18:37:00', 'Produits pharmaceutiques', 181.68, 24.60, 525537.88, 'livree', 'created', NULL, NULL, NULL, 525537.88, 181.68, 443.00, 'urbain', 'volumineux', 'urgent', 3, NULL, 1, '2025-03-16 00:00:00', NULL),
(33, 'CMD2025060033', 33, 'Centre-ville de Man', 'Marché de Korhogo', '2025-03-13', '15:10:00', 'Pièces automobiles', 127.11, 12.40, 260574.08, 'livree', 'created', NULL, NULL, NULL, 388861.12, 127.11, 267.00, 'regional', 'urgent', 'urgent', 6, NULL, 1, '2025-03-07 00:00:00', NULL),
(34, 'CMD2025060034', 124, 'Gare Routière de Bouaké', 'Marché de Cocody, Abidjan', '2025-04-22', '17:58:00', 'Matériaux de construction', 32.77, 7.10, 69792.98, 'livree', 'created', NULL, NULL, NULL, 69792.99, 32.77, 286.00, 'urbain', 'fragile', 'normal', 5, NULL, 1, '2025-04-15 00:00:00', NULL),
(35, 'CMD2025060035', 193, 'Gare Routière de Bouaké', 'Port Autonome d\'Abidjan, Treichville', '2025-05-05', '17:23:00', 'Textiles et vêtements', 138.44, 19.00, 351921.87, 'livree', 'created', NULL, NULL, NULL, 525882.82, 138.44, 358.00, 'regional', 'fragile', 'normal', 2, NULL, 1, '2025-05-02 00:00:00', NULL),
(36, 'CMD2025060036', 21, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2024-11-24', '13:13:00', 'Produits cosmétiques', 18.88, 47.40, 22290.19, 'livree', 'created', NULL, NULL, NULL, 31435.29, 18.88, 138.00, 'regional', 'fragile', 'urgent', 10, NULL, 1, '2024-11-17 00:00:00', NULL),
(37, 'CMD2025060037', 127, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-05-11', '15:14:00', 'Matériaux de construction', 72.33, 31.80, 278969.73, 'livree', 'created', NULL, NULL, NULL, 416454.60, 72.33, 704.00, 'regional', 'standard', 'normal', 5, NULL, 1, '2025-05-08 00:00:00', NULL),
(38, 'CMD2025060038', 52, 'Centre-ville de Man', 'Zone Industrielle de Yamoussoukro', '2025-01-15', '12:27:00', 'Produits pharmaceutiques', 196.10, 34.30, 657895.45, 'livree', 'created', NULL, NULL, NULL, 657895.45, 196.10, 475.00, 'urbain', 'fragile', 'normal', 1, NULL, 1, '2025-01-11 00:00:00', NULL),
(39, 'CMD2025060039', 87, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2025-01-17', '11:55:00', 'Pièces automobiles', 94.54, 49.90, 381679.74, 'livree', 'created', NULL, NULL, NULL, 381679.74, 94.54, 411.00, 'urbain', 'dangereux', 'urgent', 2, NULL, 1, '2025-01-11 00:00:00', NULL),
(40, 'CMD2025060040', 194, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2025-05-17', '09:24:00', 'Produits cosmétiques', 242.80, 29.00, 371769.16, 'livree', 'created', NULL, NULL, NULL, 371769.16, 242.80, 187.00, 'urbain', 'refrigere', 'urgent', 3, NULL, 1, '2025-05-13 00:00:00', NULL),
(41, 'CMD2025060041', 150, 'Marché de Korhogo', 'Marché Central de Daloa', '2025-03-19', '09:26:00', 'Produits cosmétiques', 169.04, 22.70, 304681.59, 'livree', 'created', NULL, NULL, NULL, 304681.59, 169.04, 183.00, 'urbain', 'dangereux', 'urgent', 3, NULL, 1, '2025-03-15 00:00:00', NULL),
(42, 'CMD2025060042', 88, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-02-11', '13:55:00', 'Pièces automobiles', 40.64, 9.80, 45872.20, 'livree', 'created', NULL, NULL, NULL, 66808.30, 40.64, 159.00, 'regional', 'volumineux', 'urgent', 5, NULL, 1, '2025-02-10 00:00:00', NULL),
(43, 'CMD2025060043', 184, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2024-11-23', '09:16:00', 'Textiles et vêtements', 185.59, 41.60, 405375.49, 'livree', 'created', NULL, NULL, NULL, 606063.24, 185.59, 267.00, 'regional', 'refrigere', 'normal', 10, NULL, 1, '2024-11-16 00:00:00', NULL),
(44, 'CMD2025060044', 41, 'Marché de Cocody, Abidjan', 'Port de San-Pédro', '2025-01-25', '17:10:00', 'Matériel informatique', 90.72, 41.20, 364949.48, 'livree', 'created', NULL, NULL, NULL, 545424.22, 90.72, 614.00, 'regional', 'volumineux', 'tres_urgent', 4, NULL, 1, '2025-01-23 00:00:00', NULL),
(45, 'CMD2025060045', 22, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-01-30', '12:26:00', 'Textiles et vêtements', 201.26, 35.20, 328954.40, 'livree', 'created', NULL, NULL, NULL, 328954.40, 201.26, 299.00, 'urbain', 'standard', 'urgent', 4, NULL, 1, '2025-01-29 00:00:00', NULL),
(46, 'CMD2025060046', 145, 'Port Autonome d\'Abidjan, Treichville', 'Marché Central de Daloa', '2025-02-21', '15:47:00', 'Matériel informatique', 182.52, 24.50, 549238.35, 'livree', 'created', NULL, NULL, NULL, 549238.35, 182.52, 461.00, 'urbain', 'volumineux', 'normal', 9, NULL, 1, '2025-02-14 00:00:00', NULL),
(47, 'CMD2025060047', 146, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2025-02-26', '13:08:00', 'Textiles et vêtements', 248.33, 12.60, 139975.57, 'livree', 'created', NULL, NULL, NULL, 167170.70, 248.33, 78.00, 'periurbain', 'fragile', 'normal', 7, NULL, 1, '2025-02-20 00:00:00', NULL),
(48, 'CMD2025060048', 26, 'Centre-ville de Man', 'Centre Commercial Playce, Marcory', '2025-02-01', '10:42:00', 'Équipements électroniques', 80.86, 27.10, 121457.24, 'livree', 'created', NULL, NULL, NULL, 180185.86, 80.86, 269.00, 'regional', 'standard', 'normal', 7, NULL, 1, '2025-01-28 00:00:00', NULL),
(49, 'CMD2025060049', 164, 'Centre-ville de Man', 'Port de San-Pédro', '2024-12-08', '16:19:00', 'Pièces automobiles', 31.89, 28.10, 124268.67, 'livree', 'created', NULL, NULL, NULL, 184403.02, 31.89, 388.00, 'regional', 'dangereux', 'tres_urgent', 5, NULL, 1, '2024-12-03 00:00:00', NULL),
(50, 'CMD2025060050', 156, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-03-02', '13:44:00', 'Pièces automobiles', 180.88, 29.80, 447933.78, 'livree', 'created', NULL, NULL, NULL, 536720.55, 180.88, 303.00, 'periurbain', 'refrigere', 'normal', 1, NULL, 1, '2025-02-27 00:00:00', NULL),
(51, 'CMD2025060051', 40, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-01-03', '15:03:00', 'Mobilier et décoration', 223.93, 17.60, 296389.88, 'livree', 'created', NULL, NULL, NULL, 354867.86, 223.93, 186.00, 'periurbain', 'fragile', 'urgent', 2, NULL, 1, '2025-01-01 00:00:00', NULL),
(52, 'CMD2025060052', 160, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2025-04-08', '09:13:00', 'Équipements électroniques', 159.75, 38.20, 435756.33, 'livree', 'created', NULL, NULL, NULL, 435756.33, 159.75, 385.00, 'urbain', 'fragile', 'normal', 7, NULL, 1, '2025-04-05 00:00:00', NULL),
(53, 'CMD2025060053', 86, 'Zone Industrielle Yopougon, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-02-18', '14:33:00', 'Matériel informatique', 84.89, 35.50, 231186.01, 'livree', 'created', NULL, NULL, NULL, 276623.22, 84.89, 413.00, 'periurbain', 'volumineux', 'normal', 10, NULL, 1, '2025-02-12 00:00:00', NULL),
(54, 'CMD2025060054', 114, 'Port de San-Pédro', 'Marché de Cocody, Abidjan', '2025-05-18', '15:56:00', 'Produits alimentaires', 42.92, 3.20, 183805.61, 'livree', 'created', NULL, NULL, NULL, 183805.62, 42.92, 431.00, 'urbain', 'dangereux', 'tres_urgent', 10, NULL, 1, '2025-05-12 00:00:00', NULL),
(55, 'CMD2025060055', 141, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2025-04-05', '14:52:00', 'Équipements électroniques', 174.99, 14.50, 250630.91, 'livree', 'created', NULL, NULL, NULL, 250630.91, 174.99, 261.00, 'urbain', 'standard', 'tres_urgent', 3, NULL, 1, '2025-04-03 00:00:00', NULL),
(56, 'CMD2025060056', 182, 'Centre Commercial Playce, Marcory', 'Zone Industrielle Yopougon, Abidjan', '2025-03-25', '13:19:00', 'Matériaux de construction', 145.89, 20.80, 386007.13, 'livree', 'created', NULL, NULL, NULL, 386007.13, 145.89, 373.00, 'urbain', 'fragile', 'normal', 3, NULL, 1, '2025-03-24 00:00:00', NULL),
(57, 'CMD2025060057', 65, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-02-11', '12:13:00', 'Matériaux de construction', 68.96, 16.90, 11373.20, 'livree', 'created', NULL, NULL, NULL, 12847.83, 68.96, 11.00, 'periurbain', 'dangereux', 'normal', 6, NULL, 1, '2025-02-05 00:00:00', NULL),
(58, 'CMD2025060058', 53, 'Marché Central de Daloa', 'Zone Industrielle de Yamoussoukro', '2025-04-15', '11:44:00', 'Pièces automobiles', 93.34, 38.10, 526886.95, 'livree', 'created', NULL, NULL, NULL, 788330.43, 93.34, 798.00, 'regional', 'fragile', 'normal', 9, NULL, 1, '2025-04-11 00:00:00', NULL),
(59, 'CMD2025060059', 73, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2024-12-19', '15:59:00', 'Mobilier et décoration', 2.57, 37.90, 12393.41, 'livree', 'created', NULL, NULL, NULL, 14072.09, 2.57, 504.00, 'periurbain', 'volumineux', 'urgent', 10, NULL, 1, '2024-12-15 00:00:00', NULL),
(60, 'CMD2025060060', 166, 'Marché de Korhogo', 'Zone Industrielle de Yamoussoukro', '2025-05-25', '14:38:00', 'Produits alimentaires', 60.76, 24.30, 190625.56, 'livree', 'created', NULL, NULL, NULL, 190625.55, 60.76, 316.00, 'urbain', 'dangereux', 'urgent', 4, NULL, 1, '2025-05-22 00:00:00', NULL),
(61, 'CMD2025060061', 16, 'Zone Industrielle Yopougon, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2024-12-26', '08:36:00', 'Mobilier et décoration', 47.36, 41.20, 68754.38, 'livree', 'created', NULL, NULL, NULL, 101131.56, 47.36, 211.00, 'regional', 'volumineux', 'urgent', 8, NULL, 1, '2024-12-19 00:00:00', NULL),
(62, 'CMD2025060062', 5, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-03-11', '18:52:00', 'Matériaux de construction', 78.84, 12.30, 507475.39, 'livree', 'created', NULL, NULL, NULL, 507475.39, 78.84, 657.00, 'urbain', 'dangereux', 'tres_urgent', 9, NULL, 1, '2025-03-10 00:00:00', NULL),
(63, 'CMD2025060063', 189, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-01-17', '15:41:00', 'Produits pharmaceutiques', 149.84, 30.00, 668138.83, 'livree', 'created', NULL, NULL, NULL, 800966.58, 149.84, 684.00, 'periurbain', 'volumineux', 'tres_urgent', 1, NULL, 1, '2025-01-11 00:00:00', NULL),
(64, 'CMD2025060064', 75, 'Port de San-Pédro', 'Marché de Cocody, Abidjan', '2025-04-14', '15:52:00', 'Produits pharmaceutiques', 167.72, 33.50, 894110.17, 'livree', 'created', NULL, NULL, NULL, 1339165.26, 167.72, 546.00, 'regional', 'dangereux', 'normal', 4, NULL, 1, '2025-04-09 00:00:00', NULL),
(65, 'CMD2025060065', 108, 'Gare Routière de Bouaké', 'Marché de Cocody, Abidjan', '2025-02-05', '10:26:00', 'Équipements électroniques', 185.31, 26.90, 723284.47, 'livree', 'created', NULL, NULL, NULL, 723284.48, 185.31, 599.00, 'urbain', 'volumineux', 'urgent', 5, NULL, 1, '2025-02-01 00:00:00', NULL),
(66, 'CMD2025060066', 43, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-03-16', '16:54:00', 'Produits alimentaires', 98.32, 40.10, 369809.39, 'livree', 'created', NULL, NULL, NULL, 552714.09, 98.32, 689.00, 'regional', 'standard', 'urgent', 7, NULL, 1, '2025-03-14 00:00:00', NULL),
(67, 'CMD2025060067', 126, 'Marché de Korhogo', 'Centre-ville de Man', '2025-01-25', '12:18:00', 'Mobilier et décoration', 186.99, 42.50, 925494.20, 'livree', 'created', NULL, NULL, NULL, 925494.20, 186.99, 702.00, 'urbain', 'fragile', 'urgent', 6, NULL, 1, '2025-01-20 00:00:00', NULL),
(68, 'CMD2025060068', 188, 'Centre-ville de Man', 'Marché de Korhogo', '2024-12-16', '14:57:00', 'Pièces automobiles', 170.93, 0.50, 795952.88, 'livree', 'created', NULL, NULL, NULL, 954343.45, 170.93, 660.00, 'periurbain', 'fragile', 'normal', 1, NULL, 1, '2024-12-15 00:00:00', NULL),
(69, 'CMD2025060069', 70, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-01-08', '14:39:00', 'Textiles et vêtements', 226.02, 14.50, 146799.44, 'livree', 'created', NULL, NULL, NULL, 218199.15, 226.02, 65.00, 'regional', 'dangereux', 'tres_urgent', 10, NULL, 1, '2025-01-02 00:00:00', NULL),
(70, 'CMD2025060070', 9, 'Zone Industrielle Yopougon, Abidjan', 'Zone Industrielle de Yamoussoukro', '2025-04-06', '17:23:00', 'Équipements électroniques', 226.55, 44.10, 976579.15, 'livree', 'created', NULL, NULL, NULL, 976579.15, 226.55, 795.00, 'urbain', 'standard', 'tres_urgent', 5, NULL, 1, '2025-04-03 00:00:00', NULL),
(71, 'CMD2025060071', 181, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-02-22', '10:45:00', 'Produits alimentaires', 34.87, 33.00, 173148.09, 'livree', 'created', NULL, NULL, NULL, 173148.10, 34.87, 691.00, 'urbain', 'fragile', 'tres_urgent', 2, NULL, 1, '2025-02-15 00:00:00', NULL),
(72, 'CMD2025060072', 57, 'Zone Industrielle de Yamoussoukro', 'Gare Routière de Bouaké', '2025-02-11', '15:54:00', 'Textiles et vêtements', 142.34, 9.80, 646887.15, 'livree', 'created', NULL, NULL, NULL, 646887.15, 142.34, 697.00, 'urbain', 'volumineux', 'normal', 1, NULL, 1, '2025-02-06 00:00:00', NULL),
(73, 'CMD2025060073', 167, 'Port de San-Pédro', 'Marché Central de Daloa', '2025-04-16', '13:01:00', 'Pièces automobiles', 157.78, 43.70, 387235.00, 'livree', 'created', NULL, NULL, NULL, 463881.99, 157.78, 346.00, 'periurbain', 'fragile', 'tres_urgent', 1, NULL, 1, '2025-04-15 00:00:00', NULL),
(74, 'CMD2025060074', 137, 'Marché Central de Daloa', 'Port de San-Pédro', '2025-02-07', '11:39:00', 'Produits pharmaceutiques', 92.52, 39.80, 69048.96, 'livree', 'created', NULL, NULL, NULL, 101573.43, 92.52, 93.00, 'regional', 'urgent', 'urgent', 4, NULL, 1, '2025-02-05 00:00:00', NULL),
(75, 'CMD2025060075', 63, 'Marché de Korhogo', 'Marché de Cocody, Abidjan', '2025-01-21', '17:10:00', 'Textiles et vêtements', 162.13, 6.20, 188906.02, 'livree', 'created', NULL, NULL, NULL, 281359.04, 162.13, 176.00, 'regional', 'volumineux', 'normal', 9, NULL, 1, '2025-01-17 00:00:00', NULL),
(76, 'CMD2025060076', 129, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2025-01-22', '08:08:00', 'Pièces automobiles', 52.77, 44.00, 297392.76, 'livree', 'created', NULL, NULL, NULL, 356071.32, 52.77, 792.00, 'periurbain', 'fragile', 'normal', 5, NULL, 1, '2025-01-18 00:00:00', NULL),
(77, 'CMD2025060077', 132, 'Gare Routière de Bouaké', 'Marché de Korhogo', '2025-05-31', '09:45:00', 'Matériaux de construction', 59.02, 26.00, 6868.37, 'livree', 'created', NULL, NULL, NULL, 7442.05, 59.02, 6.00, 'periurbain', 'refrigere', 'tres_urgent', 1, NULL, 1, '2025-05-29 00:00:00', NULL),
(78, 'CMD2025060078', 136, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2025-05-15', '09:43:00', 'Matériaux de construction', 233.10, 37.80, 1278474.25, 'livree', 'created', NULL, NULL, NULL, 1533369.10, 233.10, 675.00, 'periurbain', 'refrigere', 'normal', 8, NULL, 1, '2025-05-14 00:00:00', NULL),
(79, 'CMD2025060079', 178, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2025-05-04', '18:01:00', 'Mobilier et décoration', 50.06, 0.30, 381101.98, 'livree', 'created', NULL, NULL, NULL, 569652.97, 50.06, 775.00, 'regional', 'dangereux', 'tres_urgent', 6, NULL, 1, '2025-04-27 00:00:00', NULL),
(80, 'CMD2025060080', 85, 'Marché de Cocody, Abidjan', 'Centre-ville de Man', '2025-04-29', '10:31:00', 'Produits cosmétiques', 124.04, 34.90, 288336.89, 'livree', 'created', NULL, NULL, NULL, 288336.90, 124.04, 283.00, 'urbain', 'refrigere', 'urgent', 1, NULL, 1, '2025-04-27 00:00:00', NULL),
(81, 'CMD2025060081', 11, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-04-08', '09:08:00', 'Produits alimentaires', 112.41, 0.70, 809264.77, 'livree', 'created', NULL, NULL, NULL, 970317.72, 112.41, 737.00, 'periurbain', 'dangereux', 'urgent', 6, NULL, 1, '2025-04-03 00:00:00', NULL),
(82, 'CMD2025060082', 105, 'Zone Industrielle Yopougon, Abidjan', 'Port de San-Pédro', '2025-01-27', '11:21:00', 'Matériaux de construction', 92.09, 34.00, 245183.71, 'livree', 'created', NULL, NULL, NULL, 245183.71, 92.09, 485.00, 'urbain', 'standard', 'tres_urgent', 1, NULL, 1, '2025-01-25 00:00:00', NULL),
(83, 'CMD2025060083', 42, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2025-01-19', '13:57:00', 'Textiles et vêtements', 121.89, 8.60, 488966.18, 'livree', 'created', NULL, NULL, NULL, 585959.42, 121.89, 614.00, 'periurbain', 'volumineux', 'urgent', 6, NULL, 1, '2025-01-13 00:00:00', NULL),
(84, 'CMD2025060084', 4, 'Marché de Korhogo', 'Port Autonome d\'Abidjan, Treichville', '2025-04-02', '08:25:00', 'Pièces automobiles', 218.76, 1.60, 1483937.65, 'livree', 'created', NULL, NULL, NULL, 1779925.18, 218.76, 696.00, 'periurbain', 'dangereux', 'urgent', 9, NULL, 1, '2025-04-01 00:00:00', NULL),
(85, 'CMD2025060085', 174, 'Marché Central de Daloa', 'Marché de Korhogo', '2025-03-28', '17:16:00', 'Produits pharmaceutiques', 226.49, 25.40, 1002005.54, 'livree', 'created', NULL, NULL, NULL, 1002005.54, 226.49, 680.00, 'urbain', 'volumineux', 'normal', 4, NULL, 1, '2025-03-24 00:00:00', NULL),
(86, 'CMD2025060086', 62, 'Port Autonome d\'Abidjan, Treichville', 'Centre-ville de Man', '2025-02-23', '17:06:00', 'Équipements électroniques', 18.93, 16.20, 79082.06, 'livree', 'created', NULL, NULL, NULL, 94098.48, 18.93, 565.00, 'periurbain', 'fragile', 'urgent', 7, NULL, 1, '2025-02-19 00:00:00', NULL),
(87, 'CMD2025060087', 165, 'Gare Routière de Bouaké', 'Centre-ville de Man', '2024-12-12', '12:53:00', 'Pièces automobiles', 123.31, 38.60, 494349.61, 'livree', 'created', NULL, NULL, NULL, 494349.61, 123.31, 526.00, 'urbain', 'urgent', 'tres_urgent', 10, NULL, 1, '2024-12-10 00:00:00', NULL),
(88, 'CMD2025060088', 183, 'Zone Industrielle Yopougon, Abidjan', 'Zone Industrielle de Yamoussoukro', '2024-12-13', '15:20:00', 'Mobilier et décoration', 178.55, 46.70, 505561.23, 'livree', 'created', NULL, NULL, NULL, 756341.86, 178.55, 289.00, 'regional', 'dangereux', 'tres_urgent', 9, NULL, 1, '2024-12-10 00:00:00', NULL),
(89, 'CMD2025060089', 45, 'Gare Routière de Bouaké', 'Port de San-Pédro', '2025-03-13', '13:03:00', 'Équipements électroniques', 115.97, 25.10, 245414.75, 'livree', 'created', NULL, NULL, NULL, 245414.76, 115.97, 257.00, 'urbain', 'refrigere', 'tres_urgent', 7, NULL, 1, '2025-03-08 00:00:00', NULL),
(90, 'CMD2025060090', 6, 'Zone Industrielle Yopougon, Abidjan', 'Marché Central de Daloa', '2025-06-01', '11:43:00', 'Produits cosmétiques', 119.90, 25.60, 251329.72, 'livree', 'created', NULL, NULL, NULL, 300795.66, 119.90, 382.00, 'periurbain', 'standard', 'tres_urgent', 5, NULL, 1, '2025-05-30 00:00:00', NULL),
(91, 'CMD2025060091', 38, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2025-05-11', '12:00:00', 'Produits cosmétiques', 105.87, 23.70, 181683.74, 'livree', 'created', NULL, NULL, NULL, 181683.74, 105.87, 259.00, 'urbain', 'volumineux', 'tres_urgent', 8, NULL, 1, '2025-05-10 00:00:00', NULL),
(92, 'CMD2025060092', 171, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2025-05-03', '11:01:00', 'Produits pharmaceutiques', 75.23, 19.10, 233729.85, 'livree', 'created', NULL, NULL, NULL, 348594.78, 75.23, 377.00, 'regional', 'refrigere', 'normal', 5, NULL, 1, '2025-04-26 00:00:00', NULL),
(93, 'CMD2025060093', 99, 'Port Autonome d\'Abidjan, Treichville', 'Centre-ville de Man', '2025-04-16', '18:05:00', 'Matériel informatique', 12.54, 47.60, 6640.92, 'livree', 'created', NULL, NULL, NULL, 7961.40, 12.54, 26.00, 'regional', 'refrigere', 'normal', 6, NULL, 1, '2025-04-15 00:00:00', NULL),
(94, 'CMD2025060094', 67, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-04-18', '18:30:00', 'Mobilier et décoration', 218.56, 46.00, 1444345.37, 'livree', 'created', NULL, NULL, NULL, 1444345.37, 218.56, 678.00, 'urbain', 'dangereux', 'tres_urgent', 10, NULL, 1, '2025-04-16 00:00:00', NULL),
(95, 'CMD2025060095', 66, 'Centre-ville de Man', 'Port de San-Pédro', '2025-01-21', '16:06:00', 'Mobilier et décoration', 167.51, 38.90, 724839.08, 'livree', 'created', NULL, NULL, NULL, 724839.08, 167.51, 613.00, 'urbain', 'fragile', 'tres_urgent', 6, NULL, 1, '2025-01-19 00:00:00', NULL),
(96, 'CMD2025060096', 50, 'Zone Industrielle de Yamoussoukro', 'Gare Routière de Bouaké', '2025-04-24', '16:49:00', 'Équipements électroniques', 91.95, 8.60, 365970.37, 'livree', 'created', NULL, NULL, NULL, 546955.56, 91.95, 405.00, 'regional', 'dangereux', 'urgent', 10, NULL, 1, '2025-04-17 00:00:00', NULL),
(97, 'CMD2025060097', 195, 'Marché de Korhogo', 'Centre Commercial Playce, Marcory', '2024-12-01', '17:50:00', 'Mobilier et décoration', 89.44, 3.70, 448241.32, 'livree', 'created', NULL, NULL, NULL, 448241.33, 89.44, 511.00, 'urbain', 'dangereux', 'normal', 4, NULL, 1, '2024-11-27 00:00:00', NULL),
(98, 'CMD2025060098', 25, 'Marché de Cocody, Abidjan', 'Marché de Korhogo', '2025-02-04', '10:38:00', 'Produits cosmétiques', 222.87, 24.50, 1177410.55, 'livree', 'created', NULL, NULL, NULL, 1412092.66, 222.87, 750.00, 'periurbain', 'fragile', 'normal', 4, NULL, 1, '2025-01-31 00:00:00', NULL),
(99, 'CMD2025060099', 103, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2025-04-24', '14:41:00', 'Produits pharmaceutiques', 159.24, 44.00, 485369.78, 'livree', 'created', NULL, NULL, NULL, 485369.79, 159.24, 311.00, 'urbain', 'dangereux', 'urgent', 1, NULL, 1, '2025-04-17 00:00:00', NULL),
(100, 'CMD2025060100', 155, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-02-23', '11:16:00', 'Équipements électroniques', 166.82, 30.50, 914556.94, 'livree', 'created', NULL, NULL, NULL, 1369835.42, 166.82, 722.00, 'regional', 'urgent', 'tres_urgent', 2, NULL, 1, '2025-02-19 00:00:00', NULL),
(101, 'CMD2025060101', 44, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-05-03', '10:57:00', 'Mobilier et décoration', 90.73, 3.40, 412121.69, 'livree', 'created', NULL, NULL, NULL, 412121.69, 90.73, 595.00, 'urbain', 'urgent', 'tres_urgent', 7, NULL, 1, '2025-04-29 00:00:00', NULL),
(102, 'CMD2025060102', 107, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-05-10', '15:45:00', 'Pièces automobiles', 96.75, 20.00, 441395.14, 'livree', 'created', NULL, NULL, NULL, 660092.71, 96.75, 644.00, 'regional', 'fragile', 'normal', 3, NULL, 1, '2025-05-04 00:00:00', NULL),
(103, 'CMD2025060103', 169, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-02-01', '14:05:00', 'Matériaux de construction', 167.65, 35.40, 276679.37, 'livree', 'created', NULL, NULL, NULL, 413019.06, 167.65, 251.00, 'regional', 'volumineux', 'tres_urgent', 8, NULL, 1, '2025-01-28 00:00:00', NULL),
(104, 'CMD2025060104', 180, 'Zone Industrielle Yopougon, Abidjan', 'Centre-ville de Man', '2025-03-26', '11:58:00', 'Équipements électroniques', 139.16, 36.80, 469907.68, 'livree', 'created', NULL, NULL, NULL, 563089.22, 139.16, 620.00, 'periurbain', 'standard', 'normal', 9, NULL, 1, '2025-03-25 00:00:00', NULL),
(105, 'CMD2025060105', 71, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-05-31', '13:12:00', 'Matériel informatique', 141.32, 37.20, 387242.88, 'livree', 'created', NULL, NULL, NULL, 387242.88, 141.32, 279.00, 'urbain', 'dangereux', 'normal', 6, NULL, 1, '2025-05-24 00:00:00', NULL),
(106, 'CMD2025060106', 147, 'Port de San-Pédro', 'Marché de Cocody, Abidjan', '2025-04-04', '14:41:00', 'Produits pharmaceutiques', 189.65, 41.80, 601875.42, 'livree', 'created', NULL, NULL, NULL, 900813.13, 189.65, 417.00, 'regional', 'urgent', 'tres_urgent', 1, NULL, 1, '2025-03-31 00:00:00', NULL),
(107, 'CMD2025060107', 34, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2025-02-24', '12:14:00', 'Équipements électroniques', 113.69, 10.80, 146676.40, 'livree', 'created', NULL, NULL, NULL, 218014.61, 113.69, 166.00, 'regional', 'urgent', 'urgent', 8, NULL, 1, '2025-02-17 00:00:00', NULL),
(108, 'CMD2025060108', 96, 'Zone Industrielle Yopougon, Abidjan', 'Centre-ville de Man', '2024-11-28', '14:40:00', 'Textiles et vêtements', 74.01, 44.10, 242833.23, 'livree', 'created', NULL, NULL, NULL, 290599.88, 74.01, 498.00, 'periurbain', 'volumineux', 'urgent', 1, NULL, 1, '2024-11-26 00:00:00', NULL),
(109, 'CMD2025060109', 118, 'Gare Routière de Bouaké', 'Marché de Cocody, Abidjan', '2025-02-09', '10:05:00', 'Produits alimentaires', 134.05, 42.90, 187283.88, 'livree', 'created', NULL, NULL, NULL, 223940.66, 134.05, 211.00, 'periurbain', 'volumineux', 'urgent', 2, NULL, 1, '2025-02-07 00:00:00', NULL),
(110, 'CMD2025060110', 89, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2024-12-03', '11:22:00', 'Équipements électroniques', 182.82, 27.20, 540064.80, 'livree', 'created', NULL, NULL, NULL, 647277.78, 182.82, 362.00, 'periurbain', 'refrigere', 'normal', 10, NULL, 1, '2024-11-27 00:00:00', NULL),
(111, 'CMD2025060111', 139, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2025-01-04', '14:29:00', 'Produits cosmétiques', 156.61, 12.50, 301938.00, 'livree', 'created', NULL, NULL, NULL, 450906.99, 156.61, 271.00, 'regional', 'fragile', 'normal', 2, NULL, 1, '2024-12-29 00:00:00', NULL),
(112, 'CMD2025060112', 113, 'Zone Industrielle de Yamoussoukro', 'Zone Industrielle Yopougon, Abidjan', '2025-02-09', '17:55:00', 'Produits cosmétiques', 91.26, 47.10, 30611.42, 'livree', 'created', NULL, NULL, NULL, 35933.70, 91.26, 45.00, 'periurbain', 'volumineux', 'urgent', 1, NULL, 1, '2025-02-07 00:00:00', NULL),
(113, 'CMD2025060113', 8, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-01-19', '17:38:00', 'Produits alimentaires', 38.31, 33.50, 127958.90, 'livree', 'created', NULL, NULL, NULL, 127958.90, 38.31, 428.00, 'urbain', 'urgent', 'urgent', 9, NULL, 1, '2025-01-17 00:00:00', NULL),
(114, 'CMD2025060114', 72, 'Zone Industrielle de Yamoussoukro', 'Marché Central de Daloa', '2025-05-15', '09:19:00', 'Produits pharmaceutiques', 24.24, 8.50, 35336.50, 'livree', 'created', NULL, NULL, NULL, 41603.80, 24.24, 133.00, 'periurbain', 'dangereux', 'tres_urgent', 1, NULL, 1, '2025-05-12 00:00:00', NULL),
(115, 'CMD2025060115', 84, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-02-08', '16:04:00', 'Matériel informatique', 26.87, 10.10, 6872.94, 'livree', 'created', NULL, NULL, NULL, 7447.54, 26.87, 11.00, 'periurbain', 'dangereux', 'normal', 4, NULL, 1, '2025-02-02 00:00:00', NULL),
(116, 'CMD2025060116', 120, 'Centre-ville de Man', 'Port Autonome d\'Abidjan, Treichville', '2025-03-12', '12:33:00', 'Produits alimentaires', 90.74, 48.00, 27519.81, 'livree', 'created', NULL, NULL, NULL, 39279.72, 90.74, 48.00, 'regional', 'standard', 'tres_urgent', 1, NULL, 1, '2025-03-07 00:00:00', NULL),
(117, 'CMD2025060117', 140, 'Centre-ville de Man', 'Marché Central de Daloa', '2025-01-04', '17:17:00', 'Produits pharmaceutiques', 130.73, 47.80, 827410.75, 'livree', 'created', NULL, NULL, NULL, 1239116.13, 130.73, 648.00, 'regional', 'dangereux', 'urgent', 6, NULL, 1, '2024-12-30 00:00:00', NULL),
(118, 'CMD2025060118', 13, 'Port Autonome d\'Abidjan, Treichville', 'Centre Commercial Playce, Marcory', '2025-03-09', '10:28:00', 'Équipements électroniques', 155.11, 41.00, 448762.41, 'livree', 'created', NULL, NULL, NULL, 448762.41, 155.11, 295.00, 'urbain', 'dangereux', 'normal', 7, NULL, 1, '2025-03-04 00:00:00', NULL),
(119, 'CMD2025060119', 153, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2025-02-01', '14:01:00', 'Mobilier et décoration', 31.32, 46.20, 169745.44, 'livree', 'created', NULL, NULL, NULL, 169745.44, 31.32, 700.00, 'urbain', 'urgent', 'urgent', 6, NULL, 1, '2025-01-29 00:00:00', NULL),
(120, 'CMD2025060120', 30, 'Gare Routière de Bouaké', 'Marché de Cocody, Abidjan', '2024-12-12', '09:50:00', 'Textiles et vêtements', 116.93, 48.40, 324888.66, 'livree', 'created', NULL, NULL, NULL, 324888.67, 116.93, 363.00, 'urbain', 'urgent', 'tres_urgent', 3, NULL, 1, '2024-12-08 00:00:00', NULL),
(121, 'CMD2025060121', 143, 'Zone Industrielle Yopougon, Abidjan', 'Centre Commercial Playce, Marcory', '2025-06-08', '13:40:00', 'Équipements électroniques', 144.41, 9.80, 852047.72, 'livree', 'created', NULL, NULL, NULL, 1276071.60, 144.41, 725.00, 'regional', 'refrigere', 'normal', 1, NULL, 1, '2025-06-03 00:00:00', NULL),
(122, 'CMD2025060122', 190, 'Marché de Cocody, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-04-27', '13:13:00', 'Matériel informatique', 60.05, 8.90, 338711.49, 'livree', 'created', NULL, NULL, NULL, 506067.24, 60.05, 794.00, 'regional', 'fragile', 'urgent', 7, NULL, 1, '2025-04-22 00:00:00', NULL),
(123, 'CMD2025060123', 163, 'Centre-ville de Man', 'Marché Central de Daloa', '2025-02-22', '10:18:00', 'Matériaux de construction', 48.48, 7.30, 161598.78, 'livree', 'created', NULL, NULL, NULL, 161598.78, 48.48, 430.00, 'urbain', 'urgent', 'normal', 6, NULL, 1, '2025-02-18 00:00:00', NULL),
(124, 'CMD2025060124', 119, 'Marché de Korhogo', 'Gare Routière de Bouaké', '2025-05-16', '09:48:00', 'Produits cosmétiques', 11.08, 13.70, 16636.52, 'livree', 'created', NULL, NULL, NULL, 19163.82, 11.08, 176.00, 'periurbain', 'volumineux', 'normal', 3, NULL, 1, '2025-05-11 00:00:00', NULL),
(125, 'CMD2025060125', 101, 'Centre-ville de Man', 'Marché de Cocody, Abidjan', '2025-05-06', '15:25:00', 'Matériel informatique', 50.29, 1.70, 162866.11, 'livree', 'created', NULL, NULL, NULL, 194639.33, 50.29, 325.00, 'periurbain', 'dangereux', 'tres_urgent', 8, NULL, 1, '2025-04-30 00:00:00', NULL),
(126, 'CMD2025060126', 79, 'Marché de Korhogo', 'Port Autonome d\'Abidjan, Treichville', '2025-02-22', '10:40:00', 'Matériaux de construction', 104.86, 17.60, 197089.20, 'livree', 'created', NULL, NULL, NULL, 235707.04, 104.86, 341.00, 'periurbain', 'standard', 'normal', 4, NULL, 1, '2025-02-19 00:00:00', NULL),
(127, 'CMD2025060127', 131, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-05-08', '17:46:00', 'Produits pharmaceutiques', 150.68, 2.30, 167059.87, 'livree', 'created', NULL, NULL, NULL, 199671.83, 150.68, 167.00, 'periurbain', 'volumineux', 'normal', 3, NULL, 1, '2025-05-06 00:00:00', NULL),
(128, 'CMD2025060128', 95, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-01-21', '08:18:00', 'Produits pharmaceutiques', 140.36, 5.40, 623391.84, 'livree', 'created', NULL, NULL, NULL, 933087.77, 140.36, 454.00, 'regional', 'dangereux', 'normal', 5, NULL, 1, '2025-01-20 00:00:00', NULL),
(129, 'CMD2025060129', 93, 'Centre Commercial Playce, Marcory', 'Centre-ville de Man', '2024-11-28', '14:03:00', 'Produits cosmétiques', 110.43, 28.60, 268766.97, 'livree', 'created', NULL, NULL, NULL, 321720.36, 110.43, 296.00, 'periurbain', 'refrigere', 'normal', 10, NULL, 1, '2024-11-23 00:00:00', NULL),
(130, 'CMD2025060130', 176, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-04-27', '16:20:00', 'Textiles et vêtements', 183.85, 21.30, 356936.85, 'livree', 'created', NULL, NULL, NULL, 356936.85, 183.85, 237.00, 'urbain', 'refrigere', 'tres_urgent', 8, NULL, 1, '2025-04-24 00:00:00', NULL),
(131, 'CMD2025060131', 56, 'Marché de Cocody, Abidjan', 'Marché de Korhogo', '2025-02-10', '09:07:00', 'Textiles et vêtements', 150.27, 44.40, 786651.24, 'livree', 'created', NULL, NULL, NULL, 1177976.86, 150.27, 643.00, 'regional', 'refrigere', 'normal', 6, NULL, 1, '2025-02-08 00:00:00', NULL),
(132, 'CMD2025060132', 55, 'Marché Central de Daloa', 'Port de San-Pédro', '2025-01-18', '14:47:00', 'Produits cosmétiques', 166.79, 9.50, 1006441.26, 'livree', 'created', NULL, NULL, NULL, 1006441.26, 166.79, 742.00, 'urbain', 'refrigere', 'tres_urgent', 2, NULL, 1, '2025-01-12 00:00:00', NULL),
(133, 'CMD2025060133', 64, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2025-02-05', '13:43:00', 'Équipements électroniques', 93.49, 15.90, 300849.45, 'livree', 'created', NULL, NULL, NULL, 449274.18, 93.49, 588.00, 'regional', 'standard', 'tres_urgent', 2, NULL, 1, '2025-01-29 00:00:00', NULL),
(134, 'CMD2025060134', 46, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2025-03-25', '14:20:00', 'Équipements électroniques', 47.00, 13.60, 180644.80, 'livree', 'created', NULL, NULL, NULL, 215973.76, 47.00, 696.00, 'periurbain', 'standard', 'normal', 1, NULL, 1, '2025-03-24 00:00:00', NULL),
(135, 'CMD2025060135', 142, 'Marché de Cocody, Abidjan', 'Marché de Korhogo', '2025-04-10', '12:13:00', 'Matériel informatique', 53.32, 1.00, 228583.84, 'livree', 'created', NULL, NULL, NULL, 273500.61, 53.32, 780.00, 'periurbain', 'standard', 'urgent', 2, NULL, 1, '2025-04-04 00:00:00', NULL),
(136, 'CMD2025060136', 23, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-03-23', '09:20:00', 'Pièces automobiles', 196.73, 27.60, 101523.00, 'livree', 'created', NULL, NULL, NULL, 101522.99, 196.73, 51.00, 'urbain', 'dangereux', 'tres_urgent', 7, NULL, 1, '2025-03-20 00:00:00', NULL),
(137, 'CMD2025060137', 117, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2024-12-18', '13:07:00', 'Produits cosmétiques', 6.85, 48.20, 16909.51, 'livree', 'created', NULL, NULL, NULL, 16909.51, 6.85, 349.00, 'urbain', 'standard', 'normal', 6, NULL, 1, '2024-12-15 00:00:00', NULL),
(138, 'CMD2025060138', 24, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-02-14', '09:36:00', 'Équipements électroniques', 15.35, 7.20, 70229.11, 'livree', 'created', NULL, NULL, NULL, 70229.11, 15.35, 799.00, 'urbain', 'standard', 'urgent', 8, NULL, 1, '2025-02-13 00:00:00', NULL),
(139, 'CMD2025060139', 39, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-03-04', '13:03:00', 'Produits alimentaires', 47.41, 36.10, 259937.20, 'livree', 'created', NULL, NULL, NULL, 259937.20, 47.41, 769.00, 'urbain', 'fragile', 'normal', 10, NULL, 1, '2025-02-28 00:00:00', NULL),
(140, 'CMD2025060140', 77, 'Marché de Cocody, Abidjan', 'Zone Industrielle Yopougon, Abidjan', '2025-02-03', '15:36:00', 'Produits pharmaceutiques', 205.58, 44.30, 994015.72, 'livree', 'created', NULL, NULL, NULL, 994015.72, 205.58, 686.00, 'urbain', 'fragile', 'normal', 9, NULL, 1, '2025-01-31 00:00:00', NULL),
(141, 'CMD2025060141', 158, 'Centre-ville de Man', 'Port de San-Pédro', '2025-04-04', '11:31:00', 'Pièces automobiles', 232.09, 3.00, 893582.40, 'livree', 'created', NULL, NULL, NULL, 1071498.89, 232.09, 546.00, 'periurbain', 'fragile', 'urgent', 9, NULL, 1, '2025-04-01 00:00:00', NULL),
(142, 'CMD2025060142', 18, 'Zone Industrielle Yopougon, Abidjan', 'Port de San-Pédro', '2025-04-10', '09:12:00', 'Textiles et vêtements', 121.35, 36.40, 321815.65, 'livree', 'created', NULL, NULL, NULL, 321815.65, 121.35, 485.00, 'urbain', 'standard', 'tres_urgent', 4, NULL, 1, '2025-04-04 00:00:00', NULL),
(143, 'CMD2025060143', 28, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-04-03', '15:20:00', 'Matériel informatique', 105.87, 16.80, 191516.94, 'livree', 'created', NULL, NULL, NULL, 285275.41, 105.87, 328.00, 'regional', 'standard', 'tres_urgent', 9, NULL, 1, '2025-03-29 00:00:00', NULL),
(144, 'CMD2025060144', 179, 'Marché Central de Daloa', 'Port de San-Pédro', '2024-12-09', '08:02:00', 'Pièces automobiles', 10.87, 24.70, 45417.31, 'livree', 'created', NULL, NULL, NULL, 53700.77, 10.87, 392.00, 'periurbain', 'dangereux', 'tres_urgent', 7, NULL, 1, '2024-12-02 00:00:00', NULL),
(145, 'CMD2025060145', 196, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2025-05-16', '08:51:00', 'Pièces automobiles', 152.15, 26.50, 661288.00, 'livree', 'created', NULL, NULL, NULL, 989932.00, 152.15, 800.00, 'regional', 'standard', 'tres_urgent', 1, NULL, 1, '2025-05-11 00:00:00', NULL),
(146, 'CMD2025060146', 138, 'Gare Routière de Bouaké', 'Port de San-Pédro', '2025-02-09', '18:47:00', 'Mobilier et décoration', 228.47, 12.00, 294175.18, 'livree', 'created', NULL, NULL, NULL, 294175.17, 228.47, 168.00, 'urbain', 'urgent', 'urgent', 2, NULL, 1, '2025-02-07 00:00:00', NULL),
(147, 'CMD2025060147', 14, 'Centre Commercial Playce, Marcory', 'Marché Central de Daloa', '2025-04-18', '11:07:00', 'Produits pharmaceutiques', 82.49, 36.00, 330779.19, 'livree', 'created', NULL, NULL, NULL, 330779.18, 82.49, 524.00, 'urbain', 'urgent', 'tres_urgent', 2, NULL, 1, '2025-04-15 00:00:00', NULL),
(148, 'CMD2025060148', 106, 'Gare Routière de Bouaké', 'Zone Industrielle Yopougon, Abidjan', '2025-01-13', '08:20:00', 'Matériel informatique', 134.11, 49.50, 434895.43, 'livree', 'created', NULL, NULL, NULL, 650343.15, 134.11, 595.00, 'regional', 'standard', 'urgent', 2, NULL, 1, '2025-01-07 00:00:00', NULL),
(149, 'CMD2025060149', 97, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-01-26', '16:53:00', 'Produits cosmétiques', 99.80, 29.10, 240909.23, 'livree', 'created', NULL, NULL, NULL, 240909.23, 99.80, 314.00, 'urbain', 'urgent', 'normal', 7, NULL, 1, '2025-01-24 00:00:00', NULL),
(150, 'CMD2025060150', 69, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2025-03-12', '18:37:00', 'Textiles et vêtements', 200.01, 28.90, 861346.87, 'livree', 'created', NULL, NULL, NULL, 1032816.23, 200.01, 441.00, 'periurbain', 'dangereux', 'tres_urgent', 8, NULL, 1, '2025-03-05 00:00:00', NULL),
(151, 'CMD2025060151', 161, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-01-03', '13:07:00', 'Produits alimentaires', 144.96, 47.00, 615589.14, 'livree', 'created', NULL, NULL, NULL, 615589.13, 144.96, 601.00, 'urbain', 'fragile', 'urgent', 7, NULL, 1, '2024-12-28 00:00:00', NULL),
(152, 'CMD2025060152', 12, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2024-11-22', '14:39:00', 'Produits pharmaceutiques', 61.04, 24.10, 331176.84, 'livree', 'created', NULL, NULL, NULL, 494765.25, 61.04, 709.00, 'regional', 'urgent', 'urgent', 2, NULL, 1, '2024-11-20 00:00:00', NULL),
(153, 'CMD2025060153', 104, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-02-21', '18:07:00', 'Textiles et vêtements', 66.80, 5.70, 76685.08, 'livree', 'created', NULL, NULL, NULL, 91222.10, 66.80, 155.00, 'periurbain', 'fragile', 'tres_urgent', 2, NULL, 1, '2025-02-18 00:00:00', NULL),
(154, 'CMD2025060154', 173, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2024-12-09', '08:54:00', 'Produits pharmaceutiques', 33.54, 8.90, 72461.85, 'livree', 'created', NULL, NULL, NULL, 86154.22, 33.54, 315.00, 'periurbain', 'volumineux', 'urgent', 7, NULL, 1, '2024-12-03 00:00:00', NULL),
(155, 'CMD2025060155', 115, 'Centre-ville de Man', 'Marché de Cocody, Abidjan', '2025-05-02', '08:04:00', 'Textiles et vêtements', 238.68, 41.50, 803100.64, 'livree', 'created', NULL, NULL, NULL, 962920.77, 238.68, 620.00, 'periurbain', 'standard', 'normal', 5, NULL, 1, '2025-05-01 00:00:00', NULL),
(156, 'CMD2025060156', 175, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2025-05-26', '11:06:00', 'Matériaux de construction', 93.88, 16.60, 448089.95, 'livree', 'created', NULL, NULL, NULL, 448089.96, 93.88, 584.00, 'urbain', 'refrigere', 'urgent', 4, NULL, 1, '2025-05-19 00:00:00', NULL),
(157, 'CMD2025060157', 100, 'Port de San-Pédro', 'Zone Industrielle Yopougon, Abidjan', '2025-01-14', '12:26:00', 'Produits cosmétiques', 160.30, 18.00, 916796.29, 'livree', 'created', NULL, NULL, NULL, 1373194.44, 160.30, 703.00, 'regional', 'refrigere', 'tres_urgent', 5, NULL, 1, '2025-01-08 00:00:00', NULL),
(158, 'CMD2025060158', 170, 'Zone Industrielle Yopougon, Abidjan', 'Marché Central de Daloa', '2025-04-15', '12:31:00', 'Mobilier et décoration', 139.76, 13.40, 253052.32, 'livree', 'created', NULL, NULL, NULL, 377578.48, 139.76, 330.00, 'regional', 'standard', 'urgent', 1, NULL, 1, '2025-04-13 00:00:00', NULL),
(159, 'CMD2025060159', 1, 'Port de San-Pédro', 'Centre-ville de Man', '2025-03-24', '08:48:00', 'Produits pharmaceutiques', 237.24, 44.40, 70616.99, 'livree', 'created', NULL, NULL, NULL, 103925.49, 237.24, 52.00, 'regional', 'standard', 'urgent', 2, NULL, 1, '2025-03-19 00:00:00', NULL),
(160, 'CMD2025060160', 80, 'Marché de Korhogo', 'Port de San-Pédro', '2025-03-08', '13:10:00', 'Mobilier et décoration', 240.17, 38.30, 1052169.13, 'livree', 'created', NULL, NULL, NULL, 1576253.69, 240.17, 449.00, 'regional', 'dangereux', 'tres_urgent', 6, NULL, 1, '2025-03-03 00:00:00', NULL),
(161, 'CMD2025060161', 172, 'Centre Commercial Playce, Marcory', 'Zone Industrielle de Yamoussoukro', '2025-03-26', '12:43:00', 'Produits cosmétiques', 30.64, 27.90, 165319.60, 'livree', 'created', NULL, NULL, NULL, 165319.60, 30.64, 750.00, 'urbain', 'fragile', 'urgent', 2, NULL, 1, '2025-03-24 00:00:00', NULL),
(162, 'CMD2025060162', 68, 'Zone Industrielle Yopougon, Abidjan', 'Gare Routière de Bouaké', '2025-04-23', '13:50:00', 'Mobilier et décoration', 183.39, 19.70, 798324.44, 'livree', 'created', NULL, NULL, NULL, 798324.44, 183.39, 617.00, 'urbain', 'fragile', 'tres_urgent', 9, NULL, 1, '2025-04-16 00:00:00', NULL);
INSERT INTO `commandes` (`id`, `numero_commande`, `client_id`, `adresse_depart`, `adresse_arrivee`, `date_prevue`, `heure_prevue`, `description`, `poids`, `volume`, `prix`, `statut`, `workflow_state`, `validated_by`, `validated_at`, `rejection_reason`, `tarif_auto`, `poids_kg`, `distance_km`, `zone_tarif`, `cargo_type`, `urgence`, `priorite`, `notes`, `active`, `date_creation`, `date_modification`) VALUES
(163, 'CMD2025060163', 49, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2025-05-29', '18:13:00', 'Pièces automobiles', 101.57, 10.20, 59122.04, 'livree', 'created', NULL, NULL, NULL, 86683.08, 101.57, 67.00, 'regional', 'refrigere', 'tres_urgent', 8, NULL, 1, '2025-05-22 00:00:00', NULL),
(164, 'CMD2025060164', 187, 'Marché de Korhogo', 'Zone Industrielle de Yamoussoukro', '2025-01-25', '11:49:00', 'Produits cosmétiques', 71.22, 32.10, 443584.08, 'livree', 'created', NULL, NULL, NULL, 443584.09, 71.22, 762.00, 'urbain', 'refrigere', 'tres_urgent', 10, NULL, 1, '2025-01-24 00:00:00', NULL),
(165, 'CMD2025060165', 19, 'Port de San-Pédro', 'Marché Central de Daloa', '2025-05-30', '10:19:00', 'Équipements électroniques', 131.25, 11.10, 194724.63, 'livree', 'created', NULL, NULL, NULL, 232869.55, 131.25, 207.00, 'periurbain', 'fragile', 'tres_urgent', 8, NULL, 1, '2025-05-24 00:00:00', NULL),
(166, 'CMD2025060166', 91, 'Gare Routière de Bouaké', 'Port Autonome d\'Abidjan, Treichville', '2024-11-23', '18:03:00', 'Produits pharmaceutiques', 119.45, 21.20, 427397.69, 'livree', 'created', NULL, NULL, NULL, 639096.54, 119.45, 547.00, 'regional', 'volumineux', 'tres_urgent', 3, NULL, 1, '2024-11-21 00:00:00', NULL),
(167, 'CMD2025060167', 92, 'Port de San-Pédro', 'Marché de Korhogo', '2025-06-02', '15:27:00', 'Pièces automobiles', 138.36, 43.70, 681958.47, 'livree', 'created', NULL, NULL, NULL, 681958.46, 138.36, 698.00, 'urbain', 'fragile', 'normal', 7, NULL, 1, '2025-05-27 00:00:00', NULL),
(168, 'CMD2025060168', 58, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2025-02-10', '15:28:00', 'Matériel informatique', 50.88, 20.20, 141238.62, 'livree', 'created', NULL, NULL, NULL, 168686.35, 50.88, 333.00, 'periurbain', 'refrigere', 'normal', 10, NULL, 1, '2025-02-09 00:00:00', NULL),
(169, 'CMD2025060169', 112, 'Zone Industrielle Yopougon, Abidjan', 'Gare Routière de Bouaké', '2024-11-26', '17:27:00', 'Matériel informatique', 114.54, 48.60, 580704.32, 'livree', 'created', NULL, NULL, NULL, 869056.49, 114.54, 666.00, 'regional', 'urgent', 'normal', 4, NULL, 1, '2024-11-24 00:00:00', NULL),
(170, 'CMD2025060170', 74, 'Zone Industrielle de Yamoussoukro', 'Zone Industrielle Yopougon, Abidjan', '2024-12-21', '14:09:00', 'Produits cosmétiques', 186.83, 40.70, 19133.23, 'livree', 'created', NULL, NULL, NULL, 22159.87, 186.83, 10.00, 'periurbain', 'refrigere', 'tres_urgent', 6, NULL, 1, '2024-12-17 00:00:00', NULL),
(171, 'CMD2025060171', 135, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2025-04-23', '16:57:00', 'Mobilier et décoration', 85.21, 48.30, 428703.68, 'livree', 'created', NULL, NULL, NULL, 641055.52, 85.21, 710.00, 'regional', 'fragile', 'normal', 10, NULL, 1, '2025-04-16 00:00:00', NULL),
(172, 'CMD2025060172', 48, 'Marché de Cocody, Abidjan', 'Port de San-Pédro', '2024-12-22', '10:15:00', 'Pièces automobiles', 35.67, 5.20, 76539.94, 'livree', 'created', NULL, NULL, NULL, 112809.90, 35.67, 269.00, 'regional', 'urgent', 'urgent', 5, NULL, 1, '2024-12-19 00:00:00', NULL),
(173, 'CMD2025060173', 102, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2025-06-06', '13:58:00', 'Textiles et vêtements', 57.10, 20.00, 298896.38, 'livree', 'created', NULL, NULL, NULL, 357875.66, 57.10, 797.00, 'periurbain', 'volumineux', 'normal', 3, NULL, 1, '2025-06-02 00:00:00', NULL),
(174, 'CMD2025060174', 159, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-02-02', '13:06:00', 'Textiles et vêtements', 110.94, 39.20, 187017.72, 'livree', 'created', NULL, NULL, NULL, 223621.26, 110.94, 235.00, 'periurbain', 'fragile', 'tres_urgent', 9, NULL, 1, '2025-02-01 00:00:00', NULL),
(175, 'CMD2025060175', 110, 'Zone Industrielle Yopougon, Abidjan', 'Port de San-Pédro', '2025-02-13', '10:18:00', 'Produits pharmaceutiques', 97.16, 44.50, 222155.29, 'livree', 'created', NULL, NULL, NULL, 331232.93, 97.16, 231.00, 'regional', 'dangereux', 'tres_urgent', 2, NULL, 1, '2025-02-09 00:00:00', NULL),
(176, 'CMD2025060176', 111, 'Gare Routière de Bouaké', 'Marché de Cocody, Abidjan', '2025-03-08', '11:46:00', 'Pièces automobiles', 7.84, 18.60, 33719.87, 'livree', 'created', NULL, NULL, NULL, 39663.84, 7.84, 585.00, 'periurbain', 'volumineux', 'urgent', 8, NULL, 1, '2025-03-05 00:00:00', NULL),
(177, 'CMD2025060177', 27, 'Port de San-Pédro', 'Zone Industrielle Yopougon, Abidjan', '2024-11-24', '10:47:00', 'Mobilier et décoration', 91.40, 24.60, 14364.76, 'livree', 'created', NULL, NULL, NULL, 19547.14, 91.40, 15.00, 'regional', 'urgent', 'tres_urgent', 5, NULL, 1, '2024-11-17 00:00:00', NULL),
(178, 'CMD2025060178', 157, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2025-05-06', '12:52:00', 'Textiles et vêtements', 132.26, 42.10, 106131.17, 'livree', 'created', NULL, NULL, NULL, 126557.41, 132.26, 110.00, 'periurbain', 'fragile', 'tres_urgent', 5, NULL, 1, '2025-05-02 00:00:00', NULL),
(179, 'CMD2025060179', 15, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2025-04-25', '11:42:00', 'Pièces automobiles', 229.94, 8.90, 11450.06, 'livree', 'created', NULL, NULL, NULL, 11450.06, 229.94, 5.00, 'urbain', 'volumineux', 'urgent', 8, NULL, 1, '2025-04-18 00:00:00', NULL),
(180, 'CMD2025060180', 61, 'Marché de Korhogo', 'Gare Routière de Bouaké', '2025-02-14', '13:11:00', 'Produits pharmaceutiques', 20.19, 19.00, 53933.91, 'livree', 'created', NULL, NULL, NULL, 63920.69, 20.19, 458.00, 'periurbain', 'standard', 'tres_urgent', 4, NULL, 1, '2025-02-09 00:00:00', NULL),
(181, 'CMD2025060181', 186, 'Marché de Cocody, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-03-24', '14:33:00', 'Pièces automobiles', 156.85, 24.10, 977191.51, 'livree', 'created', NULL, NULL, NULL, 1463787.27, 156.85, 766.00, 'regional', 'refrigere', 'tres_urgent', 5, NULL, 1, '2025-03-23 00:00:00', NULL),
(182, 'CMD2025060182', 3, 'Centre-ville de Man', 'Gare Routière de Bouaké', '2025-05-07', '14:11:00', 'Produits pharmaceutiques', 129.57, 29.40, 239931.42, 'livree', 'created', NULL, NULL, NULL, 287117.70, 129.57, 281.00, 'periurbain', 'volumineux', 'urgent', 10, NULL, 1, '2025-05-01 00:00:00', NULL),
(183, 'CMD2025060183', 148, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-04-22', '08:33:00', 'Produits cosmétiques', 102.40, 39.70, 442773.76, 'livree', 'created', NULL, NULL, NULL, 442773.76, 102.40, 529.00, 'urbain', 'refrigere', 'normal', 3, NULL, 1, '2025-04-15 00:00:00', NULL),
(184, 'CMD2025060184', 54, 'Marché de Cocody, Abidjan', 'Centre-ville de Man', '2024-11-25', '12:15:00', 'Matériel informatique', 68.24, 22.50, 94281.52, 'livree', 'created', NULL, NULL, NULL, 94281.52, 68.24, 245.00, 'urbain', 'standard', 'tres_urgent', 8, NULL, 1, '2024-11-18 00:00:00', NULL),
(185, 'CMD2025060185', 51, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2024-12-08', '17:02:00', 'Produits alimentaires', 198.07, 0.80, 870358.18, 'livree', 'created', NULL, NULL, NULL, 1043629.81, 198.07, 540.00, 'periurbain', 'refrigere', 'urgent', 3, NULL, 1, '2024-12-04 00:00:00', NULL),
(186, 'CMD2025060186', 185, 'Zone Industrielle Yopougon, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-02-10', '09:13:00', 'Produits alimentaires', 156.49, 15.10, 969887.58, 'livree', 'created', NULL, NULL, NULL, 1163065.09, 156.49, 635.00, 'periurbain', 'dangereux', 'normal', 3, NULL, 1, '2025-02-08 00:00:00', NULL),
(187, 'CMD2025060187', 168, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-04-27', '11:44:00', 'Produits pharmaceutiques', 61.97, 5.10, 139294.14, 'livree', 'created', NULL, NULL, NULL, 206941.22, 61.97, 311.00, 'regional', 'fragile', 'urgent', 10, NULL, 1, '2025-04-20 00:00:00', NULL),
(188, 'CMD2025060188', 20, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-03-14', '18:34:00', 'Matériaux de construction', 61.30, 30.70, 118466.72, 'livree', 'created', NULL, NULL, NULL, 118466.72, 61.30, 247.00, 'urbain', 'urgent', 'tres_urgent', 7, NULL, 1, '2025-03-10 00:00:00', NULL),
(189, 'CMD2025060189', 192, 'Centre Commercial Playce, Marcory', 'Marché de Korhogo', '2024-12-09', '16:16:00', 'Produits alimentaires', 165.60, 38.30, 1228929.95, 'livree', 'created', NULL, NULL, NULL, 1841394.93, 165.60, 761.00, 'regional', 'dangereux', 'urgent', 10, NULL, 1, '2024-12-02 00:00:00', NULL),
(190, 'CMD2025060190', 94, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2025-05-15', '17:19:00', 'Produits cosmétiques', 239.15, 7.70, 1587010.38, 'livree', 'created', NULL, NULL, NULL, 1903612.45, 239.15, 681.00, 'periurbain', 'dangereux', 'urgent', 10, NULL, 1, '2025-05-11 00:00:00', NULL),
(191, 'CMD2025060191', 17, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-02-02', '09:10:00', 'Produits cosmétiques', 0.84, 33.30, 9486.75, 'livree', 'created', NULL, NULL, NULL, 9486.74, 0.84, 672.00, 'urbain', 'dangereux', 'urgent', 10, NULL, 1, '2025-01-26 00:00:00', NULL),
(192, 'CMD2025060192', 123, 'Marché de Cocody, Abidjan', 'Centre Commercial Playce, Marcory', '2025-05-14', '14:23:00', 'Produits alimentaires', 105.25, 28.60, 272147.53, 'livree', 'created', NULL, NULL, NULL, 325777.04, 105.25, 337.00, 'periurbain', 'urgent', 'normal', 1, NULL, 1, '2025-05-13 00:00:00', NULL),
(193, 'CMD2025060193', 29, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-03-01', '11:35:00', 'Pièces automobiles', 52.49, 22.90, 262304.34, 'livree', 'created', NULL, NULL, NULL, 262304.35, 52.49, 701.00, 'urbain', 'fragile', 'normal', 5, NULL, 1, '2025-02-22 00:00:00', NULL),
(194, 'CMD2025060194', 130, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-03-29', '08:55:00', 'Matériaux de construction', 115.63, 44.50, 621720.90, 'livree', 'created', NULL, NULL, NULL, 930581.34, 115.63, 761.00, 'regional', 'fragile', 'tres_urgent', 10, NULL, 1, '2025-03-27 00:00:00', NULL),
(195, 'CMD2025060195', 134, 'Centre Commercial Playce, Marcory', 'Marché Central de Daloa', '2024-11-25', '16:12:00', 'Matériel informatique', 237.85, 2.20, 1024190.98, 'livree', 'created', NULL, NULL, NULL, 1534286.47, 237.85, 611.00, 'regional', 'fragile', 'tres_urgent', 2, NULL, 1, '2024-11-22 00:00:00', NULL),
(196, 'CMD2025060196', 149, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-05-07', '08:13:00', 'Équipements électroniques', 63.98, 24.40, 21620.09, 'livree', 'created', NULL, NULL, NULL, 25144.11, 63.98, 51.00, 'periurbain', 'standard', 'normal', 4, NULL, 1, '2025-05-06 00:00:00', NULL),
(197, 'CMD2025060197', 152, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2025-04-01', '17:21:00', 'Pièces automobiles', 99.96, 5.90, 746310.96, 'livree', 'created', NULL, NULL, NULL, 746310.96, 99.96, 764.00, 'urbain', 'dangereux', 'tres_urgent', 9, NULL, 1, '2025-03-27 00:00:00', NULL),
(198, 'CMD2025060198', 128, 'Marché de Cocody, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-01-06', '09:58:00', 'Équipements électroniques', 124.52, 34.80, 360645.20, 'livree', 'created', NULL, NULL, NULL, 538967.81, 124.52, 442.00, 'regional', 'volumineux', 'urgent', 10, NULL, 1, '2025-01-05 00:00:00', NULL),
(199, 'CMD2025060199', 116, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2024-12-27', '09:20:00', 'Textiles et vêtements', 140.59, 34.40, 1094494.77, 'livree', 'created', NULL, NULL, NULL, 1094494.77, 140.59, 798.00, 'urbain', 'dangereux', 'tres_urgent', 1, NULL, 1, '2024-12-24 00:00:00', NULL),
(200, 'CMD2025060200', 144, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2024-11-27', '09:48:00', 'Matériel informatique', 83.27, 21.80, 44289.36, 'livree', 'created', NULL, NULL, NULL, 52347.22, 83.27, 64.00, 'periurbain', 'urgent', 'normal', 10, NULL, 1, '2024-11-25 00:00:00', NULL),
(201, 'CMD2025060201', 133, 'Centre-ville de Man', 'Port de San-Pédro', '2025-04-18', '15:41:00', 'Textiles et vêtements', 74.98, 39.10, 327103.82, 'livree', 'created', NULL, NULL, NULL, 327103.81, 74.98, 532.00, 'urbain', 'refrigere', 'tres_urgent', 3, NULL, 1, '2025-04-14 00:00:00', NULL),
(202, 'CMD2025060202', 60, 'Port de San-Pédro', 'Zone Industrielle Yopougon, Abidjan', '2025-02-21', '08:33:00', 'Produits alimentaires', 157.33, 7.90, 306026.40, 'livree', 'created', NULL, NULL, NULL, 306026.40, 157.33, 237.00, 'urbain', 'refrigere', 'urgent', 2, NULL, 1, '2025-02-14 00:00:00', NULL),
(203, 'CMD2025060203', 154, 'Marché Central de Daloa', 'Marché de Korhogo', '2025-01-23', '14:54:00', 'Textiles et vêtements', 46.17, 33.80, 78346.63, 'livree', 'created', NULL, NULL, NULL, 115519.94, 46.17, 213.00, 'regional', 'urgent', 'normal', 2, NULL, 1, '2025-01-20 00:00:00', NULL),
(204, 'CMD2025060204', 2, 'Marché Central de Daloa', 'Port de San-Pédro', '2025-01-12', '18:06:00', 'Textiles et vêtements', 216.36, 46.80, 1242678.31, 'livree', 'created', NULL, NULL, NULL, 1490413.97, 216.36, 589.00, 'periurbain', 'dangereux', 'urgent', 2, NULL, 1, '2025-01-06 00:00:00', NULL),
(205, 'CMD2025060205', 177, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2025-04-12', '09:48:00', 'Produits alimentaires', 19.97, 35.30, 126094.18, 'livree', 'created', NULL, NULL, NULL, 187141.27, 19.97, 629.00, 'regional', 'dangereux', 'tres_urgent', 4, NULL, 1, '2025-04-10 00:00:00', NULL),
(206, 'CMD2025060206', 82, 'Centre-ville de Man', 'Centre Commercial Playce, Marcory', '2025-04-25', '12:48:00', 'Équipements électroniques', 210.13, 2.50, 20226.24, 'livree', 'created', NULL, NULL, NULL, 28339.35, 210.13, 11.00, 'regional', 'fragile', 'urgent', 3, NULL, 1, '2025-04-19 00:00:00', NULL),
(207, 'CMD2025060207', 10, 'Marché de Korhogo', 'Zone Industrielle de Yamoussoukro', '2025-03-01', '11:16:00', 'Produits pharmaceutiques', 81.39, 48.00, 479457.59, 'livree', 'created', NULL, NULL, NULL, 717186.41, 81.39, 601.00, 'regional', 'dangereux', 'normal', 7, NULL, 1, '2025-02-27 00:00:00', NULL),
(208, 'CMD2025060208', 90, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Cocody, Abidjan', '2025-02-09', '16:37:00', 'Textiles et vêtements', 197.87, 12.00, 400199.06, 'livree', 'created', NULL, NULL, NULL, 479438.88, 197.87, 206.00, 'periurbain', 'dangereux', 'urgent', 10, NULL, 1, '2025-02-03 00:00:00', NULL),
(209, 'CMD2025060209', 81, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-01-28', '16:07:00', 'Matériaux de construction', 120.58, 45.60, 421050.05, 'livree', 'created', NULL, NULL, NULL, 504460.05, 120.58, 427.00, 'periurbain', 'refrigere', 'normal', 5, NULL, 1, '2025-01-24 00:00:00', NULL),
(210, 'CMD2025060210', 59, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-02-05', '09:16:00', 'Produits pharmaceutiques', 79.47, 36.80, 129909.09, 'livree', 'created', NULL, NULL, NULL, 192863.63, 79.47, 163.00, 'regional', 'dangereux', 'normal', 5, NULL, 1, '2025-02-03 00:00:00', NULL),
(211, 'CMD2025060211', 36, 'Centre-ville de Man', 'Gare Routière de Bouaké', '2024-12-23', '16:01:00', 'Produits cosmétiques', 244.44, 2.70, 735794.69, 'livree', 'created', NULL, NULL, NULL, 735794.70, 244.44, 308.00, 'urbain', 'dangereux', 'tres_urgent', 9, NULL, 1, '2024-12-18 00:00:00', NULL),
(212, 'CMD2025060212', 151, 'Port Autonome d\'Abidjan, Treichville', 'Marché Central de Daloa', '2025-03-27', '12:31:00', 'Produits cosmétiques', 100.28, 20.70, 486487.19, 'livree', 'created', NULL, NULL, NULL, 486487.20, 100.28, 594.00, 'urbain', 'refrigere', 'tres_urgent', 6, NULL, 1, '2025-03-23 00:00:00', NULL),
(213, 'CMD2025060213', 98, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2025-02-16', '15:19:00', 'Équipements électroniques', 106.85, 21.10, 606608.36, 'livree', 'created', NULL, NULL, NULL, 727130.03, 106.85, 746.00, 'periurbain', 'urgent', 'normal', 8, NULL, 1, '2025-02-11 00:00:00', NULL),
(214, 'CMD2025060214', 76, 'Centre-ville de Man', 'Marché Central de Daloa', '2025-04-04', '08:48:00', 'Produits pharmaceutiques', 248.62, 5.70, 144162.01, 'livree', 'created', NULL, NULL, NULL, 214243.02, 248.62, 87.00, 'regional', 'volumineux', 'urgent', 3, NULL, 1, '2025-03-31 00:00:00', NULL),
(215, 'CMD2025060215', 35, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2024-12-18', '18:57:00', 'Matériel informatique', 123.24, 34.70, 60899.91, 'livree', 'created', NULL, NULL, NULL, 60899.91, 123.24, 57.00, 'urbain', 'refrigere', 'normal', 4, NULL, 1, '2024-12-13 00:00:00', NULL),
(216, 'CMD2025060216', 32, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-03-20', '15:33:00', 'Textiles et vêtements', 206.16, 38.50, 815569.46, 'livree', 'created', NULL, NULL, NULL, 815569.46, 206.16, 405.00, 'urbain', 'dangereux', 'urgent', 1, NULL, 1, '2025-03-13 00:00:00', NULL),
(217, 'CMD2025060217', 37, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2024-12-13', '11:05:00', 'Équipements électroniques', 194.80, 45.60, 235212.02, 'livree', 'created', NULL, NULL, NULL, 350818.02, 194.80, 157.00, 'regional', 'urgent', 'tres_urgent', 1, NULL, 1, '2024-12-06 00:00:00', NULL),
(218, 'CMD2025060218', 78, 'Gare Routière de Bouaké', 'Port Autonome d\'Abidjan, Treichville', '2025-01-20', '12:55:00', 'Équipements électroniques', 142.11, 0.70, 71684.15, 'livree', 'created', NULL, NULL, NULL, 105526.25, 142.11, 49.00, 'regional', 'dangereux', 'urgent', 3, NULL, 1, '2025-01-17 00:00:00', NULL),
(219, 'CMD2025060219', 191, 'Port Autonome d\'Abidjan, Treichville', 'Marché Central de Daloa', '2025-01-12', '13:29:00', 'Mobilier et décoration', 100.37, 6.20, 94188.47, 'livree', 'created', NULL, NULL, NULL, 139282.69, 100.37, 128.00, 'regional', 'fragile', 'tres_urgent', 7, NULL, 1, '2025-01-09 00:00:00', NULL),
(220, 'CMD2025060220', 83, 'Gare Routière de Bouaké', 'Marché de Korhogo', '2025-04-27', '08:19:00', 'Mobilier et décoration', 173.03, 9.00, 527242.72, 'livree', 'created', NULL, NULL, NULL, 527242.72, 173.03, 560.00, 'urbain', 'standard', 'normal', 1, NULL, 1, '2025-04-25 00:00:00', NULL),
(221, 'CMD2025060221', 7, 'Port de San-Pédro', 'Marché de Cocody, Abidjan', '2025-05-01', '10:27:00', 'Pièces automobiles', 113.61, 33.60, 295716.40, 'livree', 'created', NULL, NULL, NULL, 295716.40, 113.61, 317.00, 'urbain', 'refrigere', 'tres_urgent', 7, NULL, 1, '2025-04-25 00:00:00', NULL),
(222, 'CMD2025060222', 122, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2024-11-23', '12:09:00', 'Produits alimentaires', 7.83, 21.40, 19779.64, 'livree', 'created', NULL, NULL, NULL, 27669.46, 7.83, 311.00, 'regional', 'volumineux', 'urgent', 3, NULL, 1, '2024-11-17 00:00:00', NULL),
(223, 'CMD2025060223', 109, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2025-01-21', '18:30:00', 'Produits alimentaires', 234.99, 33.40, 927158.21, 'livree', 'created', NULL, NULL, NULL, 927158.22, 234.99, 485.00, 'urbain', 'refrigere', 'urgent', 7, NULL, 1, '2025-01-15 00:00:00', NULL),
(224, 'CMD2025060224', 47, 'Zone Industrielle de Yamoussoukro', 'Port Autonome d\'Abidjan, Treichville', '2025-05-09', '16:52:00', 'Textiles et vêtements', 240.22, 12.90, 1050052.40, 'livree', 'created', NULL, NULL, NULL, 1573078.59, 240.22, 448.00, 'regional', 'dangereux', 'urgent', 5, NULL, 1, '2025-05-08 00:00:00', NULL),
(225, 'CMD2025060225', 125, 'Centre-ville de Man', 'Zone Industrielle de Yamoussoukro', '2025-01-17', '13:48:00', 'Textiles et vêtements', 182.27, 23.10, 795933.99, 'livree', 'created', NULL, NULL, NULL, 954320.80, 182.27, 447.00, 'periurbain', 'dangereux', 'urgent', 6, NULL, 1, '2025-01-10 00:00:00', NULL),
(226, 'CMD2025060226', 31, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-01-24', '18:50:00', 'Mobilier et décoration', 130.93, 1.70, 13544.80, 'livree', 'created', NULL, NULL, NULL, 18317.20, 130.93, 9.00, 'regional', 'refrigere', 'urgent', 9, NULL, 1, '2025-01-17 00:00:00', NULL),
(227, 'CMD2025060227', 33, 'Marché de Cocody, Abidjan', 'Centre Commercial Playce, Marcory', '2025-03-12', '15:59:00', 'Produits pharmaceutiques', 170.24, 37.80, 216908.95, 'livree', 'created', NULL, NULL, NULL, 216908.96, 170.24, 193.00, 'urbain', 'volumineux', 'normal', 2, NULL, 1, '2025-03-10 00:00:00', NULL),
(228, 'CMD2025060228', 124, 'Centre-ville de Man', 'Marché de Korhogo', '2025-01-18', '11:55:00', 'Produits alimentaires', 110.27, 23.10, 180493.75, 'livree', 'created', NULL, NULL, NULL, 268740.62, 110.27, 228.00, 'regional', 'fragile', 'normal', 9, NULL, 1, '2025-01-11 00:00:00', NULL),
(229, 'CMD2025060229', 193, 'Zone Industrielle de Yamoussoukro', 'Marché Central de Daloa', '2025-03-19', '11:21:00', 'Produits pharmaceutiques', 106.40, 48.30, 109144.48, 'livree', 'created', NULL, NULL, NULL, 109144.48, 106.40, 183.00, 'urbain', 'standard', 'urgent', 6, NULL, 1, '2025-03-13 00:00:00', NULL),
(230, 'CMD2025060230', 21, 'Centre-ville de Man', 'Port Autonome d\'Abidjan, Treichville', '2024-11-23', '12:08:00', 'Équipements électroniques', 75.17, 41.90, 119930.18, 'livree', 'created', NULL, NULL, NULL, 143116.22, 75.17, 238.00, 'periurbain', 'volumineux', 'tres_urgent', 4, NULL, 1, '2024-11-18 00:00:00', NULL),
(231, 'CMD2025060231', 127, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2025-04-25', '09:22:00', 'Produits cosmétiques', 239.63, 30.50, 1855716.86, 'livree', 'created', NULL, NULL, NULL, 2226060.24, 239.63, 795.00, 'periurbain', 'dangereux', 'normal', 2, NULL, 1, '2025-04-20 00:00:00', NULL),
(232, 'CMD2025060232', 52, 'Centre-ville de Man', 'Marché de Cocody, Abidjan', '2024-11-21', '16:37:00', 'Mobilier et décoration', 192.31, 39.70, 519083.10, 'livree', 'created', NULL, NULL, NULL, 519083.10, 192.31, 496.00, 'urbain', 'standard', 'normal', 9, NULL, 1, '2024-11-17 00:00:00', NULL),
(233, 'CMD2025060233', 87, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-05-01', '16:23:00', 'Produits alimentaires', 158.50, 43.30, 535000.36, 'livree', 'created', NULL, NULL, NULL, 800500.54, 158.50, 517.00, 'regional', 'volumineux', 'tres_urgent', 10, NULL, 1, '2025-04-26 00:00:00', NULL),
(234, 'CMD2025060234', 194, 'Centre Commercial Playce, Marcory', 'Centre-ville de Man', '2025-03-17', '14:30:00', 'Matériaux de construction', 82.37, 50.00, 194240.10, 'livree', 'created', NULL, NULL, NULL, 194240.10, 82.37, 329.00, 'urbain', 'fragile', 'normal', 8, NULL, 1, '2025-03-14 00:00:00', NULL),
(235, 'CMD2025060235', 150, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-05-24', '16:04:00', 'Équipements électroniques', 177.59, 1.50, 338877.91, 'livree', 'created', NULL, NULL, NULL, 338877.92, 177.59, 291.00, 'urbain', 'volumineux', 'normal', 3, NULL, 1, '2025-05-19 00:00:00', NULL),
(236, 'CMD2025060236', 88, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2025-02-20', '11:28:00', 'Produits cosmétiques', 44.33, 21.10, 119046.99, 'livree', 'created', NULL, NULL, NULL, 119046.98, 44.33, 267.00, 'urbain', 'dangereux', 'tres_urgent', 10, NULL, 1, '2025-02-15 00:00:00', NULL),
(237, 'CMD2025060237', 184, 'Marché de Cocody, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2024-12-07', '08:46:00', 'Pièces automobiles', 51.33, 11.70, 135938.63, 'livree', 'created', NULL, NULL, NULL, 135938.63, 51.33, 476.00, 'urbain', 'standard', 'tres_urgent', 2, NULL, 1, '2024-12-04 00:00:00', NULL),
(238, 'CMD2025060238', 41, 'Marché de Cocody, Abidjan', 'Port de San-Pédro', '2025-03-22', '16:10:00', 'Produits pharmaceutiques', 57.14, 33.60, 62502.22, 'livree', 'created', NULL, NULL, NULL, 91753.34, 57.14, 158.00, 'regional', 'volumineux', 'urgent', 4, NULL, 1, '2025-03-21 00:00:00', NULL),
(239, 'CMD2025060239', 22, 'Marché de Cocody, Abidjan', 'Marché de Korhogo', '2025-04-27', '13:46:00', 'Mobilier et décoration', 32.12, 18.70, 153026.52, 'livree', 'created', NULL, NULL, NULL, 153026.52, 32.12, 716.00, 'urbain', 'volumineux', 'normal', 3, NULL, 1, '2025-04-24 00:00:00', NULL),
(240, 'CMD2025060240', 145, 'Zone Industrielle de Yamoussoukro', 'Centre-ville de Man', '2025-02-11', '09:25:00', 'Produits alimentaires', 17.44, 21.50, 57115.26, 'livree', 'created', NULL, NULL, NULL, 67738.33, 17.44, 376.00, 'periurbain', 'refrigere', 'normal', 6, NULL, 1, '2025-02-08 00:00:00', NULL),
(241, 'CMD2025060241', 146, 'Zone Industrielle Yopougon, Abidjan', 'Marché Central de Daloa', '2025-03-28', '12:14:00', 'Équipements électroniques', 182.29, 12.60, 935997.73, 'livree', 'created', NULL, NULL, NULL, 1122397.28, 182.29, 526.00, 'periurbain', 'dangereux', 'tres_urgent', 10, NULL, 1, '2025-03-27 00:00:00', NULL),
(242, 'CMD2025060242', 26, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2024-11-21', '16:47:00', 'Textiles et vêtements', 220.63, 35.10, 1158468.54, 'livree', 'created', NULL, NULL, NULL, 1389362.25, 220.63, 646.00, 'periurbain', 'refrigere', 'normal', 4, NULL, 1, '2024-11-18 00:00:00', NULL),
(243, 'CMD2025060243', 164, 'Zone Industrielle de Yamoussoukro', 'Zone Industrielle Yopougon, Abidjan', '2025-03-24', '14:21:00', 'Équipements électroniques', 1.46, 43.20, 10228.36, 'livree', 'created', NULL, NULL, NULL, 10228.36, 1.46, 790.00, 'urbain', 'standard', 'normal', 2, NULL, 1, '2025-03-17 00:00:00', NULL),
(244, 'CMD2025060244', 156, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2024-12-04', '18:20:00', 'Textiles et vêtements', 226.23, 31.00, 1258626.33, 'livree', 'created', NULL, NULL, NULL, 1258626.33, 226.23, 790.00, 'urbain', 'fragile', 'normal', 10, NULL, 1, '2024-11-28 00:00:00', NULL),
(245, 'CMD2025060245', 40, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-02-09', '13:16:00', 'Produits alimentaires', 63.19, 26.90, 44810.63, 'livree', 'created', NULL, NULL, NULL, 65215.95, 63.19, 92.00, 'regional', 'fragile', 'tres_urgent', 2, NULL, 1, '2025-02-08 00:00:00', NULL),
(246, 'CMD2025060246', 160, 'Zone Industrielle Yopougon, Abidjan', 'Centre-ville de Man', '2025-04-28', '14:52:00', 'Produits alimentaires', 84.70, 35.20, 441438.23, 'livree', 'created', NULL, NULL, NULL, 528925.88, 84.70, 797.00, 'periurbain', 'volumineux', 'normal', 10, NULL, 1, '2025-04-24 00:00:00', NULL),
(247, 'CMD2025060247', 86, 'Gare Routière de Bouaké', 'Marché de Korhogo', '2025-05-09', '14:23:00', 'Produits alimentaires', 67.07, 45.70, 38334.47, 'livree', 'created', NULL, NULL, NULL, 45201.36, 67.07, 79.00, 'periurbain', 'volumineux', 'tres_urgent', 5, NULL, 1, '2025-05-07 00:00:00', NULL),
(248, 'CMD2025060248', 114, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-03-25', '11:21:00', 'Pièces automobiles', 116.93, 23.10, 519492.92, 'livree', 'created', NULL, NULL, NULL, 519492.93, 116.93, 628.00, 'urbain', 'fragile', 'normal', 5, NULL, 1, '2025-03-20 00:00:00', NULL),
(249, 'CMD2025060249', 141, 'Zone Industrielle Yopougon, Abidjan', 'Zone Industrielle de Yamoussoukro', '2024-11-21', '10:58:00', 'Produits pharmaceutiques', 72.16, 21.10, 262035.50, 'livree', 'created', NULL, NULL, NULL, 313642.59, 72.16, 473.00, 'periurbain', 'urgent', 'normal', 9, NULL, 1, '2024-11-16 00:00:00', NULL),
(250, 'CMD2025060250', 182, 'Marché Central de Daloa', 'Gare Routière de Bouaké', '2025-02-03', '08:39:00', 'Produits alimentaires', 168.19, 43.40, 561196.65, 'livree', 'created', NULL, NULL, NULL, 561196.65, 168.19, 409.00, 'urbain', 'refrigere', 'urgent', 3, NULL, 1, '2025-01-29 00:00:00', NULL),
(251, 'CMD2025060251', 65, 'Marché de Korhogo', 'Marché de Cocody, Abidjan', '2025-03-21', '08:01:00', 'Matériel informatique', 104.59, 12.50, 241774.91, 'livree', 'created', NULL, NULL, NULL, 241774.91, 104.59, 421.00, 'urbain', 'standard', 'urgent', 2, NULL, 1, '2025-03-20 00:00:00', NULL),
(252, 'CMD2025060252', 53, 'Centre Commercial Playce, Marcory', 'Marché Central de Daloa', '2024-12-13', '12:02:00', 'Matériel informatique', 228.01, 11.70, 929287.38, 'livree', 'created', NULL, NULL, NULL, 1391931.07, 228.01, 501.00, 'regional', 'refrigere', 'tres_urgent', 8, NULL, 1, '2024-12-07 00:00:00', NULL),
(253, 'CMD2025060253', 73, 'Marché de Cocody, Abidjan', 'Port de San-Pédro', '2025-04-02', '18:42:00', 'Textiles et vêtements', 62.36, 45.90, 138697.60, 'livree', 'created', NULL, NULL, NULL, 206046.40, 62.36, 400.00, 'regional', 'standard', 'tres_urgent', 7, NULL, 1, '2025-04-01 00:00:00', NULL),
(254, 'CMD2025060254', 166, 'Gare Routière de Bouaké', 'Marché de Korhogo', '2025-02-27', '14:12:00', 'Produits alimentaires', 161.57, 37.90, 130509.31, 'livree', 'created', NULL, NULL, NULL, 193763.97, 161.57, 145.00, 'regional', 'standard', 'normal', 5, NULL, 1, '2025-02-21 00:00:00', NULL),
(255, 'CMD2025060255', 16, 'Centre-ville de Man', 'Marché de Cocody, Abidjan', '2025-05-31', '08:54:00', 'Matériel informatique', 48.21, 22.30, 34120.64, 'livree', 'created', NULL, NULL, NULL, 40144.78, 48.21, 89.00, 'periurbain', 'fragile', 'urgent', 4, NULL, 1, '2025-05-28 00:00:00', NULL),
(256, 'CMD2025060256', 5, 'Centre Commercial Playce, Marcory', 'Zone Industrielle de Yamoussoukro', '2025-04-11', '09:37:00', 'Équipements électroniques', 164.04, 29.40, 332637.74, 'livree', 'created', NULL, NULL, NULL, 398365.29, 164.04, 265.00, 'periurbain', 'urgent', 'normal', 8, NULL, 1, '2025-04-04 00:00:00', NULL),
(257, 'CMD2025060257', 189, 'Centre Commercial Playce, Marcory', 'Marché de Korhogo', '2025-05-17', '14:42:00', 'Matériaux de construction', 156.28, 39.60, 446041.11, 'livree', 'created', NULL, NULL, NULL, 667061.66, 156.28, 291.00, 'regional', 'dangereux', 'urgent', 8, NULL, 1, '2025-05-13 00:00:00', NULL),
(258, 'CMD2025060258', 75, 'Marché Central de Daloa', 'Centre-ville de Man', '2024-12-15', '11:05:00', 'Pièces automobiles', 169.74, 33.90, 391720.11, 'livree', 'created', NULL, NULL, NULL, 469264.13, 169.74, 235.00, 'periurbain', 'dangereux', 'normal', 5, NULL, 1, '2024-12-09 00:00:00', NULL),
(259, 'CMD2025060259', 108, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-01-26', '09:50:00', 'Matériaux de construction', 2.22, 19.00, 12139.85, 'livree', 'created', NULL, NULL, NULL, 13767.82, 2.22, 679.00, 'periurbain', 'standard', 'tres_urgent', 7, NULL, 1, '2025-01-21 00:00:00', NULL),
(260, 'CMD2025060260', 43, 'Zone Industrielle Yopougon, Abidjan', 'Centre Commercial Playce, Marcory', '2025-02-26', '14:52:00', 'Textiles et vêtements', 96.63, 49.40, 534463.91, 'livree', 'created', NULL, NULL, NULL, 799695.86, 96.63, 782.00, 'regional', 'fragile', 'urgent', 10, NULL, 1, '2025-02-19 00:00:00', NULL),
(261, 'CMD2025060261', 126, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2024-11-20', '15:24:00', 'Pièces automobiles', 203.47, 3.30, 469425.42, 'livree', 'created', NULL, NULL, NULL, 702138.12, 203.47, 353.00, 'regional', 'volumineux', 'normal', 2, NULL, 1, '2024-11-16 00:00:00', NULL),
(262, 'CMD2025060262', 188, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2025-01-27', '10:10:00', 'Produits pharmaceutiques', 158.63, 37.30, 85291.53, 'livree', 'created', NULL, NULL, NULL, 101549.84, 158.63, 73.00, 'periurbain', 'fragile', 'tres_urgent', 9, NULL, 1, '2025-01-20 00:00:00', NULL),
(263, 'CMD2025060263', 70, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-02-25', '17:55:00', 'Mobilier et décoration', 12.16, 38.30, 95955.87, 'livree', 'created', NULL, NULL, NULL, 141933.80, 12.16, 778.00, 'regional', 'dangereux', 'tres_urgent', 7, NULL, 1, '2025-02-18 00:00:00', NULL),
(264, 'CMD2025060264', 9, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2024-12-25', '14:21:00', 'Pièces automobiles', 127.78, 28.90, 193063.29, 'livree', 'created', NULL, NULL, NULL, 193063.29, 127.78, 274.00, 'urbain', 'standard', 'tres_urgent', 2, NULL, 1, '2024-12-21 00:00:00', NULL),
(265, 'CMD2025060265', 181, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-04-30', '08:37:00', 'Produits cosmétiques', 0.92, 44.00, 6976.83, 'livree', 'created', NULL, NULL, NULL, 8465.23, 0.92, 428.00, 'regional', 'urgent', 'urgent', 10, NULL, 1, '2025-04-27 00:00:00', NULL),
(266, 'CMD2025060266', 57, 'Marché de Korhogo', 'Marché de Cocody, Abidjan', '2025-03-30', '08:57:00', 'Équipements électroniques', 134.08, 29.70, 409675.13, 'livree', 'created', NULL, NULL, NULL, 612512.70, 134.08, 431.00, 'regional', 'fragile', 'normal', 3, NULL, 1, '2025-03-26 00:00:00', NULL),
(267, 'CMD2025060267', 167, 'Centre Commercial Playce, Marcory', 'Zone Industrielle de Yamoussoukro', '2025-01-11', '10:05:00', 'Matériel informatique', 152.88, 5.10, 892624.17, 'livree', 'created', NULL, NULL, NULL, 1336936.27, 152.88, 598.00, 'regional', 'dangereux', 'urgent', 8, NULL, 1, '2025-01-04 00:00:00', NULL),
(268, 'CMD2025060268', 137, 'Zone Industrielle de Yamoussoukro', 'Marché Central de Daloa', '2025-02-13', '12:30:00', 'Pièces automobiles', 222.29, 29.20, 28967.61, 'livree', 'created', NULL, NULL, NULL, 33961.14, 222.29, 16.00, 'periurbain', 'fragile', 'normal', 2, NULL, 1, '2025-02-08 00:00:00', NULL),
(269, 'CMD2025060269', 63, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-05-08', '18:16:00', 'Mobilier et décoration', 22.43, 25.10, 59958.36, 'livree', 'created', NULL, NULL, NULL, 59958.36, 22.43, 330.00, 'urbain', 'urgent', 'tres_urgent', 4, NULL, 1, '2025-05-02 00:00:00', NULL),
(270, 'CMD2025060270', 129, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2025-04-29', '15:23:00', 'Textiles et vêtements', 60.63, 43.80, 121537.32, 'livree', 'created', NULL, NULL, NULL, 180305.98, 60.63, 359.00, 'regional', 'standard', 'tres_urgent', 8, NULL, 1, '2025-04-23 00:00:00', NULL),
(271, 'CMD2025060271', 132, 'Zone Industrielle Yopougon, Abidjan', 'Centre Commercial Playce, Marcory', '2025-03-08', '17:37:00', 'Produits alimentaires', 74.24, 37.80, 377795.43, 'livree', 'created', NULL, NULL, NULL, 377795.44, 74.24, 666.00, 'urbain', 'urgent', 'urgent', 10, NULL, 1, '2025-03-01 00:00:00', NULL),
(272, 'CMD2025060272', 136, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2025-04-05', '17:57:00', 'Produits pharmaceutiques', 209.24, 12.10, 410762.56, 'livree', 'created', NULL, NULL, NULL, 614143.84, 209.24, 360.00, 'regional', 'standard', 'urgent', 6, NULL, 1, '2025-04-03 00:00:00', NULL),
(273, 'CMD2025060273', 178, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-06-06', '13:06:00', 'Textiles et vêtements', 217.55, 0.10, 1392578.14, 'livree', 'created', NULL, NULL, NULL, 2086867.21, 217.55, 788.00, 'regional', 'refrigere', 'tres_urgent', 4, NULL, 1, '2025-06-02 00:00:00', NULL),
(274, 'CMD2025060274', 85, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-01-29', '18:12:00', 'Produits alimentaires', 173.06, 50.00, 347811.38, 'livree', 'created', NULL, NULL, NULL, 347811.38, 173.06, 283.00, 'urbain', 'fragile', 'urgent', 8, NULL, 1, '2025-01-22 00:00:00', NULL),
(275, 'CMD2025060275', 11, 'Centre-ville de Man', 'Centre Commercial Playce, Marcory', '2025-05-05', '09:29:00', 'Matériel informatique', 168.82, 22.20, 511776.80, 'livree', 'created', NULL, NULL, NULL, 765665.20, 168.82, 557.00, 'regional', 'standard', 'tres_urgent', 1, NULL, 1, '2025-05-01 00:00:00', NULL),
(276, 'CMD2025060276', 105, 'Marché de Korhogo', 'Gare Routière de Bouaké', '2024-11-21', '11:09:00', 'Matériel informatique', 110.75, 3.20, 147053.56, 'livree', 'created', NULL, NULL, NULL, 175664.27, 110.75, 184.00, 'periurbain', 'fragile', 'normal', 10, NULL, 1, '2024-11-17 00:00:00', NULL),
(277, 'CMD2025060277', 42, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-01-13', '14:48:00', 'Produits pharmaceutiques', 232.81, 3.90, 788476.58, 'livree', 'created', NULL, NULL, NULL, 1180714.86, 232.81, 480.00, 'regional', 'fragile', 'normal', 4, NULL, 1, '2025-01-09 00:00:00', NULL),
(278, 'CMD2025060278', 4, 'Marché de Korhogo', 'Zone Industrielle de Yamoussoukro', '2024-12-22', '12:37:00', 'Produits pharmaceutiques', 27.68, 11.90, 105342.02, 'livree', 'created', NULL, NULL, NULL, 125610.42, 27.68, 678.00, 'periurbain', 'standard', 'normal', 3, NULL, 1, '2024-12-20 00:00:00', NULL),
(279, 'CMD2025060279', 174, 'Marché de Korhogo', 'Marché de Cocody, Abidjan', '2025-02-06', '17:52:00', 'Mobilier et décoration', 153.76, 42.00, 388098.63, 'livree', 'created', NULL, NULL, NULL, 388098.63, 153.76, 257.00, 'urbain', 'dangereux', 'normal', 10, NULL, 1, '2025-01-31 00:00:00', NULL),
(280, 'CMD2025060280', 62, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2025-01-01', '18:09:00', 'Produits cosmétiques', 144.69, 0.50, 226677.91, 'livree', 'created', NULL, NULL, NULL, 226677.91, 144.69, 190.00, 'urbain', 'refrigere', 'tres_urgent', 2, NULL, 1, '2024-12-27 00:00:00', NULL),
(281, 'CMD2025060281', 165, 'Marché de Korhogo', 'Port Autonome d\'Abidjan, Treichville', '2025-02-11', '11:02:00', 'Textiles et vêtements', 15.10, 35.40, 30296.65, 'livree', 'created', NULL, NULL, NULL, 30296.65, 15.10, 215.00, 'urbain', 'refrigere', 'urgent', 4, NULL, 1, '2025-02-06 00:00:00', NULL),
(282, 'CMD2025060282', 183, 'Port Autonome d\'Abidjan, Treichville', 'Port de San-Pédro', '2025-04-28', '09:08:00', 'Mobilier et décoration', 122.80, 43.70, 876533.30, 'livree', 'created', NULL, NULL, NULL, 1051039.95, 122.80, 731.00, 'periurbain', 'dangereux', 'normal', 2, NULL, 1, '2025-04-27 00:00:00', NULL),
(283, 'CMD2025060283', 45, 'Zone Industrielle de Yamoussoukro', 'Centre-ville de Man', '2024-11-21', '15:38:00', 'Pièces automobiles', 95.25, 1.40, 567830.47, 'livree', 'created', NULL, NULL, NULL, 680596.56, 95.25, 609.00, 'periurbain', 'dangereux', 'normal', 10, NULL, 1, '2024-11-17 00:00:00', NULL),
(284, 'CMD2025060284', 6, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2024-12-06', '08:05:00', 'Textiles et vêtements', 134.96, 48.20, 71266.76, 'livree', 'created', NULL, NULL, NULL, 71266.76, 134.96, 71.00, 'urbain', 'fragile', 'normal', 3, NULL, 1, '2024-11-30 00:00:00', NULL),
(285, 'CMD2025060285', 38, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2025-05-30', '14:58:00', 'Matériaux de construction', 71.37, 29.20, 113607.19, 'livree', 'created', NULL, NULL, NULL, 113607.20, 71.37, 237.00, 'urbain', 'volumineux', 'tres_urgent', 1, NULL, 1, '2025-05-27 00:00:00', NULL),
(286, 'CMD2025060286', 171, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2025-04-11', '16:22:00', 'Équipements électroniques', 110.23, 15.70, 161501.03, 'livree', 'created', NULL, NULL, NULL, 193001.22, 110.23, 147.00, 'periurbain', 'dangereux', 'normal', 9, NULL, 1, '2025-04-06 00:00:00', NULL),
(287, 'CMD2025060287', 99, 'Port Autonome d\'Abidjan, Treichville', 'Port de San-Pédro', '2025-03-28', '10:39:00', 'Pièces automobiles', 154.15, 3.40, 827503.21, 'livree', 'created', NULL, NULL, NULL, 1239254.83, 154.15, 761.00, 'regional', 'fragile', 'urgent', 7, NULL, 1, '2025-03-24 00:00:00', NULL),
(288, 'CMD2025060288', 67, 'Marché de Korhogo', 'Centre-ville de Man', '2025-01-29', '17:34:00', 'Pièces automobiles', 134.81, 1.30, 1012971.96, 'livree', 'created', NULL, NULL, NULL, 1012971.96, 134.81, 770.00, 'urbain', 'dangereux', 'urgent', 2, NULL, 1, '2025-01-27 00:00:00', NULL),
(289, 'CMD2025060289', 66, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-05-24', '15:03:00', 'Produits pharmaceutiques', 168.79, 10.00, 307700.47, 'livree', 'created', NULL, NULL, NULL, 459550.72, 168.79, 238.00, 'regional', 'urgent', 'urgent', 10, NULL, 1, '2025-05-18 00:00:00', NULL),
(290, 'CMD2025060290', 50, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2024-11-18', '13:28:00', 'Équipements électroniques', 178.27, 11.30, 1048483.93, 'livree', 'created', NULL, NULL, NULL, 1048483.93, 178.27, 775.00, 'urbain', 'urgent', 'tres_urgent', 5, NULL, 1, '2024-11-16 00:00:00', NULL),
(291, 'CMD2025060291', 195, 'Port Autonome d\'Abidjan, Treichville', 'Port de San-Pédro', '2024-11-27', '16:51:00', 'Mobilier et décoration', 174.09, 20.30, 346191.30, 'livree', 'created', NULL, NULL, NULL, 346191.30, 174.09, 364.00, 'urbain', 'standard', 'normal', 10, NULL, 1, '2024-11-24 00:00:00', NULL),
(292, 'CMD2025060292', 25, 'Marché de Cocody, Abidjan', 'Centre-ville de Man', '2025-01-11', '11:04:00', 'Matériaux de construction', 85.70, 35.10, 33432.81, 'livree', 'created', NULL, NULL, NULL, 48149.21, 85.70, 53.00, 'regional', 'volumineux', 'urgent', 8, NULL, 1, '2025-01-05 00:00:00', NULL),
(293, 'CMD2025060293', 103, 'Zone Industrielle de Yamoussoukro', 'Marché Central de Daloa', '2025-02-19', '13:48:00', 'Produits pharmaceutiques', 78.25, 0.10, 430521.97, 'livree', 'created', NULL, NULL, NULL, 430521.97, 78.25, 721.00, 'urbain', 'urgent', 'normal', 7, NULL, 1, '2025-02-12 00:00:00', NULL),
(294, 'CMD2025060294', 155, 'Port de San-Pédro', 'Marché de Korhogo', '2025-02-16', '10:41:00', 'Matériaux de construction', 183.10, 47.10, 682671.14, 'livree', 'created', NULL, NULL, NULL, 1022006.70, 183.10, 572.00, 'regional', 'volumineux', 'normal', 3, NULL, 1, '2025-02-10 00:00:00', NULL),
(295, 'CMD2025060295', 44, 'Marché de Cocody, Abidjan', 'Zone Industrielle Yopougon, Abidjan', '2025-03-03', '14:00:00', 'Matériel informatique', 194.74, 35.70, 271946.66, 'livree', 'created', NULL, NULL, NULL, 405920.00, 194.74, 196.00, 'regional', 'fragile', 'normal', 8, NULL, 1, '2025-02-27 00:00:00', NULL),
(296, 'CMD2025060296', 107, 'Marché Central de Daloa', 'Gare Routière de Bouaké', '2024-12-25', '15:27:00', 'Mobilier et décoration', 120.32, 6.60, 477261.88, 'livree', 'created', NULL, NULL, NULL, 477261.88, 120.32, 607.00, 'urbain', 'volumineux', 'tres_urgent', 1, NULL, 1, '2024-12-19 00:00:00', NULL),
(297, 'CMD2025060297', 169, 'Zone Industrielle de Yamoussoukro', 'Port Autonome d\'Abidjan, Treichville', '2024-12-10', '18:12:00', 'Mobilier et décoration', 18.07, 0.40, 49081.04, 'livree', 'created', NULL, NULL, NULL, 49081.04, 18.07, 462.00, 'urbain', 'standard', 'urgent', 4, NULL, 1, '2024-12-08 00:00:00', NULL),
(298, 'CMD2025060298', 180, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2025-03-13', '10:59:00', 'Matériaux de construction', 168.81, 48.70, 366441.82, 'livree', 'created', NULL, NULL, NULL, 547662.74, 168.81, 284.00, 'regional', 'urgent', 'normal', 8, NULL, 1, '2025-03-09 00:00:00', NULL),
(299, 'CMD2025060299', 71, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2024-12-22', '11:29:00', 'Mobilier et décoration', 183.88, 9.20, 518349.14, 'livree', 'created', NULL, NULL, NULL, 621218.97, 183.88, 370.00, 'periurbain', 'urgent', 'urgent', 4, NULL, 1, '2024-12-18 00:00:00', NULL),
(300, 'CMD2025060300', 147, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Korhogo', '2025-01-10', '11:13:00', 'Produits alimentaires', 74.18, 19.00, 113876.90, 'livree', 'created', NULL, NULL, NULL, 113876.90, 74.18, 211.00, 'urbain', 'fragile', 'normal', 9, NULL, 1, '2025-01-06 00:00:00', NULL),
(301, 'CMD2025060301', 34, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2025-03-16', '10:59:00', 'Matériaux de construction', 88.34, 0.80, 77702.06, 'livree', 'created', NULL, NULL, NULL, 114553.11, 88.34, 103.00, 'regional', 'refrigere', 'normal', 6, NULL, 1, '2025-03-11 00:00:00', NULL),
(302, 'CMD2025060302', 96, 'Marché de Cocody, Abidjan', 'Centre Commercial Playce, Marcory', '2025-06-11', '13:50:00', 'Matériaux de construction', 184.28, 0.80, 594101.42, 'livree', 'created', NULL, NULL, NULL, 712121.70, 184.28, 593.00, 'periurbain', 'standard', 'tres_urgent', 5, NULL, 1, '2025-06-04 00:00:00', NULL),
(303, 'CMD2025060303', 118, 'Port de San-Pédro', 'Marché de Cocody, Abidjan', '2025-04-17', '17:23:00', 'Équipements électroniques', 241.06, 19.40, 212275.84, 'livree', 'created', NULL, NULL, NULL, 253931.01, 241.06, 160.00, 'periurbain', 'standard', 'tres_urgent', 9, NULL, 1, '2025-04-14 00:00:00', NULL),
(304, 'CMD2025060304', 89, 'Centre-ville de Man', 'Marché Central de Daloa', '2025-05-04', '09:02:00', 'Textiles et vêtements', 214.25, 41.00, 875877.52, 'livree', 'created', NULL, NULL, NULL, 1311816.28, 214.25, 628.00, 'regional', 'volumineux', 'tres_urgent', 10, NULL, 1, '2025-04-28 00:00:00', NULL),
(305, 'CMD2025060305', 139, 'Marché de Cocody, Abidjan', 'Zone Industrielle de Yamoussoukro', '2025-05-14', '10:14:00', 'Produits alimentaires', 113.13, 39.00, 158069.48, 'livree', 'created', NULL, NULL, NULL, 235104.24, 113.13, 194.00, 'regional', 'fragile', 'normal', 3, NULL, 1, '2025-05-11 00:00:00', NULL),
(306, 'CMD2025060306', 113, 'Zone Industrielle Yopougon, Abidjan', 'Port de San-Pédro', '2025-03-27', '09:34:00', 'Textiles et vêtements', 80.10, 47.50, 83933.39, 'livree', 'created', NULL, NULL, NULL, 83933.39, 80.10, 132.00, 'urbain', 'urgent', 'normal', 5, NULL, 1, '2025-03-23 00:00:00', NULL),
(307, 'CMD2025060307', 8, 'Marché de Korhogo', 'Centre Commercial Playce, Marcory', '2025-03-10', '18:36:00', 'Textiles et vêtements', 58.21, 30.30, 174400.46, 'livree', 'created', NULL, NULL, NULL, 259600.70, 58.21, 417.00, 'regional', 'fragile', 'tres_urgent', 8, NULL, 1, '2025-03-06 00:00:00', NULL),
(308, 'CMD2025060308', 72, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2025-01-20', '15:05:00', 'Produits cosmétiques', 20.45, 43.10, 9598.80, 'livree', 'created', NULL, NULL, NULL, 10718.56, 20.45, 39.00, 'periurbain', 'fragile', 'normal', 6, NULL, 1, '2025-01-14 00:00:00', NULL),
(309, 'CMD2025060309', 84, 'Marché de Korhogo', 'Marché Central de Daloa', '2025-02-04', '13:50:00', 'Produits pharmaceutiques', 59.29, 30.60, 258339.87, 'livree', 'created', NULL, NULL, NULL, 258339.87, 59.29, 662.00, 'urbain', 'volumineux', 'tres_urgent', 8, NULL, 1, '2025-02-03 00:00:00', NULL),
(310, 'CMD2025060310', 120, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2025-01-25', '16:32:00', 'Produits alimentaires', 57.55, 13.00, 286800.70, 'livree', 'created', NULL, NULL, NULL, 286800.70, 57.55, 700.00, 'urbain', 'fragile', 'urgent', 7, NULL, 1, '2025-01-22 00:00:00', NULL),
(311, 'CMD2025060311', 140, 'Marché Central de Daloa', 'Zone Industrielle de Yamoussoukro', '2025-04-20', '09:19:00', 'Produits pharmaceutiques', 233.85, 2.90, 1235977.92, 'livree', 'created', NULL, NULL, NULL, 1851966.89, 233.85, 542.00, 'regional', 'dangereux', 'urgent', 8, NULL, 1, '2025-04-19 00:00:00', NULL),
(312, 'CMD2025060312', 13, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2024-12-15', '08:42:00', 'Produits alimentaires', 62.73, 15.50, 128657.06, 'livree', 'created', NULL, NULL, NULL, 190985.59, 62.73, 368.00, 'regional', 'standard', 'urgent', 5, NULL, 1, '2024-12-13 00:00:00', NULL),
(313, 'CMD2025060313', 153, 'Centre-ville de Man', 'Zone Industrielle de Yamoussoukro', '2025-04-02', '11:43:00', 'Produits alimentaires', 160.39, 29.80, 508420.13, 'livree', 'created', NULL, NULL, NULL, 760630.21, 160.39, 448.00, 'regional', 'fragile', 'urgent', 7, NULL, 1, '2025-04-01 00:00:00', NULL),
(314, 'CMD2025060314', 30, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2025-01-07', '12:42:00', 'Produits alimentaires', 34.95, 40.10, 47596.63, 'livree', 'created', NULL, NULL, NULL, 69394.95, 34.95, 154.00, 'regional', 'refrigere', 'normal', 10, NULL, 1, '2025-01-05 00:00:00', NULL),
(315, 'CMD2025060315', 143, 'Zone Industrielle de Yamoussoukro', 'Zone Industrielle Yopougon, Abidjan', '2025-03-19', '10:52:00', 'Produits cosmétiques', 34.14, 1.80, 138727.36, 'livree', 'created', NULL, NULL, NULL, 165672.84, 34.14, 522.00, 'periurbain', 'urgent', 'tres_urgent', 10, NULL, 1, '2025-03-14 00:00:00', NULL),
(316, 'CMD2025060316', 190, 'Gare Routière de Bouaké', 'Centre-ville de Man', '2024-12-30', '14:42:00', 'Pièces automobiles', 77.07, 48.30, 329617.67, 'livree', 'created', NULL, NULL, NULL, 329617.67, 77.07, 652.00, 'urbain', 'volumineux', 'urgent', 7, NULL, 1, '2024-12-28 00:00:00', NULL),
(317, 'CMD2025060317', 163, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2025-02-22', '16:30:00', 'Matériel informatique', 53.46, 36.40, 113122.55, 'livree', 'created', NULL, NULL, NULL, 134947.07, 53.46, 210.00, 'periurbain', 'dangereux', 'urgent', 4, NULL, 1, '2025-02-17 00:00:00', NULL),
(318, 'CMD2025060318', 119, 'Port de San-Pédro', 'Marché de Korhogo', '2024-12-15', '16:09:00', 'Matériel informatique', 119.28, 9.00, 639545.31, 'livree', 'created', NULL, NULL, NULL, 957317.98, 119.28, 759.00, 'regional', 'fragile', 'normal', 5, NULL, 1, '2024-12-08 00:00:00', NULL),
(319, 'CMD2025060319', 101, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-03-22', '09:28:00', 'Produits cosmétiques', 176.63, 10.50, 1016937.72, 'livree', 'created', NULL, NULL, NULL, 1016937.72, 176.63, 590.00, 'urbain', 'dangereux', 'normal', 5, NULL, 1, '2025-03-17 00:00:00', NULL),
(320, 'CMD2025060320', 79, 'Zone Industrielle de Yamoussoukro', 'Centre-ville de Man', '2025-04-17', '18:58:00', 'Produits cosmétiques', 247.21, 43.80, 434916.70, 'livree', 'created', NULL, NULL, NULL, 650375.06, 247.21, 269.00, 'regional', 'volumineux', 'tres_urgent', 1, NULL, 1, '2025-04-15 00:00:00', NULL),
(321, 'CMD2025060321', 131, 'Centre Commercial Playce, Marcory', 'Zone Industrielle Yopougon, Abidjan', '2025-01-15', '11:39:00', 'Produits pharmaceutiques', 189.57, 36.30, 1025835.38, 'livree', 'created', NULL, NULL, NULL, 1536753.07, 189.57, 713.00, 'regional', 'urgent', 'urgent', 9, NULL, 1, '2025-01-13 00:00:00', NULL),
(322, 'CMD2025060322', 95, 'Port Autonome d\'Abidjan, Treichville', 'Centre Commercial Playce, Marcory', '2025-02-26', '17:23:00', 'Produits cosmétiques', 119.01, 0.40, 480206.61, 'livree', 'created', NULL, NULL, NULL, 575447.93, 119.01, 741.00, 'periurbain', 'standard', 'tres_urgent', 10, NULL, 1, '2025-02-23 00:00:00', NULL),
(323, 'CMD2025060323', 93, 'Zone Industrielle Yopougon, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-02-20', '17:55:00', 'Matériaux de construction', 65.49, 18.60, 414052.54, 'livree', 'created', NULL, NULL, NULL, 496063.05, 65.49, 773.00, 'periurbain', 'refrigere', 'urgent', 6, NULL, 1, '2025-02-13 00:00:00', NULL);
INSERT INTO `commandes` (`id`, `numero_commande`, `client_id`, `adresse_depart`, `adresse_arrivee`, `date_prevue`, `heure_prevue`, `description`, `poids`, `volume`, `prix`, `statut`, `workflow_state`, `validated_by`, `validated_at`, `rejection_reason`, `tarif_auto`, `poids_kg`, `distance_km`, `zone_tarif`, `cargo_type`, `urgence`, `priorite`, `notes`, `active`, `date_creation`, `date_modification`) VALUES
(324, 'CMD2025060324', 176, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2024-11-21', '09:35:00', 'Matériaux de construction', 158.34, 34.90, 987462.41, 'livree', 'created', NULL, NULL, NULL, 1479193.60, 158.34, 639.00, 'regional', 'dangereux', 'tres_urgent', 4, NULL, 1, '2024-11-17 00:00:00', NULL),
(325, 'CMD2025060325', 56, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2024-12-16', '11:23:00', 'Mobilier et décoration', 72.68, 44.30, 266642.26, 'livree', 'created', NULL, NULL, NULL, 266642.27, 72.68, 478.00, 'urbain', 'urgent', 'urgent', 6, NULL, 1, '2024-12-13 00:00:00', NULL),
(326, 'CMD2025060326', 55, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-06-10', '12:15:00', 'Produits pharmaceutiques', 124.32, 22.20, 455938.01, 'livree', 'created', NULL, NULL, NULL, 546325.60, 124.32, 374.00, 'periurbain', 'dangereux', 'normal', 2, NULL, 1, '2025-06-03 00:00:00', NULL),
(327, 'CMD2025060327', 64, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2024-11-19', '13:10:00', 'Produits alimentaires', 101.04, 37.30, 522880.82, 'livree', 'created', NULL, NULL, NULL, 626656.98, 101.04, 634.00, 'periurbain', 'refrigere', 'tres_urgent', 2, NULL, 1, '2024-11-18 00:00:00', NULL),
(328, 'CMD2025060328', 46, 'Marché Central de Daloa', 'Zone Industrielle de Yamoussoukro', '2025-01-28', '17:59:00', 'Matériel informatique', 229.95, 14.50, 1060960.58, 'livree', 'created', NULL, NULL, NULL, 1589440.86, 229.95, 608.00, 'regional', 'urgent', 'normal', 7, NULL, 1, '2025-01-26 00:00:00', NULL),
(329, 'CMD2025060329', 142, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-03-06', '17:34:00', 'Textiles et vêtements', 36.08, 33.40, 134537.44, 'livree', 'created', NULL, NULL, NULL, 199806.16, 36.08, 670.00, 'regional', 'standard', 'normal', 6, NULL, 1, '2025-02-28 00:00:00', NULL),
(330, 'CMD2025060330', 23, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2025-01-17', '08:11:00', 'Équipements électroniques', 24.13, 5.70, 18411.40, 'livree', 'created', NULL, NULL, NULL, 21293.68, 24.13, 79.00, 'periurbain', 'urgent', 'normal', 3, NULL, 1, '2025-01-13 00:00:00', NULL),
(331, 'CMD2025060331', 117, 'Zone Industrielle de Yamoussoukro', 'Gare Routière de Bouaké', '2024-12-05', '10:16:00', 'Produits pharmaceutiques', 182.45, 19.30, 474053.23, 'livree', 'created', NULL, NULL, NULL, 474053.23, 182.45, 367.00, 'urbain', 'fragile', 'tres_urgent', 7, NULL, 1, '2024-12-02 00:00:00', NULL),
(332, 'CMD2025060332', 24, 'Centre-ville de Man', 'Marché de Korhogo', '2024-12-29', '14:20:00', 'Mobilier et décoration', 101.26, 1.90, 320052.71, 'livree', 'created', NULL, NULL, NULL, 320052.71, 101.26, 578.00, 'urbain', 'standard', 'normal', 4, NULL, 1, '2024-12-28 00:00:00', NULL),
(333, 'CMD2025060333', 39, 'Port de San-Pédro', 'Marché Central de Daloa', '2024-12-14', '18:33:00', 'Produits pharmaceutiques', 30.99, 16.30, 110181.04, 'livree', 'created', NULL, NULL, NULL, 110181.04, 30.99, 423.00, 'urbain', 'refrigere', 'urgent', 2, NULL, 1, '2024-12-09 00:00:00', NULL),
(334, 'CMD2025060334', 77, 'Port de San-Pédro', 'Port Autonome d\'Abidjan, Treichville', '2025-03-14', '13:22:00', 'Mobilier et décoration', 39.69, 29.50, 242416.24, 'livree', 'created', NULL, NULL, NULL, 361624.38, 39.69, 618.00, 'regional', 'dangereux', 'tres_urgent', 2, NULL, 1, '2025-03-07 00:00:00', NULL),
(335, 'CMD2025060335', 158, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-03-28', '18:31:00', 'Textiles et vêtements', 59.37, 26.90, 259837.20, 'livree', 'created', NULL, NULL, NULL, 387755.81, 59.37, 665.00, 'regional', 'volumineux', 'normal', 5, NULL, 1, '2025-03-21 00:00:00', NULL),
(336, 'CMD2025060336', 18, 'Marché Central de Daloa', 'Port de San-Pédro', '2024-12-15', '09:49:00', 'Pièces automobiles', 63.55, 22.00, 148131.40, 'livree', 'created', NULL, NULL, NULL, 220197.10, 63.55, 420.00, 'regional', 'standard', 'tres_urgent', 7, NULL, 1, '2024-12-14 00:00:00', NULL),
(337, 'CMD2025060337', 28, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2025-03-24', '15:08:00', 'Pièces automobiles', 175.97, 36.10, 667361.15, 'livree', 'created', NULL, NULL, NULL, 800033.38, 175.97, 537.00, 'periurbain', 'fragile', 'tres_urgent', 9, NULL, 1, '2025-03-23 00:00:00', NULL),
(338, 'CMD2025060338', 179, 'Port Autonome d\'Abidjan, Treichville', 'Centre Commercial Playce, Marcory', '2025-03-05', '17:23:00', 'Équipements électroniques', 41.55, 47.10, 22622.71, 'livree', 'created', NULL, NULL, NULL, 26347.25, 41.55, 83.00, 'periurbain', 'standard', 'tres_urgent', 3, NULL, 1, '2025-03-04 00:00:00', NULL),
(339, 'CMD2025060339', 196, 'Marché de Cocody, Abidjan', 'Marché de Korhogo', '2024-12-01', '15:01:00', 'Produits cosmétiques', 215.55, 9.60, 182785.79, 'livree', 'created', NULL, NULL, NULL, 182785.79, 215.55, 128.00, 'urbain', 'volumineux', 'tres_urgent', 7, NULL, 1, '2024-11-27 00:00:00', NULL),
(340, 'CMD2025060340', 138, 'Centre Commercial Playce, Marcory', 'Gare Routière de Bouaké', '2024-11-28', '12:32:00', 'Produits pharmaceutiques', 108.50, 33.70, 87197.80, 'livree', 'created', NULL, NULL, NULL, 128796.70, 108.50, 142.00, 'regional', 'standard', 'normal', 7, NULL, 1, '2024-11-24 00:00:00', NULL),
(341, 'CMD2025060341', 14, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2025-01-13', '12:52:00', 'Mobilier et décoration', 208.00, 11.60, 221563.84, 'livree', 'created', NULL, NULL, NULL, 330345.76, 208.00, 149.00, 'regional', 'fragile', 'normal', 6, NULL, 1, '2025-01-12 00:00:00', NULL),
(342, 'CMD2025060342', 106, 'Marché de Korhogo', 'Centre-ville de Man', '2025-05-02', '11:11:00', 'Pièces automobiles', 129.92, 6.80, 477347.93, 'livree', 'created', NULL, NULL, NULL, 477347.93, 129.92, 519.00, 'urbain', 'fragile', 'normal', 1, NULL, 1, '2025-05-01 00:00:00', NULL),
(343, 'CMD2025060343', 97, 'Marché de Korhogo', 'Port de San-Pédro', '2025-01-23', '15:20:00', 'Produits pharmaceutiques', 45.85, 37.60, 56588.12, 'livree', 'created', NULL, NULL, NULL, 56588.12, 45.85, 118.00, 'urbain', 'dangereux', 'normal', 8, NULL, 1, '2025-01-20 00:00:00', NULL),
(344, 'CMD2025060344', 69, 'Zone Industrielle de Yamoussoukro', 'Marché Central de Daloa', '2025-03-10', '14:21:00', 'Pièces automobiles', 110.25, 13.00, 149860.75, 'livree', 'created', NULL, NULL, NULL, 149860.75, 110.25, 175.00, 'urbain', 'urgent', 'tres_urgent', 4, NULL, 1, '2025-03-08 00:00:00', NULL),
(345, 'CMD2025060345', 161, 'Marché de Cocody, Abidjan', 'Centre Commercial Playce, Marcory', '2025-05-28', '12:12:00', 'Produits cosmétiques', 82.31, 24.40, 376735.90, 'livree', 'created', NULL, NULL, NULL, 376735.90, 82.31, 599.00, 'urbain', 'urgent', 'tres_urgent', 2, NULL, 1, '2025-05-27 00:00:00', NULL),
(346, 'CMD2025060346', 12, 'Port de San-Pédro', 'Marché de Korhogo', '2025-02-22', '18:02:00', 'Produits alimentaires', 81.93, 18.30, 144159.29, 'livree', 'created', NULL, NULL, NULL, 144159.29, 81.93, 176.00, 'urbain', 'dangereux', 'urgent', 9, NULL, 1, '2025-02-16 00:00:00', NULL),
(347, 'CMD2025060347', 104, 'Zone Industrielle Yopougon, Abidjan', 'Centre-ville de Man', '2025-04-22', '08:06:00', 'Produits alimentaires', 29.06, 49.50, 10967.43, 'livree', 'created', NULL, NULL, NULL, 10967.43, 29.06, 37.00, 'urbain', 'volumineux', 'tres_urgent', 2, NULL, 1, '2025-04-16 00:00:00', NULL),
(348, 'CMD2025060348', 173, 'Centre-ville de Man', 'Port de San-Pédro', '2025-04-15', '14:52:00', 'Textiles et vêtements', 143.10, 37.30, 451416.46, 'livree', 'created', NULL, NULL, NULL, 540899.75, 143.10, 579.00, 'periurbain', 'standard', 'urgent', 7, NULL, 1, '2025-04-13 00:00:00', NULL),
(349, 'CMD2025060349', 115, 'Port de San-Pédro', 'Zone Industrielle Yopougon, Abidjan', '2024-12-22', '11:33:00', 'Mobilier et décoration', 6.61, 29.90, 47111.21, 'livree', 'created', NULL, NULL, NULL, 68666.82, 6.61, 671.00, 'regional', 'dangereux', 'tres_urgent', 9, NULL, 1, '2024-12-18 00:00:00', NULL),
(350, 'CMD2025060350', 175, 'Marché de Cocody, Abidjan', 'Port de San-Pédro', '2025-03-01', '14:24:00', 'Produits pharmaceutiques', 108.05, 13.90, 528072.75, 'livree', 'created', NULL, NULL, NULL, 790109.14, 108.05, 499.00, 'regional', 'dangereux', 'tres_urgent', 3, NULL, 1, '2025-02-26 00:00:00', NULL),
(351, 'CMD2025060351', 100, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2025-04-22', '08:20:00', 'Pièces automobiles', 242.43, 35.60, 1051297.60, 'livree', 'created', NULL, NULL, NULL, 1260757.12, 242.43, 800.00, 'periurbain', 'standard', 'tres_urgent', 1, NULL, 1, '2025-04-17 00:00:00', NULL),
(352, 'CMD2025060352', 170, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-01-12', '14:55:00', 'Produits cosmétiques', 133.71, 14.60, 107972.90, 'livree', 'created', NULL, NULL, NULL, 159959.35, 133.71, 144.00, 'regional', 'standard', 'normal', 9, NULL, 1, '2025-01-10 00:00:00', NULL),
(353, 'CMD2025060353', 1, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2025-04-08', '15:36:00', 'Équipements électroniques', 37.42, 41.40, 111783.07, 'livree', 'created', NULL, NULL, NULL, 165674.62, 37.42, 381.00, 'regional', 'urgent', 'urgent', 4, NULL, 1, '2025-04-01 00:00:00', NULL),
(354, 'CMD2025060354', 80, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2025-04-30', '08:43:00', 'Matériaux de construction', 59.96, 7.20, 80348.27, 'livree', 'created', NULL, NULL, NULL, 95617.91, 59.96, 131.00, 'periurbain', 'dangereux', 'tres_urgent', 5, NULL, 1, '2025-04-23 00:00:00', NULL),
(355, 'CMD2025060355', 172, 'Marché de Cocody, Abidjan', 'Gare Routière de Bouaké', '2025-05-05', '18:20:00', 'Textiles et vêtements', 150.45, 13.80, 412002.35, 'livree', 'created', NULL, NULL, NULL, 412002.35, 150.45, 279.00, 'urbain', 'dangereux', 'tres_urgent', 3, NULL, 1, '2025-05-04 00:00:00', NULL),
(356, 'CMD2025060356', 68, 'Port Autonome d\'Abidjan, Treichville', 'Centre-ville de Man', '2025-04-09', '16:30:00', 'Matériel informatique', 121.61, 43.20, 453178.70, 'livree', 'created', NULL, NULL, NULL, 453178.70, 121.61, 570.00, 'urbain', 'volumineux', 'urgent', 10, NULL, 1, '2025-04-04 00:00:00', NULL),
(357, 'CMD2025060357', 49, 'Zone Industrielle de Yamoussoukro', 'Zone Industrielle Yopougon, Abidjan', '2025-01-04', '15:53:00', 'Matériaux de construction', 79.59, 15.90, 275280.92, 'livree', 'created', NULL, NULL, NULL, 329537.12, 79.59, 526.00, 'periurbain', 'volumineux', 'normal', 5, NULL, 1, '2024-12-30 00:00:00', NULL),
(358, 'CMD2025060358', 187, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2024-12-29', '09:38:00', 'Produits alimentaires', 20.91, 3.00, 27169.95, 'livree', 'created', NULL, NULL, NULL, 27169.95, 20.91, 171.00, 'urbain', 'volumineux', 'tres_urgent', 2, NULL, 1, '2024-12-26 00:00:00', NULL),
(359, 'CMD2025060359', 19, 'Zone Industrielle de Yamoussoukro', 'Centre-ville de Man', '2025-01-14', '16:23:00', 'Produits alimentaires', 126.79, 20.60, 467176.55, 'livree', 'created', NULL, NULL, NULL, 698764.84, 126.79, 451.00, 'regional', 'refrigere', 'normal', 5, NULL, 1, '2025-01-13 00:00:00', NULL),
(360, 'CMD2025060360', 91, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-01-02', '18:12:00', 'Pièces automobiles', 29.21, 24.50, 12517.64, 'en_cours', 'created', NULL, NULL, NULL, 16776.46, 29.21, 54.00, 'regional', 'standard', 'tres_urgent', 4, NULL, 1, '2025-01-01 00:00:00', NULL),
(361, 'CMD2025060361', 92, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Cocody, Abidjan', '2025-01-06', '12:08:00', 'Produits pharmaceutiques', 133.51, 31.10, 65569.47, 'en_cours', 'created', NULL, NULL, NULL, 65569.47, 133.51, 61.00, 'urbain', 'urgent', 'normal', 8, NULL, 1, '2025-01-04 00:00:00', NULL),
(362, 'CMD2025060362', 58, 'Centre-ville de Man', 'Port Autonome d\'Abidjan, Treichville', '2024-11-23', '16:54:00', 'Matériaux de construction', 234.10, 24.00, 824679.69, 'en_cours', 'created', NULL, NULL, NULL, 988815.63, 234.10, 541.00, 'periurbain', 'volumineux', 'normal', 1, NULL, 1, '2024-11-18 00:00:00', NULL),
(363, 'CMD2025060363', 112, 'Port Autonome d\'Abidjan, Treichville', 'Port de San-Pédro', '2025-02-25', '17:45:00', 'Pièces automobiles', 41.27, 22.70, 71080.26, 'en_cours', 'created', NULL, NULL, NULL, 104620.39, 41.27, 301.00, 'regional', 'standard', 'normal', 2, NULL, 1, '2025-02-20 00:00:00', NULL),
(364, 'CMD2025060364', 74, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2024-12-06', '11:50:00', 'Produits pharmaceutiques', 30.23, 36.00, 90844.74, 'en_cours', 'created', NULL, NULL, NULL, 90844.74, 30.23, 532.00, 'urbain', 'standard', 'tres_urgent', 3, NULL, 1, '2024-12-02 00:00:00', NULL),
(365, 'CMD2025060365', 135, 'Marché de Cocody, Abidjan', 'Centre Commercial Playce, Marcory', '2025-02-03', '13:51:00', 'Mobilier et décoration', 220.87, 42.60, 600945.35, 'en_cours', 'created', NULL, NULL, NULL, 899418.03, 220.87, 385.00, 'regional', 'fragile', 'normal', 4, NULL, 1, '2025-01-29 00:00:00', NULL),
(366, 'CMD2025060366', 48, 'Marché Central de Daloa', 'Marché de Korhogo', '2024-12-08', '14:29:00', 'Équipements électroniques', 200.80, 0.60, 591484.58, 'en_cours', 'created', NULL, NULL, NULL, 885226.86, 200.80, 301.00, 'regional', 'dangereux', 'tres_urgent', 10, NULL, 1, '2024-12-04 00:00:00', NULL),
(367, 'CMD2025060367', 102, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2025-05-27', '17:44:00', 'Équipements électroniques', 27.48, 48.40, 156695.37, 'en_cours', 'created', NULL, NULL, NULL, 156695.37, 27.48, 686.00, 'urbain', 'refrigere', 'urgent', 1, NULL, 1, '2025-05-20 00:00:00', NULL),
(368, 'CMD2025060368', 159, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2025-06-04', '14:20:00', 'Matériaux de construction', 237.68, 5.10, 462969.59, 'en_cours', 'created', NULL, NULL, NULL, 692454.39, 237.68, 298.00, 'regional', 'volumineux', 'normal', 10, NULL, 1, '2025-06-01 00:00:00', NULL),
(369, 'CMD2025060369', 110, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2024-12-03', '12:36:00', 'Matériaux de construction', 170.30, 33.80, 751651.06, 'en_cours', 'created', NULL, NULL, NULL, 1125476.59, 170.30, 542.00, 'regional', 'refrigere', 'tres_urgent', 10, NULL, 1, '2024-12-02 00:00:00', NULL),
(370, 'CMD2025060370', 111, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-04-24', '18:32:00', 'Matériel informatique', 211.49, 45.90, 896280.54, 'en_cours', 'created', NULL, NULL, NULL, 1342420.82, 211.49, 601.00, 'regional', 'fragile', 'normal', 3, NULL, 1, '2025-04-22 00:00:00', NULL),
(371, 'CMD2025060371', 27, 'Port Autonome d\'Abidjan, Treichville', 'Centre Commercial Playce, Marcory', '2025-04-11', '13:46:00', 'Produits pharmaceutiques', 122.37, 50.00, 376690.07, 'en_cours', 'created', NULL, NULL, NULL, 451228.08, 122.37, 470.00, 'periurbain', 'volumineux', 'tres_urgent', 2, NULL, 1, '2025-04-09 00:00:00', NULL),
(372, 'CMD2025060372', 157, 'Gare Routière de Bouaké', 'Marché Central de Daloa', '2025-05-12', '17:12:00', 'Matériaux de construction', 211.07, 33.00, 830339.05, 'en_cours', 'created', NULL, NULL, NULL, 995606.86, 211.07, 725.00, 'periurbain', 'standard', 'urgent', 1, NULL, 1, '2025-05-11 00:00:00', NULL),
(373, 'CMD2025060373', 15, 'Gare Routière de Bouaké', 'Port de San-Pédro', '2025-03-15', '12:55:00', 'Équipements électroniques', 248.56, 5.60, 523440.69, 'en_cours', 'created', NULL, NULL, NULL, 783161.04, 248.56, 387.00, 'regional', 'standard', 'tres_urgent', 5, NULL, 1, '2025-03-13 00:00:00', NULL),
(374, 'CMD2025060374', 61, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-01-14', '13:15:00', 'Matériel informatique', 84.28, 16.80, 41137.14, 'en_cours', 'created', NULL, NULL, NULL, 41137.14, 84.28, 68.00, 'urbain', 'volumineux', 'urgent', 5, NULL, 1, '2025-01-13 00:00:00', NULL),
(375, 'CMD2025060375', 186, 'Gare Routière de Bouaké', 'Zone Industrielle de Yamoussoukro', '2025-05-04', '16:26:00', 'Produits pharmaceutiques', 100.38, 19.50, 21345.66, 'en_cours', 'created', NULL, NULL, NULL, 30018.49, 100.38, 32.00, 'regional', 'standard', 'urgent', 7, NULL, 1, '2025-04-28 00:00:00', NULL),
(376, 'CMD2025060376', 3, 'Port Autonome d\'Abidjan, Treichville', 'Centre Commercial Playce, Marcory', '2025-05-02', '10:56:00', 'Mobilier et décoration', 29.89, 46.80, 113594.67, 'en_cours', 'created', NULL, NULL, NULL, 135513.61, 29.89, 485.00, 'periurbain', 'urgent', 'tres_urgent', 5, NULL, 1, '2025-04-26 00:00:00', NULL),
(377, 'CMD2025060377', 148, 'Marché de Korhogo', 'Marché de Cocody, Abidjan', '2024-12-04', '16:58:00', 'Produits pharmaceutiques', 82.71, 33.50, 165324.20, 'en_cours', 'created', NULL, NULL, NULL, 245986.30, 82.71, 258.00, 'regional', 'urgent', 'urgent', 6, NULL, 1, '2024-12-03 00:00:00', NULL),
(378, 'CMD2025060378', 54, 'Zone Industrielle Yopougon, Abidjan', 'Marché de Cocody, Abidjan', '2025-01-17', '10:58:00', 'Équipements électroniques', 161.26, 21.10, 819072.54, 'en_cours', 'created', NULL, NULL, NULL, 982087.05, 161.26, 780.00, 'periurbain', 'volumineux', 'urgent', 10, NULL, 1, '2025-01-12 00:00:00', NULL),
(379, 'CMD2025060379', 51, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2024-11-23', '13:37:00', 'Textiles et vêtements', 58.10, 47.40, 357522.23, 'en_cours', 'created', NULL, NULL, NULL, 428226.68, 58.10, 626.00, 'periurbain', 'dangereux', 'normal', 9, NULL, 1, '2024-11-20 00:00:00', NULL),
(380, 'CMD2025060380', 185, 'Zone Industrielle de Yamoussoukro', 'Zone Industrielle Yopougon, Abidjan', '2025-01-10', '09:11:00', 'Textiles et vêtements', 25.22, 14.40, 41587.89, 'en_cours', 'created', NULL, NULL, NULL, 60381.84, 25.22, 276.00, 'regional', 'standard', 'normal', 8, NULL, 1, '2025-01-07 00:00:00', NULL),
(381, 'CMD2025060381', 168, 'Centre-ville de Man', 'Marché Central de Daloa', '2025-05-30', '08:00:00', 'Mobilier et décoration', 135.72, 39.30, 469383.88, 'en_cours', 'created', NULL, NULL, NULL, 469383.88, 135.72, 635.00, 'urbain', 'standard', 'normal', 7, NULL, 1, '2025-05-28 00:00:00', NULL),
(382, 'CMD2025060382', 20, 'Marché de Cocody, Abidjan', 'Zone Industrielle Yopougon, Abidjan', '2025-05-25', '08:18:00', 'Matériaux de construction', 12.78, 15.90, 74723.50, 'en_cours', 'created', NULL, NULL, NULL, 74723.49, 12.78, 732.00, 'urbain', 'urgent', 'tres_urgent', 8, NULL, 1, '2025-05-18 00:00:00', NULL),
(383, 'CMD2025060383', 192, 'Marché de Korhogo', 'Marché Central de Daloa', '2025-04-24', '09:17:00', 'Pièces automobiles', 115.45, 26.30, 45520.44, 'en_cours', 'created', NULL, NULL, NULL, 45520.44, 115.45, 37.00, 'urbain', 'dangereux', 'urgent', 8, NULL, 1, '2025-04-18 00:00:00', NULL),
(384, 'CMD2025060384', 94, 'Gare Routière de Bouaké', 'Zone Industrielle Yopougon, Abidjan', '2025-01-09', '15:21:00', 'Textiles et vêtements', 93.82, 20.60, 486563.17, 'en_cours', 'created', NULL, NULL, NULL, 583075.81, 93.82, 635.00, 'periurbain', 'refrigere', 'urgent', 10, NULL, 1, '2025-01-02 00:00:00', NULL),
(385, 'CMD2025060385', 17, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-05-17', '13:37:00', 'Textiles et vêtements', 45.04, 27.70, 83677.56, 'en_cours', 'created', NULL, NULL, NULL, 99613.07, 45.04, 182.00, 'periurbain', 'dangereux', 'tres_urgent', 7, NULL, 1, '2025-05-15 00:00:00', NULL),
(386, 'CMD2025060386', 123, 'Centre Commercial Playce, Marcory', 'Port de San-Pédro', '2024-11-26', '10:56:00', 'Produits pharmaceutiques', 195.96, 25.20, 1103982.27, 'en_cours', 'created', NULL, NULL, NULL, 1323978.72, 195.96, 693.00, 'periurbain', 'refrigere', 'normal', 8, NULL, 1, '2024-11-20 00:00:00', NULL),
(387, 'CMD2025060387', 29, 'Centre-ville de Man', 'Zone Industrielle Yopougon, Abidjan', '2025-01-26', '14:03:00', 'Pièces automobiles', 178.29, 44.60, 830630.89, 'en_cours', 'created', NULL, NULL, NULL, 1243946.33, 178.29, 477.00, 'regional', 'dangereux', 'urgent', 5, NULL, 1, '2025-01-19 00:00:00', NULL),
(388, 'CMD2025060388', 130, 'Centre Commercial Playce, Marcory', 'Zone Industrielle Yopougon, Abidjan', '2024-11-21', '17:14:00', 'Équipements électroniques', 87.69, 35.90, 205911.49, 'en_cours', 'created', NULL, NULL, NULL, 306867.24, 87.69, 328.00, 'regional', 'fragile', 'normal', 6, NULL, 1, '2024-11-17 00:00:00', NULL),
(389, 'CMD2025060389', 134, 'Port de San-Pédro', 'Marché de Korhogo', '2025-02-09', '18:56:00', 'Produits pharmaceutiques', 196.55, 13.90, 236440.03, 'en_cours', 'created', NULL, NULL, NULL, 282928.03, 196.55, 146.00, 'periurbain', 'refrigere', 'tres_urgent', 6, NULL, 1, '2025-02-04 00:00:00', NULL),
(390, 'CMD2025060390', 149, 'Marché de Korhogo', 'Port Autonome d\'Abidjan, Treichville', '2025-01-05', '18:59:00', 'Textiles et vêtements', 21.92, 20.90, 40469.18, 'en_cours', 'created', NULL, NULL, NULL, 58703.78, 21.92, 237.00, 'regional', 'fragile', 'urgent', 4, NULL, 1, '2025-01-02 00:00:00', NULL),
(391, 'CMD2025060391', 152, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Korhogo', '2025-02-06', '11:46:00', 'Matériel informatique', 107.54, 0.80, 403822.97, 'en_cours', 'created', NULL, NULL, NULL, 403822.96, 107.54, 459.00, 'urbain', 'refrigere', 'tres_urgent', 1, NULL, 1, '2025-02-05 00:00:00', NULL),
(392, 'CMD2025060392', 128, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-05-18', '15:10:00', 'Textiles et vêtements', 129.89, 14.20, 309813.02, 'en_cours', 'created', NULL, NULL, NULL, 309813.02, 129.89, 436.00, 'urbain', 'standard', 'urgent', 4, NULL, 1, '2025-05-17 00:00:00', NULL),
(393, 'CMD2025060393', 116, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-01-16', '13:21:00', 'Mobilier et décoration', 218.58, 12.30, 619307.07, 'en_cours', 'created', NULL, NULL, NULL, 619307.07, 218.58, 401.00, 'urbain', 'fragile', 'urgent', 9, NULL, 1, '2025-01-12 00:00:00', NULL),
(394, 'CMD2025060394', 144, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2025-02-20', '12:07:00', 'Produits alimentaires', 4.15, 10.00, 28135.57, 'en_cours', 'created', NULL, NULL, NULL, 40203.36, 4.15, 718.00, 'regional', 'refrigere', 'normal', 9, NULL, 1, '2025-02-18 00:00:00', NULL),
(395, 'CMD2025060395', 133, 'Centre-ville de Man', 'Zone Industrielle de Yamoussoukro', '2025-03-20', '18:12:00', 'Mobilier et décoration', 189.97, 1.00, 280976.26, 'en_cours', 'created', NULL, NULL, NULL, 280976.26, 189.97, 270.00, 'urbain', 'standard', 'urgent', 8, NULL, 1, '2025-03-15 00:00:00', NULL),
(396, 'CMD2025060396', 60, 'Zone Industrielle Yopougon, Abidjan', 'Gare Routière de Bouaké', '2025-03-07', '16:45:00', 'Produits alimentaires', 172.12, 46.60, 519843.64, 'en_cours', 'created', NULL, NULL, NULL, 519843.64, 172.12, 555.00, 'urbain', 'standard', 'urgent', 7, NULL, 1, '2025-02-28 00:00:00', NULL),
(397, 'CMD2025060397', 154, 'Zone Industrielle Yopougon, Abidjan', 'Zone Industrielle de Yamoussoukro', '2025-03-14', '14:23:00', 'Produits alimentaires', 82.54, 1.50, 72640.26, 'en_cours', 'created', NULL, NULL, NULL, 72640.26, 82.54, 110.00, 'urbain', 'urgent', 'urgent', 10, NULL, 1, '2025-03-13 00:00:00', NULL),
(398, 'CMD2025060398', 2, 'Marché de Korhogo', 'Centre-ville de Man', '2024-11-24', '13:21:00', 'Produits alimentaires', 249.80, 17.40, 45276.95, 'en_cours', 'created', NULL, NULL, NULL, 45276.95, 249.80, 17.00, 'urbain', 'dangereux', 'tres_urgent', 7, NULL, 1, '2024-11-23 00:00:00', NULL),
(399, 'CMD2025060399', 177, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-05-06', '17:07:00', 'Produits cosmétiques', 69.43, 24.00, 105228.94, 'en_cours', 'created', NULL, NULL, NULL, 125474.73, 69.43, 150.00, 'periurbain', 'dangereux', 'normal', 10, NULL, 1, '2025-05-02 00:00:00', NULL),
(400, 'CMD2025060400', 82, 'Gare Routière de Bouaké', 'Zone Industrielle Yopougon, Abidjan', '2025-04-04', '15:04:00', 'Équipements électroniques', 207.93, 43.60, 1188352.65, 'en_cours', 'created', NULL, NULL, NULL, 1425223.17, 207.93, 586.00, 'periurbain', 'dangereux', 'normal', 7, NULL, 1, '2025-04-03 00:00:00', NULL),
(401, 'CMD2025060401', 10, 'Zone Industrielle Yopougon, Abidjan', 'Centre-ville de Man', '2025-04-24', '12:33:00', 'Équipements électroniques', 216.71, 12.90, 1031933.55, 'en_cours', 'created', NULL, NULL, NULL, 1237520.25, 216.71, 488.00, 'periurbain', 'dangereux', 'normal', 3, NULL, 1, '2025-04-21 00:00:00', NULL),
(402, 'CMD2025060402', 90, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2025-04-22', '16:35:00', 'Matériel informatique', 140.91, 33.70, 435438.24, 'en_cours', 'created', NULL, NULL, NULL, 435438.24, 140.91, 567.00, 'urbain', 'standard', 'normal', 5, NULL, 1, '2025-04-21 00:00:00', NULL),
(403, 'CMD2025060403', 81, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-02-19', '08:31:00', 'Produits alimentaires', 223.61, 35.30, 567295.95, 'en_cours', 'created', NULL, NULL, NULL, 848943.93, 223.61, 311.00, 'regional', 'refrigere', 'tres_urgent', 3, NULL, 1, '2025-02-12 00:00:00', NULL),
(404, 'CMD2025060404', 59, 'Zone Industrielle de Yamoussoukro', 'Port Autonome d\'Abidjan, Treichville', '2024-11-27', '14:05:00', 'Textiles et vêtements', 31.25, 24.80, 82671.25, 'en_cours', 'created', NULL, NULL, NULL, 98405.50, 31.25, 333.00, 'periurbain', 'urgent', 'urgent', 8, NULL, 1, '2024-11-20 00:00:00', NULL),
(405, 'CMD2025060405', 36, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle de Yamoussoukro', '2025-04-19', '10:10:00', 'Matériaux de construction', 168.47, 27.20, 689214.66, 'en_cours', 'created', NULL, NULL, NULL, 1031821.98, 168.47, 538.00, 'regional', 'urgent', 'urgent', 5, NULL, 1, '2025-04-12 00:00:00', NULL),
(406, 'CMD2025060406', 151, 'Centre-ville de Man', 'Marché de Cocody, Abidjan', '2024-12-17', '14:36:00', 'Matériel informatique', 123.24, 7.60, 686798.90, 'en_cours', 'created', NULL, NULL, NULL, 686798.89, 123.24, 684.00, 'urbain', 'refrigere', 'tres_urgent', 1, NULL, 1, '2024-12-15 00:00:00', NULL),
(407, 'CMD2025060407', 98, 'Centre-ville de Man', 'Marché Central de Daloa', '2025-06-01', '17:36:00', 'Matériaux de construction', 61.72, 48.30, 219970.62, 'en_cours', 'created', NULL, NULL, NULL, 219970.62, 61.72, 648.00, 'urbain', 'standard', 'normal', 3, NULL, 1, '2025-05-25 00:00:00', NULL),
(408, 'CMD2025060408', 76, 'Marché de Cocody, Abidjan', 'Port Autonome d\'Abidjan, Treichville', '2025-04-07', '14:31:00', 'Produits cosmétiques', 11.48, 43.40, 20403.08, 'en_cours', 'created', NULL, NULL, NULL, 20403.08, 11.48, 147.00, 'urbain', 'dangereux', 'urgent', 2, NULL, 1, '2025-04-01 00:00:00', NULL),
(409, 'CMD2025060409', 35, 'Marché de Korhogo', 'Centre Commercial Playce, Marcory', '2025-03-25', '11:52:00', 'Produits alimentaires', 109.73, 32.40, 56380.71, 'en_cours', 'created', NULL, NULL, NULL, 66856.86, 109.73, 68.00, 'periurbain', 'fragile', 'urgent', 4, NULL, 1, '2025-03-22 00:00:00', NULL),
(410, 'CMD2025060410', 32, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2025-04-18', '17:45:00', 'Mobilier et décoration', 228.92, 35.50, 374850.40, 'en_cours', 'created', NULL, NULL, NULL, 374850.40, 228.92, 250.00, 'urbain', 'volumineux', 'urgent', 2, NULL, 1, '2025-04-15 00:00:00', NULL),
(411, 'CMD2025060411', 37, 'Gare Routière de Bouaké', 'Zone Industrielle Yopougon, Abidjan', '2025-02-01', '17:28:00', 'Textiles et vêtements', 12.40, 17.90, 63862.24, 'en_cours', 'created', NULL, NULL, NULL, 75834.69, 12.40, 596.00, 'periurbain', 'refrigere', 'normal', 2, NULL, 1, '2025-01-26 00:00:00', NULL),
(412, 'CMD2025060412', 78, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-01-26', '18:33:00', 'Textiles et vêtements', 144.40, 10.70, 322765.89, 'en_cours', 'created', NULL, NULL, NULL, 322765.89, 144.40, 292.00, 'urbain', 'urgent', 'tres_urgent', 9, NULL, 1, '2025-01-22 00:00:00', NULL),
(413, 'CMD2025060413', 191, 'Port Autonome d\'Abidjan, Treichville', 'Marché Central de Daloa', '2025-04-06', '17:03:00', 'Produits alimentaires', 160.24, 4.40, 46832.15, 'en_cours', 'created', NULL, NULL, NULL, 68248.24, 160.24, 33.00, 'regional', 'refrigere', 'normal', 6, NULL, 1, '2025-03-30 00:00:00', NULL),
(414, 'CMD2025060414', 83, 'Port Autonome d\'Abidjan, Treichville', 'Marché Central de Daloa', '2025-05-13', '18:15:00', 'Pièces automobiles', 148.37, 10.80, 531829.24, 'en_cours', 'created', NULL, NULL, NULL, 531829.24, 148.37, 549.00, 'urbain', 'volumineux', 'urgent', 4, NULL, 1, '2025-05-07 00:00:00', NULL),
(415, 'CMD2025060415', 7, 'Centre Commercial Playce, Marcory', 'Marché Central de Daloa', '2025-01-26', '17:25:00', 'Textiles et vêtements', 113.89, 10.70, 353077.41, 'en_cours', 'created', NULL, NULL, NULL, 527616.11, 113.89, 473.00, 'regional', 'volumineux', 'normal', 7, NULL, 1, '2025-01-19 00:00:00', NULL),
(416, 'CMD2025060416', 122, 'Port de San-Pédro', 'Marché de Korhogo', '2024-11-26', '09:07:00', 'Textiles et vêtements', 3.69, 43.80, 8064.90, 'en_cours', 'created', NULL, NULL, NULL, 10097.35, 3.69, 204.00, 'regional', 'standard', 'urgent', 7, NULL, 1, '2024-11-22 00:00:00', NULL),
(417, 'CMD2025060417', 109, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2024-11-20', '15:37:00', 'Textiles et vêtements', 218.30, 20.40, 1027215.76, 'en_cours', 'created', NULL, NULL, NULL, 1231858.91, 218.30, 620.00, 'periurbain', 'urgent', 'urgent', 4, NULL, 1, '2024-11-19 00:00:00', NULL),
(418, 'CMD2025060418', 47, 'Centre-ville de Man', 'Port Autonome d\'Abidjan, Treichville', '2024-12-05', '08:12:00', 'Produits pharmaceutiques', 66.92, 18.70, 398071.80, 'en_cours', 'created', NULL, NULL, NULL, 476886.18, 66.92, 727.00, 'periurbain', 'refrigere', 'tres_urgent', 6, NULL, 1, '2024-12-03 00:00:00', NULL),
(419, 'CMD2025060419', 125, 'Port de San-Pédro', 'Centre Commercial Playce, Marcory', '2024-12-17', '13:01:00', 'Matériaux de construction', 89.59, 3.50, 530262.41, 'en_cours', 'created', NULL, NULL, NULL, 793393.61, 89.59, 777.00, 'regional', 'urgent', 'normal', 6, NULL, 1, '2024-12-11 00:00:00', NULL),
(420, 'CMD2025060420', 31, 'Marché de Korhogo', 'Port de San-Pédro', '2025-01-23', '14:59:00', 'Pièces automobiles', 190.96, 42.00, 471745.06, 'en_cours', 'created', NULL, NULL, NULL, 471745.07, 190.96, 324.00, 'urbain', 'urgent', 'urgent', 7, NULL, 1, '2025-01-22 00:00:00', NULL),
(421, 'CMD2025060421', 33, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-01-12', '16:43:00', 'Produits alimentaires', 176.68, 8.20, 383720.66, 'en_cours', 'created', NULL, NULL, NULL, 573580.99, 176.68, 398.00, 'regional', 'standard', 'urgent', 2, NULL, 1, '2025-01-05 00:00:00', NULL),
(422, 'CMD2025060422', 124, 'Zone Industrielle Yopougon, Abidjan', 'Port de San-Pédro', '2025-04-10', '15:00:00', 'Produits alimentaires', 229.04, 40.40, 566751.28, 'en_cours', 'created', NULL, NULL, NULL, 679301.54, 229.04, 455.00, 'periurbain', 'standard', 'urgent', 6, NULL, 1, '2025-04-03 00:00:00', NULL),
(423, 'CMD2025060423', 193, 'Centre-ville de Man', 'Marché de Korhogo', '2025-04-08', '09:13:00', 'Pièces automobiles', 102.05, 15.00, 124353.69, 'en_cours', 'created', NULL, NULL, NULL, 184530.53, 102.05, 156.00, 'regional', 'urgent', 'tres_urgent', 9, NULL, 1, '2025-04-07 00:00:00', NULL),
(424, 'CMD2025060424', 21, 'Port Autonome d\'Abidjan, Treichville', 'Marché de Cocody, Abidjan', '2024-12-31', '12:36:00', 'Produits alimentaires', 68.03, 40.40, 379848.06, 'en_cours', 'created', NULL, NULL, NULL, 455017.67, 68.03, 787.00, 'periurbain', 'fragile', 'urgent', 8, NULL, 1, '2024-12-27 00:00:00', NULL),
(425, 'CMD2025060425', 127, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-05-15', '18:08:00', 'Produits pharmaceutiques', 65.20, 27.10, 220493.99, 'en_cours', 'created', NULL, NULL, NULL, 220493.99, 65.20, 473.00, 'urbain', 'fragile', 'urgent', 2, NULL, 1, '2025-05-10 00:00:00', NULL),
(426, 'CMD2025060426', 52, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-05-05', '12:45:00', 'Textiles et vêtements', 72.32, 42.30, 155798.23, 'en_cours', 'created', NULL, NULL, NULL, 231697.35, 72.32, 299.00, 'regional', 'fragile', 'urgent', 4, NULL, 1, '2025-04-28 00:00:00', NULL),
(427, 'CMD2025060427', 87, 'Marché de Cocody, Abidjan', 'Zone Industrielle de Yamoussoukro', '2024-12-14', '16:40:00', 'Matériel informatique', 62.02, 24.70, 353643.95, 'en_cours', 'created', NULL, NULL, NULL, 353643.96, 62.02, 696.00, 'urbain', 'refrigere', 'urgent', 2, NULL, 1, '2024-12-08 00:00:00', NULL),
(428, 'CMD2025060428', 194, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-01-23', '10:38:00', 'Matériel informatique', 239.08, 27.30, 1108606.98, 'en_cours', 'created', NULL, NULL, NULL, 1108606.98, 239.08, 713.00, 'urbain', 'volumineux', 'normal', 3, NULL, 1, '2025-01-19 00:00:00', NULL),
(429, 'CMD2025060429', 150, 'Port de San-Pédro', 'Zone Industrielle de Yamoussoukro', '2025-03-05', '08:24:00', 'Équipements électroniques', 198.75, 39.30, 350445.10, 'en_cours', 'created', NULL, NULL, NULL, 419734.12, 198.75, 269.00, 'periurbain', 'volumineux', 'normal', 8, NULL, 1, '2025-03-04 00:00:00', NULL),
(430, 'CMD2025060430', 88, 'Port Autonome d\'Abidjan, Treichville', 'Port de San-Pédro', '2025-04-21', '18:54:00', 'Produits cosmétiques', 207.37, 12.40, 108813.09, 'en_cours', 'created', NULL, NULL, NULL, 161219.65, 207.37, 52.00, 'regional', 'dangereux', 'tres_urgent', 4, NULL, 1, '2025-04-20 00:00:00', NULL),
(431, 'CMD2025060431', 184, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2025-02-24', '14:33:00', 'Textiles et vêtements', 125.35, 42.30, 73042.78, 'en_cours', 'created', NULL, NULL, NULL, 86851.33, 125.35, 68.00, 'periurbain', 'refrigere', 'urgent', 7, NULL, 1, '2025-02-19 00:00:00', NULL),
(432, 'CMD2025060432', 41, 'Marché de Korhogo', 'Port Autonome d\'Abidjan, Treichville', '2025-05-10', '09:43:00', 'Produits alimentaires', 160.11, 38.50, 755159.27, 'en_cours', 'created', NULL, NULL, NULL, 755159.27, 160.11, 724.00, 'urbain', 'volumineux', 'tres_urgent', 4, NULL, 1, '2025-05-06 00:00:00', NULL),
(433, 'CMD2025060433', 22, 'Marché de Cocody, Abidjan', 'Zone Industrielle Yopougon, Abidjan', '2025-02-18', '12:45:00', 'Produits pharmaceutiques', 90.41, 38.70, 214908.45, 'en_cours', 'created', NULL, NULL, NULL, 320362.68, 90.41, 288.00, 'regional', 'refrigere', 'tres_urgent', 5, NULL, 1, '2025-02-12 00:00:00', NULL),
(434, 'CMD2025060434', 145, 'Zone Industrielle de Yamoussoukro', 'Centre Commercial Playce, Marcory', '2025-01-10', '10:17:00', 'Équipements électroniques', 52.71, 15.90, 118252.09, 'en_cours', 'created', NULL, NULL, NULL, 118252.08, 52.71, 223.00, 'urbain', 'dangereux', 'urgent', 3, NULL, 1, '2025-01-05 00:00:00', NULL),
(435, 'CMD2025060435', 146, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-02-04', '10:02:00', 'Mobilier et décoration', 121.22, 28.00, 131644.66, 'en_cours', 'created', NULL, NULL, NULL, 131644.66, 121.22, 195.00, 'urbain', 'standard', 'normal', 3, NULL, 1, '2025-02-03 00:00:00', NULL),
(436, 'CMD2025060436', 26, 'Gare Routière de Bouaké', 'Zone Industrielle Yopougon, Abidjan', '2025-02-19', '12:18:00', 'Équipements électroniques', 178.00, 47.40, 568032.16, 'en_cours', 'created', NULL, NULL, NULL, 568032.16, 178.00, 326.00, 'urbain', 'dangereux', 'urgent', 3, NULL, 1, '2025-02-18 00:00:00', NULL),
(437, 'CMD2025060437', 164, 'Centre-ville de Man', 'Gare Routière de Bouaké', '2025-03-31', '18:12:00', 'Pièces automobiles', 134.12, 22.70, 603749.77, 'en_cours', 'created', NULL, NULL, NULL, 723699.73, 134.12, 637.00, 'periurbain', 'fragile', 'tres_urgent', 1, NULL, 1, '2025-03-28 00:00:00', NULL),
(438, 'CMD2025060438', 156, 'Gare Routière de Bouaké', 'Port de San-Pédro', '2024-11-30', '18:07:00', 'Matériaux de construction', 224.76, 7.80, 379762.76, 'confirmee', 'created', NULL, NULL, NULL, 454915.31, 224.76, 258.00, 'periurbain', 'volumineux', 'urgent', 7, NULL, 1, '2024-11-29 00:00:00', NULL),
(439, 'CMD2025060439', 40, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-01-08', '11:59:00', 'Matériel informatique', 121.69, 15.70, 175707.02, 'confirmee', 'created', NULL, NULL, NULL, 175707.03, 121.69, 201.00, 'urbain', 'fragile', 'urgent', 3, NULL, 1, '2025-01-03 00:00:00', NULL),
(440, 'CMD2025060440', 160, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2024-12-16', '09:52:00', 'Produits alimentaires', 129.52, 8.20, 724670.00, 'confirmee', 'created', NULL, NULL, NULL, 724670.01, 129.52, 736.00, 'urbain', 'urgent', 'tres_urgent', 9, NULL, 1, '2024-12-15 00:00:00', NULL),
(441, 'CMD2025060441', 86, 'Centre-ville de Man', 'Port de San-Pédro', '2024-12-12', '08:01:00', 'Matériaux de construction', 228.46, 25.50, 664761.15, 'confirmee', 'created', NULL, NULL, NULL, 995141.74, 228.46, 412.00, 'regional', 'fragile', 'urgent', 4, NULL, 1, '2024-12-10 00:00:00', NULL),
(442, 'CMD2025060442', 114, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-02-18', '10:46:00', 'Produits cosmétiques', 218.30, 47.10, 387352.26, 'confirmee', 'created', NULL, NULL, NULL, 579028.40, 218.30, 271.00, 'regional', 'volumineux', 'tres_urgent', 6, NULL, 1, '2025-02-14 00:00:00', NULL),
(443, 'CMD2025060443', 141, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle Yopougon, Abidjan', '2025-03-08', '16:58:00', 'Équipements électroniques', 39.28, 49.80, 39846.93, 'confirmee', 'created', NULL, NULL, NULL, 57770.39, 39.28, 130.00, 'regional', 'fragile', 'tres_urgent', 3, NULL, 1, '2025-03-01 00:00:00', NULL),
(444, 'CMD2025060444', 182, 'Centre-ville de Man', 'Marché de Korhogo', '2025-03-05', '17:05:00', 'Mobilier et décoration', 239.97, 35.70, 619782.22, 'confirmee', 'created', NULL, NULL, NULL, 742938.66, 239.97, 396.00, 'periurbain', 'volumineux', 'tres_urgent', 5, NULL, 1, '2025-03-04 00:00:00', NULL),
(445, 'CMD2025060445', 65, 'Centre-ville de Man', 'Zone Industrielle de Yamoussoukro', '2025-05-30', '12:00:00', 'Produits alimentaires', 124.64, 40.30, 86920.50, 'confirmee', 'created', NULL, NULL, NULL, 86920.50, 124.64, 88.00, 'urbain', 'urgent', 'tres_urgent', 9, NULL, 1, '2025-05-27 00:00:00', NULL),
(446, 'CMD2025060446', 53, 'Zone Industrielle Yopougon, Abidjan', 'Zone Industrielle de Yamoussoukro', '2025-03-03', '15:09:00', 'Matériel informatique', 150.65, 23.50, 562393.26, 'confirmee', 'created', NULL, NULL, NULL, 562393.26, 150.65, 528.00, 'urbain', 'fragile', 'urgent', 2, NULL, 1, '2025-03-02 00:00:00', NULL),
(447, 'CMD2025060447', 73, 'Marché de Korhogo', 'Port de San-Pédro', '2025-02-09', '17:23:00', 'Matériaux de construction', 176.15, 15.10, 482553.75, 'confirmee', 'created', NULL, NULL, NULL, 482553.75, 176.15, 387.00, 'urbain', 'fragile', 'urgent', 5, NULL, 1, '2025-02-06 00:00:00', NULL),
(448, 'CMD2025060448', 166, 'Port de San-Pédro', 'Marché de Korhogo', '2024-11-27', '12:40:00', 'Produits cosmétiques', 210.76, 14.90, 966380.74, 'confirmee', 'created', NULL, NULL, NULL, 1447571.12, 210.76, 604.00, 'regional', 'urgent', 'tres_urgent', 2, NULL, 1, '2024-11-23 00:00:00', NULL),
(449, 'CMD2025060449', 16, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2024-12-21', '12:18:00', 'Textiles et vêtements', 201.86, 50.00, 694106.86, 'confirmee', 'created', NULL, NULL, NULL, 694106.86, 201.86, 487.00, 'urbain', 'fragile', 'urgent', 1, NULL, 1, '2024-12-16 00:00:00', NULL),
(450, 'CMD2025060450', 5, 'Marché Central de Daloa', 'Marché de Korhogo', '2024-11-30', '08:10:00', 'Produits cosmétiques', 191.61, 20.40, 53665.31, 'confirmee', 'created', NULL, NULL, NULL, 78497.97, 191.61, 40.00, 'regional', 'volumineux', 'tres_urgent', 5, NULL, 1, '2024-11-28 00:00:00', NULL),
(451, 'CMD2025060451', 189, 'Centre-ville de Man', 'Gare Routière de Bouaké', '2025-04-16', '09:16:00', 'Produits cosmétiques', 219.66, 34.70, 492225.10, 'confirmee', 'created', NULL, NULL, NULL, 736337.66, 219.66, 294.00, 'regional', 'urgent', 'tres_urgent', 5, NULL, 1, '2025-04-13 00:00:00', NULL),
(452, 'CMD2025060452', 75, 'Centre Commercial Playce, Marcory', 'Marché de Cocody, Abidjan', '2025-01-06', '15:34:00', 'Mobilier et décoration', 44.56, 48.90, 203092.30, 'confirmee', 'created', NULL, NULL, NULL, 242910.76, 44.56, 591.00, 'periurbain', 'urgent', 'normal', 1, NULL, 1, '2024-12-30 00:00:00', NULL),
(453, 'CMD2025060453', 108, 'Marché Central de Daloa', 'Centre Commercial Playce, Marcory', '2024-11-27', '11:36:00', 'Équipements électroniques', 155.77, 44.30, 234897.87, 'confirmee', 'created', NULL, NULL, NULL, 234897.87, 155.77, 183.00, 'urbain', 'refrigere', 'urgent', 10, NULL, 1, '2024-11-25 00:00:00', NULL),
(454, 'CMD2025060454', 43, 'Port Autonome d\'Abidjan, Treichville', 'Gare Routière de Bouaké', '2024-12-25', '09:57:00', 'Produits alimentaires', 202.00, 40.10, 492242.08, 'confirmee', 'created', NULL, NULL, NULL, 589890.50, 202.00, 373.00, 'periurbain', 'volumineux', 'tres_urgent', 4, NULL, 1, '2024-12-23 00:00:00', NULL),
(455, 'CMD2025060455', 126, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2025-04-29', '16:06:00', 'Produits cosmétiques', 104.56, 41.10, 196254.47, 'confirmee', 'created', NULL, NULL, NULL, 196254.48, 104.56, 227.00, 'urbain', 'refrigere', 'urgent', 9, NULL, 1, '2025-04-25 00:00:00', NULL),
(456, 'CMD2025060456', 188, 'Marché Central de Daloa', 'Port Autonome d\'Abidjan, Treichville', '2025-03-26', '13:01:00', 'Textiles et vêtements', 207.59, 12.70, 267992.20, 'confirmee', 'created', NULL, NULL, NULL, 399988.30, 207.59, 157.00, 'regional', 'refrigere', 'tres_urgent', 4, NULL, 1, '2025-03-21 00:00:00', NULL),
(457, 'CMD2025060457', 70, 'Zone Industrielle de Yamoussoukro', 'Port Autonome d\'Abidjan, Treichville', '2025-02-25', '12:50:00', 'Pièces automobiles', 237.84, 9.90, 873238.60, 'confirmee', 'created', NULL, NULL, NULL, 1047086.32, 237.84, 564.00, 'periurbain', 'volumineux', 'urgent', 8, NULL, 1, '2025-02-22 00:00:00', NULL),
(458, 'CMD2025060458', 9, 'Marché de Korhogo', 'Zone Industrielle de Yamoussoukro', '2025-01-03', '18:00:00', 'Textiles et vêtements', 145.57, 35.70, 26010.18, 'confirmee', 'created', NULL, NULL, NULL, 26010.18, 145.57, 28.00, 'urbain', 'standard', 'tres_urgent', 7, NULL, 1, '2024-12-28 00:00:00', NULL),
(459, 'CMD2025060459', 181, 'Zone Industrielle de Yamoussoukro', 'Port Autonome d\'Abidjan, Treichville', '2024-11-27', '14:03:00', 'Mobilier et décoration', 59.52, 1.60, 106850.56, 'confirmee', 'created', NULL, NULL, NULL, 127420.67, 59.52, 320.00, 'periurbain', 'standard', 'urgent', 10, NULL, 1, '2024-11-21 00:00:00', NULL),
(460, 'CMD2025060460', 57, 'Zone Industrielle de Yamoussoukro', 'Port Autonome d\'Abidjan, Treichville', '2025-01-08', '11:37:00', 'Produits alimentaires', 37.65, 46.10, 134768.99, 'confirmee', 'created', NULL, NULL, NULL, 160922.79, 37.65, 536.00, 'periurbain', 'volumineux', 'tres_urgent', 5, NULL, 1, '2025-01-01 00:00:00', NULL),
(461, 'CMD2025060461', 167, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2025-02-24', '12:56:00', 'Textiles et vêtements', 241.20, 43.20, 73031.44, 'confirmee', 'created', NULL, NULL, NULL, 73031.44, 241.20, 53.00, 'urbain', 'standard', 'tres_urgent', 8, NULL, 1, '2025-02-17 00:00:00', NULL),
(462, 'CMD2025060462', 137, 'Marché de Cocody, Abidjan', 'Zone Industrielle de Yamoussoukro', '2024-11-23', '09:15:00', 'Matériaux de construction', 99.02, 2.30, 18597.53, 'confirmee', 'created', NULL, NULL, NULL, 25896.30, 99.02, 21.00, 'regional', 'fragile', 'tres_urgent', 2, NULL, 1, '2024-11-17 00:00:00', NULL),
(463, 'CMD2025060463', 63, 'Port de San-Pédro', 'Gare Routière de Bouaké', '2025-05-30', '12:50:00', 'Produits cosmétiques', 5.74, 0.60, 14042.70, 'confirmee', 'created', NULL, NULL, NULL, 14042.70, 5.74, 324.00, 'urbain', 'standard', 'urgent', 7, NULL, 1, '2025-05-26 00:00:00', NULL),
(464, 'CMD2025060464', 129, 'Marché Central de Daloa', 'Zone Industrielle Yopougon, Abidjan', '2025-04-20', '16:58:00', 'Produits cosmétiques', 23.51, 15.20, 68670.37, 'confirmee', 'created', NULL, NULL, NULL, 81604.44, 23.51, 283.00, 'periurbain', 'dangereux', 'normal', 6, NULL, 1, '2025-04-19 00:00:00', NULL),
(465, 'CMD2025060465', 132, 'Gare Routière de Bouaké', 'Centre-ville de Man', '2025-05-21', '12:56:00', 'Pièces automobiles', 50.03, 21.00, 194194.05, 'confirmee', 'created', NULL, NULL, NULL, 232232.86, 50.03, 704.00, 'periurbain', 'standard', 'normal', 6, NULL, 1, '2025-05-20 00:00:00', NULL),
(466, 'CMD2025060466', 136, 'Marché de Korhogo', 'Gare Routière de Bouaké', '2025-03-23', '10:42:00', 'Textiles et vêtements', 217.42, 25.10, 572835.95, 'confirmee', 'created', NULL, NULL, NULL, 686603.13, 217.42, 323.00, 'periurbain', 'refrigere', 'urgent', 5, NULL, 1, '2025-03-22 00:00:00', NULL),
(467, 'CMD2025060467', 178, 'Gare Routière de Bouaké', 'Centre Commercial Playce, Marcory', '2025-05-01', '08:43:00', 'Mobilier et décoration', 224.71, 36.70, 49867.81, 'confirmee', 'created', NULL, NULL, NULL, 49867.80, 224.71, 21.00, 'urbain', 'dangereux', 'normal', 1, NULL, 1, '2025-04-29 00:00:00', NULL),
(468, 'CMD2025060468', 85, 'Marché Central de Daloa', 'Centre-ville de Man', '2025-01-03', '13:40:00', 'Équipements électroniques', 102.70, 43.80, 40602.28, 'confirmee', 'created', NULL, NULL, NULL, 58903.42, 102.70, 66.00, 'regional', 'standard', 'tres_urgent', 4, NULL, 1, '2024-12-31 00:00:00', NULL),
(469, 'CMD2025060469', 11, 'Marché de Korhogo', 'Gare Routière de Bouaké', '2025-03-23', '14:51:00', 'Pièces automobiles', 186.38, 33.60, 1322854.70, 'confirmee', 'created', NULL, NULL, NULL, 1586625.65, 186.38, 728.00, 'periurbain', 'dangereux', 'urgent', 10, NULL, 1, '2025-03-18 00:00:00', NULL),
(470, 'CMD2025060470', 105, 'Gare Routière de Bouaké', 'Port de San-Pédro', '2025-05-12', '15:14:00', 'Équipements électroniques', 44.38, 37.00, 122196.37, 'confirmee', 'created', NULL, NULL, NULL, 122196.36, 44.38, 411.00, 'urbain', 'volumineux', 'normal', 2, NULL, 1, '2025-05-08 00:00:00', NULL),
(471, 'CMD2025060471', 42, 'Centre Commercial Playce, Marcory', 'Port Autonome d\'Abidjan, Treichville', '2025-02-10', '10:37:00', 'Produits alimentaires', 28.52, 45.60, 108787.04, 'confirmee', 'created', NULL, NULL, NULL, 129744.44, 28.52, 378.00, 'periurbain', 'dangereux', 'urgent', 4, NULL, 1, '2025-02-05 00:00:00', NULL),
(472, 'CMD2025060472', 4, 'Centre Commercial Playce, Marcory', 'Centre-ville de Man', '2025-05-31', '18:42:00', 'Matériaux de construction', 190.86, 48.40, 299794.83, 'confirmee', 'created', NULL, NULL, NULL, 358953.79, 190.86, 205.00, 'periurbain', 'urgent', 'urgent', 6, NULL, 1, '2025-05-29 00:00:00', NULL),
(473, 'CMD2025060473', 174, 'Zone Industrielle de Yamoussoukro', 'Marché de Cocody, Abidjan', '2025-01-04', '14:54:00', 'Matériaux de construction', 30.48, 20.80, 174533.77, 'confirmee', 'created', NULL, NULL, NULL, 174533.77, 30.48, 797.00, 'urbain', 'fragile', 'urgent', 3, NULL, 1, '2024-12-31 00:00:00', NULL),
(474, 'CMD2025060474', 62, 'Marché de Cocody, Abidjan', 'Centre Commercial Playce, Marcory', '2025-05-22', '11:29:00', 'Matériaux de construction', 214.93, 23.80, 1372373.34, 'confirmee', 'created', NULL, NULL, NULL, 2056560.02, 214.93, 655.00, 'regional', 'dangereux', 'urgent', 6, NULL, 1, '2025-05-16 00:00:00', NULL),
(475, 'CMD2025060475', 165, 'Marché de Korhogo', 'Zone Industrielle Yopougon, Abidjan', '2025-05-21', '15:22:00', 'Produits alimentaires', 217.19, 35.00, 383995.62, 'confirmee', 'created', NULL, NULL, NULL, 383995.63, 217.19, 216.00, 'urbain', 'refrigere', 'tres_urgent', 5, NULL, 1, '2025-05-16 00:00:00', NULL),
(476, 'CMD2025060476', 183, 'Zone Industrielle de Yamoussoukro', 'Port de San-Pédro', '2025-04-06', '11:23:00', 'Pièces automobiles', 235.45, 23.40, 130634.43, 'confirmee', 'created', NULL, NULL, NULL, 155961.32, 235.45, 83.00, 'periurbain', 'volumineux', 'tres_urgent', 3, NULL, 1, '2025-04-04 00:00:00', NULL),
(477, 'CMD2025060477', 45, 'Port de San-Pédro', 'Marché de Cocody, Abidjan', '2025-04-10', '18:24:00', 'Produits cosmétiques', 172.09, 44.50, 221452.92, 'confirmee', 'created', NULL, NULL, NULL, 330179.40, 172.09, 156.00, 'regional', 'refrigere', 'tres_urgent', 10, NULL, 1, '2025-04-08 00:00:00', NULL),
(478, 'CMD2025060478', 6, 'Marché de Cocody, Abidjan', 'Marché Central de Daloa', '2025-01-24', '16:52:00', 'Matériel informatique', 113.09, 27.40, 240335.48, 'confirmee', 'created', NULL, NULL, NULL, 240335.49, 113.09, 258.00, 'urbain', 'refrigere', 'urgent', 8, NULL, 1, '2025-01-20 00:00:00', NULL),
(479, 'CMD2025060479', 38, 'Port Autonome d\'Abidjan, Treichville', 'Port de San-Pédro', '2025-03-31', '14:24:00', 'Mobilier et décoration', 211.74, 12.60, 862919.08, 'confirmee', 'created', NULL, NULL, NULL, 1292378.62, 211.74, 626.00, 'regional', 'volumineux', 'urgent', 8, NULL, 1, '2025-03-24 00:00:00', NULL),
(480, 'CMD2025060480', 171, 'Port Autonome d\'Abidjan, Treichville', 'Zone Industrielle de Yamoussoukro', '2024-12-17', '17:11:00', 'Pièces automobiles', 219.52, 45.50, 599667.52, 'confirmee', 'created', NULL, NULL, NULL, 718801.03, 219.52, 335.00, 'periurbain', 'refrigere', 'normal', 2, NULL, 1, '2024-12-11 00:00:00', NULL),
(481, 'CMD2025060481', 99, 'Gare Routière de Bouaké', 'Port Autonome d\'Abidjan, Treichville', '2025-04-14', '18:56:00', 'Équipements électroniques', 116.76, 29.40, 207904.99, 'confirmee', 'created', NULL, NULL, NULL, 207904.99, 116.76, 231.00, 'urbain', 'urgent', 'normal', 6, NULL, 1, '2025-04-08 00:00:00', NULL),
(482, 'CMD2025060482', 67, 'Marché de Korhogo', 'Port Autonome d\'Abidjan, Treichville', '2025-05-04', '08:34:00', 'Matériaux de construction', 151.77, 29.00, 422958.05, 'confirmee', 'created', NULL, NULL, NULL, 506749.66, 151.77, 426.00, 'periurbain', 'volumineux', 'urgent', 4, NULL, 1, '2025-04-30 00:00:00', NULL),
(483, 'CMD2025060483', 66, 'Port Autonome d\'Abidjan, Treichville', 'Centre Commercial Playce, Marcory', '2024-11-28', '10:49:00', 'Mobilier et décoration', 223.31, 41.30, 1319367.36, 'confirmee', 'created', NULL, NULL, NULL, 1977051.03, 223.31, 606.00, 'regional', 'dangereux', 'tres_urgent', 7, NULL, 1, '2024-11-24 00:00:00', NULL);
INSERT INTO `commandes` (`id`, `numero_commande`, `client_id`, `adresse_depart`, `adresse_arrivee`, `date_prevue`, `heure_prevue`, `description`, `poids`, `volume`, `prix`, `statut`, `workflow_state`, `validated_by`, `validated_at`, `rejection_reason`, `tarif_auto`, `poids_kg`, `distance_km`, `zone_tarif`, `cargo_type`, `urgence`, `priorite`, `notes`, `active`, `date_creation`, `date_modification`) VALUES
(484, 'CMD2025060484', 50, 'Zone Industrielle Yopougon, Abidjan', 'Marché Central de Daloa', '2025-05-16', '09:08:00', 'Matériel informatique', 219.28, 21.80, 1027072.77, 'confirmee', 'created', NULL, NULL, NULL, 1538609.16, 219.28, 576.00, 'regional', 'refrigere', 'normal', 3, NULL, 1, '2025-05-14 00:00:00', NULL),
(485, 'CMD2025060485', 195, 'Marché de Korhogo', 'Zone Industrielle de Yamoussoukro', '2025-02-16', '16:30:00', 'Mobilier et décoration', 209.43, 3.20, 759908.26, 'confirmee', 'created', NULL, NULL, NULL, 759908.26, 209.43, 557.00, 'urbain', 'volumineux', 'tres_urgent', 10, NULL, 1, '2025-02-10 00:00:00', NULL);

--
-- Déclencheurs `commandes`
--
DROP TRIGGER IF EXISTS `tr_commande_status_change`;
DELIMITER $$
CREATE TRIGGER `tr_commande_status_change` AFTER UPDATE ON `commandes` FOR EACH ROW BEGIN
    IF OLD.statut != NEW.statut THEN
        -- Créer une notification pour les changements de statut
        INSERT INTO notifications (user_id, type, message, module, entite_id)
        VALUES (0, 'info', CONCAT('Changement statut commande ', NEW.numero_commande, ' de ', OLD.statut, ' à ', NEW.statut), 
               'commandes', NEW.id);
        
        -- Si la commande est confirmée, créer automatiquement un trajet
        IF NEW.statut = 'confirmee' AND OLD.statut != 'confirmee' THEN
            INSERT INTO trajets (commande_id, vehicule_id, chauffeur_id, date_depart, statut)
            VALUES (NEW.id, 
                   (SELECT id FROM vehicules WHERE disponible = 1 AND actif = 1 LIMIT 1),
                   (SELECT id FROM users WHERE role = 'chauffeur' AND actif = 1 LIMIT 1),
                   NEW.date_prevue, 'planifie');
        END IF;
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `tr_commande_tarif_auto`;
DELIMITER $$
CREATE TRIGGER `tr_commande_tarif_auto` BEFORE INSERT ON `commandes` FOR EACH ROW BEGIN
    -- Calculer le tarif automatiquement si poids et distance sont fournis
    IF NEW.poids_kg IS NOT NULL AND NEW.distance_km IS NOT NULL THEN
        -- Formule de base: (poids/1000) * (distance/10) * 54000
        SET NEW.tarif_auto = ROUND((NEW.poids_kg / 1000) * (NEW.distance_km / 10) * 54000, 2);
        
        -- Appliquer le multiplicateur de zone
        SET NEW.tarif_auto = CASE COALESCE(NEW.zone_tarif, 'urbain')
            WHEN 'urbain' THEN NEW.tarif_auto * 1.0
            WHEN 'periurbain' THEN NEW.tarif_auto * 1.2
            WHEN 'regional' THEN NEW.tarif_auto * 1.5
            WHEN 'international' THEN NEW.tarif_auto * 2.0
            ELSE NEW.tarif_auto
        END;
        
        -- Appliquer le multiplicateur de type de marchandise
        SET NEW.tarif_auto = CASE COALESCE(NEW.cargo_type, 'standard')
            WHEN 'standard' THEN NEW.tarif_auto * 1.0
            WHEN 'fragile' THEN NEW.tarif_auto * 1.3
            WHEN 'dangereux' THEN NEW.tarif_auto * 1.8
            WHEN 'refrigere' THEN NEW.tarif_auto * 1.5
            WHEN 'urgent' THEN NEW.tarif_auto * 1.4
            WHEN 'volumineux' THEN NEW.tarif_auto * 1.2
            ELSE NEW.tarif_auto
        END;
        
        -- Ajouter les frais fixes (4000 F CFA)
        SET NEW.tarif_auto = NEW.tarif_auto + 4000;
        
        -- Mettre à jour le prix si pas déjà défini
        IF NEW.prix IS NULL OR NEW.prix = 0 THEN
            SET NEW.prix = NEW.tarif_auto;
        END IF;
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `tr_commande_workflow_sync`;
DELIMITER $$
CREATE TRIGGER `tr_commande_workflow_sync` BEFORE UPDATE ON `commandes` FOR EACH ROW BEGIN
    -- Synchroniser le statut avec le workflow_state
    IF NEW.workflow_state != OLD.workflow_state THEN
        SET NEW.statut = CASE NEW.workflow_state
            WHEN 'created' THEN 'en_attente'
            WHEN 'validated' THEN 'confirmee'
            WHEN 'rejected' THEN 'annulee'
            WHEN 'planned' THEN 'confirmee'
            WHEN 'in_transit' THEN 'en_cours'
            WHEN 'delivered' THEN 'livree'
            WHEN 'cancelled' THEN 'annulee'
            ELSE 'en_attente'
        END;
        
        -- Enregistrer le changement d'état
        INSERT INTO workflow_states (commande_id, state, previous_state, changed_by, created_at)
        VALUES (NEW.id, NEW.workflow_state, OLD.workflow_state, COALESCE(NEW.validated_by, 1));
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `factures`
--

DROP TABLE IF EXISTS `factures`;
CREATE TABLE IF NOT EXISTS `factures` (
  `id` int NOT NULL AUTO_INCREMENT,
  `numero_facture` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `client_id` int NOT NULL,
  `commande_id` int DEFAULT NULL,
  `date_facture` date NOT NULL,
  `date_echeance` date NOT NULL,
  `montant_ht` decimal(10,2) NOT NULL,
  `taux_tva` decimal(5,2) NOT NULL DEFAULT '20.00',
  `montant_tva` decimal(10,2) NOT NULL,
  `montant_ttc` decimal(10,2) NOT NULL,
  `statut` enum('brouillon','envoyee','payee','annulee') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'brouillon',
  `date_paiement` datetime DEFAULT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `numero_facture` (`numero_facture`),
  KEY `fk_factures_client` (`client_id`),
  KEY `fk_factures_commande` (`commande_id`),
  KEY `idx_statut` (`statut`),
  KEY `idx_date_facture` (`date_facture`),
  KEY `idx_date_echeance` (`date_echeance`),
  KEY `idx_actif` (`actif`),
  KEY `idx_factures_client_statut` (`client_id`,`statut`),
  KEY `idx_factures_date_statut` (`date_facture`,`statut`),
  KEY `idx_factures_statut_date` (`statut`,`date_echeance`)
) ;

--
-- Déchargement des données de la table `factures`
--

INSERT INTO `factures` (`id`, `numero_facture`, `client_id`, `commande_id`, `date_facture`, `date_echeance`, `montant_ht`, `taux_tva`, `montant_tva`, `montant_ttc`, `statut`, `date_paiement`, `description`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 'FACT2025050001', 134, 1, '2025-05-02', '2025-06-01', 49306.86, 18.00, 8875.23, 58182.09, 'payee', '2025-05-14 07:06:51', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-02 00:00:00', NULL),
(2, 'FACT2025050002', 149, 2, '2025-05-09', '2025-06-08', 233605.67, 18.00, 42049.02, 275654.69, 'payee', '2025-05-30 12:51:27', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-05-09 00:00:00', NULL),
(3, 'FACT2024120003', 152, 3, '2024-12-18', '2025-01-17', 182580.51, 18.00, 32864.49, 215445.00, 'payee', '2025-01-06 08:40:22', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-12-17 00:00:00', NULL),
(4, 'FACT2025030004', 128, 4, '2025-03-16', '2025-04-15', 29232.74, 18.00, 5261.89, 34494.63, 'payee', '2025-03-27 19:13:36', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-15 00:00:00', NULL),
(5, 'FACT2025050005', 116, 5, '2025-05-27', '2025-06-26', 43785.18, 18.00, 7881.33, 51666.51, 'payee', '2025-06-13 02:22:48', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-25 00:00:00', NULL),
(6, 'FACT2025010006', 144, 6, '2025-01-07', '2025-02-06', 385130.44, 18.00, 69323.48, 454453.92, 'payee', '2025-01-08 03:25:10', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-05 00:00:00', NULL),
(7, 'FACT2025030007', 133, 7, '2025-03-17', '2025-04-16', 254686.58, 18.00, 45843.58, 300530.16, 'payee', '2025-04-02 09:40:25', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-16 00:00:00', NULL),
(8, 'FACT2025020008', 60, 8, '2025-02-09', '2025-03-11', 52967.55, 18.00, 9534.16, 62501.71, 'payee', '2025-02-26 08:30:37', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-09 00:00:00', NULL),
(9, 'FACT2024120009', 154, 9, '2024-12-03', '2025-01-02', 219036.08, 18.00, 39426.49, 258462.57, 'payee', '2024-12-19 20:05:12', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-02 00:00:00', NULL),
(10, 'FACT2024110010', 2, 10, '2024-11-20', '2024-12-20', 38467.12, 18.00, 6924.08, 45391.20, 'payee', '2024-12-14 02:56:29', 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-11-18 00:00:00', NULL),
(11, 'FACT2024110011', 177, 11, '2024-11-24', '2024-12-24', 128250.18, 18.00, 23085.03, 151335.21, 'payee', '2024-12-10 14:41:19', 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-11-22 00:00:00', NULL),
(12, 'FACT2025020012', 82, 12, '2025-02-19', '2025-03-21', 357040.51, 18.00, 64267.29, 421307.80, 'payee', '2025-02-21 21:44:21', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-19 00:00:00', NULL),
(13, 'FACT2025040013', 10, 13, '2025-04-12', '2025-05-12', 11803.62, 18.00, 2124.65, 13928.27, 'payee', '2025-05-10 17:32:14', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-10 00:00:00', NULL),
(14, 'FACT2025010014', 90, 14, '2025-01-21', '2025-02-20', 16412.76, 18.00, 2954.30, 19367.06, 'payee', '2025-02-02 19:16:10', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-20 00:00:00', NULL),
(15, 'FACT2025050015', 81, 15, '2025-05-11', '2025-06-10', 56174.89, 18.00, 10111.48, 66286.37, 'payee', '2025-05-13 20:31:02', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-05-09 00:00:00', NULL),
(16, 'FACT2025050016', 59, 16, '2025-05-23', '2025-06-22', 397600.81, 18.00, 71568.15, 469168.96, 'payee', '2025-06-15 18:35:35', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-05-23 00:00:00', NULL),
(17, 'FACT2025020017', 36, 17, '2025-02-20', '2025-03-22', 466537.09, 18.00, 83976.68, 550513.77, 'payee', '2025-02-25 03:01:05', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-20 00:00:00', NULL),
(18, 'FACT2025010018', 151, 18, '2025-01-04', '2025-02-03', 588389.73, 18.00, 105910.15, 694299.88, 'payee', '2025-01-06 14:05:18', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-03 00:00:00', NULL),
(19, 'FACT2025030019', 98, 19, '2025-03-06', '2025-04-05', 708404.03, 18.00, 127512.73, 835916.76, 'payee', '2025-03-09 09:01:06', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-03-04 00:00:00', NULL),
(20, 'FACT2025020020', 76, 20, '2025-02-23', '2025-03-25', 908081.65, 18.00, 163454.70, 1071536.35, 'payee', '2025-03-06 16:19:49', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-21 00:00:00', NULL),
(21, 'FACT2025010021', 35, 21, '2025-01-25', '2025-02-24', 101979.22, 18.00, 18356.26, 120335.48, 'payee', '2025-01-29 15:45:01', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-25 00:00:00', NULL),
(22, 'FACT2025030022', 32, 22, '2025-03-23', '2025-04-22', 543211.82, 18.00, 97778.13, 640989.95, 'payee', '2025-03-26 23:54:42', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-23 00:00:00', NULL),
(23, 'FACT2025020023', 37, 23, '2025-02-03', '2025-03-05', 13072.16, 18.00, 2352.99, 15425.15, 'payee', '2025-02-25 08:47:20', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-02-01 00:00:00', NULL),
(24, 'FACT2025040024', 78, 24, '2025-04-20', '2025-05-20', 465265.39, 18.00, 83747.77, 549013.16, 'payee', '2025-05-17 01:34:30', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-20 00:00:00', NULL),
(25, 'FACT2024120025', 191, 25, '2024-12-05', '2025-01-04', 463952.34, 18.00, 83511.42, 547463.76, 'payee', '2024-12-28 15:17:23', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-03 00:00:00', NULL),
(26, 'FACT2025010026', 83, 26, '2025-01-27', '2025-02-26', 11945.13, 18.00, 2150.12, 14095.25, 'payee', '2025-02-10 20:23:50', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-27 00:00:00', NULL),
(27, 'FACT2024120027', 7, 27, '2024-12-22', '2025-01-21', 660219.49, 18.00, 118839.51, 779059.00, 'payee', '2025-01-13 16:59:56', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-21 00:00:00', NULL),
(28, 'FACT2025030028', 122, 28, '2025-03-09', '2025-04-08', 755921.19, 18.00, 136065.81, 891987.00, 'payee', '2025-03-18 07:15:32', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-03-08 00:00:00', NULL),
(29, 'FACT2025040029', 109, 29, '2025-04-17', '2025-05-17', 14317.78, 18.00, 2577.20, 16894.98, 'payee', '2025-05-07 20:34:56', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-16 00:00:00', NULL),
(30, 'FACT2025030030', 47, 30, '2025-03-29', '2025-04-28', 245811.24, 18.00, 44246.02, 290057.26, 'payee', '2025-04-09 05:26:35', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-03-28 00:00:00', NULL),
(31, 'FACT2025010031', 125, 31, '2025-01-21', '2025-02-20', 33079.39, 18.00, 5954.29, 39033.68, 'payee', '2025-02-04 08:28:02', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-20 00:00:00', NULL),
(32, 'FACT2025030032', 31, 32, '2025-03-17', '2025-04-16', 525537.88, 18.00, 94596.82, 620134.70, 'payee', '2025-03-21 16:51:43', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-16 00:00:00', NULL),
(33, 'FACT2025030033', 33, 33, '2025-03-09', '2025-04-08', 260574.08, 18.00, 46903.33, 307477.41, 'payee', '2025-03-30 15:33:23', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-07 00:00:00', NULL),
(34, 'FACT2025040034', 124, 34, '2025-04-15', '2025-05-15', 69792.98, 18.00, 12562.74, 82355.72, 'payee', '2025-05-04 19:11:05', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-04-15 00:00:00', NULL),
(35, 'FACT2025050035', 193, 35, '2025-05-03', '2025-06-02', 351921.87, 18.00, 63345.94, 415267.81, 'payee', '2025-05-14 19:08:54', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-02 00:00:00', NULL),
(36, 'FACT2024110036', 21, 36, '2024-11-17', '2024-12-17', 22290.19, 18.00, 4012.23, 26302.42, 'payee', '2024-12-14 10:12:18', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-11-17 00:00:00', NULL),
(37, 'FACT2025050037', 127, 37, '2025-05-10', '2025-06-09', 278969.73, 18.00, 50214.55, 329184.28, 'payee', '2025-05-18 02:41:26', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-08 00:00:00', NULL),
(38, 'FACT2025010038', 52, 38, '2025-01-11', '2025-02-10', 657895.45, 18.00, 118421.18, 776316.63, 'payee', '2025-01-19 10:34:56', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-11 00:00:00', NULL),
(39, 'FACT2025010039', 87, 39, '2025-01-11', '2025-02-10', 381679.74, 18.00, 68702.35, 450382.09, 'payee', '2025-02-06 15:25:45', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-01-11 00:00:00', NULL),
(40, 'FACT2025050040', 194, 40, '2025-05-13', '2025-06-12', 371769.16, 18.00, 66918.45, 438687.61, 'payee', '2025-06-05 13:07:24', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-13 00:00:00', NULL),
(41, 'FACT2025030041', 150, 41, '2025-03-17', '2025-04-16', 304681.59, 18.00, 54842.69, 359524.28, 'payee', '2025-04-11 02:22:28', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-03-15 00:00:00', NULL),
(42, 'FACT2025020042', 88, 42, '2025-02-11', '2025-03-13', 45872.20, 18.00, 8257.00, 54129.20, 'payee', '2025-02-12 09:26:46', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-10 00:00:00', NULL),
(43, 'FACT2024110043', 184, 43, '2024-11-17', '2024-12-17', 405375.49, 18.00, 72967.59, 478343.08, 'payee', '2024-12-07 00:00:40', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-16 00:00:00', NULL),
(44, 'FACT2025010044', 41, 44, '2025-01-25', '2025-02-24', 364949.48, 18.00, 65690.91, 430640.39, 'payee', '2025-02-21 21:30:07', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-23 00:00:00', NULL),
(45, 'FACT2025010045', 22, 45, '2025-01-29', '2025-02-28', 328954.40, 18.00, 59211.79, 388166.19, 'payee', '2025-02-18 03:32:31', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-29 00:00:00', NULL),
(46, 'FACT2025020046', 145, 46, '2025-02-16', '2025-03-18', 549238.35, 18.00, 98862.90, 648101.25, 'payee', '2025-02-28 23:33:56', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-14 00:00:00', NULL),
(47, 'FACT2025020047', 146, 47, '2025-02-21', '2025-03-23', 139975.57, 18.00, 25195.60, 165171.17, 'payee', '2025-03-19 07:24:37', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-20 00:00:00', NULL),
(48, 'FACT2025010048', 26, 48, '2025-01-30', '2025-03-01', 121457.24, 18.00, 21862.30, 143319.54, 'payee', '2025-02-03 19:36:30', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-28 00:00:00', NULL),
(49, 'FACT2024120049', 164, 49, '2024-12-05', '2025-01-04', 124268.67, 18.00, 22368.36, 146637.03, 'payee', '2024-12-15 09:10:50', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-03 00:00:00', NULL),
(50, 'FACT2025030050', 156, 50, '2025-03-01', '2025-03-31', 447933.78, 18.00, 80628.08, 528561.86, 'payee', '2025-03-15 11:18:07', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-27 00:00:00', NULL),
(51, 'FACT2025010051', 40, 51, '2025-01-03', '2025-02-02', 296389.88, 18.00, 53350.18, 349740.06, 'payee', '2025-01-21 02:33:26', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-01 00:00:00', NULL),
(52, 'FACT2025040052', 160, 52, '2025-04-07', '2025-05-07', 435756.33, 18.00, 78436.14, 514192.47, 'payee', '2025-04-21 12:10:50', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-05 00:00:00', NULL),
(53, 'FACT2025020053', 86, 53, '2025-02-12', '2025-03-14', 231186.01, 18.00, 41613.48, 272799.49, 'payee', '2025-02-26 13:12:13', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-12 00:00:00', NULL),
(54, 'FACT2025050054', 114, 54, '2025-05-13', '2025-06-12', 183805.61, 18.00, 33085.01, 216890.62, 'payee', '2025-05-16 04:35:10', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-12 00:00:00', NULL),
(55, 'FACT2025040055', 141, 55, '2025-04-05', '2025-05-05', 250630.91, 18.00, 45113.56, 295744.47, 'payee', '2025-04-06 05:31:34', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-03 00:00:00', NULL),
(56, 'FACT2025030056', 182, 56, '2025-03-24', '2025-04-23', 386007.13, 18.00, 69481.28, 455488.41, 'payee', '2025-03-27 11:12:22', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-24 00:00:00', NULL),
(57, 'FACT2025020057', 65, 57, '2025-02-07', '2025-03-09', 11373.20, 18.00, 2047.18, 13420.38, 'payee', '2025-02-20 00:06:01', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-02-05 00:00:00', NULL),
(58, 'FACT2025040058', 53, 58, '2025-04-12', '2025-05-12', 526886.95, 18.00, 94839.65, 621726.60, 'payee', '2025-04-22 08:23:52', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-11 00:00:00', NULL),
(59, 'FACT2024120059', 73, 59, '2024-12-15', '2025-01-14', 12393.41, 18.00, 2230.81, 14624.22, 'payee', '2025-01-01 22:43:27', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-15 00:00:00', NULL),
(60, 'FACT2025050060', 166, 60, '2025-05-24', '2025-06-23', 190625.56, 18.00, 34312.60, 224938.16, 'payee', '2025-06-03 10:58:36', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-22 00:00:00', NULL),
(61, 'FACT2024120061', 16, 61, '2024-12-20', '2025-01-19', 68754.38, 18.00, 12375.79, 81130.17, 'payee', '2025-01-09 13:36:29', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-19 00:00:00', NULL),
(62, 'FACT2025030062', 5, 62, '2025-03-12', '2025-04-11', 507475.39, 18.00, 91345.57, 598820.96, 'payee', '2025-03-27 20:15:23', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-10 00:00:00', NULL),
(63, 'FACT2025010063', 189, 63, '2025-01-11', '2025-02-10', 668138.83, 18.00, 120264.99, 788403.82, 'payee', '2025-01-31 09:43:56', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-11 00:00:00', NULL),
(64, 'FACT2025040064', 75, 64, '2025-04-11', '2025-05-11', 894110.17, 18.00, 160939.83, 1055050.00, 'payee', '2025-04-24 21:33:53', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-09 00:00:00', NULL),
(65, 'FACT2025020065', 108, 65, '2025-02-02', '2025-03-04', 723284.47, 18.00, 130191.20, 853475.67, 'payee', '2025-02-19 09:40:11', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-01 00:00:00', NULL),
(66, 'FACT2025030066', 43, 66, '2025-03-15', '2025-04-14', 369809.39, 18.00, 66565.69, 436375.08, 'payee', '2025-03-24 01:55:25', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-14 00:00:00', NULL),
(67, 'FACT2025010067', 126, 67, '2025-01-20', '2025-02-19', 925494.20, 18.00, 166588.96, 1092083.16, 'payee', '2025-02-08 18:09:03', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-20 00:00:00', NULL),
(68, 'FACT2024120068', 188, 68, '2024-12-16', '2025-01-15', 795952.88, 18.00, 143271.52, 939224.40, 'payee', '2024-12-23 07:23:52', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-15 00:00:00', NULL),
(69, 'FACT2025010069', 70, 69, '2025-01-04', '2025-02-03', 146799.44, 18.00, 26423.90, 173223.34, 'payee', '2025-01-28 17:17:55', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-02 00:00:00', NULL),
(70, 'FACT2025040070', 9, 70, '2025-04-04', '2025-05-04', 976579.15, 18.00, 175784.25, 1152363.40, 'payee', '2025-04-16 18:28:54', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-03 00:00:00', NULL),
(71, 'FACT2025020071', 181, 71, '2025-02-16', '2025-03-18', 173148.09, 18.00, 31166.66, 204314.75, 'payee', '2025-03-17 13:49:42', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-15 00:00:00', NULL),
(72, 'FACT2025020072', 57, 72, '2025-02-08', '2025-03-10', 646887.15, 18.00, 116439.69, 763326.84, 'payee', '2025-02-21 09:01:39', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-06 00:00:00', NULL),
(73, 'FACT2025040073', 167, 73, '2025-04-17', '2025-05-17', 387235.00, 18.00, 69702.30, 456937.30, 'payee', '2025-04-25 20:34:14', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-15 00:00:00', NULL),
(74, 'FACT2025020074', 137, 74, '2025-02-05', '2025-03-07', 69048.96, 18.00, 12428.81, 81477.77, 'payee', '2025-02-25 07:07:09', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-05 00:00:00', NULL),
(75, 'FACT2025010075', 63, 75, '2025-01-18', '2025-02-17', 188906.02, 18.00, 34003.08, 222909.10, 'payee', '2025-01-18 04:47:08', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-17 00:00:00', NULL),
(76, 'FACT2025010076', 129, 76, '2025-01-20', '2025-02-19', 297392.76, 18.00, 53530.70, 350923.46, 'payee', '2025-02-02 02:14:36', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-01-18 00:00:00', NULL),
(77, 'FACT2025050077', 132, 77, '2025-05-29', '2025-06-28', 6868.37, 18.00, 1236.31, 8104.68, 'payee', '2025-06-13 08:13:26', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-29 00:00:00', NULL),
(78, 'FACT2025050078', 136, 78, '2025-05-15', '2025-06-14', 1278474.25, 18.00, 230125.37, 1508599.62, 'payee', '2025-06-10 20:43:43', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-14 00:00:00', NULL),
(79, 'FACT2025040079', 178, 79, '2025-04-28', '2025-05-28', 381101.98, 18.00, 68598.36, 449700.34, 'payee', '2025-05-25 05:40:52', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-27 00:00:00', NULL),
(80, 'FACT2025040080', 85, 80, '2025-04-27', '2025-05-27', 288336.89, 18.00, 51900.64, 340237.53, 'payee', '2025-05-11 21:55:20', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-27 00:00:00', NULL),
(81, 'FACT2025040081', 11, 81, '2025-04-04', '2025-05-04', 809264.77, 18.00, 145667.66, 954932.43, 'payee', '2025-04-09 06:50:54', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-03 00:00:00', NULL),
(82, 'FACT2025010082', 105, 82, '2025-01-25', '2025-02-24', 245183.71, 18.00, 44133.07, 289316.78, 'payee', '2025-02-08 15:11:52', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-25 00:00:00', NULL),
(83, 'FACT2025010083', 42, 83, '2025-01-14', '2025-02-13', 488966.18, 18.00, 88013.91, 576980.09, 'payee', '2025-01-23 07:42:54', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-13 00:00:00', NULL),
(84, 'FACT2025040084', 4, 84, '2025-04-02', '2025-05-02', 1483937.65, 18.00, 267108.78, 1751046.43, 'payee', '2025-04-05 20:56:53', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-01 00:00:00', NULL),
(85, 'FACT2025030085', 174, 85, '2025-03-24', '2025-04-23', 1002005.54, 18.00, 180361.00, 1182366.54, 'payee', '2025-04-01 03:25:51', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-24 00:00:00', NULL),
(86, 'FACT2025020086', 62, 86, '2025-02-20', '2025-03-22', 79082.06, 18.00, 14234.77, 93316.83, 'payee', '2025-02-22 04:07:41', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-19 00:00:00', NULL),
(87, 'FACT2024120087', 165, 87, '2024-12-12', '2025-01-11', 494349.61, 18.00, 88982.93, 583332.54, 'payee', '2024-12-12 00:02:05', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-10 00:00:00', NULL),
(88, 'FACT2024120088', 183, 88, '2024-12-11', '2025-01-10', 505561.23, 18.00, 91001.02, 596562.25, 'payee', '2024-12-30 19:38:29', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-10 00:00:00', NULL),
(89, 'FACT2025030089', 45, 89, '2025-03-08', '2025-04-07', 245414.75, 18.00, 44174.66, 289589.41, 'payee', '2025-03-22 00:51:45', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-08 00:00:00', NULL),
(90, 'FACT2025050090', 6, 90, '2025-05-31', '2025-06-30', 251329.72, 18.00, 45239.35, 296569.07, 'payee', '2025-06-01 15:13:06', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-30 00:00:00', NULL),
(91, 'FACT2025050091', 38, 91, '2025-05-12', '2025-06-11', 181683.74, 18.00, 32703.07, 214386.81, 'payee', '2025-06-08 17:31:47', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-10 00:00:00', NULL),
(92, 'FACT2025040092', 171, 92, '2025-04-26', '2025-05-26', 233729.85, 18.00, 42071.37, 275801.22, 'payee', '2025-05-23 13:33:12', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-26 00:00:00', NULL),
(93, 'FACT2025040093', 99, 93, '2025-04-15', '2025-05-15', 6640.92, 18.00, 1195.37, 7836.29, 'payee', '2025-04-15 10:45:40', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-15 00:00:00', NULL),
(94, 'FACT2025040094', 67, 94, '2025-04-16', '2025-05-16', 1444345.37, 18.00, 259982.17, 1704327.54, 'payee', '2025-04-22 17:21:27', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-16 00:00:00', NULL),
(95, 'FACT2025010095', 66, 95, '2025-01-21', '2025-02-20', 724839.08, 18.00, 130471.03, 855310.11, 'payee', '2025-02-18 07:24:48', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-19 00:00:00', NULL),
(96, 'FACT2025040096', 50, 96, '2025-04-18', '2025-05-18', 365970.37, 18.00, 65874.67, 431845.04, 'payee', '2025-05-15 22:41:19', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-17 00:00:00', NULL),
(97, 'FACT2024110097', 195, 97, '2024-11-27', '2024-12-27', 448241.32, 18.00, 80683.44, 528924.76, 'payee', '2024-12-23 01:48:46', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-11-27 00:00:00', NULL),
(98, 'FACT2025020098', 25, 98, '2025-02-01', '2025-03-03', 1177410.55, 18.00, 211933.90, 1389344.45, 'payee', '2025-02-21 04:12:41', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-31 00:00:00', NULL),
(99, 'FACT2025040099', 103, 99, '2025-04-19', '2025-05-19', 485369.78, 18.00, 87366.56, 572736.34, 'payee', '2025-05-12 13:43:01', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-17 00:00:00', NULL),
(100, 'FACT2025020100', 155, 100, '2025-02-20', '2025-03-22', 914556.94, 18.00, 164620.25, 1079177.19, 'payee', '2025-03-13 05:04:09', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-19 00:00:00', NULL),
(101, 'FACT2025050101', 44, 101, '2025-05-01', '2025-05-31', 412121.69, 18.00, 74181.90, 486303.59, 'payee', '2025-05-20 14:42:17', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-29 00:00:00', NULL),
(102, 'FACT2025050102', 107, 102, '2025-05-06', '2025-06-05', 441395.14, 18.00, 79451.13, 520846.27, 'payee', '2025-05-17 10:45:10', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-04 00:00:00', NULL),
(103, 'FACT2025010103', 169, 103, '2025-01-30', '2025-03-01', 276679.37, 18.00, 49802.29, 326481.66, 'payee', '2025-02-16 16:31:31', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-28 00:00:00', NULL),
(104, 'FACT2025030104', 180, 104, '2025-03-26', '2025-04-25', 469907.68, 18.00, 84583.38, 554491.06, 'payee', '2025-04-02 19:25:09', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-25 00:00:00', NULL),
(105, 'FACT2025050105', 71, 105, '2025-05-24', '2025-06-23', 387242.88, 18.00, 69703.72, 456946.60, 'payee', '2025-06-01 16:29:18', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-05-24 00:00:00', NULL),
(106, 'FACT2025040106', 147, 106, '2025-04-02', '2025-05-02', 601875.42, 18.00, 108337.58, 710213.00, 'payee', '2025-04-03 06:19:58', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-31 00:00:00', NULL),
(107, 'FACT2025020107', 34, 107, '2025-02-19', '2025-03-21', 146676.40, 18.00, 26401.75, 173078.15, 'payee', '2025-03-14 18:50:39', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-17 00:00:00', NULL),
(108, 'FACT2024110108', 96, 108, '2024-11-27', '2024-12-27', 242833.23, 18.00, 43709.98, 286543.21, 'payee', '2024-12-14 01:03:31', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-26 00:00:00', NULL),
(109, 'FACT2025020109', 118, 109, '2025-02-07', '2025-03-09', 187283.88, 18.00, 33711.10, 220994.98, 'payee', '2025-02-07 16:25:51', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-07 00:00:00', NULL),
(110, 'FACT2024110110', 89, 110, '2024-11-27', '2024-12-27', 540064.80, 18.00, 97211.66, 637276.46, 'payee', '2024-12-01 02:27:09', 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-11-27 00:00:00', NULL),
(111, 'FACT2024120111', 139, 111, '2024-12-29', '2025-01-28', 301938.00, 18.00, 54348.84, 356286.84, 'payee', '2024-12-29 02:15:36', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-12-29 00:00:00', NULL),
(112, 'FACT2025020112', 113, 112, '2025-02-09', '2025-03-11', 30611.42, 18.00, 5510.06, 36121.48, 'payee', '2025-02-26 07:07:47', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-02-07 00:00:00', NULL),
(113, 'FACT2025010113', 8, 113, '2025-01-19', '2025-02-18', 127958.90, 18.00, 23032.60, 150991.50, 'payee', '2025-02-15 22:37:40', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-17 00:00:00', NULL),
(114, 'FACT2025050114', 72, 114, '2025-05-12', '2025-06-11', 35336.50, 18.00, 6360.57, 41697.07, 'payee', '2025-05-22 03:49:31', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-05-12 00:00:00', NULL),
(115, 'FACT2025020115', 84, 115, '2025-02-03', '2025-03-05', 6872.94, 18.00, 1237.13, 8110.07, 'payee', '2025-02-11 03:22:01', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-02 00:00:00', NULL),
(116, 'FACT2025030116', 120, 116, '2025-03-09', '2025-04-08', 27519.81, 18.00, 4953.57, 32473.38, 'payee', '2025-03-11 21:06:06', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-07 00:00:00', NULL),
(117, 'FACT2024120117', 140, 117, '2024-12-30', '2025-01-29', 827410.75, 18.00, 148933.94, 976344.69, 'payee', '2025-01-24 00:31:44', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-30 00:00:00', NULL),
(118, 'FACT2025030118', 13, 118, '2025-03-05', '2025-04-04', 448762.41, 18.00, 80777.23, 529539.64, 'payee', '2025-03-22 04:45:58', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-04 00:00:00', NULL),
(119, 'FACT2025010119', 153, 119, '2025-01-30', '2025-03-01', 169745.44, 18.00, 30554.18, 200299.62, 'payee', '2025-02-20 22:00:42', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-29 00:00:00', NULL),
(120, 'FACT2024120120', 30, 120, '2024-12-08', '2025-01-07', 324888.66, 18.00, 58479.96, 383368.62, 'payee', '2024-12-12 03:39:17', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-12-08 00:00:00', NULL),
(121, 'FACT2025060121', 143, 121, '2025-06-04', '2025-07-04', 852047.72, 18.00, 153368.59, 1005416.31, 'payee', '2025-06-18 08:28:17', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-06-03 00:00:00', NULL),
(122, 'FACT2025040122', 190, 122, '2025-04-24', '2025-05-24', 338711.49, 18.00, 60968.07, 399679.56, 'payee', '2025-05-10 19:24:12', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-22 00:00:00', NULL),
(123, 'FACT2025020123', 163, 123, '2025-02-20', '2025-03-22', 161598.78, 18.00, 29087.78, 190686.56, 'payee', '2025-03-01 05:25:07', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-02-18 00:00:00', NULL),
(124, 'FACT2025050124', 119, 124, '2025-05-11', '2025-06-10', 16636.52, 18.00, 2994.57, 19631.09, 'payee', '2025-06-03 08:01:07', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-11 00:00:00', NULL),
(125, 'FACT2025050125', 101, 125, '2025-05-01', '2025-05-31', 162866.11, 18.00, 29315.90, 192182.01, 'payee', '2025-05-28 06:23:18', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-30 00:00:00', NULL),
(126, 'FACT2025020126', 79, 126, '2025-02-21', '2025-03-23', 197089.20, 18.00, 35476.06, 232565.26, 'payee', '2025-03-13 06:01:33', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-02-19 00:00:00', NULL),
(127, 'FACT2025050127', 131, 127, '2025-05-08', '2025-06-07', 167059.87, 18.00, 30070.78, 197130.65, 'payee', '2025-05-24 17:13:43', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-05-06 00:00:00', NULL),
(128, 'FACT2025010128', 95, 128, '2025-01-22', '2025-02-21', 623391.84, 18.00, 112210.53, 735602.37, 'payee', '2025-02-10 06:04:49', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-20 00:00:00', NULL),
(129, 'FACT2024110129', 93, 129, '2024-11-23', '2024-12-23', 268766.97, 18.00, 48378.05, 317145.02, 'payee', '2024-12-20 13:15:45', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-11-23 00:00:00', NULL),
(130, 'FACT2025040130', 176, 130, '2025-04-26', '2025-05-26', 356936.85, 18.00, 64248.63, 421185.48, 'payee', '2025-05-02 07:45:40', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-24 00:00:00', NULL),
(131, 'FACT2025020131', 56, 131, '2025-02-08', '2025-03-10', 786651.24, 18.00, 141597.22, 928248.46, 'payee', '2025-03-07 23:19:48', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-08 00:00:00', NULL),
(132, 'FACT2025010132', 55, 132, '2025-01-12', '2025-02-11', 1006441.26, 18.00, 181159.43, 1187600.69, 'payee', '2025-01-27 23:41:09', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-12 00:00:00', NULL),
(133, 'FACT2025010133', 64, 133, '2025-01-31', '2025-03-02', 300849.45, 18.00, 54152.90, 355002.35, 'payee', '2025-02-08 11:25:20', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-29 00:00:00', NULL),
(134, 'FACT2025030134', 46, 134, '2025-03-25', '2025-04-24', 180644.80, 18.00, 32516.06, 213160.86, 'payee', '2025-04-05 00:33:02', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-24 00:00:00', NULL),
(135, 'FACT2025040135', 142, 135, '2025-04-05', '2025-05-05', 228583.84, 18.00, 41145.09, 269728.93, 'payee', '2025-04-21 02:46:30', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-04 00:00:00', NULL),
(136, 'FACT2025030136', 23, 136, '2025-03-22', '2025-04-21', 101523.00, 18.00, 18274.14, 119797.14, 'payee', '2025-04-01 11:41:03', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-20 00:00:00', NULL),
(137, 'FACT2024120137', 117, 137, '2024-12-15', '2025-01-14', 16909.51, 18.00, 3043.71, 19953.22, 'payee', '2024-12-22 02:34:47', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-12-15 00:00:00', NULL),
(138, 'FACT2025020138', 24, 138, '2025-02-13', '2025-03-15', 70229.11, 18.00, 12641.24, 82870.35, 'payee', '2025-03-10 14:26:38', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-13 00:00:00', NULL),
(139, 'FACT2025020139', 39, 139, '2025-02-28', '2025-03-30', 259937.20, 18.00, 46788.70, 306725.90, 'payee', '2025-03-24 19:09:49', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-28 00:00:00', NULL),
(140, 'FACT2025010140', 77, 140, '2025-01-31', '2025-03-02', 994015.72, 18.00, 178922.83, 1172938.55, 'payee', '2025-02-24 10:19:18', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-31 00:00:00', NULL),
(141, 'FACT2025040141', 158, 141, '2025-04-02', '2025-05-02', 893582.40, 18.00, 160844.83, 1054427.23, 'payee', '2025-04-13 16:54:11', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-01 00:00:00', NULL),
(142, 'FACT2025040142', 18, 142, '2025-04-04', '2025-05-04', 321815.65, 18.00, 57926.82, 379742.47, 'payee', '2025-04-18 04:18:40', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-04 00:00:00', NULL),
(143, 'FACT2025030143', 28, 143, '2025-03-31', '2025-04-30', 191516.94, 18.00, 34473.05, 225989.99, 'payee', '2025-04-06 19:45:05', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-03-29 00:00:00', NULL),
(144, 'FACT2024120144', 179, 144, '2024-12-03', '2025-01-02', 45417.31, 18.00, 8175.12, 53592.43, 'payee', '2024-12-04 19:19:18', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-02 00:00:00', NULL),
(145, 'FACT2025050145', 196, 145, '2025-05-12', '2025-06-11', 661288.00, 18.00, 119031.84, 780319.84, 'payee', '2025-06-04 02:52:52', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-11 00:00:00', NULL),
(146, 'FACT2025020146', 138, 146, '2025-02-08', '2025-03-10', 294175.18, 18.00, 52951.53, 347126.71, 'payee', '2025-02-23 01:26:38', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-02-07 00:00:00', NULL),
(147, 'FACT2025040147', 14, 147, '2025-04-15', '2025-05-15', 330779.19, 18.00, 59540.25, 390319.44, 'payee', '2025-05-03 16:28:05', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-15 00:00:00', NULL),
(148, 'FACT2025010148', 106, 148, '2025-01-09', '2025-02-08', 434895.43, 18.00, 78281.18, 513176.61, 'payee', '2025-01-24 04:07:38', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-07 00:00:00', NULL),
(149, 'FACT2025010149', 97, 149, '2025-01-24', '2025-02-23', 240909.23, 18.00, 43363.66, 284272.89, 'payee', '2025-02-01 21:31:12', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-24 00:00:00', NULL),
(150, 'FACT2025030150', 69, 150, '2025-03-06', '2025-04-05', 861346.87, 18.00, 155042.44, 1016389.31, 'payee', '2025-03-24 22:50:34', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-05 00:00:00', NULL),
(151, 'FACT2024120151', 161, 151, '2024-12-29', '2025-01-28', 615589.14, 18.00, 110806.05, 726395.19, 'payee', '2025-01-02 00:30:34', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-28 00:00:00', NULL),
(152, 'FACT2024110152', 12, 152, '2024-11-22', '2024-12-22', 331176.84, 18.00, 59611.83, 390788.67, 'payee', '2024-12-01 13:23:56', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-11-20 00:00:00', NULL),
(153, 'FACT2025020153', 104, 153, '2025-02-19', '2025-03-21', 76685.08, 18.00, 13803.31, 90488.39, 'payee', '2025-02-27 22:12:34', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-18 00:00:00', NULL),
(154, 'FACT2024120154', 173, 154, '2024-12-04', '2025-01-03', 72461.85, 18.00, 13043.13, 85504.98, 'payee', '2024-12-27 07:33:08', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-03 00:00:00', NULL),
(155, 'FACT2025050155', 115, 155, '2025-05-03', '2025-06-02', 803100.64, 18.00, 144558.12, 947658.76, 'payee', '2025-05-03 06:51:15', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-01 00:00:00', NULL),
(156, 'FACT2025050156', 175, 156, '2025-05-21', '2025-06-20', 448089.95, 18.00, 80656.19, 528746.14, 'payee', '2025-06-05 11:35:42', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-19 00:00:00', NULL),
(157, 'FACT2025010157', 100, 157, '2025-01-10', '2025-02-09', 916796.29, 18.00, 165023.33, 1081819.62, 'payee', '2025-01-26 04:14:19', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-08 00:00:00', NULL),
(158, 'FACT2025040158', 170, 158, '2025-04-15', '2025-05-15', 253052.32, 18.00, 45549.42, 298601.74, 'payee', '2025-04-16 13:25:32', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-13 00:00:00', NULL),
(159, 'FACT2025030159', 1, 159, '2025-03-20', '2025-04-19', 70616.99, 18.00, 12711.06, 83328.05, 'payee', '2025-04-09 05:59:40', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-19 00:00:00', NULL),
(160, 'FACT2025030160', 80, 160, '2025-03-04', '2025-04-03', 1052169.13, 18.00, 189390.44, 1241559.57, 'payee', '2025-03-28 21:21:41', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-03-03 00:00:00', NULL),
(161, 'FACT2025030161', 172, 161, '2025-03-26', '2025-04-25', 165319.60, 18.00, 29757.53, 195077.13, 'payee', '2025-04-06 09:15:59', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-03-24 00:00:00', NULL),
(162, 'FACT2025040162', 68, 162, '2025-04-16', '2025-05-16', 798324.44, 18.00, 143698.40, 942022.84, 'payee', '2025-05-11 22:44:01', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-16 00:00:00', NULL),
(163, 'FACT2025050163', 49, 163, '2025-05-24', '2025-06-23', 59122.04, 18.00, 10641.97, 69764.01, 'payee', '2025-06-09 04:39:44', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-22 00:00:00', NULL),
(164, 'FACT2025010164', 187, 164, '2025-01-26', '2025-02-25', 443584.08, 18.00, 79845.13, 523429.21, 'payee', '2025-01-26 14:04:10', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-24 00:00:00', NULL),
(165, 'FACT2025050165', 19, 165, '2025-05-25', '2025-06-24', 194724.63, 18.00, 35050.43, 229775.06, 'payee', '2025-06-11 19:17:27', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-05-24 00:00:00', NULL),
(166, 'FACT2024110166', 91, 166, '2024-11-22', '2024-12-22', 427397.69, 18.00, 76931.58, 504329.27, 'payee', '2024-12-18 14:08:33', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-11-21 00:00:00', NULL),
(167, 'FACT2025050167', 92, 167, '2025-05-29', '2025-06-28', 681958.47, 18.00, 122752.52, 804710.99, 'payee', '2025-06-16 21:50:43', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-27 00:00:00', NULL),
(168, 'FACT2025020168', 58, 168, '2025-02-11', '2025-03-13', 141238.62, 18.00, 25422.95, 166661.57, 'payee', '2025-02-14 09:37:23', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-09 00:00:00', NULL),
(169, 'FACT2024110169', 112, 169, '2024-11-26', '2024-12-26', 580704.32, 18.00, 104526.78, 685231.10, 'payee', '2024-11-28 18:44:36', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-11-24 00:00:00', NULL),
(170, 'FACT2024120170', 74, 170, '2024-12-19', '2025-01-18', 19133.23, 18.00, 3443.98, 22577.21, 'payee', '2024-12-21 02:34:16', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-12-17 00:00:00', NULL),
(171, 'FACT2025040171', 135, 171, '2025-04-16', '2025-05-16', 428703.68, 18.00, 77166.66, 505870.34, 'payee', '2025-05-04 23:55:30', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-16 00:00:00', NULL),
(172, 'FACT2024120172', 48, 172, '2024-12-21', '2025-01-20', 76539.94, 18.00, 13777.19, 90317.13, 'payee', '2024-12-21 16:44:19', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-19 00:00:00', NULL),
(173, 'FACT2025060173', 102, 173, '2025-06-02', '2025-07-02', 298896.38, 18.00, 53801.35, 352697.73, 'payee', '2025-06-15 03:52:17', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-06-02 00:00:00', NULL),
(174, 'FACT2025020174', 159, 174, '2025-02-02', '2025-03-04', 187017.72, 18.00, 33663.19, 220680.91, 'payee', '2025-02-15 08:51:15', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-01 00:00:00', NULL),
(175, 'FACT2025020175', 110, 175, '2025-02-11', '2025-03-13', 222155.29, 18.00, 39987.95, 262143.24, 'payee', '2025-02-11 14:58:19', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-09 00:00:00', NULL),
(176, 'FACT2025030176', 111, 176, '2025-03-05', '2025-04-04', 33719.87, 18.00, 6069.58, 39789.45, 'payee', '2025-03-07 03:44:20', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-05 00:00:00', NULL),
(177, 'FACT2024110177', 27, 177, '2024-11-18', '2024-12-18', 14364.76, 18.00, 2585.66, 16950.42, 'payee', '2024-11-29 23:22:48', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-11-17 00:00:00', NULL),
(178, 'FACT2025050178', 157, 178, '2025-05-02', '2025-06-01', 106131.17, 18.00, 19103.61, 125234.78, 'payee', '2025-05-20 13:33:45', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-02 00:00:00', NULL),
(179, 'FACT2025040179', 15, 179, '2025-04-20', '2025-05-20', 11450.06, 18.00, 2061.01, 13511.07, 'payee', '2025-05-01 10:46:29', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-18 00:00:00', NULL),
(180, 'FACT2025020180', 61, 180, '2025-02-09', '2025-03-11', 53933.91, 18.00, 9708.10, 63642.01, 'payee', '2025-02-13 06:27:50', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-09 00:00:00', NULL),
(181, 'FACT2025030181', 186, 181, '2025-03-25', '2025-04-24', 977191.51, 18.00, 175894.47, 1153085.98, 'payee', '2025-04-23 12:51:09', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-23 00:00:00', NULL),
(182, 'FACT2025050182', 3, 182, '2025-05-03', '2025-06-02', 239931.42, 18.00, 43187.66, 283119.08, 'payee', '2025-05-07 03:36:58', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-05-01 00:00:00', NULL),
(183, 'FACT2025040183', 148, 183, '2025-04-16', '2025-05-16', 442773.76, 18.00, 79699.28, 522473.04, 'payee', '2025-04-29 03:53:24', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-15 00:00:00', NULL),
(184, 'FACT2024110184', 54, 184, '2024-11-19', '2024-12-19', 94281.52, 18.00, 16970.67, 111252.19, 'payee', '2024-11-21 12:17:38', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-11-18 00:00:00', NULL),
(185, 'FACT2024120185', 51, 185, '2024-12-05', '2025-01-04', 870358.18, 18.00, 156664.47, 1027022.65, 'payee', '2024-12-24 12:59:10', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-04 00:00:00', NULL),
(186, 'FACT2025020186', 185, 186, '2025-02-08', '2025-03-10', 969887.58, 18.00, 174579.76, 1144467.34, 'payee', '2025-02-11 14:00:16', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-08 00:00:00', NULL),
(187, 'FACT2025040187', 168, 187, '2025-04-21', '2025-05-21', 139294.14, 18.00, 25072.95, 164367.09, 'payee', '2025-05-04 09:01:33', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-20 00:00:00', NULL),
(188, 'FACT2025030188', 20, 188, '2025-03-11', '2025-04-10', 118466.72, 18.00, 21324.01, 139790.73, 'payee', '2025-04-08 11:02:23', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-10 00:00:00', NULL),
(189, 'FACT2024120189', 192, 189, '2024-12-04', '2025-01-03', 1228929.95, 18.00, 221207.39, 1450137.34, 'payee', '2024-12-18 16:21:16', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-02 00:00:00', NULL),
(190, 'FACT2025050190', 94, 190, '2025-05-11', '2025-06-10', 1587010.38, 18.00, 285661.87, 1872672.25, 'payee', '2025-06-03 03:44:16', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-11 00:00:00', NULL),
(191, 'FACT2025010191', 17, 191, '2025-01-26', '2025-02-25', 9486.75, 18.00, 1707.62, 11194.37, 'payee', '2025-01-31 18:09:33', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-26 00:00:00', NULL),
(192, 'FACT2025050192', 123, 192, '2025-05-15', '2025-06-14', 272147.53, 18.00, 48986.56, 321134.09, 'payee', '2025-05-25 18:26:54', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-13 00:00:00', NULL),
(193, 'FACT2025020193', 29, 193, '2025-02-23', '2025-03-25', 262304.34, 18.00, 47214.78, 309519.12, 'payee', '2025-03-22 11:59:11', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-22 00:00:00', NULL),
(194, 'FACT2025030194', 130, 194, '2025-03-27', '2025-04-26', 621720.90, 18.00, 111909.76, 733630.66, 'payee', '2025-04-12 05:32:31', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-27 00:00:00', NULL),
(195, 'FACT2024110195', 134, 195, '2024-11-22', '2024-12-22', 1024190.98, 18.00, 184354.38, 1208545.36, 'payee', '2024-12-13 23:49:19', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-11-22 00:00:00', NULL),
(196, 'FACT2025050196', 149, 196, '2025-05-08', '2025-06-07', 21620.09, 18.00, 3891.62, 25511.71, 'payee', '2025-05-15 00:58:27', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-05-06 00:00:00', NULL),
(197, 'FACT2025030197', 152, 197, '2025-03-28', '2025-04-27', 746310.96, 18.00, 134335.97, 880646.93, 'payee', '2025-04-13 12:11:53', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-27 00:00:00', NULL),
(198, 'FACT2025010198', 128, 198, '2025-01-07', '2025-02-06', 360645.20, 18.00, 64916.14, 425561.34, 'payee', '2025-01-08 07:54:59', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-05 00:00:00', NULL),
(199, 'FACT2024120199', 116, 199, '2024-12-24', '2025-01-23', 1094494.77, 18.00, 197009.06, 1291503.83, 'payee', '2025-01-10 01:40:09', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-12-24 00:00:00', NULL),
(200, 'FACT2024110200', 144, 200, '2024-11-27', '2024-12-27', 44289.36, 18.00, 7972.08, 52261.44, 'payee', '2024-12-11 12:36:15', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-11-25 00:00:00', NULL),
(201, 'FACT2025040201', 133, 201, '2025-04-16', '2025-05-16', 327103.82, 18.00, 58878.69, 385982.51, 'payee', '2025-04-21 14:37:16', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-14 00:00:00', NULL),
(202, 'FACT2025020202', 60, 202, '2025-02-15', '2025-03-17', 306026.40, 18.00, 55084.75, 361111.15, 'payee', '2025-02-23 10:58:11', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-14 00:00:00', NULL),
(203, 'FACT2025010203', 154, 203, '2025-01-20', '2025-02-19', 78346.63, 18.00, 14102.39, 92449.02, 'payee', '2025-02-01 09:41:40', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-20 00:00:00', NULL),
(204, 'FACT2025010204', 2, 204, '2025-01-08', '2025-02-07', 1242678.31, 18.00, 223682.10, 1466360.41, 'payee', '2025-01-20 09:23:51', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-06 00:00:00', NULL),
(205, 'FACT2025040205', 177, 205, '2025-04-10', '2025-05-10', 126094.18, 18.00, 22696.95, 148791.13, 'payee', '2025-04-30 14:17:02', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-10 00:00:00', NULL),
(206, 'FACT2025040206', 82, 206, '2025-04-19', '2025-05-19', 20226.24, 18.00, 3640.72, 23866.96, 'payee', '2025-04-20 17:12:29', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-19 00:00:00', NULL),
(207, 'FACT2025020207', 10, 207, '2025-02-28', '2025-03-30', 479457.59, 18.00, 86302.37, 565759.96, 'payee', '2025-03-22 19:49:39', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-27 00:00:00', NULL),
(208, 'FACT2025020208', 90, 208, '2025-02-04', '2025-03-06', 400199.06, 18.00, 72035.83, 472234.89, 'payee', '2025-02-04 10:52:47', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-03 00:00:00', NULL),
(209, 'FACT2025010209', 81, 209, '2025-01-24', '2025-02-23', 421050.05, 18.00, 75789.01, 496839.06, 'payee', '2025-02-01 03:08:33', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-24 00:00:00', NULL),
(210, 'FACT2025020210', 59, 210, '2025-02-05', '2025-03-07', 129909.09, 18.00, 23383.64, 153292.73, 'payee', '2025-02-19 06:59:54', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-03 00:00:00', NULL),
(211, 'FACT2024120211', 36, 211, '2024-12-20', '2025-01-19', 735794.69, 18.00, 132443.04, 868237.73, 'payee', '2024-12-20 07:29:20', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-12-18 00:00:00', NULL),
(212, 'FACT2025030212', 151, 212, '2025-03-23', '2025-04-22', 486487.19, 18.00, 87567.69, 574054.88, 'payee', '2025-04-20 15:01:08', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-03-23 00:00:00', NULL),
(213, 'FACT2025020213', 98, 213, '2025-02-12', '2025-03-14', 606608.36, 18.00, 109189.50, 715797.86, 'payee', '2025-02-23 07:42:06', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-11 00:00:00', NULL),
(214, 'FACT2025040214', 76, 214, '2025-04-01', '2025-05-01', 144162.01, 18.00, 25949.16, 170111.17, 'payee', '2025-04-03 02:41:10', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-31 00:00:00', NULL),
(215, 'FACT2024120215', 35, 215, '2024-12-13', '2025-01-12', 60899.91, 18.00, 10961.98, 71861.89, 'payee', '2025-01-07 23:40:14', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-12-13 00:00:00', NULL),
(216, 'FACT2025030216', 32, 216, '2025-03-14', '2025-04-13', 815569.46, 18.00, 146802.50, 962371.96, 'payee', '2025-04-06 17:41:06', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-13 00:00:00', NULL),
(217, 'FACT2024120217', 37, 217, '2024-12-06', '2025-01-05', 235212.02, 18.00, 42338.16, 277550.18, 'payee', '2024-12-17 01:15:00', 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-12-06 00:00:00', NULL),
(218, 'FACT2025010218', 78, 218, '2025-01-17', '2025-02-16', 71684.15, 18.00, 12903.15, 84587.30, 'payee', '2025-02-04 03:40:03', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-17 00:00:00', NULL),
(219, 'FACT2025010219', 191, 219, '2025-01-10', '2025-02-09', 94188.47, 18.00, 16953.92, 111142.39, 'payee', '2025-01-29 04:17:51', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-09 00:00:00', NULL),
(220, 'FACT2025040220', 83, 220, '2025-04-26', '2025-05-26', 527242.72, 18.00, 94903.69, 622146.41, 'payee', '2025-04-30 17:01:00', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-25 00:00:00', NULL),
(221, 'FACT2025040221', 7, 221, '2025-04-26', '2025-05-26', 295716.40, 18.00, 53228.95, 348945.35, 'payee', '2025-04-28 08:26:34', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-25 00:00:00', NULL),
(222, 'FACT2024110222', 122, 222, '2024-11-17', '2024-12-17', 19779.64, 18.00, 3560.34, 23339.98, 'payee', '2024-12-06 22:54:39', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-11-17 00:00:00', NULL),
(223, 'FACT2025010223', 109, 223, '2025-01-15', '2025-02-14', 927158.21, 18.00, 166888.48, 1094046.69, 'payee', '2025-02-07 12:29:25', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-15 00:00:00', NULL),
(224, 'FACT2025050224', 47, 224, '2025-05-10', '2025-06-09', 1050052.40, 18.00, 189009.43, 1239061.83, 'payee', '2025-05-13 10:09:44', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-08 00:00:00', NULL),
(225, 'FACT2025010225', 125, 225, '2025-01-12', '2025-02-11', 795933.99, 18.00, 143268.12, 939202.11, 'payee', '2025-02-07 13:52:17', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-10 00:00:00', NULL);
INSERT INTO `factures` (`id`, `numero_facture`, `client_id`, `commande_id`, `date_facture`, `date_echeance`, `montant_ht`, `taux_tva`, `montant_tva`, `montant_ttc`, `statut`, `date_paiement`, `description`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(226, 'FACT2025010226', 31, 226, '2025-01-17', '2025-02-16', 13544.80, 18.00, 2438.06, 15982.86, 'payee', '2025-02-05 19:49:59', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-17 00:00:00', NULL),
(227, 'FACT2025030227', 33, 227, '2025-03-11', '2025-04-10', 216908.95, 18.00, 39043.61, 255952.56, 'payee', '2025-04-02 01:11:46', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-10 00:00:00', NULL),
(228, 'FACT2025010228', 124, 228, '2025-01-12', '2025-02-11', 180493.75, 18.00, 32488.88, 212982.63, 'payee', '2025-01-19 16:08:56', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-11 00:00:00', NULL),
(229, 'FACT2025030229', 193, 229, '2025-03-15', '2025-04-14', 109144.48, 18.00, 19646.01, 128790.49, 'payee', '2025-03-17 03:28:58', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-13 00:00:00', NULL),
(230, 'FACT2024110230', 21, 230, '2024-11-19', '2024-12-19', 119930.18, 18.00, 21587.43, 141517.61, 'payee', '2024-12-15 15:27:55', 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-11-18 00:00:00', NULL),
(231, 'FACT2025040231', 127, 231, '2025-04-20', '2025-05-20', 1855716.86, 18.00, 334029.03, 2189745.89, 'payee', '2025-05-05 06:26:37', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-20 00:00:00', NULL),
(232, 'FACT2024110232', 52, 232, '2024-11-17', '2024-12-17', 519083.10, 18.00, 93434.96, 612518.06, 'payee', '2024-12-16 02:48:50', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-11-17 00:00:00', NULL),
(233, 'FACT2025040233', 87, 233, '2025-04-28', '2025-05-28', 535000.36, 18.00, 96300.06, 631300.42, 'payee', '2025-05-08 09:47:04', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-26 00:00:00', NULL),
(234, 'FACT2025030234', 194, 234, '2025-03-16', '2025-04-15', 194240.10, 18.00, 34963.22, 229203.32, 'payee', '2025-03-28 08:49:04', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-14 00:00:00', NULL),
(235, 'FACT2025050235', 150, 235, '2025-05-19', '2025-06-18', 338877.91, 18.00, 60998.02, 399875.93, 'payee', '2025-05-26 20:48:33', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-05-19 00:00:00', NULL),
(236, 'FACT2025020236', 88, 236, '2025-02-17', '2025-03-19', 119046.99, 18.00, 21428.46, 140475.45, 'payee', '2025-02-17 13:38:56', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-02-15 00:00:00', NULL),
(237, 'FACT2024120237', 184, 237, '2024-12-05', '2025-01-04', 135938.63, 18.00, 24468.95, 160407.58, 'payee', '2025-01-02 14:07:16', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-04 00:00:00', NULL),
(238, 'FACT2025030238', 41, 238, '2025-03-21', '2025-04-20', 62502.22, 18.00, 11250.40, 73752.62, 'payee', '2025-04-02 08:58:08', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-03-21 00:00:00', NULL),
(239, 'FACT2025040239', 22, 239, '2025-04-24', '2025-05-24', 153026.52, 18.00, 27544.77, 180571.29, 'payee', '2025-05-06 00:22:37', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-24 00:00:00', NULL),
(240, 'FACT2025020240', 145, 240, '2025-02-10', '2025-03-12', 57115.26, 18.00, 10280.75, 67396.01, 'payee', '2025-03-04 20:03:10', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-08 00:00:00', NULL),
(241, 'FACT2025030241', 146, 241, '2025-03-27', '2025-04-26', 935997.73, 18.00, 168479.59, 1104477.32, 'payee', '2025-03-31 14:25:52', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-27 00:00:00', NULL),
(242, 'FACT2024110242', 26, 242, '2024-11-18', '2024-12-18', 1158468.54, 18.00, 208524.34, 1366992.88, 'payee', '2024-11-29 01:43:44', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-18 00:00:00', NULL),
(243, 'FACT2025030243', 164, 243, '2025-03-18', '2025-04-17', 10228.36, 18.00, 1841.10, 12069.46, 'payee', '2025-03-30 09:29:13', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-17 00:00:00', NULL),
(244, 'FACT2024110244', 156, 244, '2024-11-30', '2024-12-30', 1258626.33, 18.00, 226552.74, 1485179.07, 'payee', '2024-12-26 07:00:22', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-28 00:00:00', NULL),
(245, 'FACT2025020245', 40, 245, '2025-02-09', '2025-03-11', 44810.63, 18.00, 8065.91, 52876.54, 'payee', '2025-02-28 13:21:20', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-08 00:00:00', NULL),
(246, 'FACT2025040246', 160, 246, '2025-04-24', '2025-05-24', 441438.23, 18.00, 79458.88, 520897.11, 'payee', '2025-04-26 15:04:42', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-24 00:00:00', NULL),
(247, 'FACT2025050247', 86, 247, '2025-05-08', '2025-06-07', 38334.47, 18.00, 6900.20, 45234.67, 'payee', '2025-05-10 12:18:53', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-07 00:00:00', NULL),
(248, 'FACT2025030248', 114, 248, '2025-03-21', '2025-04-20', 519492.92, 18.00, 93508.73, 613001.65, 'payee', '2025-04-02 23:52:53', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-20 00:00:00', NULL),
(249, 'FACT2024110249', 141, 249, '2024-11-18', '2024-12-18', 262035.50, 18.00, 47166.39, 309201.89, 'payee', '2024-11-22 06:01:48', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-11-16 00:00:00', NULL),
(250, 'FACT2025010250', 182, 250, '2025-01-30', '2025-03-01', 561196.65, 18.00, 101015.40, 662212.05, 'payee', '2025-02-17 00:23:03', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-29 00:00:00', NULL),
(251, 'FACT2025030251', 65, 251, '2025-03-21', '2025-04-20', 241774.91, 18.00, 43519.48, 285294.39, 'payee', '2025-04-19 10:43:00', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-03-20 00:00:00', NULL),
(252, 'FACT2024120252', 53, 252, '2024-12-08', '2025-01-07', 929287.38, 18.00, 167271.73, 1096559.11, 'payee', '2024-12-16 14:42:36', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-12-07 00:00:00', NULL),
(253, 'FACT2025040253', 73, 253, '2025-04-02', '2025-05-02', 138697.60, 18.00, 24965.57, 163663.17, 'payee', '2025-04-30 23:25:02', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-01 00:00:00', NULL),
(254, 'FACT2025020254', 166, 254, '2025-02-21', '2025-03-23', 130509.31, 18.00, 23491.68, 154000.99, 'payee', '2025-02-27 06:23:57', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-21 00:00:00', NULL),
(255, 'FACT2025050255', 16, 255, '2025-05-29', '2025-06-28', 34120.64, 18.00, 6141.72, 40262.36, 'payee', '2025-06-01 03:31:10', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-05-28 00:00:00', NULL),
(256, 'FACT2025040256', 5, 256, '2025-04-04', '2025-05-04', 332637.74, 18.00, 59874.79, 392512.53, 'payee', '2025-05-02 02:10:25', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-04 00:00:00', NULL),
(257, 'FACT2025050257', 189, 257, '2025-05-14', '2025-06-13', 446041.11, 18.00, 80287.40, 526328.51, 'payee', '2025-05-25 23:54:57', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-13 00:00:00', NULL),
(258, 'FACT2024120258', 75, 258, '2024-12-10', '2025-01-09', 391720.11, 18.00, 70509.62, 462229.73, 'payee', '2024-12-17 09:07:09', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-09 00:00:00', NULL),
(259, 'FACT2025010259', 108, 259, '2025-01-22', '2025-02-21', 12139.85, 18.00, 2185.17, 14325.02, 'payee', '2025-01-30 13:44:35', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-21 00:00:00', NULL),
(260, 'FACT2025020260', 43, 260, '2025-02-19', '2025-03-21', 534463.91, 18.00, 96203.50, 630667.41, 'payee', '2025-03-13 17:36:44', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-19 00:00:00', NULL),
(261, 'FACT2024110261', 126, 261, '2024-11-18', '2024-12-18', 469425.42, 18.00, 84496.58, 553922.00, 'payee', '2024-11-29 16:54:35', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-11-16 00:00:00', NULL),
(262, 'FACT2025010262', 188, 262, '2025-01-21', '2025-02-20', 85291.53, 18.00, 15352.48, 100644.01, 'payee', '2025-02-01 15:40:25', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-20 00:00:00', NULL),
(263, 'FACT2025020263', 70, 263, '2025-02-18', '2025-03-20', 95955.87, 18.00, 17272.06, 113227.93, 'payee', '2025-02-25 17:33:07', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-02-18 00:00:00', NULL),
(264, 'FACT2024120264', 9, 264, '2024-12-22', '2025-01-21', 193063.29, 18.00, 34751.39, 227814.68, 'payee', '2025-01-01 22:45:16', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-21 00:00:00', NULL),
(265, 'FACT2025040265', 181, 265, '2025-04-27', '2025-05-27', 6976.83, 18.00, 1255.83, 8232.66, 'payee', '2025-05-02 06:31:46', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-27 00:00:00', NULL),
(266, 'FACT2025030266', 57, 266, '2025-03-27', '2025-04-26', 409675.13, 18.00, 73741.52, 483416.65, 'payee', '2025-04-09 21:17:34', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-26 00:00:00', NULL),
(267, 'FACT2025010267', 167, 267, '2025-01-05', '2025-02-04', 892624.17, 18.00, 160672.35, 1053296.52, 'payee', '2025-01-28 07:23:17', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-04 00:00:00', NULL),
(268, 'FACT2025020268', 137, 268, '2025-02-10', '2025-03-12', 28967.61, 18.00, 5214.17, 34181.78, 'payee', '2025-02-27 22:59:36', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-08 00:00:00', NULL),
(269, 'FACT2025050269', 63, 269, '2025-05-02', '2025-06-01', 59958.36, 18.00, 10792.50, 70750.86, 'payee', '2025-05-16 19:29:48', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-05-02 00:00:00', NULL),
(270, 'FACT2025040270', 129, 270, '2025-04-25', '2025-05-25', 121537.32, 18.00, 21876.72, 143414.04, 'payee', '2025-04-30 13:02:39', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-23 00:00:00', NULL),
(271, 'FACT2025030271', 132, 271, '2025-03-03', '2025-04-02', 377795.43, 18.00, 68003.18, 445798.61, 'payee', '2025-03-21 06:57:24', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-01 00:00:00', NULL),
(272, 'FACT2025040272', 136, 272, '2025-04-03', '2025-05-03', 410762.56, 18.00, 73937.26, 484699.82, 'payee', '2025-04-09 20:31:26', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-03 00:00:00', NULL),
(273, 'FACT2025060273', 178, 273, '2025-06-02', '2025-07-02', 1392578.14, 18.00, 250664.07, 1643242.21, 'payee', '2025-06-02 21:43:52', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-06-02 00:00:00', NULL),
(274, 'FACT2025010274', 85, 274, '2025-01-24', '2025-02-23', 347811.38, 18.00, 62606.05, 410417.43, 'payee', '2025-02-03 08:33:58', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-22 00:00:00', NULL),
(275, 'FACT2025050275', 11, 275, '2025-05-02', '2025-06-01', 511776.80, 18.00, 92119.82, 603896.62, 'payee', '2025-05-24 14:20:01', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-05-01 00:00:00', NULL),
(276, 'FACT2024110276', 105, 276, '2024-11-18', '2024-12-18', 147053.56, 18.00, 26469.64, 173523.20, 'payee', '2024-12-12 23:25:56', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-11-17 00:00:00', NULL),
(277, 'FACT2025010277', 42, 277, '2025-01-09', '2025-02-08', 788476.58, 18.00, 141925.78, 930402.36, 'payee', '2025-01-26 04:55:57', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-09 00:00:00', NULL),
(278, 'FACT2024120278', 4, 278, '2024-12-20', '2025-01-19', 105342.02, 18.00, 18961.56, 124303.58, 'payee', '2025-01-07 13:40:54', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-20 00:00:00', NULL),
(279, 'FACT2025020279', 174, 279, '2025-02-01', '2025-03-03', 388098.63, 18.00, 69857.75, 457956.38, 'payee', '2025-02-25 14:25:42', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-31 00:00:00', NULL),
(280, 'FACT2024120280', 62, 280, '2024-12-28', '2025-01-27', 226677.91, 18.00, 40802.02, 267479.93, 'payee', '2025-01-04 15:51:19', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-12-27 00:00:00', NULL),
(281, 'FACT2025020281', 165, 281, '2025-02-08', '2025-03-10', 30296.65, 18.00, 5453.40, 35750.05, 'payee', '2025-02-27 07:16:15', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-06 00:00:00', NULL),
(282, 'FACT2025040282', 183, 282, '2025-04-27', '2025-05-27', 876533.30, 18.00, 157775.99, 1034309.29, 'payee', '2025-05-05 13:00:53', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-27 00:00:00', NULL),
(283, 'FACT2024110283', 45, 283, '2024-11-18', '2024-12-18', 567830.47, 18.00, 102209.48, 670039.95, 'payee', '2024-11-20 16:57:38', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-11-17 00:00:00', NULL),
(284, 'FACT2024120284', 6, 284, '2024-12-01', '2024-12-31', 71266.76, 18.00, 12828.02, 84094.78, 'payee', '2024-12-02 09:15:36', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-30 00:00:00', NULL),
(285, 'FACT2025050285', 38, 285, '2025-05-29', '2025-06-28', 113607.19, 18.00, 20449.29, 134056.48, 'payee', '2025-06-08 20:44:09', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-27 00:00:00', NULL),
(286, 'FACT2025040286', 171, 286, '2025-04-06', '2025-05-06', 161501.03, 18.00, 29070.19, 190571.22, 'payee', '2025-04-25 19:39:43', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-06 00:00:00', NULL),
(287, 'FACT2025030287', 99, 287, '2025-03-26', '2025-04-25', 827503.21, 18.00, 148950.58, 976453.79, 'payee', '2025-04-19 11:10:18', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-24 00:00:00', NULL),
(288, 'FACT2025010288', 67, 288, '2025-01-27', '2025-02-26', 1012971.96, 18.00, 182334.95, 1195306.91, 'payee', '2025-01-31 03:49:51', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-01-27 00:00:00', NULL),
(289, 'FACT2025050289', 66, 289, '2025-05-20', '2025-06-19', 307700.47, 18.00, 55386.08, 363086.55, 'payee', '2025-06-10 11:52:20', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-05-18 00:00:00', NULL),
(290, 'FACT2024110290', 50, 290, '2024-11-17', '2024-12-17', 1048483.93, 18.00, 188727.11, 1237211.04, 'payee', '2024-12-06 13:06:56', 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-11-16 00:00:00', NULL),
(291, 'FACT2024110291', 195, 291, '2024-11-26', '2024-12-26', 346191.30, 18.00, 62314.43, 408505.73, 'payee', '2024-12-23 02:32:17', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-11-24 00:00:00', NULL),
(292, 'FACT2025010292', 25, 292, '2025-01-06', '2025-02-05', 33432.81, 18.00, 6017.91, 39450.72, 'payee', '2025-01-16 18:06:32', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-01-05 00:00:00', NULL),
(293, 'FACT2025020293', 103, 293, '2025-02-12', '2025-03-14', 430521.97, 18.00, 77493.95, 508015.92, 'payee', '2025-02-17 07:03:19', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-12 00:00:00', NULL),
(294, 'FACT2025020294', 155, 294, '2025-02-12', '2025-03-14', 682671.14, 18.00, 122880.81, 805551.95, 'payee', '2025-03-11 07:06:15', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-02-10 00:00:00', NULL),
(295, 'FACT2025020295', 44, 295, '2025-02-27', '2025-03-29', 271946.66, 18.00, 48950.40, 320897.06, 'payee', '2025-03-09 08:53:19', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-27 00:00:00', NULL),
(296, 'FACT2024120296', 107, 296, '2024-12-21', '2025-01-20', 477261.88, 18.00, 85907.14, 563169.02, 'payee', '2025-01-11 13:32:18', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-19 00:00:00', NULL),
(297, 'FACT2024120297', 169, 297, '2024-12-08', '2025-01-07', 49081.04, 18.00, 8834.59, 57915.63, 'payee', '2024-12-18 07:58:48', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-08 00:00:00', NULL),
(298, 'FACT2025030298', 180, 298, '2025-03-11', '2025-04-10', 366441.82, 18.00, 65959.53, 432401.35, 'payee', '2025-03-11 19:23:59', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-09 00:00:00', NULL),
(299, 'FACT2024120299', 71, 299, '2024-12-20', '2025-01-19', 518349.14, 18.00, 93302.85, 611651.99, 'payee', '2025-01-07 13:18:38', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-18 00:00:00', NULL),
(300, 'FACT2025010300', 147, 300, '2025-01-06', '2025-02-05', 113876.90, 18.00, 20497.84, 134374.74, 'payee', '2025-01-22 16:17:08', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-06 00:00:00', NULL),
(301, 'FACT2025030301', 34, 301, '2025-03-11', '2025-04-10', 77702.06, 18.00, 13986.37, 91688.43, 'payee', '2025-03-29 12:14:42', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-03-11 00:00:00', NULL),
(302, 'FACT2025060302', 96, 302, '2025-06-06', '2025-07-06', 594101.42, 18.00, 106938.26, 701039.68, 'payee', '2025-06-13 16:08:59', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-06-04 00:00:00', NULL),
(303, 'FACT2025040303', 118, 303, '2025-04-16', '2025-05-16', 212275.84, 18.00, 38209.65, 250485.49, 'payee', '2025-05-07 20:39:42', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-14 00:00:00', NULL),
(304, 'FACT2025040304', 89, 304, '2025-04-30', '2025-05-30', 875877.52, 18.00, 157657.95, 1033535.47, 'payee', '2025-05-07 00:46:32', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-28 00:00:00', NULL),
(305, 'FACT2025050305', 139, 305, '2025-05-11', '2025-06-10', 158069.48, 18.00, 28452.51, 186521.99, 'payee', '2025-05-16 16:09:18', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-11 00:00:00', NULL),
(306, 'FACT2025030306', 113, 306, '2025-03-24', '2025-04-23', 83933.39, 18.00, 15108.01, 99041.40, 'payee', '2025-04-14 11:08:34', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-23 00:00:00', NULL),
(307, 'FACT2025030307', 8, 307, '2025-03-07', '2025-04-06', 174400.46, 18.00, 31392.08, 205792.54, 'payee', '2025-03-29 10:06:35', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-06 00:00:00', NULL),
(308, 'FACT2025010308', 72, 308, '2025-01-14', '2025-02-13', 9598.80, 18.00, 1727.78, 11326.58, 'payee', '2025-01-28 19:53:32', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-14 00:00:00', NULL),
(309, 'FACT2025020309', 84, 309, '2025-02-05', '2025-03-07', 258339.87, 18.00, 46501.18, 304841.05, 'payee', '2025-02-16 23:24:07', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-03 00:00:00', NULL),
(310, 'FACT2025010310', 120, 310, '2025-01-24', '2025-02-23', 286800.70, 18.00, 51624.13, 338424.83, 'payee', '2025-02-14 21:48:53', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-22 00:00:00', NULL),
(311, 'FACT2025040311', 140, 311, '2025-04-20', '2025-05-20', 1235977.92, 18.00, 222476.03, 1458453.95, 'payee', '2025-05-08 18:34:25', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-19 00:00:00', NULL),
(312, 'FACT2024120312', 13, 312, '2024-12-13', '2025-01-12', 128657.06, 18.00, 23158.27, 151815.33, 'payee', '2024-12-15 08:43:34', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-13 00:00:00', NULL),
(313, 'FACT2025040313', 153, 313, '2025-04-02', '2025-05-02', 508420.13, 18.00, 91515.62, 599935.75, 'payee', '2025-04-05 21:52:35', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-01 00:00:00', NULL),
(314, 'FACT2025010314', 30, 314, '2025-01-07', '2025-02-06', 47596.63, 18.00, 8567.39, 56164.02, 'payee', '2025-01-26 14:18:53', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-05 00:00:00', NULL),
(315, 'FACT2025030315', 143, 315, '2025-03-15', '2025-04-14', 138727.36, 18.00, 24970.92, 163698.28, 'payee', '2025-04-13 14:49:33', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-03-14 00:00:00', NULL),
(316, 'FACT2024120316', 190, 316, '2024-12-29', '2025-01-28', 329617.67, 18.00, 59331.18, 388948.85, 'payee', '2025-01-15 21:03:19', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-28 00:00:00', NULL),
(317, 'FACT2025020317', 163, 317, '2025-02-17', '2025-03-19', 113122.55, 18.00, 20362.06, 133484.61, 'payee', '2025-03-07 16:58:34', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-17 00:00:00', NULL),
(318, 'FACT2024120318', 119, 318, '2024-12-08', '2025-01-07', 639545.31, 18.00, 115118.16, 754663.47, 'payee', '2024-12-25 05:54:35', 'Prestation de transport - Matériel informatique', NULL, 1, '2024-12-08 00:00:00', NULL),
(319, 'FACT2025030319', 101, 319, '2025-03-19', '2025-04-18', 1016937.72, 18.00, 183048.79, 1199986.51, 'payee', '2025-04-06 05:59:45', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-03-17 00:00:00', NULL),
(320, 'FACT2025040320', 79, 320, '2025-04-17', '2025-05-17', 434916.70, 18.00, 78285.01, 513201.71, 'payee', '2025-05-13 10:29:50', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-15 00:00:00', NULL),
(321, 'FACT2025010321', 131, 321, '2025-01-14', '2025-02-13', 1025835.38, 18.00, 184650.37, 1210485.75, 'payee', '2025-01-22 04:39:17', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-13 00:00:00', NULL),
(322, 'FACT2025020322', 95, 322, '2025-02-23', '2025-03-25', 480206.61, 18.00, 86437.19, 566643.80, 'payee', '2025-03-10 19:19:52', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-02-23 00:00:00', NULL),
(323, 'FACT2025020323', 93, 323, '2025-02-15', '2025-03-17', 414052.54, 18.00, 74529.46, 488582.00, 'payee', '2025-02-23 09:02:51', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-02-13 00:00:00', NULL),
(324, 'FACT2024110324', 176, 324, '2024-11-18', '2024-12-18', 987462.41, 18.00, 177743.23, 1165205.64, 'payee', '2024-12-15 13:55:41', 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-11-17 00:00:00', NULL),
(325, 'FACT2024120325', 56, 325, '2024-12-14', '2025-01-13', 266642.26, 18.00, 47995.61, 314637.87, 'payee', '2025-01-05 03:33:46', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-13 00:00:00', NULL),
(326, 'FACT2025060326', 55, 326, '2025-06-05', '2025-07-05', 455938.01, 18.00, 82068.84, 538006.85, 'payee', '2025-06-12 11:04:06', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-06-03 00:00:00', NULL),
(327, 'FACT2024110327', 64, 327, '2024-11-19', '2024-12-19', 522880.82, 18.00, 94118.55, 616999.37, 'payee', '2024-12-02 12:22:01', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-11-18 00:00:00', NULL),
(328, 'FACT2025010328', 46, 328, '2025-01-28', '2025-02-27', 1060960.58, 18.00, 190972.90, 1251933.48, 'payee', '2025-01-28 17:02:12', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-26 00:00:00', NULL),
(329, 'FACT2025020329', 142, 329, '2025-02-28', '2025-03-30', 134537.44, 18.00, 24216.74, 158754.18, 'payee', '2025-03-16 01:52:35', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-28 00:00:00', NULL),
(330, 'FACT2025010330', 23, 330, '2025-01-13', '2025-02-12', 18411.40, 18.00, 3314.05, 21725.45, 'payee', '2025-01-30 15:50:17', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-13 00:00:00', NULL),
(331, 'FACT2024120331', 117, 331, '2024-12-02', '2025-01-01', 474053.23, 18.00, 85329.58, 559382.81, 'payee', '2024-12-31 06:16:19', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-02 00:00:00', NULL),
(332, 'FACT2024120332', 24, 332, '2024-12-30', '2025-01-29', 320052.71, 18.00, 57609.49, 377662.20, 'payee', '2025-01-20 05:56:36', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-28 00:00:00', NULL),
(333, 'FACT2024120333', 39, 333, '2024-12-10', '2025-01-09', 110181.04, 18.00, 19832.59, 130013.63, 'payee', '2024-12-11 22:47:32', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-09 00:00:00', NULL),
(334, 'FACT2025030334', 77, 334, '2025-03-09', '2025-04-08', 242416.24, 18.00, 43634.92, 286051.16, 'payee', '2025-04-07 00:17:47', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-03-07 00:00:00', NULL),
(335, 'FACT2025030335', 158, 335, '2025-03-23', '2025-04-22', 259837.20, 18.00, 46770.70, 306607.90, 'payee', '2025-04-11 17:52:57', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-21 00:00:00', NULL),
(336, 'FACT2024120336', 18, 336, '2024-12-15', '2025-01-14', 148131.40, 18.00, 26663.65, 174795.05, 'payee', '2025-01-06 16:11:56', 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-14 00:00:00', NULL),
(337, 'FACT2025030337', 28, 337, '2025-03-24', '2025-04-23', 667361.15, 18.00, 120125.01, 787486.16, 'payee', '2025-04-08 14:39:00', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-23 00:00:00', NULL),
(338, 'FACT2025030338', 179, 338, '2025-03-04', '2025-04-03', 22622.71, 18.00, 4072.09, 26694.80, 'payee', '2025-03-09 07:20:21', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-04 00:00:00', NULL),
(339, 'FACT2024110339', 196, 339, '2024-11-29', '2024-12-29', 182785.79, 18.00, 32901.44, 215687.23, 'payee', '2024-12-16 09:29:07', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-11-27 00:00:00', NULL),
(340, 'FACT2024110340', 138, 340, '2024-11-24', '2024-12-24', 87197.80, 18.00, 15695.60, 102893.40, 'payee', '2024-12-10 19:38:19', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-11-24 00:00:00', NULL),
(341, 'FACT2025010341', 14, 341, '2025-01-12', '2025-02-11', 221563.84, 18.00, 39881.49, 261445.33, 'payee', '2025-02-01 08:44:19', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-12 00:00:00', NULL),
(342, 'FACT2025050342', 106, 342, '2025-05-03', '2025-06-02', 477347.93, 18.00, 85922.63, 563270.56, 'payee', '2025-05-17 20:18:21', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-01 00:00:00', NULL),
(343, 'FACT2025010343', 97, 343, '2025-01-21', '2025-02-20', 56588.12, 18.00, 10185.86, 66773.98, 'payee', '2025-02-10 01:23:36', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-20 00:00:00', NULL),
(344, 'FACT2025030344', 69, 344, '2025-03-08', '2025-04-07', 149860.75, 18.00, 26974.93, 176835.68, 'payee', '2025-03-12 03:33:41', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-08 00:00:00', NULL),
(345, 'FACT2025050345', 161, 345, '2025-05-27', '2025-06-26', 376735.90, 18.00, 67812.46, 444548.36, 'payee', '2025-06-19 14:23:33', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-27 00:00:00', NULL),
(346, 'FACT2025020346', 12, 346, '2025-02-18', '2025-03-20', 144159.29, 18.00, 25948.67, 170107.96, 'payee', '2025-03-19 00:48:47', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-16 00:00:00', NULL),
(347, 'FACT2025040347', 104, 347, '2025-04-16', '2025-05-16', 10967.43, 18.00, 1974.14, 12941.57, 'payee', '2025-04-18 18:22:00', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-16 00:00:00', NULL),
(348, 'FACT2025040348', 173, 348, '2025-04-15', '2025-05-15', 451416.46, 18.00, 81254.96, 532671.42, 'payee', '2025-04-24 08:21:30', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-13 00:00:00', NULL),
(349, 'FACT2024120349', 115, 349, '2024-12-19', '2025-01-18', 47111.21, 18.00, 8480.02, 55591.23, 'payee', '2024-12-26 06:35:57', 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-18 00:00:00', NULL),
(350, 'FACT2025020350', 175, 350, '2025-02-27', '2025-03-29', 528072.75, 18.00, 95053.10, 623125.85, 'payee', '2025-02-28 02:17:42', 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-26 00:00:00', NULL),
(351, 'FACT2025040351', 100, 351, '2025-04-19', '2025-05-19', 1051297.60, 18.00, 189233.57, 1240531.17, 'payee', '2025-05-08 12:45:54', 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-17 00:00:00', NULL),
(352, 'FACT2025010352', 170, 352, '2025-01-10', '2025-02-09', 107972.90, 18.00, 19435.12, 127408.02, 'payee', '2025-01-11 07:11:28', 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-01-10 00:00:00', NULL),
(353, 'FACT2025040353', 1, 353, '2025-04-03', '2025-05-03', 111783.07, 18.00, 20120.95, 131904.02, 'payee', '2025-04-30 21:10:52', 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-01 00:00:00', NULL),
(354, 'FACT2025040354', 80, 354, '2025-04-23', '2025-05-23', 80348.27, 18.00, 14462.69, 94810.96, 'payee', '2025-05-21 01:38:47', 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-04-23 00:00:00', NULL),
(355, 'FACT2025050355', 172, 355, '2025-05-05', '2025-06-04', 412002.35, 18.00, 74160.42, 486162.77, 'payee', '2025-05-09 12:47:26', 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-04 00:00:00', NULL),
(356, 'FACT2025040356', 68, 356, '2025-04-04', '2025-05-04', 453178.70, 18.00, 81572.17, 534750.87, 'payee', '2025-04-09 05:27:52', 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-04 00:00:00', NULL),
(357, 'FACT2024120357', 49, 357, '2024-12-31', '2025-01-30', 275280.92, 18.00, 49550.57, 324831.49, 'payee', '2025-01-13 02:43:31', 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-12-30 00:00:00', NULL),
(358, 'FACT2024120358', 187, 358, '2024-12-28', '2025-01-27', 27169.95, 18.00, 4890.59, 32060.54, 'payee', '2025-01-13 03:18:14', 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-26 00:00:00', NULL),
(359, 'FACT2025010359', 19, 359, '2025-01-15', '2025-02-14', 467176.55, 18.00, 84091.78, 551268.33, 'payee', '2025-02-06 21:33:47', 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-13 00:00:00', NULL),
(360, 'FACT2025010360', 91, 360, '2025-01-03', '2025-02-02', 12517.64, 18.00, 2253.18, 14770.82, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-01-01 00:00:00', NULL),
(361, 'FACT2025010361', 92, 361, '2025-01-04', '2025-02-03', 65569.47, 18.00, 11802.50, 77371.97, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-01-04 00:00:00', NULL),
(362, 'FACT2024110362', 58, 362, '2024-11-20', '2024-12-20', 824679.69, 18.00, 148442.34, 973122.03, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-11-18 00:00:00', NULL),
(363, 'FACT2025020363', 112, 363, '2025-02-20', '2025-03-22', 71080.26, 18.00, 12794.45, 83874.71, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-20 00:00:00', NULL),
(364, 'FACT2024120364', 74, 364, '2024-12-02', '2025-01-01', 90844.74, 18.00, 16352.05, 107196.79, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-02 00:00:00', NULL),
(365, 'FACT2025010365', 135, 365, '2025-01-29', '2025-02-28', 600945.35, 18.00, 108170.16, 709115.51, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-29 00:00:00', NULL),
(366, 'FACT2024120366', 48, 366, '2024-12-05', '2025-01-04', 591484.58, 18.00, 106467.22, 697951.80, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-12-04 00:00:00', NULL),
(367, 'FACT2025050367', 102, 367, '2025-05-22', '2025-06-21', 156695.37, 18.00, 28205.17, 184900.54, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-05-20 00:00:00', NULL),
(368, 'FACT2025060368', 159, 368, '2025-06-03', '2025-07-03', 462969.59, 18.00, 83334.53, 546304.12, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-06-01 00:00:00', NULL),
(369, 'FACT2024120369', 110, 369, '2024-12-04', '2025-01-03', 751651.06, 18.00, 135297.19, 886948.25, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-12-02 00:00:00', NULL),
(370, 'FACT2025040370', 111, 370, '2025-04-24', '2025-05-24', 896280.54, 18.00, 161330.50, 1057611.04, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-22 00:00:00', NULL),
(371, 'FACT2025040371', 27, 371, '2025-04-10', '2025-05-10', 376690.07, 18.00, 67804.21, 444494.28, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-09 00:00:00', NULL),
(372, 'FACT2025050372', 157, 372, '2025-05-11', '2025-06-10', 830339.05, 18.00, 149461.03, 979800.08, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-11 00:00:00', NULL),
(373, 'FACT2025030373', 15, 373, '2025-03-14', '2025-04-13', 523440.69, 18.00, 94219.32, 617660.01, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-13 00:00:00', NULL),
(374, 'FACT2025010374', 61, 374, '2025-01-13', '2025-02-12', 41137.14, 18.00, 7404.69, 48541.83, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-13 00:00:00', NULL),
(375, 'FACT2025040375', 186, 375, '2025-04-29', '2025-05-29', 21345.66, 18.00, 3842.22, 25187.88, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-04-28 00:00:00', NULL),
(376, 'FACT2025040376', 3, 376, '2025-04-26', '2025-05-26', 113594.67, 18.00, 20447.04, 134041.71, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-26 00:00:00', NULL),
(377, 'FACT2024120377', 148, 377, '2024-12-05', '2025-01-04', 165324.20, 18.00, 29758.36, 195082.56, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-03 00:00:00', NULL),
(378, 'FACT2025010378', 54, 378, '2025-01-13', '2025-02-12', 819072.54, 18.00, 147433.06, 966505.60, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-12 00:00:00', NULL),
(379, 'FACT2024110379', 51, 379, '2024-11-20', '2024-12-20', 357522.23, 18.00, 64354.00, 421876.23, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-20 00:00:00', NULL),
(380, 'FACT2025010380', 185, 380, '2025-01-07', '2025-02-06', 41587.89, 18.00, 7485.82, 49073.71, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-07 00:00:00', NULL),
(381, 'FACT2025050381', 168, 381, '2025-05-29', '2025-06-28', 469383.88, 18.00, 84489.10, 553872.98, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-05-28 00:00:00', NULL),
(382, 'FACT2025050382', 20, 382, '2025-05-20', '2025-06-19', 74723.50, 18.00, 13450.23, 88173.73, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-18 00:00:00', NULL),
(383, 'FACT2025040383', 192, 383, '2025-04-18', '2025-05-18', 45520.44, 18.00, 8193.68, 53714.12, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-18 00:00:00', NULL),
(384, 'FACT2025010384', 94, 384, '2025-01-04', '2025-02-03', 486563.17, 18.00, 87581.37, 574144.54, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-02 00:00:00', NULL),
(385, 'FACT2025050385', 17, 385, '2025-05-17', '2025-06-16', 83677.56, 18.00, 15061.96, 98739.52, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-15 00:00:00', NULL),
(386, 'FACT2024110386', 123, 386, '2024-11-21', '2024-12-21', 1103982.27, 18.00, 198716.81, 1302699.08, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-11-20 00:00:00', NULL),
(387, 'FACT2025010387', 29, 387, '2025-01-21', '2025-02-20', 830630.89, 18.00, 149513.56, 980144.45, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-01-19 00:00:00', NULL),
(388, 'FACT2024110388', 130, 388, '2024-11-18', '2024-12-18', 205911.49, 18.00, 37064.07, 242975.56, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-11-17 00:00:00', NULL),
(389, 'FACT2025020389', 134, 389, '2025-02-06', '2025-03-08', 236440.03, 18.00, 42559.21, 278999.24, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-04 00:00:00', NULL),
(390, 'FACT2025010390', 149, 390, '2025-01-03', '2025-02-02', 40469.18, 18.00, 7284.45, 47753.63, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-02 00:00:00', NULL),
(391, 'FACT2025020391', 152, 391, '2025-02-05', '2025-03-07', 403822.97, 18.00, 72688.13, 476511.10, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-02-05 00:00:00', NULL),
(392, 'FACT2025050392', 128, 392, '2025-05-18', '2025-06-17', 309813.02, 18.00, 55766.34, 365579.36, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-05-17 00:00:00', NULL),
(393, 'FACT2025010393', 116, 393, '2025-01-12', '2025-02-11', 619307.07, 18.00, 111475.27, 730782.34, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-01-12 00:00:00', NULL),
(394, 'FACT2025020394', 144, 394, '2025-02-19', '2025-03-21', 28135.57, 18.00, 5064.40, 33199.97, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-18 00:00:00', NULL),
(395, 'FACT2025030395', 133, 395, '2025-03-17', '2025-04-16', 280976.26, 18.00, 50575.73, 331551.99, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-03-15 00:00:00', NULL),
(396, 'FACT2025030396', 60, 396, '2025-03-01', '2025-03-31', 519843.64, 18.00, 93571.86, 613415.50, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-28 00:00:00', NULL),
(397, 'FACT2025030397', 154, 397, '2025-03-14', '2025-04-13', 72640.26, 18.00, 13075.25, 85715.51, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-13 00:00:00', NULL),
(398, 'FACT2024110398', 2, 398, '2024-11-23', '2024-12-23', 45276.95, 18.00, 8149.85, 53426.80, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-11-23 00:00:00', NULL),
(399, 'FACT2025050399', 177, 399, '2025-05-04', '2025-06-03', 105228.94, 18.00, 18941.21, 124170.15, 'envoyee', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-02 00:00:00', NULL),
(400, 'FACT2025040400', 82, 400, '2025-04-03', '2025-05-03', 1188352.65, 18.00, 213903.48, 1402256.13, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-03 00:00:00', NULL),
(401, 'FACT2025040401', 10, 401, '2025-04-23', '2025-05-23', 1031933.55, 18.00, 185748.04, 1217681.59, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-21 00:00:00', NULL),
(402, 'FACT2025040402', 90, 402, '2025-04-22', '2025-05-22', 435438.24, 18.00, 78378.88, 513817.12, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-04-21 00:00:00', NULL),
(403, 'FACT2025020403', 81, 403, '2025-02-13', '2025-03-15', 567295.95, 18.00, 102113.27, 669409.22, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-12 00:00:00', NULL),
(404, 'FACT2024110404', 59, 404, '2024-11-20', '2024-12-20', 82671.25, 18.00, 14880.82, 97552.07, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-20 00:00:00', NULL),
(405, 'FACT2025040405', 36, 405, '2025-04-13', '2025-05-13', 689214.66, 18.00, 124058.64, 813273.30, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-04-12 00:00:00', NULL),
(406, 'FACT2024120406', 151, 406, '2024-12-17', '2025-01-16', 686798.90, 18.00, 123623.80, 810422.70, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2024-12-15 00:00:00', NULL),
(407, 'FACT2025050407', 98, 407, '2025-05-25', '2025-06-24', 219970.62, 18.00, 39594.71, 259565.33, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-25 00:00:00', NULL),
(408, 'FACT2025040408', 76, 408, '2025-04-01', '2025-05-01', 20403.08, 18.00, 3672.55, 24075.63, 'envoyee', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-01 00:00:00', NULL),
(409, 'FACT2025030409', 35, 409, '2025-03-22', '2025-04-21', 56380.71, 18.00, 10148.53, 66529.24, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-22 00:00:00', NULL),
(410, 'FACT2025040410', 32, 410, '2025-04-16', '2025-05-16', 374850.40, 18.00, 67473.07, 442323.47, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-15 00:00:00', NULL),
(411, 'FACT2025010411', 37, 411, '2025-01-27', '2025-02-26', 63862.24, 18.00, 11495.20, 75357.44, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-26 00:00:00', NULL),
(412, 'FACT2025010412', 78, 412, '2025-01-23', '2025-02-22', 322765.89, 18.00, 58097.86, 380863.75, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-22 00:00:00', NULL),
(413, 'FACT2025030413', 191, 413, '2025-03-31', '2025-04-30', 46832.15, 18.00, 8429.79, 55261.94, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-03-30 00:00:00', NULL),
(414, 'FACT2025050414', 83, 414, '2025-05-09', '2025-06-08', 531829.24, 18.00, 95729.26, 627558.50, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-07 00:00:00', NULL),
(415, 'FACT2025010415', 7, 415, '2025-01-19', '2025-02-18', 353077.41, 18.00, 63553.93, 416631.34, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-01-19 00:00:00', NULL),
(416, 'FACT2024110416', 122, 416, '2024-11-24', '2024-12-24', 8064.90, 18.00, 1451.68, 9516.58, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-22 00:00:00', NULL),
(417, 'FACT2024110417', 109, 417, '2024-11-20', '2024-12-20', 1027215.76, 18.00, 184898.84, 1212114.60, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-11-19 00:00:00', NULL),
(418, 'FACT2024120418', 47, 418, '2024-12-04', '2025-01-03', 398071.80, 18.00, 71652.92, 469724.72, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2024-12-03 00:00:00', NULL),
(419, 'FACT2024120419', 125, 419, '2024-12-13', '2025-01-12', 530262.41, 18.00, 95447.23, 625709.64, 'envoyee', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-12-11 00:00:00', NULL),
(420, 'FACT2025010420', 31, 420, '2025-01-24', '2025-02-23', 471745.06, 18.00, 84914.11, 556659.17, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-01-22 00:00:00', NULL),
(421, 'FACT2025010421', 33, 421, '2025-01-06', '2025-02-05', 383720.66, 18.00, 69069.72, 452790.38, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-05 00:00:00', NULL),
(422, 'FACT2025040422', 124, 422, '2025-04-03', '2025-05-03', 566751.28, 18.00, 102015.23, 668766.51, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-04-03 00:00:00', NULL),
(423, 'FACT2025040423', 193, 423, '2025-04-09', '2025-05-09', 124353.69, 18.00, 22383.66, 146737.35, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-07 00:00:00', NULL),
(424, 'FACT2024120424', 21, 424, '2024-12-29', '2025-01-28', 379848.06, 18.00, 68372.65, 448220.71, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-27 00:00:00', NULL),
(425, 'FACT2025050425', 127, 425, '2025-05-11', '2025-06-10', 220493.99, 18.00, 39688.92, 260182.91, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-05-10 00:00:00', NULL),
(426, 'FACT2025040426', 52, 426, '2025-04-28', '2025-05-28', 155798.23, 18.00, 28043.68, 183841.91, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-04-28 00:00:00', NULL),
(427, 'FACT2024120427', 87, 427, '2024-12-10', '2025-01-09', 353643.95, 18.00, 63655.91, 417299.86, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2024-12-08 00:00:00', NULL),
(428, 'FACT2025010428', 194, 428, '2025-01-19', '2025-02-18', 1108606.98, 18.00, 199549.26, 1308156.24, 'envoyee', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-19 00:00:00', NULL),
(429, 'FACT2025030429', 150, 429, '2025-03-05', '2025-04-04', 350445.10, 18.00, 63080.12, 413525.22, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-04 00:00:00', NULL),
(430, 'FACT2025040430', 88, 430, '2025-04-21', '2025-05-21', 108813.09, 18.00, 19586.36, 128399.45, 'envoyee', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-20 00:00:00', NULL),
(431, 'FACT2025020431', 184, 431, '2025-02-21', '2025-03-23', 73042.78, 18.00, 13147.70, 86190.48, 'envoyee', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-19 00:00:00', NULL),
(432, 'FACT2025050432', 41, 432, '2025-05-07', '2025-06-06', 755159.27, 18.00, 135928.67, 891087.94, 'envoyee', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-06 00:00:00', NULL),
(433, 'FACT2025020433', 22, 433, '2025-02-14', '2025-03-16', 214908.45, 18.00, 38683.52, 253591.97, 'envoyee', NULL, 'Prestation de transport - Produits pharmaceutiques', NULL, 1, '2025-02-12 00:00:00', NULL),
(434, 'FACT2025010434', 145, 434, '2025-01-07', '2025-02-06', 118252.09, 18.00, 21285.38, 139537.47, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-01-05 00:00:00', NULL),
(435, 'FACT2025020435', 146, 435, '2025-02-04', '2025-03-06', 131644.66, 18.00, 23696.04, 155340.70, 'envoyee', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-02-03 00:00:00', NULL),
(436, 'FACT2025020436', 26, 436, '2025-02-19', '2025-03-21', 568032.16, 18.00, 102245.79, 670277.95, 'envoyee', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-02-18 00:00:00', NULL),
(437, 'FACT2025030437', 164, 437, '2025-03-30', '2025-04-29', 603749.77, 18.00, 108674.96, 712424.73, 'envoyee', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-28 00:00:00', NULL),
(438, 'FACT2024110438', 156, 438, '2024-11-30', '2024-12-30', 379762.76, 18.00, 68357.30, 448120.06, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-11-29 00:00:00', NULL),
(439, 'FACT2025010439', 40, 439, '2025-01-04', '2025-02-03', 175707.02, 18.00, 31627.26, 207334.28, 'brouillon', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-03 00:00:00', NULL),
(440, 'FACT2024120440', 160, 440, '2024-12-17', '2025-01-16', 724670.00, 18.00, 130440.60, 855110.60, 'brouillon', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-15 00:00:00', NULL),
(441, 'FACT2024120441', 86, 441, '2024-12-10', '2025-01-09', 664761.15, 18.00, 119657.01, 784418.16, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-12-10 00:00:00', NULL),
(442, 'FACT2025020442', 114, 442, '2025-02-14', '2025-03-16', 387352.26, 18.00, 69723.41, 457075.67, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-02-14 00:00:00', NULL),
(443, 'FACT2025030443', 141, 443, '2025-03-01', '2025-03-31', 39846.93, 18.00, 7172.45, 47019.38, 'brouillon', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-03-01 00:00:00', NULL),
(444, 'FACT2025030444', 182, 444, '2025-03-05', '2025-04-04', 619782.22, 18.00, 111560.80, 731343.02, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-03-04 00:00:00', NULL),
(445, 'FACT2025050445', 65, 445, '2025-05-29', '2025-06-28', 86920.50, 18.00, 15645.69, 102566.19, 'brouillon', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-27 00:00:00', NULL),
(446, 'FACT2025030446', 53, 446, '2025-03-03', '2025-04-02', 562393.26, 18.00, 101230.79, 663624.05, 'brouillon', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-03-02 00:00:00', NULL),
(447, 'FACT2025020447', 73, 447, '2025-02-07', '2025-03-09', 482553.75, 18.00, 86859.68, 569413.43, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-02-06 00:00:00', NULL),
(448, 'FACT2024110448', 166, 448, '2024-11-23', '2024-12-23', 966380.74, 18.00, 173948.53, 1140329.27, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-11-23 00:00:00', NULL),
(449, 'FACT2024120449', 16, 449, '2024-12-17', '2025-01-16', 694106.86, 18.00, 124939.23, 819046.09, 'brouillon', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-12-16 00:00:00', NULL),
(450, 'FACT2024110450', 5, 450, '2024-11-28', '2024-12-28', 53665.31, 18.00, 9659.76, 63325.07, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2024-11-28 00:00:00', NULL),
(451, 'FACT2025040451', 189, 451, '2025-04-13', '2025-05-13', 492225.10, 18.00, 88600.52, 580825.62, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-13 00:00:00', NULL),
(452, 'FACT2024120452', 75, 452, '2024-12-31', '2025-01-30', 203092.30, 18.00, 36556.61, 239648.91, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-12-30 00:00:00', NULL),
(453, 'FACT2024110453', 108, 453, '2024-11-27', '2024-12-27', 234897.87, 18.00, 42281.62, 277179.49, 'brouillon', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-11-25 00:00:00', NULL),
(454, 'FACT2024120454', 43, 454, '2024-12-24', '2025-01-23', 492242.08, 18.00, 88603.57, 580845.65, 'brouillon', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2024-12-23 00:00:00', NULL),
(455, 'FACT2025040455', 126, 455, '2025-04-27', '2025-05-27', 196254.47, 18.00, 35325.80, 231580.27, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-25 00:00:00', NULL),
(456, 'FACT2025030456', 188, 456, '2025-03-22', '2025-04-21', 267992.20, 18.00, 48238.60, 316230.80, 'brouillon', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-21 00:00:00', NULL);
INSERT INTO `factures` (`id`, `numero_facture`, `client_id`, `commande_id`, `date_facture`, `date_echeance`, `montant_ht`, `taux_tva`, `montant_tva`, `montant_ttc`, `statut`, `date_paiement`, `description`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(457, 'FACT2025020457', 70, 457, '2025-02-22', '2025-03-24', 873238.60, 18.00, 157182.95, 1030421.55, 'brouillon', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-02-22 00:00:00', NULL),
(458, 'FACT2024120458', 9, 458, '2024-12-30', '2025-01-29', 26010.18, 18.00, 4681.83, 30692.01, 'brouillon', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2024-12-28 00:00:00', NULL),
(459, 'FACT2024110459', 181, 459, '2024-11-21', '2024-12-21', 106850.56, 18.00, 19233.10, 126083.66, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-11-21 00:00:00', NULL),
(460, 'FACT2025010460', 57, 460, '2025-01-01', '2025-01-31', 134768.99, 18.00, 24258.42, 159027.41, 'brouillon', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-01-01 00:00:00', NULL),
(461, 'FACT2025020461', 167, 461, '2025-02-19', '2025-03-21', 73031.44, 18.00, 13145.66, 86177.10, 'brouillon', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-02-17 00:00:00', NULL),
(462, 'FACT2024110462', 137, 462, '2024-11-19', '2024-12-19', 18597.53, 18.00, 3347.56, 21945.09, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-11-17 00:00:00', NULL),
(463, 'FACT2025050463', 63, 463, '2025-05-27', '2025-06-26', 14042.70, 18.00, 2527.69, 16570.39, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-05-26 00:00:00', NULL),
(464, 'FACT2025040464', 129, 464, '2025-04-19', '2025-05-19', 68670.37, 18.00, 12360.67, 81031.04, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-19 00:00:00', NULL),
(465, 'FACT2025050465', 132, 465, '2025-05-21', '2025-06-20', 194194.05, 18.00, 34954.93, 229148.98, 'brouillon', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-05-20 00:00:00', NULL),
(466, 'FACT2025030466', 136, 466, '2025-03-24', '2025-04-23', 572835.95, 18.00, 103110.47, 675946.42, 'brouillon', NULL, 'Prestation de transport - Textiles et vêtements', NULL, 1, '2025-03-22 00:00:00', NULL),
(467, 'FACT2025040467', 178, 467, '2025-04-29', '2025-05-29', 49867.81, 18.00, 8976.21, 58844.02, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-04-29 00:00:00', NULL),
(468, 'FACT2025010468', 85, 468, '2025-01-02', '2025-02-01', 40602.28, 18.00, 7308.41, 47910.69, 'brouillon', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2024-12-31 00:00:00', NULL),
(469, 'FACT2025030469', 11, 469, '2025-03-19', '2025-04-18', 1322854.70, 18.00, 238113.85, 1560968.55, 'brouillon', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-03-18 00:00:00', NULL),
(470, 'FACT2025050470', 105, 470, '2025-05-09', '2025-06-08', 122196.37, 18.00, 21995.35, 144191.72, 'brouillon', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-05-08 00:00:00', NULL),
(471, 'FACT2025020471', 42, 471, '2025-02-07', '2025-03-09', 108787.04, 18.00, 19581.67, 128368.71, 'brouillon', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-02-05 00:00:00', NULL),
(472, 'FACT2025050472', 4, 472, '2025-05-30', '2025-06-29', 299794.83, 18.00, 53963.07, 353757.90, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-29 00:00:00', NULL),
(473, 'FACT2025010473', 174, 473, '2025-01-02', '2025-02-01', 174533.77, 18.00, 31416.08, 205949.85, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2024-12-31 00:00:00', NULL),
(474, 'FACT2025050474', 62, 474, '2025-05-16', '2025-06-15', 1372373.34, 18.00, 247027.20, 1619400.54, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-05-16 00:00:00', NULL),
(475, 'FACT2025050475', 165, 475, '2025-05-18', '2025-06-17', 383995.62, 18.00, 69119.21, 453114.83, 'brouillon', NULL, 'Prestation de transport - Produits alimentaires', NULL, 1, '2025-05-16 00:00:00', NULL),
(476, 'FACT2025040476', 183, 476, '2025-04-06', '2025-05-06', 130634.43, 18.00, 23514.20, 154148.63, 'brouillon', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2025-04-04 00:00:00', NULL),
(477, 'FACT2025040477', 45, 477, '2025-04-10', '2025-05-10', 221452.92, 18.00, 39861.53, 261314.45, 'brouillon', NULL, 'Prestation de transport - Produits cosmétiques', NULL, 1, '2025-04-08 00:00:00', NULL),
(478, 'FACT2025010478', 6, 478, '2025-01-22', '2025-02-21', 240335.48, 18.00, 43260.39, 283595.87, 'brouillon', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-01-20 00:00:00', NULL),
(479, 'FACT2025030479', 38, 479, '2025-03-25', '2025-04-24', 862919.08, 18.00, 155325.43, 1018244.51, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-03-24 00:00:00', NULL),
(480, 'FACT2024120480', 171, 480, '2024-12-11', '2025-01-10', 599667.52, 18.00, 107940.15, 707607.67, 'brouillon', NULL, 'Prestation de transport - Pièces automobiles', NULL, 1, '2024-12-11 00:00:00', NULL),
(481, 'FACT2025040481', 99, 481, '2025-04-09', '2025-05-09', 207904.99, 18.00, 37422.90, 245327.89, 'brouillon', NULL, 'Prestation de transport - Équipements électroniques', NULL, 1, '2025-04-08 00:00:00', NULL),
(482, 'FACT2025050482', 67, 482, '2025-05-02', '2025-06-01', 422958.05, 18.00, 76132.45, 499090.50, 'brouillon', NULL, 'Prestation de transport - Matériaux de construction', NULL, 1, '2025-04-30 00:00:00', NULL),
(483, 'FACT2024110483', 66, 483, '2024-11-24', '2024-12-24', 1319367.36, 18.00, 237486.12, 1556853.48, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2024-11-24 00:00:00', NULL),
(484, 'FACT2025050484', 50, 484, '2025-05-16', '2025-06-15', 1027072.77, 18.00, 184873.10, 1211945.87, 'brouillon', NULL, 'Prestation de transport - Matériel informatique', NULL, 1, '2025-05-14 00:00:00', NULL),
(485, 'FACT2025020485', 195, 485, '2025-02-12', '2025-03-14', 759908.26, 18.00, 136783.49, 896691.75, 'brouillon', NULL, 'Prestation de transport - Mobilier et décoration', NULL, 1, '2025-02-10 00:00:00', NULL);

--
-- Déclencheurs `factures`
--
DROP TRIGGER IF EXISTS `tr_facture_payment_date`;
DELIMITER $$
CREATE TRIGGER `tr_facture_payment_date` BEFORE UPDATE ON `factures` FOR EACH ROW BEGIN
    IF OLD.statut != 'payee' AND NEW.statut = 'payee' AND NEW.date_paiement IS NULL THEN
        SET NEW.date_paiement = NOW();
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `maintenances`
--

DROP TABLE IF EXISTS `maintenances`;
CREATE TABLE IF NOT EXISTS `maintenances` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicule_id` int NOT NULL,
  `date_maintenance` date NOT NULL,
  `type_maintenance` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `cout` decimal(10,2) DEFAULT '0.00',
  `garage` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_maintenances_vehicule` (`vehicule_id`),
  KEY `idx_date_maintenance` (`date_maintenance`),
  KEY `idx_type_maintenance` (`type_maintenance`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `maintenances`
--

INSERT INTO `maintenances` (`id`, `vehicule_id`, `date_maintenance`, `type_maintenance`, `description`, `cout`, `garage`, `date_creation`) VALUES
(1, 1, '2025-05-30', 'Changement pneus', 'Maintenance Changement pneus - Véhicule ID 1', 60023.00, 'Garage Central Abidjan', '2025-05-30 09:53:26'),
(2, 2, '2025-05-25', 'Maintenance préventive', 'Maintenance Maintenance préventive - Véhicule ID 2', 100672.00, 'Garage Central Abidjan', '2025-05-25 09:53:26'),
(3, 3, '2025-06-03', 'Maintenance préventive', 'Maintenance Maintenance préventive - Véhicule ID 3', 205032.00, 'Méca Pro Yopougon', '2025-06-03 09:53:26'),
(4, 4, '2025-06-10', 'Révision générale', 'Maintenance Révision générale - Véhicule ID 4', 53158.00, 'Méca Pro Yopougon', '2025-06-10 09:53:26'),
(5, 5, '2025-05-22', 'Révision générale', 'Maintenance Révision générale - Véhicule ID 5', 172430.00, 'Auto Service Plateau', '2025-05-22 09:53:26'),
(6, 6, '2025-06-12', 'Changement pneus', 'Maintenance Changement pneus - Véhicule ID 6', 113134.00, 'Garage Moderne Cocody', '2025-06-12 09:53:26'),
(7, 7, '2025-05-24', 'Maintenance préventive', 'Maintenance Maintenance préventive - Véhicule ID 7', 142640.00, 'Garage Moderne Cocody', '2025-05-24 09:53:26'),
(8, 8, '2025-06-10', 'Changement pneus', 'Maintenance Changement pneus - Véhicule ID 8', 141844.00, 'Auto Service Plateau', '2025-06-10 09:53:26');

-- --------------------------------------------------------

--
-- Structure de la table `planification`
--

DROP TABLE IF EXISTS `planification`;
CREATE TABLE IF NOT EXISTS `planification` (
  `id` int NOT NULL AUTO_INCREMENT,
  `type` enum('projet','achat','voyage') NOT NULL,
  `statut` varchar(50) DEFAULT 'Planifié',
  `description` text,
  `created_by` int DEFAULT NULL,
  `updated_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `nom` varchar(255) DEFAULT NULL,
  `date_debut` date DEFAULT NULL,
  `date_fin` date DEFAULT NULL,
  `budget_estime` decimal(15,2) DEFAULT NULL,
  `priorite` enum('Haute','Moyenne','Basse') DEFAULT NULL,
  `article` varchar(255) DEFAULT NULL,
  `categorie` varchar(100) DEFAULT NULL,
  `date_prevue` date DEFAULT NULL,
  `quantite` int DEFAULT NULL,
  `prix_unitaire` decimal(15,2) DEFAULT NULL,
  `total` decimal(15,2) DEFAULT NULL,
  `destination` varchar(255) DEFAULT NULL,
  `employe_nom` varchar(255) DEFAULT NULL,
  `employe_id` int DEFAULT NULL,
  `date_depart` date DEFAULT NULL,
  `date_retour` date DEFAULT NULL,
  `budget` decimal(15,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_type` (`type`),
  KEY `idx_statut` (`statut`),
  KEY `idx_date_debut` (`date_debut`),
  KEY `idx_date_prevue` (`date_prevue`),
  KEY `idx_date_depart` (`date_depart`),
  KEY `idx_created_by` (`created_by`),
  KEY `updated_by` (`updated_by`),
  KEY `employe_id` (`employe_id`)
) ENGINE=MyISAM AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `planification_achats`
--

DROP TABLE IF EXISTS `planification_achats`;
CREATE TABLE IF NOT EXISTS `planification_achats` (
  `id` int NOT NULL AUTO_INCREMENT,
  `article` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `categorie` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `quantite` decimal(10,2) NOT NULL,
  `prix_unitaire` decimal(10,2) NOT NULL,
  `total` decimal(15,2) GENERATED ALWAYS AS ((`quantite` * `prix_unitaire`)) STORED,
  `date_prevue` date NOT NULL,
  `date_achat` date DEFAULT NULL,
  `fournisseur` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `statut` enum('Planifié','Commandé','Reçu','Annulé') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Planifié',
  `priorite` enum('Basse','Moyenne','Haute','Urgente') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Moyenne',
  `budget_alloue` decimal(15,2) DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_categorie` (`categorie`),
  KEY `idx_date_prevue` (`date_prevue`),
  KEY `idx_statut` (`statut`),
  KEY `idx_priorite` (`priorite`),
  KEY `idx_actif` (`actif`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `planification_achats`
--

INSERT INTO `planification_achats` (`id`, `article`, `description`, `categorie`, `quantite`, `prix_unitaire`, `date_prevue`, `date_achat`, `fournisseur`, `statut`, `priorite`, `budget_alloue`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 'Camion 20 tonnes', 'Camion de transport lourd pour marchandises', 'Véhicule', 2.00, 7500000.00, '2025-07-15', NULL, 'IVECO Côte d\'Ivoire', 'Planifié', 'Haute', 15000000.00, 'Négociation en cours', 1, '2025-06-15 20:51:05', NULL),
(2, 'Équipements de sécurité', 'Casques, gilets, chaussures de sécurité', 'Sécurité', 50.00, 15000.00, '2025-06-30', NULL, 'SecuriMax CI', 'Planifié', 'Moyenne', 750000.00, 'Commande urgente', 1, '2025-06-15 20:51:05', NULL),
(3, 'Ordinateurs portables', 'Laptops pour équipes terrain', 'Informatique', 10.00, 450000.00, '2025-07-10', NULL, 'TechnoPlus', 'Planifié', 'Basse', 4500000.00, 'Renouvellement parc informatique', 1, '2025-06-15 20:51:05', NULL),
(4, 'Pneus véhicules', 'Pneus de rechange pour la flotte', 'Maintenance', 20.00, 85000.00, '2025-06-25', NULL, 'Michelin CI', 'Commandé', 'Moyenne', 1700000.00, 'Stock de sécurité', 1, '2025-06-15 20:51:05', NULL);

-- --------------------------------------------------------

--
-- Structure de la table `planification_projets`
--

DROP TABLE IF EXISTS `planification_projets`;
CREATE TABLE IF NOT EXISTS `planification_projets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nom` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_debut` date NOT NULL,
  `date_fin` date NOT NULL,
  `budget_estime` decimal(15,2) NOT NULL,
  `budget_reel` decimal(15,2) DEFAULT '0.00',
  `priorite` enum('Basse','Moyenne','Haute','Critique') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Moyenne',
  `statut` enum('Planifié','En cours','Terminé','Annulé','En pause') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Planifié',
  `responsable` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `client_id` int DEFAULT NULL,
  `progression` int NOT NULL DEFAULT '0',
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_statut` (`statut`),
  KEY `idx_priorite` (`priorite`),
  KEY `idx_date_debut` (`date_debut`),
  KEY `idx_date_fin` (`date_fin`),
  KEY `idx_actif` (`actif`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `planification_projets`
--

INSERT INTO `planification_projets` (`id`, `nom`, `description`, `date_debut`, `date_fin`, `budget_estime`, `budget_reel`, `priorite`, `statut`, `responsable`, `client_id`, `progression`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 'Extension flotte véhicules', 'Acquisition de nouveaux véhicules pour répondre à la demande croissante', '2025-07-01', '2025-09-30', 15000000.00, 0.00, 'Haute', 'Planifié', 'Directeur Général', NULL, 0, 1, '2025-06-15 20:51:05', NULL),
(2, 'Digitalisation processus', 'Mise en place d\'un système de gestion intégré', '2025-08-15', '2025-12-31', 2500000.00, 0.00, 'Moyenne', 'En cours', 'Responsable IT', NULL, 25, 1, '2025-06-15 20:51:05', NULL),
(3, 'Formation équipes', 'Programme de formation pour améliorer les compétences', '2025-07-01', '2025-08-31', 800000.00, 0.00, 'Moyenne', 'Planifié', 'RH Manager', NULL, 0, 1, '2025-06-15 20:51:05', NULL);

-- --------------------------------------------------------

--
-- Structure de la table `planification_voyages`
--

DROP TABLE IF EXISTS `planification_voyages`;
CREATE TABLE IF NOT EXISTS `planification_voyages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `destination` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `objet` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `employe_id` int NOT NULL,
  `date_depart` date NOT NULL,
  `date_retour` date NOT NULL,
  `budget` decimal(15,2) NOT NULL,
  `cout_reel` decimal(15,2) DEFAULT '0.00',
  `statut` enum('Planifié','Approuvé','En cours','Terminé','Annulé','Refusé') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Planifié',
  `type_voyage` enum('Formation','Commercial','Technique','Administratif','Autre') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Commercial',
  `transport` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hebergement` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `rapport_voyage` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_employe_id` (`employe_id`),
  KEY `idx_date_depart` (`date_depart`),
  KEY `idx_date_retour` (`date_retour`),
  KEY `idx_statut` (`statut`),
  KEY `idx_type_voyage` (`type_voyage`),
  KEY `idx_actif` (`actif`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `planification_voyages`
--

INSERT INTO `planification_voyages` (`id`, `destination`, `objet`, `employe_id`, `date_depart`, `date_retour`, `budget`, `cout_reel`, `statut`, `type_voyage`, `transport`, `hebergement`, `notes`, `rapport_voyage`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 'Ouagadougou, Burkina Faso', 'Prospection nouveaux clients', 1, '2025-07-10', '2025-07-15', 850000.00, 0.00, 'Approuvé', 'Commercial', 'Avion', 'Hôtel Laico', 'Mission importante pour expansion', NULL, 1, '2025-06-15 20:51:05', NULL),
(2, 'Accra, Ghana', 'Formation technique équipes', 2, '2025-08-05', '2025-08-10', 1200000.00, 0.00, 'Planifié', 'Formation', 'Avion', 'Golden Tulip', 'Formation sur nouveaux équipements', NULL, 1, '2025-06-15 20:51:05', NULL),
(3, 'Bamako, Mali', 'Négociation contrat transport', 1, '2025-07-20', '2025-07-23', 650000.00, 0.00, 'Planifié', 'Commercial', 'Route', 'Hôtel Radisson', 'Contrat de 6 mois', NULL, 1, '2025-06-15 20:51:05', NULL),
(4, 'Lagos, Nigeria', 'Salon professionnel logistique', 3, '2025-09-15', '2025-09-18', 1500000.00, 0.00, 'Planifié', 'Commercial', 'Avion', 'Eko Hotel', 'Participation au salon LOGEXPO', NULL, 1, '2025-06-15 20:51:05', NULL);

-- --------------------------------------------------------

--
-- Structure de la table `tarification_history`
--

DROP TABLE IF EXISTS `tarification_history`;
CREATE TABLE IF NOT EXISTS `tarification_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `commande_id` int DEFAULT NULL,
  `poids` decimal(10,2) NOT NULL,
  `distance` decimal(10,2) NOT NULL,
  `zone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cargo_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'standard',
  `tarif_base` decimal(10,2) NOT NULL,
  `tarif_total` decimal(10,2) NOT NULL,
  `details` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_commande_id` (`commande_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Structure de la table `trajets`
--

DROP TABLE IF EXISTS `trajets`;
CREATE TABLE IF NOT EXISTS `trajets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `commande_id` int NOT NULL,
  `vehicule_id` int NOT NULL,
  `chauffeur_id` int NOT NULL,
  `date_depart` datetime NOT NULL,
  `date_arrivee_prevue` datetime DEFAULT NULL,
  `date_arrivee_reelle` datetime DEFAULT NULL,
  `distance_km` decimal(8,2) DEFAULT '0.00',
  `statut` enum('planifie','en_cours','termine','annule') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'planifie',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_trajets_commande` (`commande_id`),
  KEY `fk_trajets_vehicule` (`vehicule_id`),
  KEY `fk_trajets_chauffeur` (`chauffeur_id`),
  KEY `idx_statut` (`statut`),
  KEY `idx_date_depart` (`date_depart`),
  KEY `idx_actif` (`actif`),
  KEY `idx_trajets_chauffeur_statut` (`chauffeur_id`,`statut`),
  KEY `idx_trajets_vehicule_statut` (`vehicule_id`,`statut`),
  KEY `idx_trajets_vehicule_date` (`vehicule_id`,`date_depart`)
) ;

--
-- Déchargement des données de la table `trajets`
--

INSERT INTO `trajets` (`id`, `commande_id`, `vehicule_id`, `chauffeur_id`, `date_depart`, `date_arrivee_prevue`, `date_arrivee_reelle`, `distance_km`, `statut`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 1, 9, 17, '2025-05-02 17:53:48', '2025-05-02 20:53:48', '2025-05-02 20:30:48', 43.00, 'termine', NULL, 1, '2025-05-02 00:00:00', NULL),
(2, 2, 10, 18, '2025-05-09 17:14:19', '2025-05-10 00:14:19', '2025-05-10 00:55:19', 152.00, 'termine', NULL, 1, '2025-05-09 00:00:00', NULL),
(3, 3, 11, 19, '2024-12-17 02:10:02', '2024-12-17 08:10:02', '2024-12-17 07:13:02', 168.00, 'termine', NULL, 1, '2024-12-17 00:00:00', NULL),
(4, 4, 12, 20, '2025-03-19 21:16:52', '2025-03-20 00:16:52', '2025-03-19 23:34:52', 37.00, 'termine', NULL, 1, '2025-03-15 00:00:00', NULL),
(5, 5, 13, 21, '2025-05-27 02:51:26', '2025-05-27 09:51:26', '2025-05-27 11:20:26', 185.00, 'termine', NULL, 1, '2025-05-25 00:00:00', NULL),
(6, 6, 14, 22, '2025-01-05 09:23:41', '2025-01-05 18:23:41', '2025-01-05 18:00:41', 376.00, 'termine', NULL, 1, '2025-01-05 00:00:00', NULL),
(7, 7, 15, 23, '2025-03-21 01:15:59', '2025-03-21 09:15:59', '2025-03-21 09:51:59', 210.00, 'termine', NULL, 1, '2025-03-16 00:00:00', NULL),
(8, 8, 16, 24, '2025-02-11 12:54:02', '2025-02-11 22:54:02', '2025-02-12 00:37:02', 472.00, 'termine', NULL, 1, '2025-02-09 00:00:00', NULL),
(9, 9, 17, 25, '2024-12-03 07:13:11', '2024-12-03 13:13:11', '2024-12-03 13:24:11', 286.00, 'termine', NULL, 1, '2024-12-02 00:00:00', NULL),
(10, 10, 18, 26, '2024-11-19 06:41:13', '2024-11-19 09:41:13', '2024-11-19 09:54:13', 45.00, 'termine', NULL, 1, '2024-11-18 00:00:00', NULL),
(11, 11, 19, 27, '2024-11-23 08:29:16', '2024-11-23 14:29:16', '2024-11-23 14:23:16', 177.00, 'termine', NULL, 1, '2024-11-22 00:00:00', NULL),
(12, 12, 20, 28, '2025-02-20 15:23:48', '2025-02-20 22:23:48', '2025-02-20 22:57:48', 316.00, 'termine', NULL, 1, '2025-02-19 00:00:00', NULL),
(13, 13, 21, 29, '2025-04-16 02:52:34', '2025-04-16 04:52:34', '2025-04-16 05:15:34', 7.00, 'termine', NULL, 1, '2025-04-10 00:00:00', NULL),
(14, 14, 22, 30, '2025-01-22 06:38:34', '2025-01-22 09:38:34', '2025-01-22 10:05:34', 26.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(15, 15, 23, 17, '2025-05-10 18:21:37', '2025-05-11 08:21:37', '2025-05-11 09:28:37', 632.00, 'termine', NULL, 1, '2025-05-09 00:00:00', NULL),
(16, 16, 24, 18, '2025-05-23 20:11:57', '2025-05-24 01:11:57', '2025-05-24 02:22:57', 191.00, 'termine', NULL, 1, '2025-05-23 00:00:00', NULL),
(17, 17, 25, 19, '2025-02-20 03:12:57', '2025-02-20 13:12:57', '2025-02-20 14:16:57', 514.00, 'termine', NULL, 1, '2025-02-20 00:00:00', NULL),
(18, 18, 26, 20, '2025-01-03 12:23:55', '2025-01-04 01:23:55', '2025-01-04 02:07:55', 611.00, 'termine', NULL, 1, '2025-01-03 00:00:00', NULL),
(19, 19, 27, 21, '2025-03-04 07:49:56', '2025-03-04 20:49:56', '2025-03-04 21:22:56', 667.00, 'termine', NULL, 1, '2025-03-04 00:00:00', NULL),
(20, 20, 28, 22, '2025-02-21 01:32:37', '2025-02-21 11:32:37', '2025-02-21 13:25:37', 532.00, 'termine', NULL, 1, '2025-02-21 00:00:00', NULL),
(21, 21, 29, 23, '2025-01-26 08:46:29', '2025-01-26 14:46:29', '2025-01-26 15:08:29', 186.00, 'termine', NULL, 1, '2025-01-25 00:00:00', NULL),
(22, 22, 30, 24, '2025-03-23 16:04:20', '2025-03-24 06:04:20', '2025-03-24 05:26:20', 690.00, 'termine', NULL, 1, '2025-03-23 00:00:00', NULL),
(23, 23, 31, 25, '2025-02-02 04:52:00', '2025-02-02 08:52:00', '2025-02-02 09:29:00', 99.00, 'termine', NULL, 1, '2025-02-01 00:00:00', NULL),
(24, 24, 32, 26, '2025-04-23 08:41:33', '2025-04-23 17:41:33', '2025-04-23 19:09:33', 266.00, 'termine', NULL, 1, '2025-04-20 00:00:00', NULL),
(25, 25, 33, 27, '2024-12-03 23:12:53', '2024-12-04 11:12:53', '2024-12-04 10:29:53', 621.00, 'termine', NULL, 1, '2024-12-03 00:00:00', NULL),
(26, 26, 34, 28, '2025-01-30 23:49:14', '2025-01-31 08:49:14', '2025-01-31 09:10:14', 366.00, 'termine', NULL, 1, '2025-01-27 00:00:00', NULL),
(27, 27, 35, 29, '2024-12-21 04:45:02', '2024-12-21 14:45:02', '2024-12-21 13:53:02', 516.00, 'termine', NULL, 1, '2024-12-21 00:00:00', NULL),
(28, 28, 36, 30, '2025-03-09 04:35:50', '2025-03-09 14:35:50', '2025-03-09 14:02:50', 516.00, 'termine', NULL, 1, '2025-03-08 00:00:00', NULL),
(29, 29, 37, 17, '2025-04-16 20:05:16', '2025-04-17 01:05:16', '2025-04-17 02:20:16', 110.00, 'termine', NULL, 1, '2025-04-16 00:00:00', NULL),
(30, 30, 38, 18, '2025-04-01 00:47:16', '2025-04-01 14:47:16', '2025-04-01 14:03:16', 579.00, 'termine', NULL, 1, '2025-03-28 00:00:00', NULL),
(31, 31, 39, 19, '2025-01-21 22:54:46', '2025-01-22 07:54:46', '2025-01-22 07:39:46', 329.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(32, 32, 40, 20, '2025-03-16 03:13:02', '2025-03-16 15:13:02', '2025-03-16 14:33:02', 443.00, 'termine', NULL, 1, '2025-03-16 00:00:00', NULL),
(33, 33, 41, 21, '2025-03-12 09:41:02', '2025-03-12 16:41:02', '2025-03-12 16:42:02', 267.00, 'termine', NULL, 1, '2025-03-07 00:00:00', NULL),
(34, 34, 42, 22, '2025-04-21 06:27:45', '2025-04-21 14:27:45', '2025-04-21 15:37:45', 286.00, 'termine', NULL, 1, '2025-04-15 00:00:00', NULL),
(35, 35, 43, 23, '2025-05-02 19:48:03', '2025-05-03 02:48:03', '2025-05-03 04:13:03', 358.00, 'termine', NULL, 1, '2025-05-02 00:00:00', NULL),
(36, 36, 44, 24, '2024-11-20 08:21:52', '2024-11-20 14:21:52', '2024-11-20 16:17:52', 138.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(37, 37, 45, 25, '2025-05-09 02:43:29', '2025-05-09 16:43:29', '2025-05-09 16:34:29', 704.00, 'termine', NULL, 1, '2025-05-08 00:00:00', NULL),
(38, 38, 46, 26, '2025-01-11 05:33:17', '2025-01-11 15:33:17', '2025-01-11 16:54:17', 475.00, 'termine', NULL, 1, '2025-01-11 00:00:00', NULL),
(39, 39, 47, 27, '2025-01-14 20:10:06', '2025-01-15 04:10:06', '2025-01-15 03:45:06', 411.00, 'termine', NULL, 1, '2025-01-11 00:00:00', NULL),
(40, 40, 48, 28, '2025-05-16 19:27:22', '2025-05-17 02:27:22', '2025-05-17 03:42:22', 187.00, 'termine', NULL, 1, '2025-05-13 00:00:00', NULL),
(41, 41, 49, 29, '2025-03-17 17:36:55', '2025-03-18 01:36:55', '2025-03-18 02:09:55', 183.00, 'termine', NULL, 1, '2025-03-15 00:00:00', NULL),
(42, 42, 50, 30, '2025-02-10 05:07:15', '2025-02-10 11:07:15', '2025-02-10 11:05:15', 159.00, 'termine', NULL, 1, '2025-02-10 00:00:00', NULL),
(43, 43, 51, 17, '2024-11-21 16:27:24', '2024-11-21 22:27:24', '2024-11-21 22:07:24', 267.00, 'termine', NULL, 1, '2024-11-16 00:00:00', NULL),
(44, 44, 52, 18, '2025-01-23 17:54:11', '2025-01-24 05:54:11', '2025-01-24 07:34:11', 614.00, 'termine', NULL, 1, '2025-01-23 00:00:00', NULL),
(45, 45, 53, 19, '2025-01-29 19:10:34', '2025-01-30 03:10:34', '2025-01-30 02:29:34', 299.00, 'termine', NULL, 1, '2025-01-29 00:00:00', NULL),
(46, 46, 54, 20, '2025-02-20 20:08:43', '2025-02-21 05:08:43', '2025-02-21 06:02:43', 461.00, 'termine', NULL, 1, '2025-02-14 00:00:00', NULL),
(47, 47, 55, 21, '2025-02-23 20:54:53', '2025-02-23 23:54:53', '2025-02-23 23:18:53', 78.00, 'termine', NULL, 1, '2025-02-20 00:00:00', NULL),
(48, 48, 56, 22, '2025-01-29 12:37:58', '2025-01-29 21:37:58', '2025-01-29 23:29:58', 269.00, 'termine', NULL, 1, '2025-01-28 00:00:00', NULL),
(49, 49, 57, 23, '2024-12-07 15:53:01', '2024-12-08 00:53:01', '2024-12-08 00:43:01', 388.00, 'termine', NULL, 1, '2024-12-03 00:00:00', NULL),
(50, 50, 58, 24, '2025-02-27 19:06:52', '2025-02-28 03:06:52', '2025-02-28 02:28:52', 303.00, 'termine', NULL, 1, '2025-02-27 00:00:00', NULL),
(51, 51, 59, 25, '2025-01-02 21:52:25', '2025-01-03 04:52:25', '2025-01-03 04:40:25', 186.00, 'termine', NULL, 1, '2025-01-01 00:00:00', NULL),
(52, 52, 60, 26, '2025-04-06 03:46:23', '2025-04-06 11:46:23', '2025-04-06 12:09:23', 385.00, 'termine', NULL, 1, '2025-04-05 00:00:00', NULL),
(53, 53, 61, 27, '2025-02-14 10:07:34', '2025-02-14 18:07:34', '2025-02-14 19:22:34', 413.00, 'termine', NULL, 1, '2025-02-12 00:00:00', NULL),
(54, 54, 62, 28, '2025-05-14 23:12:07', '2025-05-15 09:12:07', '2025-05-15 09:47:07', 431.00, 'termine', NULL, 1, '2025-05-12 00:00:00', NULL),
(55, 55, 63, 29, '2025-04-03 18:13:46', '2025-04-04 01:13:46', '2025-04-04 02:19:46', 261.00, 'termine', NULL, 1, '2025-04-03 00:00:00', NULL),
(56, 56, 64, 30, '2025-03-24 04:07:34', '2025-03-24 15:07:34', '2025-03-24 15:44:34', 373.00, 'termine', NULL, 1, '2025-03-24 00:00:00', NULL),
(57, 57, 65, 17, '2025-02-08 17:59:11', '2025-02-08 20:59:11', '2025-02-08 21:36:11', 11.00, 'termine', NULL, 1, '2025-02-05 00:00:00', NULL),
(58, 58, 66, 18, '2025-04-14 19:57:10', '2025-04-15 12:57:10', '2025-04-15 14:21:10', 798.00, 'termine', NULL, 1, '2025-04-11 00:00:00', NULL),
(59, 59, 67, 19, '2024-12-16 23:24:30', '2024-12-17 09:24:30', '2024-12-17 10:15:30', 504.00, 'termine', NULL, 1, '2024-12-15 00:00:00', NULL),
(60, 60, 9, 20, '2025-05-22 13:50:54', '2025-05-22 20:50:54', '2025-05-22 22:12:54', 316.00, 'termine', NULL, 1, '2025-05-22 00:00:00', NULL),
(61, 61, 10, 21, '2024-12-23 23:55:27', '2024-12-24 04:55:27', '2024-12-24 04:08:27', 211.00, 'termine', NULL, 1, '2024-12-19 00:00:00', NULL),
(62, 62, 11, 22, '2025-03-10 21:46:48', '2025-03-11 10:46:48', '2025-03-11 10:21:48', 657.00, 'termine', NULL, 1, '2025-03-10 00:00:00', NULL),
(63, 63, 12, 23, '2025-01-11 11:44:03', '2025-01-12 01:44:03', '2025-01-12 02:39:03', 684.00, 'termine', NULL, 1, '2025-01-11 00:00:00', NULL),
(64, 64, 13, 24, '2025-04-10 15:13:35', '2025-04-11 04:13:35', '2025-04-11 05:08:35', 546.00, 'termine', NULL, 1, '2025-04-09 00:00:00', NULL),
(65, 65, 14, 25, '2025-02-03 12:41:24', '2025-02-03 23:41:24', '2025-02-03 23:38:24', 599.00, 'termine', NULL, 1, '2025-02-01 00:00:00', NULL),
(66, 66, 15, 26, '2025-03-15 08:47:29', '2025-03-16 00:47:29', '2025-03-16 00:43:29', 689.00, 'termine', NULL, 1, '2025-03-14 00:00:00', NULL),
(67, 67, 16, 27, '2025-01-20 11:12:53', '2025-01-21 00:12:53', '2025-01-20 23:14:53', 702.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(68, 68, 17, 28, '2024-12-15 06:53:38', '2024-12-15 20:53:38', '2024-12-15 22:21:38', 660.00, 'termine', NULL, 1, '2024-12-15 00:00:00', NULL),
(69, 69, 18, 29, '2025-01-07 08:37:41', '2025-01-07 13:37:41', '2025-01-07 12:52:41', 65.00, 'termine', NULL, 1, '2025-01-02 00:00:00', NULL),
(70, 70, 19, 30, '2025-04-04 22:12:50', '2025-04-05 15:12:50', '2025-04-05 16:15:50', 795.00, 'termine', NULL, 1, '2025-04-03 00:00:00', NULL),
(71, 71, 20, 17, '2025-02-18 22:52:46', '2025-02-19 11:52:46', '2025-02-19 11:08:46', 691.00, 'termine', NULL, 1, '2025-02-15 00:00:00', NULL),
(72, 72, 21, 18, '2025-02-10 00:57:47', '2025-02-10 15:57:47', '2025-02-10 17:30:47', 697.00, 'termine', NULL, 1, '2025-02-06 00:00:00', NULL),
(73, 73, 22, 19, '2025-04-15 23:56:19', '2025-04-16 09:56:19', '2025-04-16 10:38:19', 346.00, 'termine', NULL, 1, '2025-04-15 00:00:00', NULL),
(74, 74, 23, 20, '2025-02-05 16:08:55', '2025-02-05 20:08:55', '2025-02-05 20:32:55', 93.00, 'termine', NULL, 1, '2025-02-05 00:00:00', NULL),
(75, 75, 24, 21, '2025-01-17 18:16:50', '2025-01-17 22:16:50', '2025-01-17 21:56:50', 176.00, 'termine', NULL, 1, '2025-01-17 00:00:00', NULL),
(76, 76, 25, 22, '2025-01-18 06:48:45', '2025-01-18 23:48:45', '2025-01-18 23:33:45', 792.00, 'termine', NULL, 1, '2025-01-18 00:00:00', NULL),
(77, 77, 26, 23, '2025-05-29 00:01:00', '2025-05-29 03:01:00', '2025-05-29 04:00:00', 6.00, 'termine', NULL, 1, '2025-05-29 00:00:00', NULL),
(78, 78, 27, 24, '2025-05-14 12:42:50', '2025-05-15 04:42:50', '2025-05-15 03:49:50', 675.00, 'termine', NULL, 1, '2025-05-14 00:00:00', NULL),
(79, 79, 28, 25, '2025-04-30 23:48:06', '2025-05-01 16:48:06', '2025-05-01 15:50:06', 775.00, 'termine', NULL, 1, '2025-04-27 00:00:00', NULL),
(80, 80, 29, 26, '2025-04-28 23:33:16', '2025-04-29 08:33:16', '2025-04-29 09:42:16', 283.00, 'termine', NULL, 1, '2025-04-27 00:00:00', NULL),
(81, 81, 30, 27, '2025-04-04 22:04:25', '2025-04-05 14:04:25', '2025-04-05 14:26:25', 737.00, 'termine', NULL, 1, '2025-04-03 00:00:00', NULL),
(82, 82, 31, 28, '2025-01-25 02:00:24', '2025-01-25 14:00:24', '2025-01-25 14:44:24', 485.00, 'termine', NULL, 1, '2025-01-25 00:00:00', NULL),
(83, 83, 32, 29, '2025-01-15 08:15:19', '2025-01-15 22:15:19', '2025-01-15 22:40:19', 614.00, 'termine', NULL, 1, '2025-01-13 00:00:00', NULL),
(84, 84, 33, 30, '2025-04-01 19:06:29', '2025-04-02 09:06:29', '2025-04-02 10:16:29', 696.00, 'termine', NULL, 1, '2025-04-01 00:00:00', NULL),
(85, 85, 34, 17, '2025-03-27 06:43:37', '2025-03-27 19:43:37', '2025-03-27 21:11:37', 680.00, 'termine', NULL, 1, '2025-03-24 00:00:00', NULL),
(86, 86, 35, 18, '2025-02-20 14:23:50', '2025-02-21 01:23:50', '2025-02-21 03:10:50', 565.00, 'termine', NULL, 1, '2025-02-19 00:00:00', NULL),
(87, 87, 36, 19, '2024-12-10 12:06:52', '2024-12-11 00:06:52', '2024-12-10 23:30:52', 526.00, 'termine', NULL, 1, '2024-12-10 00:00:00', NULL),
(88, 88, 37, 20, '2024-12-10 05:10:03', '2024-12-10 14:10:03', '2024-12-10 14:31:03', 289.00, 'termine', NULL, 1, '2024-12-10 00:00:00', NULL),
(89, 89, 38, 21, '2025-03-10 21:57:00', '2025-03-11 06:57:00', '2025-03-11 06:28:00', 257.00, 'termine', NULL, 1, '2025-03-08 00:00:00', NULL),
(90, 90, 39, 22, '2025-05-30 05:46:32', '2025-05-30 15:46:32', '2025-05-30 15:26:32', 382.00, 'termine', NULL, 1, '2025-05-30 00:00:00', NULL),
(91, 91, 40, 23, '2025-05-10 05:05:02', '2025-05-10 13:05:02', '2025-05-10 13:33:02', 259.00, 'termine', NULL, 1, '2025-05-10 00:00:00', NULL),
(92, 92, 41, 24, '2025-04-27 18:13:50', '2025-04-28 05:13:50', '2025-04-28 07:06:50', 377.00, 'termine', NULL, 1, '2025-04-26 00:00:00', NULL),
(93, 93, 42, 25, '2025-04-15 07:55:07', '2025-04-15 10:55:07', '2025-04-15 12:39:07', 26.00, 'termine', NULL, 1, '2025-04-15 00:00:00', NULL),
(94, 94, 43, 26, '2025-04-16 15:05:11', '2025-04-17 07:05:11', '2025-04-17 09:03:11', 678.00, 'termine', NULL, 1, '2025-04-16 00:00:00', NULL),
(95, 95, 44, 27, '2025-01-19 22:42:52', '2025-01-20 12:42:52', '2025-01-20 13:31:52', 613.00, 'termine', NULL, 1, '2025-01-19 00:00:00', NULL),
(96, 96, 45, 28, '2025-04-18 11:37:37', '2025-04-18 22:37:37', '2025-04-18 23:44:37', 405.00, 'termine', NULL, 1, '2025-04-17 00:00:00', NULL),
(97, 97, 46, 29, '2024-11-29 05:33:00', '2024-11-29 17:33:00', '2024-11-29 17:05:00', 511.00, 'termine', NULL, 1, '2024-11-27 00:00:00', NULL),
(98, 98, 47, 30, '2025-02-01 22:46:18', '2025-02-02 14:46:18', '2025-02-02 15:17:18', 750.00, 'termine', NULL, 1, '2025-01-31 00:00:00', NULL),
(99, 99, 48, 17, '2025-04-18 07:55:46', '2025-04-18 17:55:46', '2025-04-18 19:06:46', 311.00, 'termine', NULL, 1, '2025-04-17 00:00:00', NULL),
(100, 100, 49, 18, '2025-02-21 00:13:11', '2025-02-21 15:13:11', '2025-02-21 17:09:11', 722.00, 'termine', NULL, 1, '2025-02-19 00:00:00', NULL),
(101, 101, 50, 19, '2025-04-29 01:32:19', '2025-04-29 15:32:19', '2025-04-29 16:29:19', 595.00, 'termine', NULL, 1, '2025-04-29 00:00:00', NULL),
(102, 102, 51, 20, '2025-05-04 02:03:49', '2025-05-04 16:03:49', '2025-05-04 15:59:49', 644.00, 'termine', NULL, 1, '2025-05-04 00:00:00', NULL),
(103, 103, 52, 21, '2025-01-28 04:14:13', '2025-01-28 10:14:13', '2025-01-28 09:59:13', 251.00, 'termine', NULL, 1, '2025-01-28 00:00:00', NULL),
(104, 104, 53, 22, '2025-03-25 06:58:03', '2025-03-25 21:58:03', '2025-03-25 23:36:03', 620.00, 'termine', NULL, 1, '2025-03-25 00:00:00', NULL),
(105, 105, 54, 23, '2025-05-26 04:23:57', '2025-05-26 10:23:57', '2025-05-26 11:50:57', 279.00, 'termine', NULL, 1, '2025-05-24 00:00:00', NULL),
(106, 106, 55, 24, '2025-04-03 14:57:19', '2025-04-04 00:57:19', '2025-04-04 01:25:19', 417.00, 'termine', NULL, 1, '2025-03-31 00:00:00', NULL),
(107, 107, 56, 25, '2025-02-22 12:35:20', '2025-02-22 18:35:20', '2025-02-22 17:37:20', 166.00, 'termine', NULL, 1, '2025-02-17 00:00:00', NULL),
(108, 108, 57, 26, '2024-11-26 20:40:21', '2024-11-27 09:40:21', '2024-11-27 09:14:21', 498.00, 'termine', NULL, 1, '2024-11-26 00:00:00', NULL),
(109, 109, 58, 27, '2025-02-08 20:29:34', '2025-02-09 03:29:34', '2025-02-09 04:52:34', 211.00, 'termine', NULL, 1, '2025-02-07 00:00:00', NULL),
(110, 110, 59, 28, '2024-11-29 08:41:36', '2024-11-29 16:41:36', '2024-11-29 17:32:36', 362.00, 'termine', NULL, 1, '2024-11-27 00:00:00', NULL),
(111, 111, 60, 29, '2025-01-01 17:06:48', '2025-01-02 00:06:48', '2025-01-02 01:57:48', 271.00, 'termine', NULL, 1, '2024-12-29 00:00:00', NULL),
(112, 112, 61, 30, '2025-02-08 23:48:56', '2025-02-09 01:48:56', '2025-02-09 01:22:56', 45.00, 'termine', NULL, 1, '2025-02-07 00:00:00', NULL),
(113, 113, 62, 17, '2025-01-17 10:34:08', '2025-01-17 19:34:08', '2025-01-17 20:15:08', 428.00, 'termine', NULL, 1, '2025-01-17 00:00:00', NULL),
(114, 114, 63, 18, '2025-05-14 03:28:40', '2025-05-14 07:28:40', '2025-05-14 06:28:40', 133.00, 'termine', NULL, 1, '2025-05-12 00:00:00', NULL),
(115, 115, 64, 19, '2025-02-03 21:20:48', '2025-02-03 23:20:48', '2025-02-04 00:09:48', 11.00, 'termine', NULL, 1, '2025-02-02 00:00:00', NULL),
(116, 116, 65, 20, '2025-03-07 11:31:05', '2025-03-07 15:31:05', '2025-03-07 15:55:05', 48.00, 'termine', NULL, 1, '2025-03-07 00:00:00', NULL),
(117, 117, 66, 21, '2024-12-30 14:26:40', '2024-12-31 03:26:40', '2024-12-31 02:28:40', 648.00, 'termine', NULL, 1, '2024-12-30 00:00:00', NULL),
(118, 118, 67, 22, '2025-03-05 20:50:01', '2025-03-06 04:50:01', '2025-03-06 04:50:01', 295.00, 'termine', NULL, 1, '2025-03-04 00:00:00', NULL),
(119, 119, 9, 23, '2025-01-30 19:18:54', '2025-01-31 10:18:54', '2025-01-31 11:13:54', 700.00, 'termine', NULL, 1, '2025-01-29 00:00:00', NULL),
(120, 120, 10, 24, '2024-12-10 08:33:15', '2024-12-10 19:33:15', '2024-12-10 21:24:15', 363.00, 'termine', NULL, 1, '2024-12-08 00:00:00', NULL),
(121, 121, 11, 25, '2025-06-03 15:19:42', '2025-06-04 05:19:42', '2025-06-04 06:54:42', 725.00, 'termine', NULL, 1, '2025-06-03 00:00:00', NULL),
(122, 122, 12, 26, '2025-04-26 08:13:33', '2025-04-27 00:13:33', '2025-04-27 00:00:33', 794.00, 'termine', NULL, 1, '2025-04-22 00:00:00', NULL),
(123, 123, 13, 27, '2025-02-20 08:19:13', '2025-02-20 20:19:13', '2025-02-20 22:03:13', 430.00, 'termine', NULL, 1, '2025-02-18 00:00:00', NULL),
(124, 124, 14, 28, '2025-05-13 00:38:27', '2025-05-13 06:38:27', '2025-05-13 06:28:27', 176.00, 'termine', NULL, 1, '2025-05-11 00:00:00', NULL),
(125, 125, 15, 29, '2025-05-05 19:30:08', '2025-05-06 02:30:08', '2025-05-06 03:46:08', 325.00, 'termine', NULL, 1, '2025-04-30 00:00:00', NULL),
(126, 126, 16, 30, '2025-02-19 10:16:55', '2025-02-19 18:16:55', '2025-02-19 17:52:55', 341.00, 'termine', NULL, 1, '2025-02-19 00:00:00', NULL),
(127, 127, 17, 17, '2025-05-06 20:19:17', '2025-05-07 03:19:17', '2025-05-07 05:16:17', 167.00, 'termine', NULL, 1, '2025-05-06 00:00:00', NULL),
(128, 128, 18, 18, '2025-01-20 16:33:34', '2025-01-21 03:33:34', '2025-01-21 03:41:34', 454.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(129, 129, 19, 19, '2024-11-27 04:06:38', '2024-11-27 10:06:38', '2024-11-27 11:42:38', 296.00, 'termine', NULL, 1, '2024-11-23 00:00:00', NULL),
(130, 130, 20, 20, '2025-04-26 23:55:09', '2025-04-27 07:55:09', '2025-04-27 08:02:09', 237.00, 'termine', NULL, 1, '2025-04-24 00:00:00', NULL),
(131, 131, 21, 21, '2025-02-09 22:30:30', '2025-02-10 12:30:30', '2025-02-10 13:34:30', 643.00, 'termine', NULL, 1, '2025-02-08 00:00:00', NULL),
(132, 132, 22, 22, '2025-01-15 03:05:33', '2025-01-15 20:05:33', '2025-01-15 19:23:33', 742.00, 'termine', NULL, 1, '2025-01-12 00:00:00', NULL),
(133, 133, 23, 23, '2025-02-04 16:05:35', '2025-02-05 04:05:35', '2025-02-05 04:08:35', 588.00, 'termine', NULL, 1, '2025-01-29 00:00:00', NULL),
(134, 134, 24, 24, '2025-03-24 08:21:07', '2025-03-24 23:21:07', '2025-03-24 22:40:07', 696.00, 'termine', NULL, 1, '2025-03-24 00:00:00', NULL),
(135, 135, 25, 25, '2025-04-06 07:05:39', '2025-04-06 22:05:39', '2025-04-06 23:07:39', 780.00, 'termine', NULL, 1, '2025-04-04 00:00:00', NULL),
(136, 136, 26, 26, '2025-03-20 07:10:27', '2025-03-20 09:10:27', '2025-03-20 10:38:27', 51.00, 'termine', NULL, 1, '2025-03-20 00:00:00', NULL),
(137, 137, 27, 27, '2024-12-17 19:31:25', '2024-12-18 02:31:25', '2024-12-18 02:34:25', 349.00, 'termine', NULL, 1, '2024-12-15 00:00:00', NULL),
(138, 138, 28, 28, '2025-02-13 19:29:20', '2025-02-14 12:29:20', '2025-02-14 12:56:20', 799.00, 'termine', NULL, 1, '2025-02-13 00:00:00', NULL),
(139, 139, 29, 29, '2025-03-03 22:28:18', '2025-03-04 12:28:18', '2025-03-04 12:31:18', 769.00, 'termine', NULL, 1, '2025-02-28 00:00:00', NULL),
(140, 140, 30, 30, '2025-02-02 20:24:13', '2025-02-03 11:24:13', '2025-02-03 12:07:13', 686.00, 'termine', NULL, 1, '2025-01-31 00:00:00', NULL),
(141, 141, 31, 17, '2025-04-02 22:18:20', '2025-04-03 12:18:20', '2025-04-03 12:31:20', 546.00, 'termine', NULL, 1, '2025-04-01 00:00:00', NULL),
(142, 142, 32, 18, '2025-04-08 10:47:16', '2025-04-08 23:47:16', '2025-04-08 22:52:16', 485.00, 'termine', NULL, 1, '2025-04-04 00:00:00', NULL),
(143, 143, 33, 19, '2025-03-31 02:55:17', '2025-03-31 12:55:17', '2025-03-31 14:45:17', 328.00, 'termine', NULL, 1, '2025-03-29 00:00:00', NULL),
(144, 144, 34, 20, '2024-12-05 10:29:29', '2024-12-05 19:29:29', '2024-12-05 21:11:29', 392.00, 'termine', NULL, 1, '2024-12-02 00:00:00', NULL),
(145, 145, 35, 21, '2025-05-11 04:01:07', '2025-05-11 20:01:07', '2025-05-11 20:54:07', 800.00, 'termine', NULL, 1, '2025-05-11 00:00:00', NULL),
(146, 146, 36, 22, '2025-02-08 14:00:22', '2025-02-08 21:00:22', '2025-02-08 22:16:22', 168.00, 'termine', NULL, 1, '2025-02-07 00:00:00', NULL),
(147, 147, 37, 23, '2025-04-15 19:09:20', '2025-04-16 07:09:20', '2025-04-16 08:35:20', 524.00, 'termine', NULL, 1, '2025-04-15 00:00:00', NULL),
(148, 148, 38, 24, '2025-01-11 03:10:12', '2025-01-11 16:10:12', '2025-01-11 18:08:12', 595.00, 'termine', NULL, 1, '2025-01-07 00:00:00', NULL),
(149, 149, 39, 25, '2025-01-24 11:20:39', '2025-01-24 20:20:39', '2025-01-24 19:54:39', 314.00, 'termine', NULL, 1, '2025-01-24 00:00:00', NULL),
(150, 150, 40, 26, '2025-03-10 22:46:11', '2025-03-11 08:46:11', '2025-03-11 07:53:11', 441.00, 'termine', NULL, 1, '2025-03-05 00:00:00', NULL),
(151, 151, 41, 27, '2024-12-30 11:46:23', '2024-12-30 23:46:23', '2024-12-30 22:55:23', 601.00, 'termine', NULL, 1, '2024-12-28 00:00:00', NULL),
(152, 152, 42, 28, '2024-11-20 01:25:06', '2024-11-20 15:25:06', '2024-11-20 16:01:06', 709.00, 'termine', NULL, 1, '2024-11-20 00:00:00', NULL),
(153, 153, 43, 29, '2025-02-18 04:10:27', '2025-02-18 10:10:27', '2025-02-18 10:06:27', 155.00, 'termine', NULL, 1, '2025-02-18 00:00:00', NULL),
(154, 154, 44, 30, '2024-12-04 12:12:13', '2024-12-04 19:12:13', '2024-12-04 20:03:13', 315.00, 'termine', NULL, 1, '2024-12-03 00:00:00', NULL),
(155, 155, 45, 17, '2025-05-01 06:17:47', '2025-05-01 20:17:47', '2025-05-01 19:42:47', 620.00, 'termine', NULL, 1, '2025-05-01 00:00:00', NULL),
(156, 156, 46, 18, '2025-05-25 12:20:55', '2025-05-25 23:20:55', '2025-05-25 23:44:55', 584.00, 'termine', NULL, 1, '2025-05-19 00:00:00', NULL),
(157, 157, 47, 19, '2025-01-11 08:26:08', '2025-01-11 22:26:08', '2025-01-11 23:41:08', 703.00, 'termine', NULL, 1, '2025-01-08 00:00:00', NULL),
(158, 158, 48, 20, '2025-04-13 09:19:27', '2025-04-13 16:19:27', '2025-04-13 18:01:27', 330.00, 'termine', NULL, 1, '2025-04-13 00:00:00', NULL),
(159, 159, 49, 21, '2025-03-19 02:26:04', '2025-03-19 05:26:04', '2025-03-19 04:31:04', 52.00, 'termine', NULL, 1, '2025-03-19 00:00:00', NULL),
(160, 160, 50, 22, '2025-03-04 15:58:09', '2025-03-05 02:58:09', '2025-03-05 02:38:09', 449.00, 'termine', NULL, 1, '2025-03-03 00:00:00', NULL),
(161, 161, 51, 23, '2025-03-24 01:01:00', '2025-03-24 15:01:00', '2025-03-24 15:30:00', 750.00, 'termine', NULL, 1, '2025-03-24 00:00:00', NULL),
(162, 162, 52, 24, '2025-04-20 14:50:36', '2025-04-21 02:50:36', '2025-04-21 02:32:36', 617.00, 'termine', NULL, 1, '2025-04-16 00:00:00', NULL),
(163, 163, 53, 25, '2025-05-25 18:05:41', '2025-05-25 23:05:41', '2025-05-25 22:10:41', 67.00, 'termine', NULL, 1, '2025-05-22 00:00:00', NULL),
(164, 164, 54, 26, '2025-01-24 19:39:18', '2025-01-25 11:39:18', '2025-01-25 11:11:18', 762.00, 'termine', NULL, 1, '2025-01-24 00:00:00', NULL),
(165, 165, 55, 27, '2025-05-24 18:24:09', '2025-05-24 23:24:09', '2025-05-25 00:55:09', 207.00, 'termine', NULL, 1, '2025-05-24 00:00:00', NULL),
(166, 166, 56, 28, '2024-11-21 22:10:28', '2024-11-22 11:10:28', '2024-11-22 11:08:28', 547.00, 'termine', NULL, 1, '2024-11-21 00:00:00', NULL),
(167, 167, 57, 29, '2025-05-31 04:02:17', '2025-05-31 19:02:17', '2025-05-31 20:27:17', 698.00, 'termine', NULL, 1, '2025-05-27 00:00:00', NULL),
(168, 168, 58, 30, '2025-02-09 18:41:35', '2025-02-10 01:41:35', '2025-02-10 02:53:35', 333.00, 'termine', NULL, 1, '2025-02-09 00:00:00', NULL),
(169, 169, 59, 17, '2024-11-24 08:35:10', '2024-11-24 21:35:10', '2024-11-24 21:51:10', 666.00, 'termine', NULL, 1, '2024-11-24 00:00:00', NULL),
(170, 170, 60, 18, '2024-12-19 05:10:10', '2024-12-19 09:10:10', '2024-12-19 09:28:10', 10.00, 'termine', NULL, 1, '2024-12-17 00:00:00', NULL),
(171, 171, 61, 19, '2025-04-22 16:54:49', '2025-04-23 08:54:49', '2025-04-23 10:00:49', 710.00, 'termine', NULL, 1, '2025-04-16 00:00:00', NULL),
(172, 172, 62, 20, '2024-12-21 18:33:20', '2024-12-22 00:33:20', '2024-12-22 00:56:20', 269.00, 'termine', NULL, 1, '2024-12-19 00:00:00', NULL),
(173, 173, 63, 21, '2025-06-05 12:30:28', '2025-06-06 06:30:28', '2025-06-06 06:25:28', 797.00, 'termine', NULL, 1, '2025-06-02 00:00:00', NULL),
(174, 174, 64, 22, '2025-02-01 01:50:14', '2025-02-01 08:50:14', '2025-02-01 10:45:14', 235.00, 'termine', NULL, 1, '2025-02-01 00:00:00', NULL),
(175, 175, 65, 23, '2025-02-11 23:18:00', '2025-02-12 05:18:00', '2025-02-12 04:46:00', 231.00, 'termine', NULL, 1, '2025-02-09 00:00:00', NULL),
(176, 176, 66, 24, '2025-03-06 00:42:35', '2025-03-06 14:42:35', '2025-03-06 15:24:35', 585.00, 'termine', NULL, 1, '2025-03-05 00:00:00', NULL),
(177, 177, 67, 25, '2024-11-21 04:22:29', '2024-11-21 07:22:29', '2024-11-21 07:38:29', 15.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(178, 178, 9, 26, '2025-05-03 11:49:14', '2025-05-03 16:49:14', '2025-05-03 16:17:14', 110.00, 'termine', NULL, 1, '2025-05-02 00:00:00', NULL),
(179, 179, 10, 27, '2025-04-24 17:08:39', '2025-04-24 19:08:39', '2025-04-24 20:01:39', 5.00, 'termine', NULL, 1, '2025-04-18 00:00:00', NULL),
(180, 180, 11, 28, '2025-02-12 20:03:58', '2025-02-13 08:03:58', '2025-02-13 07:26:58', 458.00, 'termine', NULL, 1, '2025-02-09 00:00:00', NULL),
(181, 181, 12, 29, '2025-03-23 08:24:06', '2025-03-24 00:24:06', '2025-03-24 01:58:06', 766.00, 'termine', NULL, 1, '2025-03-23 00:00:00', NULL),
(182, 182, 13, 30, '2025-05-06 03:29:47', '2025-05-06 12:29:47', '2025-05-06 12:08:47', 281.00, 'termine', NULL, 1, '2025-05-01 00:00:00', NULL),
(183, 183, 14, 17, '2025-04-17 11:38:44', '2025-04-18 00:38:44', '2025-04-18 02:19:44', 529.00, 'termine', NULL, 1, '2025-04-15 00:00:00', NULL),
(184, 184, 15, 18, '2024-11-23 19:16:02', '2024-11-24 03:16:02', '2024-11-24 02:35:02', 245.00, 'termine', NULL, 1, '2024-11-18 00:00:00', NULL),
(185, 185, 16, 19, '2024-12-07 22:51:36', '2024-12-08 09:51:36', '2024-12-08 11:04:36', 540.00, 'termine', NULL, 1, '2024-12-04 00:00:00', NULL),
(186, 186, 17, 20, '2025-02-08 21:42:11', '2025-02-09 11:42:11', '2025-02-09 10:50:11', 635.00, 'termine', NULL, 1, '2025-02-08 00:00:00', NULL),
(187, 187, 18, 21, '2025-04-24 15:20:01', '2025-04-24 23:20:01', '2025-04-24 22:40:01', 311.00, 'termine', NULL, 1, '2025-04-20 00:00:00', NULL),
(188, 188, 19, 22, '2025-03-11 20:26:15', '2025-03-12 02:26:15', '2025-03-12 02:07:15', 247.00, 'termine', NULL, 1, '2025-03-10 00:00:00', NULL),
(189, 189, 20, 23, '2024-12-08 23:32:10', '2024-12-09 15:32:10', '2024-12-09 15:36:10', 761.00, 'termine', NULL, 1, '2024-12-02 00:00:00', NULL),
(190, 190, 21, 24, '2025-05-13 16:16:51', '2025-05-14 08:16:51', '2025-05-14 10:10:51', 681.00, 'termine', NULL, 1, '2025-05-11 00:00:00', NULL),
(191, 191, 22, 25, '2025-01-26 15:45:21', '2025-01-27 04:45:21', '2025-01-27 04:40:21', 672.00, 'termine', NULL, 1, '2025-01-26 00:00:00', NULL),
(192, 192, 23, 26, '2025-05-13 10:38:04', '2025-05-13 19:38:04', '2025-05-13 20:32:04', 337.00, 'termine', NULL, 1, '2025-05-13 00:00:00', NULL),
(193, 193, 24, 27, '2025-02-27 02:37:15', '2025-02-27 15:37:15', '2025-02-27 15:12:15', 701.00, 'termine', NULL, 1, '2025-02-22 00:00:00', NULL),
(194, 194, 25, 28, '2025-03-27 11:05:03', '2025-03-28 04:05:03', '2025-03-28 05:48:03', 761.00, 'termine', NULL, 1, '2025-03-27 00:00:00', NULL),
(195, 195, 26, 29, '2024-11-24 01:54:41', '2024-11-24 15:54:41', '2024-11-24 16:07:41', 611.00, 'termine', NULL, 1, '2024-11-22 00:00:00', NULL),
(196, 196, 27, 30, '2025-05-06 23:35:25', '2025-05-07 02:35:25', '2025-05-07 04:08:25', 51.00, 'termine', NULL, 1, '2025-05-06 00:00:00', NULL),
(197, 197, 28, 17, '2025-03-28 06:48:11', '2025-03-28 22:48:11', '2025-03-29 00:27:11', 764.00, 'termine', NULL, 1, '2025-03-27 00:00:00', NULL),
(198, 198, 29, 18, '2025-01-05 16:18:08', '2025-01-06 02:18:08', '2025-01-06 03:03:08', 442.00, 'termine', NULL, 1, '2025-01-05 00:00:00', NULL),
(199, 199, 30, 19, '2024-12-25 19:22:33', '2024-12-26 12:22:33', '2024-12-26 12:24:33', 798.00, 'termine', NULL, 1, '2024-12-24 00:00:00', NULL),
(200, 200, 31, 20, '2024-11-26 12:04:46', '2024-11-26 15:04:46', '2024-11-26 16:28:46', 64.00, 'termine', NULL, 1, '2024-11-25 00:00:00', NULL),
(201, 201, 32, 21, '2025-04-17 01:00:52', '2025-04-17 14:00:52', '2025-04-17 15:16:52', 532.00, 'termine', NULL, 1, '2025-04-14 00:00:00', NULL),
(202, 202, 33, 22, '2025-02-16 02:37:03', '2025-02-16 10:37:03', '2025-02-16 12:16:03', 237.00, 'termine', NULL, 1, '2025-02-14 00:00:00', NULL),
(203, 203, 34, 23, '2025-01-21 18:28:56', '2025-01-21 23:28:56', '2025-01-21 23:10:56', 213.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(204, 204, 35, 24, '2025-01-09 05:19:57', '2025-01-09 19:19:57', '2025-01-09 21:00:57', 589.00, 'termine', NULL, 1, '2025-01-06 00:00:00', NULL),
(205, 205, 36, 25, '2025-04-11 03:08:53', '2025-04-11 16:08:53', '2025-04-11 15:36:53', 629.00, 'termine', NULL, 1, '2025-04-10 00:00:00', NULL),
(206, 206, 37, 26, '2025-04-22 16:05:28', '2025-04-22 21:05:28', '2025-04-22 20:37:28', 11.00, 'termine', NULL, 1, '2025-04-19 00:00:00', NULL),
(207, 207, 38, 27, '2025-02-27 10:53:00', '2025-02-27 23:53:00', '2025-02-27 23:36:00', 601.00, 'termine', NULL, 1, '2025-02-27 00:00:00', NULL),
(208, 208, 39, 28, '2025-02-08 14:51:04', '2025-02-08 21:51:04', '2025-02-08 21:54:04', 206.00, 'termine', NULL, 1, '2025-02-03 00:00:00', NULL),
(209, 209, 40, 29, '2025-01-26 21:29:59', '2025-01-27 08:29:59', '2025-01-27 09:44:59', 427.00, 'termine', NULL, 1, '2025-01-24 00:00:00', NULL),
(210, 210, 41, 30, '2025-02-04 12:28:27', '2025-02-04 17:28:27', '2025-02-04 17:48:27', 163.00, 'termine', NULL, 1, '2025-02-03 00:00:00', NULL),
(211, 211, 42, 17, '2024-12-18 04:33:03', '2024-12-18 14:33:03', '2024-12-18 15:24:03', 308.00, 'termine', NULL, 1, '2024-12-18 00:00:00', NULL),
(212, 212, 43, 18, '2025-03-24 05:57:15', '2025-03-24 19:57:15', '2025-03-24 21:30:15', 594.00, 'termine', NULL, 1, '2025-03-23 00:00:00', NULL),
(213, 213, 44, 19, '2025-02-12 06:27:40', '2025-02-12 23:27:40', '2025-02-13 00:40:40', 746.00, 'termine', NULL, 1, '2025-02-11 00:00:00', NULL),
(214, 214, 45, 20, '2025-04-01 08:27:49', '2025-04-01 14:27:49', '2025-04-01 15:07:49', 87.00, 'termine', NULL, 1, '2025-03-31 00:00:00', NULL),
(215, 215, 46, 21, '2024-12-13 12:43:06', '2024-12-13 14:43:06', '2024-12-13 16:14:06', 57.00, 'termine', NULL, 1, '2024-12-13 00:00:00', NULL),
(216, 216, 47, 22, '2025-03-17 06:54:58', '2025-03-17 14:54:58', '2025-03-17 14:26:58', 405.00, 'termine', NULL, 1, '2025-03-13 00:00:00', NULL),
(217, 217, 48, 23, '2024-12-08 08:58:45', '2024-12-08 13:58:45', '2024-12-08 15:56:45', 157.00, 'termine', NULL, 1, '2024-12-06 00:00:00', NULL),
(218, 218, 49, 24, '2025-01-17 21:44:35', '2025-01-18 00:44:35', '2025-01-18 01:50:35', 49.00, 'termine', NULL, 1, '2025-01-17 00:00:00', NULL),
(219, 219, 50, 25, '2025-01-10 13:34:55', '2025-01-10 20:34:55', '2025-01-10 22:16:55', 128.00, 'termine', NULL, 1, '2025-01-09 00:00:00', NULL),
(220, 220, 51, 26, '2025-04-26 04:28:04', '2025-04-26 17:28:04', '2025-04-26 18:55:04', 560.00, 'termine', NULL, 1, '2025-04-25 00:00:00', NULL),
(221, 221, 52, 27, '2025-04-29 19:15:08', '2025-04-30 03:15:08', '2025-04-30 02:29:08', 317.00, 'termine', NULL, 1, '2025-04-25 00:00:00', NULL),
(222, 222, 53, 28, '2024-11-18 16:24:51', '2024-11-18 23:24:51', '2024-11-19 00:39:51', 311.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(223, 223, 54, 29, '2025-01-18 04:54:38', '2025-01-18 17:54:38', '2025-01-18 18:19:38', 485.00, 'termine', NULL, 1, '2025-01-15 00:00:00', NULL),
(224, 224, 55, 30, '2025-05-08 22:08:20', '2025-05-09 07:08:20', '2025-05-09 08:50:20', 448.00, 'termine', NULL, 1, '2025-05-08 00:00:00', NULL),
(225, 225, 56, 17, '2025-01-11 06:53:08', '2025-01-11 15:53:08', '2025-01-11 14:54:08', 447.00, 'termine', NULL, 1, '2025-01-10 00:00:00', NULL),
(226, 226, 57, 18, '2025-01-19 14:43:00', '2025-01-19 19:43:00', '2025-01-19 19:26:00', 9.00, 'termine', NULL, 1, '2025-01-17 00:00:00', NULL),
(227, 227, 58, 19, '2025-03-10 13:06:43', '2025-03-10 21:06:43', '2025-03-10 21:15:43', 193.00, 'termine', NULL, 1, '2025-03-10 00:00:00', NULL),
(228, 228, 59, 20, '2025-01-13 09:21:50', '2025-01-13 14:21:50', '2025-01-13 14:45:50', 228.00, 'termine', NULL, 1, '2025-01-11 00:00:00', NULL),
(229, 229, 60, 21, '2025-03-16 22:50:09', '2025-03-17 03:50:09', '2025-03-17 04:49:09', 183.00, 'termine', NULL, 1, '2025-03-13 00:00:00', NULL),
(230, 230, 61, 22, '2024-11-21 00:48:34', '2024-11-21 07:48:34', '2024-11-21 07:59:34', 238.00, 'termine', NULL, 1, '2024-11-18 00:00:00', NULL),
(231, 231, 62, 23, '2025-04-21 20:53:42', '2025-04-22 11:53:42', '2025-04-22 12:25:42', 795.00, 'termine', NULL, 1, '2025-04-20 00:00:00', NULL),
(232, 232, 63, 24, '2024-11-19 13:55:59', '2024-11-20 00:55:59', '2024-11-20 00:24:59', 496.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(233, 233, 64, 25, '2025-04-28 17:47:40', '2025-04-29 03:47:40', '2025-04-29 05:24:40', 517.00, 'termine', NULL, 1, '2025-04-26 00:00:00', NULL),
(234, 234, 65, 26, '2025-03-15 07:27:28', '2025-03-15 15:27:28', '2025-03-15 16:24:28', 329.00, 'termine', NULL, 1, '2025-03-14 00:00:00', NULL),
(235, 235, 66, 27, '2025-05-21 00:52:51', '2025-05-21 06:52:51', '2025-05-21 07:15:51', 291.00, 'termine', NULL, 1, '2025-05-19 00:00:00', NULL),
(236, 236, 67, 28, '2025-02-18 05:49:50', '2025-02-18 14:49:50', '2025-02-18 16:20:50', 267.00, 'termine', NULL, 1, '2025-02-15 00:00:00', NULL),
(237, 237, 9, 29, '2024-12-06 13:33:34', '2024-12-06 23:33:34', '2024-12-07 00:48:34', 476.00, 'termine', NULL, 1, '2024-12-04 00:00:00', NULL),
(238, 238, 10, 30, '2025-03-21 18:27:27', '2025-03-21 22:27:27', '2025-03-21 23:34:27', 158.00, 'termine', NULL, 1, '2025-03-21 00:00:00', NULL),
(239, 239, 11, 17, '2025-04-24 02:00:57', '2025-04-24 18:00:57', '2025-04-24 19:47:57', 716.00, 'termine', NULL, 1, '2025-04-24 00:00:00', NULL),
(240, 240, 12, 18, '2025-02-08 23:29:36', '2025-02-09 07:29:36', '2025-02-09 07:55:36', 376.00, 'termine', NULL, 1, '2025-02-08 00:00:00', NULL),
(241, 241, 13, 19, '2025-03-27 22:38:33', '2025-03-28 08:38:33', '2025-03-28 09:02:33', 526.00, 'termine', NULL, 1, '2025-03-27 00:00:00', NULL),
(242, 242, 14, 20, '2024-11-19 10:29:16', '2024-11-20 01:29:16', '2024-11-20 01:07:16', 646.00, 'termine', NULL, 1, '2024-11-18 00:00:00', NULL),
(243, 243, 15, 21, '2025-03-20 03:08:29', '2025-03-20 20:08:29', '2025-03-20 20:35:29', 790.00, 'termine', NULL, 1, '2025-03-17 00:00:00', NULL),
(244, 244, 16, 22, '2024-11-28 11:21:58', '2024-11-29 04:21:58', '2024-11-29 06:19:58', 790.00, 'termine', NULL, 1, '2024-11-28 00:00:00', NULL),
(245, 245, 17, 23, '2025-02-08 02:31:27', '2025-02-08 06:31:27', '2025-02-08 06:14:27', 92.00, 'termine', NULL, 1, '2025-02-08 00:00:00', NULL),
(246, 246, 18, 24, '2025-04-26 15:24:43', '2025-04-27 06:24:43', '2025-04-27 06:33:43', 797.00, 'termine', NULL, 1, '2025-04-24 00:00:00', NULL),
(247, 247, 19, 25, '2025-05-07 07:20:29', '2025-05-07 10:20:29', '2025-05-07 11:20:29', 79.00, 'termine', NULL, 1, '2025-05-07 00:00:00', NULL),
(248, 248, 20, 26, '2025-03-20 18:49:39', '2025-03-21 09:49:39', '2025-03-21 11:09:39', 628.00, 'termine', NULL, 1, '2025-03-20 00:00:00', NULL),
(249, 249, 21, 27, '2024-11-19 17:48:36', '2024-11-20 04:48:36', '2024-11-20 05:54:36', 473.00, 'termine', NULL, 1, '2024-11-16 00:00:00', NULL),
(250, 250, 22, 28, '2025-02-02 05:51:31', '2025-02-02 14:51:31', '2025-02-02 14:34:31', 409.00, 'termine', NULL, 1, '2025-01-29 00:00:00', NULL),
(251, 251, 23, 29, '2025-03-20 19:40:33', '2025-03-21 07:40:33', '2025-03-21 08:26:33', 421.00, 'termine', NULL, 1, '2025-03-20 00:00:00', NULL),
(252, 252, 24, 30, '2024-12-07 02:08:07', '2024-12-07 12:08:07', '2024-12-07 13:18:07', 501.00, 'termine', NULL, 1, '2024-12-07 00:00:00', NULL),
(253, 253, 25, 17, '2025-04-01 04:37:50', '2025-04-01 15:37:50', '2025-04-01 17:13:50', 400.00, 'termine', NULL, 1, '2025-04-01 00:00:00', NULL),
(254, 254, 26, 18, '2025-02-21 08:00:08', '2025-02-21 12:00:08', '2025-02-21 12:32:08', 145.00, 'termine', NULL, 1, '2025-02-21 00:00:00', NULL),
(255, 255, 27, 19, '2025-05-28 06:07:10', '2025-05-28 12:07:10', '2025-05-28 13:38:10', 89.00, 'termine', NULL, 1, '2025-05-28 00:00:00', NULL),
(256, 256, 28, 20, '2025-04-10 19:07:25', '2025-04-11 03:07:25', '2025-04-11 04:39:25', 265.00, 'termine', NULL, 1, '2025-04-04 00:00:00', NULL),
(257, 257, 29, 21, '2025-05-14 08:51:26', '2025-05-14 17:51:26', '2025-05-14 19:33:26', 291.00, 'termine', NULL, 1, '2025-05-13 00:00:00', NULL),
(258, 258, 30, 22, '2024-12-10 02:06:49', '2024-12-10 10:06:49', '2024-12-10 11:33:49', 235.00, 'termine', NULL, 1, '2024-12-09 00:00:00', NULL),
(259, 259, 31, 23, '2025-01-25 12:24:01', '2025-01-26 03:24:01', '2025-01-26 04:07:01', 679.00, 'termine', NULL, 1, '2025-01-21 00:00:00', NULL),
(260, 260, 32, 24, '2025-02-20 10:30:11', '2025-02-21 02:30:11', '2025-02-21 04:15:11', 782.00, 'termine', NULL, 1, '2025-02-19 00:00:00', NULL),
(261, 261, 33, 25, '2024-11-19 20:14:11', '2024-11-20 04:14:11', '2024-11-20 03:28:11', 353.00, 'termine', NULL, 1, '2024-11-16 00:00:00', NULL),
(262, 262, 34, 26, '2025-01-24 00:07:15', '2025-01-24 06:07:15', '2025-01-24 05:41:15', 73.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(263, 263, 35, 27, '2025-02-19 20:15:59', '2025-02-20 10:15:59', '2025-02-20 11:43:59', 778.00, 'termine', NULL, 1, '2025-02-18 00:00:00', NULL),
(264, 264, 36, 28, '2024-12-23 16:50:36', '2024-12-23 23:50:36', '2024-12-23 23:50:36', 274.00, 'termine', NULL, 1, '2024-12-21 00:00:00', NULL),
(265, 265, 37, 29, '2025-04-27 21:28:18', '2025-04-28 09:28:18', '2025-04-28 09:11:18', 428.00, 'termine', NULL, 1, '2025-04-27 00:00:00', NULL),
(266, 266, 38, 30, '2025-03-26 08:37:06', '2025-03-26 19:37:06', '2025-03-26 19:20:06', 431.00, 'termine', NULL, 1, '2025-03-26 00:00:00', NULL),
(267, 267, 39, 17, '2025-01-05 20:14:08', '2025-01-06 09:14:08', '2025-01-06 10:57:08', 598.00, 'termine', NULL, 1, '2025-01-04 00:00:00', NULL),
(268, 268, 40, 18, '2025-02-09 06:44:57', '2025-02-09 09:44:57', '2025-02-09 09:00:57', 16.00, 'termine', NULL, 1, '2025-02-08 00:00:00', NULL),
(269, 269, 41, 19, '2025-05-02 20:51:28', '2025-05-03 06:51:28', '2025-05-03 08:31:28', 330.00, 'termine', NULL, 1, '2025-05-02 00:00:00', NULL),
(270, 270, 42, 20, '2025-04-24 11:36:01', '2025-04-24 19:36:01', '2025-04-24 19:25:01', 359.00, 'termine', NULL, 1, '2025-04-23 00:00:00', NULL),
(271, 271, 43, 21, '2025-03-01 19:30:43', '2025-03-02 09:30:43', '2025-03-02 09:17:43', 666.00, 'termine', NULL, 1, '2025-03-01 00:00:00', NULL),
(272, 272, 44, 22, '2025-04-04 18:33:44', '2025-04-05 04:33:44', '2025-04-05 04:25:44', 360.00, 'termine', NULL, 1, '2025-04-03 00:00:00', NULL),
(273, 273, 45, 23, '2025-06-02 05:43:05', '2025-06-02 22:43:05', '2025-06-02 21:44:05', 788.00, 'termine', NULL, 1, '2025-06-02 00:00:00', NULL),
(274, 274, 46, 24, '2025-01-24 01:05:25', '2025-01-24 09:05:25', '2025-01-24 08:08:25', 283.00, 'termine', NULL, 1, '2025-01-22 00:00:00', NULL),
(275, 275, 47, 25, '2025-05-04 00:35:50', '2025-05-04 13:35:50', '2025-05-04 15:00:50', 557.00, 'termine', NULL, 1, '2025-05-01 00:00:00', NULL),
(276, 276, 48, 26, '2024-11-20 17:14:45', '2024-11-21 01:14:45', '2024-11-21 01:52:45', 184.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(277, 277, 49, 27, '2025-01-12 14:37:38', '2025-01-13 02:37:38', '2025-01-13 02:50:38', 480.00, 'termine', NULL, 1, '2025-01-09 00:00:00', NULL),
(278, 278, 50, 28, '2024-12-20 06:46:16', '2024-12-20 22:46:16', '2024-12-20 23:20:16', 678.00, 'termine', NULL, 1, '2024-12-20 00:00:00', NULL),
(279, 279, 51, 29, '2025-02-05 04:56:07', '2025-02-05 10:56:07', '2025-02-05 10:13:07', 257.00, 'termine', NULL, 1, '2025-01-31 00:00:00', NULL),
(280, 280, 52, 30, '2024-12-27 01:16:34', '2024-12-27 06:16:34', '2024-12-27 05:32:34', 190.00, 'termine', NULL, 1, '2024-12-27 00:00:00', NULL),
(281, 281, 53, 17, '2025-02-06 10:48:10', '2025-02-06 16:48:10', '2025-02-06 16:38:10', 215.00, 'termine', NULL, 1, '2025-02-06 00:00:00', NULL),
(282, 282, 54, 18, '2025-04-27 02:54:15', '2025-04-27 19:54:15', '2025-04-27 21:30:15', 731.00, 'termine', NULL, 1, '2025-04-27 00:00:00', NULL),
(283, 283, 55, 19, '2024-11-20 01:18:23', '2024-11-20 15:18:23', '2024-11-20 16:59:23', 609.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(284, 284, 56, 20, '2024-12-04 12:54:06', '2024-12-04 15:54:06', '2024-12-04 15:29:06', 71.00, 'termine', NULL, 1, '2024-11-30 00:00:00', NULL),
(285, 285, 57, 21, '2025-05-27 17:00:58', '2025-05-28 01:00:58', '2025-05-28 00:09:58', 237.00, 'termine', NULL, 1, '2025-05-27 00:00:00', NULL),
(286, 286, 58, 22, '2025-04-08 02:04:18', '2025-04-08 07:04:18', '2025-04-08 08:27:18', 147.00, 'termine', NULL, 1, '2025-04-06 00:00:00', NULL),
(287, 287, 59, 23, '2025-03-27 10:35:41', '2025-03-28 01:35:41', '2025-03-28 03:26:41', 761.00, 'termine', NULL, 1, '2025-03-24 00:00:00', NULL),
(288, 288, 60, 24, '2025-01-28 19:21:43', '2025-01-29 10:21:43', '2025-01-29 11:34:43', 770.00, 'termine', NULL, 1, '2025-01-27 00:00:00', NULL),
(289, 289, 61, 25, '2025-05-20 00:21:57', '2025-05-20 07:21:57', '2025-05-20 08:44:57', 238.00, 'termine', NULL, 1, '2025-05-18 00:00:00', NULL),
(290, 290, 62, 26, '2024-11-17 22:04:04', '2024-11-18 13:04:04', '2024-11-18 13:21:04', 775.00, 'termine', NULL, 1, '2024-11-16 00:00:00', NULL),
(291, 291, 63, 27, '2024-11-24 01:52:03', '2024-11-24 09:52:03', '2024-11-24 10:10:03', 364.00, 'termine', NULL, 1, '2024-11-24 00:00:00', NULL),
(292, 292, 64, 28, '2025-01-06 09:46:24', '2025-01-06 14:46:24', '2025-01-06 14:22:24', 53.00, 'termine', NULL, 1, '2025-01-05 00:00:00', NULL),
(293, 293, 65, 29, '2025-02-15 23:32:40', '2025-02-16 16:32:40', '2025-02-16 17:27:40', 721.00, 'termine', NULL, 1, '2025-02-12 00:00:00', NULL),
(294, 294, 66, 30, '2025-02-11 09:12:23', '2025-02-11 22:12:23', '2025-02-11 22:19:23', 572.00, 'termine', NULL, 1, '2025-02-10 00:00:00', NULL),
(295, 295, 67, 17, '2025-03-01 03:43:36', '2025-03-01 08:43:36', '2025-03-01 10:28:36', 196.00, 'termine', NULL, 1, '2025-02-27 00:00:00', NULL),
(296, 296, 9, 18, '2024-12-24 22:20:31', '2024-12-25 13:20:31', '2024-12-25 13:56:31', 607.00, 'termine', NULL, 1, '2024-12-19 00:00:00', NULL),
(297, 297, 10, 19, '2024-12-08 16:19:11', '2024-12-09 04:19:11', '2024-12-09 03:40:11', 462.00, 'termine', NULL, 1, '2024-12-08 00:00:00', NULL),
(298, 298, 11, 20, '2025-03-11 11:48:42', '2025-03-11 19:48:42', '2025-03-11 20:51:42', 284.00, 'termine', NULL, 1, '2025-03-09 00:00:00', NULL),
(299, 299, 12, 21, '2024-12-18 09:48:56', '2024-12-18 19:48:56', '2024-12-18 20:36:56', 370.00, 'termine', NULL, 1, '2024-12-18 00:00:00', NULL),
(300, 300, 13, 22, '2025-01-09 00:50:22', '2025-01-09 08:50:22', '2025-01-09 09:53:22', 211.00, 'termine', NULL, 1, '2025-01-06 00:00:00', NULL),
(301, 301, 14, 23, '2025-03-14 00:03:56', '2025-03-14 03:03:56', '2025-03-14 03:45:56', 103.00, 'termine', NULL, 1, '2025-03-11 00:00:00', NULL),
(302, 302, 15, 24, '2025-06-05 04:59:39', '2025-06-05 17:59:39', '2025-06-05 19:53:39', 593.00, 'termine', NULL, 1, '2025-06-04 00:00:00', NULL),
(303, 303, 16, 25, '2025-04-15 02:40:13', '2025-04-15 07:40:13', '2025-04-15 09:40:13', 160.00, 'termine', NULL, 1, '2025-04-14 00:00:00', NULL),
(304, 304, 17, 26, '2025-05-01 09:25:40', '2025-05-01 21:25:40', '2025-05-01 23:09:40', 628.00, 'termine', NULL, 1, '2025-04-28 00:00:00', NULL),
(305, 305, 18, 27, '2025-05-12 00:03:00', '2025-05-12 08:03:00', '2025-05-12 08:12:00', 194.00, 'termine', NULL, 1, '2025-05-11 00:00:00', NULL),
(306, 306, 19, 28, '2025-03-26 01:12:15', '2025-03-26 05:12:15', '2025-03-26 04:36:15', 132.00, 'termine', NULL, 1, '2025-03-23 00:00:00', NULL),
(307, 307, 20, 29, '2025-03-09 21:41:49', '2025-03-10 06:41:49', '2025-03-10 07:15:49', 417.00, 'termine', NULL, 1, '2025-03-06 00:00:00', NULL),
(308, 308, 21, 30, '2025-01-18 07:56:19', '2025-01-18 10:56:19', '2025-01-18 12:45:19', 39.00, 'termine', NULL, 1, '2025-01-14 00:00:00', NULL),
(309, 309, 22, 17, '2025-02-03 06:30:10', '2025-02-03 21:30:10', '2025-02-03 22:28:10', 662.00, 'termine', NULL, 1, '2025-02-03 00:00:00', NULL),
(310, 310, 23, 18, '2025-01-22 14:09:49', '2025-01-23 05:09:49', '2025-01-23 06:51:49', 700.00, 'termine', NULL, 1, '2025-01-22 00:00:00', NULL),
(311, 311, 24, 19, '2025-04-19 19:10:39', '2025-04-20 09:10:39', '2025-04-20 10:43:39', 542.00, 'termine', NULL, 1, '2025-04-19 00:00:00', NULL),
(312, 312, 25, 20, '2024-12-13 12:12:45', '2024-12-13 20:12:45', '2024-12-13 19:38:45', 368.00, 'termine', NULL, 1, '2024-12-13 00:00:00', NULL),
(313, 313, 26, 21, '2025-04-01 11:03:27', '2025-04-01 23:03:27', '2025-04-01 22:27:27', 448.00, 'termine', NULL, 1, '2025-04-01 00:00:00', NULL),
(314, 314, 27, 22, '2025-01-05 19:55:25', '2025-01-06 01:55:25', '2025-01-06 02:41:25', 154.00, 'termine', NULL, 1, '2025-01-05 00:00:00', NULL),
(315, 315, 28, 23, '2025-03-14 12:53:34', '2025-03-14 23:53:34', '2025-03-15 01:09:34', 522.00, 'termine', NULL, 1, '2025-03-14 00:00:00', NULL),
(316, 316, 29, 24, '2024-12-28 05:28:39', '2024-12-28 17:28:39', '2024-12-28 18:20:39', 652.00, 'termine', NULL, 1, '2024-12-28 00:00:00', NULL),
(317, 317, 30, 25, '2025-02-21 17:32:55', '2025-02-22 00:32:55', '2025-02-22 00:53:55', 210.00, 'termine', NULL, 1, '2025-02-17 00:00:00', NULL),
(318, 318, 31, 26, '2024-12-13 00:47:40', '2024-12-13 16:47:40', '2024-12-13 17:34:40', 759.00, 'termine', NULL, 1, '2024-12-08 00:00:00', NULL),
(319, 319, 32, 27, '2025-03-17 02:56:49', '2025-03-17 14:56:49', '2025-03-17 15:02:49', 590.00, 'termine', NULL, 1, '2025-03-17 00:00:00', NULL),
(320, 320, 33, 28, '2025-04-16 19:34:10', '2025-04-17 02:34:10', '2025-04-17 02:57:10', 269.00, 'termine', NULL, 1, '2025-04-15 00:00:00', NULL),
(321, 321, 34, 29, '2025-01-14 23:49:31', '2025-01-15 15:49:31', '2025-01-15 17:28:31', 713.00, 'termine', NULL, 1, '2025-01-13 00:00:00', NULL),
(322, 322, 35, 30, '2025-02-23 03:45:34', '2025-02-23 20:45:34', '2025-02-23 19:51:34', 741.00, 'termine', NULL, 1, '2025-02-23 00:00:00', NULL),
(323, 323, 36, 17, '2025-02-13 03:22:37', '2025-02-13 18:22:37', '2025-02-13 19:35:37', 773.00, 'termine', NULL, 1, '2025-02-13 00:00:00', NULL),
(324, 324, 37, 18, '2024-11-19 10:52:36', '2024-11-20 00:52:36', '2024-11-20 02:07:36', 639.00, 'termine', NULL, 1, '2024-11-17 00:00:00', NULL),
(325, 325, 38, 19, '2024-12-14 18:40:57', '2024-12-15 03:40:57', '2024-12-15 03:57:57', 478.00, 'termine', NULL, 1, '2024-12-13 00:00:00', NULL),
(326, 326, 39, 20, '2025-06-07 12:32:06', '2025-06-07 21:32:06', '2025-06-07 21:47:06', 374.00, 'termine', NULL, 1, '2025-06-03 00:00:00', NULL),
(327, 327, 40, 21, '2024-11-18 10:27:17', '2024-11-18 23:27:17', '2024-11-18 22:50:17', 634.00, 'termine', NULL, 1, '2024-11-18 00:00:00', NULL),
(328, 328, 41, 22, '2025-01-26 20:00:19', '2025-01-27 08:00:19', '2025-01-27 07:52:19', 608.00, 'termine', NULL, 1, '2025-01-26 00:00:00', NULL),
(329, 329, 42, 23, '2025-03-02 01:07:34', '2025-03-02 15:07:34', '2025-03-02 15:01:34', 670.00, 'termine', NULL, 1, '2025-02-28 00:00:00', NULL),
(330, 330, 43, 24, '2025-01-15 17:45:38', '2025-01-15 22:45:38', '2025-01-15 23:41:38', 79.00, 'termine', NULL, 1, '2025-01-13 00:00:00', NULL),
(331, 331, 44, 25, '2024-12-02 12:06:04', '2024-12-02 22:06:04', '2024-12-02 21:37:04', 367.00, 'termine', NULL, 1, '2024-12-02 00:00:00', NULL),
(332, 332, 45, 26, '2024-12-28 06:55:17', '2024-12-28 20:55:17', '2024-12-28 19:59:17', 578.00, 'termine', NULL, 1, '2024-12-28 00:00:00', NULL),
(333, 333, 46, 27, '2024-12-13 04:05:49', '2024-12-13 13:05:49', '2024-12-13 13:03:49', 423.00, 'termine', NULL, 1, '2024-12-09 00:00:00', NULL),
(334, 334, 47, 28, '2025-03-10 04:07:40', '2025-03-10 17:07:40', '2025-03-10 16:53:40', 618.00, 'termine', NULL, 1, '2025-03-07 00:00:00', NULL),
(335, 335, 48, 29, '2025-03-21 05:09:02', '2025-03-21 21:09:02', '2025-03-21 20:38:02', 665.00, 'termine', NULL, 1, '2025-03-21 00:00:00', NULL),
(336, 336, 49, 30, '2024-12-14 03:16:25', '2024-12-14 11:16:25', '2024-12-14 12:40:25', 420.00, 'termine', NULL, 1, '2024-12-14 00:00:00', NULL),
(337, 337, 50, 17, '2025-03-23 08:09:00', '2025-03-23 19:09:00', '2025-03-23 19:29:00', 537.00, 'termine', NULL, 1, '2025-03-23 00:00:00', NULL),
(338, 338, 51, 18, '2025-03-04 09:51:47', '2025-03-04 14:51:47', '2025-03-04 16:49:47', 83.00, 'termine', NULL, 1, '2025-03-04 00:00:00', NULL),
(339, 339, 52, 19, '2024-11-28 17:08:11', '2024-11-28 21:08:11', '2024-11-28 20:56:11', 128.00, 'termine', NULL, 1, '2024-11-27 00:00:00', NULL),
(340, 340, 53, 20, '2024-11-25 07:30:16', '2024-11-25 14:30:16', '2024-11-25 15:20:16', 142.00, 'termine', NULL, 1, '2024-11-24 00:00:00', NULL),
(341, 341, 54, 21, '2025-01-12 17:59:57', '2025-01-12 23:59:57', '2025-01-13 00:18:57', 149.00, 'termine', NULL, 1, '2025-01-12 00:00:00', NULL),
(342, 342, 55, 22, '2025-05-01 14:16:40', '2025-05-02 00:16:40', '2025-05-02 01:14:40', 519.00, 'termine', NULL, 1, '2025-05-01 00:00:00', NULL),
(343, 343, 56, 23, '2025-01-20 00:05:44', '2025-01-20 04:05:44', '2025-01-20 03:06:44', 118.00, 'termine', NULL, 1, '2025-01-20 00:00:00', NULL),
(344, 344, 57, 24, '2025-03-08 03:04:23', '2025-03-08 07:04:23', '2025-03-08 06:24:23', 175.00, 'termine', NULL, 1, '2025-03-08 00:00:00', NULL),
(345, 345, 58, 25, '2025-05-27 19:18:43', '2025-05-28 09:18:43', '2025-05-28 10:05:43', 599.00, 'termine', NULL, 1, '2025-05-27 00:00:00', NULL),
(346, 346, 59, 26, '2025-02-19 15:58:31', '2025-02-19 21:58:31', '2025-02-19 21:49:31', 176.00, 'termine', NULL, 1, '2025-02-16 00:00:00', NULL),
(347, 347, 60, 27, '2025-04-18 11:17:31', '2025-04-18 14:17:31', '2025-04-18 15:19:31', 37.00, 'termine', NULL, 1, '2025-04-16 00:00:00', NULL);
INSERT INTO `trajets` (`id`, `commande_id`, `vehicule_id`, `chauffeur_id`, `date_depart`, `date_arrivee_prevue`, `date_arrivee_reelle`, `distance_km`, `statut`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(348, 348, 61, 28, '2025-04-13 07:37:58', '2025-04-13 19:37:58', '2025-04-13 20:46:58', 579.00, 'termine', NULL, 1, '2025-04-13 00:00:00', NULL),
(349, 349, 62, 29, '2024-12-19 10:33:30', '2024-12-20 02:33:30', '2024-12-20 02:05:30', 671.00, 'termine', NULL, 1, '2024-12-18 00:00:00', NULL),
(350, 350, 63, 30, '2025-02-26 20:45:52', '2025-02-27 06:45:52', '2025-02-27 07:52:52', 499.00, 'termine', NULL, 1, '2025-02-26 00:00:00', NULL),
(351, 351, 64, 17, '2025-04-21 03:18:55', '2025-04-21 18:18:55', '2025-04-21 18:31:55', 800.00, 'termine', NULL, 1, '2025-04-17 00:00:00', NULL),
(352, 352, 65, 18, '2025-01-11 10:01:41', '2025-01-11 15:01:41', '2025-01-11 16:18:41', 144.00, 'termine', NULL, 1, '2025-01-10 00:00:00', NULL),
(353, 353, 66, 19, '2025-04-01 07:28:27', '2025-04-01 18:28:27', '2025-04-01 18:13:27', 381.00, 'termine', NULL, 1, '2025-04-01 00:00:00', NULL),
(354, 354, 67, 20, '2025-04-24 21:55:22', '2025-04-25 04:55:22', '2025-04-25 06:31:22', 131.00, 'termine', NULL, 1, '2025-04-23 00:00:00', NULL),
(355, 355, 9, 21, '2025-05-04 15:54:35', '2025-05-04 22:54:35', '2025-05-05 00:32:35', 279.00, 'termine', NULL, 1, '2025-05-04 00:00:00', NULL),
(356, 356, 10, 22, '2025-04-07 23:16:14', '2025-04-08 10:16:14', '2025-04-08 10:19:14', 570.00, 'termine', NULL, 1, '2025-04-04 00:00:00', NULL),
(357, 357, 11, 23, '2025-01-03 15:30:31', '2025-01-04 03:30:31', '2025-01-04 03:02:31', 526.00, 'termine', NULL, 1, '2024-12-30 00:00:00', NULL),
(358, 358, 12, 24, '2024-12-26 15:56:37', '2024-12-26 20:56:37', '2024-12-26 20:01:37', 171.00, 'termine', NULL, 1, '2024-12-26 00:00:00', NULL),
(359, 359, 13, 25, '2025-01-13 19:50:49', '2025-01-14 05:50:49', '2025-01-14 05:20:49', 451.00, 'termine', NULL, 1, '2025-01-13 00:00:00', NULL),
(360, 360, 14, 26, '2025-05-23 11:26:22', '2025-05-23 13:26:22', NULL, 54.00, 'en_cours', NULL, 1, '2025-01-01 00:00:00', NULL),
(361, 361, 15, 27, '2025-06-18 16:09:33', '2025-06-18 19:09:33', NULL, 61.00, 'en_cours', NULL, 1, '2025-01-04 00:00:00', NULL),
(362, 362, 16, 28, '2025-03-18 04:19:57', '2025-03-18 15:19:57', NULL, 541.00, 'en_cours', NULL, 1, '2024-11-18 00:00:00', NULL),
(363, 363, 17, 29, '2025-05-16 21:42:01', '2025-05-17 07:42:01', NULL, 301.00, 'en_cours', NULL, 1, '2025-02-20 00:00:00', NULL),
(364, 364, 18, 30, '2025-05-14 05:15:51', '2025-05-14 17:15:51', NULL, 532.00, 'en_cours', NULL, 1, '2024-12-02 00:00:00', NULL),
(365, 365, 19, 17, '2025-01-30 17:45:08', '2025-01-31 01:45:08', NULL, 385.00, 'en_cours', NULL, 1, '2025-01-29 00:00:00', NULL),
(366, 366, 20, 18, '2025-04-28 10:09:14', '2025-04-28 17:09:14', NULL, 301.00, 'en_cours', NULL, 1, '2024-12-04 00:00:00', NULL),
(367, 367, 21, 19, '2025-06-11 15:21:11', '2025-06-12 04:21:11', NULL, 686.00, 'en_cours', NULL, 1, '2025-05-20 00:00:00', NULL),
(368, 368, 22, 20, '2025-06-16 17:05:06', '2025-06-17 02:05:06', NULL, 298.00, 'en_cours', NULL, 1, '2025-06-01 00:00:00', NULL),
(369, 369, 23, 21, '2024-12-12 08:00:52', '2024-12-12 20:00:52', NULL, 542.00, 'en_cours', NULL, 1, '2024-12-02 00:00:00', NULL),
(370, 370, 24, 22, '2025-06-05 09:58:19', '2025-06-05 23:58:19', NULL, 601.00, 'en_cours', NULL, 1, '2025-04-22 00:00:00', NULL),
(371, 371, 25, 23, '2025-05-10 17:12:55', '2025-05-11 05:12:55', NULL, 470.00, 'en_cours', NULL, 1, '2025-04-09 00:00:00', NULL),
(372, 372, 26, 24, '2025-05-14 17:08:02', '2025-05-15 08:08:02', NULL, 725.00, 'en_cours', NULL, 1, '2025-05-11 00:00:00', NULL),
(373, 373, 27, 25, '2025-05-14 15:41:12', '2025-05-15 01:41:12', NULL, 387.00, 'en_cours', NULL, 1, '2025-03-13 00:00:00', NULL),
(374, 374, 28, 26, '2025-05-21 10:31:20', '2025-05-21 13:31:20', NULL, 68.00, 'en_cours', NULL, 1, '2025-01-13 00:00:00', NULL),
(375, 375, 29, 27, '2025-05-15 12:32:34', '2025-05-15 14:32:34', NULL, 32.00, 'en_cours', NULL, 1, '2025-04-28 00:00:00', NULL),
(376, 376, 30, 28, '2025-06-11 19:55:20', '2025-06-12 06:55:20', NULL, 485.00, 'en_cours', NULL, 1, '2025-04-26 00:00:00', NULL),
(377, 377, 31, 29, '2025-01-26 06:29:39', '2025-01-26 14:29:39', NULL, 258.00, 'en_cours', NULL, 1, '2024-12-03 00:00:00', NULL),
(378, 378, 32, 30, '2025-05-09 13:19:50', '2025-05-10 03:19:50', NULL, 780.00, 'en_cours', NULL, 1, '2025-01-12 00:00:00', NULL),
(379, 379, 33, 17, '2025-05-03 01:07:13', '2025-05-03 15:07:13', NULL, 626.00, 'en_cours', NULL, 1, '2024-11-20 00:00:00', NULL),
(380, 380, 34, 18, '2025-04-21 15:07:49', '2025-04-21 23:07:49', NULL, 276.00, 'en_cours', NULL, 1, '2025-01-07 00:00:00', NULL),
(381, 381, 35, 19, '2025-06-18 06:10:30', '2025-06-18 18:10:30', NULL, 635.00, 'en_cours', NULL, 1, '2025-05-28 00:00:00', NULL),
(382, 382, 36, 20, '2025-06-19 13:39:07', '2025-06-20 04:39:07', NULL, 732.00, 'en_cours', NULL, 1, '2025-05-18 00:00:00', NULL),
(383, 383, 37, 21, '2025-05-21 12:55:59', '2025-05-21 16:55:59', NULL, 37.00, 'en_cours', NULL, 1, '2025-04-18 00:00:00', NULL),
(384, 384, 38, 22, '2025-02-14 02:53:04', '2025-02-14 17:53:04', NULL, 635.00, 'en_cours', NULL, 1, '2025-01-02 00:00:00', NULL),
(385, 385, 39, 23, '2025-05-17 10:11:15', '2025-05-17 15:11:15', NULL, 182.00, 'en_cours', NULL, 1, '2025-05-15 00:00:00', NULL),
(386, 386, 40, 24, '2025-04-15 00:44:37', '2025-04-15 13:44:37', NULL, 693.00, 'en_cours', NULL, 1, '2024-11-20 00:00:00', NULL),
(387, 387, 41, 25, '2025-03-29 06:47:23', '2025-03-29 18:47:23', NULL, 477.00, 'en_cours', NULL, 1, '2025-01-19 00:00:00', NULL),
(388, 388, 42, 26, '2025-02-20 15:05:53', '2025-02-20 23:05:53', NULL, 328.00, 'en_cours', NULL, 1, '2024-11-17 00:00:00', NULL),
(389, 389, 43, 27, '2025-03-25 08:27:23', '2025-03-25 15:27:23', NULL, 146.00, 'en_cours', NULL, 1, '2025-02-04 00:00:00', NULL),
(390, 390, 44, 28, '2025-02-14 18:41:31', '2025-02-15 01:41:31', NULL, 237.00, 'en_cours', NULL, 1, '2025-01-02 00:00:00', NULL),
(391, 391, 45, 29, '2025-02-23 08:02:20', '2025-02-23 20:02:20', NULL, 459.00, 'en_cours', NULL, 1, '2025-02-05 00:00:00', NULL),
(392, 392, 46, 30, '2025-06-01 08:55:12', '2025-06-01 19:55:12', NULL, 436.00, 'en_cours', NULL, 1, '2025-05-17 00:00:00', NULL),
(393, 393, 47, 17, '2025-03-15 05:30:44', '2025-03-15 14:30:44', NULL, 401.00, 'en_cours', NULL, 1, '2025-01-12 00:00:00', NULL),
(394, 394, 48, 18, '2025-06-04 18:06:26', '2025-06-05 10:06:26', NULL, 718.00, 'en_cours', NULL, 1, '2025-02-18 00:00:00', NULL),
(395, 395, 49, 19, '2025-03-27 21:26:28', '2025-03-28 06:26:28', NULL, 270.00, 'en_cours', NULL, 1, '2025-03-15 00:00:00', NULL),
(396, 396, 50, 20, '2025-04-21 09:04:07', '2025-04-21 21:04:07', NULL, 555.00, 'en_cours', NULL, 1, '2025-02-28 00:00:00', NULL),
(397, 397, 51, 21, '2025-04-24 08:22:53', '2025-04-24 12:22:53', NULL, 110.00, 'en_cours', NULL, 1, '2025-03-13 00:00:00', NULL),
(398, 398, 52, 22, '2024-12-16 12:43:28', '2024-12-16 17:43:28', NULL, 17.00, 'en_cours', NULL, 1, '2024-11-23 00:00:00', NULL),
(399, 399, 53, 23, '2025-06-15 00:09:44', '2025-06-15 05:09:44', NULL, 150.00, 'en_cours', NULL, 1, '2025-05-02 00:00:00', NULL),
(400, 400, 54, 24, '2025-04-29 00:31:07', '2025-04-29 12:31:07', NULL, 586.00, 'en_cours', NULL, 1, '2025-04-03 00:00:00', NULL),
(401, 401, 55, 25, '2025-05-24 09:30:03', '2025-05-24 19:30:03', NULL, 488.00, 'en_cours', NULL, 1, '2025-04-21 00:00:00', NULL),
(402, 402, 56, 26, '2025-05-07 12:20:48', '2025-05-08 02:20:48', NULL, 567.00, 'en_cours', NULL, 1, '2025-04-21 00:00:00', NULL),
(403, 403, 57, 27, '2025-04-26 06:22:59', '2025-04-26 15:22:59', NULL, 311.00, 'en_cours', NULL, 1, '2025-02-12 00:00:00', NULL),
(404, 404, 58, 28, '2025-05-12 09:12:11', '2025-05-12 17:12:11', NULL, 333.00, 'en_cours', NULL, 1, '2024-11-20 00:00:00', NULL),
(405, 405, 59, 29, '2025-04-25 17:11:11', '2025-04-26 04:11:11', NULL, 538.00, 'en_cours', NULL, 1, '2025-04-12 00:00:00', NULL),
(406, 406, 60, 30, '2025-01-26 16:25:44', '2025-01-27 08:25:44', NULL, 684.00, 'en_cours', NULL, 1, '2024-12-15 00:00:00', NULL),
(407, 407, 61, 17, '2025-06-19 14:13:10', '2025-06-20 03:13:10', NULL, 648.00, 'en_cours', NULL, 1, '2025-05-25 00:00:00', NULL),
(408, 408, 62, 18, '2025-05-08 11:06:40', '2025-05-08 15:06:40', NULL, 147.00, 'en_cours', NULL, 1, '2025-04-01 00:00:00', NULL),
(409, 409, 63, 19, '2025-05-10 14:19:49', '2025-05-10 19:19:49', NULL, 68.00, 'en_cours', NULL, 1, '2025-03-22 00:00:00', NULL),
(410, 410, 64, 20, '2025-06-16 12:25:42', '2025-06-16 19:25:42', NULL, 250.00, 'en_cours', NULL, 1, '2025-04-15 00:00:00', NULL),
(411, 411, 65, 21, '2025-03-02 03:06:22', '2025-03-02 14:06:22', NULL, 596.00, 'en_cours', NULL, 1, '2025-01-26 00:00:00', NULL),
(412, 412, 66, 22, '2025-01-24 13:56:01', '2025-01-24 21:56:01', NULL, 292.00, 'en_cours', NULL, 1, '2025-01-22 00:00:00', NULL),
(413, 413, 67, 23, '2025-05-21 20:37:14', '2025-05-22 01:37:14', NULL, 33.00, 'en_cours', NULL, 1, '2025-03-30 00:00:00', NULL),
(414, 414, 9, 24, '2025-06-12 01:31:31', '2025-06-12 13:31:31', NULL, 549.00, 'en_cours', NULL, 1, '2025-05-07 00:00:00', NULL),
(415, 415, 10, 25, '2025-06-19 01:29:18', '2025-06-19 10:29:18', NULL, 473.00, 'en_cours', NULL, 1, '2025-01-19 00:00:00', NULL),
(416, 416, 11, 26, '2025-02-16 09:04:16', '2025-02-16 14:04:16', NULL, 204.00, 'en_cours', NULL, 1, '2024-11-22 00:00:00', NULL),
(417, 417, 12, 27, '2025-03-19 16:59:30', '2025-03-20 06:59:30', NULL, 620.00, 'en_cours', NULL, 1, '2024-11-19 00:00:00', NULL),
(418, 418, 13, 28, '2025-04-08 08:48:15', '2025-04-08 22:48:15', NULL, 727.00, 'en_cours', NULL, 1, '2024-12-03 00:00:00', NULL),
(419, 419, 14, 29, '2025-04-22 03:11:55', '2025-04-22 20:11:55', NULL, 777.00, 'en_cours', NULL, 1, '2024-12-11 00:00:00', NULL),
(420, 420, 15, 30, '2025-02-11 15:51:35', '2025-02-12 00:51:35', NULL, 324.00, 'en_cours', NULL, 1, '2025-01-22 00:00:00', NULL),
(421, 421, 16, 17, '2025-03-05 12:12:36', '2025-03-05 23:12:36', NULL, 398.00, 'en_cours', NULL, 1, '2025-01-05 00:00:00', NULL),
(422, 422, 17, 18, '2025-05-11 04:46:12', '2025-05-11 14:46:12', NULL, 455.00, 'en_cours', NULL, 1, '2025-04-03 00:00:00', NULL),
(423, 423, 18, 19, '2025-04-14 19:16:50', '2025-04-14 23:16:50', NULL, 156.00, 'en_cours', NULL, 1, '2025-04-07 00:00:00', NULL),
(424, 424, 19, 20, '2025-04-12 14:43:32', '2025-04-13 05:43:32', NULL, 787.00, 'en_cours', NULL, 1, '2024-12-27 00:00:00', NULL),
(425, 425, 20, 21, '2025-06-10 11:08:38', '2025-06-10 21:08:38', NULL, 473.00, 'en_cours', NULL, 1, '2025-05-10 00:00:00', NULL),
(426, 426, 21, 22, '2025-05-11 02:23:15', '2025-05-11 11:23:15', NULL, 299.00, 'en_cours', NULL, 1, '2025-04-28 00:00:00', NULL),
(427, 427, 22, 23, '2025-05-02 14:37:08', '2025-05-03 04:37:08', NULL, 696.00, 'en_cours', NULL, 1, '2024-12-08 00:00:00', NULL),
(428, 428, 23, 24, '2025-02-18 03:19:50', '2025-02-18 18:19:50', NULL, 713.00, 'en_cours', NULL, 1, '2025-01-19 00:00:00', NULL),
(429, 429, 24, 25, '2025-04-08 19:44:02', '2025-04-09 03:44:02', NULL, 269.00, 'en_cours', NULL, 1, '2025-03-04 00:00:00', NULL),
(430, 430, 25, 26, '2025-06-13 18:47:31', '2025-06-13 21:47:31', NULL, 52.00, 'en_cours', NULL, 1, '2025-04-20 00:00:00', NULL),
(431, 431, 26, 27, '2025-04-14 02:14:07', '2025-04-14 05:14:07', NULL, 68.00, 'en_cours', NULL, 1, '2025-02-19 00:00:00', NULL),
(432, 432, 27, 28, '2025-06-08 07:45:13', '2025-06-09 00:45:13', NULL, 724.00, 'en_cours', NULL, 1, '2025-05-06 00:00:00', NULL),
(433, 433, 28, 29, '2025-04-22 22:59:06', '2025-04-23 04:59:06', NULL, 288.00, 'en_cours', NULL, 1, '2025-02-12 00:00:00', NULL),
(434, 434, 29, 30, '2025-02-01 18:34:13', '2025-02-01 23:34:13', NULL, 223.00, 'en_cours', NULL, 1, '2025-01-05 00:00:00', NULL),
(435, 435, 30, 17, '2025-03-01 20:27:09', '2025-03-02 04:27:09', NULL, 195.00, 'en_cours', NULL, 1, '2025-02-03 00:00:00', NULL),
(436, 436, 31, 18, '2025-04-30 09:15:27', '2025-04-30 19:15:27', NULL, 326.00, 'en_cours', NULL, 1, '2025-02-18 00:00:00', NULL),
(437, 437, 32, 19, '2025-06-11 23:17:01', '2025-06-12 13:17:01', NULL, 637.00, 'en_cours', NULL, 1, '2025-03-28 00:00:00', NULL),
(438, 438, 33, 20, '2024-11-30 03:00:00', '2024-11-30 12:00:00', NULL, 258.00, 'planifie', NULL, 1, '2024-11-29 00:00:00', NULL),
(439, 439, 34, 21, '2025-01-08 06:00:00', '2025-01-08 12:00:00', NULL, 201.00, 'planifie', NULL, 1, '2025-01-03 00:00:00', NULL),
(440, 440, 35, 22, '2024-12-16 04:00:00', '2024-12-16 20:00:00', NULL, 736.00, 'planifie', NULL, 1, '2024-12-15 00:00:00', NULL),
(441, 441, 36, 23, '2024-12-12 05:00:00', '2024-12-12 16:00:00', NULL, 412.00, 'planifie', NULL, 1, '2024-12-10 00:00:00', NULL),
(442, 442, 37, 24, '2025-02-18 06:00:00', '2025-02-18 13:00:00', NULL, 271.00, 'planifie', NULL, 1, '2025-02-14 00:00:00', NULL),
(443, 443, 38, 25, '2025-03-08 09:00:00', '2025-03-08 16:00:00', NULL, 130.00, 'planifie', NULL, 1, '2025-03-01 00:00:00', NULL),
(444, 444, 39, 26, '2025-03-05 00:00:00', '2025-03-05 09:00:00', NULL, 396.00, 'planifie', NULL, 1, '2025-03-04 00:00:00', NULL),
(445, 445, 40, 27, '2025-05-30 19:00:00', '2025-05-31 01:00:00', NULL, 88.00, 'planifie', NULL, 1, '2025-05-27 00:00:00', NULL),
(446, 446, 41, 28, '2025-03-03 19:00:00', '2025-03-04 06:00:00', NULL, 528.00, 'planifie', NULL, 1, '2025-03-02 00:00:00', NULL),
(447, 447, 42, 29, '2025-02-09 06:00:00', '2025-02-09 17:00:00', NULL, 387.00, 'planifie', NULL, 1, '2025-02-06 00:00:00', NULL),
(448, 448, 43, 30, '2024-11-27 04:00:00', '2024-11-27 17:00:00', NULL, 604.00, 'planifie', NULL, 1, '2024-11-23 00:00:00', NULL),
(449, 449, 44, 17, '2024-12-22 00:00:00', '2024-12-22 11:00:00', NULL, 487.00, 'planifie', NULL, 1, '2024-12-16 00:00:00', NULL),
(450, 450, 45, 18, '2024-11-30 13:00:00', '2024-11-30 16:00:00', NULL, 40.00, 'planifie', NULL, 1, '2024-11-28 00:00:00', NULL),
(451, 451, 46, 19, '2025-04-16 11:00:00', '2025-04-16 19:00:00', NULL, 294.00, 'planifie', NULL, 1, '2025-04-13 00:00:00', NULL),
(452, 452, 47, 20, '2025-01-06 08:00:00', '2025-01-06 21:00:00', NULL, 591.00, 'planifie', NULL, 1, '2024-12-30 00:00:00', NULL),
(453, 453, 48, 21, '2024-11-27 06:00:00', '2024-11-27 12:00:00', NULL, 183.00, 'planifie', NULL, 1, '2024-11-25 00:00:00', NULL),
(454, 454, 49, 22, '2024-12-25 09:00:00', '2024-12-25 17:00:00', NULL, 373.00, 'planifie', NULL, 1, '2024-12-23 00:00:00', NULL),
(455, 455, 50, 23, '2025-04-30 00:00:00', '2025-04-30 05:00:00', NULL, 227.00, 'planifie', NULL, 1, '2025-04-25 00:00:00', NULL),
(456, 456, 51, 24, '2025-03-26 23:00:00', '2025-03-27 04:00:00', NULL, 157.00, 'planifie', NULL, 1, '2025-03-21 00:00:00', NULL),
(457, 457, 52, 25, '2025-02-25 20:00:00', '2025-02-26 07:00:00', NULL, 564.00, 'planifie', NULL, 1, '2025-02-22 00:00:00', NULL),
(458, 458, 53, 26, '2025-01-03 22:00:00', '2025-01-04 00:00:00', NULL, 28.00, 'planifie', NULL, 1, '2024-12-28 00:00:00', NULL),
(459, 459, 54, 27, '2024-11-27 10:00:00', '2024-11-27 20:00:00', NULL, 320.00, 'planifie', NULL, 1, '2024-11-21 00:00:00', NULL),
(460, 460, 55, 28, '2025-01-08 00:00:00', '2025-01-08 13:00:00', NULL, 536.00, 'planifie', NULL, 1, '2025-01-01 00:00:00', NULL),
(461, 461, 56, 29, '2025-02-24 07:00:00', '2025-02-24 09:00:00', NULL, 53.00, 'planifie', NULL, 1, '2025-02-17 00:00:00', NULL),
(462, 462, 57, 30, '2024-11-23 01:00:00', '2024-11-23 06:00:00', NULL, 21.00, 'planifie', NULL, 1, '2024-11-17 00:00:00', NULL),
(463, 463, 58, 17, '2025-05-30 20:00:00', '2025-05-31 05:00:00', NULL, 324.00, 'planifie', NULL, 1, '2025-05-26 00:00:00', NULL),
(464, 464, 59, 18, '2025-04-20 00:00:00', '2025-04-20 08:00:00', NULL, 283.00, 'planifie', NULL, 1, '2025-04-19 00:00:00', NULL),
(465, 465, 60, 19, '2025-05-22 00:00:00', '2025-05-22 16:00:00', NULL, 704.00, 'planifie', NULL, 1, '2025-05-20 00:00:00', NULL),
(466, 466, 61, 20, '2025-03-23 05:00:00', '2025-03-23 15:00:00', NULL, 323.00, 'planifie', NULL, 1, '2025-03-22 00:00:00', NULL),
(467, 467, 62, 21, '2025-05-01 00:00:00', '2025-05-01 03:00:00', NULL, 21.00, 'planifie', NULL, 1, '2025-04-29 00:00:00', NULL),
(468, 468, 63, 22, '2025-01-03 02:00:00', '2025-01-03 08:00:00', NULL, 66.00, 'planifie', NULL, 1, '2024-12-31 00:00:00', NULL),
(469, 469, 64, 23, '2025-03-23 11:00:00', '2025-03-24 04:00:00', NULL, 728.00, 'planifie', NULL, 1, '2025-03-18 00:00:00', NULL),
(470, 470, 65, 24, '2025-05-12 13:00:00', '2025-05-12 21:00:00', NULL, 411.00, 'planifie', NULL, 1, '2025-05-08 00:00:00', NULL),
(471, 471, 66, 25, '2025-02-10 10:00:00', '2025-02-10 20:00:00', NULL, 378.00, 'planifie', NULL, 1, '2025-02-05 00:00:00', NULL),
(472, 472, 67, 26, '2025-05-31 05:00:00', '2025-05-31 10:00:00', NULL, 205.00, 'planifie', NULL, 1, '2025-05-29 00:00:00', NULL),
(473, 473, 9, 27, '2025-01-04 12:00:00', '2025-01-05 06:00:00', NULL, 797.00, 'planifie', NULL, 1, '2024-12-31 00:00:00', NULL),
(474, 474, 10, 28, '2025-05-22 06:00:00', '2025-05-22 21:00:00', NULL, 655.00, 'planifie', NULL, 1, '2025-05-16 00:00:00', NULL),
(475, 475, 11, 29, '2025-05-21 00:00:00', '2025-05-21 05:00:00', NULL, 216.00, 'planifie', NULL, 1, '2025-05-16 00:00:00', NULL),
(476, 476, 12, 30, '2025-04-06 01:00:00', '2025-04-06 04:00:00', NULL, 83.00, 'planifie', NULL, 1, '2025-04-04 00:00:00', NULL),
(477, 477, 13, 17, '2025-04-10 04:00:00', '2025-04-10 08:00:00', NULL, 156.00, 'planifie', NULL, 1, '2025-04-08 00:00:00', NULL),
(478, 478, 14, 18, '2025-01-24 12:00:00', '2025-01-24 20:00:00', NULL, 258.00, 'planifie', NULL, 1, '2025-01-20 00:00:00', NULL),
(479, 479, 15, 19, '2025-03-31 06:00:00', '2025-03-31 21:00:00', NULL, 626.00, 'planifie', NULL, 1, '2025-03-24 00:00:00', NULL),
(480, 480, 16, 20, '2024-12-17 21:00:00', '2024-12-18 05:00:00', NULL, 335.00, 'planifie', NULL, 1, '2024-12-11 00:00:00', NULL),
(481, 481, 17, 21, '2025-04-14 03:00:00', '2025-04-14 08:00:00', NULL, 231.00, 'planifie', NULL, 1, '2025-04-08 00:00:00', NULL),
(482, 482, 18, 22, '2025-05-05 00:00:00', '2025-05-05 11:00:00', NULL, 426.00, 'planifie', NULL, 1, '2025-04-30 00:00:00', NULL),
(483, 483, 19, 23, '2024-11-28 04:00:00', '2024-11-28 16:00:00', NULL, 606.00, 'planifie', NULL, 1, '2024-11-24 00:00:00', NULL),
(484, 484, 20, 24, '2025-05-16 09:00:00', '2025-05-16 21:00:00', NULL, 576.00, 'planifie', NULL, 1, '2025-05-14 00:00:00', NULL),
(485, 485, 21, 25, '2025-02-16 09:00:00', '2025-02-16 21:00:00', NULL, 557.00, 'planifie', NULL, 1, '2025-02-10 00:00:00', NULL);

--
-- Déclencheurs `trajets`
--
DROP TRIGGER IF EXISTS `tr_trajet_complete_order`;
DELIMITER $$
CREATE TRIGGER `tr_trajet_complete_order` AFTER UPDATE ON `trajets` FOR EACH ROW BEGIN
    IF OLD.statut != 'termine' AND NEW.statut = 'termine' THEN
        UPDATE commandes SET statut = 'livree' WHERE id = NEW.commande_id;
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `tr_trajet_status_update`;
DELIMITER $$
CREATE TRIGGER `tr_trajet_status_update` AFTER UPDATE ON `trajets` FOR EACH ROW BEGIN
    IF OLD.statut != NEW.statut THEN
        IF NEW.statut = 'termine' OR NEW.statut = 'annule' THEN
            UPDATE vehicules SET disponible = 1 WHERE id = NEW.vehicule_id;
        ELSEIF NEW.statut = 'en_cours' AND OLD.statut = 'planifie' THEN
            UPDATE vehicules SET disponible = 0 WHERE id = NEW.vehicule_id;
        END IF;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `transactions`
--

DROP TABLE IF EXISTS `transactions`;
CREATE TABLE IF NOT EXISTS `transactions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `reference` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('paiement','salaire','maintenance','carburant','autre') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `montant` decimal(15,2) NOT NULL,
  `date_transaction` date NOT NULL,
  `statut` enum('en_attente','valide','annule') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'valide',
  `mode_paiement` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `facture_id` int DEFAULT NULL,
  `client_id` int DEFAULT NULL,
  `employe_id` int DEFAULT NULL,
  `vehicule_id` int DEFAULT NULL,
  `categorie` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantite` decimal(10,2) DEFAULT NULL,
  `prix_unitaire` decimal(10,2) DEFAULT NULL,
  `periode` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type_maintenance` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `reference` (`reference`),
  KEY `idx_type` (`type`),
  KEY `idx_date_transaction` (`date_transaction`),
  KEY `idx_statut` (`statut`),
  KEY `idx_actif` (`actif`)
) ENGINE=InnoDB AUTO_INCREMENT=600 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `transactions`
--

INSERT INTO `transactions` (`id`, `reference`, `type`, `description`, `montant`, `date_transaction`, `statut`, `mode_paiement`, `facture_id`, `client_id`, `employe_id`, `vehicule_id`, `categorie`, `quantite`, `prix_unitaire`, `periode`, `type_maintenance`, `actif`, `date_creation`, `date_modification`) VALUES
(1, 'OM20250621000001', 'paiement', 'Paiement facture FACT2025050001 - Commande CMD2025060001', 58182.09, '2025-05-14', 'valide', 'Orange Money', 1, 134, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-14 07:06:51', NULL),
(2, 'ESP20250621000002', 'paiement', 'Paiement facture FACT2025050002 - Commande CMD2025060002', 275654.69, '2025-05-30', 'valide', 'Espèces', 2, 149, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-30 12:51:27', NULL),
(3, 'MM20250621000003', 'paiement', 'Paiement facture FACT2024120003 - Commande CMD2025060003', 215445.00, '2025-01-06', 'valide', 'MTN Mobile Money', 3, 152, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-06 08:40:22', NULL),
(4, 'OM20250621000004', 'paiement', 'Paiement facture FACT2025030004 - Commande CMD2025060004', 34494.63, '2025-03-27', 'valide', 'Orange Money', 4, 128, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-27 19:13:36', NULL),
(5, 'VIR20250621000005', 'paiement', 'Paiement facture FACT2025050005 - Commande CMD2025060005', 51666.51, '2025-06-13', 'valide', 'Virement bancaire', 5, 116, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-13 02:22:48', NULL),
(6, 'VIR20250621000006', 'paiement', 'Paiement facture FACT2025010006 - Commande CMD2025060006', 454453.92, '2025-01-08', 'valide', 'Virement bancaire', 6, 144, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-08 03:25:10', NULL),
(7, 'MM20250621000007', 'paiement', 'Paiement facture FACT2025030007 - Commande CMD2025060007', 300530.16, '2025-04-02', 'valide', 'MTN Mobile Money', 7, 133, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-02 09:40:25', NULL),
(8, 'VIR20250621000008', 'paiement', 'Paiement facture FACT2025020008 - Commande CMD2025060008', 62501.71, '2025-02-26', 'valide', 'Virement bancaire', 8, 60, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-26 08:30:37', NULL),
(9, 'VIR20250621000009', 'paiement', 'Paiement facture FACT2024120009 - Commande CMD2025060009', 258462.57, '2024-12-19', 'valide', 'Virement bancaire', 9, 154, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-19 20:05:12', NULL),
(10, 'VIR20250621000010', 'paiement', 'Paiement facture FACT2024110010 - Commande CMD2025060010', 45391.20, '2024-12-14', 'valide', 'Virement bancaire', 10, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-14 02:56:29', NULL),
(11, 'ESP20250621000011', 'paiement', 'Paiement facture FACT2024110011 - Commande CMD2025060011', 151335.21, '2024-12-10', 'valide', 'Espèces', 11, 177, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-10 14:41:19', NULL),
(12, 'VIR20250621000012', 'paiement', 'Paiement facture FACT2025020012 - Commande CMD2025060012', 421307.80, '2025-02-21', 'valide', 'Virement bancaire', 12, 82, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-21 21:44:21', NULL),
(13, 'VIR20250621000013', 'paiement', 'Paiement facture FACT2025040013 - Commande CMD2025060013', 13928.27, '2025-05-10', 'valide', 'Virement bancaire', 13, 10, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-10 17:32:14', NULL),
(14, 'VIR20250621000014', 'paiement', 'Paiement facture FACT2025010014 - Commande CMD2025060014', 19367.06, '2025-02-02', 'valide', 'Virement bancaire', 14, 90, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-02 19:16:10', NULL),
(15, 'OM20250621000015', 'paiement', 'Paiement facture FACT2025050015 - Commande CMD2025060015', 66286.37, '2025-05-13', 'valide', 'Orange Money', 15, 81, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-13 20:31:02', NULL),
(16, 'MM20250621000016', 'paiement', 'Paiement facture FACT2025050016 - Commande CMD2025060016', 469168.96, '2025-06-15', 'valide', 'MTN Mobile Money', 16, 59, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-15 18:35:35', NULL),
(17, 'VIR20250621000017', 'paiement', 'Paiement facture FACT2025020017 - Commande CMD2025060017', 550513.77, '2025-02-25', 'valide', 'Virement bancaire', 17, 36, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-25 03:01:05', NULL),
(18, 'VIR20250621000018', 'paiement', 'Paiement facture FACT2025010018 - Commande CMD2025060018', 694299.88, '2025-01-06', 'valide', 'Virement bancaire', 18, 151, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-06 14:05:18', NULL),
(19, 'VIR20250621000019', 'paiement', 'Paiement facture FACT2025030019 - Commande CMD2025060019', 835916.76, '2025-03-09', 'valide', 'Virement bancaire', 19, 98, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-09 09:01:06', NULL),
(20, 'MM20250621000020', 'paiement', 'Paiement facture FACT2025020020 - Commande CMD2025060020', 1071536.35, '2025-03-06', 'valide', 'MTN Mobile Money', 20, 76, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-06 16:19:49', NULL),
(21, 'OM20250621000021', 'paiement', 'Paiement facture FACT2025010021 - Commande CMD2025060021', 120335.48, '2025-01-29', 'valide', 'Orange Money', 21, 35, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-29 15:45:01', NULL),
(22, 'VIR20250621000022', 'paiement', 'Paiement facture FACT2025030022 - Commande CMD2025060022', 640989.95, '2025-03-26', 'valide', 'Virement bancaire', 22, 32, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-26 23:54:42', NULL),
(23, 'VIR20250621000023', 'paiement', 'Paiement facture FACT2025020023 - Commande CMD2025060023', 15425.15, '2025-02-25', 'valide', 'Virement bancaire', 23, 37, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-25 08:47:20', NULL),
(24, 'VIR20250621000024', 'paiement', 'Paiement facture FACT2025040024 - Commande CMD2025060024', 549013.16, '2025-05-17', 'valide', 'Virement bancaire', 24, 78, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-17 01:34:30', NULL),
(25, 'CHQ20250621000025', 'paiement', 'Paiement facture FACT2024120025 - Commande CMD2025060025', 547463.76, '2024-12-28', 'valide', 'Chèque', 25, 191, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-28 15:17:23', NULL),
(26, 'VIR20250621000026', 'paiement', 'Paiement facture FACT2025010026 - Commande CMD2025060026', 14095.25, '2025-02-10', 'valide', 'Virement bancaire', 26, 83, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-10 20:23:50', NULL),
(27, 'MM20250621000027', 'paiement', 'Paiement facture FACT2024120027 - Commande CMD2025060027', 779059.00, '2025-01-13', 'valide', 'MTN Mobile Money', 27, 7, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-13 16:59:56', NULL),
(28, 'ESP20250621000028', 'paiement', 'Paiement facture FACT2025030028 - Commande CMD2025060028', 891987.00, '2025-03-18', 'valide', 'Espèces', 28, 122, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-18 07:15:32', NULL),
(29, 'VIR20250621000029', 'paiement', 'Paiement facture FACT2025040029 - Commande CMD2025060029', 16894.98, '2025-05-07', 'valide', 'Virement bancaire', 29, 109, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-07 20:34:56', NULL),
(30, 'OM20250621000030', 'paiement', 'Paiement facture FACT2025030030 - Commande CMD2025060030', 290057.26, '2025-04-09', 'valide', 'Orange Money', 30, 47, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-09 05:26:35', NULL),
(31, 'ESP20250621000031', 'paiement', 'Paiement facture FACT2025010031 - Commande CMD2025060031', 39033.68, '2025-02-04', 'valide', 'Espèces', 31, 125, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-04 08:28:02', NULL),
(32, 'VIR20250621000032', 'paiement', 'Paiement facture FACT2025030032 - Commande CMD2025060032', 620134.70, '2025-03-21', 'valide', 'Virement bancaire', 32, 31, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-21 16:51:43', NULL),
(33, 'OM20250621000033', 'paiement', 'Paiement facture FACT2025030033 - Commande CMD2025060033', 307477.41, '2025-03-30', 'valide', 'Orange Money', 33, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-30 15:33:23', NULL),
(34, 'MM20250621000034', 'paiement', 'Paiement facture FACT2025040034 - Commande CMD2025060034', 82355.72, '2025-05-04', 'valide', 'MTN Mobile Money', 34, 124, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-04 19:11:05', NULL),
(35, 'OM20250621000035', 'paiement', 'Paiement facture FACT2025050035 - Commande CMD2025060035', 415267.81, '2025-05-14', 'valide', 'Orange Money', 35, 193, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-14 19:08:54', NULL),
(36, 'VIR20250621000036', 'paiement', 'Paiement facture FACT2024110036 - Commande CMD2025060036', 26302.42, '2024-12-14', 'valide', 'Virement bancaire', 36, 21, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-14 10:12:18', NULL),
(37, 'VIR20250621000037', 'paiement', 'Paiement facture FACT2025050037 - Commande CMD2025060037', 329184.28, '2025-05-18', 'valide', 'Virement bancaire', 37, 127, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-18 02:41:26', NULL),
(38, 'MM20250621000038', 'paiement', 'Paiement facture FACT2025010038 - Commande CMD2025060038', 776316.63, '2025-01-19', 'valide', 'MTN Mobile Money', 38, 52, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-19 10:34:56', NULL),
(39, 'ESP20250621000039', 'paiement', 'Paiement facture FACT2025010039 - Commande CMD2025060039', 450382.09, '2025-02-06', 'valide', 'Espèces', 39, 87, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-06 15:25:45', NULL),
(40, 'OM20250621000040', 'paiement', 'Paiement facture FACT2025050040 - Commande CMD2025060040', 438687.61, '2025-06-05', 'valide', 'Orange Money', 40, 194, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-05 13:07:24', NULL),
(41, 'CHQ20250621000041', 'paiement', 'Paiement facture FACT2025030041 - Commande CMD2025060041', 359524.28, '2025-04-11', 'valide', 'Chèque', 41, 150, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-11 02:22:28', NULL),
(42, 'VIR20250621000042', 'paiement', 'Paiement facture FACT2025020042 - Commande CMD2025060042', 54129.20, '2025-02-12', 'valide', 'Virement bancaire', 42, 88, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-12 09:26:46', NULL),
(43, 'VIR20250621000043', 'paiement', 'Paiement facture FACT2024110043 - Commande CMD2025060043', 478343.08, '2024-12-07', 'valide', 'Virement bancaire', 43, 184, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-07 00:00:40', NULL),
(44, 'OM20250621000044', 'paiement', 'Paiement facture FACT2025010044 - Commande CMD2025060044', 430640.39, '2025-02-21', 'valide', 'Orange Money', 44, 41, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-21 21:30:07', NULL),
(45, 'OM20250621000045', 'paiement', 'Paiement facture FACT2025010045 - Commande CMD2025060045', 388166.19, '2025-02-18', 'valide', 'Orange Money', 45, 22, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-18 03:32:31', NULL),
(46, 'VIR20250621000046', 'paiement', 'Paiement facture FACT2025020046 - Commande CMD2025060046', 648101.25, '2025-02-28', 'valide', 'Virement bancaire', 46, 145, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-28 23:33:56', NULL),
(47, 'OM20250621000047', 'paiement', 'Paiement facture FACT2025020047 - Commande CMD2025060047', 165171.17, '2025-03-19', 'valide', 'Orange Money', 47, 146, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-19 07:24:37', NULL),
(48, 'VIR20250621000048', 'paiement', 'Paiement facture FACT2025010048 - Commande CMD2025060048', 143319.54, '2025-02-03', 'valide', 'Virement bancaire', 48, 26, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-03 19:36:30', NULL),
(49, 'VIR20250621000049', 'paiement', 'Paiement facture FACT2024120049 - Commande CMD2025060049', 146637.03, '2024-12-15', 'valide', 'Virement bancaire', 49, 164, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-15 09:10:50', NULL),
(50, 'VIR20250621000050', 'paiement', 'Paiement facture FACT2025030050 - Commande CMD2025060050', 528561.86, '2025-03-15', 'valide', 'Virement bancaire', 50, 156, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-15 11:18:07', NULL),
(51, 'OM20250621000051', 'paiement', 'Paiement facture FACT2025010051 - Commande CMD2025060051', 349740.06, '2025-01-21', 'valide', 'Orange Money', 51, 40, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-21 02:33:26', NULL),
(52, 'VIR20250621000052', 'paiement', 'Paiement facture FACT2025040052 - Commande CMD2025060052', 514192.47, '2025-04-21', 'valide', 'Virement bancaire', 52, 160, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-21 12:10:50', NULL),
(53, 'MM20250621000053', 'paiement', 'Paiement facture FACT2025020053 - Commande CMD2025060053', 272799.49, '2025-02-26', 'valide', 'MTN Mobile Money', 53, 86, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-26 13:12:13', NULL),
(54, 'OM20250621000054', 'paiement', 'Paiement facture FACT2025050054 - Commande CMD2025060054', 216890.62, '2025-05-16', 'valide', 'Orange Money', 54, 114, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-16 04:35:10', NULL),
(55, 'OM20250621000055', 'paiement', 'Paiement facture FACT2025040055 - Commande CMD2025060055', 295744.47, '2025-04-06', 'valide', 'Orange Money', 55, 141, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-06 05:31:34', NULL),
(56, 'OM20250621000056', 'paiement', 'Paiement facture FACT2025030056 - Commande CMD2025060056', 455488.41, '2025-03-27', 'valide', 'Orange Money', 56, 182, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-27 11:12:22', NULL),
(57, 'VIR20250621000057', 'paiement', 'Paiement facture FACT2025020057 - Commande CMD2025060057', 13420.38, '2025-02-20', 'valide', 'Virement bancaire', 57, 65, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-20 00:06:01', NULL),
(58, 'ESP20250621000058', 'paiement', 'Paiement facture FACT2025040058 - Commande CMD2025060058', 621726.60, '2025-04-22', 'valide', 'Espèces', 58, 53, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-22 08:23:52', NULL),
(59, 'MM20250621000059', 'paiement', 'Paiement facture FACT2024120059 - Commande CMD2025060059', 14624.22, '2025-01-01', 'valide', 'MTN Mobile Money', 59, 73, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-01 22:43:27', NULL),
(60, 'VIR20250621000060', 'paiement', 'Paiement facture FACT2025050060 - Commande CMD2025060060', 224938.16, '2025-06-03', 'valide', 'Virement bancaire', 60, 166, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-03 10:58:36', NULL),
(61, 'VIR20250621000061', 'paiement', 'Paiement facture FACT2024120061 - Commande CMD2025060061', 81130.17, '2025-01-09', 'valide', 'Virement bancaire', 61, 16, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-09 13:36:29', NULL),
(62, 'VIR20250621000062', 'paiement', 'Paiement facture FACT2025030062 - Commande CMD2025060062', 598820.96, '2025-03-27', 'valide', 'Virement bancaire', 62, 5, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-27 20:15:23', NULL),
(63, 'MM20250621000063', 'paiement', 'Paiement facture FACT2025010063 - Commande CMD2025060063', 788403.82, '2025-01-31', 'valide', 'MTN Mobile Money', 63, 189, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-31 09:43:56', NULL),
(64, 'VIR20250621000064', 'paiement', 'Paiement facture FACT2025040064 - Commande CMD2025060064', 1055050.00, '2025-04-24', 'valide', 'Virement bancaire', 64, 75, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-24 21:33:53', NULL),
(65, 'OM20250621000065', 'paiement', 'Paiement facture FACT2025020065 - Commande CMD2025060065', 853475.67, '2025-02-19', 'valide', 'Orange Money', 65, 108, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-19 09:40:11', NULL),
(66, 'VIR20250621000066', 'paiement', 'Paiement facture FACT2025030066 - Commande CMD2025060066', 436375.08, '2025-03-24', 'valide', 'Virement bancaire', 66, 43, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-24 01:55:25', NULL),
(67, 'VIR20250621000067', 'paiement', 'Paiement facture FACT2025010067 - Commande CMD2025060067', 1092083.16, '2025-02-08', 'valide', 'Virement bancaire', 67, 126, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-08 18:09:03', NULL),
(68, 'OM20250621000068', 'paiement', 'Paiement facture FACT2024120068 - Commande CMD2025060068', 939224.40, '2024-12-23', 'valide', 'Orange Money', 68, 188, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-23 07:23:52', NULL),
(69, 'VIR20250621000069', 'paiement', 'Paiement facture FACT2025010069 - Commande CMD2025060069', 173223.34, '2025-01-28', 'valide', 'Virement bancaire', 69, 70, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-28 17:17:55', NULL),
(70, 'MM20250621000070', 'paiement', 'Paiement facture FACT2025040070 - Commande CMD2025060070', 1152363.40, '2025-04-16', 'valide', 'MTN Mobile Money', 70, 9, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-16 18:28:54', NULL),
(71, 'VIR20250621000071', 'paiement', 'Paiement facture FACT2025020071 - Commande CMD2025060071', 204314.75, '2025-03-17', 'valide', 'Virement bancaire', 71, 181, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-17 13:49:42', NULL),
(72, 'OM20250621000072', 'paiement', 'Paiement facture FACT2025020072 - Commande CMD2025060072', 763326.84, '2025-02-21', 'valide', 'Orange Money', 72, 57, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-21 09:01:39', NULL),
(73, 'VIR20250621000073', 'paiement', 'Paiement facture FACT2025040073 - Commande CMD2025060073', 456937.30, '2025-04-25', 'valide', 'Virement bancaire', 73, 167, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-25 20:34:14', NULL),
(74, 'OM20250621000074', 'paiement', 'Paiement facture FACT2025020074 - Commande CMD2025060074', 81477.77, '2025-02-25', 'valide', 'Orange Money', 74, 137, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-25 07:07:09', NULL),
(75, 'MM20250621000075', 'paiement', 'Paiement facture FACT2025010075 - Commande CMD2025060075', 222909.10, '2025-01-18', 'valide', 'MTN Mobile Money', 75, 63, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-18 04:47:08', NULL),
(76, 'VIR20250621000076', 'paiement', 'Paiement facture FACT2025010076 - Commande CMD2025060076', 350923.46, '2025-02-02', 'valide', 'Virement bancaire', 76, 129, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-02 02:14:36', NULL),
(77, 'VIR20250621000077', 'paiement', 'Paiement facture FACT2025050077 - Commande CMD2025060077', 8104.68, '2025-06-13', 'valide', 'Virement bancaire', 77, 132, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-13 08:13:26', NULL),
(78, 'MM20250621000078', 'paiement', 'Paiement facture FACT2025050078 - Commande CMD2025060078', 1508599.62, '2025-06-10', 'valide', 'MTN Mobile Money', 78, 136, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-10 20:43:43', NULL),
(79, 'VIR20250621000079', 'paiement', 'Paiement facture FACT2025040079 - Commande CMD2025060079', 449700.34, '2025-05-25', 'valide', 'Virement bancaire', 79, 178, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-25 05:40:52', NULL),
(80, 'ESP20250621000080', 'paiement', 'Paiement facture FACT2025040080 - Commande CMD2025060080', 340237.53, '2025-05-11', 'valide', 'Espèces', 80, 85, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-11 21:55:20', NULL),
(81, 'VIR20250621000081', 'paiement', 'Paiement facture FACT2025040081 - Commande CMD2025060081', 954932.43, '2025-04-09', 'valide', 'Virement bancaire', 81, 11, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-09 06:50:54', NULL),
(82, 'MM20250621000082', 'paiement', 'Paiement facture FACT2025010082 - Commande CMD2025060082', 289316.78, '2025-02-08', 'valide', 'MTN Mobile Money', 82, 105, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-08 15:11:52', NULL),
(83, 'VIR20250621000083', 'paiement', 'Paiement facture FACT2025010083 - Commande CMD2025060083', 576980.09, '2025-01-23', 'valide', 'Virement bancaire', 83, 42, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-23 07:42:54', NULL),
(84, 'VIR20250621000084', 'paiement', 'Paiement facture FACT2025040084 - Commande CMD2025060084', 1751046.43, '2025-04-05', 'valide', 'Virement bancaire', 84, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-05 20:56:53', NULL),
(85, 'OM20250621000085', 'paiement', 'Paiement facture FACT2025030085 - Commande CMD2025060085', 1182366.54, '2025-04-01', 'valide', 'Orange Money', 85, 174, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-01 03:25:51', NULL),
(86, 'VIR20250621000086', 'paiement', 'Paiement facture FACT2025020086 - Commande CMD2025060086', 93316.83, '2025-02-22', 'valide', 'Virement bancaire', 86, 62, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-22 04:07:41', NULL),
(87, 'OM20250621000087', 'paiement', 'Paiement facture FACT2024120087 - Commande CMD2025060087', 583332.54, '2024-12-12', 'valide', 'Orange Money', 87, 165, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-12 00:02:05', NULL),
(88, 'OM20250621000088', 'paiement', 'Paiement facture FACT2024120088 - Commande CMD2025060088', 596562.25, '2024-12-30', 'valide', 'Orange Money', 88, 183, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-30 19:38:29', NULL),
(89, 'ESP20250621000089', 'paiement', 'Paiement facture FACT2025030089 - Commande CMD2025060089', 289589.41, '2025-03-22', 'valide', 'Espèces', 89, 45, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-22 00:51:45', NULL),
(90, 'VIR20250621000090', 'paiement', 'Paiement facture FACT2025050090 - Commande CMD2025060090', 296569.07, '2025-06-01', 'valide', 'Virement bancaire', 90, 6, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-01 15:13:06', NULL),
(91, 'VIR20250621000091', 'paiement', 'Paiement facture FACT2025050091 - Commande CMD2025060091', 214386.81, '2025-06-08', 'valide', 'Virement bancaire', 91, 38, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-08 17:31:47', NULL),
(92, 'OM20250621000092', 'paiement', 'Paiement facture FACT2025040092 - Commande CMD2025060092', 275801.22, '2025-05-23', 'valide', 'Orange Money', 92, 171, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-23 13:33:12', NULL),
(93, 'VIR20250621000093', 'paiement', 'Paiement facture FACT2025040093 - Commande CMD2025060093', 7836.29, '2025-04-15', 'valide', 'Virement bancaire', 93, 99, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-15 10:45:40', NULL),
(94, 'VIR20250621000094', 'paiement', 'Paiement facture FACT2025040094 - Commande CMD2025060094', 1704327.54, '2025-04-22', 'valide', 'Virement bancaire', 94, 67, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-22 17:21:27', NULL),
(95, 'VIR20250621000095', 'paiement', 'Paiement facture FACT2025010095 - Commande CMD2025060095', 855310.11, '2025-02-18', 'valide', 'Virement bancaire', 95, 66, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-18 07:24:48', NULL),
(96, 'VIR20250621000096', 'paiement', 'Paiement facture FACT2025040096 - Commande CMD2025060096', 431845.04, '2025-05-15', 'valide', 'Virement bancaire', 96, 50, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-15 22:41:19', NULL),
(97, 'OM20250621000097', 'paiement', 'Paiement facture FACT2024110097 - Commande CMD2025060097', 528924.76, '2024-12-23', 'valide', 'Orange Money', 97, 195, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-23 01:48:46', NULL),
(98, 'MM20250621000098', 'paiement', 'Paiement facture FACT2025020098 - Commande CMD2025060098', 1389344.45, '2025-02-21', 'valide', 'MTN Mobile Money', 98, 25, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-21 04:12:41', NULL),
(99, 'VIR20250621000099', 'paiement', 'Paiement facture FACT2025040099 - Commande CMD2025060099', 572736.34, '2025-05-12', 'valide', 'Virement bancaire', 99, 103, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-12 13:43:01', NULL),
(100, 'OM20250621000100', 'paiement', 'Paiement facture FACT2025020100 - Commande CMD2025060100', 1079177.19, '2025-03-13', 'valide', 'Orange Money', 100, 155, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-13 05:04:09', NULL),
(101, 'OM20250621000101', 'paiement', 'Paiement facture FACT2025050101 - Commande CMD2025060101', 486303.59, '2025-05-20', 'valide', 'Orange Money', 101, 44, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-20 14:42:17', NULL),
(102, 'VIR20250621000102', 'paiement', 'Paiement facture FACT2025050102 - Commande CMD2025060102', 520846.27, '2025-05-17', 'valide', 'Virement bancaire', 102, 107, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-17 10:45:10', NULL),
(103, 'MM20250621000103', 'paiement', 'Paiement facture FACT2025010103 - Commande CMD2025060103', 326481.66, '2025-02-16', 'valide', 'MTN Mobile Money', 103, 169, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-16 16:31:31', NULL),
(104, 'MM20250621000104', 'paiement', 'Paiement facture FACT2025030104 - Commande CMD2025060104', 554491.06, '2025-04-02', 'valide', 'MTN Mobile Money', 104, 180, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-02 19:25:09', NULL),
(105, 'ESP20250621000105', 'paiement', 'Paiement facture FACT2025050105 - Commande CMD2025060105', 456946.60, '2025-06-01', 'valide', 'Espèces', 105, 71, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-01 16:29:18', NULL),
(106, 'MM20250621000106', 'paiement', 'Paiement facture FACT2025040106 - Commande CMD2025060106', 710213.00, '2025-04-03', 'valide', 'MTN Mobile Money', 106, 147, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-03 06:19:58', NULL),
(107, 'MM20250621000107', 'paiement', 'Paiement facture FACT2025020107 - Commande CMD2025060107', 173078.15, '2025-03-14', 'valide', 'MTN Mobile Money', 107, 34, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-14 18:50:39', NULL),
(108, 'OM20250621000108', 'paiement', 'Paiement facture FACT2024110108 - Commande CMD2025060108', 286543.21, '2024-12-14', 'valide', 'Orange Money', 108, 96, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-14 01:03:31', NULL),
(109, 'OM20250621000109', 'paiement', 'Paiement facture FACT2025020109 - Commande CMD2025060109', 220994.98, '2025-02-07', 'valide', 'Orange Money', 109, 118, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-07 16:25:51', NULL),
(110, 'MM20250621000110', 'paiement', 'Paiement facture FACT2024110110 - Commande CMD2025060110', 637276.46, '2024-12-01', 'valide', 'MTN Mobile Money', 110, 89, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-01 02:27:09', NULL),
(111, 'OM20250621000111', 'paiement', 'Paiement facture FACT2024120111 - Commande CMD2025060111', 356286.84, '2024-12-29', 'valide', 'Orange Money', 111, 139, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-29 02:15:36', NULL),
(112, 'VIR20250621000112', 'paiement', 'Paiement facture FACT2025020112 - Commande CMD2025060112', 36121.48, '2025-02-26', 'valide', 'Virement bancaire', 112, 113, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-26 07:07:47', NULL),
(113, 'OM20250621000113', 'paiement', 'Paiement facture FACT2025010113 - Commande CMD2025060113', 150991.50, '2025-02-15', 'valide', 'Orange Money', 113, 8, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-15 22:37:40', NULL),
(114, 'VIR20250621000114', 'paiement', 'Paiement facture FACT2025050114 - Commande CMD2025060114', 41697.07, '2025-05-22', 'valide', 'Virement bancaire', 114, 72, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-22 03:49:31', NULL),
(115, 'VIR20250621000115', 'paiement', 'Paiement facture FACT2025020115 - Commande CMD2025060115', 8110.07, '2025-02-11', 'valide', 'Virement bancaire', 115, 84, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-11 03:22:01', NULL),
(116, 'VIR20250621000116', 'paiement', 'Paiement facture FACT2025030116 - Commande CMD2025060116', 32473.38, '2025-03-11', 'valide', 'Virement bancaire', 116, 120, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-11 21:06:06', NULL),
(117, 'VIR20250621000117', 'paiement', 'Paiement facture FACT2024120117 - Commande CMD2025060117', 976344.69, '2025-01-24', 'valide', 'Virement bancaire', 117, 140, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-24 00:31:44', NULL),
(118, 'OM20250621000118', 'paiement', 'Paiement facture FACT2025030118 - Commande CMD2025060118', 529539.64, '2025-03-22', 'valide', 'Orange Money', 118, 13, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-22 04:45:58', NULL),
(119, 'ESP20250621000119', 'paiement', 'Paiement facture FACT2025010119 - Commande CMD2025060119', 200299.62, '2025-02-20', 'valide', 'Espèces', 119, 153, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-20 22:00:42', NULL),
(120, 'OM20250621000120', 'paiement', 'Paiement facture FACT2024120120 - Commande CMD2025060120', 383368.62, '2024-12-12', 'valide', 'Orange Money', 120, 30, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-12 03:39:17', NULL),
(121, 'OM20250621000121', 'paiement', 'Paiement facture FACT2025060121 - Commande CMD2025060121', 1005416.31, '2025-06-18', 'valide', 'Orange Money', 121, 143, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-18 08:28:17', NULL),
(122, 'VIR20250621000122', 'paiement', 'Paiement facture FACT2025040122 - Commande CMD2025060122', 399679.56, '2025-05-10', 'valide', 'Virement bancaire', 122, 190, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-10 19:24:12', NULL),
(123, 'OM20250621000123', 'paiement', 'Paiement facture FACT2025020123 - Commande CMD2025060123', 190686.56, '2025-03-01', 'valide', 'Orange Money', 123, 163, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-01 05:25:07', NULL),
(124, 'ESP20250621000124', 'paiement', 'Paiement facture FACT2025050124 - Commande CMD2025060124', 19631.09, '2025-06-03', 'valide', 'Espèces', 124, 119, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-03 08:01:07', NULL),
(125, 'MM20250621000125', 'paiement', 'Paiement facture FACT2025050125 - Commande CMD2025060125', 192182.01, '2025-05-28', 'valide', 'MTN Mobile Money', 125, 101, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-28 06:23:18', NULL),
(126, 'VIR20250621000126', 'paiement', 'Paiement facture FACT2025020126 - Commande CMD2025060126', 232565.26, '2025-03-13', 'valide', 'Virement bancaire', 126, 79, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-13 06:01:33', NULL),
(127, 'MM20250621000127', 'paiement', 'Paiement facture FACT2025050127 - Commande CMD2025060127', 197130.65, '2025-05-24', 'valide', 'MTN Mobile Money', 127, 131, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-24 17:13:43', NULL),
(128, 'OM20250621000128', 'paiement', 'Paiement facture FACT2025010128 - Commande CMD2025060128', 735602.37, '2025-02-10', 'valide', 'Orange Money', 128, 95, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-10 06:04:49', NULL),
(129, 'OM20250621000129', 'paiement', 'Paiement facture FACT2024110129 - Commande CMD2025060129', 317145.02, '2024-12-20', 'valide', 'Orange Money', 129, 93, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-20 13:15:45', NULL),
(130, 'VIR20250621000130', 'paiement', 'Paiement facture FACT2025040130 - Commande CMD2025060130', 421185.48, '2025-05-02', 'valide', 'Virement bancaire', 130, 176, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-02 07:45:40', NULL),
(131, 'CHQ20250621000131', 'paiement', 'Paiement facture FACT2025020131 - Commande CMD2025060131', 928248.46, '2025-03-07', 'valide', 'Chèque', 131, 56, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-07 23:19:48', NULL),
(132, 'CHQ20250621000132', 'paiement', 'Paiement facture FACT2025010132 - Commande CMD2025060132', 1187600.69, '2025-01-27', 'valide', 'Chèque', 132, 55, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-27 23:41:09', NULL),
(133, 'OM20250621000133', 'paiement', 'Paiement facture FACT2025010133 - Commande CMD2025060133', 355002.35, '2025-02-08', 'valide', 'Orange Money', 133, 64, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-08 11:25:20', NULL),
(134, 'OM20250621000134', 'paiement', 'Paiement facture FACT2025030134 - Commande CMD2025060134', 213160.86, '2025-04-05', 'valide', 'Orange Money', 134, 46, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-05 00:33:02', NULL),
(135, 'VIR20250621000135', 'paiement', 'Paiement facture FACT2025040135 - Commande CMD2025060135', 269728.93, '2025-04-21', 'valide', 'Virement bancaire', 135, 142, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-21 02:46:30', NULL),
(136, 'MM20250621000136', 'paiement', 'Paiement facture FACT2025030136 - Commande CMD2025060136', 119797.14, '2025-04-01', 'valide', 'MTN Mobile Money', 136, 23, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-01 11:41:03', NULL),
(137, 'OM20250621000137', 'paiement', 'Paiement facture FACT2024120137 - Commande CMD2025060137', 19953.22, '2024-12-22', 'valide', 'Orange Money', 137, 117, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-22 02:34:47', NULL),
(138, 'MM20250621000138', 'paiement', 'Paiement facture FACT2025020138 - Commande CMD2025060138', 82870.35, '2025-03-10', 'valide', 'MTN Mobile Money', 138, 24, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-10 14:26:38', NULL),
(139, 'MM20250621000139', 'paiement', 'Paiement facture FACT2025020139 - Commande CMD2025060139', 306725.90, '2025-03-24', 'valide', 'MTN Mobile Money', 139, 39, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-24 19:09:49', NULL),
(140, 'VIR20250621000140', 'paiement', 'Paiement facture FACT2025010140 - Commande CMD2025060140', 1172938.55, '2025-02-24', 'valide', 'Virement bancaire', 140, 77, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-24 10:19:18', NULL),
(141, 'OM20250621000141', 'paiement', 'Paiement facture FACT2025040141 - Commande CMD2025060141', 1054427.23, '2025-04-13', 'valide', 'Orange Money', 141, 158, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-13 16:54:11', NULL),
(142, 'VIR20250621000142', 'paiement', 'Paiement facture FACT2025040142 - Commande CMD2025060142', 379742.47, '2025-04-18', 'valide', 'Virement bancaire', 142, 18, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-18 04:18:40', NULL),
(143, 'OM20250621000143', 'paiement', 'Paiement facture FACT2025030143 - Commande CMD2025060143', 225989.99, '2025-04-06', 'valide', 'Orange Money', 143, 28, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-06 19:45:05', NULL),
(144, 'OM20250621000144', 'paiement', 'Paiement facture FACT2024120144 - Commande CMD2025060144', 53592.43, '2024-12-04', 'valide', 'Orange Money', 144, 179, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-04 19:19:18', NULL),
(145, 'VIR20250621000145', 'paiement', 'Paiement facture FACT2025050145 - Commande CMD2025060145', 780319.84, '2025-06-04', 'valide', 'Virement bancaire', 145, 196, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-04 02:52:52', NULL),
(146, 'OM20250621000146', 'paiement', 'Paiement facture FACT2025020146 - Commande CMD2025060146', 347126.71, '2025-02-23', 'valide', 'Orange Money', 146, 138, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-23 01:26:38', NULL),
(147, 'VIR20250621000147', 'paiement', 'Paiement facture FACT2025040147 - Commande CMD2025060147', 390319.44, '2025-05-03', 'valide', 'Virement bancaire', 147, 14, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-03 16:28:05', NULL),
(148, 'ESP20250621000148', 'paiement', 'Paiement facture FACT2025010148 - Commande CMD2025060148', 513176.61, '2025-01-24', 'valide', 'Espèces', 148, 106, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-24 04:07:38', NULL),
(149, 'VIR20250621000149', 'paiement', 'Paiement facture FACT2025010149 - Commande CMD2025060149', 284272.89, '2025-02-01', 'valide', 'Virement bancaire', 149, 97, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-01 21:31:12', NULL),
(150, 'ESP20250621000150', 'paiement', 'Paiement facture FACT2025030150 - Commande CMD2025060150', 1016389.31, '2025-03-24', 'valide', 'Espèces', 150, 69, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-24 22:50:34', NULL),
(151, 'CHQ20250621000151', 'paiement', 'Paiement facture FACT2024120151 - Commande CMD2025060151', 726395.19, '2025-01-02', 'valide', 'Chèque', 151, 161, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-02 00:30:34', NULL),
(152, 'VIR20250621000152', 'paiement', 'Paiement facture FACT2024110152 - Commande CMD2025060152', 390788.67, '2024-12-01', 'valide', 'Virement bancaire', 152, 12, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-01 13:23:56', NULL),
(153, 'VIR20250621000153', 'paiement', 'Paiement facture FACT2025020153 - Commande CMD2025060153', 90488.39, '2025-02-27', 'valide', 'Virement bancaire', 153, 104, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-27 22:12:34', NULL),
(154, 'MM20250621000154', 'paiement', 'Paiement facture FACT2024120154 - Commande CMD2025060154', 85504.98, '2024-12-27', 'valide', 'MTN Mobile Money', 154, 173, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-27 07:33:08', NULL),
(155, 'MM20250621000155', 'paiement', 'Paiement facture FACT2025050155 - Commande CMD2025060155', 947658.76, '2025-05-03', 'valide', 'MTN Mobile Money', 155, 115, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-03 06:51:15', NULL),
(156, 'VIR20250621000156', 'paiement', 'Paiement facture FACT2025050156 - Commande CMD2025060156', 528746.14, '2025-06-05', 'valide', 'Virement bancaire', 156, 175, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-05 11:35:42', NULL),
(157, 'OM20250621000157', 'paiement', 'Paiement facture FACT2025010157 - Commande CMD2025060157', 1081819.62, '2025-01-26', 'valide', 'Orange Money', 157, 100, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-26 04:14:19', NULL),
(158, 'MM20250621000158', 'paiement', 'Paiement facture FACT2025040158 - Commande CMD2025060158', 298601.74, '2025-04-16', 'valide', 'MTN Mobile Money', 158, 170, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-16 13:25:32', NULL),
(159, 'OM20250621000159', 'paiement', 'Paiement facture FACT2025030159 - Commande CMD2025060159', 83328.05, '2025-04-09', 'valide', 'Orange Money', 159, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-09 05:59:40', NULL),
(160, 'VIR20250621000160', 'paiement', 'Paiement facture FACT2025030160 - Commande CMD2025060160', 1241559.57, '2025-03-28', 'valide', 'Virement bancaire', 160, 80, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-28 21:21:41', NULL),
(161, 'MM20250621000161', 'paiement', 'Paiement facture FACT2025030161 - Commande CMD2025060161', 195077.13, '2025-04-06', 'valide', 'MTN Mobile Money', 161, 172, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-06 09:15:59', NULL),
(162, 'VIR20250621000162', 'paiement', 'Paiement facture FACT2025040162 - Commande CMD2025060162', 942022.84, '2025-05-11', 'valide', 'Virement bancaire', 162, 68, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-11 22:44:01', NULL),
(163, 'VIR20250621000163', 'paiement', 'Paiement facture FACT2025050163 - Commande CMD2025060163', 69764.01, '2025-06-09', 'valide', 'Virement bancaire', 163, 49, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-09 04:39:44', NULL),
(164, 'MM20250621000164', 'paiement', 'Paiement facture FACT2025010164 - Commande CMD2025060164', 523429.21, '2025-01-26', 'valide', 'MTN Mobile Money', 164, 187, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-26 14:04:10', NULL),
(165, 'VIR20250621000165', 'paiement', 'Paiement facture FACT2025050165 - Commande CMD2025060165', 229775.06, '2025-06-11', 'valide', 'Virement bancaire', 165, 19, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-11 19:17:27', NULL),
(166, 'VIR20250621000166', 'paiement', 'Paiement facture FACT2024110166 - Commande CMD2025060166', 504329.27, '2024-12-18', 'valide', 'Virement bancaire', 166, 91, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-18 14:08:33', NULL),
(167, 'VIR20250621000167', 'paiement', 'Paiement facture FACT2025050167 - Commande CMD2025060167', 804710.99, '2025-06-16', 'valide', 'Virement bancaire', 167, 92, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-16 21:50:43', NULL),
(168, 'OM20250621000168', 'paiement', 'Paiement facture FACT2025020168 - Commande CMD2025060168', 166661.57, '2025-02-14', 'valide', 'Orange Money', 168, 58, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-14 09:37:23', NULL),
(169, 'CHQ20250621000169', 'paiement', 'Paiement facture FACT2024110169 - Commande CMD2025060169', 685231.10, '2024-11-28', 'valide', 'Chèque', 169, 112, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-28 18:44:36', NULL),
(170, 'OM20250621000170', 'paiement', 'Paiement facture FACT2024120170 - Commande CMD2025060170', 22577.21, '2024-12-21', 'valide', 'Orange Money', 170, 74, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-21 02:34:16', NULL),
(171, 'OM20250621000171', 'paiement', 'Paiement facture FACT2025040171 - Commande CMD2025060171', 505870.34, '2025-05-04', 'valide', 'Orange Money', 171, 135, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-04 23:55:30', NULL),
(172, 'OM20250621000172', 'paiement', 'Paiement facture FACT2024120172 - Commande CMD2025060172', 90317.13, '2024-12-21', 'valide', 'Orange Money', 172, 48, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-21 16:44:19', NULL),
(173, 'VIR20250621000173', 'paiement', 'Paiement facture FACT2025060173 - Commande CMD2025060173', 352697.73, '2025-06-15', 'valide', 'Virement bancaire', 173, 102, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-15 03:52:17', NULL),
(174, 'VIR20250621000174', 'paiement', 'Paiement facture FACT2025020174 - Commande CMD2025060174', 220680.91, '2025-02-15', 'valide', 'Virement bancaire', 174, 159, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-15 08:51:15', NULL),
(175, 'VIR20250621000175', 'paiement', 'Paiement facture FACT2025020175 - Commande CMD2025060175', 262143.24, '2025-02-11', 'valide', 'Virement bancaire', 175, 110, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-11 14:58:19', NULL),
(176, 'VIR20250621000176', 'paiement', 'Paiement facture FACT2025030176 - Commande CMD2025060176', 39789.45, '2025-03-07', 'valide', 'Virement bancaire', 176, 111, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-07 03:44:20', NULL),
(177, 'OM20250621000177', 'paiement', 'Paiement facture FACT2024110177 - Commande CMD2025060177', 16950.42, '2024-11-29', 'valide', 'Orange Money', 177, 27, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-29 23:22:48', NULL),
(178, 'MM20250621000178', 'paiement', 'Paiement facture FACT2025050178 - Commande CMD2025060178', 125234.78, '2025-05-20', 'valide', 'MTN Mobile Money', 178, 157, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-20 13:33:45', NULL),
(179, 'VIR20250621000179', 'paiement', 'Paiement facture FACT2025040179 - Commande CMD2025060179', 13511.07, '2025-05-01', 'valide', 'Virement bancaire', 179, 15, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-01 10:46:29', NULL),
(180, 'MM20250621000180', 'paiement', 'Paiement facture FACT2025020180 - Commande CMD2025060180', 63642.01, '2025-02-13', 'valide', 'MTN Mobile Money', 180, 61, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-13 06:27:50', NULL),
(181, 'VIR20250621000181', 'paiement', 'Paiement facture FACT2025030181 - Commande CMD2025060181', 1153085.98, '2025-04-23', 'valide', 'Virement bancaire', 181, 186, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-23 12:51:09', NULL),
(182, 'VIR20250621000182', 'paiement', 'Paiement facture FACT2025050182 - Commande CMD2025060182', 283119.08, '2025-05-07', 'valide', 'Virement bancaire', 182, 3, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-07 03:36:58', NULL),
(183, 'VIR20250621000183', 'paiement', 'Paiement facture FACT2025040183 - Commande CMD2025060183', 522473.04, '2025-04-29', 'valide', 'Virement bancaire', 183, 148, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-29 03:53:24', NULL),
(184, 'VIR20250621000184', 'paiement', 'Paiement facture FACT2024110184 - Commande CMD2025060184', 111252.19, '2024-11-21', 'valide', 'Virement bancaire', 184, 54, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-21 12:17:38', NULL),
(185, 'MM20250621000185', 'paiement', 'Paiement facture FACT2024120185 - Commande CMD2025060185', 1027022.65, '2024-12-24', 'valide', 'MTN Mobile Money', 185, 51, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-24 12:59:10', NULL),
(186, 'MM20250621000186', 'paiement', 'Paiement facture FACT2025020186 - Commande CMD2025060186', 1144467.34, '2025-02-11', 'valide', 'MTN Mobile Money', 186, 185, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-11 14:00:16', NULL),
(187, 'VIR20250621000187', 'paiement', 'Paiement facture FACT2025040187 - Commande CMD2025060187', 164367.09, '2025-05-04', 'valide', 'Virement bancaire', 187, 168, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-04 09:01:33', NULL),
(188, 'VIR20250621000188', 'paiement', 'Paiement facture FACT2025030188 - Commande CMD2025060188', 139790.73, '2025-04-08', 'valide', 'Virement bancaire', 188, 20, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-08 11:02:23', NULL),
(189, 'OM20250621000189', 'paiement', 'Paiement facture FACT2024120189 - Commande CMD2025060189', 1450137.34, '2024-12-18', 'valide', 'Orange Money', 189, 192, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-18 16:21:16', NULL),
(190, 'OM20250621000190', 'paiement', 'Paiement facture FACT2025050190 - Commande CMD2025060190', 1872672.25, '2025-06-03', 'valide', 'Orange Money', 190, 94, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-03 03:44:16', NULL),
(191, 'VIR20250621000191', 'paiement', 'Paiement facture FACT2025010191 - Commande CMD2025060191', 11194.37, '2025-01-31', 'valide', 'Virement bancaire', 191, 17, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-31 18:09:33', NULL),
(192, 'VIR20250621000192', 'paiement', 'Paiement facture FACT2025050192 - Commande CMD2025060192', 321134.09, '2025-05-25', 'valide', 'Virement bancaire', 192, 123, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-25 18:26:54', NULL),
(193, 'OM20250621000193', 'paiement', 'Paiement facture FACT2025020193 - Commande CMD2025060193', 309519.12, '2025-03-22', 'valide', 'Orange Money', 193, 29, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-22 11:59:11', NULL),
(194, 'OM20250621000194', 'paiement', 'Paiement facture FACT2025030194 - Commande CMD2025060194', 733630.66, '2025-04-12', 'valide', 'Orange Money', 194, 130, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-12 05:32:31', NULL),
(195, 'VIR20250621000195', 'paiement', 'Paiement facture FACT2024110195 - Commande CMD2025060195', 1208545.36, '2024-12-13', 'valide', 'Virement bancaire', 195, 134, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-13 23:49:19', NULL),
(196, 'OM20250621000196', 'paiement', 'Paiement facture FACT2025050196 - Commande CMD2025060196', 25511.71, '2025-05-15', 'valide', 'Orange Money', 196, 149, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-15 00:58:27', NULL),
(197, 'VIR20250621000197', 'paiement', 'Paiement facture FACT2025030197 - Commande CMD2025060197', 880646.93, '2025-04-13', 'valide', 'Virement bancaire', 197, 152, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-13 12:11:53', NULL),
(198, 'VIR20250621000198', 'paiement', 'Paiement facture FACT2025010198 - Commande CMD2025060198', 425561.34, '2025-01-08', 'valide', 'Virement bancaire', 198, 128, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-08 07:54:59', NULL),
(199, 'ESP20250621000199', 'paiement', 'Paiement facture FACT2024120199 - Commande CMD2025060199', 1291503.83, '2025-01-10', 'valide', 'Espèces', 199, 116, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-10 01:40:09', NULL),
(200, 'VIR20250621000200', 'paiement', 'Paiement facture FACT2024110200 - Commande CMD2025060200', 52261.44, '2024-12-11', 'valide', 'Virement bancaire', 200, 144, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-11 12:36:15', NULL),
(201, 'VIR20250621000201', 'paiement', 'Paiement facture FACT2025040201 - Commande CMD2025060201', 385982.51, '2025-04-21', 'valide', 'Virement bancaire', 201, 133, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-21 14:37:16', NULL),
(202, 'MM20250621000202', 'paiement', 'Paiement facture FACT2025020202 - Commande CMD2025060202', 361111.15, '2025-02-23', 'valide', 'MTN Mobile Money', 202, 60, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-23 10:58:11', NULL),
(203, 'MM20250621000203', 'paiement', 'Paiement facture FACT2025010203 - Commande CMD2025060203', 92449.02, '2025-02-01', 'valide', 'MTN Mobile Money', 203, 154, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-01 09:41:40', NULL),
(204, 'OM20250621000204', 'paiement', 'Paiement facture FACT2025010204 - Commande CMD2025060204', 1466360.41, '2025-01-20', 'valide', 'Orange Money', 204, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-20 09:23:51', NULL),
(205, 'OM20250621000205', 'paiement', 'Paiement facture FACT2025040205 - Commande CMD2025060205', 148791.13, '2025-04-30', 'valide', 'Orange Money', 205, 177, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-30 14:17:02', NULL),
(206, 'VIR20250621000206', 'paiement', 'Paiement facture FACT2025040206 - Commande CMD2025060206', 23866.96, '2025-04-20', 'valide', 'Virement bancaire', 206, 82, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-20 17:12:29', NULL),
(207, 'ESP20250621000207', 'paiement', 'Paiement facture FACT2025020207 - Commande CMD2025060207', 565759.96, '2025-03-22', 'valide', 'Espèces', 207, 10, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-22 19:49:39', NULL),
(208, 'VIR20250621000208', 'paiement', 'Paiement facture FACT2025020208 - Commande CMD2025060208', 472234.89, '2025-02-04', 'valide', 'Virement bancaire', 208, 90, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-04 10:52:47', NULL),
(209, 'VIR20250621000209', 'paiement', 'Paiement facture FACT2025010209 - Commande CMD2025060209', 496839.06, '2025-02-01', 'valide', 'Virement bancaire', 209, 81, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-01 03:08:33', NULL),
(210, 'OM20250621000210', 'paiement', 'Paiement facture FACT2025020210 - Commande CMD2025060210', 153292.73, '2025-02-19', 'valide', 'Orange Money', 210, 59, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-19 06:59:54', NULL),
(211, 'MM20250621000211', 'paiement', 'Paiement facture FACT2024120211 - Commande CMD2025060211', 868237.73, '2024-12-20', 'valide', 'MTN Mobile Money', 211, 36, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-20 07:29:20', NULL),
(212, 'MM20250621000212', 'paiement', 'Paiement facture FACT2025030212 - Commande CMD2025060212', 574054.88, '2025-04-20', 'valide', 'MTN Mobile Money', 212, 151, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-20 15:01:08', NULL);
INSERT INTO `transactions` (`id`, `reference`, `type`, `description`, `montant`, `date_transaction`, `statut`, `mode_paiement`, `facture_id`, `client_id`, `employe_id`, `vehicule_id`, `categorie`, `quantite`, `prix_unitaire`, `periode`, `type_maintenance`, `actif`, `date_creation`, `date_modification`) VALUES
(213, 'VIR20250621000213', 'paiement', 'Paiement facture FACT2025020213 - Commande CMD2025060213', 715797.86, '2025-02-23', 'valide', 'Virement bancaire', 213, 98, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-23 07:42:06', NULL),
(214, 'VIR20250621000214', 'paiement', 'Paiement facture FACT2025040214 - Commande CMD2025060214', 170111.17, '2025-04-03', 'valide', 'Virement bancaire', 214, 76, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-03 02:41:10', NULL),
(215, 'ESP20250621000215', 'paiement', 'Paiement facture FACT2024120215 - Commande CMD2025060215', 71861.89, '2025-01-07', 'valide', 'Espèces', 215, 35, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-07 23:40:14', NULL),
(216, 'ESP20250621000216', 'paiement', 'Paiement facture FACT2025030216 - Commande CMD2025060216', 962371.96, '2025-04-06', 'valide', 'Espèces', 216, 32, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-06 17:41:06', NULL),
(217, 'MM20250621000217', 'paiement', 'Paiement facture FACT2024120217 - Commande CMD2025060217', 277550.18, '2024-12-17', 'valide', 'MTN Mobile Money', 217, 37, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-17 01:15:00', NULL),
(218, 'OM20250621000218', 'paiement', 'Paiement facture FACT2025010218 - Commande CMD2025060218', 84587.30, '2025-02-04', 'valide', 'Orange Money', 218, 78, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-04 03:40:03', NULL),
(219, 'VIR20250621000219', 'paiement', 'Paiement facture FACT2025010219 - Commande CMD2025060219', 111142.39, '2025-01-29', 'valide', 'Virement bancaire', 219, 191, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-29 04:17:51', NULL),
(220, 'VIR20250621000220', 'paiement', 'Paiement facture FACT2025040220 - Commande CMD2025060220', 622146.41, '2025-04-30', 'valide', 'Virement bancaire', 220, 83, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-30 17:01:00', NULL),
(221, 'VIR20250621000221', 'paiement', 'Paiement facture FACT2025040221 - Commande CMD2025060221', 348945.35, '2025-04-28', 'valide', 'Virement bancaire', 221, 7, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-28 08:26:34', NULL),
(222, 'MM20250621000222', 'paiement', 'Paiement facture FACT2024110222 - Commande CMD2025060222', 23339.98, '2024-12-06', 'valide', 'MTN Mobile Money', 222, 122, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-06 22:54:39', NULL),
(223, 'VIR20250621000223', 'paiement', 'Paiement facture FACT2025010223 - Commande CMD2025060223', 1094046.69, '2025-02-07', 'valide', 'Virement bancaire', 223, 109, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-07 12:29:25', NULL),
(224, 'OM20250621000224', 'paiement', 'Paiement facture FACT2025050224 - Commande CMD2025060224', 1239061.83, '2025-05-13', 'valide', 'Orange Money', 224, 47, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-13 10:09:44', NULL),
(225, 'ESP20250621000225', 'paiement', 'Paiement facture FACT2025010225 - Commande CMD2025060225', 939202.11, '2025-02-07', 'valide', 'Espèces', 225, 125, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-07 13:52:17', NULL),
(226, 'VIR20250621000226', 'paiement', 'Paiement facture FACT2025010226 - Commande CMD2025060226', 15982.86, '2025-02-05', 'valide', 'Virement bancaire', 226, 31, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-05 19:49:59', NULL),
(227, 'MM20250621000227', 'paiement', 'Paiement facture FACT2025030227 - Commande CMD2025060227', 255952.56, '2025-04-02', 'valide', 'MTN Mobile Money', 227, 33, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-02 01:11:46', NULL),
(228, 'VIR20250621000228', 'paiement', 'Paiement facture FACT2025010228 - Commande CMD2025060228', 212982.63, '2025-01-19', 'valide', 'Virement bancaire', 228, 124, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-19 16:08:56', NULL),
(229, 'CHQ20250621000229', 'paiement', 'Paiement facture FACT2025030229 - Commande CMD2025060229', 128790.49, '2025-03-17', 'valide', 'Chèque', 229, 193, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-17 03:28:58', NULL),
(230, 'VIR20250621000230', 'paiement', 'Paiement facture FACT2024110230 - Commande CMD2025060230', 141517.61, '2024-12-15', 'valide', 'Virement bancaire', 230, 21, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-15 15:27:55', NULL),
(231, 'VIR20250621000231', 'paiement', 'Paiement facture FACT2025040231 - Commande CMD2025060231', 2189745.89, '2025-05-05', 'valide', 'Virement bancaire', 231, 127, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-05 06:26:37', NULL),
(232, 'VIR20250621000232', 'paiement', 'Paiement facture FACT2024110232 - Commande CMD2025060232', 612518.06, '2024-12-16', 'valide', 'Virement bancaire', 232, 52, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-16 02:48:50', NULL),
(233, 'ESP20250621000233', 'paiement', 'Paiement facture FACT2025040233 - Commande CMD2025060233', 631300.42, '2025-05-08', 'valide', 'Espèces', 233, 87, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-08 09:47:04', NULL),
(234, 'VIR20250621000234', 'paiement', 'Paiement facture FACT2025030234 - Commande CMD2025060234', 229203.32, '2025-03-28', 'valide', 'Virement bancaire', 234, 194, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-28 08:49:04', NULL),
(235, 'VIR20250621000235', 'paiement', 'Paiement facture FACT2025050235 - Commande CMD2025060235', 399875.93, '2025-05-26', 'valide', 'Virement bancaire', 235, 150, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-26 20:48:33', NULL),
(236, 'VIR20250621000236', 'paiement', 'Paiement facture FACT2025020236 - Commande CMD2025060236', 140475.45, '2025-02-17', 'valide', 'Virement bancaire', 236, 88, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-17 13:38:56', NULL),
(237, 'ESP20250621000237', 'paiement', 'Paiement facture FACT2024120237 - Commande CMD2025060237', 160407.58, '2025-01-02', 'valide', 'Espèces', 237, 184, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-02 14:07:16', NULL),
(238, 'ESP20250621000238', 'paiement', 'Paiement facture FACT2025030238 - Commande CMD2025060238', 73752.62, '2025-04-02', 'valide', 'Espèces', 238, 41, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-02 08:58:08', NULL),
(239, 'VIR20250621000239', 'paiement', 'Paiement facture FACT2025040239 - Commande CMD2025060239', 180571.29, '2025-05-06', 'valide', 'Virement bancaire', 239, 22, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-06 00:22:37', NULL),
(240, 'OM20250621000240', 'paiement', 'Paiement facture FACT2025020240 - Commande CMD2025060240', 67396.01, '2025-03-04', 'valide', 'Orange Money', 240, 145, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-04 20:03:10', NULL),
(241, 'OM20250621000241', 'paiement', 'Paiement facture FACT2025030241 - Commande CMD2025060241', 1104477.32, '2025-03-31', 'valide', 'Orange Money', 241, 146, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-31 14:25:52', NULL),
(242, 'VIR20250621000242', 'paiement', 'Paiement facture FACT2024110242 - Commande CMD2025060242', 1366992.88, '2024-11-29', 'valide', 'Virement bancaire', 242, 26, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-29 01:43:44', NULL),
(243, 'VIR20250621000243', 'paiement', 'Paiement facture FACT2025030243 - Commande CMD2025060243', 12069.46, '2025-03-30', 'valide', 'Virement bancaire', 243, 164, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-30 09:29:13', NULL),
(244, 'CHQ20250621000244', 'paiement', 'Paiement facture FACT2024110244 - Commande CMD2025060244', 1485179.07, '2024-12-26', 'valide', 'Chèque', 244, 156, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-26 07:00:22', NULL),
(245, 'ESP20250621000245', 'paiement', 'Paiement facture FACT2025020245 - Commande CMD2025060245', 52876.54, '2025-02-28', 'valide', 'Espèces', 245, 40, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-28 13:21:20', NULL),
(246, 'OM20250621000246', 'paiement', 'Paiement facture FACT2025040246 - Commande CMD2025060246', 520897.11, '2025-04-26', 'valide', 'Orange Money', 246, 160, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-26 15:04:42', NULL),
(247, 'OM20250621000247', 'paiement', 'Paiement facture FACT2025050247 - Commande CMD2025060247', 45234.67, '2025-05-10', 'valide', 'Orange Money', 247, 86, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-10 12:18:53', NULL),
(248, 'VIR20250621000248', 'paiement', 'Paiement facture FACT2025030248 - Commande CMD2025060248', 613001.65, '2025-04-02', 'valide', 'Virement bancaire', 248, 114, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-02 23:52:53', NULL),
(249, 'OM20250621000249', 'paiement', 'Paiement facture FACT2024110249 - Commande CMD2025060249', 309201.89, '2024-11-22', 'valide', 'Orange Money', 249, 141, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-22 06:01:48', NULL),
(250, 'VIR20250621000250', 'paiement', 'Paiement facture FACT2025010250 - Commande CMD2025060250', 662212.05, '2025-02-17', 'valide', 'Virement bancaire', 250, 182, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-17 00:23:03', NULL),
(251, 'OM20250621000251', 'paiement', 'Paiement facture FACT2025030251 - Commande CMD2025060251', 285294.39, '2025-04-19', 'valide', 'Orange Money', 251, 65, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-19 10:43:00', NULL),
(252, 'VIR20250621000252', 'paiement', 'Paiement facture FACT2024120252 - Commande CMD2025060252', 1096559.11, '2024-12-16', 'valide', 'Virement bancaire', 252, 53, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-16 14:42:36', NULL),
(253, 'MM20250621000253', 'paiement', 'Paiement facture FACT2025040253 - Commande CMD2025060253', 163663.17, '2025-04-30', 'valide', 'MTN Mobile Money', 253, 73, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-30 23:25:02', NULL),
(254, 'OM20250621000254', 'paiement', 'Paiement facture FACT2025020254 - Commande CMD2025060254', 154000.99, '2025-02-27', 'valide', 'Orange Money', 254, 166, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-27 06:23:57', NULL),
(255, 'CHQ20250621000255', 'paiement', 'Paiement facture FACT2025050255 - Commande CMD2025060255', 40262.36, '2025-06-01', 'valide', 'Chèque', 255, 16, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-01 03:31:10', NULL),
(256, 'VIR20250621000256', 'paiement', 'Paiement facture FACT2025040256 - Commande CMD2025060256', 392512.53, '2025-05-02', 'valide', 'Virement bancaire', 256, 5, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-02 02:10:25', NULL),
(257, 'ESP20250621000257', 'paiement', 'Paiement facture FACT2025050257 - Commande CMD2025060257', 526328.51, '2025-05-25', 'valide', 'Espèces', 257, 189, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-25 23:54:57', NULL),
(258, 'VIR20250621000258', 'paiement', 'Paiement facture FACT2024120258 - Commande CMD2025060258', 462229.73, '2024-12-17', 'valide', 'Virement bancaire', 258, 75, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-17 09:07:09', NULL),
(259, 'VIR20250621000259', 'paiement', 'Paiement facture FACT2025010259 - Commande CMD2025060259', 14325.02, '2025-01-30', 'valide', 'Virement bancaire', 259, 108, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-30 13:44:35', NULL),
(260, 'ESP20250621000260', 'paiement', 'Paiement facture FACT2025020260 - Commande CMD2025060260', 630667.41, '2025-03-13', 'valide', 'Espèces', 260, 43, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-13 17:36:44', NULL),
(261, 'VIR20250621000261', 'paiement', 'Paiement facture FACT2024110261 - Commande CMD2025060261', 553922.00, '2024-11-29', 'valide', 'Virement bancaire', 261, 126, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-29 16:54:35', NULL),
(262, 'CHQ20250621000262', 'paiement', 'Paiement facture FACT2025010262 - Commande CMD2025060262', 100644.01, '2025-02-01', 'valide', 'Chèque', 262, 188, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-01 15:40:25', NULL),
(263, 'VIR20250621000263', 'paiement', 'Paiement facture FACT2025020263 - Commande CMD2025060263', 113227.93, '2025-02-25', 'valide', 'Virement bancaire', 263, 70, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-25 17:33:07', NULL),
(264, 'VIR20250621000264', 'paiement', 'Paiement facture FACT2024120264 - Commande CMD2025060264', 227814.68, '2025-01-01', 'valide', 'Virement bancaire', 264, 9, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-01 22:45:16', NULL),
(265, 'MM20250621000265', 'paiement', 'Paiement facture FACT2025040265 - Commande CMD2025060265', 8232.66, '2025-05-02', 'valide', 'MTN Mobile Money', 265, 181, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-02 06:31:46', NULL),
(266, 'VIR20250621000266', 'paiement', 'Paiement facture FACT2025030266 - Commande CMD2025060266', 483416.65, '2025-04-09', 'valide', 'Virement bancaire', 266, 57, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-09 21:17:34', NULL),
(267, 'VIR20250621000267', 'paiement', 'Paiement facture FACT2025010267 - Commande CMD2025060267', 1053296.52, '2025-01-28', 'valide', 'Virement bancaire', 267, 167, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-28 07:23:17', NULL),
(268, 'VIR20250621000268', 'paiement', 'Paiement facture FACT2025020268 - Commande CMD2025060268', 34181.78, '2025-02-27', 'valide', 'Virement bancaire', 268, 137, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-27 22:59:36', NULL),
(269, 'OM20250621000269', 'paiement', 'Paiement facture FACT2025050269 - Commande CMD2025060269', 70750.86, '2025-05-16', 'valide', 'Orange Money', 269, 63, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-16 19:29:48', NULL),
(270, 'VIR20250621000270', 'paiement', 'Paiement facture FACT2025040270 - Commande CMD2025060270', 143414.04, '2025-04-30', 'valide', 'Virement bancaire', 270, 129, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-30 13:02:39', NULL),
(271, 'OM20250621000271', 'paiement', 'Paiement facture FACT2025030271 - Commande CMD2025060271', 445798.61, '2025-03-21', 'valide', 'Orange Money', 271, 132, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-21 06:57:24', NULL),
(272, 'MM20250621000272', 'paiement', 'Paiement facture FACT2025040272 - Commande CMD2025060272', 484699.82, '2025-04-09', 'valide', 'MTN Mobile Money', 272, 136, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-09 20:31:26', NULL),
(273, 'VIR20250621000273', 'paiement', 'Paiement facture FACT2025060273 - Commande CMD2025060273', 1643242.21, '2025-06-02', 'valide', 'Virement bancaire', 273, 178, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-02 21:43:52', NULL),
(274, 'OM20250621000274', 'paiement', 'Paiement facture FACT2025010274 - Commande CMD2025060274', 410417.43, '2025-02-03', 'valide', 'Orange Money', 274, 85, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-03 08:33:58', NULL),
(275, 'VIR20250621000275', 'paiement', 'Paiement facture FACT2025050275 - Commande CMD2025060275', 603896.62, '2025-05-24', 'valide', 'Virement bancaire', 275, 11, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-24 14:20:01', NULL),
(276, 'VIR20250621000276', 'paiement', 'Paiement facture FACT2024110276 - Commande CMD2025060276', 173523.20, '2024-12-12', 'valide', 'Virement bancaire', 276, 105, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-12 23:25:56', NULL),
(277, 'OM20250621000277', 'paiement', 'Paiement facture FACT2025010277 - Commande CMD2025060277', 930402.36, '2025-01-26', 'valide', 'Orange Money', 277, 42, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-26 04:55:57', NULL),
(278, 'MM20250621000278', 'paiement', 'Paiement facture FACT2024120278 - Commande CMD2025060278', 124303.58, '2025-01-07', 'valide', 'MTN Mobile Money', 278, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-07 13:40:54', NULL),
(279, 'CHQ20250621000279', 'paiement', 'Paiement facture FACT2025020279 - Commande CMD2025060279', 457956.38, '2025-02-25', 'valide', 'Chèque', 279, 174, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-25 14:25:42', NULL),
(280, 'MM20250621000280', 'paiement', 'Paiement facture FACT2024120280 - Commande CMD2025060280', 267479.93, '2025-01-04', 'valide', 'MTN Mobile Money', 280, 62, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-04 15:51:19', NULL),
(281, 'CHQ20250621000281', 'paiement', 'Paiement facture FACT2025020281 - Commande CMD2025060281', 35750.05, '2025-02-27', 'valide', 'Chèque', 281, 165, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-27 07:16:15', NULL),
(282, 'VIR20250621000282', 'paiement', 'Paiement facture FACT2025040282 - Commande CMD2025060282', 1034309.29, '2025-05-05', 'valide', 'Virement bancaire', 282, 183, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-05 13:00:53', NULL),
(283, 'OM20250621000283', 'paiement', 'Paiement facture FACT2024110283 - Commande CMD2025060283', 670039.95, '2024-11-20', 'valide', 'Orange Money', 283, 45, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-11-20 16:57:38', NULL),
(284, 'VIR20250621000284', 'paiement', 'Paiement facture FACT2024120284 - Commande CMD2025060284', 84094.78, '2024-12-02', 'valide', 'Virement bancaire', 284, 6, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-02 09:15:36', NULL),
(285, 'VIR20250621000285', 'paiement', 'Paiement facture FACT2025050285 - Commande CMD2025060285', 134056.48, '2025-06-08', 'valide', 'Virement bancaire', 285, 38, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-08 20:44:09', NULL),
(286, 'VIR20250621000286', 'paiement', 'Paiement facture FACT2025040286 - Commande CMD2025060286', 190571.22, '2025-04-25', 'valide', 'Virement bancaire', 286, 171, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-25 19:39:43', NULL),
(287, 'CHQ20250621000287', 'paiement', 'Paiement facture FACT2025030287 - Commande CMD2025060287', 976453.79, '2025-04-19', 'valide', 'Chèque', 287, 99, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-19 11:10:18', NULL),
(288, 'MM20250621000288', 'paiement', 'Paiement facture FACT2025010288 - Commande CMD2025060288', 1195306.91, '2025-01-31', 'valide', 'MTN Mobile Money', 288, 67, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-31 03:49:51', NULL),
(289, 'VIR20250621000289', 'paiement', 'Paiement facture FACT2025050289 - Commande CMD2025060289', 363086.55, '2025-06-10', 'valide', 'Virement bancaire', 289, 66, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-10 11:52:20', NULL),
(290, 'VIR20250621000290', 'paiement', 'Paiement facture FACT2024110290 - Commande CMD2025060290', 1237211.04, '2024-12-06', 'valide', 'Virement bancaire', 290, 50, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-06 13:06:56', NULL),
(291, 'MM20250621000291', 'paiement', 'Paiement facture FACT2024110291 - Commande CMD2025060291', 408505.73, '2024-12-23', 'valide', 'MTN Mobile Money', 291, 195, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-23 02:32:17', NULL),
(292, 'VIR20250621000292', 'paiement', 'Paiement facture FACT2025010292 - Commande CMD2025060292', 39450.72, '2025-01-16', 'valide', 'Virement bancaire', 292, 25, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-16 18:06:32', NULL),
(293, 'OM20250621000293', 'paiement', 'Paiement facture FACT2025020293 - Commande CMD2025060293', 508015.92, '2025-02-17', 'valide', 'Orange Money', 293, 103, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-17 07:03:19', NULL),
(294, 'VIR20250621000294', 'paiement', 'Paiement facture FACT2025020294 - Commande CMD2025060294', 805551.95, '2025-03-11', 'valide', 'Virement bancaire', 294, 155, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-11 07:06:15', NULL),
(295, 'OM20250621000295', 'paiement', 'Paiement facture FACT2025020295 - Commande CMD2025060295', 320897.06, '2025-03-09', 'valide', 'Orange Money', 295, 44, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-09 08:53:19', NULL),
(296, 'VIR20250621000296', 'paiement', 'Paiement facture FACT2024120296 - Commande CMD2025060296', 563169.02, '2025-01-11', 'valide', 'Virement bancaire', 296, 107, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-11 13:32:18', NULL),
(297, 'VIR20250621000297', 'paiement', 'Paiement facture FACT2024120297 - Commande CMD2025060297', 57915.63, '2024-12-18', 'valide', 'Virement bancaire', 297, 169, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-18 07:58:48', NULL),
(298, 'VIR20250621000298', 'paiement', 'Paiement facture FACT2025030298 - Commande CMD2025060298', 432401.35, '2025-03-11', 'valide', 'Virement bancaire', 298, 180, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-11 19:23:59', NULL),
(299, 'OM20250621000299', 'paiement', 'Paiement facture FACT2024120299 - Commande CMD2025060299', 611651.99, '2025-01-07', 'valide', 'Orange Money', 299, 71, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-07 13:18:38', NULL),
(300, 'MM20250621000300', 'paiement', 'Paiement facture FACT2025010300 - Commande CMD2025060300', 134374.74, '2025-01-22', 'valide', 'MTN Mobile Money', 300, 147, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-22 16:17:08', NULL),
(301, 'MM20250621000301', 'paiement', 'Paiement facture FACT2025030301 - Commande CMD2025060301', 91688.43, '2025-03-29', 'valide', 'MTN Mobile Money', 301, 34, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-29 12:14:42', NULL),
(302, 'ESP20250621000302', 'paiement', 'Paiement facture FACT2025060302 - Commande CMD2025060302', 701039.68, '2025-06-13', 'valide', 'Espèces', 302, 96, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-13 16:08:59', NULL),
(303, 'VIR20250621000303', 'paiement', 'Paiement facture FACT2025040303 - Commande CMD2025060303', 250485.49, '2025-05-07', 'valide', 'Virement bancaire', 303, 118, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-07 20:39:42', NULL),
(304, 'OM20250621000304', 'paiement', 'Paiement facture FACT2025040304 - Commande CMD2025060304', 1033535.47, '2025-05-07', 'valide', 'Orange Money', 304, 89, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-07 00:46:32', NULL),
(305, 'VIR20250621000305', 'paiement', 'Paiement facture FACT2025050305 - Commande CMD2025060305', 186521.99, '2025-05-16', 'valide', 'Virement bancaire', 305, 139, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-16 16:09:18', NULL),
(306, 'OM20250621000306', 'paiement', 'Paiement facture FACT2025030306 - Commande CMD2025060306', 99041.40, '2025-04-14', 'valide', 'Orange Money', 306, 113, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-14 11:08:34', NULL),
(307, 'OM20250621000307', 'paiement', 'Paiement facture FACT2025030307 - Commande CMD2025060307', 205792.54, '2025-03-29', 'valide', 'Orange Money', 307, 8, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-29 10:06:35', NULL),
(308, 'VIR20250621000308', 'paiement', 'Paiement facture FACT2025010308 - Commande CMD2025060308', 11326.58, '2025-01-28', 'valide', 'Virement bancaire', 308, 72, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-28 19:53:32', NULL),
(309, 'VIR20250621000309', 'paiement', 'Paiement facture FACT2025020309 - Commande CMD2025060309', 304841.05, '2025-02-16', 'valide', 'Virement bancaire', 309, 84, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-16 23:24:07', NULL),
(310, 'VIR20250621000310', 'paiement', 'Paiement facture FACT2025010310 - Commande CMD2025060310', 338424.83, '2025-02-14', 'valide', 'Virement bancaire', 310, 120, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-14 21:48:53', NULL),
(311, 'VIR20250621000311', 'paiement', 'Paiement facture FACT2025040311 - Commande CMD2025060311', 1458453.95, '2025-05-08', 'valide', 'Virement bancaire', 311, 140, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-08 18:34:25', NULL),
(312, 'VIR20250621000312', 'paiement', 'Paiement facture FACT2024120312 - Commande CMD2025060312', 151815.33, '2024-12-15', 'valide', 'Virement bancaire', 312, 13, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-15 08:43:34', NULL),
(313, 'VIR20250621000313', 'paiement', 'Paiement facture FACT2025040313 - Commande CMD2025060313', 599935.75, '2025-04-05', 'valide', 'Virement bancaire', 313, 153, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-05 21:52:35', NULL),
(314, 'VIR20250621000314', 'paiement', 'Paiement facture FACT2025010314 - Commande CMD2025060314', 56164.02, '2025-01-26', 'valide', 'Virement bancaire', 314, 30, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-26 14:18:53', NULL),
(315, 'OM20250621000315', 'paiement', 'Paiement facture FACT2025030315 - Commande CMD2025060315', 163698.28, '2025-04-13', 'valide', 'Orange Money', 315, 143, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-13 14:49:33', NULL),
(316, 'VIR20250621000316', 'paiement', 'Paiement facture FACT2024120316 - Commande CMD2025060316', 388948.85, '2025-01-15', 'valide', 'Virement bancaire', 316, 190, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-15 21:03:19', NULL),
(317, 'OM20250621000317', 'paiement', 'Paiement facture FACT2025020317 - Commande CMD2025060317', 133484.61, '2025-03-07', 'valide', 'Orange Money', 317, 163, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-07 16:58:34', NULL),
(318, 'OM20250621000318', 'paiement', 'Paiement facture FACT2024120318 - Commande CMD2025060318', 754663.47, '2024-12-25', 'valide', 'Orange Money', 318, 119, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-25 05:54:35', NULL),
(319, 'VIR20250621000319', 'paiement', 'Paiement facture FACT2025030319 - Commande CMD2025060319', 1199986.51, '2025-04-06', 'valide', 'Virement bancaire', 319, 101, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-06 05:59:45', NULL),
(320, 'VIR20250621000320', 'paiement', 'Paiement facture FACT2025040320 - Commande CMD2025060320', 513201.71, '2025-05-13', 'valide', 'Virement bancaire', 320, 79, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-13 10:29:50', NULL),
(321, 'ESP20250621000321', 'paiement', 'Paiement facture FACT2025010321 - Commande CMD2025060321', 1210485.75, '2025-01-22', 'valide', 'Espèces', 321, 131, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-22 04:39:17', NULL),
(322, 'OM20250621000322', 'paiement', 'Paiement facture FACT2025020322 - Commande CMD2025060322', 566643.80, '2025-03-10', 'valide', 'Orange Money', 322, 95, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-10 19:19:52', NULL),
(323, 'VIR20250621000323', 'paiement', 'Paiement facture FACT2025020323 - Commande CMD2025060323', 488582.00, '2025-02-23', 'valide', 'Virement bancaire', 323, 93, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-23 09:02:51', NULL),
(324, 'VIR20250621000324', 'paiement', 'Paiement facture FACT2024110324 - Commande CMD2025060324', 1165205.64, '2024-12-15', 'valide', 'Virement bancaire', 324, 176, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-15 13:55:41', NULL),
(325, 'OM20250621000325', 'paiement', 'Paiement facture FACT2024120325 - Commande CMD2025060325', 314637.87, '2025-01-05', 'valide', 'Orange Money', 325, 56, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-05 03:33:46', NULL),
(326, 'ESP20250621000326', 'paiement', 'Paiement facture FACT2025060326 - Commande CMD2025060326', 538006.85, '2025-06-12', 'valide', 'Espèces', 326, 55, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-12 11:04:06', NULL),
(327, 'OM20250621000327', 'paiement', 'Paiement facture FACT2024110327 - Commande CMD2025060327', 616999.37, '2024-12-02', 'valide', 'Orange Money', 327, 64, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-02 12:22:01', NULL),
(328, 'MM20250621000328', 'paiement', 'Paiement facture FACT2025010328 - Commande CMD2025060328', 1251933.48, '2025-01-28', 'valide', 'MTN Mobile Money', 328, 46, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-28 17:02:12', NULL),
(329, 'VIR20250621000329', 'paiement', 'Paiement facture FACT2025020329 - Commande CMD2025060329', 158754.18, '2025-03-16', 'valide', 'Virement bancaire', 329, 142, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-16 01:52:35', NULL),
(330, 'VIR20250621000330', 'paiement', 'Paiement facture FACT2025010330 - Commande CMD2025060330', 21725.45, '2025-01-30', 'valide', 'Virement bancaire', 330, 23, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-30 15:50:17', NULL),
(331, 'MM20250621000331', 'paiement', 'Paiement facture FACT2024120331 - Commande CMD2025060331', 559382.81, '2024-12-31', 'valide', 'MTN Mobile Money', 331, 117, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-31 06:16:19', NULL),
(332, 'OM20250621000332', 'paiement', 'Paiement facture FACT2024120332 - Commande CMD2025060332', 377662.20, '2025-01-20', 'valide', 'Orange Money', 332, 24, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-20 05:56:36', NULL),
(333, 'OM20250621000333', 'paiement', 'Paiement facture FACT2024120333 - Commande CMD2025060333', 130013.63, '2024-12-11', 'valide', 'Orange Money', 333, 39, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-11 22:47:32', NULL),
(334, 'MM20250621000334', 'paiement', 'Paiement facture FACT2025030334 - Commande CMD2025060334', 286051.16, '2025-04-07', 'valide', 'MTN Mobile Money', 334, 77, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-07 00:17:47', NULL),
(335, 'OM20250621000335', 'paiement', 'Paiement facture FACT2025030335 - Commande CMD2025060335', 306607.90, '2025-04-11', 'valide', 'Orange Money', 335, 158, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-11 17:52:57', NULL),
(336, 'VIR20250621000336', 'paiement', 'Paiement facture FACT2024120336 - Commande CMD2025060336', 174795.05, '2025-01-06', 'valide', 'Virement bancaire', 336, 18, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-06 16:11:56', NULL),
(337, 'MM20250621000337', 'paiement', 'Paiement facture FACT2025030337 - Commande CMD2025060337', 787486.16, '2025-04-08', 'valide', 'MTN Mobile Money', 337, 28, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-08 14:39:00', NULL),
(338, 'VIR20250621000338', 'paiement', 'Paiement facture FACT2025030338 - Commande CMD2025060338', 26694.80, '2025-03-09', 'valide', 'Virement bancaire', 338, 179, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-09 07:20:21', NULL),
(339, 'OM20250621000339', 'paiement', 'Paiement facture FACT2024110339 - Commande CMD2025060339', 215687.23, '2024-12-16', 'valide', 'Orange Money', 339, 196, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-16 09:29:07', NULL),
(340, 'VIR20250621000340', 'paiement', 'Paiement facture FACT2024110340 - Commande CMD2025060340', 102893.40, '2024-12-10', 'valide', 'Virement bancaire', 340, 138, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-10 19:38:19', NULL),
(341, 'MM20250621000341', 'paiement', 'Paiement facture FACT2025010341 - Commande CMD2025060341', 261445.33, '2025-02-01', 'valide', 'MTN Mobile Money', 341, 14, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-01 08:44:19', NULL),
(342, 'OM20250621000342', 'paiement', 'Paiement facture FACT2025050342 - Commande CMD2025060342', 563270.56, '2025-05-17', 'valide', 'Orange Money', 342, 106, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-17 20:18:21', NULL),
(343, 'ESP20250621000343', 'paiement', 'Paiement facture FACT2025010343 - Commande CMD2025060343', 66773.98, '2025-02-10', 'valide', 'Espèces', 343, 97, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-10 01:23:36', NULL),
(344, 'ESP20250621000344', 'paiement', 'Paiement facture FACT2025030344 - Commande CMD2025060344', 176835.68, '2025-03-12', 'valide', 'Espèces', 344, 69, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-12 03:33:41', NULL),
(345, 'VIR20250621000345', 'paiement', 'Paiement facture FACT2025050345 - Commande CMD2025060345', 444548.36, '2025-06-19', 'valide', 'Virement bancaire', 345, 161, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-06-19 14:23:33', NULL),
(346, 'VIR20250621000346', 'paiement', 'Paiement facture FACT2025020346 - Commande CMD2025060346', 170107.96, '2025-03-19', 'valide', 'Virement bancaire', 346, 12, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-03-19 00:48:47', NULL),
(347, 'ESP20250621000347', 'paiement', 'Paiement facture FACT2025040347 - Commande CMD2025060347', 12941.57, '2025-04-18', 'valide', 'Espèces', 347, 104, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-18 18:22:00', NULL),
(348, 'OM20250621000348', 'paiement', 'Paiement facture FACT2025040348 - Commande CMD2025060348', 532671.42, '2025-04-24', 'valide', 'Orange Money', 348, 173, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-24 08:21:30', NULL),
(349, 'VIR20250621000349', 'paiement', 'Paiement facture FACT2024120349 - Commande CMD2025060349', 55591.23, '2024-12-26', 'valide', 'Virement bancaire', 349, 115, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2024-12-26 06:35:57', NULL),
(350, 'VIR20250621000350', 'paiement', 'Paiement facture FACT2025020350 - Commande CMD2025060350', 623125.85, '2025-02-28', 'valide', 'Virement bancaire', 350, 175, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-28 02:17:42', NULL),
(351, 'VIR20250621000351', 'paiement', 'Paiement facture FACT2025040351 - Commande CMD2025060351', 1240531.17, '2025-05-08', 'valide', 'Virement bancaire', 351, 100, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-08 12:45:54', NULL),
(352, 'OM20250621000352', 'paiement', 'Paiement facture FACT2025010352 - Commande CMD2025060352', 127408.02, '2025-01-11', 'valide', 'Orange Money', 352, 170, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-11 07:11:28', NULL),
(353, 'VIR20250621000353', 'paiement', 'Paiement facture FACT2025040353 - Commande CMD2025060353', 131904.02, '2025-04-30', 'valide', 'Virement bancaire', 353, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-30 21:10:52', NULL),
(354, 'ESP20250621000354', 'paiement', 'Paiement facture FACT2025040354 - Commande CMD2025060354', 94810.96, '2025-05-21', 'valide', 'Espèces', 354, 80, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-21 01:38:47', NULL),
(355, 'VIR20250621000355', 'paiement', 'Paiement facture FACT2025050355 - Commande CMD2025060355', 486162.77, '2025-05-09', 'valide', 'Virement bancaire', 355, 172, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-05-09 12:47:26', NULL),
(356, 'VIR20250621000356', 'paiement', 'Paiement facture FACT2025040356 - Commande CMD2025060356', 534750.87, '2025-04-09', 'valide', 'Virement bancaire', 356, 68, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-04-09 05:27:52', NULL),
(357, 'VIR20250621000357', 'paiement', 'Paiement facture FACT2024120357 - Commande CMD2025060357', 324831.49, '2025-01-13', 'valide', 'Virement bancaire', 357, 49, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-13 02:43:31', NULL),
(358, 'VIR20250621000358', 'paiement', 'Paiement facture FACT2024120358 - Commande CMD2025060358', 32060.54, '2025-01-13', 'valide', 'Virement bancaire', 358, 187, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-01-13 03:18:14', NULL),
(359, 'VIR20250621000359', 'paiement', 'Paiement facture FACT2025010359 - Commande CMD2025060359', 551268.33, '2025-02-06', 'valide', 'Virement bancaire', 359, 19, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, '2025-02-06 21:33:47', NULL),
(360, 'SAL2024110001', 'salaire', 'Salaire 2024-11 - Ibrahim Kouassi', 584565.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(361, 'SAL2024110002', 'salaire', 'Salaire 2024-11 - Mariam Koffi', 405185.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(362, 'SAL2024110003', 'salaire', 'Salaire 2024-11 - Moussa Yao', 362356.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(363, 'SAL2024110004', 'salaire', 'Salaire 2024-11 - Aminata Koné', 467448.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(364, 'SAL2024110005', 'salaire', 'Salaire 2024-11 - Michel Traoré', 489047.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(365, 'SAL2024110006', 'salaire', 'Salaire 2024-11 - Aminata Ouattara', 486965.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(366, 'SAL2024110007', 'salaire', 'Salaire 2024-11 - Brahima Bamba', 231918.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(367, 'SAL2024110008', 'salaire', 'Salaire 2024-11 - Ibrahim Doumbia', 300666.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(368, 'SAL2024110009', 'salaire', 'Salaire 2024-11 - Adama Coulibaly', 336797.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(369, 'SAL2024110010', 'salaire', 'Salaire 2024-11 - Brahima Fofana', 331205.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(370, 'SAL2024110011', 'salaire', 'Salaire 2024-11 - François Diabaté', 196174.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(371, 'SAL2024110012', 'salaire', 'Salaire 2024-11 - Moussa Sangaré', 272445.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(372, 'SAL2024110013', 'salaire', 'Salaire 2024-11 - Issiaka Cissé', 299279.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(373, 'SAL2024110014', 'salaire', 'Salaire 2024-11 - Ibrahim Konaté', 251892.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(374, 'SAL2024110015', 'salaire', 'Salaire 2024-11 - Aminata Diallo', 226725.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(375, 'SAL2024110016', 'salaire', 'Salaire 2024-11 - Moussa Camara', 245096.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(376, 'SAL2024110017', 'salaire', 'Salaire 2024-11 - Bernard Keita', 206689.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(377, 'SAL2024110018', 'salaire', 'Salaire 2024-11 - Issiaka Sylla', 204983.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(378, 'SAL2024110019', 'salaire', 'Salaire 2024-11 - Issiaka Barry', 156511.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(379, 'SAL2024110020', 'salaire', 'Salaire 2024-11 - Aminata Sow', 157610.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(380, 'SAL2024110021', 'salaire', 'Salaire 2024-11 - Moussa Assi', 189919.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(381, 'SAL2024110022', 'salaire', 'Salaire 2024-11 - Seydou Akoto', 160869.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(382, 'SAL2024110023', 'salaire', 'Salaire 2024-11 - Seydou Adjoumani', 153307.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(383, 'SAL2024110024', 'salaire', 'Salaire 2024-11 - Ousmane Ahoussou', 172167.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(384, 'SAL2024110025', 'salaire', 'Salaire 2024-11 - Philippe Aké', 187756.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(385, 'SAL2024110026', 'salaire', 'Salaire 2024-11 - Mariam Amani', 196067.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(386, 'SAL2024110027', 'salaire', 'Salaire 2024-11 - André Anoh', 223984.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(387, 'SAL2024110028', 'salaire', 'Salaire 2024-11 - Yao Assié', 226819.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(388, 'SAL2024110029', 'salaire', 'Salaire 2024-11 - Aminata Atta', 193062.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(389, 'SAL2024110030', 'salaire', 'Salaire 2024-11 - Michel Bédié', 159572.00, '2024-11-30', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2024-11', NULL, 1, '2024-11-30 00:00:00', NULL),
(390, 'SAL2024120001', 'salaire', 'Salaire 2024-12 - Ibrahim Kouassi', 584565.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(391, 'SAL2024120002', 'salaire', 'Salaire 2024-12 - Mariam Koffi', 405185.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(392, 'SAL2024120003', 'salaire', 'Salaire 2024-12 - Moussa Yao', 362356.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(393, 'SAL2024120004', 'salaire', 'Salaire 2024-12 - Aminata Koné', 467448.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(394, 'SAL2024120005', 'salaire', 'Salaire 2024-12 - Michel Traoré', 489047.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(395, 'SAL2024120006', 'salaire', 'Salaire 2024-12 - Aminata Ouattara', 486965.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(396, 'SAL2024120007', 'salaire', 'Salaire 2024-12 - Brahima Bamba', 231918.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(397, 'SAL2024120008', 'salaire', 'Salaire 2024-12 - Ibrahim Doumbia', 300666.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(398, 'SAL2024120009', 'salaire', 'Salaire 2024-12 - Adama Coulibaly', 336797.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(399, 'SAL2024120010', 'salaire', 'Salaire 2024-12 - Brahima Fofana', 331205.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(400, 'SAL2024120011', 'salaire', 'Salaire 2024-12 - François Diabaté', 196174.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(401, 'SAL2024120012', 'salaire', 'Salaire 2024-12 - Moussa Sangaré', 272445.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(402, 'SAL2024120013', 'salaire', 'Salaire 2024-12 - Issiaka Cissé', 299279.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(403, 'SAL2024120014', 'salaire', 'Salaire 2024-12 - Ibrahim Konaté', 251892.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(404, 'SAL2024120015', 'salaire', 'Salaire 2024-12 - Aminata Diallo', 226725.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(405, 'SAL2024120016', 'salaire', 'Salaire 2024-12 - Moussa Camara', 245096.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(406, 'SAL2024120017', 'salaire', 'Salaire 2024-12 - Bernard Keita', 206689.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(407, 'SAL2024120018', 'salaire', 'Salaire 2024-12 - Issiaka Sylla', 204983.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(408, 'SAL2024120019', 'salaire', 'Salaire 2024-12 - Issiaka Barry', 156511.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(409, 'SAL2024120020', 'salaire', 'Salaire 2024-12 - Aminata Sow', 157610.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(410, 'SAL2024120021', 'salaire', 'Salaire 2024-12 - Moussa Assi', 189919.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(411, 'SAL2024120022', 'salaire', 'Salaire 2024-12 - Seydou Akoto', 160869.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(412, 'SAL2024120023', 'salaire', 'Salaire 2024-12 - Seydou Adjoumani', 153307.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(413, 'SAL2024120024', 'salaire', 'Salaire 2024-12 - Ousmane Ahoussou', 172167.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(414, 'SAL2024120025', 'salaire', 'Salaire 2024-12 - Philippe Aké', 187756.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(415, 'SAL2024120026', 'salaire', 'Salaire 2024-12 - Mariam Amani', 196067.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(416, 'SAL2024120027', 'salaire', 'Salaire 2024-12 - André Anoh', 223984.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(417, 'SAL2024120028', 'salaire', 'Salaire 2024-12 - Yao Assié', 226819.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(418, 'SAL2024120029', 'salaire', 'Salaire 2024-12 - Aminata Atta', 193062.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(419, 'SAL2024120030', 'salaire', 'Salaire 2024-12 - Michel Bédié', 159572.00, '2024-12-31', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2024-12', NULL, 1, '2024-12-31 00:00:00', NULL),
(420, 'SAL2025010001', 'salaire', 'Salaire 2025-01 - Ibrahim Kouassi', 584565.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(421, 'SAL2025010002', 'salaire', 'Salaire 2025-01 - Mariam Koffi', 405185.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(422, 'SAL2025010003', 'salaire', 'Salaire 2025-01 - Moussa Yao', 362356.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(423, 'SAL2025010004', 'salaire', 'Salaire 2025-01 - Aminata Koné', 467448.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(424, 'SAL2025010005', 'salaire', 'Salaire 2025-01 - Michel Traoré', 489047.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(425, 'SAL2025010006', 'salaire', 'Salaire 2025-01 - Aminata Ouattara', 486965.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(426, 'SAL2025010007', 'salaire', 'Salaire 2025-01 - Brahima Bamba', 231918.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(427, 'SAL2025010008', 'salaire', 'Salaire 2025-01 - Ibrahim Doumbia', 300666.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(428, 'SAL2025010009', 'salaire', 'Salaire 2025-01 - Adama Coulibaly', 336797.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(429, 'SAL2025010010', 'salaire', 'Salaire 2025-01 - Brahima Fofana', 331205.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(430, 'SAL2025010011', 'salaire', 'Salaire 2025-01 - François Diabaté', 196174.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL);
INSERT INTO `transactions` (`id`, `reference`, `type`, `description`, `montant`, `date_transaction`, `statut`, `mode_paiement`, `facture_id`, `client_id`, `employe_id`, `vehicule_id`, `categorie`, `quantite`, `prix_unitaire`, `periode`, `type_maintenance`, `actif`, `date_creation`, `date_modification`) VALUES
(431, 'SAL2025010012', 'salaire', 'Salaire 2025-01 - Moussa Sangaré', 272445.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(432, 'SAL2025010013', 'salaire', 'Salaire 2025-01 - Issiaka Cissé', 299279.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(433, 'SAL2025010014', 'salaire', 'Salaire 2025-01 - Ibrahim Konaté', 251892.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(434, 'SAL2025010015', 'salaire', 'Salaire 2025-01 - Aminata Diallo', 226725.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(435, 'SAL2025010016', 'salaire', 'Salaire 2025-01 - Moussa Camara', 245096.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(436, 'SAL2025010017', 'salaire', 'Salaire 2025-01 - Bernard Keita', 206689.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(437, 'SAL2025010018', 'salaire', 'Salaire 2025-01 - Issiaka Sylla', 204983.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(438, 'SAL2025010019', 'salaire', 'Salaire 2025-01 - Issiaka Barry', 156511.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(439, 'SAL2025010020', 'salaire', 'Salaire 2025-01 - Aminata Sow', 157610.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(440, 'SAL2025010021', 'salaire', 'Salaire 2025-01 - Moussa Assi', 189919.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(441, 'SAL2025010022', 'salaire', 'Salaire 2025-01 - Seydou Akoto', 160869.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(442, 'SAL2025010023', 'salaire', 'Salaire 2025-01 - Seydou Adjoumani', 153307.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(443, 'SAL2025010024', 'salaire', 'Salaire 2025-01 - Ousmane Ahoussou', 172167.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(444, 'SAL2025010025', 'salaire', 'Salaire 2025-01 - Philippe Aké', 187756.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(445, 'SAL2025010026', 'salaire', 'Salaire 2025-01 - Mariam Amani', 196067.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(446, 'SAL2025010027', 'salaire', 'Salaire 2025-01 - André Anoh', 223984.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(447, 'SAL2025010028', 'salaire', 'Salaire 2025-01 - Yao Assié', 226819.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(448, 'SAL2025010029', 'salaire', 'Salaire 2025-01 - Aminata Atta', 193062.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(449, 'SAL2025010030', 'salaire', 'Salaire 2025-01 - Michel Bédié', 159572.00, '2025-01-31', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2025-01', NULL, 1, '2025-01-31 00:00:00', NULL),
(450, 'SAL2025020001', 'salaire', 'Salaire 2025-02 - Ibrahim Kouassi', 584565.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(451, 'SAL2025020002', 'salaire', 'Salaire 2025-02 - Mariam Koffi', 405185.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(452, 'SAL2025020003', 'salaire', 'Salaire 2025-02 - Moussa Yao', 362356.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(453, 'SAL2025020004', 'salaire', 'Salaire 2025-02 - Aminata Koné', 467448.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(454, 'SAL2025020005', 'salaire', 'Salaire 2025-02 - Michel Traoré', 489047.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(455, 'SAL2025020006', 'salaire', 'Salaire 2025-02 - Aminata Ouattara', 486965.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(456, 'SAL2025020007', 'salaire', 'Salaire 2025-02 - Brahima Bamba', 231918.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(457, 'SAL2025020008', 'salaire', 'Salaire 2025-02 - Ibrahim Doumbia', 300666.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(458, 'SAL2025020009', 'salaire', 'Salaire 2025-02 - Adama Coulibaly', 336797.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(459, 'SAL2025020010', 'salaire', 'Salaire 2025-02 - Brahima Fofana', 331205.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(460, 'SAL2025020011', 'salaire', 'Salaire 2025-02 - François Diabaté', 196174.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(461, 'SAL2025020012', 'salaire', 'Salaire 2025-02 - Moussa Sangaré', 272445.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(462, 'SAL2025020013', 'salaire', 'Salaire 2025-02 - Issiaka Cissé', 299279.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(463, 'SAL2025020014', 'salaire', 'Salaire 2025-02 - Ibrahim Konaté', 251892.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(464, 'SAL2025020015', 'salaire', 'Salaire 2025-02 - Aminata Diallo', 226725.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(465, 'SAL2025020016', 'salaire', 'Salaire 2025-02 - Moussa Camara', 245096.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(466, 'SAL2025020017', 'salaire', 'Salaire 2025-02 - Bernard Keita', 206689.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(467, 'SAL2025020018', 'salaire', 'Salaire 2025-02 - Issiaka Sylla', 204983.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(468, 'SAL2025020019', 'salaire', 'Salaire 2025-02 - Issiaka Barry', 156511.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(469, 'SAL2025020020', 'salaire', 'Salaire 2025-02 - Aminata Sow', 157610.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(470, 'SAL2025020021', 'salaire', 'Salaire 2025-02 - Moussa Assi', 189919.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(471, 'SAL2025020022', 'salaire', 'Salaire 2025-02 - Seydou Akoto', 160869.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(472, 'SAL2025020023', 'salaire', 'Salaire 2025-02 - Seydou Adjoumani', 153307.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(473, 'SAL2025020024', 'salaire', 'Salaire 2025-02 - Ousmane Ahoussou', 172167.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(474, 'SAL2025020025', 'salaire', 'Salaire 2025-02 - Philippe Aké', 187756.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(475, 'SAL2025020026', 'salaire', 'Salaire 2025-02 - Mariam Amani', 196067.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(476, 'SAL2025020027', 'salaire', 'Salaire 2025-02 - André Anoh', 223984.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(477, 'SAL2025020028', 'salaire', 'Salaire 2025-02 - Yao Assié', 226819.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(478, 'SAL2025020029', 'salaire', 'Salaire 2025-02 - Aminata Atta', 193062.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(479, 'SAL2025020030', 'salaire', 'Salaire 2025-02 - Michel Bédié', 159572.00, '2025-02-28', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2025-02', NULL, 1, '2025-02-28 00:00:00', NULL),
(480, 'SAL2025030001', 'salaire', 'Salaire 2025-03 - Ibrahim Kouassi', 584565.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(481, 'SAL2025030002', 'salaire', 'Salaire 2025-03 - Mariam Koffi', 405185.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(482, 'SAL2025030003', 'salaire', 'Salaire 2025-03 - Moussa Yao', 362356.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(483, 'SAL2025030004', 'salaire', 'Salaire 2025-03 - Aminata Koné', 467448.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(484, 'SAL2025030005', 'salaire', 'Salaire 2025-03 - Michel Traoré', 489047.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(485, 'SAL2025030006', 'salaire', 'Salaire 2025-03 - Aminata Ouattara', 486965.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(486, 'SAL2025030007', 'salaire', 'Salaire 2025-03 - Brahima Bamba', 231918.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(487, 'SAL2025030008', 'salaire', 'Salaire 2025-03 - Ibrahim Doumbia', 300666.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(488, 'SAL2025030009', 'salaire', 'Salaire 2025-03 - Adama Coulibaly', 336797.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(489, 'SAL2025030010', 'salaire', 'Salaire 2025-03 - Brahima Fofana', 331205.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(490, 'SAL2025030011', 'salaire', 'Salaire 2025-03 - François Diabaté', 196174.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(491, 'SAL2025030012', 'salaire', 'Salaire 2025-03 - Moussa Sangaré', 272445.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(492, 'SAL2025030013', 'salaire', 'Salaire 2025-03 - Issiaka Cissé', 299279.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(493, 'SAL2025030014', 'salaire', 'Salaire 2025-03 - Ibrahim Konaté', 251892.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(494, 'SAL2025030015', 'salaire', 'Salaire 2025-03 - Aminata Diallo', 226725.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(495, 'SAL2025030016', 'salaire', 'Salaire 2025-03 - Moussa Camara', 245096.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(496, 'SAL2025030017', 'salaire', 'Salaire 2025-03 - Bernard Keita', 206689.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(497, 'SAL2025030018', 'salaire', 'Salaire 2025-03 - Issiaka Sylla', 204983.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(498, 'SAL2025030019', 'salaire', 'Salaire 2025-03 - Issiaka Barry', 156511.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(499, 'SAL2025030020', 'salaire', 'Salaire 2025-03 - Aminata Sow', 157610.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(500, 'SAL2025030021', 'salaire', 'Salaire 2025-03 - Moussa Assi', 189919.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(501, 'SAL2025030022', 'salaire', 'Salaire 2025-03 - Seydou Akoto', 160869.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(502, 'SAL2025030023', 'salaire', 'Salaire 2025-03 - Seydou Adjoumani', 153307.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(503, 'SAL2025030024', 'salaire', 'Salaire 2025-03 - Ousmane Ahoussou', 172167.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(504, 'SAL2025030025', 'salaire', 'Salaire 2025-03 - Philippe Aké', 187756.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(505, 'SAL2025030026', 'salaire', 'Salaire 2025-03 - Mariam Amani', 196067.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(506, 'SAL2025030027', 'salaire', 'Salaire 2025-03 - André Anoh', 223984.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(507, 'SAL2025030028', 'salaire', 'Salaire 2025-03 - Yao Assié', 226819.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(508, 'SAL2025030029', 'salaire', 'Salaire 2025-03 - Aminata Atta', 193062.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(509, 'SAL2025030030', 'salaire', 'Salaire 2025-03 - Michel Bédié', 159572.00, '2025-03-31', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2025-03', NULL, 1, '2025-03-31 00:00:00', NULL),
(510, 'SAL2025040001', 'salaire', 'Salaire 2025-04 - Ibrahim Kouassi', 584565.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(511, 'SAL2025040002', 'salaire', 'Salaire 2025-04 - Mariam Koffi', 405185.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(512, 'SAL2025040003', 'salaire', 'Salaire 2025-04 - Moussa Yao', 362356.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(513, 'SAL2025040004', 'salaire', 'Salaire 2025-04 - Aminata Koné', 467448.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(514, 'SAL2025040005', 'salaire', 'Salaire 2025-04 - Michel Traoré', 489047.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(515, 'SAL2025040006', 'salaire', 'Salaire 2025-04 - Aminata Ouattara', 486965.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(516, 'SAL2025040007', 'salaire', 'Salaire 2025-04 - Brahima Bamba', 231918.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(517, 'SAL2025040008', 'salaire', 'Salaire 2025-04 - Ibrahim Doumbia', 300666.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(518, 'SAL2025040009', 'salaire', 'Salaire 2025-04 - Adama Coulibaly', 336797.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(519, 'SAL2025040010', 'salaire', 'Salaire 2025-04 - Brahima Fofana', 331205.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(520, 'SAL2025040011', 'salaire', 'Salaire 2025-04 - François Diabaté', 196174.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(521, 'SAL2025040012', 'salaire', 'Salaire 2025-04 - Moussa Sangaré', 272445.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(522, 'SAL2025040013', 'salaire', 'Salaire 2025-04 - Issiaka Cissé', 299279.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(523, 'SAL2025040014', 'salaire', 'Salaire 2025-04 - Ibrahim Konaté', 251892.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(524, 'SAL2025040015', 'salaire', 'Salaire 2025-04 - Aminata Diallo', 226725.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(525, 'SAL2025040016', 'salaire', 'Salaire 2025-04 - Moussa Camara', 245096.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(526, 'SAL2025040017', 'salaire', 'Salaire 2025-04 - Bernard Keita', 206689.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(527, 'SAL2025040018', 'salaire', 'Salaire 2025-04 - Issiaka Sylla', 204983.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(528, 'SAL2025040019', 'salaire', 'Salaire 2025-04 - Issiaka Barry', 156511.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(529, 'SAL2025040020', 'salaire', 'Salaire 2025-04 - Aminata Sow', 157610.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(530, 'SAL2025040021', 'salaire', 'Salaire 2025-04 - Moussa Assi', 189919.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(531, 'SAL2025040022', 'salaire', 'Salaire 2025-04 - Seydou Akoto', 160869.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(532, 'SAL2025040023', 'salaire', 'Salaire 2025-04 - Seydou Adjoumani', 153307.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(533, 'SAL2025040024', 'salaire', 'Salaire 2025-04 - Ousmane Ahoussou', 172167.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(534, 'SAL2025040025', 'salaire', 'Salaire 2025-04 - Philippe Aké', 187756.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(535, 'SAL2025040026', 'salaire', 'Salaire 2025-04 - Mariam Amani', 196067.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(536, 'SAL2025040027', 'salaire', 'Salaire 2025-04 - André Anoh', 223984.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(537, 'SAL2025040028', 'salaire', 'Salaire 2025-04 - Yao Assié', 226819.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(538, 'SAL2025040029', 'salaire', 'Salaire 2025-04 - Aminata Atta', 193062.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(539, 'SAL2025040030', 'salaire', 'Salaire 2025-04 - Michel Bédié', 159572.00, '2025-04-30', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2025-04', NULL, 1, '2025-04-30 00:00:00', NULL),
(540, 'SAL2025050001', 'salaire', 'Salaire 2025-05 - Ibrahim Kouassi', 584565.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(541, 'SAL2025050002', 'salaire', 'Salaire 2025-05 - Mariam Koffi', 405185.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(542, 'SAL2025050003', 'salaire', 'Salaire 2025-05 - Moussa Yao', 362356.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(543, 'SAL2025050004', 'salaire', 'Salaire 2025-05 - Aminata Koné', 467448.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(544, 'SAL2025050005', 'salaire', 'Salaire 2025-05 - Michel Traoré', 489047.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(545, 'SAL2025050006', 'salaire', 'Salaire 2025-05 - Aminata Ouattara', 486965.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(546, 'SAL2025050007', 'salaire', 'Salaire 2025-05 - Brahima Bamba', 231918.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(547, 'SAL2025050008', 'salaire', 'Salaire 2025-05 - Ibrahim Doumbia', 300666.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(548, 'SAL2025050009', 'salaire', 'Salaire 2025-05 - Adama Coulibaly', 336797.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(549, 'SAL2025050010', 'salaire', 'Salaire 2025-05 - Brahima Fofana', 331205.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(550, 'SAL2025050011', 'salaire', 'Salaire 2025-05 - François Diabaté', 196174.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(551, 'SAL2025050012', 'salaire', 'Salaire 2025-05 - Moussa Sangaré', 272445.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(552, 'SAL2025050013', 'salaire', 'Salaire 2025-05 - Issiaka Cissé', 299279.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(553, 'SAL2025050014', 'salaire', 'Salaire 2025-05 - Ibrahim Konaté', 251892.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(554, 'SAL2025050015', 'salaire', 'Salaire 2025-05 - Aminata Diallo', 226725.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(555, 'SAL2025050016', 'salaire', 'Salaire 2025-05 - Moussa Camara', 245096.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(556, 'SAL2025050017', 'salaire', 'Salaire 2025-05 - Bernard Keita', 206689.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(557, 'SAL2025050018', 'salaire', 'Salaire 2025-05 - Issiaka Sylla', 204983.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(558, 'SAL2025050019', 'salaire', 'Salaire 2025-05 - Issiaka Barry', 156511.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(559, 'SAL2025050020', 'salaire', 'Salaire 2025-05 - Aminata Sow', 157610.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(560, 'SAL2025050021', 'salaire', 'Salaire 2025-05 - Moussa Assi', 189919.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(561, 'SAL2025050022', 'salaire', 'Salaire 2025-05 - Seydou Akoto', 160869.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(562, 'SAL2025050023', 'salaire', 'Salaire 2025-05 - Seydou Adjoumani', 153307.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(563, 'SAL2025050024', 'salaire', 'Salaire 2025-05 - Ousmane Ahoussou', 172167.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(564, 'SAL2025050025', 'salaire', 'Salaire 2025-05 - Philippe Aké', 187756.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(565, 'SAL2025050026', 'salaire', 'Salaire 2025-05 - Mariam Amani', 196067.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(566, 'SAL2025050027', 'salaire', 'Salaire 2025-05 - André Anoh', 223984.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(567, 'SAL2025050028', 'salaire', 'Salaire 2025-05 - Yao Assié', 226819.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(568, 'SAL2025050029', 'salaire', 'Salaire 2025-05 - Aminata Atta', 193062.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(569, 'SAL2025050030', 'salaire', 'Salaire 2025-05 - Michel Bédié', 159572.00, '2025-05-31', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2025-05', NULL, 1, '2025-05-31 00:00:00', NULL),
(570, 'SAL2025060001', 'salaire', 'Salaire 2025-06 - Ibrahim Kouassi', 584565.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 1, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(571, 'SAL2025060002', 'salaire', 'Salaire 2025-06 - Mariam Koffi', 405185.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 2, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(572, 'SAL2025060003', 'salaire', 'Salaire 2025-06 - Moussa Yao', 362356.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 3, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(573, 'SAL2025060004', 'salaire', 'Salaire 2025-06 - Aminata Koné', 467448.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 4, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(574, 'SAL2025060005', 'salaire', 'Salaire 2025-06 - Michel Traoré', 489047.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 5, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(575, 'SAL2025060006', 'salaire', 'Salaire 2025-06 - Aminata Ouattara', 486965.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 6, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(576, 'SAL2025060007', 'salaire', 'Salaire 2025-06 - Brahima Bamba', 231918.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 7, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(577, 'SAL2025060008', 'salaire', 'Salaire 2025-06 - Ibrahim Doumbia', 300666.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 8, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(578, 'SAL2025060009', 'salaire', 'Salaire 2025-06 - Adama Coulibaly', 336797.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 9, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(579, 'SAL2025060010', 'salaire', 'Salaire 2025-06 - Brahima Fofana', 331205.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 10, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(580, 'SAL2025060011', 'salaire', 'Salaire 2025-06 - François Diabaté', 196174.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 11, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(581, 'SAL2025060012', 'salaire', 'Salaire 2025-06 - Moussa Sangaré', 272445.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 12, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(582, 'SAL2025060013', 'salaire', 'Salaire 2025-06 - Issiaka Cissé', 299279.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 13, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(583, 'SAL2025060014', 'salaire', 'Salaire 2025-06 - Ibrahim Konaté', 251892.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 14, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(584, 'SAL2025060015', 'salaire', 'Salaire 2025-06 - Aminata Diallo', 226725.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 15, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(585, 'SAL2025060016', 'salaire', 'Salaire 2025-06 - Moussa Camara', 245096.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 16, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(586, 'SAL2025060017', 'salaire', 'Salaire 2025-06 - Bernard Keita', 206689.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 17, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(587, 'SAL2025060018', 'salaire', 'Salaire 2025-06 - Issiaka Sylla', 204983.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 18, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(588, 'SAL2025060019', 'salaire', 'Salaire 2025-06 - Issiaka Barry', 156511.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 19, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(589, 'SAL2025060020', 'salaire', 'Salaire 2025-06 - Aminata Sow', 157610.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 20, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(590, 'SAL2025060021', 'salaire', 'Salaire 2025-06 - Moussa Assi', 189919.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 21, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(591, 'SAL2025060022', 'salaire', 'Salaire 2025-06 - Seydou Akoto', 160869.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 22, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(592, 'SAL2025060023', 'salaire', 'Salaire 2025-06 - Seydou Adjoumani', 153307.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 23, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(593, 'SAL2025060024', 'salaire', 'Salaire 2025-06 - Ousmane Ahoussou', 172167.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 24, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(594, 'SAL2025060025', 'salaire', 'Salaire 2025-06 - Philippe Aké', 187756.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 25, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(595, 'SAL2025060026', 'salaire', 'Salaire 2025-06 - Mariam Amani', 196067.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 26, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(596, 'SAL2025060027', 'salaire', 'Salaire 2025-06 - André Anoh', 223984.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 27, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(597, 'SAL2025060028', 'salaire', 'Salaire 2025-06 - Yao Assié', 226819.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 28, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(598, 'SAL2025060029', 'salaire', 'Salaire 2025-06 - Aminata Atta', 193062.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 29, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL),
(599, 'SAL2025060030', 'salaire', 'Salaire 2025-06 - Michel Bédié', 159572.00, '2025-06-30', 'valide', 'Virement bancaire', NULL, NULL, 30, NULL, NULL, NULL, NULL, '2025-06', NULL, 1, '2025-06-30 00:00:00', NULL);

-- --------------------------------------------------------

--
-- Structure de la table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nom` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `prenom` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('admin','commercial','chauffeur','comptabilite') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'commercial',
  `client_id` int DEFAULT NULL,
  `salaire` decimal(10,2) DEFAULT '0.00',
  `telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `derniere_connexion` datetime DEFAULT NULL,
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_role` (`role`),
  KEY `idx_actif` (`actif`),
  KEY `idx_users_nom_prenom` (`nom`,`prenom`),
  KEY `fk_users_client` (`client_id`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `users`
--

INSERT INTO `users` (`id`, `nom`, `prenom`, `email`, `password`, `role`, `client_id`, `salaire`, `telephone`, `actif`, `derniere_connexion`, `date_creation`, `date_modification`) VALUES
(1, 'Kouassi', 'Ibrahim', 'ibrahim.kouassi1@logiswayz.ci', '$2y$12$D92Zy1lSzNS/EckLTlOWKuBBUH/Z0aJZx3X5ObWUIL.CyxUybLvNy', 'admin', NULL, 584565.00, '0599385971', 1, NULL, '2024-11-06 00:00:00', NULL),
(2, 'Koffi', 'Mariam', 'mariam.koffi2@logiswayz.ci', '$2y$12$i45PVglSja9D8MFYXUts5.HNTz6nELfTSJ6nxZ/S4iqb8mLrl0uPu', 'comptabilite', NULL, 405185.00, '0784107721', 1, NULL, '2025-02-07 00:00:00', NULL),
(3, 'Yao', 'Moussa', 'moussa.yao3@logiswayz.ci', '$2y$12$VX3UTTZcshfEebNOL5iUY.39s7U5XtbBi33Cu0YXAo5NTkmH8QCIi', 'comptabilite', NULL, 362356.00, '0176022888', 1, NULL, '2025-02-21 00:00:00', NULL),
(4, 'Koné', 'Aminata', 'aminata.koné4@logiswayz.ci', '$2y$12$fvuHoTumqJlX2nSdcWtH8ecml4871xj6q6uTpXxhtCZIiW/E93B5S', 'comptabilite', NULL, 467448.00, '0761505252', 1, NULL, '2025-01-07 00:00:00', NULL),
(5, 'Traoré', 'Michel', 'michel.traoré5@logiswayz.ci', '$2y$12$E7tqfDovsS.OTjzWivzYIOQ69ZGzW2cU..3Sm2rLmd1nNCO2PdpLO', 'comptabilite', NULL, 489047.00, '0154960022', 1, NULL, '2025-04-25 00:00:00', NULL),
(6, 'Ouattara', 'Aminata', 'aminata.ouattara6@logiswayz.ci', '$2y$12$uoVclIPfWyx4cjDLDGqzgergQizaWq/U8C0Ab57slDWHnSsV7p2K6', 'comptabilite', NULL, 486965.00, '0583660949', 1, NULL, '2025-02-08 00:00:00', NULL),
(7, 'Bamba', 'Brahima', 'brahima.bamba7@logiswayz.ci', '$2y$12$Wd2vCheB3P.xkVZRtSriXuF6quXs7UhsWqez4bfUFGG8h1S6xsHFG', 'commercial', NULL, 231918.00, '0590006742', 1, NULL, '2024-11-23 00:00:00', NULL),
(8, 'Doumbia', 'Ibrahim', 'ibrahim.doumbia8@logiswayz.ci', '$2y$12$O4om1bnExBqGfRexdZSZgOgRDDF82o2V8fbP.O4cTK4V.Ygk2GQB6', 'commercial', NULL, 300666.00, '0789909409', 1, NULL, '2025-05-16 00:00:00', NULL),
(9, 'Coulibaly', 'Adama', 'adama.coulibaly9@logiswayz.ci', '$2y$12$oNj5fIJ8kXvlM0VyO.Dk7O9lcrWUn.2kNhgVTkUW.XbuTDpH5vr.6', 'commercial', NULL, 336797.00, '0377974869', 1, NULL, '2025-01-25 00:00:00', NULL),
(10, 'Fofana', 'Brahima', 'brahima.fofana10@logiswayz.ci', '$2y$12$NGatMrf7angAEwZgLau41OA1/7gFgI5ophlZOxfHaqrGGWQvYHXgS', 'commercial', NULL, 331205.00, '0142223034', 1, NULL, '2025-03-07 00:00:00', NULL),
(11, 'Diabaté', 'François', 'françois.diabaté11@logiswayz.ci', '$2y$12$bN2rCzdV6TcO4qpcjEVuiOnHcEFogpzl3xkEIqlTp5wuSMljHJ8BC', 'commercial', NULL, 196174.00, '0551108691', 1, NULL, '2025-04-01 00:00:00', NULL),
(12, 'Sangaré', 'Moussa', 'moussa.sangaré12@logiswayz.ci', '$2y$12$IiWd0tg3M564WCiV/y709eYRebcxYuWbon68707A6vo1RPR6RYC4u', 'commercial', NULL, 272445.00, '0372910329', 1, NULL, '2025-02-10 00:00:00', NULL),
(13, 'Cissé', 'Issiaka', 'issiaka.cissé13@logiswayz.ci', '$2y$12$rUUjUiJZYu6.a.2bb9as8OK8WFMXbIlB.jmfcLc2O.Gtr0NOa9THa', 'commercial', NULL, 299279.00, '0386510817', 1, NULL, '2024-11-05 00:00:00', NULL),
(14, 'Konaté', 'Ibrahim', 'ibrahim.konaté14@logiswayz.ci', '$2y$12$0QpVw1ZPm6BogN5AoEStJuF74F/Xv8tgLj5MuCMd6Gx4.Bz9JdolG', 'commercial', NULL, 251892.00, '0160019831', 1, NULL, '2025-05-13 00:00:00', NULL),
(15, 'Diallo', 'Aminata', 'aminata.diallo15@logiswayz.ci', '$2y$12$PtY66X4s.4NidG5VM/w8oe5jNreQCjRSDD5pCEmkcPuotjaz7jO4e', 'commercial', NULL, 226725.00, '0535114519', 1, NULL, '2024-11-11 00:00:00', NULL),
(16, 'Camara', 'Moussa', 'moussa.camara16@logiswayz.ci', '$2y$12$0goZD1p5xigrKlF9/atMcuoxcIvbnj7n/WWQXmziuNeyO3jlO5dDK', 'commercial', NULL, 245096.00, '0299989477', 1, NULL, '2025-03-22 00:00:00', NULL),
(17, 'Keita', 'Bernard', 'bernard.keita17@logiswayz.ci', '$2y$12$y3MaxNLnPwG9/mPS/Dk2uubCx7coJbdHgnbzVUec.9lSFV7N9CBly', 'chauffeur', NULL, 206689.00, '0247559705', 1, NULL, '2025-03-15 00:00:00', NULL),
(18, 'Sylla', 'Issiaka', 'issiaka.sylla18@logiswayz.ci', '$2y$12$M7Qv3gbDsBla.H6tUj0QRuBMy.H0WTs5.l2qZC7AJ8gGmHtgrP3BC', 'chauffeur', NULL, 204983.00, '0221990490', 1, NULL, '2025-03-28 00:00:00', NULL),
(19, 'Barry', 'Issiaka', 'issiaka.barry19@logiswayz.ci', '$2y$12$fOsVh9eQGGye6KxRYGVYeu2FkizrUYoAmkScjtHIej12RFaBJTqkG', 'chauffeur', NULL, 156511.00, '0129077431', 1, NULL, '2024-11-23 00:00:00', NULL),
(20, 'Sow', 'Aminata', 'aminata.sow20@logiswayz.ci', '$2y$12$DLjoTQWl/Kls9YsLrD9u9u2Ff70aiV3qg/PJeHA4FIi/riJShqI4e', 'chauffeur', NULL, 157610.00, '0258256831', 1, NULL, '2025-04-01 00:00:00', NULL),
(21, 'Assi', 'Moussa', 'moussa.assi21@logiswayz.ci', '$2y$12$58B60wIqZFzFP7JBFTGiNurqDM4HA.9OJLsp4Dl725Dtpo/YUYvS.', 'chauffeur', NULL, 189919.00, '0290372501', 1, NULL, '2025-05-09 00:00:00', NULL),
(22, 'Akoto', 'Seydou', 'seydou.akoto22@logiswayz.ci', '$2y$12$M5JiQ7yM3n.81KtOKYVKguvo0hN41ccHMYBBHVLMRdXKKRJ3786cS', 'chauffeur', NULL, 160869.00, '0110385132', 1, NULL, '2025-04-05 00:00:00', NULL),
(23, 'Adjoumani', 'Seydou', 'seydou.adjoumani23@logiswayz.ci', '$2y$12$PJP3PQqb5ya0YJYV0t/eNO9YCOomLqV3D5J7/Wj/C6qrfbStFQiiO', 'chauffeur', NULL, 153307.00, '0243209051', 1, NULL, '2025-04-07 00:00:00', NULL),
(24, 'Ahoussou', 'Ousmane', 'ousmane.ahoussou24@logiswayz.ci', '$2y$12$49fMGb7Ol3TNDWCCCb8QNena0X/ZCBu9DE6en5Tdyt4b6UMWWzTEa', 'chauffeur', NULL, 172167.00, '0124025717', 1, NULL, '2024-12-27 00:00:00', NULL),
(25, 'Aké', 'Philippe', 'philippe.aké25@logiswayz.ci', '$2y$12$HQJcsdNxo8FYndJymrepRew6vVRxM8AMSEd.xoOShfHgcXofed6/G', 'chauffeur', NULL, 187756.00, '0149755719', 1, NULL, '2024-12-05 00:00:00', NULL),
(26, 'Amani', 'Mariam', 'mariam.amani26@logiswayz.ci', '$2y$12$IQG.MJl7T2gEwTZmQZYvCukKFLQN.jct44oa4f/cUPpi3iLSBc6sm', 'chauffeur', NULL, 196067.00, '0385732412', 1, NULL, '2025-03-18 00:00:00', NULL),
(27, 'Anoh', 'André', 'andré.anoh27@logiswayz.ci', '$2y$12$R.wXPZfe/UBlz.QDlYEn3.GUBEEOB0JXg8qXNguCQHVSoTqSeTbUG', 'chauffeur', NULL, 223984.00, '0279414576', 1, NULL, '2024-12-03 00:00:00', NULL),
(28, 'Assié', 'Yao', 'yao.assié28@logiswayz.ci', '$2y$12$hN90v3cFh9xK7gpSGvjG0OLVgQdZYWuOI1UyQaXV7I1rFWjf61/D6', 'chauffeur', NULL, 226819.00, '0219229397', 1, NULL, '2024-11-17 00:00:00', NULL),
(29, 'Atta', 'Aminata', 'aminata.atta29@logiswayz.ci', '$2y$12$R2DVsforcDRSmW4T4hro3OhpJVW1PYvKrq5FpcLgHGdsvPR5cnXam', 'chauffeur', NULL, 193062.00, '0171577928', 1, NULL, '2025-01-30 00:00:00', NULL),
(30, 'Bédié', 'Michel', 'michel.bédié30@logiswayz.ci', '$2y$12$fPFZIp7oOoerflBO12gcW.iTrVoSvnOx4kcxCczN4BL29pzzhLcYO', 'chauffeur', NULL, 159572.00, '0744060243', 1, NULL, '2025-01-23 00:00:00', NULL),
(31, 'Affouet', 'Aguia Paul-aristide', 'affouetaguia99@gmail.com', '$2y$12$4Isu6DibWrgzsBHqwHPR.eiPLn.35xsho5vpG//L0cEYzi2ssJtA2', 'admin', NULL, 0.00, '0160502400', 1, '2025-06-21 09:58:58', '2025-06-21 09:54:40', '2025-06-21 09:58:58'),
(32, 'Sapro', 'Kivo', 'affouetworkspace@gmail.com', '$2y$12$550bCnNx7JzcWeHgfGOiTewKpxH25Bbhvgi12aTFOuHTf9UVeEByK', 'comptabilite', NULL, 400000.00, NULL, 1, '2025-06-21 10:13:23', '2025-06-21 10:01:01', '2025-06-21 10:13:23'),
(33, 'Paul', 'Aristide', 'logiswayz@gmail.com', '$2y$12$6PnqCxcnZczzX36KtPvxtOHL/4Jds.GS7t8Ac/NYcFw8oLP0StQoO', 'commercial', NULL, 240000.00, NULL, 1, NULL, '2025-06-21 10:02:36', NULL),
(34, 'Abou', 'koyate', 'affouet.iacompte@gmail.com', '$2y$12$gHdaLWIVYCq5KhVYygivyulJRUuDZt0D4/lmoFNZ0vdTZLy46daEG', 'chauffeur', NULL, 160000.00, NULL, 1, '2025-06-21 10:04:46', '2025-06-21 10:04:26', '2025-06-21 10:04:46');

-- --------------------------------------------------------

--
-- Structure de la table `vehicules`
--

DROP TABLE IF EXISTS `vehicules`;
CREATE TABLE IF NOT EXISTS `vehicules` (
  `id` int NOT NULL AUTO_INCREMENT,
  `immatriculation` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `marque` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `modele` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `annee` int DEFAULT NULL,
  `type` enum('camion','camionnette','fourgon','semi_remorque') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `capacite_poids` decimal(8,2) DEFAULT '0.00',
  `capacite_volume` decimal(8,2) DEFAULT '0.00',
  `consommation` decimal(5,2) DEFAULT '0.00',
  `km_parcourus` decimal(10,2) DEFAULT '0.00',
  `date_derniere_maintenance` date DEFAULT NULL,
  `statut` enum('actif','maintenance','hors_service') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'actif',
  `disponible` tinyint(1) NOT NULL DEFAULT '1',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actif` tinyint(1) NOT NULL DEFAULT '1',
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modification` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `immatriculation` (`immatriculation`),
  KEY `idx_type` (`type`),
  KEY `idx_statut` (`statut`),
  KEY `idx_disponible` (`disponible`),
  KEY `idx_actif` (`actif`)
) ENGINE=InnoDB AUTO_INCREMENT=68 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `vehicules`
--

INSERT INTO `vehicules` (`id`, `immatriculation`, `marque`, `modele`, `annee`, `type`, `capacite_poids`, `capacite_volume`, `consommation`, `km_parcourus`, `date_derniere_maintenance`, `statut`, `disponible`, `notes`, `actif`, `date_creation`, `date_modification`) VALUES
(1, '01CI01-18', 'MAN', 'TGL', 2024, 'semi_remorque', 33.46, 111.00, 25.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2023-06-08 09:53:26', NULL),
(2, '02CI02-12', 'Volvo', 'FL', 2017, 'camion', 25.08, 87.00, 15.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2022-12-18 09:53:26', NULL),
(3, '03CI03-03', 'Volvo', 'FE', 2023, 'camionnette', 3.13, 12.00, 43.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2024-04-22 09:53:26', NULL),
(4, '04CI04-09', 'DAF', 'LF', 2024, 'fourgon', 3.56, 22.00, 24.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2024-02-15 09:53:26', NULL),
(5, '05CI05-19', 'Scania', 'R-Series', 2018, 'semi_remorque', 40.45, 117.00, 23.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2025-03-09 09:53:26', NULL),
(6, '06CI06-12', 'Scania', 'R-Series', 2017, 'camion', 24.80, 60.00, 34.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2023-05-06 09:53:26', NULL),
(7, '07CI07-03', 'Renault', 'Midlum', 2022, 'camionnette', 2.17, 5.00, 44.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2022-10-26 09:53:26', NULL),
(8, '08CI08-02', 'IVECO', 'Eurocargo', 2024, 'semi_remorque', 36.98, 114.00, 33.00, 0.00, NULL, 'maintenance', 0, NULL, 1, '2023-02-21 09:53:26', NULL),
(9, '09CI09-07', 'Mercedes-Benz', 'Actros', 2021, 'camion', 9.62, 53.00, 27.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-10-06 09:53:26', '2025-06-21 09:53:30'),
(10, '10CI10-18', 'Renault', 'Master', 2020, 'camionnette', 2.40, 8.00, 24.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-06-12 09:53:26', '2025-06-21 09:53:30'),
(11, '11CI11-10', 'Renault', 'Premium', 2017, 'camionnette', 3.45, 16.00, 25.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-05-04 09:53:26', '2025-06-21 09:53:30'),
(12, '12CI12-04', 'DAF', 'XF', 2022, 'camion', 21.68, 46.00, 21.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-01-10 09:53:26', '2025-06-21 09:53:30'),
(13, '13CI13-12', 'Mercedes-Benz', 'Sprinter', 2016, 'camion', 8.50, 56.00, 33.00, 0.00, NULL, 'actif', 0, NULL, 1, '2025-01-23 09:53:26', '2025-06-21 09:53:30'),
(14, '14CI14-05', 'MAN', 'TGM', 2015, 'semi_remorque', 31.91, 118.00, 21.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-09-18 09:53:26', '2025-06-21 09:53:30'),
(15, '15CI15-07', 'IVECO', 'Eurocargo', 2017, 'camionnette', 2.65, 12.00, 33.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-11-04 09:53:26', '2025-06-21 09:53:30'),
(16, '16CI16-14', 'Mercedes-Benz', 'Atego', 2017, 'camion', 9.43, 36.00, 15.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-13 09:53:26', '2025-06-21 09:53:30'),
(17, '17CI17-18', 'DAF', 'XF', 2021, 'fourgon', 5.84, 25.00, 44.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-10-31 09:53:26', '2025-06-21 09:53:30'),
(18, '18CI18-19', 'Renault', 'Master', 2017, 'semi_remorque', 39.12, 86.00, 43.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-03-04 09:53:26', '2025-06-21 09:53:30'),
(19, '19CI19-02', 'DAF', 'XF', 2019, 'fourgon', 5.61, 19.00, 30.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-10-01 09:53:26', '2025-06-21 09:53:30'),
(20, '20CI20-02', 'Scania', 'R-Series', 2019, 'fourgon', 6.59, 34.00, 45.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-04-16 09:53:26', NULL),
(21, '21CI21-09', 'Volvo', 'FL', 2015, 'fourgon', 4.99, 22.00, 22.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-12-01 09:53:26', NULL),
(22, '22CI22-12', 'Volvo', 'FL', 2021, 'fourgon', 4.69, 20.00, 36.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-11-07 09:53:26', NULL),
(23, '23CI23-06', 'DAF', 'LF', 2019, 'fourgon', 4.84, 17.00, 17.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-06-12 09:53:26', NULL),
(24, '24CI24-01', 'DAF', 'LF', 2016, 'semi_remorque', 37.06, 90.00, 24.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-04-03 09:53:26', NULL),
(25, '25CI25-17', 'Mercedes-Benz', 'Sprinter', 2022, 'camion', 13.96, 58.00, 31.00, 0.00, NULL, 'actif', 0, NULL, 1, '2025-01-11 09:53:26', NULL),
(26, '26CI26-03', 'IVECO', 'Stralis', 2019, 'camion', 15.63, 36.00, 16.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-01-29 09:53:26', NULL),
(27, '27CI27-17', 'DAF', 'CF', 2018, 'semi_remorque', 43.48, 86.00, 34.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-11-27 09:53:26', NULL),
(28, '28CI28-19', 'Scania', 'P-Series', 2023, 'semi_remorque', 29.70, 84.00, 20.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-07-05 09:53:26', NULL),
(29, '29CI29-08', 'Renault', 'Premium', 2017, 'camion', 14.65, 39.00, 15.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-04-19 09:53:26', NULL),
(30, '30CI30-05', 'Volvo', 'FM', 2017, 'camionnette', 3.05, 5.00, 32.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-03-23 09:53:26', NULL),
(31, '31CI31-15', 'IVECO', 'Eurocargo', 2018, 'camionnette', 2.52, 8.00, 26.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-11-17 09:53:26', NULL),
(32, '32CI32-04', 'MAN', 'TGM', 2019, 'semi_remorque', 38.53, 80.00, 28.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-08 09:53:26', NULL),
(33, '33CI33-12', 'Mercedes-Benz', 'Actros', 2018, 'camionnette', 3.22, 12.00, 30.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-06-02 09:53:26', NULL),
(34, '34CI34-11', 'Scania', 'R-Series', 2021, 'fourgon', 7.25, 19.00, 25.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-12-12 09:53:26', NULL),
(35, '35CI35-08', 'IVECO', 'Daily', 2021, 'camion', 23.18, 43.00, 28.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-05-19 09:53:26', NULL),
(36, '36CI36-12', 'IVECO', 'Stralis', 2020, 'fourgon', 4.61, 39.00, 19.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-16 09:53:26', NULL),
(37, '37CI37-14', 'DAF', 'LF', 2015, 'camion', 13.42, 82.00, 44.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-12-12 09:53:26', NULL),
(38, '38CI38-16', 'Volvo', 'FM', 2023, 'camionnette', 2.71, 18.00, 32.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-03-12 09:53:26', NULL),
(39, '39CI39-05', 'Renault', 'Master', 2015, 'fourgon', 6.15, 36.00, 23.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-02-17 09:53:26', NULL),
(40, '40CI40-03', 'Volvo', 'FM', 2015, 'semi_remorque', 31.45, 95.00, 17.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-07-13 09:53:26', NULL),
(41, '41CI41-10', 'Mercedes-Benz', 'Actros', 2017, 'camionnette', 1.93, 6.00, 33.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-28 09:53:26', NULL),
(42, '42CI42-02', 'DAF', 'LF', 2018, 'camion', 10.09, 86.00, 41.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-01-25 09:53:26', NULL),
(43, '43CI43-06', 'Scania', 'P-Series', 2016, 'camion', 14.71, 85.00, 29.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-10-22 09:53:26', NULL),
(44, '44CI44-19', 'Mercedes-Benz', 'Sprinter', 2023, 'camion', 11.04, 51.00, 34.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-10-30 09:53:26', NULL),
(45, '45CI45-10', 'MAN', 'TGE', 2021, 'fourgon', 5.79, 28.00, 43.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-09-04 09:53:26', NULL),
(46, '46CI46-11', 'Mercedes-Benz', 'Sprinter', 2015, 'fourgon', 5.59, 22.00, 38.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-12-02 09:53:26', NULL),
(47, '47CI47-10', 'Mercedes-Benz', 'Actros', 2024, 'camionnette', 1.09, 17.00, 31.00, 0.00, NULL, 'actif', 0, NULL, 1, '2025-01-09 09:53:26', NULL),
(48, '48CI48-03', 'Volvo', 'FL', 2017, 'fourgon', 6.15, 33.00, 27.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-18 09:53:26', NULL),
(49, '49CI49-13', 'Volvo', 'FE', 2019, 'fourgon', 6.49, 26.00, 22.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-11-28 09:53:26', NULL),
(50, '50CI50-17', 'Volvo', 'FM', 2017, 'semi_remorque', 31.64, 113.00, 36.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-01-19 09:53:26', NULL),
(51, '51CI51-02', 'MAN', 'TGE', 2015, 'fourgon', 4.43, 31.00, 43.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-10-29 09:53:26', NULL),
(52, '52CI52-03', 'Renault', 'Premium', 2020, 'camion', 17.41, 44.00, 19.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-12-08 09:53:26', NULL),
(53, '53CI53-02', 'MAN', 'TGM', 2023, 'semi_remorque', 40.70, 101.00, 21.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-03 09:53:26', NULL),
(54, '54CI54-08', 'Mercedes-Benz', 'Sprinter', 2017, 'fourgon', 7.41, 39.00, 44.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-04-09 09:53:26', NULL),
(55, '55CI55-01', 'Renault', 'Midlum', 2017, 'fourgon', 6.35, 26.00, 37.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-05-24 09:53:26', NULL),
(56, '56CI56-16', 'MAN', 'TGE', 2024, 'fourgon', 3.70, 40.00, 36.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-07-08 09:53:26', NULL),
(57, '57CI57-08', 'MAN', 'TGE', 2019, 'camionnette', 3.33, 6.00, 19.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-08-09 09:53:26', NULL),
(58, '58CI58-11', 'Mercedes-Benz', 'Actros', 2024, 'camion', 9.41, 51.00, 37.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-01-30 09:53:26', NULL),
(59, '59CI59-10', 'Volvo', 'FE', 2017, 'fourgon', 5.97, 18.00, 21.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-07-16 09:53:26', NULL),
(60, '60CI60-17', 'DAF', 'CF', 2020, 'fourgon', 4.34, 19.00, 20.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-12-10 09:53:26', NULL),
(61, '61CI61-10', 'MAN', 'TGM', 2015, 'camion', 18.53, 56.00, 19.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-05-06 09:53:26', NULL),
(62, '62CI62-02', 'Mercedes-Benz', 'Sprinter', 2016, 'semi_remorque', 33.39, 107.00, 36.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-12-03 09:53:26', NULL),
(63, '63CI63-03', 'Mercedes-Benz', 'Sprinter', 2016, 'camion', 12.68, 83.00, 25.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-02-22 09:53:26', NULL),
(64, '64CI64-17', 'IVECO', 'Stralis', 2020, 'camionnette', 2.85, 19.00, 37.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-03-27 09:53:26', NULL),
(65, '65CI65-01', 'Scania', 'G-Series', 2023, 'camionnette', 1.39, 10.00, 39.00, 0.00, NULL, 'actif', 0, NULL, 1, '2022-10-31 09:53:26', NULL),
(66, '66CI66-08', 'Volvo', 'FM', 2021, 'camionnette', 3.00, 6.00, 38.00, 0.00, NULL, 'actif', 0, NULL, 1, '2023-09-19 09:53:26', NULL),
(67, '67CI67-11', 'Volvo', 'FE', 2024, 'semi_remorque', 32.61, 119.00, 15.00, 0.00, NULL, 'actif', 0, NULL, 1, '2024-11-05 09:53:26', NULL);

-- --------------------------------------------------------

--
-- Doublure de structure pour la vue `view_commandes_detail`
-- (Voir ci-dessous la vue réelle)
--
DROP VIEW IF EXISTS `view_commandes_detail`;
CREATE TABLE IF NOT EXISTS `view_commandes_detail` (
`id` int
,`numero_commande` varchar(50)
,`client_id` int
,`adresse_depart` text
,`adresse_arrivee` text
,`date_prevue` date
,`heure_prevue` time
,`description` text
,`poids` decimal(8,2)
,`volume` decimal(8,2)
,`prix` decimal(10,2)
,`statut` enum('en_attente','confirmee','en_cours','livree','annulee')
,`notes` text
,`active` tinyint(1)
,`date_creation` datetime
,`date_modification` datetime
,`client_nom` varchar(100)
,`client_prenom` varchar(100)
,`client_entreprise` varchar(200)
,`client_email` varchar(255)
,`client_telephone` varchar(20)
,`client_nom_complet` varchar(201)
);

-- --------------------------------------------------------

--
-- Doublure de structure pour la vue `view_commandes_en_retard`
-- (Voir ci-dessous la vue réelle)
--
DROP VIEW IF EXISTS `view_commandes_en_retard`;
CREATE TABLE IF NOT EXISTS `view_commandes_en_retard` (
`id` int
,`numero_commande` varchar(50)
,`client_id` int
,`adresse_depart` text
,`adresse_arrivee` text
,`date_prevue` date
,`heure_prevue` time
,`description` text
,`poids` decimal(8,2)
,`volume` decimal(8,2)
,`prix` decimal(10,2)
,`statut` enum('en_attente','confirmee','en_cours','livree','annulee')
,`notes` text
,`active` tinyint(1)
,`date_creation` datetime
,`date_modification` datetime
,`client_nom` varchar(100)
,`client_entreprise` varchar(200)
);

-- --------------------------------------------------------

--
-- Doublure de structure pour la vue `view_commandes_workflow`
-- (Voir ci-dessous la vue réelle)
--
DROP VIEW IF EXISTS `view_commandes_workflow`;
CREATE TABLE IF NOT EXISTS `view_commandes_workflow` (
`id` int
,`numero_commande` varchar(50)
,`client_id` int
,`adresse_depart` text
,`adresse_arrivee` text
,`date_prevue` date
,`heure_prevue` time
,`description` text
,`poids` decimal(8,2)
,`volume` decimal(8,2)
,`prix` decimal(10,2)
,`statut` enum('en_attente','confirmee','en_cours','livree','annulee')
,`workflow_state` enum('created','validated','rejected','planned','in_transit','delivered','cancelled')
,`validated_by` int
,`validated_at` timestamp
,`rejection_reason` text
,`tarif_auto` decimal(10,2)
,`poids_kg` decimal(10,2)
,`distance_km` decimal(10,2)
,`zone_tarif` varchar(20)
,`cargo_type` varchar(20)
,`urgence` enum('normal','urgent','tres_urgent')
,`priorite` tinyint
,`notes` text
,`active` tinyint(1)
,`date_creation` datetime
,`date_modification` datetime
,`validated_by_nom` varchar(100)
,`validated_by_prenom` varchar(100)
,`client_nom` varchar(100)
,`client_prenom` varchar(100)
,`client_email` varchar(255)
,`client_telephone` varchar(20)
);

-- --------------------------------------------------------

--
-- Doublure de structure pour la vue `view_factures_detail`
-- (Voir ci-dessous la vue réelle)
--
DROP VIEW IF EXISTS `view_factures_detail`;
CREATE TABLE IF NOT EXISTS `view_factures_detail` (
`id` int
,`numero_facture` varchar(50)
,`client_id` int
,`commande_id` int
,`date_facture` date
,`date_echeance` date
,`montant_ht` decimal(10,2)
,`taux_tva` decimal(5,2)
,`montant_tva` decimal(10,2)
,`montant_ttc` decimal(10,2)
,`statut` enum('brouillon','envoyee','payee','annulee')
,`date_paiement` datetime
,`description` text
,`notes` text
,`actif` tinyint(1)
,`date_creation` datetime
,`date_modification` datetime
,`client_nom` varchar(100)
,`client_prenom` varchar(100)
,`client_entreprise` varchar(200)
,`client_email` varchar(255)
,`client_telephone` varchar(20)
,`client_adresse` text
,`client_ville` varchar(100)
,`client_code_postal` varchar(10)
,`numero_commande` varchar(50)
,`commande_description` text
);

-- --------------------------------------------------------

--
-- Doublure de structure pour la vue `view_trajets_detail`
-- (Voir ci-dessous la vue réelle)
--
DROP VIEW IF EXISTS `view_trajets_detail`;
CREATE TABLE IF NOT EXISTS `view_trajets_detail` (
`id` int
,`commande_id` int
,`vehicule_id` int
,`chauffeur_id` int
,`date_depart` datetime
,`date_arrivee_prevue` datetime
,`date_arrivee_reelle` datetime
,`distance_km` decimal(8,2)
,`statut` enum('planifie','en_cours','termine','annule')
,`notes` text
,`actif` tinyint(1)
,`date_creation` datetime
,`date_modification` datetime
,`numero_commande` varchar(50)
,`adresse_depart` text
,`adresse_arrivee` text
,`commande_description` text
,`client_nom` varchar(100)
,`client_prenom` varchar(100)
,`client_entreprise` varchar(200)
,`vehicule_immat` varchar(20)
,`vehicule_marque` varchar(50)
,`vehicule_modele` varchar(50)
,`chauffeur_nom` varchar(100)
,`chauffeur_prenom` varchar(100)
,`chauffeur_telephone` varchar(20)
);

-- --------------------------------------------------------

--
-- Doublure de structure pour la vue `view_vehicules_maintenance`
-- (Voir ci-dessous la vue réelle)
--
DROP VIEW IF EXISTS `view_vehicules_maintenance`;
CREATE TABLE IF NOT EXISTS `view_vehicules_maintenance` (
`id` int
,`immatriculation` varchar(20)
,`marque` varchar(50)
,`modele` varchar(50)
,`annee` int
,`type` enum('camion','camionnette','fourgon','semi_remorque')
,`capacite_poids` decimal(8,2)
,`capacite_volume` decimal(8,2)
,`consommation` decimal(5,2)
,`statut` enum('actif','maintenance','hors_service')
,`disponible` tinyint(1)
,`notes` text
,`actif` tinyint(1)
,`date_creation` datetime
,`date_modification` datetime
,`derniere_maintenance` date
,`nb_maintenances` bigint
);

-- --------------------------------------------------------

--
-- Structure de la table `workflow_states`
--

DROP TABLE IF EXISTS `workflow_states`;
CREATE TABLE IF NOT EXISTS `workflow_states` (
  `id` int NOT NULL AUTO_INCREMENT,
  `commande_id` int NOT NULL,
  `state` enum('created','validated','rejected','planned','in_transit','delivered','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'created',
  `previous_state` enum('created','validated','rejected','planned','in_transit','delivered','cancelled') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `changed_by` int NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci,
  `metadata` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_commande_id` (`commande_id`),
  KEY `idx_state` (`state`),
  KEY `idx_changed_by` (`changed_by`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Structure de la vue `view_commandes_detail`
--
DROP TABLE IF EXISTS `view_commandes_detail`;

DROP VIEW IF EXISTS `view_commandes_detail`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_commandes_detail`  AS SELECT `c`.`id` AS `id`, `c`.`numero_commande` AS `numero_commande`, `c`.`client_id` AS `client_id`, `c`.`adresse_depart` AS `adresse_depart`, `c`.`adresse_arrivee` AS `adresse_arrivee`, `c`.`date_prevue` AS `date_prevue`, `c`.`heure_prevue` AS `heure_prevue`, `c`.`description` AS `description`, `c`.`poids` AS `poids`, `c`.`volume` AS `volume`, `c`.`prix` AS `prix`, `c`.`statut` AS `statut`, `c`.`notes` AS `notes`, `c`.`active` AS `active`, `c`.`date_creation` AS `date_creation`, `c`.`date_modification` AS `date_modification`, `cl`.`nom` AS `client_nom`, `cl`.`prenom` AS `client_prenom`, `cl`.`entreprise` AS `client_entreprise`, `cl`.`email` AS `client_email`, `cl`.`telephone` AS `client_telephone`, concat(`cl`.`nom`,' ',ifnull(`cl`.`prenom`,'')) AS `client_nom_complet` FROM (`commandes` `c` join `clients` `cl` on((`c`.`client_id` = `cl`.`id`))) WHERE ((`c`.`active` = 1) AND (`cl`.`actif` = 1)) ;

-- --------------------------------------------------------

--
-- Structure de la vue `view_commandes_en_retard`
--
DROP TABLE IF EXISTS `view_commandes_en_retard`;

DROP VIEW IF EXISTS `view_commandes_en_retard`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_commandes_en_retard`  AS SELECT `c`.`id` AS `id`, `c`.`numero_commande` AS `numero_commande`, `c`.`client_id` AS `client_id`, `c`.`adresse_depart` AS `adresse_depart`, `c`.`adresse_arrivee` AS `adresse_arrivee`, `c`.`date_prevue` AS `date_prevue`, `c`.`heure_prevue` AS `heure_prevue`, `c`.`description` AS `description`, `c`.`poids` AS `poids`, `c`.`volume` AS `volume`, `c`.`prix` AS `prix`, `c`.`statut` AS `statut`, `c`.`notes` AS `notes`, `c`.`active` AS `active`, `c`.`date_creation` AS `date_creation`, `c`.`date_modification` AS `date_modification`, `cl`.`nom` AS `client_nom`, `cl`.`entreprise` AS `client_entreprise` FROM (`commandes` `c` join `clients` `cl` on((`c`.`client_id` = `cl`.`id`))) WHERE ((`c`.`active` = 1) AND (`c`.`statut` not in ('livree','annulee')) AND (`c`.`date_prevue` < curdate())) ;

-- --------------------------------------------------------

--
-- Structure de la vue `view_commandes_workflow`
--
DROP TABLE IF EXISTS `view_commandes_workflow`;

DROP VIEW IF EXISTS `view_commandes_workflow`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_commandes_workflow`  AS SELECT `c`.`id` AS `id`, `c`.`numero_commande` AS `numero_commande`, `c`.`client_id` AS `client_id`, `c`.`adresse_depart` AS `adresse_depart`, `c`.`adresse_arrivee` AS `adresse_arrivee`, `c`.`date_prevue` AS `date_prevue`, `c`.`heure_prevue` AS `heure_prevue`, `c`.`description` AS `description`, `c`.`poids` AS `poids`, `c`.`volume` AS `volume`, `c`.`prix` AS `prix`, `c`.`statut` AS `statut`, `c`.`workflow_state` AS `workflow_state`, `c`.`validated_by` AS `validated_by`, `c`.`validated_at` AS `validated_at`, `c`.`rejection_reason` AS `rejection_reason`, `c`.`tarif_auto` AS `tarif_auto`, `c`.`poids_kg` AS `poids_kg`, `c`.`distance_km` AS `distance_km`, `c`.`zone_tarif` AS `zone_tarif`, `c`.`cargo_type` AS `cargo_type`, `c`.`urgence` AS `urgence`, `c`.`priorite` AS `priorite`, `c`.`notes` AS `notes`, `c`.`active` AS `active`, `c`.`date_creation` AS `date_creation`, `c`.`date_modification` AS `date_modification`, `u_validated`.`nom` AS `validated_by_nom`, `u_validated`.`prenom` AS `validated_by_prenom`, `cl`.`nom` AS `client_nom`, `cl`.`prenom` AS `client_prenom`, `cl`.`email` AS `client_email`, `cl`.`telephone` AS `client_telephone` FROM ((`commandes` `c` left join `users` `u_validated` on((`c`.`validated_by` = `u_validated`.`id`))) left join `clients` `cl` on((`c`.`client_id` = `cl`.`id`))) ;

-- --------------------------------------------------------

--
-- Structure de la vue `view_factures_detail`
--
DROP TABLE IF EXISTS `view_factures_detail`;

DROP VIEW IF EXISTS `view_factures_detail`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_factures_detail`  AS SELECT `f`.`id` AS `id`, `f`.`numero_facture` AS `numero_facture`, `f`.`client_id` AS `client_id`, `f`.`commande_id` AS `commande_id`, `f`.`date_facture` AS `date_facture`, `f`.`date_echeance` AS `date_echeance`, `f`.`montant_ht` AS `montant_ht`, `f`.`taux_tva` AS `taux_tva`, `f`.`montant_tva` AS `montant_tva`, `f`.`montant_ttc` AS `montant_ttc`, `f`.`statut` AS `statut`, `f`.`date_paiement` AS `date_paiement`, `f`.`description` AS `description`, `f`.`notes` AS `notes`, `f`.`actif` AS `actif`, `f`.`date_creation` AS `date_creation`, `f`.`date_modification` AS `date_modification`, `cl`.`nom` AS `client_nom`, `cl`.`prenom` AS `client_prenom`, `cl`.`entreprise` AS `client_entreprise`, `cl`.`email` AS `client_email`, `cl`.`telephone` AS `client_telephone`, `cl`.`adresse` AS `client_adresse`, `cl`.`ville` AS `client_ville`, `cl`.`code_postal` AS `client_code_postal`, `c`.`numero_commande` AS `numero_commande`, `c`.`description` AS `commande_description` FROM ((`factures` `f` join `clients` `cl` on((`f`.`client_id` = `cl`.`id`))) left join `commandes` `c` on((`f`.`commande_id` = `c`.`id`))) WHERE ((`f`.`actif` = 1) AND (`cl`.`actif` = 1)) ;

-- --------------------------------------------------------

--
-- Structure de la vue `view_trajets_detail`
--
DROP TABLE IF EXISTS `view_trajets_detail`;

DROP VIEW IF EXISTS `view_trajets_detail`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_trajets_detail`  AS SELECT `t`.`id` AS `id`, `t`.`commande_id` AS `commande_id`, `t`.`vehicule_id` AS `vehicule_id`, `t`.`chauffeur_id` AS `chauffeur_id`, `t`.`date_depart` AS `date_depart`, `t`.`date_arrivee_prevue` AS `date_arrivee_prevue`, `t`.`date_arrivee_reelle` AS `date_arrivee_reelle`, `t`.`distance_km` AS `distance_km`, `t`.`statut` AS `statut`, `t`.`notes` AS `notes`, `t`.`actif` AS `actif`, `t`.`date_creation` AS `date_creation`, `t`.`date_modification` AS `date_modification`, `c`.`numero_commande` AS `numero_commande`, `c`.`adresse_depart` AS `adresse_depart`, `c`.`adresse_arrivee` AS `adresse_arrivee`, `c`.`description` AS `commande_description`, `cl`.`nom` AS `client_nom`, `cl`.`prenom` AS `client_prenom`, `cl`.`entreprise` AS `client_entreprise`, `v`.`immatriculation` AS `vehicule_immat`, `v`.`marque` AS `vehicule_marque`, `v`.`modele` AS `vehicule_modele`, `u`.`nom` AS `chauffeur_nom`, `u`.`prenom` AS `chauffeur_prenom`, `u`.`telephone` AS `chauffeur_telephone` FROM ((((`trajets` `t` join `commandes` `c` on((`t`.`commande_id` = `c`.`id`))) join `clients` `cl` on((`c`.`client_id` = `cl`.`id`))) join `vehicules` `v` on((`t`.`vehicule_id` = `v`.`id`))) join `users` `u` on((`t`.`chauffeur_id` = `u`.`id`))) WHERE ((`t`.`actif` = 1) AND (`c`.`active` = 1) AND (`cl`.`actif` = 1) AND (`v`.`actif` = 1) AND (`u`.`actif` = 1)) ;

-- --------------------------------------------------------

--
-- Structure de la vue `view_vehicules_maintenance`
--
DROP TABLE IF EXISTS `view_vehicules_maintenance`;

DROP VIEW IF EXISTS `view_vehicules_maintenance`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_vehicules_maintenance`  AS SELECT `v`.`id` AS `id`, `v`.`immatriculation` AS `immatriculation`, `v`.`marque` AS `marque`, `v`.`modele` AS `modele`, `v`.`annee` AS `annee`, `v`.`type` AS `type`, `v`.`capacite_poids` AS `capacite_poids`, `v`.`capacite_volume` AS `capacite_volume`, `v`.`consommation` AS `consommation`, `v`.`statut` AS `statut`, `v`.`disponible` AS `disponible`, `v`.`notes` AS `notes`, `v`.`actif` AS `actif`, `v`.`date_creation` AS `date_creation`, `v`.`date_modification` AS `date_modification`, (select max(`m`.`date_maintenance`) from `maintenances` `m` where (`m`.`vehicule_id` = `v`.`id`)) AS `derniere_maintenance`, (select count(0) from `maintenances` `m` where (`m`.`vehicule_id` = `v`.`id`)) AS `nb_maintenances` FROM `vehicules` AS `v` WHERE (`v`.`actif` = 1) ;

--
-- Index pour les tables déchargées
--

--
-- Index pour la table `clients`
--
ALTER TABLE `clients` ADD FULLTEXT KEY `nom` (`nom`,`prenom`,`entreprise`);

--
-- Index pour la table `commandes`
--
ALTER TABLE `commandes` ADD FULLTEXT KEY `description` (`description`,`notes`);

--
-- Contraintes pour les tables déchargées
--

--
-- Contraintes pour la table `commandes`
--
ALTER TABLE `commandes`
  ADD CONSTRAINT `fk_commandes_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_commandes_validated_by` FOREIGN KEY (`validated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Contraintes pour la table `factures`
--
ALTER TABLE `factures`
  ADD CONSTRAINT `fk_factures_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_factures_commande` FOREIGN KEY (`commande_id`) REFERENCES `commandes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Contraintes pour la table `maintenances`
--
ALTER TABLE `maintenances`
  ADD CONSTRAINT `fk_maintenances_vehicule` FOREIGN KEY (`vehicule_id`) REFERENCES `vehicules` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `tarification_history`
--
ALTER TABLE `tarification_history`
  ADD CONSTRAINT `fk_tarification_commande` FOREIGN KEY (`commande_id`) REFERENCES `commandes` (`id`) ON DELETE SET NULL;

--
-- Contraintes pour la table `trajets`
--
ALTER TABLE `trajets`
  ADD CONSTRAINT `fk_trajets_chauffeur` FOREIGN KEY (`chauffeur_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_trajets_commande` FOREIGN KEY (`commande_id`) REFERENCES `commandes` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_trajets_vehicule` FOREIGN KEY (`vehicule_id`) REFERENCES `vehicules` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

--
-- Contraintes pour la table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `fk_users_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE SET NULL;

--
-- Contraintes pour la table `workflow_states`
--
ALTER TABLE `workflow_states`
  ADD CONSTRAINT `fk_workflow_commande` FOREIGN KEY (`commande_id`) REFERENCES `commandes` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_workflow_user` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
