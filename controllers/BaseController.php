<?php
namespace App\Controllers;

use App\Models\Database;

// Base controller class for common functionality
abstract class BaseController {
    protected $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * Send JSON response
     */
    protected function jsonResponse($data, $statusCode = 200) {
        http_response_code($statusCode);
        header('Content-Type: application/json');
        echo json_encode($data, JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    /**
     * Send error response
     */
    protected function errorResponse($message = 'Erreur', $code = 400) {
        http_response_code($code);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => $message]);
        exit;
    }
    
    /**
     * Send success response
     */
    protected function successResponse($data = null, $message = 'OK', $statusCode = 200) {
        $response = ['success' => true];
        if ($message) $response['message'] = $message;
        if ($data) $response['data'] = $data;
        $this->jsonResponse($response, $statusCode);
    }
    
    /**
     * Get request body as JSON
     */
    protected function getRequestBody() {
        $input = file_get_contents('php://input');
        return json_decode($input, true);
    }

    /**
     * Get JSON input (alias for getRequestBody)
     */
    protected function getJsonInput() {
        return $this->getRequestBody();
    }

    /**
     * Get query parameter with default value
     */
    protected function getQueryParam($key, $default = null) {
        return $_GET[$key] ?? $default;
    }
    
    /**
     * Validate required fields
     */
    protected function validateRequired($data, $fields) {
        $missing = [];
        foreach ($fields as $field) {
            if (!isset($data[$field]) || empty($data[$field])) {
                $missing[] = $field;
            }
        }
        
        if (!empty($missing)) {
            $this->errorResponse('Champs requis manquants: ' . implode(', ', $missing));
        }
    }
    
    /**
     * Sanitize input data
     */
    protected function sanitizeInput($data) {
        if (is_array($data)) {
            return array_map([$this, 'sanitizeInput'], $data);
        }
        return htmlspecialchars(trim($data), ENT_QUOTES, 'UTF-8');
    }
}
?>
