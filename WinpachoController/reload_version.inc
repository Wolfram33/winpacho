//winpacho version - single source of truth.
//Read by: default_config_vars.pas (compiled into WinpachoController),
//scripts/build-bundle.ps1 (bundle stamping) and
//.github/workflows/build.yml (exe VersionInfo, release tagging).
//Release procedure: bump this version, commit, tag the commit vX.Y.Z,
//push branch and tag - CI publishes the versioned release.
//PATCH is also raised by scripts/auto-release.ps1 (monthly, when Apache, PHP,
//MariaDB, MySQL or Adminer have updates) - run git pull before bumping by hand.
US_RELOAD_VERSION = '2.4.1';
