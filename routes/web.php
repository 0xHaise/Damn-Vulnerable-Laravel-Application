<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
 * Página principal
 */
Route::get('/', function () {
    return response()->view('welcome');
});

/*
 * UI del laboratorio
 */
Route::get('/lab', function() {
    return response()->view('lab');
});

/*
 * ⚠️ VULNERABLE: Path Traversal
 * 
 * Este endpoint permite descargar archivos sin validación
 * Ejemplos de ataque:
 *   /download?filename=hello.txt              (legítimo)
 *   /download?filename=../../.env             (path traversal)
 *   /download?filename=../../composer.json    (path traversal)
 */
Route::get('/download', function(Request $request) {
    $filename = $request->input('filename');

    // ⚠️ VULNERABLE: Concatenación sin sanitización
    $path = storage_path('content/') . $filename;

    if (!file_exists($path)) {
        return response('File not found', 404);
    }

    return response()->download($path);
});

/*
 * ✅ SEGURO: Download con basename()
 * Elimina cualquier intento de path traversal
 */
Route::get('/download-secure', function(Request $request) {
    $filename = basename($request->input('filename'));
    $path = storage_path('content/') . $filename;

    if (!file_exists($path)) {
        return response('File not found', 404);
    }

    return response()->download($path);
});

/*
 * ✅ SEGURO: Download con validación realpath()
 * Valida que el archivo esté dentro del directorio permitido
 */
Route::get('/download-realpath', function(Request $request) {
    $filename = $request->input('filename');
    $basePath = realpath(storage_path('content/'));
    $fullPath = realpath($basePath . '/' . $filename);

    if (!$fullPath || strpos($fullPath, $basePath) !== 0) {
        return response('Access denied', 403);
    }

    if (!file_exists($fullPath)) {
        return response('File not found', 404);
    }

    return response()->download($fullPath);
});

/*
 * ✅ SEGURO: Download con allow-list
 * Solo permite archivos específicos
 */
Route::get('/download-allowlist', function(Request $request) {
    $filename = $request->input('filename');
    
    $allowedFiles = [
        'hello.txt',
        'document.pdf',
        'image.jpg'
    ];

    if (!in_array($filename, $allowedFiles, true)) {
        return response('File not allowed', 403);
    }

    $path = storage_path('content/') . $filename;

    if (!file_exists($path)) {
        return response('File not found', 404);
    }

    return response()->download($path);
});

// ===============================================================================
// Rutas de Open Redirect
// ===============================================================================

/*
 * ⚠️ VULNERABLE: Open Redirect
 * 
 * Redirige a cualquier URL sin validación
 * Ejemplos de ataque:
 *   /redirect-vuln?url=http://evil.example.com
 *   /redirect-vuln?url=http://phishing-site.com/fake-login
 */
Route::get('/redirect-vuln', function(Request $request) {
    $target = $request->input('url', '/');
    
    // ⚠️ VULNERABLE: Sin validación
    return redirect($target);
});

/*
 * ✅ SEGURO: Redirect con allow-list de hosts
 */
Route::get('/redirect-safe', function(Request $request) {
    $target = $request->input('url', '');
    
    if (empty($target)) {
        return response('Missing url parameter', 400);
    }

    $parts = parse_url($target);
    
    if ($parts === false) {
        return response('Invalid URL', 400);
    }

    $allowedHosts = [
        'localhost',
        '127.0.0.1',
        'example.com',
    ];

    if (isset($parts['host'])) {
        $scheme = isset($parts['scheme']) ? strtolower($parts['scheme']) : '';
        $host = strtolower($parts['host']);
        
        if (!in_array($host, $allowedHosts, true) || !in_array($scheme, ['http','https'], true)) {
            return response('Redirect not allowed', 403);
        }
        
        return redirect($target);
    }

    if (isset($parts['path']) && str_starts_with($parts['path'], '/')) {
        return redirect($target);
    }

    return response('Redirect not allowed', 403);
});

/*
 * ✅ SEGURO: Solo rutas relativas
 */
Route::get('/redirect-validate', function(Request $request) {
    $target = $request->input('url', '/');
    
    if (filter_var($target, FILTER_VALIDATE_URL)) {
        return response('Only relative paths allowed', 403);
    }
    
    if (str_starts_with($target, '/')) {
        return redirect($target);
    }
    
    return response('Invalid redirect target', 400);
});