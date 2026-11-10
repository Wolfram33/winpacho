# Privacy Policy — winpacho

*Last updated: 2026-10-24*

winpacho is a free, open-source, portable WAMP stack for Windows (Apache, MariaDB, MySQL, PHP, Adminer and the WinpachoController / WinpachoService control programs). It is developed in the open at <https://github.com/Wolfram33/winpacho>.

**In short: winpacho does not collect, store or transmit any personal data. There is no telemetry, no usage statistics, no crash reporting, no account and no automatic update check.**

## 1. Data the software collects

None. The programs written by this project (`WinpachoController.exe`, `WinpachoService.exe`, the packaging scripts) do not send any information about you, your computer or your usage to the project maintainers or to anyone else.

* No telemetry, analytics or usage tracking.
* No crash or error reports are sent anywhere.
* No unique identifiers are generated or stored.
* No registration, login or account is required.
* No automatic update check: the controller never contacts a server on its own. Checking for a new version is a manual step — you open the GitHub release page in your browser yourself.

## 2. Network connections the software makes

winpacho runs a web server on **your** machine. By default the database listens on `localhost` only; Apache listens on all network interfaces (so other computers can reach your `www` pages unless the Windows firewall blocks them), while the database tool Adminer answers on this computer only. Network activity is limited to what you configure and trigger yourself:

* **Local server traffic:** Apache, the database and PHP answer requests from browsers or applications that connect to your server. If you expose the server to your network or the internet, the access logs written by Apache (`core\apache2\logs`) contain the IP addresses and requested URLs of the visitors — stored locally on your machine only, under your control, and never sent to the project.
* **Scheduled tasks (cron):** the controller's cron feature can fetch a URL at intervals. It only requests the addresses you enter yourself.
* **E-mail (msmtp):** PHP's `mail()` function delivers messages through the SMTP account you configure. Nothing is sent unless your own scripts send mail.
* **Links to the project site:** some menu entries and dialogs open pages such as the GitHub release or documentation page in your default browser. Opening such a page is subject to the privacy policy of the site you visit (GitHub: <https://docs.github.com/site-policy/privacy-policies/github-privacy-statement>).

## 3. Bundled third-party components

The bundle ships software from other vendors unchanged: Apache HTTP Server, MariaDB, MySQL, PHP, Adminer, msmtp and OpenSSL. Their behaviour is governed by their own projects. One point worth knowing:

* **Adminer** has a built-in version check that would ask `adminer.org` for the latest version number when you open it. winpacho switches it off in its Adminer entry page (`home\us_opt1\winpacho-adminer.php`) and removes adminer.org from Adminer's Content-Security-Policy, so the page makes no outside connection. (Up to 2.1.x the bundle shipped phpMyAdmin, whose version check asked `phpmyadmin.net` unless `$cfg['VersionCheck']` was set to `false`.)

None of these components report anything to winpacho.

## 4. Data stored on your computer

Everything the software creates stays inside the folder you unpacked it into (configuration files, databases, logs, certificates, your `www` content). The only exceptions, each triggered explicitly by you from the controller, are:

* entries in the Windows `hosts` file when you create a virtual host,
* a self-signed certificate in the Windows certificate store when you choose *Trust certificate*,
* a Windows service registration when you run the servers as a service.

Nothing is written to the registry otherwise, and deleting the folder removes the software completely.

## 5. Website, downloads and source code

The project has no website of its own. Source code, issue tracker and downloads are hosted on GitHub, whose privacy statement applies when you visit those pages or download files. Donations are handled by PayPal under PayPal's privacy policy; the project receives no personal data from PayPal beyond what PayPal shows the recipient of a payment.

## 6. Code signing

Release binaries may be signed with a certificate provided through the [SignPath Foundation](https://signpath.org). Code signing lets Windows verify that a file has not been altered since it was built; it does not add any data collection to the software.

## 7. Changes to this policy

Changes are made in this file in the repository, where the history of every change is visible. The date at the top shows the last revision.

## 8. Contact

Questions about privacy: open an issue at <https://github.com/Wolfram33/winpacho/issues>.
