unit vhost_create_form;

{#############################################################################
'# Name: vhost_create_form.pas
'# Developed By: The Uniform Server Development Team
'# Web: https://www.uniformserver.com
'#############################################################################}


{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazFileUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  default_config_vars,
  us_common_procedures,
  us_common_functions,
  vhost_config;

type

  { Tvhost_create }

  Tvhost_create = class(TForm)
    Btn_create_vhost: TButton;
    Btn_browse: TButton;
    Btn_help_server_name: TButton;
    Btn_help_root_folder: TButton;
    Edit_root_folder: TEdit;
    Edit_server_name: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    procedure Btn_create_vhostClick(Sender: TObject);
    procedure Btn_browseClick(Sender: TObject);
    procedure Btn_help_root_folderClick(Sender: TObject);
    procedure Btn_help_server_nameClick(Sender: TObject);
    procedure Edit_server_nameChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  vhost_create: Tvhost_create;

implementation

{$R *.lfm}

{ Tvhost_create }

procedure Tvhost_create.Btn_create_vhostClick(Sender: TObject);
{
Create new Vhost:
  Environment variable HOME=C:\winpacho
  Environment variable US_ROOTF=C:/winpacho
}
var
   new_ServerName  :string;      // New server name - Domain name
   new_root_input  :string;      // Raw text entered (folder name or full path)
   new_root_path   :string;      // Full document root path (Windows-style)
   doc_root_conf   :string;      // DocumentRoot value written to config
   dir_path_conf   :string;      // <Directory> path written to config
   is_external     :boolean;     // True when an absolute path was given
   valid_input     :boolean;     // Valid data from user
   tld_hint        :string;      // Browser hint for an unusual host name ending
   include_ok      :boolean;     // httpd.conf loads httpd-vhosts.conf
begin
   new_root_path   :='';
   doc_root_conf   :='';
   dir_path_conf   :='';
   new_root_input  := Trim(Edit_root_folder.Text); // Get root-folder/path entered
   new_ServerName  := Edit_server_name.Text;       // Get server name entered

   valid_input := True;    // Assume input is invalid

   // An absolute path (drive letter or UNC) means "use this folder directly"
   is_external := (Length(new_root_input) >= 2) and
                  ((new_root_input[2] = ':') or (Copy(new_root_input,1,2) = '\\'));

   //==Check data entered by user - Validate user input===

   If is_external Then
     begin
       new_root_path := ExcludeTrailingPathDelimiter(new_root_input);
       If Not DirectoryExists(new_root_path) Then
         begin
           valid_input := False;
           us_MessageDlg('Document Root',
             'The folder does not exist:' + sLineBreak + new_root_path + sLineBreak + sLineBreak +
             'Pick an existing folder with the Browse button.', mtError,[mbOk],0);
         end;
     end
   Else
     //--Check simple folder name (portable, created under vhosts\)
     If Not valid_root_folder_name(new_root_input,'Root folder') Then valid_input := False;

   //--Check domain name looks resonable e.g fred.com
   If Not valid_server_name(new_ServerName,'Server Name')       Then valid_input := False;

  //===Create full root path and config values
  If valid_input Then
    begin
      If is_external Then
        begin
          // Absolute path: reference it directly (forward slashes for
          // DocumentRoot, backslashes for the <Directory> match)
          doc_root_conf := StringReplace(new_root_path,'\','/',[rfReplaceAll]);
          dir_path_conf := StringReplace(new_root_path,'/','\',[rfReplaceAll]);
        end
      Else
        begin
          // Portable name under vhosts\  (keeps ${US_ROOTF}/${HOME} tokens)
          us_vhost_portable_conf(new_root_input, doc_root_conf, dir_path_conf, new_root_path);
        end;
    end;

  //###== Create new Vhost ==###
  If valid_input Then
   begin

    include_ok := us_enable_vhost_include;   // httpd.conf: activate the vhosts Include

    //== Portable mode only: create the folder under vhosts\ and seed it. An
    //   external folder is used as-is and its contents are left untouched.
    If (Not is_external) and (Not us_seed_portable_vhost_folder(new_root_path)) Then
      begin
        us_MessageDlg('Vhost not created',
          'The folder could not be created:' + sLineBreak + new_root_path + sLineBreak + sLineBreak +
          'Check that winpacho may write to its vhosts folder (not read-only,' + sLineBreak +
          'enough disk space), or pick an existing folder with Browse.', mtError,[mbOk],0);
        Exit;
      end;

     //===Add new block to Vhost configuration file
     If Not us_add_vhost_block(doc_root_conf,dir_path_conf,new_ServerName) Then
       begin
         us_MessageDlg('Vhost not created',
           'The Vhost could not be written to' + sLineBreak + USF_APACHE_VHOST_CNF + sLineBreak + sLineBreak +
           'Close any editor that has the file open, check that it is not' + sLineBreak +
           'read-only, then click Create again.', mtError,[mbOk],0);
         Exit;
       end;

     //===Add to Uniform Server PAC file
     us_add_to_pac_file(new_ServerName);                     // Add new host to PAC file

     //===Add to Windows hosts  file
     us_add_to_hosts_file(new_ServerName);                   // Add new host to hosts file

     //===Rebuild the server certificate so its subjectAltName covers this
     //   (and every other) vhost domain -> https://<domain> works too.
     us_regenerate_cert_for_all_vhosts;

     us_offer_vhost_cert_trust('New Vhost created for ' + new_ServerName + '.');

     tld_hint := us_vhost_tld_hint(new_ServerName);
     If tld_hint <> '' Then tld_hint := sLineBreak + sLineBreak + 'Note: ' + tld_hint;
     If Not include_ok Then tld_hint := tld_hint + sLineBreak + sLineBreak + us_vhost_include_warning;
     us_MessageDlg('Apache Info',
       'Restart Apache for the new Vhost to take effect.' + tld_hint,
       mtInformation,[mbOk],0) ; //Display information message
  end;//End valid_input

  If valid_input Then vhost_create.Close;

end;

procedure Tvhost_create.Btn_browseClick(Sender: TObject);
begin
  //Let the user pick any existing folder as the document root (alias mode)
  If DirectoryExists(Edit_root_folder.Text) Then
     SelectDirectoryDialog1.InitialDir := Edit_root_folder.Text
  Else
     SelectDirectoryDialog1.InitialDir := US_VHOSTS;

  If SelectDirectoryDialog1.Execute Then
     Edit_root_folder.Text := SelectDirectoryDialog1.FileName; // Store chosen full path
end;

procedure Tvhost_create.Btn_help_root_folderClick(Sender: TObject);
var
  str:string;
begin
    str :='';
    str := str + 'The document root is the folder Apache serves this'    + sLineBreak;
    str := str + 'host from. Two ways to set it:'                        + sLineBreak + sLineBreak;

    str := str + '1) A plain name, e.g. "app123":'                       + sLineBreak;
    str := str + '   A portable folder is created under'                 + sLineBreak;
    str := str + '   '+ US_VHOSTS+'\'                                     + sLineBreak;
    str := str + '   Moves with the server folder.'                      + sLineBreak + sLineBreak;

    str := str + '2) A full path, e.g. "D:\projects\app" (Browse...):'   + sLineBreak;
    str := str + '   Apache serves that folder directly - no need to'    + sLineBreak;
    str := str + '   copy your project into www or vhosts. The folder'   + sLineBreak;
    str := str + '   must already exist; its contents are left as they'  + sLineBreak;
    str := str + '   are. Note: an absolute path is not portable if you' + sLineBreak;
    str := str + '   move the installation to another PC.'               + sLineBreak + sLineBreak;

    str := str + 'You can always fine-tune the generated block in:'      + sLineBreak;
    str := str +  USF_APACHE_VHOST_CNF;

   us_MessageDlg('Document Root', str, mtInformation,[mbOk],0) ; //Display message
end;

procedure Tvhost_create.Btn_help_server_nameClick(Sender: TObject);
var
   str:string;
begin
  str := '';
  str := str + 'Host name is the address you type into' + sLineBreak;
  str := str + 'a browser, excluding the http:// part. ' + sLineBreak + sLineBreak;

  str := str + 'Example 1: ' + sLineBreak;
  str := str + 'Full Internet address: http://www.me.com' + sLineBreak;
  str := str + 'Host name: www.me.com' + sLineBreak + sLineBreak;

  str := str + 'Example 2' + sLineBreak;
  str := str + 'Full Internet address: http://uniserver.com' + sLineBreak;
  str := str + 'Host name: uniserver.com' + sLineBreak + sLineBreak;

  str := str + 'Choosing the ending:' + sLineBreak;
  str := str + 'Any ending is allowed, but browsers only treat names with' + sLineBreak;
  str := str + 'an ending they know as an address. An invented ending such' + sLineBreak;
  str := str + 'as .wolf is sent to the search engine instead. Reserved' + sLineBreak;
  str := str + 'endings that always work locally: .test, .localhost,' + sLineBreak;
  str := str + '.example. Avoid .dev and .app (browsers force HTTPS)' + sLineBreak;
  str := str + 'and .local (used by network discovery).' + sLineBreak;
  str := str + 'Any other ending still works when the address is typed' + sLineBreak;
  str := str + 'in full, e.g. http://buchhaltung.wolf/';

  us_MessageDlg('Server Name - Host Name', str, mtInformation,[mbOk],0); //Display message
end;

{ Live hint under the server-name field: explains why an ending may not
  behave as expected in the browser (rule: nothing fails without a reason). }
procedure Tvhost_create.Edit_server_nameChange(Sender: TObject);
var
  tld_hint:string;
begin
  tld_hint := us_vhost_tld_hint(Edit_server_name.Text);
  If tld_hint = '' Then
    Label4.Caption := 'e.g. app.test (endings .test, .localhost and .example always open directly in a browser)'
  Else
    Label4.Caption := tld_hint;
end;

procedure Tvhost_create.FormShow(Sender: TObject);
begin
   Edit_root_folder.Text :='';
   Edit_server_name.Text :='app.test';
   Edit_server_nameChange(nil);                    // Show default hint
end;

end.

