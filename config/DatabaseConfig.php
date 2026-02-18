<?php
namespace App\Config;

// Database configuration for logiswayz system
class DatabaseConfig {
    public static function getConfig() {
        return [
            'host' => $_ENV['DB_HOST'] ?? 'localhost',
            'username' => $_ENV['DB_USERNAME'] ?? 'root',
            'password' => $_ENV['DB_PASSWORD'] ?? '',
            'database' => $_ENV['DB_NAME'] ?? 'logistique_db',
            'charset' => 'utf8mb4',
            'port' => $_ENV['DB_PORT'] ?? 3306
        ];
    }
    
    public static function getDSN() {
        $config = self::getConfig();
        return "mysql:host={$config['host']};port={$config['port']};dbname={$config['database']};charset={$config['charset']}";
    }
}
?>