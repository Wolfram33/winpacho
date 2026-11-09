unit vhost_config;

{#############################################################################
'# Name: vhost_config.pas
'# Vhost configuration shared by "Create Apache Vhost" and the Vhost
'# export/import. The export saves host name + document root of every
'# vhost to a text file outside the installation; the import rebuilds the
'# vhosts from it in a new winpacho version (blocks from the current
'# template, hosts file, PAC file and certificate in one go).
'#############################################################################}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazFileUtils, FileUtil, Dialogs, Controls, RegExpr,
  default_config_vars,
  us_common_procedures,
  us_common_functions;

function  us_enable_vhost_include: boolean;              // Activate the vhosts Include in httpd.conf
function  us_vhost_include_warning: string;              // What to do when that failed
procedure us_vhost_portable_conf(const folder_name:string;
            out doc_root, dir_path, folder_path:string);  // Config values for a folder under vhosts\
function  us_seed_portable_vhost_folder(const folder_path:string): boolean; // Create folder + .htaccess/favicon
function  us_add_vhost_block(In_DocRoot, In_DirPath, In_ServerName:string): boolean; // http + https block
procedure us_offer_vhost_cert_trust(const intro:string); // Ask to trust the rebuilt certificate
function  us_read_vhosts(out_list:TStrings): boolean;    // User vhosts as host=DocumentRoot (False: unreadable)
function  us_resolve_vhost_root(root:string; out doc_root, dir_path, folder_path, reason:string): boolean; // List folder -> config values
procedure us_export_vhosts;                              // Menu: Export Vhosts
procedure us_import_vhosts;                              // Menu: Import Vhosts

implementation

const
  VHOST_PORTABLE_PREFIX = '${US_ROOTF}/vhosts/';   // DocumentRoot of a portable vhost
  VHOST_EXPORT_FILE     = 'winpacho-vhosts.txt';
  VHOST_LIST_FILTER     = 'winpacho Vhost list (*.txt)|*.txt|All files (*.*)|*.*';
  MAX_IMPORT_LINES      = 5000;  // A real list is far shorter: larger means a wrong file
  MAX_LISTED            = 15;    // Names shown per list in a message box
  // Same rule as valid_server_name in "Create Apache Vhost": dot-separated
  // labels of letters, digits and inner hyphens, ending in a 2-63 letter TLD
  HOST_NAME_PATTERN     = '^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$';

{ Message for a locked or unreadable httpd-vhosts.conf }
procedure show_vhost_file_error(const caption:string);
begin
  us_MessageDlg(caption,
    'The Vhost configuration could not be read or written:' + sLineBreak +
    USF_APACHE_VHOST_CNF + sLineBreak + sLineBreak +
    'Close any editor that has it open, check that it is not read-only,' + sLineBreak +
    'then try again.', mtError,[mbOk],0);
end;

{===============================================================
 httpd.conf: enable the "Include conf/extra/httpd-vhosts.conf" line
----------------------------------------------------------------}
function us_enable_vhost_include: boolean;
var
  sList :TStringList;
  i     :integer;
begin
  Result := False;
  If Not FileExists(USF_APACHE_CNF) Then Exit;
  sList := TStringList.Create;
  try
    try
      sList.LoadFromFile(USF_APACHE_CNF);
      Result := True;                    // No commented-out Include: nothing to switch on
      for i:=0 to sList.Count-1 do
        If (sList[i]<>'') and ExecRegExpr('^\s*#\s*Include\s*conf/extra/httpd-vhosts.conf', sList[i]) Then
          begin
            sList[i] := 'Include conf/extra/httpd-vhosts.conf';
            Result := FileIsWritable(USF_APACHE_CNF);
            If Result Then sList.SaveToFile(USF_APACHE_CNF);
            Break;
          end;
    except
      Result := False;                   // Locked or unreadable: caller tells the user
    end;
  finally
    sList.Free;
  end;
end;

function us_vhost_include_warning: string;
begin
  Result := 'Warning: httpd.conf could not be changed, so Apache may not load the' + sLineBreak +
            'Vhosts. Make sure this line in ' + USF_APACHE_CNF + sLineBreak +
            'has no # in front:  Include conf/extra/httpd-vhosts.conf';
end;

{ Portable vhost: folder under vhosts\, config keeps the US_ROOTF/HOME
  tokens so it moves with the server folder. }
procedure us_vhost_portable_conf(const folder_name:string; out doc_root, dir_path, folder_path:string);
begin
  doc_root    := VHOST_PORTABLE_PREFIX + folder_name;
  dir_path    := '${HOME}\vhosts\' + folder_name;
  folder_path := UniConPath + '\vhosts\' + folder_name;
end;

{ False when the folder could not be created (the helper files are optional) }
function us_seed_portable_vhost_folder(const folder_path:string): boolean;
begin
  If Not DirectoryExists(folder_path) Then ForceDirectories(folder_path);
  Result := DirectoryExists(folder_path);
  If Not Result Then Exit;
  If Not FileExists(folder_path+'\.htaccess')   Then CopyFile(USF_VHOST_HTACCESS, folder_path+'\.htaccess');
  If Not FileExists(folder_path+'\favicon.ico') Then CopyFile(USF_VHOST_ICO,      folder_path+'\favicon.ico');
end;

{===============================================================
Add Vhost block to httpd-vhosts.conf (nothing happens when a block
with this ServerName exists already):
  In_DocRoot - DocumentRoot value (portable US_ROOTF token + /vhosts/name or an
               absolute path like D:/projects/app)
  In_DirPath - matching <Directory> path (Windows-style backslashes)
----------------------------------------------------------------}
function us_add_vhost_block(In_DocRoot, In_DirPath, In_ServerName:string): boolean;
var
 sList :TStringList;
 i     :integer;
begin
  Result := False;
  If Not FileExists(USF_APACHE_VHOST_CNF) Then Exit;
  sList := TStringList.Create;
  try
  try
   sList.LoadFromFile(USF_APACHE_VHOST_CNF);

   //-- Section already present? (exact name: app.test must not match app.testing)
   for i:=0 to sList.Count-1 do
     If (sList[i]<>'') and ExecRegExpr('^\s*ServerName\s+'+QuoteRegExprMetaChars(In_ServerName)+'(\s|$)', sList[i]) Then
       begin Result := True; Exit; end;

   sList.Add('');
   sList.Add('<VirtualHost *:${AP_PORT}>');
   sList.Add(' ServerAdmin webmaster@'+In_ServerName);
   sList.Add(' DocumentRoot "'+In_DocRoot+'"');  // quoted: the path may contain spaces
   sList.Add(' ServerName '+ In_ServerName);
   sList.Add(' ServerAlias www.'+In_ServerName+ ' *.'+In_ServerName);
   //-- One rotated error log per vhost, shared by the http and the https
   //   block below (Apache runs one writer per identical ErrorLog pipe,
   //   but one per CustomLog line - so the vhost gets no access log of
   //   its own: its requests go to logs/access.log tagged host:port,
   //   vhost_combined format). Same scheme as scripts/tune-server-config.ps1;
   //   rotatelogs_z.exe is the windowless copy us_prepare_rotatelogs
   //   creates at Apache start.
   sList.Add(' ErrorLog "|bin/rotatelogs_z.exe -n 5 -D -L logs/'+In_ServerName+'-error.log logs/rotated/'+In_ServerName+'-error.log 10M"');
   sList.Add(' # Access lines of this host go to logs/access.log, tagged "host:port" (vhost_combined)');
   sList.Add(' <Directory "'+In_DirPath+'">');
   sList.Add('   Options Indexes Includes FollowSymLinks');
   sList.Add('   AllowOverride All   ');
   sList.Add('   Require all granted ');
   sList.Add(' </Directory> ');
   sList.Add('</VirtualHost> ');
   sList.Add('');
   //-- Matching SSL vhost on the SSL port (https://<domain>).
   //   Wrapped in IfModule so the file also parses when SSL is disabled.
   //   Uses the shared server certificate, which the controller rebuilds
   //   to cover every vhost domain (subjectAltName).
   sList.Add('<IfModule ssl_module>');
   sList.Add('<VirtualHost *:${AP_SSL_PORT}>');
   sList.Add(' ServerAdmin webmaster@'+In_ServerName);
   sList.Add(' DocumentRoot "'+In_DocRoot+'"');  // quoted: the path may contain spaces
   sList.Add(' ServerName '+ In_ServerName);
   sList.Add(' ServerAlias www.'+In_ServerName+ ' *.'+In_ServerName);
   sList.Add(' ErrorLog "|bin/rotatelogs_z.exe -n 5 -D -L logs/'+In_ServerName+'-error.log logs/rotated/'+In_ServerName+'-error.log 10M"');
   sList.Add(' # Access lines of this host go to logs/access.log, tagged "host:port" (vhost_combined)');
   sList.Add(' SSLEngine on');
   sList.Add(' SSLCertificateFile "${US_ROOTF}/core/apache2/server_certs/server.crt"');
   sList.Add(' SSLCertificateKeyFile "${US_ROOTF}/core/apache2/server_certs/server.key"');
   sList.Add(' <Directory "'+In_DirPath+'">');
   sList.Add('   Options Indexes Includes FollowSymLinks');
   sList.Add('   AllowOverride All   ');
   sList.Add('   Require all granted ');
   sList.Add(' </Directory> ');
   sList.Add('</VirtualHost>');
   sList.Add('</IfModule>');
   sList.Add('');

   //== Clean file list: no blank lines except one above each Vhost block
   for i:=sList.Count-1 downto 0 do
     If sList[i]='' Then sList.Delete(i);
   for i:=sList.Count-1 downto 0 do
     If (sList[i]<>'') and ExecRegExpr('^\s*<VirtualHost\s', sList[i]) Then
       sList.Insert(i,'');

   Result := FileIsWritable(USF_APACHE_VHOST_CNF);
   If Result Then sList.SaveToFile(USF_APACHE_VHOST_CNF);
  except
   Result := False;                      // Locked or unreadable: caller tells the user
  end;
  finally
   sList.Free;
  end;
end;

{ The certificate was rebuilt for new vhost domains - the previous trust no
  longer covers it, browsers would warn again. }
procedure us_offer_vhost_cert_trust(const intro:string);
begin
  If us_MessageDlg('Vhosts created - trust certificate?',
    intro + sLineBreak + sLineBreak +
    'HTTPS is set up: the server certificate was rebuilt so it also' + sLineBreak +
    'covers the new domains. Browsers only drop their warning after the' + sLineBreak +
    'rebuilt certificate is trusted again.' + sLineBreak + sLineBreak +
    'Trust the rebuilt certificate in Windows now?' + sLineBreak +
    '(Afterwards restart your browser completely. Also available' + sLineBreak +
    'later: Apache > Apache SSL > Trust certificate in Windows.)',
    mtConfirmation,[mbYes,mbNo],0) = mrYes Then
      us_trust_ssl_cert;
end;

{===============================================================
 Read the user vhosts from httpd-vhosts.conf as "host=DocumentRoot"
 (each host once - it has an http and an https block). The built-in
 default vhosts are left out: every installation brings its own.
----------------------------------------------------------------}
function us_read_vhosts(out_list:TStrings): boolean;
var
  sList          :TStringList;
  reHost, reDoc  :TRegExpr;
  reVH, reVHend  :TRegExpr;
  i              :integer;
  host, doc      :string;
begin
  out_list.Clear;
  Result := True;                                   // No file yet = no vhosts
  If Not FileExists(USF_APACHE_VHOST_CNF) Then Exit;
  sList  := TStringList.Create;
  reHost := TRegExpr.Create('^\s*ServerName\s+(\S+)');
  reDoc  := TRegExpr.Create('^\s*DocumentRoot\s+(.+?)\s*$');
  reVH   := TRegExpr.Create('^\s*<VirtualHost\s');
  reVHend:= TRegExpr.Create('^\s*</VirtualHost>');
  try
    try
      sList.LoadFromFile(USF_APACHE_VHOST_CNF);
    except
      Result := False;                              // Locked or unreadable
      Exit;
    end;
    host := ''; doc := '';
    for i:=0 to sList.Count-1 do
      begin
        If reVH.Exec(sList[i]) Then begin host := ''; doc := ''; end
        Else If reHost.Exec(sList[i]) Then host := StringReplace(reHost.Match[1],'"','',[rfReplaceAll])
        Else If reDoc.Exec(sList[i])  Then doc  := StringReplace(reDoc.Match[1], '"','',[rfReplaceAll])
        Else If reVHend.Exec(sList[i]) Then
          begin
            If (host <> '') and (doc <> '')
               and (host <> '${US_SERVERNAME}') and (host <> UENV_US_SERVERNAME)
               and (out_list.IndexOfName(host) < 0) Then
              out_list.Add(host + '=' + doc);
            host := ''; doc := '';
          end;
      end;
  finally
    reVHend.Free; reVH.Free; reDoc.Free; reHost.Free;
    sList.Free;
  end;
end;

{ Up to MAX_LISTED lines "   item", then "   ... and N more" }
function list_text(list:TStrings): string;
var i:integer;
begin
  Result := '';
  for i:=0 to list.Count-1 do
    begin
      If i = MAX_LISTED Then
        begin
          Result := Result + '   ... and ' + IntToStr(list.Count - MAX_LISTED) + ' more' + sLineBreak;
          Break;
        end;
      Result := Result + '   ' + list[i] + sLineBreak;
    end;
end;

{===============================================================
 Turn the document root of a list line into config values.
 Accepts the portable form (VHOST_PORTABLE_PREFIX + name) and full paths
 (D:/projects/app, D:\projects\app, \\server\share\app). An external
 folder must exist - the same rule as in "Create Apache Vhost".
 folder_path is the portable folder ('' for an external one).
----------------------------------------------------------------}
function us_resolve_vhost_root(root:string; out doc_root, dir_path, folder_path, reason:string): boolean;
var
  folder, path :string;
  i            :integer;
begin
  Result := False;
  doc_root := ''; dir_path := ''; folder_path := ''; reason := '';
  root := Trim(StringReplace(root,'"','',[rfReplaceAll]));

  for i:=1 to Length(root) do
    If root[i] < ' ' Then begin reason := 'folder contains control characters'; Exit; end;

  If LowerCase(Copy(root,1,Length(VHOST_PORTABLE_PREFIX))) = LowerCase(VHOST_PORTABLE_PREFIX) Then
    begin
      folder := ExcludeTrailingPathDelimiter(StringReplace(Copy(root, Length(VHOST_PORTABLE_PREFIX)+1, MaxInt),'/','\',[rfReplaceAll]));
      If Not us_is_valid_root_folder_name(folder) Then
        begin reason := 'portable folder name "'+folder+'" not allowed (letters, digits, - and _ only)'; Exit; end;
      us_vhost_portable_conf(folder, doc_root, dir_path, folder_path);
      Result := True;
      Exit;
    end;

  path := ExcludeTrailingPathDelimiter(StringReplace(root,'/','\',[rfReplaceAll]));
  If Not (((Length(path) >= 3) and (path[2] = ':') and (path[3] = '\')) or (Copy(path,1,2) = '\\')) Then
    begin reason := 'no full folder path (expected e.g. D:\projects\app)'; Exit; end;
  If Not DirectoryExists(path) Then
    begin reason := 'folder not found: ' + path; Exit; end;

  doc_root := StringReplace(path,'\','/',[rfReplaceAll]);  // forward slashes for DocumentRoot
  dir_path := path;                                        // backslashes for <Directory>
  Result   := True;
end;

{===============================================================
 Menu: Apache Vhosts > Export Vhosts
----------------------------------------------------------------}
procedure us_export_vhosts;
var
  vhosts, outFile, portable :TStringList;
  dlg  :TSaveDialog;
  i    :integer;
  str  :string;
begin
  vhosts   := TStringList.Create;
  outFile  := TStringList.Create;
  portable := TStringList.Create;
  dlg      := TSaveDialog.Create(nil);
  try
    If Not us_read_vhosts(vhosts) Then begin show_vhost_file_error('Export Vhosts'); Exit; end;
    If vhosts.Count = 0 Then
      begin
        us_MessageDlg('Export Vhosts',
          'There are no Vhosts to export yet.' + sLineBreak + sLineBreak +
          'Vhosts made with Apache Vhosts > Create Apache Vhost are stored in' + sLineBreak +
          USF_APACHE_VHOST_CNF, mtInformation,[mbOk],0);
        Exit;
      end;

    dlg.Title      := 'Export Vhosts - save the list OUTSIDE the winpacho folder';
    dlg.Filter     := VHOST_LIST_FILTER;
    dlg.DefaultExt := 'txt';
    dlg.FileName   := VHOST_EXPORT_FILE;
    dlg.InitialDir := GetUserDir;    // Not the installation that a new version replaces
    dlg.Options    := dlg.Options + [ofOverwritePrompt];
    If Not dlg.Execute Then Exit;

    outFile.Add('# winpacho Vhost list - exported ' + FormatDateTime('yyyy-mm-dd hh:nn', Now) +
                ' from winpacho ' + US_RELOAD_VERSION);
    outFile.Add('# Restore it in any winpacho version: Apache > Apache Vhosts > Import Vhosts.');
    outFile.Add('# One Vhost per line: host name, TAB, document root folder. Lines starting');
    outFile.Add('# with # are ignored. Only name and folder are stored - hand edits inside');
    outFile.Add('# httpd-vhosts.conf are not; the import writes fresh blocks.');
    outFile.Add('# ${US_ROOTF}/vhosts/<name> is a folder inside the winpacho folder: its files');
    outFile.Add('# are NOT in this list - copy that vhosts\<name> folder yourself.');
    for i:=0 to vhosts.Count-1 do
      begin
        outFile.Add(vhosts.Names[i] + #9 + vhosts.ValueFromIndex[i]);
        If LowerCase(Copy(vhosts.ValueFromIndex[i],1,Length(VHOST_PORTABLE_PREFIX))) = LowerCase(VHOST_PORTABLE_PREFIX) Then
          portable.Add(vhosts.Names[i] + '  ->  ' + US_VHOSTS + '\' + Copy(vhosts.ValueFromIndex[i], Length(VHOST_PORTABLE_PREFIX)+1, MaxInt));
      end;

    try
      outFile.SaveToFile(dlg.FileName);
    except
      on E: Exception do
        begin
          us_MessageDlg('Export Vhosts',
            'The list could not be saved:' + sLineBreak + dlg.FileName + sLineBreak +
            '(' + E.Message + ')' + sLineBreak + sLineBreak +
            'Choose a folder you can write to, e.g. Documents.', mtError,[mbOk],0);
          Exit;
        end;
    end;

    str := IntToStr(vhosts.Count) + ' Vhost(s) saved to' + sLineBreak + dlg.FileName + sLineBreak + sLineBreak +
           'Next step in a new winpacho version: Apache > Apache Vhosts >' + sLineBreak +
           'Import Vhosts and choose this file.';
    If LowerCase(Copy(ExpandFileName(dlg.FileName),1,Length(UniConPath)+1)) = LowerCase(UniConPath+'\') Then
      str := str + sLineBreak + sLineBreak +
             'Note: the file lies inside the winpacho folder. If you replace or' + sLineBreak +
             'delete that folder, the list goes with it - keep a copy elsewhere.';
    If portable.Count > 0 Then
      str := str + sLineBreak + sLineBreak +
             'These Vhosts use folders inside winpacho. Their files are not in the' + sLineBreak +
             'list - copy the folders to the new version''s vhosts folder:' + sLineBreak +
             list_text(portable);
    us_MessageDlg('Export Vhosts', str, mtInformation,[mbOk],0);
  finally
    dlg.Free;
    portable.Free;
    outFile.Free;
    vhosts.Free;
  end;
end;

{===============================================================
 Menu: Apache Vhosts > Import Vhosts
 Checks every line first, shows what will be created and what is
 skipped (and why), and only then changes anything.
----------------------------------------------------------------}
procedure us_import_vhosts;
var
  dlg                         :TOpenDialog;
  lines, existing, toCreate   :TStringList;
  skipped, names, emptyFolders:TStringList;
  preview                     :TStringList;   // "host  ->  folder" for the confirmation
  i, sp                       :integer;
  line, host, root, str       :string;
  doc_root, dir_path, folder_path, reason :string;
  include_ok                  :boolean;
  folder_was_missing          :boolean;
begin
  dlg          := TOpenDialog.Create(nil);
  lines        := TStringList.Create;
  existing     := TStringList.Create;
  toCreate     := TStringList.Create;   // host=root as in the file
  skipped      := TStringList.Create;   // "host: reason"
  names        := TStringList.Create;
  emptyFolders := TStringList.Create;
  preview      := TStringList.Create;
  try
    dlg.Title      := 'Import Vhosts - choose an exported Vhost list';
    dlg.Filter     := VHOST_LIST_FILTER;
    dlg.InitialDir := GetUserDir;
    dlg.Options    := dlg.Options + [ofFileMustExist];
    If Not dlg.Execute Then Exit;

    try
      lines.LoadFromFile(dlg.FileName);
    except
      on E: Exception do
        begin
          us_MessageDlg('Import Vhosts', 'The file could not be read:' + sLineBreak + dlg.FileName + sLineBreak +
            '(' + E.Message + ')', mtError,[mbOk],0);
          Exit;
        end;
    end;
    If lines.Count > MAX_IMPORT_LINES Then
      begin
        us_MessageDlg('Import Vhosts', 'This file has ' + IntToStr(lines.Count) + ' lines - that is not a Vhost list' + sLineBreak +
          '(Apache > Apache Vhosts > Export Vhosts writes one line per Vhost).', mtError,[mbOk],0);
        Exit;
      end;

    //== Check every line before anything is changed
    If Not us_read_vhosts(existing) Then begin show_vhost_file_error('Import Vhosts'); Exit; end;
    for i:=0 to lines.Count-1 do
      begin
        line := Trim(lines[i]);
        If (line = '') or (line[1] = '#') Then Continue;
        // A host name has no blanks: the first tab or space ends it
        sp := 1;
        While (sp <= Length(line)) and Not (line[sp] in [#9,' ']) Do Inc(sp);
        host := Copy(line, 1, sp-1);
        root := Trim(Copy(line, sp+1, MaxInt));

        If Not (us_is_valid_hostname(host) and ExecRegExpr(HOST_NAME_PATTERN, host)) Then
          skipped.Add(host + ': not a valid host name (e.g. app.test)')
        Else If (host = UENV_US_SERVERNAME) Then
          skipped.Add(host + ': reserved for the main server')
        Else If existing.IndexOfName(host) >= 0 Then
          skipped.Add(host + ': exists already')
        Else If toCreate.IndexOfName(host) >= 0 Then
          skipped.Add(host + ': listed twice in the file')
        Else If Not us_resolve_vhost_root(root, doc_root, dir_path, folder_path, reason) Then
          skipped.Add(host + ': ' + reason)
        Else
          begin
            toCreate.Add(host + '=' + root);
            preview.Add(host + '  ->  ' + root);
          end;
      end;

    If toCreate.Count = 0 Then
      begin
        str := 'Nothing to import from' + sLineBreak + dlg.FileName + sLineBreak;
        If skipped.Count > 0 Then
          str := str + sLineBreak + 'Skipped:' + sLineBreak + list_text(skipped)
        Else
          str := str + sLineBreak + 'The file lists no Vhosts (one line per Vhost: host name, TAB, folder).';
        us_MessageDlg('Import Vhosts', str, mtInformation,[mbOk],0);
        Exit;
      end;

    str := 'Create these ' + IntToStr(toCreate.Count) + ' Vhost(s)?' + sLineBreak + list_text(preview);
    If skipped.Count > 0 Then
      str := str + sLineBreak + 'Skipped:' + sLineBreak + list_text(skipped);
    str := str + sLineBreak +
           'Windows asks once for administrator permission (hosts file entries),' + sLineBreak +
           'and the server certificate is rebuilt to cover the new domains.';
    If us_MessageDlg('Import Vhosts', str, mtConfirmation,[mbYes,mbNo],0) <> mrYes Then Exit;

    //== Create (each step re-checked: the confirmation may have stayed open
    //   while a folder was moved or a network drive went away)
    include_ok := us_enable_vhost_include;
    for i:=0 to toCreate.Count-1 do
      begin
        host := toCreate.Names[i];
        If Not us_resolve_vhost_root(toCreate.ValueFromIndex[i], doc_root, dir_path, folder_path, reason) Then
          begin skipped.Add(host + ': ' + reason); Continue; end;
        If folder_path <> '' Then
          begin
            folder_was_missing := Not DirectoryExists(folder_path);
            If Not us_seed_portable_vhost_folder(folder_path) Then
              begin
                skipped.Add(host + ': folder could not be created: ' + folder_path);
                Continue;
              end;
            If folder_was_missing Then emptyFolders.Add(folder_path);
          end;
        If Not us_add_vhost_block(doc_root, dir_path, host) Then
          begin skipped.Add(host + ': could not be written to ' + ExtractFileName(USF_APACHE_VHOST_CNF)); Continue; end;
        us_add_to_pac_file(host);
        names.Add(host);
      end;

    If names.Count = 0 Then
      begin
        str := 'No Vhost was imported.' + sLineBreak + sLineBreak + list_text(skipped) + sLineBreak +
               'If the configuration file is the cause: close any editor that has' + sLineBreak +
               USF_APACHE_VHOST_CNF + sLineBreak + 'open and check that it is not read-only.';
        us_MessageDlg('Import Vhosts', str, mtError,[mbOk],0);
        Exit;
      end;
    us_add_many_to_hosts_file(names);   // One write - one UAC prompt

    us_regenerate_cert_for_all_vhosts;
    us_offer_vhost_cert_trust(IntToStr(names.Count) + ' Vhost(s) imported.');

    str := IntToStr(names.Count) + ' Vhost(s) imported:' + sLineBreak + list_text(names);
    If skipped.Count > 0 Then
      str := str + sLineBreak + 'Not imported:' + sLineBreak + list_text(skipped);
    If emptyFolders.Count > 0 Then
      str := str + sLineBreak +
             'These portable folders were created empty - copy your files from' + sLineBreak +
             'the vhosts folder of the old winpacho installation into them:' + sLineBreak +
             list_text(emptyFolders);
    If Not include_ok Then str := str + sLineBreak + us_vhost_include_warning + sLineBreak;
    str := str + sLineBreak + 'Restart Apache for the Vhosts to take effect.';
    us_MessageDlg('Import Vhosts', str, mtInformation,[mbOk],0);
  finally
    preview.Free;
    emptyFolders.Free;
    names.Free;
    skipped.Free;
    toCreate.Free;
    existing.Free;
    lines.Free;
    dlg.Free;
  end;
end;

end.
