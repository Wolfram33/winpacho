unit us_common_procedures;

{#############################################################################
'# Name: us_common_procedures.inc
'# Developed By: The Uniform Server Development Team
'# Web: https://www.uniformserver.com
'#############################################################################}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,Dialogs,Forms,
  default_config_vars,
  us_common_functions,
  JwaTlHelp32,windows,Process,
  Graphics, Controls,
  RegExpr, LazFileUtils, FileUtil,
  ExtCtrls, LCLType, INIFiles, registry, ShellApi,
  fileinfo, winpeimagereader;

//=== General ===
 procedure us_set_environment_path;             //Set enironment path
 procedure us_set_additional_environment_vars;  //Set additional enironment variables defined in config
 procedure us_ini_set(IniFile:string;section:string;variable:string;value:string); //Set value in ini configuration file
 procedure us_clean_up;                     // Delete listed files and delete files in listed folders
 procedure us_rotate_log(const log_file:string);       // Shift an oversized log into its ring of older parts
 procedure us_delete_log_parts(const log_file:string); // Delete the older parts (<log>.1 ..) of a rotated log
 procedure us_rotate_app_logs;              // Rotate the logs Apache's rotatelogs does not cover
 procedure us_set_icon_and_hover_text;      // Set icon displayed and hover text based on ServerType in config file
 procedure KillRunningProcess(ProcessName: string);        // Kill named process
 procedure us_display_in_editor(FileToDisplay: string);    // Display page in editor default - notepad
 procedure us_warn_if_vcruntime_too_old(php_sel:string);   // Warn when Apache or the selected PHP needs a newer VC++ runtime

 //=== Apache ===
procedure us_prepare_rotatelogs;          // Windowless log writer bin\rotatelogs_z.exe + 1.3.3 config migration
procedure us_start_apache_program;        // Start Apache as a standard program
procedure us_kill_apache_program;         // Kills Apache running as a standard program
procedure us_apache_syntax_check;         // Runs Apache with -t performs a syntax check
procedure apache_indicator(state:String); // Apache Bi-state indicator

procedure us_enable_apache_ssl;           // Enable Apache ssl in configuration file httpd.conf
procedure us_disable_apache_ssl;          // Disable Apache ssl in configuration file httpd.conf
procedure us_auto_generate_ssl_cert;      // First start: generate localhost certificate and enable SSL
procedure us_generate_ssl_cert(san_ext:string; overwrite:boolean); // Generate self-signed cert with given subjectAltName
procedure us_regenerate_cert_for_all_vhosts; // Rebuild cert covering localhost + all vhost domains
procedure us_trust_ssl_cert;              // Add server certificate to the Windows user certificate store
procedure us_offer_trust_ssl_cert_once;   // First interactive start: offer to trust the certificate (asked once)

//=== MySQL ===
procedure us_start_mysql_program;                   // Start MySQL as a standard program
procedure us_kill_mysql_program;                    // Kills MySQL running as a standard program
procedure us_clean_stop_mysql_program;              // Clean stop MySQL program. Using a name and password last resort Kills
procedure mysql_indicator(state:String);            // MySQL Bi-state indicator
procedure us_display_mysql_prompt;                  // Display MySQL command console and open MySQL prompt
procedure us_save_mysql_password(my_pwd_in:String); // Save MySQL password to file

procedure us_create_mysql_database(database_name:string); // Create MySQL Database using mysqladmin 
procedure us_drop_mysql_database(database_name:string);   // Delete(Drop) MySQL Database using mysqladmin 

//=== MySQL Change root password ===
procedure mysql_change_root_password(new_password:string);  // Runs/stops server chnages password

//=== MySQL restore root password ===
procedure mysql_restore_root_password;                      // Restore MySQL server root password.



//=== Display Server Console ===
procedure us_open_console(const ATitle, AWorkDir: String; const ACommand: array of String); // Interactive console in Reload look (Windows Terminal, translucent), classic cmd fallback
procedure us_display_server_console;   // Display console at root folder
procedure us_display_uniservice;       // Launch WinpachoService (Windows service module, UAC prompt)

//=== Windows services (installed by WinpachoService) ===
function us_run_elevated(const exe, params, work_dir:string; wait_ms:DWORD):boolean; // Run a program via UAC prompt and wait for it
function us_control_windows_service(const service_name:string; start:boolean):boolean; // Start/stop a service elevated, wait for the new state

//=== Perl
procedure force_shebang_update(NEW_SHEBANG:string); // Update shebang in all perl scripts

//=== PHP
procedure disable_all_php_accelerators;               // Disable all enabled accelerators
procedure enable_php_accelerator(accelerator:String); // Enable named PHP accelerator in selected PHP ini configuration file
procedure view_selected_acc_control_panel;            // View selected accelerator, control pannel

//=== Message Dialogs
procedure msg_restart_apache;                  // Check Apache runnning and inform user to restart Apache
procedure msg_stop_mysql_port_change;          // Port change inform user to stop MySQL Server
procedure msg_stop_mysql_pwd_change;           // Password change inform user to stop MySQL server
procedure msg_password_file_contains_defaults; // Password file contains defaults
procedure msg_password_file_empty;             // Password file empty


//=== GO PEAR ===
procedure us_update_go_pear_config; //updates paths in go-pear configuration file

//=== PALE MOON BROWSER ===
procedure us_start_palemoon;                // Start Portable Pale Moon browser
procedure us_kill_palemoon;                 // Kills Pale Moon Browser

//=== DEFAULT BROWSER ===
procedure us_start_default_browser;        // Start Default browser

//=== DISPLAY IN BROWSER ===
procedure browser_display_url(url:string); // Display page in Pale Moon

//=== PAC ===
procedure us_add_to_pac_file(host:string);       // Add new host - domain name/IP to PAC file
procedure us_delete_from_pac_file(host:string);  // Remove host  - domain name/IP from PAC file
procedure us_proxy_file_port_update(old_port:string;new_port:string); //Update PAC file with new port

//=== HOSTS ===
procedure us_launch_edit_hosts_utility;            // Launches - Uniform Server Windows hosts file utility
function  us_hosts_file_path:string;               // Full path of the Windows hosts file
procedure us_add_to_hosts_file(host:string);       // Add new host - domain name/IP to hosts file
procedure us_add_many_to_hosts_file(hosts:TStrings); // Same for several hosts, one write (one UAC prompt)
function  us_is_valid_hostname(const h:string): boolean; // Plain host name: letters/digits/dot/hyphen
procedure us_delete_from_hosts_file(host:string);  // Remove host  - domain name/IP from hosts file

//===END===


implementation

uses
    main_unit;

//=== General ===
 
{****************************************************************************
 This procedure sets the environment PATH.

  Used by us_main_init
  Also used by elements that change the path:
   TMain.MMSS_php70Click    - PHP select buttons
   TMain.MMSS_php71Click    - change the
   TMain.MMSS_php72Click    - environment paths
   TMain.MMSS_php73Click
   TMain.MMSS_php74Click
   TMain.MMSS_php80Click
   TMain.MMSS_php81Click
   TMain.MMSS_php82Click
   TMain.MMSS_php83Click
   TMain.MMSS_php84Click
   TMain.MMSS_php85Click

  ORIGINAL_ENV_PATH - Original environment path when controller started

  Procedure first reads additional environment path variables
  these are user definable in file home\us_config\us_config.ini
  under the section named [ENV_PATHS]
  Variable format is path=value
  If the value contains the constant %UniConPath% it is expanded
  to a full path.

============================================================================}
procedure us_set_environment_path;
var
 path:        string;                // Temp var
 Ini1:TINIFile;                      // Handle for configuration file
 sList_env_vars: TStringList;        // Raw string list of environment vars
 sList_split: TStringList;           // Temp String list
 i: Integer;                         // Loop counter
 value:String;                       // Variable value

begin
  path := '';                                           // Set initial value
  windows.SetEnvironmentVariable('PATH',PCHAR(path));   // Reset PATH variable

  // Create new paths

  //===Add additional paths set in config file
  If FileExists(USF_US_CONF_INI) Then // If file exists proceed
   begin
    Ini1           := TINIFile.Create(USF_US_CONF_INI); // create ini object
    sList_env_vars := TStringList.Create;               // Create vars object
    sList_split    := TStringList.Create;               // Create split object

    Ini1.ReadSectionRaw('ENV_PATHS'  ,sList_env_vars);  // Read section unchanged

    //Scan Environment Path section
    If Not (sList_env_vars.Count=0) Then                // Check content
      begin
       for i:=0 to sList_env_vars.Count-1 do            // Scan vars line by line
        begin
         //Split name value pair
         sList_split.Clear;                             // Clear list
         sList_split.StrictDelimiter := true;           // Force split only on defined delimiter
         sList_split.Delimiter := '=';                  // Define delimeter
         sList_split.DelimitedText := sList_env_vars[i];// Split name value pair
         value := sList_split[1];                       // Only value used

         //If the value contains a path with %UniConPath% expand this to give full path
         value := StringReplace(value, '%UniConPath%',UniConPath,[rfReplaceAll]); // Expand path
         If DirectoryExists(value) Then path := path + value + ';';               //Add to path
       end;
      end;

     //Clean-up
     Ini1.Free;            // Free method of object
     sList_env_vars.free;  // Remove
     sList_split.free;     // Remove
    end;
  //===END Add additional paths set in config file


  //--If Apache installed add to path --------
  If DirectoryExists(US_APACHE_BIN) Then
    path := path + US_APACHE_BIN + ';';                 // Apache binary folder

  //--If MySQL installed add to path --------
  If DirectoryExists(US_MYSQL_BIN) Then                 // MySQL binary folder
     path := path + US_MYSQL_BIN + ';';                 // MySQL binary

  //--If PHP installed
  If Not (UENV_PHP_SELECT = 'None') then                // PHP Installed
   begin
    If DirectoryExists(US_CORE + '\' +UENV_PHP_SELECT) Then
     begin
       path := path + US_CORE + '\' +UENV_PHP_SELECT + ';'; // PHP
     end;
   end;

  //--If Perl installed add to path --------
  If DirectoryExists(US_PERL) Then
   begin
     path := path + US_PERL + ';';     // Perl
     path := path + US_PERL_BIN + ';'; // Perl binaries
     path := path + US_PERL_LIB + ';'; // Perl library
   end;

  //--Add remaining paths
  If DirectoryExists(US_OPENSSL) Then path := path + US_OPENSSL + ';'; // Open SSL
  If DirectoryExists(US_MSMTP)   Then path := path + US_MSMTP + ';' ;  // msmtp
  If DirectoryExists(US_UTILS)   Then path := path + US_UTILS + ';';   // utils

  //-- Add original path
  path := path + ORIGINAL_ENV_PATH;                              // Add original paths

  windows.SetEnvironmentVariable('PATH',PCHAR(path));            // Set new PATH variable

end;
{--End us_set_environment_path ----------------------------------------------}


{****************************************************************************
 This procedure sets additional environment variables
 these are user definable in file home\us_config\us_config.ini
 under the section named [ENV_VARS]
 Variable format is variable_name=value
============================================================================}
procedure us_set_additional_environment_vars;
var
  Ini1:TINIFile;                      // Handle for configuration file
  sList_env_vars: TStringList;        // Raw string list of environment vars
  sList_split: TStringList;           // Temp String list
  i: Integer;                         // Loop counter
  name: String;                       // Variable name
  value:String;                       // Variable value
begin
  If FileExists(USF_US_CONF_INI) Then // If file exists proceed
   begin
    //Create objects
    Ini1           := TINIFile.Create(USF_US_CONF_INI); // create ini object
    sList_env_vars := TStringList.Create;               // Create vars object
    sList_split    := TStringList.Create;               // Create split object

    //Read raw sections
    Ini1.ReadSectionRaw('ENV_VARS'  ,sList_env_vars);   // Read section unchanged

    //Scan Environment section
    If Not (sList_env_vars.Count=0) Then                  // Check content
      begin
       for i:=0 to sList_env_vars.Count-1 do            // Scan vars line by line
        begin
         //Split name value pair
         sList_split.Clear;                             // Clear list
         sList_split.StrictDelimiter := true;           // Force split only on defined delimiter
         sList_split.Delimiter := '=';                  // Define delimeter
         sList_split.DelimitedText := sList_env_vars[i];// Split name value pair
         name  := sList_split[0];
         value := sList_split[1];

         //If the value contains a path with %UniConPath% expand this to give full path
         value := StringReplace(value, '%UniConPath%',UniConPath,[rfReplaceAll]); // Expand path
         windows.SetEnvironmentVariable(PCHAR(name),PCHAR(value));                // Set new variable
       end;
      end;

     //Clean-up
     Ini1.Free;            // Free method of object
     sList_env_vars.free;  // Remove
     sList_split.free;     // Remove
    end;
end;
{--End us_set_additional_environment_vars ------------------------------------}

 {****************************************************************************
 Set value in ini configuration file
 Note uses INIFiles
 =============================================================================}
 procedure us_ini_set(IniFile:string;section:string;variable:string;value:string);
 Var
 ini:TINIFile;
 begin
  ini := TINIFile.Create(IniFile);          // create object
  ini.WriteString(section,variable,value);  // set value
  ini.Free;                                 // Free method of object
 end;
 {--- End us_ini_set ------------------------------------------------}


{********************************************************************
This procedure:
 Deletes listed files
 Deletes listed folders
 Deletes dolders/files in listed folders

 Lists are defined in configuration file 
 winpacho\home\us_config\us_clean_up.ini

====================================================================}
procedure us_clean_up; 
var
 sList_files          :TStringList; // List of files in section   [FILES]
 sList_folders        :TStringList; // List of folders in section [FOLDERS]
 sList_folder_content :TStringList; // List of folders in section [FOLDERS_CONTENT]
 Ini1           :TINIFile;          // Handle for configuration file
 i              :Integer;           // Loop counter
 path           :String;            // Full path to file or folder
begin

 If FileExists(USF_US_CLEAN_UP_INI) Then // If file exists proceed
  begin
   //Create objects
   Ini1 := TINIFile.Create(USF_US_CLEAN_UP_INI); // create object
   sList_files          := TStringList.Create;   // Create object
   sList_folders        := TStringList.Create;   // Create object
   sList_folder_content := TStringList.Create;   // Create object

   //Read raw sections
   Ini1.ReadSectionRaw('FILES'  ,sList_files);   // Read section unchanged
   Ini1.ReadSectionRaw('FOLDERS',sList_folders); // Read section unchanged
   Ini1.ReadSectionRaw('FOLDERS_CONTENT',sList_folder_content); // Read section unchanged

   //Scan FILE section
   If Not (sList_files.Count=0) Then                // Check content
    begin
       for i:=0 to sList_files.Count-1 do         // Scan file list line by line
        begin
          If Not (Pos(';',sList_files[i]) <> 0) then    // Not a comment 
            begin
              path := UniConPath+'\'+sList_files[i];    // Full path
              If FileExists(path) Then DeleteFile(Pchar(path));
            end;
        end;
    end;
 


   //Scan FOLDERS section
   If Not (sList_folders.Count=0) Then                                 // Check content
    begin
       for i:=0 to sList_folders.Count-1 do                            // Scan folder list line by line
        begin
          If Not (Pos(';',sList_folders[i]) <> 0) then                 // Not a comment
          begin
            path := UniConPath+'\'+sList_folders[i];                   // Full path
            If DirectoryExists(path) Then
              Begin
              if DeleteDirectory(path,True) then RemoveDirUTF8(path);  // Delete content and folder
             end;
          end;
        end;
    end;


   //Scan FOLDERS_CONTENT section
   If Not (sList_folder_content.Count=0) Then                          // Check content
    begin
       for i:=0 to sList_folder_content.Count-1 do                     // Scan folder list line by line
        begin
          If Not (Pos(';',sList_folder_content[i]) <> 0) then          // Not a comment
          begin
            path := UniConPath+'\'+sList_folder_content[i];            // Full path
            If DirectoryExists(path) Then DeleteDirectory(path,true);  // Delete folder content
          end;
        end;
    end;

   //Clean-up
   Ini1.Free;                 // Free method of object
   sList_files.free;          // Remove
   sList_folders.free;        // Remove
   sList_folder_content.free; // Remove
 end;
end;
{--- End procedure us_clean_up --------------------------------------------}


{********************************************************************
Rolling logs for everything Apache's rotatelogs does not cover.
Apache's own logs (and PHP's errors, which reach Apache's error log via
FastCGI) rotate in core\apache2\logs\rotated. Three more logs grow
without limit otherwise:
  core\mysql\data\mysql.err   MySQL/MariaDB error log
  core\msmtp\msmtp.log        mail log of PHP's mail()
  home\us_cron\cron.log       cron log (when cron logging is on)
Once a log passes LOG_ROTATE_MAX_BYTES it becomes <log>.1, the older
parts move up one number and the oldest beyond LOG_ROTATE_OLD_PARTS is
deleted - together with the current file at most 5 x 10 MB per log,
the same as Apache's error logs.
Housekeeping never interrupts the controller: a file that is locked
right now (msmtp writing, the database holding mysql.err) is skipped and
rotated on the next round.
====================================================================}
const
  LOG_ROTATE_MAX_BYTES = 10 * 1024 * 1024; // Rotate a log once it is larger than 10 MB
  LOG_ROTATE_OLD_PARTS = 4;                // Older parts kept: <log>.1 (newest) .. <log>.4 (oldest)

function log_part_name(const log_file:string; part:Integer):string;
begin
  Result := log_file + '.' + IntToStr(part);
end;

function log_file_size(const log_file:string):Int64;
var
  sr: TSearchRec;
begin
  Result := -1;                                  // -1 = no such file
  If FindFirst(log_file, faAnyFile, sr) = 0 Then
    Result := sr.Size;
  SysUtils.FindClose(sr);                        // windows.FindClose takes a handle, not the record
end;

procedure us_rotate_log(const log_file:string);
var
  part:    Integer;
  pending: string;   // the full log, moved aside, waiting to become part 1
begin
  pending := log_file + '.rotating';
  try
    // Move the full log aside first. While a writer holds it open this
    // fails, and the ring must stay untouched - otherwise every failed round
    // would push another old part out. A leftover from an interrupted round
    // is finished instead.
    If not FileExists(pending) Then
     begin
       If log_file_size(log_file) <= LOG_ROTATE_MAX_BYTES Then Exit;   // Missing or small enough
       If not RenameFile(log_file, pending) Then Exit;                  // Busy: next round retries
     end;

    If FileExists(log_part_name(log_file, 1)) Then                      // Make room for the new part 1
     begin
       SysUtils.DeleteFile(log_part_name(log_file, LOG_ROTATE_OLD_PARTS)); // Oldest part leaves the ring
       For part := LOG_ROTATE_OLD_PARTS - 1 downto 1 do                    // .3 -> .4, .2 -> .3, .1 -> .2
         If FileExists(log_part_name(log_file, part)) Then
           RenameFile(log_part_name(log_file, part), log_part_name(log_file, part + 1));
     end;

    RenameFile(pending, log_part_name(log_file, 1)); // The writer starts a fresh log on its next entry
  except
    // Never let housekeeping break the controller - next round retries
  end;
end;

procedure us_delete_log_parts(const log_file:string);
var
  part: Integer;
begin
  For part := 1 to LOG_ROTATE_OLD_PARTS do
    SysUtils.DeleteFile(log_part_name(log_file, part));
  SysUtils.DeleteFile(log_file + '.rotating');   // leftover of an interrupted rotation
end;

procedure us_rotate_app_logs;
begin
  us_rotate_log(USF_MSMTP_LOG);
  us_rotate_log(USF_CRON_LOG);
  // A running database keeps mysql.err open; it is rotated while stopped,
  // at the latest right before the next start (us_start_mysql_program)
  If not MysqlRunning() Then us_rotate_log(USF_MYSQL_ERROR_LOG);
end;
{--- End rolling logs ------------------------------------------------------}



{********************************************************************
This procedure sets icon displayed and hover text based on
ServerType in config file. Valid valus are:

User can run Apache and MySQL as standalone servers the icon is
configurable to distingush between the  servers.

 ServerType - WAMP0 to WAMP3  -DefaultWAMP0 (Apache MySQL PHP)
            - APS0  to APS3   -Apache standalone server
            - MYS0  to  MYS3  -MySQL  standalone server

 TrayIcon hover text:
 ServerTypeText1 - Default: Uniform Server
 ServerTypeText2 - Default: Portable WAMP

 Icons defined in: unicon_images.rc
 120 ICON "unicon_images/main_icon2_a0.ico"
 121 ICON "unicon_images/main_icon2_a1.ico"
 122 ICON "unicon_images/main_icon2_a2.ico"
 123 ICON "unicon_images/main_icon2_a3.ico"

 130 ICON "unicon_images/main_icon2_m0.ico"
 131 ICON "unicon_images/main_icon2_m1.ico"
 132 ICON "unicon_images/main_icon2_m2.ico"
 133 ICON "unicon_images/main_icon2_m3.ico"

 140 ICON "unicon_images/main_icon2_u0.ico"
 141 ICON "unicon_images/main_icon2_u1.ico"
 142 ICON "unicon_images/main_icon2_u2.ico"
 143 ICON "unicon_images/main_icon2_u3.ico"

 Note: Resource is added as follows to main_unit
 Note Replace [] with curly brackes - [] avoids warning Comment level 2

 implementation
 [$R *.lfm]
 [$R manifest.rc]       // Add manifest to raise privileges to admin
 [$R unicon_images.rc]  // Add image resource for tray icon

====================================================================}
procedure us_set_icon_and_hover_text;

begin

 //--Set hover text
 Application.Title:=USC_ServerTypeText1 + #13#10 + USC_ServerTypeText2;

 //--Window/taskbar icon: intentionally NOT touched. The exe's MAINICON
 //(Reload branding) stays; overriding Application.Icon with the state
 //icons 120-143 put the old upstream icon on the taskbar. Server type
 //and state are signalled by the tray icon below and the main window.

 //TrayIcon
 If USC_TrayIconEnabled Then
   begin
    //--Set hover text
    Main.SystrayIcon.Hint:=USC_ServerTypeText1 + #13#10 + USC_ServerTypeText2;

    //-- Must clear Icon first
    Main.SystrayIcon.Icon.Clear; // Must clear Icon first

    If USC_ServerType = 'APS0'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(120));
    If USC_ServerType = 'APS1'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(121));
    If USC_ServerType = 'APS2'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(122));
    If USC_ServerType = 'APS3'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(123));

    If USC_ServerType = 'MYS0'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(130));
    If USC_ServerType = 'MYS1'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(131));
    If USC_ServerType = 'MYS2'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(132));
    If USC_ServerType = 'MYS3'  Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(133));

    If USC_ServerType = 'WAMP0' Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(140));
    If USC_ServerType = 'WAMP1' Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(141));
    If USC_ServerType = 'WAMP2' Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(142));
    If USC_ServerType = 'WAMP3' Then Main.SystrayIcon.Icon.Handle := LoadIcon(hInstance, MAKEINTRESOURCE(143));

   end;


