<?php

// Ce script sert de routeur pour le serveur web intégré de PHP.
// Il garantit que les requêtes sont traitées de manière sécurisée et correcte,
// en utilisant le dossier 'public' comme racine de documents.

$uri = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));

// Si la ressource demandée est un fichier ou un dossier qui existe réellement
// dans le dossier public, le serveur intégré de PHP le servira directement.
// Cette condition est une sécurité supplémentaire pour s'assurer que nous
// passons au routeur principal uniquement lorsque c'est nécessaire.
$requested_path = __DIR__ . '/public' . $uri;

if ($uri !== '/' && file_exists($requested_path) && !is_dir($requested_path)) {
    // Laisse le serveur intégré de PHP gérer la requête.
    return false;
}

// Pour toutes les autres requêtes (ex: /api/..., ou les routes du frontend),
// on charge le contrôleur frontal principal de l'application (index.php à la racine).
// C'est lui qui contient la logique de routage de l'API.
require_once __DIR__ . '/index.php';