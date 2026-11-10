<?php
$version="";

 if (getenv('HOME') == ''){                       // Not set when running as service
   $root= substr($_SERVER["DOCUMENT_ROOT"],0,-4); // this alternative with limitations
 }                                                // gets path to the server folder

 else{                                            // Set when run as standard program
   $root= getenv('HOME');                         // this is the ideal method to
 }                                                // get the path to the server folder

function us_h($text){                             // escape for HTML output
  return htmlspecialchars((string)$text, ENT_QUOTES, 'UTF-8');
}

$file="$root\home\us_config\us_config.ini" ;     // Name and path of configuration file
$settings=false;

if (file_exists($file) && is_readable($file)){   // Check file
  $settings=parse_ini_file($file,true);          // parse file into an array
  if ($settings !== false && isset($settings["APP"]["AppVersion"])){
    $version=$settings["APP"]["AppVersion"];     // get parameter
  }
}

// Database engine: the flavour file of the engine in core\mysql names it and,
// since 2.4.0, its full version (release). It moves with the engine when the
// controller switches between MariaDB and MySQL, so the page always names the
// active one. Older installations: the DatabaseVersion the bundle build stamped
// into us_config.ini up to 2.3.x, then name and major version.
$db_name = "";
$db_release = "";
$db_major = "";
$opt_file = "$root/core/mysql/us_opt.ini";
$opt = is_readable($opt_file) ? parse_ini_file($opt_file, true, INI_SCANNER_RAW) : false;
if (is_array($opt) && isset($opt["USER"]["text"])){
  $db_name    = trim((string)$opt["USER"]["text"]);
  $db_release = trim((string)($opt["USER"]["release"] ?? ""));
  $db_major   = trim((string)($opt["USER"]["version"] ?? ""));
}
$db_ver = "";
if ($db_name !== "" && $db_release !== "" && strpos($db_release, "{") === false){
  $db_ver = "$db_name $db_release";
} elseif ($settings !== false && isset($settings["APP"]["DatabaseVersion"])){
  $db_ver = trim((string)$settings["APP"]["DatabaseVersion"]);
}
if ($db_ver === "" && $db_name !== "") $db_ver = trim("$db_name $db_major");
if ($db_ver === "") $db_ver = "Database engine not installed";
$db_label = $db_name !== "" ? $db_name : "MariaDB/MySQL";

// The other engine waits in core\db_standby (bundles from 2.4.0 on)
$db_standby = "";
foreach (array("mariadb" => "MariaDB", "mysql" => "MySQL") as $dir => $name) {
  if ($name !== $db_name && is_file("$root/core/db_standby/$dir/bin/mysqld_z.exe")) $db_standby = $name;
}

// Database tool: the version from the header of the upstream Adminer file
$tool_file = "$root/home/us_opt1/adminer.php";
$tool_head = is_readable($tool_file) ? file_get_contents($tool_file, false, null, 0, 1024) : false;
if ($tool_head === false) {
  $tool_ver = "Adminer not installed (folder home\\us_opt1)";
} elseif (preg_match('/@version\s+(\d+\.\d+\.\d+)/', $tool_head, $m)) {
  $tool_ver = "Adminer " . $m[1];
} else {
  $tool_ver = "Adminer";
}

// Installed PHP versions: scan core/php* folders so this list can never go stale
$php_installed = array();
foreach (glob("$root/core/php[0-9][0-9]", GLOB_ONLYDIR) as $dir) {
  $name = basename($dir);                        // e.g. php84
  $php_installed[] = substr($name,3,1).".".substr($name,4);  // -> 8.4
}
rsort($php_installed);

$php_active  = PHP_VERSION;                                       // currently running version
$apache_ver  = function_exists('apache_get_version') ? apache_get_version() : 'Apache';
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>winpacho - Splash page</title>
<meta name="Description" content="winpacho - a maintained fork of The Uniform Server ZeroXV" />
<meta name="Keywords" content="winpacho,The Uniform Server,ZeroXV,WAMP,Apache,MariaDB,MySQL,PHP" />
<link rel="icon" href="favicon.ico" />
<link rel="stylesheet" type="text/css" href="css/style.css" media="screen" />
</head>

<body>

<a class="skip-link" href="#main">Skip to main content</a>

