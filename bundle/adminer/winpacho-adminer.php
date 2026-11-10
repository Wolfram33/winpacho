<?php
/**
 * winpacho settings for Adminer, loaded by index.php through adminer_object().
 *
 * - Opening the page without parameters (the controller's Adminer button) logs in
 *   to the active database engine (MariaDB or MySQL, whichever sits in core\mysql)
 *   as root, with the password from htpasswd\mysql\passwd.txt
 *   that WinpachoController keeps up to date - the comfort phpMyAdmin's
 *   auth_type 'config' offered before 2.2.0. Logging out leads to the normal
 *   login form, where SQLite or another server can be chosen.
 * - SQLite has no passwords of its own; Adminer refuses such logins unless it checks
 *   a password itself (Adminer\Password). winpacho uses the database root password.
 * - No version check and no adminer.org in the Content-Security-Policy:
 *   winpacho makes no outside calls at run time.
 * The folder is reachable from this computer only (Require local in httpd.conf),
 * because the automatic login opens the databases to whoever reaches the page.
 */
declare(strict_types=1);

final class WinpachoAdminer extends Adminer\Plugin
{
    private const DB_HOST = '127.0.0.1';
    private const DEFAULT_PORT = 3306;
    private const MAX_PASSWORD_LENGTH = 41;   // limit of WinpachoController's password dialog
    private const ADMINER_ORG = 'https://www.adminer.org';
    private const CONNECT_TIMEOUT_SEC = 1;    // local server: answers at once or not at all
    private const LOOPBACK_ADDRESSES = ['127.0.0.1', '::1'];
    private const LOCAL_HOST_NAMES = ['localhost', '127.0.0.1', '[::1]'];
    private const ENGINES = ['MariaDB', 'MySQL'];   // names core\mysql\us_opt.ini may carry
    private const DEFAULT_ENGINE = 'MariaDB';

    private string $server;
    private ?string $rootPassword;
    private bool $autoLogin;
    private bool $serverDown;
    private bool $notLocal;
    private string $engine;

    private function __construct(string $server, ?string $rootPassword, bool $autoLogin, bool $serverDown, bool $notLocal)
    {
        $this->server = $server;
        $this->rootPassword = $rootPassword;
        $this->autoLogin = $autoLogin;
        $this->serverDown = $serverDown;
        $this->notLocal = $notLocal;
        $this->engine = self::engineName();
    }

    /** Name of the active engine for the hints: core\mysql\us_opt.ini, written by the engine's module. */
    private static function engineName(): string
    {
        $file = dirname(__DIR__, 2) . '/core/mysql/us_opt.ini';
        if (!is_file($file) || !is_readable($file)) {
            return self::DEFAULT_ENGINE;
        }
        $ini = parse_ini_file($file, true, INI_SCANNER_RAW);
        $name = is_array($ini) ? trim((string) ($ini['USER']['text'] ?? '')) : '';
        return in_array($name, self::ENGINES, true) ? $name : self::DEFAULT_ENGINE;
    }

    /** Request from this computer to one of its own names (localhost, loopback, the controller's server name). */
    private static function isLocalRequest(): bool
    {
        if (!in_array($_SERVER['REMOTE_ADDR'] ?? '', self::LOOPBACK_ADDRESSES, true)) {
            return false;
        }
        $host = strtolower((string) ($_SERVER['HTTP_HOST'] ?? ''));
        $host = preg_replace('/:\d+$/', '', $host);   // drop the port, keeps [::1]
        $names = self::LOCAL_HOST_NAMES;
        $serverName = strtolower((string) getenv('US_SERVERNAME'));   // set by WinpachoController for Apache
        if ($serverName !== '' && preg_match('/^[a-z0-9.-]{1,253}$/', $serverName)) {
            $names[] = $serverName;
        }
        return in_array($host, $names, true);
    }

    /** The hook object handed to Adminer: this plugin, plus the SQLite password check. */
    public static function plugins(): Adminer\Plugins
    {
        $port = self::port();
        $server = self::DB_HOST . ':' . $port;
        $password = self::readRootPassword();
        // Only the bare page is the controller's button; any parameter means the
        // user is already working in Adminer or has just logged out.
        $bare = ($_SERVER['REQUEST_METHOD'] ?? '') === 'GET' && $_GET === [] && $_POST === [];
        // Checked here, not only by Require local in httpd.conf: an updated
        // installation may lack that line, and a foreign site can point its own
        // host name at 127.0.0.1 (DNS rebinding) - its requests do come from
        // this computer, but not under one of our host names.
        $trusted = self::isLocalRequest();
        // A login against a stopped server ends in Adminer's misleading
        // "Session expired"; the form says what is wrong instead.
        $serverDown = $bare && $trusted && !self::isListening($port);
        $autoLogin = $bare && $trusted && !$serverDown && $password !== null;
        if ($autoLogin) {
            $_POST['auth'] = ['driver' => 'server', 'server' => $server, 'username' => 'root', 'password' => $password, 'db' => ''];
        }
        $plugins = [new self($server, $password, $autoLogin, $serverDown, $bare && !$trusted)];
        // password_hash() is deliberately slow, so only SQLite requests pay for it
        if ($password !== null && isset($_GET['sqlite'])) {
            $plugins[] = new Adminer\Password(password_hash($password, PASSWORD_DEFAULT));
        }
        return new Adminer\Plugins($plugins);
    }

