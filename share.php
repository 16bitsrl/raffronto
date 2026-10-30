<?php
// Raffronto: keeps a shared comparison for 7 days.
// The browser encrypts the two documents and the view state before uploading them; the key lives only
// in the link fragment (#s=<id>.<key>), which browsers never send to the server. Here we only see ciphertext.
//
// HTTP  POST share.php            raw body (application/octet-stream) -> 201 {"id": "...", "expires": <unix>}
//       GET  share.php?id=<id>    -> the stored bytes, header X-Expires: <unix>
// CLI   php share.php cleanup     deletes expired shares (run it from cron)
//
// Storage lives outside the web root: RAFFRONTO_STORAGE if set, otherwise
// /home/forge/tools.16bit.cloud/storage/raffronto on the server and /tmp/raffronto-share elsewhere.

declare(strict_types=1);

const TTL = 7 * 86400;
const MAX_FILE = 10_000_000;               // per document (checked by the browser, which knows the sizes)
const MAX_BODY = 2 * MAX_FILE + 65_536;    // two documents + view state + encryption overhead; under nginx/PHP 20M
const MAX_STORAGE = 2_000_000_000;         // all shares together
const RATE_MAX = 20;                       // new links per address...
const RATE_WINDOW = 3600;                  // ...per hour
const PROD_DIR = '/home/forge/tools.16bit.cloud/public/raffronto';
const PROD_STORAGE = '/home/forge/tools.16bit.cloud/storage/raffronto';

function storage(): string
{
    $dir = getenv('RAFFRONTO_STORAGE') ?: (__DIR__ === PROD_DIR ? PROD_STORAGE : '/tmp/raffronto-share');
    return rtrim($dir, '/');
}

function blobs(): string
{
    $dir = storage() . '/blobs';
    if (!is_dir($dir) && !@mkdir($dir, 0700, true) && !is_dir($dir)) {
        fail(500, 'storage unavailable');
    }
    return $dir;
}

function fail(int $status, string $error): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => $error]);
    exit;
}

function expired(string $path): bool
{
    return filemtime($path) + TTL <= time();
}

function cleanup(): int
{
    $removed = 0;
    foreach (glob(blobs() . '/*') ?: [] as $path) {
        $name = basename($path);
        $stale = str_starts_with($name, 'tmp-') ? filemtime($path) < time() - 3600 : expired($path);
        if ($stale && @unlink($path)) {
            $removed++;
        }
    }
    foreach (glob(storage() . '/rate/*') ?: [] as $path) {
        if (filemtime($path) < time() - RATE_WINDOW) {
            @unlink($path);
        }
    }
    return $removed;
}

// true when this address may create another link; counts the attempt
function allowed(string $ip): bool
{
    $dir = storage() . '/rate';
    if (!is_dir($dir) && !@mkdir($dir, 0700, true) && !is_dir($dir)) {
        return true;
    }
    $fh = fopen($dir . '/' . hash('sha256', 'raffronto|' . $ip), 'c+');
    if (!$fh) {
        return true;
    }
    flock($fh, LOCK_EX);
    $now = time();
    $hits = array_filter(json_decode(stream_get_contents($fh) ?: '[]', true) ?: [], fn ($t) => is_int($t) && $t > $now - RATE_WINDOW);
    $ok = count($hits) < RATE_MAX;
    if ($ok) {
        $hits[] = $now;
    }
    ftruncate($fh, 0);
    rewind($fh);
    fwrite($fh, json_encode(array_values($hits)));
    flock($fh, LOCK_UN);
    fclose($fh);
    return $ok;
}

if (PHP_SAPI === 'cli') {
    if (($argv[1] ?? '') !== 'cleanup') {
        fwrite(STDERR, "usage: php share.php cleanup\n");
        exit(2);
    }
    echo 'removed ' . cleanup() . "\n";
    exit(0);
}

header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
header('X-Robots-Tag: noindex');
header('Referrer-Policy: no-referrer');

$method = $_SERVER['REQUEST_METHOD'] ?? '';

if ($method === 'GET') {
    $id = $_GET['id'] ?? null;
    if (!is_string($id) || !preg_match('/\A[0-9a-f]{32}\z/', $id)) {
        fail(400, 'invalid id');
    }
    $path = blobs() . '/' . $id;
    if (!is_file($path)) {
        fail(404, 'not found');
    }
    if (expired($path)) {
        fail(410, 'expired');
    }
    header('Content-Type: application/octet-stream');
    header('Content-Length: ' . filesize($path));
    header('X-Expires: ' . (filemtime($path) + TTL));
    readfile($path);
    exit;
}

if ($method !== 'POST') {
    header('Allow: GET, POST');
    fail(405, 'method not allowed');
}
if (strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0])) !== 'application/octet-stream') {
    fail(415, 'expected application/octet-stream');
}
$length = (int) ($_SERVER['CONTENT_LENGTH'] ?? 0);
if ($length > MAX_BODY) {
    fail(413, 'too large');
}
if ($length <= 0) {
    fail(400, 'empty body');
}
if (!allowed($_SERVER['REMOTE_ADDR'] ?? '')) {
    header('Retry-After: ' . RATE_WINDOW);
    fail(429, 'too many links, try again later');
}
$dir = blobs();
$used = 0;
foreach (glob($dir . '/*') ?: [] as $path) {
    $used += (int) @filesize($path);
}
if ($used + $length > MAX_STORAGE) {
    cleanup();
    clearstatcache();
    $used = array_sum(array_map(fn ($p) => (int) @filesize($p), glob($dir . '/*') ?: []));
    if ($used + $length > MAX_STORAGE) {
        fail(507, 'storage full');
    }
}

// copy the body to a temporary file, never more than MAX_BODY bytes, then move it in place
$tmp = $dir . '/tmp-' . bin2hex(random_bytes(8));
$in = fopen('php://input', 'rb');
$out = fopen($tmp, 'xb');
if (!$in || !$out) {
    fail(500, 'storage unavailable');
}
$size = stream_copy_to_stream($in, $out, MAX_BODY + 1);
fclose($in);
fclose($out);
if ($size === false || $size === 0 || $size > MAX_BODY) {
    @unlink($tmp);
    fail($size > MAX_BODY ? 413 : 400, $size > MAX_BODY ? 'too large' : 'empty body');
}
chmod($tmp, 0600);
do {
    $id = bin2hex(random_bytes(16));
} while (file_exists("$dir/$id"));
rename($tmp, "$dir/$id");

http_response_code(201);
header('Content-Type: application/json; charset=utf-8');
echo json_encode(['id' => $id, 'expires' => filemtime("$dir/$id") + TTL]);