end;
{--- End us_set_icon_and_hover_text --------------------------------}


{===================================================================
 us_vcruntime_dll_version:
 Reads major.minor from the file version of System32\vcruntime140.dll.
 Fallback for systems where the redistributable's registry key is
 absent although the runtime DLLs exist (e.g. the runtime landed on
 the PC without the official installer, or the key was cleaned up).
 Returns false when the DLL is missing or its version is unreadable.
====================================================================}
function us_vcruntime_dll_version(var major:integer; var minor:integer):boolean;
var
  dll      :string;
  ver      :string;   // Full file version e.g. 14.50.35719.0
  info     :TFileVersionInfo;
  dot_pos  :integer;
  major_s  :string;
  minor_s  :string;
begin
 Result := False;
 dll := SysUtils.GetEnvironmentVariable('SystemRoot')+'\System32\vcruntime140.dll';
 If not FileExists(dll) Then Exit;

 ver  := '';
 info := TFileVersionInfo.Create(nil);
 try
   try
     info.FileName := dll;
     info.ReadFileInfo;
     ver := info.VersionStrings.Values['FileVersion'];
   except
     ver := '';                            // Unreadable version resource
   end;
 finally
   info.Free;
 end;
 If ver = '' Then Exit;

 //--First two numeric parts are major.minor
 dot_pos := Pos('.',ver);
 If dot_pos = 0 Then Exit;
 major_s := Copy(ver,1,dot_pos-1);
 minor_s := Copy(ver,dot_pos+1,Length(ver));
 dot_pos := Pos('.',minor_s);
 If dot_pos <> 0 Then minor_s := Copy(minor_s,1,dot_pos-1);

 major := StrToIntDef(Trim(major_s),-1);
 minor := StrToIntDef(Trim(minor_s),-1);
 If (major < 0) or (minor < 0) Then Exit;
 Result := True;
end;
{--- End us_vcruntime_dll_version ----------------------------------}


{********************************************************************
 us_parse_major_minor:
 Splits a "major.minor" version string (e.g. 14.51). Returns false for
 an empty or malformed value so callers can skip that requirement.
********************************************************************}
function us_parse_major_minor(ver:string; var major:integer; var minor:integer):boolean;
var
  dot_pos :integer;
begin
 Result  := False;
 dot_pos := Pos('.',ver);
 If dot_pos = 0 Then Exit;
 major := StrToIntDef(Copy(ver,1,dot_pos-1),-1);
 minor := StrToIntDef(Copy(ver,dot_pos+1,Length(ver)),-1);
 Result := (major >= 0) and (minor >= 0);
end;
{--- End us_parse_major_minor --------------------------------------}


