unit us_db_engine;

{#############################################################################
'# Name: us_db_engine.pas
'# Switch between the two database engines the bundle ships (since 2.4.0).
'#
'# The active engine always sits in core\mysql: the controller, WinpachoService,
'# Adminer, the splash page and the scripts all expect it there. The other
'# engine waits complete - binaries, my.ini, data folder - in
'# core\db_standby\<engine> (mariadb or mysql). Switching swaps the two folders
'# by renaming them, so the engines never share a file: their data formats are
'# incompatible, and each keeps its own databases, users and root password.
'# The root password file htpasswd\mysql\passwd.txt belongs to the active
'# engine; the waiting one keeps its password in standby_root_password.txt
'# inside its folder.
'#############################################################################}

{$mode objfpc}{$H+}

interface

{ The engine that is not active (MySQL when MariaDB runs, and vice versa). }
function us_db_standby_engine: string;

{ Full path of the waiting place of AEngine, e.g. C:\winpacho\core\db_standby\mysql. }
function us_db_standby_folder(const AEngine: string): string;

{ True when AEngine waits complete in its standby folder. }
function us_db_engine_in_standby(const AEngine: string): Boolean;

{ Why the engines cannot be swapped right now, with the next step for the
  user - or '' when nothing stands in the way. }
function us_db_switch_blocker: string;

{ Swaps the active engine with the waiting one and reloads the engine
  settings (name, exe, password). Returns False with the reason in AMessage
  when nothing was changed (or, in one rare case, what to repair by hand).
  Returns True when the other engine is active now; AMessage is then empty
  or a warning about the root password file. }
function us_db_switch_engine(out AMessage: string): Boolean;

implementation

uses
  Windows, SysUtils, Classes,
  default_config_vars, us_common_functions, us_common_procedures;

const
  STANDBY_DIR           = '\core\db_standby';            // below UniConPath
  STANDBY_PWD_FILE      = 'standby_root_password.txt';   // in the standby folder
  DEFAULT_ROOT_PASSWORD = 'root';                        // password the engines ship with
  ENGINE_SERVER_EXE     = '\bin\mysqld_z.exe';           // server exe name of both modules

function us_db_standby_engine: string;
begin
  if US_MYMAR_TXT = DB_ENGINE_MYSQL then
    Result := DB_ENGINE_MARIADB
  else
    Result := DB_ENGINE_MYSQL;
end;

function us_db_standby_folder(const AEngine: string): string;
begin
  Result := UniConPath + STANDBY_DIR + '\' + LowerCase(AEngine);
end;

function us_db_engine_in_standby(const AEngine: string): Boolean;
begin
  Result := FileExists(us_db_standby_folder(AEngine) + ENGINE_SERVER_EXE);
end;

function us_db_switch_blocker: string;
var
  parking: string;
begin
  Result  := '';
  parking := us_db_standby_folder(US_MYMAR_TXT);
  if not us_db_engine_in_standby(us_db_standby_engine) then
    Result := us_db_standby_engine + ' is not part of this installation: the folder' + sLineBreak +
              us_db_standby_folder(us_db_standby_engine) + sLineBreak +
              'is missing or incomplete.' + sLineBreak + sLineBreak +
              'Bundles from winpacho 2.4.0 on ship both engines. To get it, extract' + sLineBreak +
              'the current bundle into a new, empty folder and copy its folder' + sLineBreak +
              'core\db_standby\' + LowerCase(us_db_standby_engine) + ' into the same place here.'
  else if not DirectoryExists(US_MYSQL) then
    Result := 'The folder of the active engine is missing:' + sLineBreak + US_MYSQL + sLineBreak + sLineBreak +
              'Without it there is nothing to put on standby. Copy core\mysql from the' + sLineBreak +
              'bundle back (or restore your own copy), then switch again.'
  else if MysqlRunning() then
    Result := US_MYMAR_TXT + ' is running. Its files are in use and cannot be moved.' + sLineBreak + sLineBreak +
              'Stop it first (button Stop ' + US_MYMAR_TXT + '), then switch again.'
  else if us_ServiceInstalled(USC_MYSQL_SERVICE_NAME) then
    Result := US_MYMAR_TXT + ' is installed as the Windows service ' + USC_MYSQL_SERVICE_NAME + '.' + sLineBreak +
              'The service is set up for the engine in core\mysql and its port.' + sLineBreak + sLineBreak +
              'Uninstall the service first (Extra > Run Apache/' + US_MYMAR_TXT + ' as Windows' + sLineBreak +
              'service), switch, then install the service again for the new engine.'
  else if DirectoryExists(parking) then
    Result := 'The folder' + sLineBreak + parking + sLineBreak +
              'already exists, so the active ' + US_MYMAR_TXT + ' cannot be put on standby there.' + sLineBreak + sLineBreak +
              'It is probably a leftover copy. Move it out of the server folder (or rename' + sLineBreak +
              'it), then switch again.';
end;

{ First line of a password file in APassword. False when the file cannot
  be read or holds no password - the caller decides what that means. }
function read_password_file(const AFile: string; out APassword: string): Boolean;
var
  lines: TStringList;
begin
  APassword := '';
  lines := TStringList.Create;
  try
    try
      lines.LoadFromFile(AFile);
      if lines.Count > 0 then APassword := Trim(lines[0]);
    except
      on E: Exception do APassword := '';   // reported through the False result
    end;
  finally
    lines.Free;
  end;
  Result := APassword <> '';
end;

{ Deletes a password copy that is no longer needed. '' when it is gone,
  otherwise a note for the user naming the file to delete by hand. }
function remove_password_copy(const AFile: string): string;
begin
  Result := '';
  if FileExists(AFile) and not DeleteFile(AFile) then
    Result := sLineBreak + sLineBreak +
              'Note: the file ' + AFile + sLineBreak +
              'could not be deleted (' + SysErrorMessage(GetLastError) + '). It holds a copy of a root' + sLineBreak +
              'password; delete it by hand.';
end;

{ The engine in core\mysql changed: everything the controller derived from it. }
procedure reload_engine_settings;
begin
  us_load_db_engine_config;              // US_MYMAR_TXT, start/stop texts
  MY_EXE_NAME := us_get_mysql_exe();     // server exe in core\mysql\bin
  MY_PWD      := us_get_mysql_password(); // root password of the new engine
end;

function us_db_switch_engine(out AMessage: string): Boolean;
var
  old_engine, new_engine : string;
  standby, parking       : string;   // folder of the new engine / place for the old one
  kept_pwd, new_pwd      : string;   // password files of the old and the new engine
  pwd, check, write_error: string;
  err                    : DWORD;
begin
  Result   := False;
  AMessage := us_db_switch_blocker;
  if AMessage <> '' then Exit;

  old_engine := US_MYMAR_TXT;
  new_engine := us_db_standby_engine;
  standby    := us_db_standby_folder(new_engine);
  parking    := us_db_standby_folder(old_engine);
  kept_pwd   := US_MYSQL + '\' + STANDBY_PWD_FILE;

  //1) The old engine takes its root password along
  if FileExists(USF_MYSQL_PWD) and not CopyFile(PChar(USF_MYSQL_PWD), PChar(kept_pwd), False) then
  begin
    AMessage := 'The root password of ' + old_engine + ' could not be saved to' + sLineBreak + kept_pwd + sLineBreak +
                '(' + SysErrorMessage(GetLastError) + ').' + sLineBreak + sLineBreak +
                'Nothing was changed. Make sure the server folder is writable, then try again.';
    Exit;
  end;

  //2) Old engine: core\mysql -> core\db_standby\<old>
  if not RenameFile(US_MYSQL, parking) then
  begin
    err := GetLastError;
    AMessage := 'The folder core\mysql could not be moved to' + sLineBreak + parking + sLineBreak +
                '(' + SysErrorMessage(err) + ').' + sLineBreak + sLineBreak +
                'Nothing was changed. Usually another program still has a file open in' + sLineBreak +
                'core\mysql: close Explorer windows, editors and consoles that show it,' + sLineBreak +
                'wait for a running virus scan, then try again.' + remove_password_copy(kept_pwd);
    Exit;
  end;

  //3) New engine: core\db_standby\<new> -> core\mysql
  if not RenameFile(standby, US_MYSQL) then
  begin
    err := GetLastError;
    if RenameFile(parking, US_MYSQL) then
      AMessage := new_engine + ' could not be moved from' + sLineBreak + standby + sLineBreak +
                  'to core\mysql (' + SysErrorMessage(err) + ').' + sLineBreak + sLineBreak +
                  'Nothing was changed, ' + old_engine + ' stays active. Close programs that show' + sLineBreak +
                  'files of that folder, then try again.' + remove_password_copy(kept_pwd)
    else
      AMessage := new_engine + ' could not be moved to core\mysql (' + SysErrorMessage(err) + '),' + sLineBreak +
                  'and moving ' + old_engine + ' back failed as well.' + sLineBreak + sLineBreak +
                  'Please repair this by hand before you start a database:' + sLineBreak +
                  'rename ' + parking + sLineBreak +
                  'back to ' + US_MYSQL + sLineBreak +
                  'and delete the file ' + STANDBY_PWD_FILE + ' inside it.';
    Exit;
  end;

  //4) Root password of the new engine: kept from its last time as active
  //   engine, or - no file - the one it ships with. A file that exists but
  //   cannot be read is the only copy of that password: it stays untouched.
  new_pwd := US_MYSQL + '\' + STANDBY_PWD_FILE;
  write_error := '';
  if not FileExists(new_pwd) then
    pwd := DEFAULT_ROOT_PASSWORD
  else if not read_password_file(new_pwd, pwd) then
  begin
    AMessage := 'Warning: the root password of ' + new_engine + ' could not be read from' + sLineBreak +
                new_pwd + '.' + sLineBreak +
                'The password file ' + USF_MYSQL_PWD + ' was not changed, so Adminer' + sLineBreak +
                'cannot log in by itself. Check that file (it must hold the password in' + sLineBreak +
                'its first line), or use ' + new_engine + ' > Restore default password (root).';
    reload_engine_settings;
    Result := True;
    Exit;
  end;
  //   Checked by reading it back: whether a failed write raises depends on
  //   the I/O-check setting the controller is compiled with
  try
    us_save_mysql_password(pwd);
  except
    on E: Exception do write_error := ' (' + E.Message + ')';
  end;
  if read_password_file(USF_MYSQL_PWD, check) and (check = pwd) then
    AMessage := remove_password_copy(new_pwd)
  else
    AMessage := 'Warning: the root password of ' + new_engine + ' could not be written to' + sLineBreak +
                USF_MYSQL_PWD + write_error + '.' + sLineBreak +
                'It is still in ' + new_pwd + '.' + sLineBreak +
                'Adminer cannot log in by itself until the file is right: make the server' + sLineBreak +
                'folder writable and set the password again with' + sLineBreak +
                new_engine + ' > Change ' + new_engine + ' root password.';

  reload_engine_settings;
  Result := True;
end;

end.