    /** Database port: the controller passes it to Apache in MYSQL_TCP_PORT. */
    private static function port(): int
    {
        $port = getenv('MYSQL_TCP_PORT');
        if (is_string($port) && ctype_digit($port) && (int) $port >= 1 && (int) $port <= 65535) {
            return (int) $port;
        }
        return self::DEFAULT_PORT;
    }

    private static function isListening(int $port): bool
    {
        // The failed connect raises a warning; the result is handled right here
        set_error_handler(static fn (): bool => true);
        try {
            $socket = stream_socket_client('tcp://' . self::DB_HOST . ':' . $port, $errno, $errstr, self::CONNECT_TIMEOUT_SEC);
        } finally {
            restore_error_handler();
        }
        if ($socket === false) {
            return false;
        }
        fclose($socket);
        return true;
    }

    /** First line of htpasswd\mysql\passwd.txt, or null when missing or not a valid password. */
    private static function readRootPassword(): ?string
    {
        $file = dirname(__DIR__, 2) . '/htpasswd/mysql/passwd.txt';
        if (!is_file($file) || !is_readable($file)) {
            return null;
        }
        $lines = file($file, FILE_IGNORE_NEW_LINES);
        if ($lines === false || $lines === []) {
            return null;
        }
        $password = trim($lines[0]);
        if ($password === '' || strlen($password) > self::MAX_PASSWORD_LENGTH || !preg_match('/^[\x21-\x7E]+$/', $password)) {
            return null;
        }
        return $password;
    }

    /** The synthesized login of the button carries no CSRF token; real form logins keep the check. */
    public function verifyLoginToken()
    {
        return $this->autoLogin ? false : null;
    }

    public function verifyVersion()
    {
        return false;
    }

    /** Adminer allows adminer.org for its version check; winpacho has none, so it goes. */
    public function csp(array $csp)
    {
        foreach ($csp as $i => $directives) {
            foreach ($directives as $name => $sources) {
                $kept = trim(preg_replace('/\s+/', ' ', str_replace(self::ADMINER_ORG, '', $sources)));
                $csp[$i][$name] = $kept === '' ? "'none'" : $kept;
            }
        }
        return $csp;
    }

    public function serverName($server)
    {
        return $server === $this->server ? 'winpacho' : null;
    }

    /** Printed above Adminer's own login form: what to enter for winpacho's databases. */
    public function loginForm()
    {
        $port = substr($this->server, strlen(self::DB_HOST) + 1);
        $e = $this->engine;
        $lines = [
            'winpacho - ' . $e . ': System "MySQL / MariaDB", Server ' . $this->server . ', Username root,'
                . ' Password = the ' . $e . ' root password (default root; change it in WinpachoController under'
                . ' ' . $e . ' > Change ' . $e . ' root password). The Adminer button of the controller logs in by itself.',
            'SQLite: System "SQLite", Database = full path of the database file (for example'
                . ' C:\\winpacho\\www\\app\\data.sqlite), Username empty, Password = the same ' . $e . ' root password.',
        ];
        if ($this->notLocal) {
            $lines[] = 'No automatic login: this page was not opened from this computer as http://localhost/us_opt1/'
                . ' (or the server name set in WinpachoController). Log in with the root password instead.';
        }
        if ($this->serverDown) {
            $lines[] = $e . ' is not running (nothing answers on ' . $this->server . '). Start it in WinpachoController'
                . ' (Start ' . $e . '), then click the Adminer button again - or log in to SQLite below.';
        }
        if ($this->rootPassword === null) {
            $lines[] = 'The password file htpasswd\\mysql\\passwd.txt could not be read, so the automatic login and'
                . ' the SQLite login are off. Start WinpachoController once or set the ' . $e . ' password again'
                . ' (' . $e . ' > Change ' . $e . ' root password); both write the file.';
        }
        if ($port !== (string) self::DEFAULT_PORT) {
            $lines[] = $e . ' runs on port ' . $port . ' in this installation (WinpachoController > ' . $e . ' > Change ' . $e . ' port).';
        }
        foreach ($lines as $line) {
            echo '<p class="message">' . htmlspecialchars($line, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') . "</p>\n";
        }
        return null;
    }
}