{********************************************************************
 us_warn_if_vcruntime_too_old:
 Apache Lounge and windows.php.net builds require a minimum version of
 the Microsoft Visual C++ runtime. With an older runtime Apache either
 does not start at all or dies loading the PHP module with nothing but
 "Configuration Failed, exiting" in logs\error.log (issue #3).
 This warns the user up front, names the installed and required
 versions and offers to open the redistributable download page.
 The start attempt itself is never blocked (detection could be wrong).

 Minimum versions are read from us_config.ini section [VCRUNTIME]
 (value = major.minor): key "apache" for the bundled Apache build
 (e.g. apache=14.51 for a VS18 build), key = PHP folder name for PHP
 (e.g. php85=14.44), so future builds can raise the bar without a
 code change; php85 has a built-in default of 14.44.

 Installed version is read from the registry (64-bit view):
 HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64
 Despite the "VisualStudio" path the key is written by the standalone
 redistributable installer too - it is Microsoft's documented way to
 detect the installed redist. If the key is absent the file version
 of System32\vcruntime140.dll is used as fallback; only when both
 sources fail is the runtime reported as not installed.
********************************************************************}
procedure us_warn_if_vcruntime_too_old(php_sel:string);
const
  REDIST_URL = 'https://aka.ms/vc14/vc_redist.x64.exe'; // Always the latest 14.x redist
var
  ap_req     :string;    // Required version for Apache e.g. 14.51
  php_req    :string;    // Required version for the selected PHP e.g. 14.44
  ap_major   :integer;   // Requirements split into numbers
  ap_minor   :integer;
  php_major  :integer;
  php_minor  :integer;
  ap_known   :boolean;   // Requirement present and well-formed
  php_known  :boolean;
  ap_short   :boolean;   // Installed runtime older than the requirement
  php_short  :boolean;
  required   :string;    // Highest unmet requirement, for the dialog
  have_major :integer;   // Installed runtime version
  have_minor :integer;
  have_str   :string;    // Installed version as text for the dialog
  ver_txt    :string;    // PHP version for display e.g. 8.5
  who_txt    :string;    // "Apache", "PHP 8.5" or both
  Reg        :TRegistry;
  str        :string;
begin
 //--Minimum runtime for the Apache build (config only)
 ap_req   := us_ini_get(USF_US_CONF_INI,'VCRUNTIME','apache');
 ap_known := us_parse_major_minor(ap_req,ap_major,ap_minor);

 //--Minimum runtime for the selected PHP: config wins, php85 has a default
 php_req := '';
 If (php_sel <> '') and (php_sel <> 'None') Then
  begin
    php_req := us_ini_get(USF_US_CONF_INI,'VCRUNTIME',php_sel);
    If (php_req = '') and (php_sel = 'php85') Then php_req := '14.44';
  end;
 php_known := us_parse_major_minor(php_req,php_major,php_minor);

 If not (ap_known or php_known) Then Exit;            // No requirement known

 //--Installed x64 VC++ runtime from the registry
 have_major := 0;
 have_minor := 0;
 have_str   := 'not installed';
 Reg := TRegistry.Create(KEY_READ);
 try
   Reg.RootKey := HKEY_LOCAL_MACHINE;
   If Reg.OpenKeyReadOnly('SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64') Then
    begin
      try
        have_major := Reg.ReadInteger('Major');
        have_minor := Reg.ReadInteger('Minor');
        have_str   := IntToStr(have_major)+'.'+IntToStr(have_minor);
      except
        //Unreadable values: keep defaults, treated as not installed
      end;
    end;
 finally
   Reg.Free;
 end;

 //--Registry key absent: the runtime may still exist (deployed without the
 //  official installer) - fall back to the DLL file version in System32
 If have_str = 'not installed' Then
  begin
    If us_vcruntime_dll_version(have_major,have_minor) Then
      have_str := IntToStr(have_major)+'.'+IntToStr(have_minor)+' (from vcruntime140.dll)';
  end;

 //--Which requirements does the installed runtime miss?
 ap_short  := ap_known and ((have_major < ap_major) or
              ((have_major = ap_major) and (have_minor < ap_minor)));
 php_short := php_known and ((have_major < php_major) or
              ((have_major = php_major) and (have_minor < php_minor)));
 If not (ap_short or php_short) Then Exit;            // New enough: nothing to do

 //--Runtime too old: name cause and fix, offer the download page
 ver_txt := php_sel;                                  // Fallback: raw folder name
 If (Length(php_sel) >= 5) and (Copy(php_sel,1,3) = 'php') Then
   ver_txt := Copy(php_sel,4,1)+'.'+Copy(php_sel,5,Length(php_sel));

 If ap_short and php_short Then
  begin
    who_txt := 'Apache and PHP '+ver_txt;
    //The higher requirement is the one the user must reach
    If (ap_major > php_major) or ((ap_major = php_major) and (ap_minor >= php_minor)) Then
      required := ap_req
    Else
      required := php_req;
  end
 Else If ap_short Then
  begin
    who_txt  := 'Apache';
    required := ap_req;
  end
 Else
  begin
    who_txt  := 'PHP '+ver_txt;
    required := php_req;
  end;

 str :=       who_txt+' requires the Microsoft Visual C++ runtime '+required+' or newer.'+ sLineBreak;
 str := str + 'Installed on this PC: '+have_str+'.'+ sLineBreak + sLineBreak;
 str := str + 'With the old runtime Apache does not start or stops with'+ sLineBreak;
 str := str + '"Configuration Failed" (details in logs\error.log).'+ sLineBreak + sLineBreak;
 str := str + 'Fix: install the latest "Visual C++ Redistributable (x64)" from'+ sLineBreak;
 str := str + REDIST_URL + sLineBreak;
 str := str + 'It updates in place - nothing needs to be uninstalled.'+ sLineBreak;
 str := str + 'Afterwards start Apache again.'+ sLineBreak + sLineBreak;
 str := str + 'Open the download in your browser now?';

 If us_MessageDlg('Visual C++ runtime too old for '+who_txt, str, mtWarning,[mbYes,mbNo],0) = mrYes Then
   browser_display_url(REDIST_URL);   // Download starts in the default browser
end;
{--- End us_warn_if_vcruntime_too_old ------------------------------}

 {********************************************************************
 Kill named process.
 Uses JwaTlHelp32, windows
 ====================================================================}
  procedure KillRunningProcess(ProcessName: string);
  var
   pa: TProcessEntry32;
   RetVal: THandle;
   AHandle: THandle;
    begin

   RetVal := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
   pa.dwSize := sizeof(pa);

   //Get first process
   if Process32First(RetVal, pa) then
   begin
     //While we have process handle
     while Process32Next(RetVal, pa) do
     begin
       if pa.szExeFile = ProcessName then
         begin
           AHandle := OpenProcess(PROCESS_ALL_ACCESS,False,pa.th32ProcessID); //uses windows
           TerminateProcess(AHandle,255);
           CloseHandle(AHandle);
         end;
       end;
   end;
   CloseHandle(RetVal);
 end;
 {----------------------------------------------------------------------------}

 {****************************************************************************
 This procedure displays a file in an external text editor. This editor is
 user definable inthe user.ini file. Note: - default is notepad.exe
 If editor already on windows path use its name, otherwise use full path.
 Input Full path of file to display
 =============================================================================}
 procedure us_display_in_editor(FileToDisplay: string);
 var
  AProcess: TProcess;
  str:String;
 begin
     AProcess := TProcess.Create(nil);                     // Create process
     try
       Try
          AProcess.Executable := USUC_USER_EDITOR;              // Executable to run
          AProcess.Parameters.Add(FileToDisplay);               // Parmeters passed to exe

          AProcess.Options := AProcess.Options + [poNoConsole]; // Set options hide console
          AProcess.Execute;                                     // execute detatched process
       except
         str := 'Editor specified in us_user.ini cannot be found.';
         us_MessageDlg('Error', str, mtWarning,[mbOk],0) ; //Display message
       end;
     finally
       AProcess.Free;                                        // free memory ;
     end;
 end;
 {----------------------------------------------------------------------------}

//=== Apache ===

{****************************************************************************
Start Apache as a program
 Skip if already running.

  usapache :=  ExtractFilePath(Application.ExeName) + 'core\apache2';
  strCmd := usapache + '\bin\httpd.exe' + ' -f ' + usapache + '\conf\httpd.conf -d ' + usapache;
Note: Uses Process
=============================================================================}
{*****************************************************************************
Windowless rotatelogs: core\apache2\bin\rotatelogs_z.exe

The Apache logs rotate through piped rotatelogs processes. Apache spawns its
piped log programs without any console flag; when Apache itself runs without
a console (as this controller starts it), every console rotatelogs.exe gets
a console window of its own - on Windows 11 a Windows Terminal window per
log, respawned by Apache whenever one is closed (that was 1.3.3). A copy of
rotatelogs.exe with the PE subsystem set to GUI never gets a console and
still reads the log pipe.

Creates that copy when it is missing (bundles get it from
scripts/tune-server-config.ps1, controller-only upgrades from here) and moves
1.3.3 configuration lines, user vhosts included, to it. Runs before every
Apache start; does nothing when everything is in place.
=============================================================================}
procedure us_prepare_rotatelogs;
const
  IMAGE_SUBSYSTEM_WINDOWS_GUI = 2;
  IMAGE_SUBSYSTEM_WINDOWS_CUI = 3;
  CONSOLE_PIPE    = '|bin/rotatelogs.exe ';
  WINDOWLESS_PIPE = '|bin/rotatelogs_z.exe ';

  procedure move_pipes(const conf: String);
  var
    sList   : TStringList;
    i       : Integer;
    changed : Boolean;
  begin
    If Not FileExists(conf) Then Exit;
    sList := TStringList.Create;
    try
      sList.LoadFromFile(conf);
      changed := False;
      for i := 0 to sList.Count-1 do
        If Pos(CONSOLE_PIPE, sList[i]) > 0 Then
          begin
            sList[i] := StringReplace(sList[i], CONSOLE_PIPE, WINDOWLESS_PIPE, [rfReplaceAll]);
            changed  := True;
          end;
      If changed And FileIsWritable(conf) Then sList.SaveToFile(conf);
    finally
      sList.Free;
    end;
  end;

var
  src, dst     : String;
  fs           : TFileStream;
  data         : array of Byte;
  peOffset     : LongInt;
  subsysOffset : LongInt;
begin
  src := US_APACHE_BIN + '\rotatelogs.exe';
  dst := US_APACHE_BIN + '\rotatelogs_z.exe';
  If FileExists(src) And Not FileExists(dst) Then
    begin
      fs := TFileStream.Create(src, fmOpenRead or fmShareDenyNone);
      try
        SetLength(data, fs.Size);
        If Length(data) > 0 Then fs.ReadBuffer(data[0], Length(data));
      finally
        fs.Free;
      end;
      // 'MZ' header; e_lfanew at 0x3C points to 'PE\0\0'; the optional
      // header follows the 20-byte COFF header and Subsystem is the WORD at
      // optional header + 68
      If (Length(data) > $40) And (data[0] = Ord('M')) And (data[1] = Ord('Z')) Then
        begin
          peOffset     := PLongInt(@data[$3C])^;
          subsysOffset := peOffset + 4 + 20 + 68;
          If (peOffset > 0) And (subsysOffset + 2 <= Length(data))
             And (data[peOffset] = Ord('P')) And (data[peOffset+1] = Ord('E'))
             And (PWord(@data[subsysOffset])^ = IMAGE_SUBSYSTEM_WINDOWS_CUI) Then
            begin
              PWord(@data[subsysOffset])^ := IMAGE_SUBSYSTEM_WINDOWS_GUI;
              fs := TFileStream.Create(dst, fmCreate);
              try
                fs.WriteBuffer(data[0], Length(data));
              finally
                fs.Free;
              end;
            end;
        end;
    end;
  // Only once the copy exists may the pipes point at it
  If FileExists(dst) Then
    begin
      move_pipes(USF_APACHE_CNF);
      move_pipes(USF_APACHE_SSL_CNF);
      move_pipes(USF_APACHE_VHOST_CNF);
    end;
end;

procedure us_start_apache_program;
Var
 AProcess: TProcess;
 saftey_loop: Integer;
 config_error: string;

begin
 if not ApacheRunning() then
  begin
   saftey_loop :=0;
   us_prepare_rotatelogs;   // windowless log writer, 1.3.3 config migration

   //--A broken configuration makes httpd exit at once; the wait loops below
   //  would then block the window for a minute and end in a vague warning.
   //  Check first and name file, line and reason (rule: cause + next step).
   config_error := us_apache_config_error();
   If config_error <> '' Then
    begin
      us_MessageDlg('Apache not started - configuration error',
        'Apache was not started because its configuration does not parse:' + sLineBreak + sLineBreak +
        config_error + sLineBreak + sLineBreak +
        'Next step: open the file named above, fix that line and start' + sLineBreak +
        'Apache again. Blocks created by "Create Apache Vhost" live in'          + sLineBreak +
        USF_APACHE_VHOST_CNF + sLineBreak +
        '(a Vhost can also be removed with Apache Vhosts > Delete Apache Vhost).',
        mtError,[mbOk],0);
      Exit;
    end;

   //--Run command string.
  AProcess := TProcess.Create(nil);                         // Create new process

  AProcess.Executable := US_APACHE_BIN + '\' + AP_EXE_NAME; // Executable to run
  AProcess.Parameters.Add('-f');
  AProcess.Parameters.Add(USF_APACHE_CNF);                  // Apache configuration file
  AProcess.Parameters.Add('-d');
  AProcess.Parameters.Add(US_APACHE );                      // Apache folder
  AProcess.Options  := AProcess.Options + [poNoConsole];    // Set option no console
  //AProcess.Priority := ppHigh;                            // The process runs at higher than normal priority.
  AProcess.Execute;                                         // Run command
  AProcess.Free;                                            // Release process


  Repeat   // Wait for Apache to start
    begin
      Application.ProcessMessages; //allow message processing
      sleep(100);
      saftey_loop := saftey_loop +1;             // Increment counter
      if saftey_loop > (USC_AP_StartSafetyTime*10) then
       begin
         us_MessageDlg('Warning','Failed to start Apache', mtWarning,[mbOk],0) ; //Display warning message
         Break;
       end;
    end;
  Until ApacheRunning();

  // Wait for Apache to serve pages
  saftey_loop := 0;
  Repeat
    begin
      Application.ProcessMessages; //allow message processing
      sleep(1000);
      saftey_loop := saftey_loop +1;             // Increment counter
      if saftey_loop > (USC_AP_StartSafetyTime) then
       begin
         us_MessageDlg('Warning','Apache failed to start', mtWarning,[mbOk],0) ; //Display warning message
         Break;
       end;
    end;
  Until Not ApachePortFree; // Until Apache is listening on 127.0.0.1','80'

  end;
 end;
{----------------------------------------------------------------------------}

{****************************************************************************
Kills Apache running as a standard program
Global variables used:
  AP_EXE_NAME
=============================================================================}
procedure us_kill_apache_program;
Var
 saftey_loop: Integer;

begin
 saftey_loop:=0;   // Initialize unconditionally: previously only this line was
                   // guarded by the If, leaving the counter uninitialized when
                   // Apache was not running - a garbage value triggered a
                   // spurious "Failed to stop Apache" warning
 if ApacheRunning() then
  begin
      KillRunningProcess(AP_EXE_NAME);           //Kill Apache program
  end;

  Repeat                                         // Wait for Apache to stop
    begin
      Application.ProcessMessages; //allow message processing
      sleep(100);
      saftey_loop := saftey_loop +1;             // Increment counter
      if saftey_loop > (USC_AP_StopSafetyTime*10) then
       begin
         us_MessageDlg('Warning','Failed to stop Apache', mtWarning,[mbOk],0) ; //Display warning message
         Break;
       end;
    end;
   Until not ApacheRunning();
 end;
{----------------------------------------------------------------------------}

{*****************************************************************************
Apache Syntax Check
Opens a dos window and displays syntax check result
=============================================================================}
procedure us_apache_syntax_check;
Var
 AProcess: TProcess;
begin

 AProcess := TProcess.Create(nil); // Create process

 AProcess.Executable := 'cmd';                                // Executable to run
 AProcess.Parameters.Add('/T:0F');                            // Set background colour
 AProcess.Parameters.Add('/K');                               // Keep open
 AProcess.Parameters.Add('title');                            // A title is required
 AProcess.Parameters.Add('Apache Syntax check');              // Title
 AProcess.Parameters.Add('&&');                               // Start a new command line
 AProcess.Parameters.Add(US_APACHE_BIN + '\' + AP_EXE_NAME);  // Apache exe
 AProcess.Parameters.Add('-t');                               // Syntax check

 AProcess.Execute; // execute detatched process command window remains visible
 AProcess.Free;    // free memory

end;
{----------------------------------------------------------------------------}


{*****************************************************************************
Apache Server status indicator

A bi-state indicator showing current server status.
 Red   � Server not running
 Green � Server is running
This indicator specifically targets Apache.

Inputs:
 state - Red
       - Green

Draws a round LED sized to the target TImage (apache_img on the main form).
=============================================================================}

{Shared LED painter: green circle = running, red circle = stopped.
 Sizes itself to the TImage so DPI scaling keeps the circle round.}
procedure us_draw_state_led(AImg: TImage; ARunning: Boolean);
Var
  Bmp: TBitmap;
  W, H: Integer;
  clFill, clEdge: TColor;
begin
  W := AImg.Width;
  H := AImg.Height;
  If (W < 2) or (H < 2) Then Exit;

  If ARunning Then
    begin
      clFill := TColor($48A124); // #24A148 green - running
      clEdge := TColor($2E6B16); // darker green rim
    end
  Else
    begin
      clFill := TColor($2929D6); // #D62929 red - stopped
      clEdge := TColor($1C1C96); // darker red rim
    end;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(W, H);
    Bmp.Canvas.Brush.Color := Main.Color;  // blend with form background
    Bmp.Canvas.FillRect(0, 0, W, H);
    Bmp.Canvas.Brush.Color := clFill;
    Bmp.Canvas.Pen.Color   := clEdge;
    Bmp.Canvas.Ellipse(0, 0, W, H);
    // Assign, not Canvas.Draw: the picture takes the LED's size. A picture
    // created earlier at a smaller size (before DPI scaling) clipped the circle.
    AImg.Picture.Bitmap.Assign(Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure apache_indicator(state:String);
begin
  us_draw_state_led(Main.apache_img, state = 'green');
end;
{----------------------------------------------------------------------------}

{*****************************************************************************
Enable Apache ssl in configuration file httpd.conf
=============================================================================}
procedure us_enable_apache_ssl;
var
  sList: TStringList;                // String list
  i: Integer;                        // Loop counter

begin

 //-- Get current configuration line from core\apache2\conf\httpd.conf and update
If FileExists(USF_APACHE_CNF) Then
 begin
   sList := TStringList.Create;           // Create object
   sList.LoadFromFile(USF_APACHE_CNF);    // Load file
   for i:=0 to sList.Count-1 do          // Scan file line by line
     begin
      if (sList[i]<>'') and ExecRegExpr('^#LoadModule ssl_module modules/mod_ssl.so', sList[i]) then      // Match found
        begin
         sList[i] := 'LoadModule ssl_module modules/mod_ssl.so'; // Update with new string
         Break;                                                  // Nothing else to do
        end;
     end;

   If FileIsWritable(USF_APACHE_CNF) Then
    begin
      sList.SaveToFile(USF_APACHE_CNF);   // Save changes back to file
      AP_SSL_ENABLED := True;             // SSL Enabled in config
    end;

  sleep(100);
  sList.Free;     // remove from memory
 end;
end;
{----------------------------------------------------------------------------}

{*****************************************************************************
Disable Apache ssl in configuration file httpd.conf
=============================================================================}
procedure  us_disable_apache_ssl;
var
  sList: TStringList;                // String list
  i: Integer;                        // Loop counter

begin
//-- Get current configuration line from core\apache2\conf\httpd.conf and update
If FileExists(USF_APACHE_CNF) Then
  begin
    sList := TStringList.Create;           // Create object
    sList.LoadFromFile(USF_APACHE_CNF);         // Load file
  for i:=0 to sList.Count-1 do          // Scan file line by line
    begin
     if (sList[i]<>'') and ExecRegExpr('^LoadModule ssl_module modules/mod_ssl.so', sList[i]) then      // Match found
       begin
        sList[i] := '#LoadModule ssl_module modules/mod_ssl.so'; // Update with new string
        Break;                                                   // Nothing else to do
       end;
    end;

    If FileIsWritable(USF_APACHE_CNF) Then
     begin
       sList.SaveToFile(USF_APACHE_CNF);   // Save changes back to file
       AP_SSL_ENABLED := False;            // SSL Disabled in config
     end;

   sleep(100);
   sList.Free;     // remove from memory
 end;

end;
{----------------------------------------------------------------------------}


//=== MySQL ===

{****************************************************************************
us_start_mysql_program: 
 Start MySQL server as a program
  Skip if already running.

 Note: Uses Process

  set my=!CD!\core\mysql\bin\mysqld.exe
  set my=!my! --defaults-file=!MYSQL_HOME!\my.ini
  set my=!my! --tmpdir=!CD!\tmp
  set my=!my! --datadir=!MYSQL_HOME!\data
  set my=!my! --innodb_data_home_dir=!MYSQL_HOME!\data
  set my=!my! --innodb_log_group_home_dir=!MYSQL_HOME!\data
=============================================================================}
procedure us_start_mysql_program;
Var
 AProcess: TProcess;
 saftey_loop: Integer;
begin
 if not MysqlRunning() then
  begin
    us_rotate_log(USF_MYSQL_ERROR_LOG);  // Only chance while the database is down - it holds the file once running
    saftey_loop:=0;
     //--Run command string.
    AProcess := TProcess.Create(nil);                                              // Create new process

    AProcess.Executable := US_MYSQL_BIN + '\' + MY_EXE_NAME;                       // Executable to run

    //MYSQL command line parameters:
    //Parameters optionally set in configuration file us_config.ini [MYSQL] e.g
    //1) defaults-file=          No value remove parameter from command line
    //2) defaults-file=C:\fred   Use absolute path to folder fred
    //3) No parameter in us_config.ini use default path set in default_config_vars file

    IF USF_MYSQL_INI <>'' Then //If parameter with no value skip this section
     begin
      AProcess.Parameters.Add('--defaults-file="' + USF_MYSQL_INI  + '"');                  // Force use of a default file
     end;
    IF USP_TMPDIR <>'' Then //If parameter with no value skip this section
     begin
      AProcess.Parameters.Add('--tmpdir="' + USP_TMPDIR + '"');                             // Temp folder
     end;
    IF USP_DATADIR <>'' Then //If parameter with no value skip this section
     begin
      AProcess.Parameters.Add('--datadir="' + USP_DATADIR  + '"');                          // MySQL data folder
     end;
    IF USP_INNODB_DATA_HOME_DIR <>'' Then //If parameter with no value skip this section
     begin
     AProcess.Parameters.Add('--innodb_data_home_dir="' + USP_INNODB_DATA_HOME_DIR + '"');  // MySQL innodb data folder
     end;
    IF USP_INNODB_LOG_GROUP_HOME_DIR <>'' Then //If parameter with no value skip this section
     begin
      AProcess.Parameters.Add('--innodb_log_group_home_dir="' + USP_INNODB_LOG_GROUP_HOME_DIR + '"'); // MySQL innodb log folder
     end;

    AProcess.Options  := AProcess.Options + [poNoConsole];                         // Set option no console
    //AProcess.Priority := ppHigh;                                                 // The process runs at higher than normal priority.
    AProcess.Execute;                                                              // Run command
    AProcess.Free;

    Repeat                                         // Wait for MySQL server to start
     begin
       Application.ProcessMessages; //allow message processing
       sleep(100);
       saftey_loop := saftey_loop +1;              // Increment counter
       if saftey_loop > (USC_MY_StartSafetyTime*10) then
        begin
          us_MessageDlg('Warning','Failed to start '+US_MYMAR_TXT, mtWarning,[mbOk],0) ; //Display warning message
          Break;
        end;
     end;
    Until MysqlRunning();
  end;
end;
{--- End us_start_mysql_program --------------------------------------------}



{****************************************************************************
Kill MySQL running as a program
Global variables used:
  MY_EXE_NAME   - Exe name
=============================================================================}
procedure us_kill_mysql_program;
Var
 saftey_loop: Integer;

begin
 saftey_loop:=0;
 if MysqlRunning() then
  begin
    KillRunningProcess(MY_EXE_NAME);           // Kill MySQL server
  end;

  Repeat                                       // Wait for MySQL server to stop
    begin
      Application.ProcessMessages; //allow message processing
      sleep(100);
      saftey_loop := saftey_loop +1;           // Increment counter
      if saftey_loop > (USC_MY_StopSafetyTime*10) then
       begin
         us_MessageDlg('Warning','Failed to Kill '+US_MYMAR_TXT, mtWarning,[mbOk],0) ; //Display warning message
         Break;
       end;
    end;
   Until not MysqlRunning();
end;
{--- End us_kill_mysql_program ---------------------------------------------}


{****************************************************************************
Clean stop MySQL server - Stops MySQL program using a name and password
If this fails a user is offered the choice to Kill MySQL server (unclean).
Global variables used:
  MY_EXE_NAME   - Exe name
  USF_MYSQL_PWD      - Password file
=============================================================================}
procedure us_clean_stop_mysql_program;
Var
 AProcess: TProcess;
 saftey_loop: Integer;
 Reply, BoxStyle: Integer;

 mysql_port: String;         //MySQL port
 pwdFile : TextFile;         // File containing mysql file
 mysql_pwd:  String;         //MySQL password

begin
  if MysqlRunning() then
   begin
    mysql_port  := UENV_MYSQL_TCP_PORT; //Get port configured
    saftey_loop :=0;

    //Get PWD from file
    AssignFile(pwdFile, USF_MYSQL_PWD);  // Text file handle
    Reset(pwdFile);                      // Open file for reading
    ReadLn(pwdFile, mysql_pwd);          // Read first line - get pid
    CloseFile(pwdFile);                  // Close file

   //--Run command string.
  AProcess := TProcess.Create(nil);                          // Create new process

  AProcess.Executable := US_MYSQL_BIN + '\mysqladmin.exe';   // Executable to run
  AProcess.Parameters.Add('--port=' + mysql_port);           // Parameter mysql server port
  AProcess.Parameters.Add('--user=root');                    // Parameter root user
  AProcess.Parameters.Add('--password=' + mysql_pwd);        // Parameter root user password
  AProcess.Parameters.Add('shutdown');                       // Parameter shutdown

  AProcess.Options     := AProcess.Options + [poNoConsole];   // Set option no console
  AProcess.Execute;                                           // Run command
  AProcess.Free;                                              // Release process

  Repeat                                          // Wait for MySQL server to stop
    begin
      Application.ProcessMessages; //allow message processing
      sleep(100);
      saftey_loop := saftey_loop +1;              // Increment counter
      if saftey_loop > (USC_MY_StopSafetyTime*10) then
       begin
        If USC_CLI_MODE Then
         begin
          //Command line mode: no dialogs - force kill so scripts never block
          cli_write_line('Unable to perform clean shut-down of '+US_MYMAR_TXT+': killing process');
          us_kill_mysql_program;
         end
        Else
         begin
          //Clean shutdown failed ask user if they want to use MySQL kill?
          BoxStyle := MB_ICONQUESTION + MB_YESNO;
          //Reply := Application.MessageBox(Pchar('Unable to perform clean shut-down. Kill process ), 'Kill MySQL', BoxStyle);
          Reply := Application.MessageBox(Pchar('Unable to perform clean shut-down. Kill process' ),Pchar('Kill '+US_MYMAR_TXT), BoxStyle);
          if Reply = IDYES then
             us_kill_mysql_program;
         end;
        Break;
       end;
     end;
   Until not MysqlRunning();
   end;
end;
{--- End us_clean_stop_mysql_program ----------------------------------------}

{*****************************************************************************
MySQL Server status indicator

A bi-state indicator showing current server status.
 Red   � Server not running
 Green � Server is running
This indicator specifically targets MySQL.

Inputs:
 state - Red
       - Green

Draws a round LED sized to the target TImage (mysql_img on the main form).
=============================================================================}
procedure mysql_indicator(state:String);
begin
  us_draw_state_led(Main.mysql_img, state = 'green');
end;
{--- ENd mysql_indicator ----------------------------------------------------}

{*****************************************************************************
Display MySQL Command Prompt
Opens a console in the MySQL bin folder and starts the mysql client
(Reload look, see us_open_console). Runs:
  mysql.exe --host=127.0.0.1 --port=3306 --user=root --password=root
=============================================================================}
procedure us_display_mysql_prompt;
begin
 us_open_console('SERVER MySQL Command Console', US_MYSQL_BIN,
   ['SET', 'MYSQL_HOME=' + US_MYSQL,                        // Path to MySQL my.ini folder
    '&&',
    'mysql.exe',
    '--host=' + US_DB_HOST,                                 // Server
    '--port=' + UENV_MYSQL_TCP_PORT,                        // MySQL server port
    '--user=root',
    '--password=' + MY_PWD]);                               // root user password
end;
{--- End us_display_mysql_prompt -----------------------------------}

{====================================================================
 Save MySQL password to file.
====================================================================}
procedure us_save_mysql_password(my_pwd_in:string);
 var
  myFile : TextFile;

 begin
   AssignFile(myFile, USF_MYSQL_PWD); // Assign file handle
   ReWrite(myFile);                   // Open the file for write

   Write(myFile, my_pwd_in);          // Write password to file
   CloseFile(myFile);                 // Close the file
 end;
{--- End us_get_mysql_password() -----------------------------------}


{*****************************************************************************
us_create_mysql_database:
 Runs mysqladmin directely.
 Parameters to access MySQL server and create database are passed to mysqladmin
 Assumes the database does not exist and name is valid.
 Assumes server is running

 Note: Using mysqladmin avoids a user having to install a driver.
 Uses: Process
=============================================================================}
procedure us_create_mysql_database(database_name:string); 
Var
  AProcess: TProcess;   // Process handle
begin
  //--Run command string.
  AProcess := TProcess.Create(nil);                          // Create new process

  AProcess.Executable := US_MYSQL_BIN + '\mysqladmin.exe';   // Path to MySQL admin exe
  AProcess.Parameters.Add('--host=' + US_DB_HOST);           // Parameter server
  AProcess.Parameters.Add('--port=' + UENV_MYSQL_TCP_PORT);  // Parameter mysql server port
  AProcess.Parameters.Add('--user=root');                    // Parameter root user
  AProcess.Parameters.Add('--password=' + MY_PWD);           // Parameter root user password
  AProcess.Parameters.Add('create');                         // Parameter command to run
  AProcess.Parameters.Add(database_name);                    // Parmeter database name to delete

  AProcess.Options     := AProcess.Options + [poWaitOnExit];  // Set option wait to complete
  AProcess.ShowWindow  := swoHIDE;                            // Hide command window
  AProcess.Execute;                                           // Run command
  AProcess.Free;                                              // Release process
end;
{--- End us_create_mysql_database -------------------------------------------}

{*****************************************************************************
us_drop_mysql_database:
 Delete(Drop) MySQL Database
 Runs mysqladmin directely.
 Parameters to access MySQL server and drop database are passed to mysqladmin
 Assumes the database exists and server is running.

 Note: Using mysqladmin avoids a user having to install a driver.
 Uses: Process
=============================================================================}
procedure us_drop_mysql_database(database_name:string);
Var
  AProcess: TProcess;   // Process handle
begin
 //--Run command string.
 AProcess := TProcess.Create(nil);                          // Create new process

 AProcess.Executable := US_MYSQL_BIN + '\mysqladmin.exe';   // Executable to run
 AProcess.Parameters.Add('--host=' + US_DB_HOST);           // Parameter server
 AProcess.Parameters.Add('--port=' + UENV_MYSQL_TCP_PORT);  // Parameter mysql server port
 AProcess.Parameters.Add('--user=root');                    // Parameter root user
 AProcess.Parameters.Add('--password=' + MY_PWD);           // Parameter root user password
 AProcess.Parameters.Add('--force');                        // Parameter command to delete database
 AProcess.Parameters.Add('drop');                           // drop deletes db
 AProcess.Parameters.Add(database_name);                    // Parmeter database name to delete

 AProcess.Options     := AProcess.Options + [poWaitOnExit];  // Set option wait to complete
 AProcess.ShowWindow  := swoHIDE;                            // Hide command window
 AProcess.Execute;                                           // Run command
 AProcess.Free;                                              // Release process
end;
{--- End us_drop_mysql_database ---------------------------------------------}


//=== MySQL Change root password ===

{=============================================================================
MySQL Change root password:
 1) A new mysql-init.txt file is used for updating the old MySQL root password.
    The file is run during MSQL server start-up and contains the following
    sql instructions:

    FLUSH PRIVILEGES;
    ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpass';
    FLUSH PRIVILEGES;

 2) Start MySQL server

    Command line format:
    C:\winpacho\core\mysql\bin\mysqld_z.exe --defaults-file=C:\winpacho\core\mysql\my.ini

 3) Run mySQL with the user and the password providing the input file to change the password
    Command Line Format:
    mysql.exe --user=root --password=root --execute="SOURCE mysql-init.txt"

 4) Passwords changed kill the MySQL server.

  Changes:
  --------
  2019-09-07 : SudeepJD: Added in the MySQL8 support as it needs to be handled differntly
  2021-04-06 : SudeepJD: MySQL5.7+ and MySQL8 are now handled the same way using ALTER instead of UPDATE
               Updated the method of changing the password since we know the old password
  2.2.0      : MariaDB only, root only - the phpMyAdmin control user 'pma' is gone
               with phpMyAdmin. The password is escaped for the SQL string: the
               password dialog allows ' and \, which broke the statement before.
               The temp file holding the new password is deleted again.
