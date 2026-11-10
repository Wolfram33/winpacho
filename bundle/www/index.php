<?php
// PHP blocks outside the HTML-comment toggles below are kept free of the
// greater-than sign, so a server without PHP serves this file as clean HTML.
$version="";
$server_name="";
$server_port="";

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

if (file_exists($file) && is_readable($file)){   // Check file
  $settings=parse_ini_file($file,true);          // parse file into an array
  if ($settings !== false && isset($settings["APP"]["AppVersion"])){
    $version=$settings["APP"]["AppVersion"];     // get parameter
  }
}


$file="$root\home\us_config\us_user.ini" ;       // Name and path of user configuration file

if (file_exists($file) && is_readable($file)){     // Check file
  $settings=parse_ini_file($file,true);            // parse file into an array
  if ($settings !== false && isset($settings["USER"]["US_SERVERNAME"])){
    $server_name=$settings["USER"]["US_SERVERNAME"]; // get parameter
  }
  if ($settings !== false && isset($settings["USER"]["AP_PORT"])){
    $server_port=$settings["USER"]["AP_PORT"];       // get parameter
  }
}

// Fall back to sane defaults so the server links stay usable
if ($server_name === ""){ $server_name = "localhost"; }
if (!ctype_digit((string)$server_port) || (int)$server_port < 1 || 65535 < (int)$server_port){
  $server_port = "80";
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>winpacho - test page</title>
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
    <p class="version"><?php if ($version !== ""){ print "v".us_h($version); } ?></p>
  </header>

  <main id="main">
    <h1>Welcome to winpacho</h1>

    <p class="intro">This test page <strong>index.php</strong> was served from the <strong>www</strong> folder of your winpacho installation
    <?php if (0): ?><br />If no PHP module is installed, Apache returns PHP directives un-processed.<?php endif; ?>
    </p>

    <p class="padlock">
      <img src="images/padlock2.gif" width="103" height="148" alt="Open padlock: access is not password protected" />
    </p>

    <p class="intro"><strong><em>Note</em>:</strong> Please read manual page: <a href="/us_docs/manual/quick_start_guide.html#Installing your Website or Test pages">Installing your Website or Test pages</a>.</p>


<!-- server links -->
<!-- <?php print("--" . ">");?>

    <section>
      <h2>Server links</h2>
      <ul class="link-list">
        <li><a href="http://<?php echo(us_h($server_name).':'.us_h($server_port)) ?>/us_splash/index.php" target="_blank">Splash page</a> - Displays server specification and useful links.</li>
        <li><a href="http://<?php echo(us_h($server_name).':'.us_h($server_port)) ?>/us_opt1/index.php" target="_blank">Adminer</a> - Database administration (MariaDB or MySQL, and SQLite, this computer only).</li>
        <li><a href="http://<?php echo(us_h($server_name).':'.us_h($server_port)) ?>/us_extra/phpinfo.php" target="_blank">PHP Info</a> - Active PHP configuration.</li>
      </ul>
    </section>
<?php print("<"."!"."--")?> -->

<!-- subdirs -->
<!-- <?php print("--" . ">");?>

    <section>
      <h2>Served Subdirectories</h2>
      <ul class="link-list">
  <?php
    $dirs = array();
    $entries = scandir("./");
    if ($entries !== false){
      foreach ($entries as $file){
        if (is_dir($file) && !in_array($file, array(".", "..", "css", "images"))){
          $dirs[] = $file;
        }
      }
    }
    if (count($dirs) === 0){
      echo "        <li class=\"empty\">None</li>\n";
    } else {
      foreach ($dirs as $dir){
        echo "        <li><a href=\"".us_h(rawurlencode($dir))."/\" target=\"_blank\">".us_h($dir)."</a></li>\n";
      }
    }
  ?>
      </ul>
    </section>
<?php print("<"."!"."--")?> -->


<!-- php files -->
<!-- <?php print("--" . ">");?>

    <section>
      <h2>Served PHP Files</h2>
      <ul class="link-list">
  <?php
    $php_files = array();
    $entries = scandir("./");
    if ($entries !== false){
      foreach ($entries as $file){
        if (is_file($file) && strtolower((string)strrchr($file, '.')) === ".php" && $file !== "index.php"){
          $php_files[] = $file;
        }
      }
    }
    if (count($php_files) === 0){
      echo "        <li class=\"empty\">None</li>\n";
    } else {
      foreach ($php_files as $php_file){
        echo "        <li><a href=\"".us_h(rawurlencode($php_file))."\" target=\"_blank\">".us_h($php_file)."</a></li>\n";
      }
    }
  ?>
      </ul>
    </section>
<?php print("<"."!"."--")?> -->

  </main>

  <footer>
    <p class="footer-links"><a href="https://github.com/Wolfram33/winpacho">GitHub Repository</a> | <a href="https://github.com/Wolfram33/winpacho/releases/tag/latest">Latest Downloads</a> | <a href="/us_docs/manual/index.html">Local Documentation</a></p>
    <p><a class="donate" href="https://www.paypal.com/paypalme/robderoy" rel="noopener"><span aria-hidden="true">&#9829;</span> Donate via PayPal</a></p>
    <p class="credits">Originally developed by <a href="https://www.uniformserver.com/">The Uniform Server Development Team</a> &mdash; winpacho (formerly Uniform Server Reload) initiated by Rob de Roy</p>
  </footer>
</div>
</body>
</html>
