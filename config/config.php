<?php
// Main configuration file for logiswayz system
define('APP_NAME', 'LogisWayZ');
define('APP_VERSION', '1.0.0');
define('APP_ENV', $_ENV['APP_ENV'] ?? 'production');
define('BASE_URL', $_ENV['BASE_URL'] ?? 'http://localhost:5000');

// Security settings
define('JWT_SECRET', $_ENV['JWT_SECRET'] ?? 'V1cT0rieux');
define('SESSION_LIFETIME', 3600 * 8); // 8 hours
define('PASSWORD_MIN_LENGTH', 8);

// File upload settings
define('MAX_FILE_SIZE', 5 * 1024 * 1024); // 5MB
define('UPLOAD_PATH', 'uploads/');

// PDF settings
define('PDF_COMPANY_NAME', $_ENV['COMPANY_NAME'] ?? 'LogisWayZ');
define('PDF_COMPANY_ADDRESS', $_ENV['COMPANY_ADDRESS'] ?? 'Terminus 47, yopougon/Abidjan');
define('PDF_COMPANY_PHONE', $_ENV['COMPANY_PHONE'] ?? '01 60 50 24 00');
define('PDF_COMPANY_EMAIL', $_ENV['COMPANY_EMAIL'] ?? 'logiswayz@gmail.com');

// Time zone
date_default_timezone_set('africa/Abidjan');

// Error reporting based on environment
if (APP_ENV === 'development') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
} else {
    error_reporting(0);
    ini_set('display_errors', 0);
}

// Start session
session_start();
?>