=============================================================================}
procedure mysql_change_root_password(new_password:string);
var
  FileVar1      : TextFile;    // Text File handle
  AProcess      : TProcess;    // Process handle
  saftey_loop   : Integer;     // Loop counter
  failed        : Boolean;     // Failed to set password
  root_password : String;      //The existing password
  sql_password  : String;      // new_password as SQL string content
begin
  failed := False;                          // Assume not failed

  root_password := us_get_mysql_password();
  sql_password  := StringReplace(StringReplace(new_password, '\', '\\', [rfReplaceAll]), '''', '\''', [rfReplaceAll]);

  //1==Create new mysql-init.txt
  Assign(FileVar1,USF_MYSQL_TEMP_SQL);      // Assign file
  ReWrite(FileVar1);                        // Create file for writing

  Writeln(FileVar1, 'FLUSH PRIVILEGES;');
  Writeln(FileVar1, 'ALTER USER ''root''@''localhost'' IDENTIFIED BY '''+sql_password+''';');
  Writeln(FileVar1, 'FLUSH PRIVILEGES;');

  CloseFile(FileVar1);                     // Close file
  sleep(100);                              // Wait for file to be created

  //2==Start MySQL server
  //   File is run during start-up and passwords changed.
  AProcess := TProcess.Create(nil);                                              // Create new process

  AProcess.Executable := US_MYSQL_BIN + '\' + MY_EXE_NAME;                       // Executable to run
  AProcess.Parameters.Add('--defaults-file="' + USF_MYSQL_INI+ '"');             // Force use of default file
  //AProcess.Parameters.Add('--init-file="' + USF_MYSQL_TEMP_SQL+ '"');            // Parameter mysql mysql-init.txt file

  AProcess.Options  := AProcess.Options + [poNoConsole];                         // Set option no console
  //AProcess.Priority := ppHigh;                                                 // The process runs at higher than normal priority.
  AProcess.Execute;                                                              // Run command
  AProcess.Free;

  saftey_loop:=0;
  Repeat                                         // Wait for MySQL server to start
   begin
    Application.ProcessMessages;                 // allow message processing
    sleep(100);
     saftey_loop := saftey_loop +1;              // Increment counter
     if saftey_loop > (USC_MY_StartSafetyTime*10) then
      begin
        us_MessageDlg('Warning','Failed to start '+US_MYMAR_TXT, mtWarning,[mbOk],0) ; //Display warning message
        Failed := True;
        Break;
      end;
   end;
  Until MysqlRunning();

  //Check MySQL server is ready
  If not Failed then
   begin
     saftey_loop:=0;
     Repeat                                         // Wait for MySQL server to be ready
      begin
       Application.ProcessMessages;                 // allow message processing
       sleep(100);
        saftey_loop := saftey_loop +1;              // Increment counter
        if saftey_loop > (USC_MY_StartSafetyTime*10) then
         begin
           us_MessageDlg('Warning',US_MYMAR_TXT+' server failed to become ready', mtWarning,[mbOk],0) ; //Display warning message
           Failed := True;
           Break;
         end;
      end;
     Until MysqlServerReady(root_password);
   end;

  //3)==Run the sql file and execute the Init file
  If not Failed then
   Begin
     AProcess := TProcess.Create(nil);   // Create new process

      AProcess.Executable := US_MYSQL_BIN + '\mysql.exe';                   // Executable to run
      AProcess.Parameters.Add('--user=root');                               // User root
      AProcess.Parameters.Add('--password=' + root_password);       // User password
      AProcess.Parameters.Add('--execute="SOURCE '+USF_MYSQL_TEMP_SQL+'"'); // mysql-init.txt

      // Wait for the client: only a statement that ran without error may
      // change passwd.txt, which Adminer's automatic login reads as well
      AProcess.Options  := AProcess.Options + [poNoConsole, poWaitOnExit];
      AProcess.Execute;                                                     // Run command
      If AProcess.ExitStatus <> 0 Then Failed := True;                      // ALTER USER refused
      AProcess.Free;
   End;

  //3)==MySQL running kill the MySQL server.
  Sleep(4000);
  us_kill_mysql_program;                  // Kills MySQL server

  //4)==Delete temp file mysql-init.txt - it holds the new password in plain text
  If FileExists(USF_MYSQL_TEMP_SQL) and not DeleteFile(Pchar(USF_MYSQL_TEMP_SQL)) Then
    us_MessageDlg('Warning', 'Could not delete ' + USF_MYSQL_TEMP_SQL + sLineBreak +
                  'It contains the new root password in plain text - please delete it by hand.',
                  mtWarning, [mbOk], 0);

  //5)==Update parameters
  If Failed then //Failed to change root password
   begin
     us_MessageDlg(US_MYMAR_TXT+' Info','Failed to change root password. No action taken', mtcustom,[mbOk],0) ; //Display information message
   end
  Else           //Root password changed
   begin
    us_save_mysql_password(new_password);   // Save new password to password file
    MY_PWD := new_password;                 // Updated password global variable
    us_MessageDlg(US_MYMAR_TXT+' Info',US_MYMAR_TXT+' root password changed', mtcustom,[mbOk],0) ; //Display information message
   End;
end;
{--- End mysql_change_root_password -----------------------------------------}

//=== MySQL restore root password ===

{=============================================================================
mysql_restore_root_password:
 A user may forget the root password or delete the root user or change
 root user privileges. This procedure restores password to root and
 either creates or updates privileges.

 A list of privileges is obtained by running the following using mysql.exe
 SELECT * FROM mysql.user WHERE User = 'root'\G;
 results from the above are used to create a restore file mysql-init.txt.

 To restore password and privileges MySQL server is started with no-privileges using:
 mysqld_z.exe --defaults-file="C:\winpacho\core\mysql\my.ini" --skip-grant-tables

 With server running the following line is executed which runs the restore file.
 mysql.exe --user=root --execute="SOURCE C:\winpacho\core\mysql\bin\mysql-init.txt"

 Following steps restores the password and privileges
 
 1) Kill server if running

 2) A new mysql-init.txt file is created this is used for restoring the MySQL root user.

 3) Start MySQL server with skip grant tables
    mysqld_z.exe --defaults-file="C:\winpacho\core\mysql\my.ini" --skip-grant-tables

 4) Insert root if it was deleted, set password 'root' and all privileges

 5) Kill the server

 6) Update parameters

 7) Delete temp file mysql-init.txt

 Changes:
  --------
  2019-09-07 : SudeepJD: Added in the MySQL8 support as it needs to be handled differently
                         MySQL8 does not have a Password in the Database but uses the identified by
  2021-04-07 : SudeepJD: MariaDB post 10.5 has made mysql.user a view, so it cannot be modified
                         This has moved to global_privs and the restore needs to be done differently.
  2.2.0      : MariaDB only, root only (the MySQL branch and the phpMyAdmin control
               user 'pma' are gone). root gets WITH GRANT OPTION back, which
               Create restricted user needs and the old restore left out.
=============================================================================}
procedure mysql_restore_root_password;
var
  FileVar1 : TextFile;  // Text File handle
  AProcess : TProcess;  // Process handle
begin

  //1==Kill server
  us_kill_mysql_program;                    // Check server running. If running kill it

  //2==Write the restore statements to mysql-init.txt.
  //   mysql_native_password: MariaDB's own default; caching_sha2_password is
  //   a MySQL 8 plugin MariaDB does not ship as a server plugin, a row naming
  //   it would leave a user account that cannot log in
   Assign(FileVar1,USF_MYSQL_TEMP_SQL);      // Assign file
   ReWrite(FileVar1);                        // Create file for writting
   Writeln(FileVar1, 'use mysql;');
   Writeln(FileVar1, 'INSERT IGNORE INTO global_priv (Host, User, Priv) VALUES (''localhost'', ''root'', ''{"access":0,"plugin":"mysql_native_password","authentication_string":"","password_last_changed":0}'');');
   Writeln(FileVar1, 'FLUSH PRIVILEGES;');
   Writeln(FileVar1, 'ALTER USER ''root''@''localhost'' IDENTIFIED BY ''root'';');
   Writeln(FileVar1, 'GRANT ALL ON *.* TO ''root''@''localhost'' WITH GRANT OPTION;');
   Writeln(FileVar1, 'FLUSH PRIVILEGES;');

   CloseFile(FileVar1);                     // Close file
   Sleep(100);                              // Wait for file to be created

  //3)== Start MySQL server with skip Grant tables
  If us_start_mysql_skip_grants() Then
    Begin   // Server running

      //==4)Run sql file mysql-init.txt
      AProcess := TProcess.Create(nil);   // Create new process

      AProcess.Executable := US_MYSQL_BIN + '\mysql.exe';                   // Executable to run
      AProcess.Parameters.Add('--execute="SOURCE '+USF_MYSQL_TEMP_SQL+'"'); // mysql-init.txt

      AProcess.Options  := AProcess.Options + [poNoConsole];                // Set option no console
      AProcess.Execute;                                                     // Run command
      AProcess.Free;     

      //5)==Wait a short time and kill server
      Sleep(4000);
      us_kill_mysql_program;                 // Kills MySQL server     

      //6)==Root password changed
      us_save_mysql_password('root');        // Save 'root' password to password file
      MY_PWD := 'root';                      // Updated password global variable
      us_MessageDlg(US_MYMAR_TXT+' Info',US_MYMAR_TXT+' root user restored', mtcustom,[mbOk],0) ; //Display information message
    End
  Else      // Failed to start server
    Begin
      us_MessageDlg(US_MYMAR_TXT+' Info','Failed to restore root user. No action taken', mtcustom,[mbOk],0) ; //Display information message
    End;

  //7)==Delete temp file mysql-init.txt
  If FileExists(USF_MYSQL_TEMP_SQL) Then
    DeleteFile(Pchar(USF_MYSQL_TEMP_SQL));

end;
{---End mysql_restore_root_password -----------------------------------------}


//=== Display Server Console ===

{*****************************************************************************
Console windows in Reload look

Windows 11 hosts new cmd windows in Windows Terminal. Windows Terminal has no
command line switch for transparency, but it reads profile "fragments" that
applications may place in
  %LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\<app>\<file>.json
(a documented extension point). The controller keeps one such fragment with
the profile "winpacho Console" (black acrylic background, opacity
from CONSOLE_OPACITY in us_user.ini, Reload icon) and opens its interactive
consoles with that profile. The profile also shows up in the Windows Terminal
dropdown, so a Reload console can be opened from there as well.

Fallback: without Windows Terminal (wt.exe not found), when the fragment
cannot be written, or with CONSOLE_OPACITY=100 the classic cmd window opens
(white on black), exactly as before.
=============================================================================}
const
 US_CONSOLE_PROFILE      = 'winpacho Console';                              // Profile name: fragment and wt -p
 US_CONSOLE_FRAGMENT_DIR = '\Microsoft\Windows Terminal\Fragments\winpacho'; // Below %LOCALAPPDATA%
 US_CONSOLE_FRAGMENT     = 'console.json';
 // Fragment folder of the console profile before the 2.0 rename; removed so
 // Windows Terminal does not list the old profile next to the new one
 US_CONSOLE_FRAGMENT_DIR_OLD = '\Microsoft\Windows Terminal\Fragments\UniServer Reload';

{ Escape a string for use inside a JSON string literal (paths) }
function us_json_escape(const S: String): String;
begin
 Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
 Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

{ Full path of wt.exe (Windows Terminal launcher), '' when not installed.
  The launcher is an "app execution alias", a reparse point FPC's FileExists
  cannot follow - hence FollowLink=False. }
function us_find_windows_terminal: String;
var
 localAppData, pathEntry: String;
 dirs: TStringList;
 i: Integer;
begin
 localAppData := SysUtils.GetEnvironmentVariable('LOCALAPPDATA');
 if localAppData <> '' then
  begin
   Result := localAppData + '\Microsoft\WindowsApps\wt.exe';   // Store / packaged install
   if FileExists(Result, False) then Exit;
  end;

 dirs := TStringList.Create;                                   // Other installs put wt.exe on the PATH
 try
  dirs.Delimiter       := ';';
  dirs.StrictDelimiter := True;
  dirs.DelimitedText   := SysUtils.GetEnvironmentVariable('PATH');
  for i := 0 to dirs.Count - 1 do
   begin
    pathEntry := Trim(dirs[i]);
    if pathEntry = '' then Continue;
    Result := IncludeTrailingPathDelimiter(pathEntry) + 'wt.exe';
    if FileExists(Result, False) then Exit;
   end;
 finally
  dirs.Free;
 end;
 Result := '';
end;

{ Write or refresh the Windows Terminal fragment with the Reload console
  profile. Rewritten only when the content changed (opacity, install path);
  us_user.ini is the single source of truth, edits of the file are not kept.
  Returns False when it cannot be written (no LOCALAPPDATA, no permission);
  the caller then falls back to the classic console. }
function us_write_console_fragment(opacity: Integer): Boolean;
var
 localAppData, dir, fileName: String;
 wanted, existing: TStringList;
begin
 Result := False;
 localAppData := SysUtils.GetEnvironmentVariable('LOCALAPPDATA');
 if localAppData = '' then Exit;
 dir      := localAppData + US_CONSOLE_FRAGMENT_DIR;
 fileName := dir + '\' + US_CONSOLE_FRAGMENT;

 // Only the file this controller wrote, then the folder if it is now empty
 if FileExists(localAppData + US_CONSOLE_FRAGMENT_DIR_OLD + '\' + US_CONSOLE_FRAGMENT) then
  begin
   SysUtils.DeleteFile(localAppData + US_CONSOLE_FRAGMENT_DIR_OLD + '\' + US_CONSOLE_FRAGMENT);
   RemoveDir(localAppData + US_CONSOLE_FRAGMENT_DIR_OLD);       // Fails harmlessly when not empty
  end;

 wanted   := TStringList.Create;
 existing := TStringList.Create;
 try
  wanted.Add('{');
  wanted.Add('  "profiles": [');
  wanted.Add('    {');
  wanted.Add('      "name": "' + US_CONSOLE_PROFILE + '",');
  wanted.Add('      "commandline": "cmd.exe",');
  wanted.Add('      "startingDirectory": "' + us_json_escape(UniConPath) + '",');
  wanted.Add('      "icon": "' + us_json_escape(Application.ExeName) + '",');   // Tab icon: the controller's own icon
  wanted.Add('      "colorScheme": "Campbell",');
  wanted.Add('      "foreground": "#FFFFFF",');
  wanted.Add('      "background": "#000000",');
  wanted.Add('      "opacity": ' + IntToStr(opacity) + ',');
  wanted.Add('      "useAcrylic": true');
  wanted.Add('    }');
  wanted.Add('  ]');
  wanted.Add('}');

  try
   if FileExists(fileName) then
    begin
     existing.LoadFromFile(fileName);
     if existing.Text = wanted.Text then Exit(True);              // Up to date
    end;
   if not ForceDirectories(dir) then Exit;
   wanted.SaveToFile(fileName);
   Result := True;
  except
   Result := False;                                              // e.g. read-only profile folder
  end;
 finally
  existing.Free;
  wanted.Free;
 end;
end;

{*****************************************************************************
us_open_console
 Opens an interactive console (cmd /K) in Reload look, classic fallback.
  ATitle   - window / tab title
  AWorkDir - folder the console starts in (controller root when missing)
  ACommand - command line tokens cmd runs after start, e.g. mysql.exe and its
             parameters; empty = plain prompt. TProcess quotes tokens that
             contain spaces.
=============================================================================}
procedure us_open_console(const ATitle, AWorkDir: String; const ACommand: array of String);
var
 AProcess   : TProcess;
 wtExe      : String;
 workDir    : String;
 words      : TStringList;
 i          : Integer;
 useTerminal: Boolean;
begin
 workDir := ExcludeTrailingPathDelimiter(AWorkDir);      // "dir\" before a closing quote breaks the argument
 if not DirectoryExists(workDir) then
   workDir := UniConPath;

 wtExe       := '';
 useTerminal := USUC_CONSOLE_OPACITY < 100;               // 100 = user wants the classic window
 if useTerminal then
  begin
   wtExe       := us_find_windows_terminal;
   useTerminal := (wtExe <> '') and us_write_console_fragment(USUC_CONSOLE_OPACITY);
  end;

 AProcess := TProcess.Create(nil);
 try
  if useTerminal then
   begin
    AProcess.Executable := wtExe;
    AProcess.Parameters.Add('-w');                         // Own window, like the classic console
    AProcess.Parameters.Add('new');
    AProcess.Parameters.Add('-p');
    AProcess.Parameters.Add(US_CONSOLE_PROFILE);           // Profile from the fragment: transparency, icon
    AProcess.Parameters.Add('-d');
    AProcess.Parameters.Add(workDir);
    AProcess.Parameters.Add('--title');
    AProcess.Parameters.Add(ATitle);
    AProcess.Parameters.Add('--suppressApplicationTitle'); // Keep our title; cmd would show the running
                                                           // command line instead (MySQL password!)
    AProcess.Parameters.Add('cmd.exe');
    AProcess.Parameters.Add('/K');                         // Keep open
   end
  else
   begin
    AProcess.Executable := 'cmd';
    AProcess.Parameters.Add('/T:0F');                      // White on black
    AProcess.Parameters.Add('/K');                         // Keep open
    AProcess.Parameters.Add('cd');
    AProcess.Parameters.Add('/d');                         // Also switch the drive
    AProcess.Parameters.Add(workDir);
    AProcess.Parameters.Add('&&');
    AProcess.Parameters.Add('title');                      // title takes the rest of the line verbatim: pass the
    words := TStringList.Create;                           // words one by one - a single quoted parameter
    try                                                    // would put the quotes into the title
     words.Delimiter       := ' ';
     words.StrictDelimiter := True;
     words.DelimitedText   := ATitle;
     for i := 0 to words.Count - 1 do
      if words[i] <> '' then AProcess.Parameters.Add(words[i]);
    finally
     words.Free;
    end;
   end;

  if Length(ACommand) > 0 then
   begin
    if not useTerminal then AProcess.Parameters.Add('&&');
    for i := 0 to High(ACommand) do
     AProcess.Parameters.Add(ACommand[i]);
   end;

  AProcess.Execute;                                        // Detached: the window stays open
 finally
  AProcess.Free;
 end;
end;
{--- End us_open_console ----------------------------------------------------}

{*****************************************************************************
Display Server Command Console
Opens a console at the server root folder (Reload look, see us_open_console).
=============================================================================}
procedure us_display_server_console;
begin
 us_open_console('SERVER Command Console', UniConPath, []);
end;
{----------------------------------------------------------------------------}


{*****************************************************************************
Launch WinpachoService (Windows service module)
WinpachoService ships in the utils subfolder. Until 2.0.0 it was called
UniService.exe (in utils since 1.3.0, next to the controller before), so an
install that only got a new controller still finds its old service module.
Its manifest requires administrator rights, hence ShellExecute is used so
Windows shows the UAC prompt.
=============================================================================}
procedure us_display_uniservice;
const
 SERVICE_EXE_CANDIDATES: array[0..2] of String = (
   '\utils\WinpachoService.exe',  // Default location since 2.1.0
   '\utils\UniService.exe',       // Name until 2.0.0
   '\UniService.exe');            // Root location before 1.3.0
Var
 exePath :String;
 i       :Integer;
begin
 exePath := '';
 for i := Low(SERVICE_EXE_CANDIDATES) to High(SERVICE_EXE_CANDIDATES) do
   If FileExists(UniConPath + SERVICE_EXE_CANDIDATES[i]) Then
    begin
     exePath := UniConPath + SERVICE_EXE_CANDIDATES[i];
     Break;
    end;

 If exePath <> '' Then
   //--from-controller: WinpachoService skips its "please start me from the
   //controller" hint when launched through this menu entry
   ShellExecute(0, 'open', PChar(exePath), PChar('--from-controller'),
                PChar(UniConPath), SW_SHOWNORMAL)
 Else
   us_MessageDlg('WinpachoService not found',
     'WinpachoService.exe was not found in:'+ sLineBreak +
     UniConPath + '\utils'+ sLineBreak + sLineBreak +
     'It is part of winpacho.zip on the release page: take utils\WinpachoService.exe' + sLineBreak +
     'out of the zip, place it in the utils folder above and try again.',
     mtError,[mbOk],0);
end;
{--- End us_display_uniservice ----------------------------------------------}


//=== Perl

{*****************************************************************************
 This procedure updates Perl shebang to either a Windows or Unix shebang.
 For the following files in folder cgi-bin
   *.pl
   *.pm
   *.cgi

 Input:
 US_WINDOWS_SHEBANG - Replaces Unix shebang with Windows version
 US_UNIX_SHEBANG    - Replaces Windows shebang with Unix version

 // Perl Shebangs
 US_SHEBANG             := '#!';               // #!
 US_UNIX_SHEBANG        := '#!/usr/bin/perl';  // #!/usr/bin/perl
 US_WINDOWS_SHEBANG     := '#!perl';           // #!perl

 FindAllFiles: Uses  FileUtil
 ExecRegExpr : Uses  RegExpr
=============================================================================}
procedure force_shebang_update(NEW_SHEBANG:string);

var
  sList_Files   :TStringList;    // Save list of files
  sList         :TStringList;    // Save file to list
  i             :integer;        // Loop counter
begin
  If DirectoryExists(US_CGI_BIN) Then   // CGI Folder exists
   begin
    sList        := TStringList.Create;  // Create object

  //==Get all files of type *.pl
  sList_Files  := FindAllFiles(US_CGI_BIN, '*.pl',true);  //Create list. Search subs

   //Scan file list
   for i:=0 to sList_Files.Count-1 do
     begin
       sList.Clear;                                   // Remove old list content
       sList.LoadFromFile(sList_Files[i]);            // Load file
       If (sList[i]<>'') and ExecRegExpr('^'+US_SHEBANG, sList[0])  then // Shebang found in first line
         begin
            sList[0] := NEW_SHEBANG;                  // Set new shebang

            If FileIsWritable(sList_Files[i]) Then
               sList.SaveToFile(sList_Files[i]);      // Save new values to file

            sleep(100);
         end;
     end;//End scan list

   //==Get all files of type *.pm
   sList_Files.Clear;                                       // Remove old content
   sList_Files   := FindAllFiles(US_CGI_BIN, '*.pm',true);  // Search subs

   //Scan file list
   for i:=0 to sList_Files.Count-1 do
     begin
       sList.Clear;                                  // Remove old list content
       sList.LoadFromFile(sList_Files[i]);           // Load file
       If (sList[i]<>'') and ExecRegExpr('^'+US_SHEBANG, sList[0]) then // Shebang found in first line
         begin
            sList[0] := NEW_SHEBANG;                // Set new shebang

            If FileIsWritable(sList_Files[i]) Then
               sList.SaveToFile(sList_Files[i]);      // Save new values to file

            sleep(100);
         end;
     end;//End scan list

   //==Get all files of type *.cgi
   sList_Files.Clear;                                       // Remove old content
   sList_Files  := FindAllFiles(US_CGI_BIN, '*.cgi',true);  // Search subs

   //Scan file list
   for i:=0 to sList_Files.Count-1 do
     begin
       sList.Clear;                                   // Remove old list content
       sList.LoadFromFile(sList_Files[i]);            // Load file
       If (sList[i]<>'') and ExecRegExpr('^'+US_SHEBANG, sList[0]) then  // Shebang found in first line
         begin
            sList[0] := NEW_SHEBANG;                  // Set new shebang

            If FileIsWritable(sList_Files[i]) Then
               sList.SaveToFile(sList_Files[i]);      // Save new values to file

            sleep(100);
         end;
     end;//End scan list

   //==Clean up
   sList.Free;       //Release memory
   sList_Files.Free; //Release memory

  end; //DirectoryExists(US_CGI_BINL)


end;
{----------------------------------------------------------------------------}

//=== PHP

{*****************************************************************************
Disable all PHP accelerators in selected PHP ini configuration file
=============================================================================}
procedure disable_all_php_accelerators;
var
 sList                  :TStringList;  // String list
 i                      :integer;      // Loop counter
 selected_ini_file      :String;       // Full path selected php config file
begin
 selected_ini_file :=US_CORE+'\'+UENV_PHP_SELECT+'\'+UENV_PHP_INI_SELECT;     // Full path selected php config file

 sList  := TStringList.Create;            // Create object
 sList.LoadFromFile(selected_ini_file);   // Load PHP ini configuration file

 //Scan sList. add ; to disable accelerator
 for i:=0 to sList.Count-1 do
   begin
     // Zend OpCache code
     If (sList[i]<>'') and ExecRegExpr('^[^;].*'+QuoteRegExprMetaChars(ZENDOPCACHE_DLL)+'.*$', sList[i]) Then  sList[i] := ';'+sList[i];
   end; //End scan list

  If FileIsWritable(selected_ini_file) Then
     sList.SaveToFile(selected_ini_file);  // Save new values to file


sList.Free;                                // Remove from memory
end;
{--End disable_all_php_accelerators -----------------------------------------}

{*****************************************************************************
Enable named PHP accelerator in selected PHP ini configuration file
Input:
  apc
  eaccelerator
  xcache
  zop
=============================================================================}
procedure enable_php_accelerator(accelerator:String);
var
 sList                  :TStringList;  // String list
 i                      :integer;      // Loop counter
 selected_ini_file      :String;       // Full path selected php config file
begin
 selected_ini_file :=US_CORE+'\'+UENV_PHP_SELECT+'\'+UENV_PHP_INI_SELECT; // Full path selected php config file

 sList  := TStringList.Create;            // Create object
 sList.LoadFromFile(selected_ini_file);   // Load PHP ini configuration file

 //Scan sList. add ; to disable accelerator

  // Zend OpCache
  If accelerator = 'zop' Then
  begin
   for i:=0 to sList.Count-1 do
      begin
         // Zend OpCache code
        If (sList[i]<>'') and ExecRegExpr('^[;].*'+QuoteRegExprMetaChars(ZENDOPCACHE_DLL)+'.*$', sList[i]) Then
          sList[i] := ReplaceRegExpr('^;', sList[i], '', False); //Remove ; to enable
      end; //End scan list
  end;

 If FileIsWritable(selected_ini_file) Then
    sList.SaveToFile(selected_ini_file);  // Save new values to file

 sList.Free;                              // Remove from memory
end;
{--End enable_php_accelerator -----------------------------------------------}

{*****************************************************************************
View selected PHP Accelerator, control panel
=============================================================================}
procedure view_selected_acc_control_panel;
var
  url :string;
begin

   // Zend OpCache code
   If Main.MMSS_php_acc_zop.Checked Then
    Begin
      url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/us_extra/zend_optimizer_control.php';
      browser_display_url(url); //Display URL in default/portable browser
    End;
end;
{--End view_selected_acc_control_panel --------------------------------------}

//=== Message Dialogs

{*****************************************************************************
 Reminder dialog - Restart apache.
=============================================================================}
procedure msg_restart_apache;
var
 title:string;
 str:string;
begin
 If ApacheRunning() then
  begin
    title     := 'Apache running';
    str:='';
    str := str + 'Apache is running' + sLineBreak;
    str := str + 'For changes to take effect restart the Apache server.';

    us_MessageDlg(title, str, mtInformation,[mbOk],0) ;  //Display message
  end;
end;
{-- End msg_restart_apache --------------------------------------------------}


{*****************************************************************************
MySQL port change
Warn user MySQL server is running and to stop server.
=============================================================================}
procedure msg_stop_mysql_port_change;
var
 title:string;
 str:string;
begin
    title     := US_MYMAR_TXT+' running';
    str:='';
    str := str + US_MYMAR_TXT+' is running! You need to stop the '+US_MYMAR_TXT+' server' + sLineBreak;
    str := str + 'before its port can be changed.' + sLineBreak+ sLineBreak;

    str := str + 'a) Stop the '+US_MYMAR_TXT+' server.' + sLineBreak;
    str := str + 'b) Run this menu item again to change port.';

    us_MessageDlg(title, str, mtInformation,[mbOk],0) ;  //Display message
end;
{--End msg_stop_mysql_port_change -------------------------------------------}


{*****************************************************************************
MySQL root password change
Warn user MySQL server is running and to stop server.
=============================================================================}
procedure msg_stop_mysql_pwd_change;
var
 title:string;
 str:string;
begin
    title     := US_MYMAR_TXT+' running';
    str:='';
    str := str + US_MYMAR_TXT+' is running! You need to stop the '+US_MYMAR_TXT+' server' + sLineBreak;
    str := str + 'before you can change the '+US_MYMAR_TXT+' root password.' + sLineBreak+ sLineBreak;

    str := str + 'a) Stop the '+US_MYMAR_TXT+' server.' + sLineBreak;
    str := str + 'b) Run this menu item again to change root password.';

    us_MessageDlg(title, str, mtInformation,[mbOk],0) ;  //Display message
end;
{--End msg_stop_mysql_pwd_change -------------------------------------------}


{*****************************************************************************
Password file contains_defaults
Warn user file contains root:root default name and password.
=============================================================================}
procedure msg_password_file_contains_defaults;
var
 title:string;
 str:string;
begin
    title     := 'Defaults detected';
    str:='';
    str := str + 'Password file contains root:root default name and password.' + sLineBreak + sLineBreak;
    str := str + 'To enable password protection delete these defaults.';

    us_MessageDlg(title, str, mtInformation,[mbOk],0) ;  //Display message
end;
{--End msg_password_file_contains_defaults ----------------------------------}

{*****************************************************************************
Password file empty
Warn user no enteries in file
=============================================================================}
procedure msg_password_file_empty;
var
 title:string;
 str:string;
begin
    title     := 'No Entries';
    str:='';
    str := str + 'Password file is empty.' + sLineBreak + sLineBreak;
    str := str + 'One or more name password pairs are required.';

    us_MessageDlg(title, str, mtInformation,[mbOk],0) ;  //Display message
end;
{--End msg_password_file_empty -------------------------------------------}


//=== GO PEAR ===

{===============================================================
 update_go_pear_config:
 This procedure updates paths in go-pear configuration file.
 Inaddition updates PHP selected

 For portability paths upto 'home' and 'core' require updating.
 Paths are not tracked hence this procedure is always run at start-up.
 In addition run if a user selects a different PHP version.
 Path updates use a regex to isolate sections of a string and
 paths chaged accordingly.
----------------------------------------------------------------}
procedure us_update_go_pear_config;
var
  sList:    TStringList; // String list
  sList2:   TStringList; // String list
  i:        integer;     // Loop counter
  s_value:  Integer;     // Length
  str:      string;
  RegexObj: TRegExpr;    // Object
  pt1:String; //Path component parts
  pt2:String;
  pt3:String;
  pt4:String;
  pt5:String;
  pt6:String;
  pt7:String;
  pt8:String;

begin
 If FileExists(USF_GO_PEAR_CONFIG) Then
  begin

    //==Get go-pear configuration file
    sList       := TStringList.Create;       // Create object
    sList2      := TStringList.Create;       // Create object
    sList.LoadFromFile(USF_GO_PEAR_CONFIG);  // Load file

    //=== Serialize string (sList[1]) save to sList2 which splits the string
    sList2.StrictDelimiter := true;   // Use only the defined delimiter
    sList2.Delimiter := ';';          // Define delimiter - split at ;
    sList2.DelimitedText := sList[1]; // Assign serialized string and split

    //== Update paths using regex selection
    RegexObj := TRegExpr.Create;           // Create regex obj

    //== Update home path
    RegexObj.Expression := '^(s:)(\d+)(:")(.+)(\\home\\)(.+)"$'; // Set search pattern

    for i:=0 to sList2.Count-1 do // Scan list
    begin
     if (sList2[i]<>'') and RegexObj.Exec(sList2[i]) then                            // Match found
       begin
        //Build new line:
        pt1 := 's:';              // s:
        pt2 := RegexObj.Match[2]; // digits for s
        pt3 := ':"';              // :"
        pt4 := UniConPath;        // Set new path e.g C:\fred\winpacho
        pt5 := '\home\';          // \home\  folder
        pt6 := RegexObj.Match[6]; // remainder of path us_pear\PEAR\docs
        pt7 := '"';               // Last quote "
        s_value  := Length(pt4) + Length(pt5)+Length(pt6);    // Length of string
        pt2      := IntToStr(s_value);                        // Convert to string
        sList2[i] := pt1 + pt2 + pt3 + pt4 + pt5 + pt6 + pt7; // Create new line
       end;
    end;
    //== Update core path note this also includes php version selected.
    RegexObj.Expression := '^(s:)(\d+)(:")(.+)(\\core\\)(php\d+)(.+)"$'; // Set search pattern

    for i:=0 to sList2.Count-1 do      // Scan list
    begin
     if (sList2[i]<>'') and RegexObj.Exec(sList2[i]) then  // Match found
       begin
        //Build new line:
        pt1 := 's:';              // s:
        pt2 := RegexObj.Match[2]; // digits for s
        pt3 := ':"';              // :"
        pt4 := UniConPath;        // Set new path e.g C:\fred\winpacho
        pt5 := '\core\';          // \core\  folder
        pt6 := UENV_PHP_SELECT;   // PHP Version selected
        pt7 := RegexObj.Match[7]; // remainder of path us_pear\PEAR\docs
        pt8 := '"';               // Last quote "
        s_value := Length(pt4) + Length(pt5)+Length(pt6)+Length(pt7); // Length of string
        pt2     := IntToStr(s_value);                                 // Convert to string
        sList2[i] := pt1 + pt2 + pt3 + pt4 + pt5 + pt6 + pt7 + pt8;   // Create new line
       end;
    end;
     RegexObj.Free; // Release memory

    //===Build new configuration string
    str :='';                           // Clear string
    for i:=0 to sList2.Count-2 do       // Built new string
      begin
        str := str + sList2[i] +';' ;   // Build string re-insert ;
      end;
    str := str + sList2[sList2.Count-1]; // Last line note no ';'

    //Save new conig string
    sList[1] := str;    // Assign new config string

    //Save new file
    sList.SaveToFile(USF_GO_PEAR_CONFIG);  // Save new values to file

    //Clean-up
    sList.Free;    // Remove from memory
    sList2.Free;   // Remove from memory
  end; //If file exists
end; 

{--- END us_update_go_pear_config ---------------------------------}

//=== PALE MOON BROWSER ===

{****************************************************************************
Start PaleMoon Browser
 Skip if already running.
 PALE_MOONL_EXE  Palemoon-Portable.exe Portable Palemoon launcher start-up exe
Note: Uses Process
=============================================================================}
procedure us_start_palemoon;
Var
 AProcess: TProcess;
 saftey_loop: Integer;

begin
 If DirectoryExists(US_PALE_MOON) Then
  begin
   if not PaleMoonPortableRunning() then
    begin
    //--Run command string.
    AProcess := TProcess.Create(nil);                         // Create new process

    AProcess.Executable := USF_PALE_MOON_EXE;                 // Executable to run
    AProcess.Parameters.Add('file:///'+USF_REFERENCE_HTML);   // Parameter ref html file
    AProcess.Options  := AProcess.Options + [poNoConsole];    // Set option no console
    AProcess.Execute;                                         // Run command
    AProcess.Free;                                            // Release process

    saftey_loop :=0;
    Repeat   // Wait for Pale moon to start
      begin
        Application.ProcessMessages;      // allow message processing
        sleep(100);
        saftey_loop := saftey_loop +1;    // Increment counter
        if saftey_loop > (USC_PM_StartSafetyTime*10) then
         begin
           us_MessageDlg('Warning','Failed to start Pale Moon Browser', mtWarning,[mbOk],0) ; //Display warning message
           Break;
         end;
      end;
    Until PaleMoonPortableRunning();

    //Pale Moon now running confirm it is ready
    //Wait for window and read unique title bar
    saftey_loop :=0;                  // Reset flag

    Repeat   // Wait for Pale moon - ready
      begin
        Application.ProcessMessages;      // allow message processing
        sleep(1000);
        saftey_loop := saftey_loop +1;    // Increment counter
        if saftey_loop > (USC_PM_ReadySafetyTime) then
         begin
           us_MessageDlg('Warning','Failed to start Pale Moon Browser', mtWarning,[mbOk],0) ; //Display warning message
           Break;
         end;
      end;
    Until palemoon_ready();
    end;
  end;//DirectoryExists(US_PALE_MOON)
 end;
{--- End us_start_palemoon -------------------------------------------------}



{****************************************************************************
Kill Pale Moon Browser
Global variables used:
  PALE_MOON_EXE  palemoon.exe   Palemoon execuitable
=============================================================================}
procedure us_kill_palemoon;
Var
 saftey_loop: Integer;

begin
 if PaleMoonPortableRunning() then
  saftey_loop:=0;
  begin
      KillRunningProcess(PALE_MOON_EXE);    //Kill Pale Moon program
  end;

  Repeat                                   // Wait for Pale Moon to stop
    begin
      Application.ProcessMessages;         //allow message processing
      sleep(100);
      saftey_loop := saftey_loop +1;       // Increment counter
      if saftey_loop > (USC_PM_StopSafetyTime*10) then
       begin
         us_MessageDlg('Warning','Failed to stop Pale Moon Browser', mtWarning,[mbOk],0) ; //Display warning message
         Break;
       end;
    end;
   Until not PaleMoonPortableRunning();
 end;
{--- END us_kill_palemoon  -----------------------------------------------------}


//=== DEFAULT BROWSER ===
{****************************************************************************
us_start_default_browser
 Skip if already running.
 Start with a reference html page allowing default exe name to be determined.
 Initial value for default browser DEFAULT_BROWSER_EXE xxx
Note: Uses Process
=============================================================================}
procedure us_start_default_browser;
Var
 saftey_loop: Integer;

begin
   if not DefaultBrowserRunning() then //Default browser is not running
    begin
    //--Run default browser with the reference html page.
    //URL Format eg: URL:='file:///G:/us_traymenu/docs/manual/index.html'
    ShellExecute(0, 'open', PCHAR('file:///'+USF_REFERENCE_HTML), Nil,  Nil,  SW_SHOWNORMAL);

    //--Wait for window and read unique title bar
    saftey_loop :=0;                  // Reset flag

    Repeat   // Wait for Default browser  - ready
      begin
        Application.ProcessMessages;      // allow message processing
        sleep(1000);
        saftey_loop := saftey_loop +1;    // Increment counter
        if saftey_loop > (USC_PM_ReadySafetyTime) then
         begin
           us_MessageDlg('Warning','Failed to start default browser', mtWarning,[mbOk],0) ; //Display warning message
           Break;
         end;
      end;
    Until default_browser_ready();
    end;
 end;
{--- End us_start_default_browser --------------------------------------------}


//=== DISPLAY IN BROWSER ===

{****************************************************************************
browser_display_url();
 Display page in portable browser - Pale Moon browser
 Or display in default browser
 Selection performed by variable PortableBrowser - Set if Pale Moon installed
 Note: Uses Process

General note:
 Display URL in default/portable browser.
     eg: URL:='http://www.lazarus.freepascal.org';
     eg: URL:='file:///G:/docs/English/index.html'

 Input
  URL : String  - Full URL to page
 Uses   windows

 This procedure uses the ShellExecute function to display the requested URL
 in the default browser. If the default browser is not running it is started.

 Mirosoft format:
  ShellExecute(NULL, 'open', 'http://www.microsoft.com', NULL, NULL, SW_SHOWNORMAL);
 Lazarus format:
  ShellExecute(0,    'open', 'http://www.microsoft.com', nil,  nil,  SW_SHOWNORMAL);

=============================================================================}
procedure browser_display_url(url:string);
Var
 AProcess: TProcess;
begin

 If PortableBrowser Then // Portable browser installed
  begin
    //us_start_palemoon;  // Ensure browser is running. If running no action taken. 
    //SudeepJD - Commeted the above line, The TProcess will start up Palemoon directly
    //  so a check that it is already running is not required, since it will start up anyways.

    //--Run command string.
    AProcess := TProcess.Create(nil);                         // Create new process
    AProcess.Executable := USF_PALE_MOON_EXE;                 // Executable to run
    AProcess.Parameters.Add(url);                             // Pass parameter to run
    AProcess.Options  := AProcess.Options + [poNoConsole];    // Set option no console
    AProcess.Execute;                                         // Run command
    AProcess.Free;                                            // Release process
  end
 Else   // Use default browser
  begin
    //us_start_default_browser; // Ensure browser is running. If running no action taken.
    //SudeepJD - Commented the above line since ideally a ShellExecute should start anyway, starting
    // with a default page, does not seem to be required.
    ShellExecute(0, 'open', PCHAR(URL), Nil,  Nil,  SW_SHOWNORMAL); //Display in default
  end;
end;

{--- End browser_display_url ----------------------------------------------}

//=== PAC ===

{****************************************************************************
us_add_to_pac_file
 Add domain (e.g fred.com) name to UniServer PAC file
=============================================================================}
procedure us_add_to_pac_file(host:string);
Var
  newHost :String;                   //New host to inser
  endPac  :String;                   // End of pac file
  sList: TStringList;                // String list
  i: Integer;                        // Loop counter
begin
If FileExists(USF_PAC) Then               // Check proxy.pac exists
 begin
   //Create new host string
   newHost := 'if (shExpMatch(host, "*'+host+'")) return "PROXY 127.0.0.1:'+UENV_AP_PORT+'";';
   host := QuoteRegExprMetaChars(host);   // Escape to regular string for regex
   endPac  := '^return "DIRECT";}';       // Convert to regex

   Try
    begin
     sList := TStringList.Create;         // Create object
     sList.LoadFromFile(USF_PAC);         // Load file
     for i:=0 to sList.Count-1 do         // Scan file line by line

       begin
        if (sList[i]<>'') and ExecRegExpr(host, sList[i]) then break; // host exists nothing else to do
        if (sList[i]<>'') and ExecRegExpr(endPac, sList[i]) then     // host not found
          begin
            sList.Insert(i,newHost);               // add new host before to list
            sList.SaveToFile(USF_PAC);             // Save new host to PAC file
          end;
       end;
    end;//End try
   Finally
    sList.Free;     // remove from memory
 end;
end;
end;
{--- End us_add_to_pac_file ------------------------------------------------}

{****************************************************************************
us_delete_from_pac_file
 Delete domain (e.g fred.com) name from UniServer PAC file
=============================================================================}
procedure us_delete_from_pac_file(host:string);
Var
  sList: TStringList;                // String list
  i: Integer;                        // Loop counter
begin
If FileExists(USF_PAC) Then          // Check proxy.pac exists
 begin
   host := QuoteRegExprMetaChars(host);   // Escape to regular string for regex

   Try
    begin
     sList := TStringList.Create;           // Create object
     sList.LoadFromFile(USF_PAC);           // Load file
     for i:=0 to sList.Count-1 do           // Scan file line by line

       begin
        if (sList[i]<>'') and ExecRegExpr(host, sList[i]) then  // host found
          begin
            sList.Delete(i);                 // Remove host from list
            sList.SaveToFile(USF_PAC);       // Save pac file
            break;                           // Exit for nothing else to do
          end;
       end;
    end;//End try
   Finally
    sList.Free;     // remove from memory
 end;
end;
end;
{--- End us_delete_from_pac_file -------------------------------------------}

{****************************************************************************
us_proxy_file_port_update
 Replace old port with new port for all domains
=============================================================================}
procedure us_proxy_file_port_update(old_port:string;new_port:string);
Var
  sList: TStringList;                // String list
  i: Integer;                        // Loop counter
  old_str:string;                    // "PROXY 127.0.0.1:port"
  new_str:string;                    // "PROXY 127.0.0.1:new_port"
begin
If FileExists(USF_PAC) Then          // Check proxy.pac exists
 begin
   old_str:= '"PROXY 127.0.0.1:'+old_port+'"';
   new_str:= '"PROXY 127.0.0.1:'+new_port+'"';

   Try
    begin
     sList := TStringList.Create;         // Create object
     sList.LoadFromFile(USF_PAC);         // Load file
     for i:=0 to sList.Count-1 do         // Scan file line by line
       begin
         sList[i] := StringReplace(sList[i], old_str,new_str,[rfReplaceAll]);   // Update port to new value
       end;
     sList.SaveToFile(USF_PAC);           // Save new pac to file
    end;//End try
   Finally
    sList.Free;     // remove from memory
 end;
 end;
end;
{--- End us_proxy_file_port_update ------------------------------------------}


//=== HOSTS ===


{****************************************************************************
us_auto_generate_ssl_cert
 First-start comfort: if no server certificate exists, silently generate a
 self-signed certificate for localhost (subjectAltName covers localhost,
 127.0.0.1 and ::1) using the bundled openssl, install it to the Apache
 server_certs folder and enable SSL in Apache's configuration file.
 https://localhost then works out of the box.
 Does nothing when a certificate already exists or openssl is missing.
=============================================================================}
procedure us_generate_ssl_cert(san_ext:string; overwrite:boolean);
Var
 AProcess: TProcess;
begin
 If FileExists(USF_CERT) and (not overwrite) Then Exit;        // Certificate already exists
 If Not FileExists(US_APACHE_BIN + '\openssl.exe') Then Exit;  // OpenSSL not available

 AProcess := TProcess.Create(nil);        // Create process
 AProcess.Executable := 'cmd';            // Want to run a command prompt

 AProcess.Parameters.Add('/T:0F');        // Set background colour
 AProcess.Parameters.Add('/c');           // Close when finished
 AProcess.Parameters.Add('title');        // A title is required
 AProcess.Parameters.Add('US Cert');      // Title

 AProcess.Parameters.Add('&&');           // Start a new command line
 AProcess.Parameters.Add('CD');           // Change directory
 AProcess.Parameters.Add(US_APACHE_BIN);  // To path Apache bin openssl.exe

 AProcess.Parameters.Add('&&');           // Start a new command line
 AProcess.Parameters.Add('set');          // Set environment variable command Dos
 AProcess.Parameters.Add('OPENSSL_CONF='+US_OPENSSL + '\openssl.cnf'); // Set cmd variable OPENSSL_CONF

 AProcess.Parameters.Add('&&');           // Start a new command line
 AProcess.Parameters.Add('openssl');      // Run Openssl program
 AProcess.Parameters.Add('req');          // Request new certificate
 AProcess.Parameters.Add('-x509');        // Self-signed certificate (no csr needed)
 AProcess.Parameters.Add('-newkey');      // and new key
 AProcess.Parameters.Add('rsa:2048');     // Key size
 AProcess.Parameters.Add('-batch');       // Run in batch mode (requires no user input)
 AProcess.Parameters.Add('-nodes');       // Unencrypted key
 AProcess.Parameters.Add('-keyout');      // Output key
 AProcess.Parameters.Add('server.key');   // to file server.key
 AProcess.Parameters.Add('-out');         // Output file is
 AProcess.Parameters.Add('server.crt');   // certificate file server.crt
 AProcess.Parameters.Add('-days');        // Validity
 AProcess.Parameters.Add('3650');         // 10 years
 AProcess.Parameters.Add('-subj');        // Subject
 AProcess.Parameters.Add('"/O=winpacho/CN=localhost"');
 AProcess.Parameters.Add('-addext');      // subjectAltName so browsers accept the names
 AProcess.Parameters.Add('"subjectAltName='+san_ext+'"');

 AProcess.Parameters.Add('&&');           // Start a new command line
 AProcess.Parameters.Add('set');          // Set environment variable command
 AProcess.Parameters.Add('OPENSSL_CONF=');// resets OPENSSL_CONF var

 AProcess.Options     := AProcess.Options + [poWaitOnExit];   // Set option wait to complete
 AProcess.ShowWindow  := swoHIDE;                             // Hide command window
 AProcess.Execute;                                            // Run command
 AProcess.Free;                                               // Release process

 //--Create server certificates folder if not exist
 ForceDirectories(US_APACHE_CERTS);

 //-- Move Certificate and Key to server (overwrite existing)
 // SysUtils. qualifier: the windows unit is in scope and its DeleteFile
 // takes a PChar; we want the string overload.
 If FileExists(US_APACHE_BIN + '\server.crt')  Then
   begin
     If FileExists(US_APACHE_CERTS+ '\server.crt') Then SysUtils.DeleteFile(US_APACHE_CERTS+ '\server.crt');
     RenameFile(US_APACHE_BIN + '\server.crt',US_APACHE_CERTS+ '\server.crt');
   end;
 If FileExists(US_APACHE_BIN + '\server.key')  Then
   begin
     If FileExists(US_APACHE_CERTS+ '\server.key') Then SysUtils.DeleteFile(US_APACHE_CERTS+ '\server.key');
     RenameFile(US_APACHE_BIN + '\server.key',US_APACHE_CERTS+ '\server.key');
   end;

 //--Certificate created: enable SSL so https works out of the box
 If FileExists(USF_CERT) Then
    us_enable_apache_ssl;
end;
{--- End us_generate_ssl_cert ------------------------------------------------}


procedure us_auto_generate_ssl_cert;
begin
 // First start comfort: only when no certificate exists yet
 us_generate_ssl_cert('DNS:localhost,IP:127.0.0.1,IP:::1', False);
end;
{--- End us_auto_generate_ssl_cert -------------------------------------------}


{****************************************************************************
us_regenerate_cert_for_all_vhosts
 Rebuild the single server certificate so its subjectAltName covers
 localhost plus every ServerName found in httpd-vhosts.conf (each domain
 with a matching *.domain wildcard). One trusted certificate then serves
 https for localhost and all vhosts. Overwrites the existing certificate,
 so the user must re-run 'Trust certificate' afterwards.
=============================================================================}
// A real hostname: letters/digits/dot/hyphen only, contains at least one
// letter, no template tokens. Rejects the default vhost's ${US_SERVERNAME},
// which would otherwise poison the SAN and make openssl refuse the whole
// extension (leaving the old localhost-only certificate in place).
function us_is_valid_hostname(const h:string): boolean;
var i:integer; hasAlpha:boolean;
begin
  Result := False;
  If (h = '') or (Length(h) > 253) Then Exit;
  hasAlpha := False;
  for i:=1 to Length(h) do
    case h[i] of
      'A'..'Z','a'..'z': hasAlpha := True;
      '0'..'9','.','-':  ;               // allowed
    else
      Exit;                              // any other char (incl. $ { }) -> invalid
    end;
  Result := hasAlpha;
end;

procedure us_regenerate_cert_for_all_vhosts;
Var
 sList : TStringList;
 san   : string;
 line, dom : string;
 i, sp : integer;
 seen  : TStringList;
begin
 san  := 'DNS:localhost,IP:127.0.0.1,IP:::1';
 seen := TStringList.Create;
 seen.Add('localhost');

 If FileExists(USF_APACHE_VHOST_CNF) Then
  begin
   sList := TStringList.Create;
   sList.LoadFromFile(USF_APACHE_VHOST_CNF);
   for i:=0 to sList.Count-1 do
     begin
       line := Trim(sList[i]);
       If (LowerCase(Copy(line,1,11)) = 'servername ') Then
         begin
           dom := Trim(Copy(line, 12, Length(line)));
           sp  := Pos(' ', dom);                       // Keep only the first token
           If sp > 0 Then dom := Copy(dom, 1, sp-1);
           If us_is_valid_hostname(dom) and (seen.IndexOf(dom) < 0) Then
             begin
               seen.Add(dom);
               san := san + ',DNS:' + dom + ',DNS:*.' + dom;
             end;
         end;
     end;
   sList.Free;
  end;
 seen.Free;

 us_generate_ssl_cert(san, True);   // Overwrite with the expanded SAN list
end;
{--- End us_regenerate_cert_for_all_vhosts -----------------------------------}


{****************************************************************************
us_trust_ssl_cert
 Add the server certificate to the Windows certificate store of the current
 user (certutil -user -addstore Root). After a browser restart
 https://localhost is shown as secure without a warning.
 Windows displays its own confirmation prompt before importing.
=============================================================================}
{===================================================================
 us_firefox_installed:
 Best-effort detection of a Firefox installation: registry entries
 written by the installer (machine or per-user install) plus the
 default install path.
====================================================================}
function us_firefox_installed:boolean;
var
  Reg :TRegistry;
begin
 Result := False;
 Reg := TRegistry.Create(KEY_READ);
 try
   Reg.RootKey := HKEY_LOCAL_MACHINE;
   If Reg.KeyExists('SOFTWARE\Mozilla\Mozilla Firefox') Then Result := True;
   If Not Result Then
    begin
      Reg.RootKey := HKEY_CURRENT_USER;
      If Reg.KeyExists('SOFTWARE\Mozilla\Mozilla Firefox') Then Result := True;
    end;
 finally
   Reg.Free;
 end;
 If Not Result Then
   Result := FileExists(SysUtils.GetEnvironmentVariable('ProgramFiles')+'\Mozilla Firefox\firefox.exe');
end;
{--- End us_firefox_installed --------------------------------------}


{===================================================================
 firefox_policy_enabled:
 True when Mozilla's ImportEnterpriseRoots policy is already active
 (per-user or machine location) - Firefox then trusts certificates
 from the Windows certificate store.
====================================================================}
function firefox_policy_enabled:boolean;
var
  Reg :TRegistry;

  function check_root(root:HKEY):boolean;
  begin
    Result := False;
    Reg.RootKey := root;
    If Reg.OpenKeyReadOnly('SOFTWARE\Policies\Mozilla\Firefox\Certificates') Then
     begin
       try
         If Reg.ValueExists('ImportEnterpriseRoots') and
            (Reg.ReadInteger('ImportEnterpriseRoots') = 1) Then Result := True;
       except
         //Unreadable value: treat as not enabled
       end;
       Reg.CloseKey;
     end;
  end;

begin
 Reg := TRegistry.Create(KEY_READ);
 try
   Result := check_root(HKEY_CURRENT_USER) or check_root(HKEY_LOCAL_MACHINE);
 finally
   Reg.Free;
 end;
end;
{--- End firefox_policy_enabled ------------------------------------}


{********************************************************************
 us_offer_firefox_trust_policy:
 Called after the certificate was added to the Windows store.
 Firefox ignores the Windows certificate store by default, so its
 https warning stays although Chrome/Edge are already satisfied.
 When Firefox is installed this offers - exactly once - to enable
 Mozilla's official ImportEnterpriseRoots policy for the current
 user, which makes Firefox use the Windows store too.
 Skipped silently when the policy is already active.
********************************************************************}
procedure us_offer_firefox_trust_policy;
var
  Reg :TRegistry;
  str :string;
  ok  :boolean;
begin
 If Not us_firefox_installed Then Exit;                                          // No Firefox on this PC
 If firefox_policy_enabled Then Exit;                                            // Already active
 If us_ini_get(USF_US_CONF_INI,'APP','FirefoxPolicyPromptDone') = 'true' Then Exit; // Already asked

 //--Remember the question was asked, whatever the answer is
 us_ini_set(USF_US_CONF_INI,'APP','FirefoxPolicyPromptDone','true');

 str :=       'Firefox is installed on this PC. Unlike Chrome and Edge,'    + sLineBreak;
 str := str + 'Firefox ignores the Windows certificate store by default,'   + sLineBreak;
 str := str + 'so its https warning stays although the certificate is now'  + sLineBreak;
 str := str + 'trusted in Windows.'                                         + sLineBreak + sLineBreak;
 str := str + 'Enable the official Firefox policy "ImportEnterpriseRoots"'  + sLineBreak;
 str := str + 'for the current user, so Firefox uses the Windows store'     + sLineBreak;
 str := str + 'too? Restart Firefox afterwards.'                            + sLineBreak + sLineBreak;
 str := str + 'Undo any time: delete value ImportEnterpriseRoots under'     + sLineBreak;
 str := str + 'HKCU\Software\Policies\Mozilla\Firefox\Certificates.'        + sLineBreak;
 str := str + 'Alternative: import the certificate manually in Firefox'     + sLineBreak;
 str := str + '(Settings, Privacy & Security, View Certificates, Import).';

 If us_MessageDlg('Firefox detected', str, mtConfirmation,[mbYes,mbNo],0) <> mrYes Then Exit;

 ok  := False;
 Reg := TRegistry.Create(KEY_WRITE);
 try
   try
     Reg.RootKey := HKEY_CURRENT_USER;
     If Reg.OpenKey('SOFTWARE\Policies\Mozilla\Firefox\Certificates', True) Then
      begin
        Reg.WriteInteger('ImportEnterpriseRoots', 1);
        ok := True;
      end;
   except
     ok := False;
   end;
 finally
   Reg.Free;
 end;

 If ok Then
   us_MessageDlg('Firefox policy set',
     'Done. Restart Firefox completely - it then trusts the'          + sLineBreak +
     'certificates from the Windows store.', mtInformation,[mbOk],0)
 Else
   us_MessageDlg('Firefox policy not set',
     'The registry value could not be written. You can import the'    + sLineBreak +
     'certificate manually instead: Firefox Settings,'                + sLineBreak +
     'Privacy & Security, View Certificates, Import.', mtWarning,[mbOk],0);
end;
{--- End us_offer_firefox_trust_policy -----------------------------}


procedure us_trust_ssl_cert;
Var
 AProcess: TProcess;
 str: string;
begin
 If Not FileExists(USF_CERT) Then
  begin
    str := 'No server certificate found.'                          + sLineBreak + sLineBreak;
    str := str + 'Generate one first via menu:'                    + sLineBreak;
    str := str + 'Apache > Apache SSL > Server Certificate and Key generator';
    us_MessageDlg('Trust Certificate', str, mtInformation,[mbOk],0);
    Exit;
  end;

 AProcess := TProcess.Create(nil);        // Create process
 AProcess.Executable := 'certutil';       // Windows certificate utility
 AProcess.Parameters.Add('-user');        // Current user store (no admin required)
 AProcess.Parameters.Add('-addstore');    // Add to store
 AProcess.Parameters.Add('Root');         // Trusted Root Certification Authorities
 AProcess.Parameters.Add(USF_CERT);       // The server certificate
 AProcess.Options    := AProcess.Options + [poWaitOnExit];  // Wait to complete
 AProcess.ShowWindow := swoHIDE;                            // Hide command window
 AProcess.Execute;                                          // Run command

 If AProcess.ExitStatus = 0 Then
  begin
    str := 'The server certificate has been added to the'   + sLineBreak;
    str := str + 'Windows certificate store of the current user.' + sLineBreak + sLineBreak;
    str := str + 'Restart your browser; https://localhost and every'  + sLineBreak;
    str := str + 'Vhost covered by this certificate will now be shown' + sLineBreak;
    str := str + 'as secure without a warning.' + sLineBreak + sLineBreak;
    str := str + 'Note: one certificate covers all domains. If you add'  + sLineBreak;
    str := str + 'a new Vhost later, run "Regenerate certificate for all' + sLineBreak;
    str := str + 'Vhosts", then trust and restart the browser again.';
    us_MessageDlg('Trust Certificate', str, mtInformation,[mbOk],0);

    //Firefox ignores the Windows store by default: offer the policy fix once
    us_offer_firefox_trust_policy;
  end
 Else
  begin
    str := 'Could not add the certificate to the Windows store.'  + sLineBreak;
    str := str + 'The Windows security prompt may have been declined.';
    us_MessageDlg('Trust Certificate', str, mtWarning,[mbOk],0);
  end;
 AProcess.Free;                           // Release process
end;
{--- End us_trust_ssl_cert ---------------------------------------------------}


{********************************************************************
 us_offer_trust_ssl_cert_once:
 First interactive start: proactively offer to trust the generated
 server certificate in Windows instead of leaving the function hidden
 in menu Apache > Apache SSL > Trust certificate in Windows.
 Asked exactly once - the fact that the question was asked is stored
 in us_config.ini, so the dialog never nags on later starts,
 whatever the answer was.
********************************************************************}
procedure us_offer_trust_ssl_cert_once;
var
  str :string;
begin
 If us_ini_get(USF_US_CONF_INI,'APP','TrustCertPromptDone') = 'true' Then Exit; // Already asked
 If Not FileExists(USF_CERT) Then Exit;                                         // Nothing to trust yet

 //--Remember the question was asked, whatever the answer is
 us_ini_set(USF_US_CONF_INI,'APP','TrustCertPromptDone','true');

 str :=       'HTTPS is ready: https://localhost uses a self-signed'      + sLineBreak;
 str := str + 'certificate generated for this installation.'              + sLineBreak + sLineBreak;
 str := str + 'Windows does not trust self-signed certificates yet, so'   + sLineBreak;
 str := str + 'browsers will show a security warning on https pages.'     + sLineBreak + sLineBreak;
 str := str + 'Trust the certificate now? Windows will ask for a final'   + sLineBreak;
 str := str + 'confirmation; afterwards restart your browser completely'  + sLineBreak;
 str := str + 'to get the padlock without a warning.'                     + sLineBreak + sLineBreak;
 str := str + 'You can also do this any time later via menu:'             + sLineBreak;
 str := str + 'Apache > Apache SSL > Trust certificate in Windows';

 If us_MessageDlg('Trust HTTPS certificate?', str, mtConfirmation,[mbYes,mbNo],0) = mrYes Then
   us_trust_ssl_cert;
end;
{--- End us_offer_trust_ssl_cert_once ------------------------------}


{****************************************************************************
us_launch_edit_hosts_utility
 Launches the Uniform Server Windows hosts file utility (utils\EdHost.exe).
 Uses a seperate cmd window forces user to confirm changes to hosts file.
 EdHost asks Windows for administrator rights (UAC prompt): the hosts file
 is system protected. When the utility is switched off or missing the user
 is told why, instead of a menu click that does nothing.
=============================================================================}
procedure us_launch_edit_hosts_utility;
Var
 AProcess: TProcess;
begin
 If Not USC_EditHostsFileEnabled Then      // User has disabled Edit Windows hosts file
  begin
   us_MessageDlg('Edit Windows hosts file',
     'Editing the hosts file is switched off in this installation.'  + sLineBreak + sLineBreak +
     'To enable it, set EditHostsFileEnabled=True in section [HOSTS] of' + sLineBreak +
     USF_US_CONF_INI                                                  + sLineBreak +
     'and restart WinpachoController.', mtInformation, [mbOk], 0);
   Exit;
  end;

 If Not FileExists(USF_EDHOST_UTILITY) Then // Edit host utility EdHost.exe missing
  begin
   us_MessageDlg('Edit Windows hosts file',
     'The hosts file editor was not found:'                            + sLineBreak +
     USF_EDHOST_UTILITY                                                + sLineBreak + sLineBreak +
     'Restore utils\EdHost.exe from the winpacho package, or edit' + sLineBreak +
     us_hosts_file_path                                                + sLineBreak +
     'with an editor started as administrator.', mtWarning, [mbOk], 0);
   Exit;
  end;

 AProcess := TProcess.Create(nil); // Create process

 AProcess.Executable := 'cmd';                           // Executable to run
 AProcess.Parameters.Add('/T:0F');                       // Set background colour
 AProcess.Parameters.Add('/C');                          // Close on exit

 AProcess.Parameters.Add('title');                       // A title is required
 AProcess.Parameters.Add('Edit hosts');                  // Title

 AProcess.Parameters.Add('&&');                          // Start a new command line
 AProcess.Parameters.Add('start');                       // Command to run
 AProcess.Parameters.Add(USF_EDHOST_UTILITY);            // Run EdHost utility

 AProcess.Options := AProcess.Options + [poNoConsole];   // Set option no console
 AProcess.Execute;                                       // execute detatched process
 AProcess.Free;                                          // free memory
end;
{--- End us_launch_edit_hosts_utility ----------------------------------------}


{===================================================================
 us_hosts_file_path: Full path of the Windows hosts file.
====================================================================}
function us_hosts_file_path:string;
begin
 Result := SysUtils.GetEnvironmentVariable('SystemRoot')+'\System32\drivers\etc\hosts';
end;
{--- End us_hosts_file_path ----------------------------------------}


{===================================================================
 us_hosts_entry_regex: Matches an active (un-commented) hosts line
 mapping any IP to the given host name, e.g. "127.0.0.1  app.test".
====================================================================}
function us_hosts_entry_regex(host:string):string;
begin
 Result := '^\s*[0-9a-fA-F\.:]+\s+'+QuoteRegExprMetaChars(host)+'(\s|$)';
end;
{--- End us_hosts_entry_regex --------------------------------------}


{===================================================================
 us_hosts_has_entry: True when the hosts file already resolves the
 given host name (reading needs no administrator rights).
====================================================================}
function us_hosts_has_entry(host:string):boolean;
var
  sList :TStringList;
  re    :TRegExpr;
  i     :integer;
  line  :string;
begin
 Result := False;
 If Not FileExists(us_hosts_file_path) Then Exit;
 sList := TStringList.Create;
 re    := TRegExpr.Create;
 try
   re.Expression := us_hosts_entry_regex(host);
   re.ModifierI  := True;
   sList.LoadFromFile(us_hosts_file_path);
   for i:=0 to sList.Count-1 do
     begin
       line := Trim(sList[i]);
       If (line<>'') and (line[1]<>'#') and re.Exec(sList[i]) Then
         begin
           Result := True;
           Break;
         end;
     end;
 finally
   re.Free;
   sList.Free;
 end;
end;
{--- End us_hosts_has_entry ----------------------------------------}


{===================================================================
 us_write_hosts_file: Save the new hosts file content.
 Direct write works when the controller runs elevated; otherwise the
 content is staged in a temp file and copied over the hosts file by
 an elevated one-shot cmd (Windows shows the UAC prompt).
====================================================================}
function us_write_hosts_file(sList:TStringList):boolean;
var
  tmpPath      :string;
begin
 Result := False;

 //--Direct write: succeeds when running with administrator rights
 try
   sList.SaveToFile(us_hosts_file_path);
   Result := True;
   Exit;
 except
   //Access denied - continue with the elevated copy below
 end;

 //--Stage content in a temp file, then copy it elevated
 tmpPath := SysUtils.GetTempDir + 'us_hosts_new.txt';
 try
   sList.SaveToFile(tmpPath);
 except
   Exit;                                     // Cannot even stage: give up
 end;

 //--Copy attempted when the UAC prompt was accepted; caller verifies the result
 Result := us_run_elevated('cmd.exe',
                           '/c copy /y "'+tmpPath+'" "'+us_hosts_file_path+'"',
                           SysUtils.GetTempDir, 120000);

 SysUtils.DeleteFile(tmpPath);               // Best effort clean-up
end;
{--- End us_write_hosts_file ---------------------------------------}


//=== Windows services ===

{===================================================================
 us_run_elevated: Run a program through the UAC prompt (verb "runas")
 hidden, and wait up to wait_ms for it to finish.
 Returns false when the user declines the UAC prompt or the program
 cannot be started. A true result only means the program ran; the
 caller checks whether it achieved anything.
====================================================================}
function us_run_elevated(const exe, params, work_dir:string; wait_ms:DWORD):boolean;
var
  sei          :TShellExecuteInfoW;
  verbW, fileW :WideString;
  parW, dirW   :WideString;
begin
 Result := False;

 verbW := 'runas';
 fileW := WideString(exe);
 parW  := WideString(params);
 dirW  := WideString(work_dir);

 FillChar(sei, SizeOf(sei), 0);
 sei.cbSize       := SizeOf(sei);
 sei.fMask        := SEE_MASK_NOCLOSEPROCESS;
 sei.lpVerb       := PWideChar(verbW);
 sei.lpFile       := PWideChar(fileW);
 sei.lpParameters := PWideChar(parW);
 sei.lpDirectory  := PWideChar(dirW);
 sei.nShow        := SW_HIDE;

 If ShellExecuteExW(@sei) Then               // False when the UAC prompt is declined
  begin
    If sei.hProcess <> 0 Then
     begin
       WaitForSingleObject(sei.hProcess, wait_ms); // Allow time for the UAC prompt
       CloseHandle(sei.hProcess);
     end;
    Result := True;
  end;
end;
{--- End us_run_elevated -------------------------------------------}


{===================================================================
 us_control_windows_service: Start or stop one of the services that
 WinpachoService installed (us_apache_<n>, us_mysql_<n>).
 The controller runs without administrator rights, so the request
 goes through sc.exe with a UAC prompt; afterwards the service state
 is polled until it matches or the safety timer runs out.
 Returns true when the service reached the requested state.
 Every failure is explained to the user, including the next step.
====================================================================}
function us_control_windows_service(const service_name:string; start:boolean):boolean;
var
  action      :string;   // sc.exe verb
  saftey_loop :integer;  // Seconds waited
  max_wait    :integer;  // Seconds before giving up
begin
 Result := False;

 If not us_ServiceInstalled(service_name) Then
  begin
    us_MessageDlg('Windows service',
      'The service "'+service_name+'" is not installed.'+ sLineBreak + sLineBreak +
      'Install it via Extra > Run Apache/'+US_MYMAR_TXT+' as Windows service.',
      mtInformation,[mbOk],0);
    Exit;
  end;

 If start Then
  begin
    action   := 'start';
    max_wait := USC_AP_StartSafetyTime;    // Same budget as a normal program start
  end
 Else
  begin
    action   := 'stop';
    max_wait := USC_AP_StopSafetyTime;
  end;
 If max_wait < 15 Then max_wait := 15;      // Never give up before Windows has had a fair chance

 //--Ask Windows (UAC) - the whole command runs hidden
 If not us_run_elevated('sc.exe', action + ' "' + service_name + '"', UniConPath, 120000) Then
  begin
    us_MessageDlg('Windows service',
      'Windows did not allow the service to be '+ action +'ed.'+ sLineBreak + sLineBreak +
      'The administrator prompt was declined or blocked.'+ sLineBreak +
      'Try again and confirm the prompt, or use Extra > Run Apache/'+US_MYMAR_TXT+' as Windows service.',
      mtWarning,[mbOk],0);
    Exit;
  end;

 //--Wait for the service to reach the requested state
 saftey_loop := 0;
 While us_IsServiceRunning(service_name) <> start do
  begin
    Sleep(1000);
    Application.ProcessMessages;                 // Keep the window responsive
    Inc(saftey_loop);
    If saftey_loop > max_wait Then Break;
  end;

 Result := (us_IsServiceRunning(service_name) = start);

 If not Result Then
   us_MessageDlg('Windows service',
     'The service "'+service_name+'" did not '+ action +' within '+ IntToStr(max_wait) +' seconds.'+ sLineBreak + sLineBreak +
     'Check the server error log for the cause, or manage the service via'+ sLineBreak +
     'Extra > Run Apache/'+US_MYMAR_TXT+' as Windows service (or services.msc).',
     mtWarning,[mbOk],0);
end;
{--- End us_control_windows_service --------------------------------}


{****************************************************************************
us_add_to_hosts_file
 Add domain (e.g fred.com) to the Windows hosts file, mapped to 127.0.0.1.

 The entry is written directly by the controller (the former hand-off to the
 interactive EdHost utility silently added nothing - EdHost has no command
 line interface). Already-resolvable names are left untouched, and the
 result is verified: if the entry is still missing afterwards the user is
 told what failed, what the consequence is and how to fix it manually.
=============================================================================}
procedure us_add_to_hosts_file(host:string);
var
  hosts :TStringList;
begin
 hosts := TStringList.Create;
 try
   hosts.Add(host);
   us_add_many_to_hosts_file(hosts);
 finally
   hosts.Free;
 end;
end;

{ Several hosts in one write - the Vhost import would otherwise raise one
  UAC prompt per host. }
procedure us_add_many_to_hosts_file(hosts:TStrings);
var
  sList, added, missing :TStringList;
  i     :integer;
  str   :string;
begin
 If Not USC_EditHostsFileEnabled Then Exit;   // User disabled hosts file editing

 added   := TStringList.Create;
 missing := TStringList.Create;
 sList   := TStringList.Create;
 try
   for i:=0 to hosts.Count-1 do
     If us_is_valid_hostname(hosts[i])                 // Never write invalid names
        and Not us_hosts_has_entry(hosts[i])           // Already resolves - nothing to do
        and (added.IndexOf(hosts[i]) < 0) Then
       added.Add(hosts[i]);
   If added.Count = 0 Then Exit;

   If FileExists(us_hosts_file_path) Then
     sList.LoadFromFile(us_hosts_file_path);
   for i:=0 to added.Count-1 do
     sList.Add('127.0.0.1'+#9+added[i]+#9+'# winpacho vhost');
   us_write_hosts_file(sList);

   //--Verify: without the entry the host name will not resolve in a browser
   for i:=0 to added.Count-1 do
     If Not us_hosts_has_entry(added[i]) Then missing.Add(added[i]);
   If missing.Count = 0 Then Exit;

   str :=       'The Windows hosts file entries for these names could not be' + sLineBreak;
   str := str + 'written - this needs administrator rights and the Windows'   + sLineBreak;
   str := str + 'prompt may have been declined:'                              + sLineBreak;
   for i:=0 to missing.Count-1 do str := str + '   ' + missing[i]            + sLineBreak;
   str := str + sLineBreak + 'Without an entry http://<name> will not resolve.' + sLineBreak + sLineBreak;
   str := str + 'Fix: add one line per name to '+us_hosts_file_path+','     + sLineBreak;
   str := str + 'e.g. 127.0.0.1   '+missing[0]                               + sLineBreak;
   str := str + 'or use menu: Extra > Edit Win hosts file.';
   us_MessageDlg('Hosts file entry missing', str, mtWarning,[mbOk],0);
 finally
   sList.Free;
   missing.Free;
   added.Free;
 end;
end;
{--- End us_add_to_hosts_file ------------------------------------------------}

{****************************************************************************
us_delete_from_hosts_file
 Delete domain (e.g fred.com) from the Windows hosts file.
 Direct rewrite by the controller (see us_add_to_hosts_file); verified,
 with a manual-fix hint when the entry could not be removed.
=============================================================================}
procedure us_delete_from_hosts_file(host:string);
var
  sList   :TStringList;
  re      :TRegExpr;
  i       :integer;
  line    :string;
  changed :boolean;
  str     :string;
begin
 If Not USC_EditHostsFileEnabled Then Exit;   // User disabled hosts file editing
 If Not FileExists(us_hosts_file_path) Then Exit;

 sList   := TStringList.Create;
 re      := TRegExpr.Create;
 changed := False;
 try
   re.Expression := us_hosts_entry_regex(host);
   re.ModifierI  := True;
   sList.LoadFromFile(us_hosts_file_path);
   for i:=sList.Count-1 downto 0 do
     begin
       line := Trim(sList[i]);
       If (line<>'') and (line[1]<>'#') and re.Exec(sList[i]) Then
         begin
           sList.Delete(i);
           changed := True;
         end;
     end;
   If changed Then us_write_hosts_file(sList);
 finally
   re.Free;
   sList.Free;
 end;

 //--Verify removal; explain the manual way when it failed
 If us_hosts_has_entry(host) Then
  begin
    str :=       'The Windows hosts file entry for "'+host+'" could not be'  + sLineBreak;
    str := str + 'removed - this needs administrator rights and the Windows' + sLineBreak;
    str := str + 'prompt may have been declined.'                            + sLineBreak + sLineBreak;
    str := str + 'Remove the line containing "'+host+'" from'                + sLineBreak;
    str := str + us_hosts_file_path                                          + sLineBreak;
    str := str + 'or use menu: Extra > Edit Win hosts file.';
    us_MessageDlg('Hosts file entry still present', str, mtWarning,[mbOk],0);
  end;
end;
{--- End us_delete_from_hosts_file -------------------------------------------}


//--END----
end.

