<?php
// Main entry point for the system
// Autoload dependencies
require_once __DIR__ . '/vendor/autoload.php';

// Load configuration (not managed by autoloader)
require_once 'config/config.php';

// Enable CORS for API requests
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Simple routing system
$requestUri = $_SERVER['REQUEST_URI'];
$requestMethod = $_SERVER['REQUEST_METHOD'];

// Remove query string from URI
$uri = parse_url($requestUri, PHP_URL_PATH);

// Handle API routes
if (strpos($uri, '/api/') === 0) {
    require_once 'routes/api.php';
    exit();
}

// Handle specific routes
if ($uri === '/') {
    header('Location: /public/loading.html');
    exit();
} elseif ($uri === '/client-tracking.html') {
    header('Location: /public/client-tracking.html');
    exit();
} elseif ($uri === '/test_new_features.html') {
    require_once 'test_new_features.html';
    exit();
} elseif ($uri === '/loading.php') {
    header('Location: /public/loading.html');
    exit();
}

// Check if file exists in public directory
$publicFile = __DIR__ . '/public' . $uri;
if (file_exists($publicFile) && !is_dir($publicFile)) {
    // Let PHP serve the file
    return false;
}

// Handle 404
http_response_code(404);
echo json_encode(['error' => 'Route non trouvée']);
?>