<div id="wrap">
  <header id="header">
    <a href="https://github.com/Wolfram33/winpacho">
      <img src="images/logo.png" width="465" height="93" alt="winpacho - portable WAMP server for Windows" />
    </a>
    <div class="server-info">
      <strong>Reload<?php if ($version !== ""){ print " - ".us_h($version); } ?></strong><br />
      <?php print us_h($apache_ver); ?><br />
      <?php print us_h($db_ver); ?><br />
      <?php
        if (count($php_installed) !== 0){
          print "PHP ".us_h(implode(" / ", $php_installed))." (active: ".us_h($php_active).")";
        } else {
          print "PHP ".us_h($php_active);
        }
      ?>
    </div>
  </header>

  <main id="main">
    <h1>Welcome to winpacho</h1>
    <p><strong>winpacho</strong> is a maintained community fork of The Uniform Server ZeroXV. This page and every other file are being served by Apache running from your winpacho folder. Documentation is included in its <strong>docs</strong> subfolder &mdash; see the <a href="/us_docs/manual/index.html">local documentation</a>.</p>

    <h2>This build</h2>
    <p>Everything below ships preinstalled in the all-in-one package &mdash; no further downloads or configuration needed.</p>

    <div class="columns">
      <section class="col">
        <h3>Core</h3>
        <ul>
          <li><strong>WinpachoController</strong></li>
          <li><strong><?php print us_h($apache_ver); ?></strong></li>
          <li><strong>Mail client for PHP - msmtp</strong></li>
          <li><strong>Cron - Scheduler</strong></li>
        </ul>
        <h3>Database</h3>
        <ul>
          <li><strong><?php print us_h($db_ver); ?></strong> (active)</li>
<?php if ($db_standby !== "") { ?>
          <li><?php print us_h($db_standby); ?> on standby &mdash; switch in the controller: <em><?php print us_h($db_label); ?> &gt; Switch database engine to <?php print us_h($db_standby); ?></em></li>
<?php } ?>
          <li>SQLite through PHP (sqlite3, pdo_sqlite) &mdash; no server needed</li>
        </ul>
        <h3>Database Admin</h3>
        <ul>
          <li><strong><a href="/us_opt1/"><?php print us_h($tool_ver); ?></a></strong> &mdash; <?php print us_h($db_label); ?> and SQLite, this computer only. Button <em>Adminer</em> in the controller logs in to <?php print us_h($db_label); ?> by itself; for SQLite see <a href="/us_docs/manual/index.html#sqlite">SQLite files in Adminer</a> in the documentation</li>
        </ul>
      </section>

      <section class="col">
        <h3>PHP Versions (installed)</h3>
        <ul>
          <li><strong>PHP installed as Apache module</strong></li>
          <li><strong>Active: PHP <?php print us_h($php_active); ?></strong></li>
<?php foreach ($php_installed as $v) { print "          <li>PHP ".us_h($v)."</li>\n"; } ?>
        </ul>
        <p>Switch versions in the controller: stop Apache, then <em>PHP &gt; Select PHP version</em>, then start Apache again.</p>
        <h3>HTTPS</h3>
        <p><a href="https://localhost">https://localhost</a> works out of the box and serves the same <strong>www</strong> folder as http. The controller offers to trust the certificate on its first start &mdash; confirm with Yes and restart the browser completely to remove the warning. Any time later: <em>Apache &gt; Apache SSL &gt; Trust certificate in Windows</em>.</p>
        <h3>Virtual hosts</h3>
        <p>Create as many as you like (<em>Apache &gt; Apache Vhosts</em>) &mdash; host names are added to the Windows hosts file automatically and verified, and every vhost is served over http <strong>and</strong> https.</p>
        <h3>PHP Accelerator</h3>
        <ul>
          <li><strong>Zend OpCache</strong></li>
        </ul>
      </section>
    </div>
  </main>

  <footer>
    <p class="footer-links"><a target="_1" rel="noopener" href="https://github.com/Wolfram33/winpacho">GitHub Repository</a> | <a target="_1" rel="noopener" href="https://github.com/Wolfram33/winpacho/releases/tag/latest">Latest Downloads</a> | <a target="_1" rel="noopener" href="https://github.com/Wolfram33/winpacho/issues">Issues / Support</a> | <a href="/us_docs/manual/index.html">Local Documentation</a></p>
    <p><a class="donate" target="_1" rel="noopener" href="https://www.paypal.com/paypalme/robderoy"><span aria-hidden="true">&#9829;</span> Donate via PayPal</a></p>
    <p>winpacho is a portable WAMP package for Windows (64-bit): unpack it anywhere and Apache, MariaDB or MySQL and PHP are ready to run &mdash; no installation, no registry entries, no external dependencies. Updated builds with current PHP versions are published automatically on the <a target="_1" rel="noopener" href="https://github.com/Wolfram33/winpacho/releases/tag/latest">releases page</a>.</p>
    <p class="credits">Originally developed by <a target="_1" rel="noopener" href="https://www.uniformserver.com/">The Uniform Server Development Team</a> &mdash; winpacho (formerly Uniform Server Reload) initiated by Rob de Roy</p>
  </footer>
</div>
</body>
</html>
