unit main_unit;

{#############################################################################
'# Name: main_unit.pas
'# Developed By: The Uniform Server Development Team
'# Web: https://www.uniformserver.com
'#############################################################################}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Menus,
  us_buttons,
  us_medallion,
  us_gui_style_dlg,
  us_db_engine,
  default_config_vars,
  us_common_procedures,
  us_common_functions,
  are_servers_runable,
  about_form,
  windows,
  us_server_state,
  server_cert_key_gen_form,
  vhost_create_form,
  vhost_delete_form,
  vhost_config,
  apache_basic_form,
  apache_modules_form,
  root_www_pass_access_form,
  root_ssl_pass_access_form,
  php_extensions_form,
  edit_php_basic_form,
  msmtp_php_mail_form,
  pc_win_startup_form,
  cron_form,
  command_line_start_up,
  mysql_db_create_delete_form,
  mysql_create_restricted_user_form,
  mysql_edit_restricted_user_form,
  mysql_database_backup_form,
  mysql_database_restore_form;

type

  { Control position in design units (DesignTimePPI), scaled to the
    current DPI when a window look is applied }
  TDesignBounds = record
    X, Y, W, H: Integer;
  end;
  TControlList = array of TControl;

  { TMain }

  TMain = class(TForm)
    Btn_opt2: TUsButton;
    Btn_mysql_console: TUsButton;
    Btn_opt1: TUsButton;
    Btn_opt3: TUsButton;
    Btn_start_apache: TUsButton;
    Btn_start_mysql: TUsButton;
    Btn_server_console: TUsButton;
    Btn_view_www: TUsButton;
    Btn_view_ssl: TUsButton;
    Btn_documentation: TUsButton;
    Btn_minimize: TUsButton;
    Btn_close: TUsButton;
    Tab_general: TUsButton;
    Tab_extra: TUsButton;
    Tab_apache: TUsButton;
    Tab_mysql: TUsButton;
    Tab_php: TUsButton;
    Tab_perl: TUsButton;
    Tab_about: TUsButton;
    Lbl_apache_utilities: TLabel;
    Lbl_mysql_utilities: TLabel;
    Lbl_version: TLabel;
    Img_logo: TImage;
    apache_img: TImage;
    menuImageList: TImageList;
    MenuItem1: TMenuItem;
    MenuItem17_spacer: TMenuItem;
    MenuItem18_spacer: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;

    MMSS_php70: TMenuItem;
    MMSS_php71: TMenuItem;
    MMSS_php72: TMenuItem;
    MMSS_php73: TMenuItem;
    MMSS_php74: TMenuItem;
    MMSS_php80: TMenuItem;
    MMSS_php81: TMenuItem;
    MMSS_php82: TMenuItem;
    MMSS_php83: TMenuItem;
    MMSS_php84: TMenuItem;
    MMSS_php85: TMenuItem;

    MMS_hosts: TMenuItem;
    MenuItem_service_spacer: TMenuItem;
    MMS_uniservice: TMenuItem;
    MMS_select_portable_browser: TMenuItem;
    MMS_select_default_browser: TMenuItem;
    MMS_pear_frontend: TMenuItem;
    MMS_mysql_database_backup: TMenuItem;
    MMS_mysql_database_restore: TMenuItem;
    MenuItem5: TMenuItem;
    MMS_mysql_edit_user: TMenuItem;
    MMS_mysql_create_user: TMenuItem;
    MMS_mysql_database_create_delete: TMenuItem;
    MMS_mysql_error_log: TMenuItem;
    MenuItem20_spacer: TMenuItem;
    MMS_cron: TMenuItem;
    MMS_pc_win_startup: TMenuItem;
    MMS_tray_icon: TMenuItem;
    MenuItem_tray_spacer: TMenuItem;
    MMS_gui_style: TMenuItem;
    MMSS_gui_classic: TMenuItem;
    MMSS_gui_modern: TMenuItem;
    MMS_clean_up: TMenuItem;
    MMSS_display_at_startup_page1: TMenuItem;
    MMSS_select_page_to_display1: TMenuItem;
    MenuItem_18_spacer: TMenuItem;
    MMSS_display_at_startup_page2: TMenuItem;
    MMSS_select_page_to_display2: TMenuItem;
    MMS_acache_start_up_pages: TMenuItem;
    MenuItem14_spacer: TMenuItem;
    MenuItem15_spacer: TMenuItem;
    MMS_php_mail_msmtp: TMenuItem;
    MMS_view_phpinfo: TMenuItem;
    MMSS_php_edit_basic: TMenuItem;
    MMSS_php_edit_modules: TMenuItem;
    MMS_php_basic_and_modules: TMenuItem;
    MMSS_folder_www_access_pass: TMenuItem;
    MenuItem13_spacer: TMenuItem;
    MMSS_folder_ssl_access_pass: TMenuItem;
    MMS_folder_access_passwords: TMenuItem;
    MMS_edit_uniformserver_pac: TMenuItem;
    MenuItem12_spacer: TMenuItem;
    MMSS_apache_error_log: TMenuItem;
    MMSS_apache_access_log: TMenuItem;
    MMSS_apache_ssl_error_log: TMenuItem;
    MenuItem11_spacer: TMenuItem;
    MMSS_apache_ssl_access_log: TMenuItem;
    MMSS_apache_delete_all_logs: TMenuItem;
    MMS_apache_logs: TMenuItem;
    MMSS_apache_edit_basic: TMenuItem;
    MMSS_apache_edit_modules: TMenuItem;
    MMS_apache_basic_and_modules: TMenuItem;
    MMSS_apache_edit_httpd_conf: TMenuItem;
    MMSS_apache_edit_ssl_conf: TMenuItem;
    MMS_apache_edit_configs: TMenuItem;
    MenuItem10_spacer: TMenuItem;
    MMS_apache_vhosts: TMenuItem;
    MMSS_apache_delete_vhost: TMenuItem;
    MMSS_apache_add_vhost: TMenuItem;
    MMSS_apache_export_vhosts: TMenuItem;
    MMSS_apache_import_vhosts: TMenuItem;
    MenuItem9_spacer: TMenuItem;
    MMSS_enable_disable_ssl: TMenuItem;
    MMS_apache_ssl: TMenuItem;
    MMSS_server_cert_key: TMenuItem;
    MMSS_trust_cert: TMenuItem;
    MMSS_regen_cert_vhosts: TMenuItem;
    MMSS_apache_server_information: TMenuItem;
    MMSS_apache_server_status: TMenuItem;
    MMS_apache_server_info_status: TMenuItem;
    MMSS_apache_select_root_folder_www: TMenuItem;
    MMSS_apache_select_root_folder_ssl: TMenuItem;
    MMS_apache_change_root_folder: TMenuItem;
    MMSS_apache_change_port: TMenuItem;
    MMSS_apache_change_ssl_port: TMenuItem;
    MMS_apache_change_ports: TMenuItem;
    MenuItem8_spacer: TMenuItem;
    MMSS_php_acc_zop: TMenuItem;
    MMS_php_view_accelerator_control_panel: TMenuItem;
    MMS_edit_selected_php_config: TMenuItem;
    MenuItem5_spacer: TMenuItem;
    MMS_mysql_restore_root_pwd: TMenuItem;
    MMS_mysql_change_pwd: TMenuItem;
    MMS_mysql_change_port: TMenuItem;
    MenuItem3_spacer: TMenuItem;
    MMSS_php_production: TMenuItem;
    MMSS_php_development: TMenuItem;
    MMSS_php_ini: TMenuItem;
    MenuItem1_spacer: TMenuItem;
    MMS_select_php_config: TMenuItem;
    MMS_select_php_version: TMenuItem;
    MMS_mysql_edit_config: TMenuItem;
    mysql_img: TImage;
    MainMenu1: TMainMenu;
    MMS_force_unix_shebang: TMenuItem;
    MMS_force_windows_shebang: TMenuItem;
    MMS_shebang_help: TMenuItem;
    MM_apache: TMenuItem;
    MM_general: TMenuItem;
    MMS_perl_view_test_pl: TMenuItem;
    MM_perl: TMenuItem;
    MM_php: TMenuItem;
    MM_mysql: TMenuItem;
    MM_about: TMenuItem;
    MMS_apache_syntax_check: TMenuItem;
    SystrayIcon: TTrayIcon;
    Timer1: TTimer;
    procedure Btn_mysql_consoleClick(Sender: TObject);
    procedure Btn_view_sslClick(Sender: TObject);
    procedure Btn_opt2Click(Sender: TObject);
    procedure Btn_opt3Click(Sender: TObject);
    procedure Btn_documentationClick(Sender: TObject);
    procedure Btn_minimizeClick(Sender: TObject);
    procedure Btn_closeClick(Sender: TObject);
    procedure TabClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormPaint(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure MMSS_display_at_startup_page1Click(Sender: TObject);
    procedure MMSS_display_at_startup_page2Click(Sender: TObject);
    procedure MMSS_php70Click(Sender: TObject);
    procedure MMSS_php71Click(Sender: TObject);
    procedure MMSS_php72Click(Sender: TObject);
    procedure MMSS_php73Click(Sender: TObject);
    procedure MMSS_php74Click(Sender: TObject);
    procedure MMSS_php80Click(Sender: TObject);
    procedure MMSS_php81Click(Sender: TObject);
    procedure MMSS_php82Click(Sender: TObject);
    procedure MMSS_php83Click(Sender: TObject);
    procedure MMSS_php84Click(Sender: TObject);
    procedure MMSS_php85Click(Sender: TObject);
    procedure MMSS_select_page_to_display1Click(Sender: TObject);
    procedure MMSS_select_page_to_display2Click(Sender: TObject);
    procedure MMSS_apache_access_logClick(Sender: TObject);
    procedure MMSS_apache_add_vhostClick(Sender: TObject);
    procedure MMSS_apache_delete_all_logsClick(Sender: TObject);
    procedure MMSS_apache_delete_vhostClick(Sender: TObject);
    procedure MMSS_apache_export_vhostsClick(Sender: TObject);
    procedure MMSS_apache_import_vhostsClick(Sender: TObject);
    procedure MMSS_apache_edit_basicClick(Sender: TObject);
    procedure MMSS_apache_edit_httpd_confClick(Sender: TObject);
    procedure MMSS_apache_edit_modulesClick(Sender: TObject);
    procedure MMSS_apache_edit_ssl_confClick(Sender: TObject);
    procedure MMSS_apache_error_logClick(Sender: TObject);
    procedure MMSS_apache_ssl_access_logClick(Sender: TObject);
    procedure MMSS_apache_ssl_error_logClick(Sender: TObject);
    procedure MMSS_enable_disable_sslClick(Sender: TObject);
    procedure MMSS_folder_ssl_access_passClick(Sender: TObject);
    procedure MMSS_folder_www_access_passClick(Sender: TObject);
    procedure MMSS_php_edit_basicClick(Sender: TObject);
    procedure MMSS_php_edit_modulesClick(Sender: TObject);
    procedure MMSS_server_cert_keyClick(Sender: TObject);
    procedure MMSS_trust_certClick(Sender: TObject);
    procedure MMSS_regen_cert_vhostsClick(Sender: TObject);
    procedure MMSS_apache_change_portClick(Sender: TObject);
    procedure MMSS_apache_change_ssl_portClick(Sender: TObject);
    procedure MMSS_apache_select_root_folder_sslClick(Sender: TObject);
    procedure MMSS_apache_select_root_folder_wwwClick(Sender: TObject);
    procedure MMSS_apache_server_informationClick(Sender: TObject);
    procedure MMSS_apache_server_statusClick(Sender: TObject);
    procedure MMSS_php_acc_zop1Click(Sender: TObject);
    procedure MMSS_php_developmentClick(Sender: TObject);
    procedure MMSS_php_iniClick(Sender: TObject);
    procedure MMSS_php_productionClick(Sender: TObject);
    procedure MMS_apache_select_root_folder_sslClick(Sender: TObject);
    procedure MMS_apache_syntax_checkClick(Sender: TObject);
    procedure Btn_opt1Click(Sender: TObject);
    procedure Btn_start_apacheClick(Sender: TObject);
    procedure Btn_start_mysqlClick(Sender: TObject);
    procedure Btn_server_consoleClick(Sender: TObject);
    procedure Btn_view_wwwClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MMS_clean_upClick(Sender: TObject);
    procedure MMS_cronClick(Sender: TObject);
    procedure MMS_edit_selected_php_configClick(Sender: TObject);
    procedure MMS_edit_uniformserver_pacClick(Sender: TObject);
    procedure MMS_force_unix_shebangClick(Sender: TObject);
    procedure MMS_force_windows_shebangClick(Sender: TObject);
    procedure MMS_hostsClick(Sender: TObject);
    procedure MMS_uniserviceClick(Sender: TObject);
    procedure MMS_mysql_change_portClick(Sender: TObject);
    procedure MMS_mysql_change_pwdClick(Sender: TObject);
    procedure MMS_mysql_create_userClick(Sender: TObject);
    procedure MMS_mysql_database_backupClick(Sender: TObject);
    procedure MMS_mysql_database_create_deleteClick(Sender: TObject);
    procedure MMS_mysql_database_restoreClick(Sender: TObject);
    procedure MMS_mysql_edit_configClick(Sender: TObject);
    procedure MMS_mysql_edit_userClick(Sender: TObject);
    procedure MMS_mysql_error_logClick(Sender: TObject);
    procedure MMS_mysql_restore_root_pwdClick(Sender: TObject);
    procedure MMS_pc_win_startupClick(Sender: TObject);
    //procedure MMS_pear_frontendClick(Sender: TObject);
    procedure MMS_perl_view_test_plClick(Sender: TObject);
    procedure MMS_php_mail_msmtpClick(Sender: TObject);
    procedure MMS_php_view_accelerator_control_panelClick(Sender: TObject);
    procedure MMS_select_php_versionClick(Sender: TObject);
    procedure MMS_shebang_helpClick(Sender: TObject);
    procedure MMS_select_portable_browserClick(Sender: TObject);
    procedure MMS_select_default_browserClick(Sender: TObject);
    procedure MMS_tray_iconClick(Sender: TObject);
    procedure MMSS_gui_classicClick(Sender: TObject);
    procedure MMSS_gui_modernClick(Sender: TObject);
    procedure MMS_view_phpinfoClick(Sender: TObject);
    procedure MM_aboutClick(Sender: TObject);
    procedure SystrayIconClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
    state_refresh_tick: integer; // Timer divider for the periodic server-state refresh
    log_rotate_tick: integer;    // Timer divider for the periodic log rotation (us_rotate_app_logs)
    FMedallion     : TUsMedallion;     // coin artwork + window region builder
    FBackground    : Graphics.TBitmap; // coin rendered at the current window size
    FBackgroundSize: Integer;          // edge length FBackground was rendered for
    FTrayMenu      : TPopupMenu;       // right-click menu of the notification area icon
    FClassic       : Boolean;          // True = classic window look, False = medallion
    FModernBounds  : array of TDesignBounds; // medallion places of LayoutControls, taken from the .lfm
    FShownEngineName : string;         // engine name the captions carry now ('' = design text 'MySQL')
    FEngineSwitchItem: TMenuItem;      // database menu: Switch database engine
    procedure RenderBackground;
    function LayoutControls: TControlList; // controls whose place depends on the window look
    procedure ApplyGuiStyle;               // switch the form to USC_GuiStyle (classic or medallion)
    procedure ApplyGuiStyleAsync(Data: PtrInt);
    procedure AskGuiStyleOnce;             // first interactive start: classic or modern?
    function SaveGuiStyle(const AStyle: string): Boolean;
    procedure SwitchGuiStyle(const AStyle: string); // menu General > Window look
    function MenuItemForTab(ATab: TUsButton): TMenuItem;
    procedure ApplyDatabaseEngineName; // captions name the active engine (MariaDB or MySQL)
    procedure CreateTrayMenu;          // Show / Exit for the notification area icon
    procedure TrayShowClick(Sender: TObject);
    procedure TrayExitClick(Sender: TObject);
    procedure CreateEngineSwitchMenuItem; // "Switch database engine to ..." at the end of the database menu
    procedure UpdateEngineSwitchItem;  // its caption names the engine on standby
    procedure EngineSwitchClick(Sender: TObject);
    function SwitchDatabaseEngine: Boolean; // swap the engines, report the outcome
  protected
    procedure CreateWnd; override;     // hooks the title bar minimize button (see TitleBarMinimizeProc)
  public
    { public declarations }
    procedure MinimizeToTray;          // hide into the notification area icon
    procedure SyncMenuTabs; // Mirror caption/enabled state of the top-level menu items onto the tabs
  end;

var
  Main: TMain;

implementation

uses
  commctrl;  // SetWindowSubclass for the title bar minimize button

{$R *.lfm}
{$R unicon_images.rc}  // Add image resource for tray icon -> Added into the Project Resources

const
  //--- Window looks (design units at DesignTimePPI 120, see ApplyGuiStyle)
  MEDALLION_CLIENT_SIZE = 800;              // edge of the coin window
  MEDALLION_FORM_COLOR  = TColor($2F2F2F);  // dark outside/behind the coin
  MEDALLION_LABEL_COLOR = TColor($EDEAE8);  // #E8EAED on the dark pads
  MEDALLION_FILL_OPACITY = 240;             // buttons let the metal shimmer through

  CLASSIC_CLIENT_WIDTH  = 556;              // compact UniServer Zero layout
  CLASSIC_CLIENT_HEIGHT = 318;
  CLASSIC_FORM_COLOR    = clWhite;
  CLASSIC_LABEL_COLOR   = TColor($514137);  // #374151, about 10:1 on white
  CLASSIC_FILL_OPACITY  = 255;              // opaque: a translucent fill on white loses contrast
  // Same order as TMain.LayoutControls
  CLASSIC_BOUNDS: array[0..13] of TDesignBounds = (
    (X: 290; Y:  14; W: 214; H: 38),  // Btn_start_apache
    (X: 290; Y:  60; W: 214; H: 38),  // Btn_start_mysql
    (X: 512; Y:  22; W:  22; H: 22),  // apache_img
    (X: 512; Y:  68; W:  22; H: 22),  // mysql_img
    (X:  16; Y: 112; W: 200; H: 26),  // Lbl_apache_utilities
    (X:  16; Y: 142; W: 250; H: 34),  // Btn_server_console
    (X:  16; Y: 184; W: 250; H: 34),  // Btn_view_www
    (X:  16; Y: 226; W: 250; H: 34),  // Btn_view_ssl
    (X:  16; Y: 268; W: 250; H: 34),  // Btn_documentation
    (X: 290; Y: 112; W: 200; H: 26),  // Lbl_mysql_utilities
    (X: 290; Y: 142; W: 250; H: 34),  // Btn_mysql_console
    (X: 290; Y: 184; W: 250; H: 34),  // Btn_opt1
    (X: 290; Y: 226; W: 250; H: 34),  // Btn_opt2
    (X: 290; Y: 268; W: 250; H: 34)); // Btn_opt3

  TITLE_BAR_SUBCLASS_ID = 1;  // our id for SetWindowSubclass on the form window

  LOG_ROTATE_CHECK_TICKS = 600;  // Timer1 ticks once a second: check the rolling logs every 10 minutes

{ TMain }

{====================================================================
Window look. The same form shows either the round medallion (borderless,
clipped to the coin, menus as tabs) or the classic window (title bar,
real menu bar, compact UniServer Zero layout). The choice lives in
us_config.ini [APP] GuiStyle and is asked once at the first interactive
start; General > Window look switches at any time without a restart.
--------------------------------------------------------------------}
function TMain.LayoutControls: TControlList;
begin
  Result := TControlList.Create(
    Btn_start_apache, Btn_start_mysql, apache_img, mysql_img,
    Lbl_apache_utilities, Btn_server_console, Btn_view_www, Btn_view_ssl,
    Btn_documentation, Lbl_mysql_utilities, Btn_mysql_console,
    Btn_opt1, Btn_opt2, Btn_opt3);
end;

procedure TMain.ApplyGuiStyle;
var
  placed : TControlList;
  i        : Integer;
  b        : TDesignBounds;
  wasShown : Boolean;
  cx, cy   : Integer;
  fill     : Byte;
  lblColor : TColor;
begin
  placed := LayoutControls;
  if Length(FModernBounds) = 0 then   // first call: remember the medallion layout of the .lfm
  begin
    SetLength(FModernBounds, Length(placed));
    for i := 0 to High(placed) do
    begin
      FModernBounds[i].X := ScaleFormToDesign(placed[i].Left);
      FModernBounds[i].Y := ScaleFormToDesign(placed[i].Top);
      FModernBounds[i].W := ScaleFormToDesign(placed[i].Width);
      FModernBounds[i].H := ScaleFormToDesign(placed[i].Height);
    end;
  end;

  FClassic := USC_GuiStyle = GUI_CLASSIC;   // not chosen yet = medallion, as before
  wasShown := Visible;
  cx := Left + Width div 2;                 // switching keeps the window centre
  cy := Top + Height div 2;

  // Elements that exist in one look only
  Tab_general.Visible := not FClassic;
  Tab_extra.Visible   := not FClassic;
  Tab_apache.Visible  := not FClassic;
  Tab_mysql.Visible   := not FClassic;
  Tab_php.Visible     := not FClassic;
  Tab_perl.Visible    := not FClassic;
  Tab_about.Visible   := not FClassic;
  Btn_minimize.Visible:= not FClassic;      // classic: title bar buttons instead
  Btn_close.Visible   := not FClassic;
  Lbl_version.Visible := not FClassic;      // classic: version is in About
  Img_logo.Visible    := FClassic;

  if FClassic then
  begin
    UsButtonBackground := nil;              // buttons paint their corners in the form colour
    FreeAndNil(FBackground);
    FBackgroundSize := 0;
    if HandleAllocated then SetWindowRgn(Handle, 0, True); // no coin outline
    Color       := CLASSIC_FORM_COLOR;
    // Menu first: the BorderStyle change recreates the window, and a window
    // created with the menu shows it (attaching it afterwards left no menu bar)
    Menu        := MainMenu1;               // real menu bar replaces the tabs
    BorderStyle := bsSingle;                // recreates the window with a title bar
    fill     := CLASSIC_FILL_OPACITY;
    lblColor := CLASSIC_LABEL_COLOR;
  end
  else
  begin
    Menu        := nil;
    BorderStyle := bsNone;
    Color       := MEDALLION_FORM_COLOR;
    fill     := MEDALLION_FILL_OPACITY;
    lblColor := MEDALLION_LABEL_COLOR;
  end;

  for i := 0 to High(placed) do
  begin
    if FClassic then b := CLASSIC_BOUNDS[i] else b := FModernBounds[i];
    placed[i].SetBounds(ScaleDesignToForm(b.X), ScaleDesignToForm(b.Y),
                          ScaleDesignToForm(b.W), ScaleDesignToForm(b.H));
    if placed[i] is TUsButton then TUsButton(placed[i]).FillOpacity := fill;
  end;
  Lbl_apache_utilities.Font.Color := lblColor;
  Lbl_mysql_utilities.Font.Color  := lblColor;

  if FClassic then
  begin
    ClientWidth  := ScaleDesignToForm(CLASSIC_CLIENT_WIDTH);
    ClientHeight := ScaleDesignToForm(CLASSIC_CLIENT_HEIGHT);
  end
  else
  begin
    ClientWidth  := ScaleDesignToForm(MEDALLION_CLIENT_SIZE);
    ClientHeight := ScaleDesignToForm(MEDALLION_CLIENT_SIZE);
    if FBackgroundSize <> ClientWidth then RenderBackground; // also sets the coin outline
  end;

  // Menu state
  MMSS_gui_classic.Checked := FClassic;
  MMSS_gui_modern.Checked  := not FClassic;

  if wasShown then
  begin
    // Same centre as before, but fully on the work area of this monitor
    Left := cx - Width div 2;
    Top  := cy - Height div 2;
    if Left + Width > Monitor.WorkareaRect.Right then Left := Monitor.WorkareaRect.Right - Width;
    if Top + Height > Monitor.WorkareaRect.Bottom then Top := Monitor.WorkareaRect.Bottom - Height;
    if Left < Monitor.WorkareaRect.Left then Left := Monitor.WorkareaRect.Left;
    if Top < Monitor.WorkareaRect.Top then Top := Monitor.WorkareaRect.Top;
  end;
  Invalidate;
end;

procedure TMain.ApplyGuiStyleAsync(Data: PtrInt);
begin
  ApplyGuiStyle;
  us_update_server_state; // redraw the LEDs on the new background colour
end;

{Persist the look. Returns False (after telling the user) when
 us_config.ini cannot be written, e.g. a read-only server folder.}
function TMain.SaveGuiStyle(const AStyle: string): Boolean;
begin
  USC_GuiStyle := AStyle;
  try
    us_ini_set(USF_US_CONF_INI, 'APP', 'GuiStyle', AStyle);
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      us_MessageDlg('Window look',
        'The window look could not be saved in' + sLineBreak + USF_US_CONF_INI + sLineBreak + sLineBreak +
        'Reason: ' + E.Message + sLineBreak + sLineBreak +
        'The look applies until WinpachoController is closed. To keep it, make sure the' + sLineBreak +
        'server folder is writable and choose it again in General > Window look.',
        mtWarning, [mbOk], 0);
    end;
  end;
end;

procedure TMain.AskGuiStyleOnce;
var
  choice, engine, standby: string;
begin
  if USC_GuiStyle <> '' then Exit;          // already chosen
  // Same dialog, first band: the database engine - offered when the other
  // engine waits in core\db_standby (bundles from 2.4.0 on)
  standby := '';
  if us_db_engine_in_standby(us_db_standby_engine) then standby := us_db_standby_engine;
  choice := us_ask_gui_style(US_MYMAR_TXT, standby, engine); // coloured choice dialog, us_gui_style_dlg.pas
  if choice = '' then Exit;   // closed without a choice: medallion and engine as shipped, asked again next start
  SaveGuiStyle(choice);
  // The captions are renamed after this (ApplyDatabaseEngineName in FormCreate)
  if engine <> US_MYMAR_TXT then SwitchDatabaseEngine;
end;

procedure TMain.SwitchGuiStyle(const AStyle: string);
begin
  if AStyle <> USC_GuiStyle then SaveGuiStyle(AStyle);
  USC_GuiStyle := AStyle;
  // Outside the menu's own message handling: the switch recreates the window
  Application.QueueAsyncCall(@ApplyGuiStyleAsync, 0);
end;

procedure TMain.MMSS_gui_classicClick(Sender: TObject);
begin
  SwitchGuiStyle(GUI_CLASSIC);
end;

procedure TMain.MMSS_gui_modernClick(Sender: TObject);
begin
  SwitchGuiStyle(GUI_MODERN);
end;

{====================================================================
Medallion window (see us_medallion.pas): render the coin at the current
window size with dark pads under the text rows, hand it to the buttons
for their corner areas and clip the window to the coin's outline.
--------------------------------------------------------------------}
procedure TMain.RenderBackground;
var
  size, pad, padY, radius, gap: Integer;
  bands : array[0..3] of TRect;
  rgn   : HRGN;
begin
  size := ClientWidth;
  if (size <= 0) or (FMedallion = nil) then Exit;
  if FBackground = nil then FBackground := Graphics.TBitmap.Create;

  pad    := ScaleDesignToForm(8);
  padY   := ScaleDesignToForm(6);
  gap    := ScaleDesignToForm(4);
  radius := ScaleDesignToForm(10);
  // Pads: menu row, the two column headings, the version line
  bands[0] := Classes.Rect(Tab_general.Left - pad, Tab_general.Top - padY,
                   Tab_about.Left + Tab_about.Width + pad,
                   Tab_general.Top + Tab_general.Height + padY);
  bands[1] := Classes.Rect(Btn_server_console.Left - gap,
                   Lbl_apache_utilities.Top - gap,
                   Btn_server_console.Left + Btn_server_console.Width + gap,
                   Btn_server_console.Top - gap);
  bands[2] := Classes.Rect(Btn_mysql_console.Left - gap,
                   Lbl_mysql_utilities.Top - gap,
                   Btn_mysql_console.Left + Btn_mysql_console.Width + gap,
                   Btn_mysql_console.Top - gap);
  bands[3] := Classes.Rect(Lbl_version.Left - pad, Lbl_version.Top - padY,
                   Lbl_version.Left + Lbl_version.Width + pad,
                   Lbl_version.Top + Lbl_version.Height + padY);

  if FMedallion.Render(size, FBackground, bands, radius, 190) then
    rgn := FMedallion.CreateRegion
  else
  begin
    // Artwork missing or unreadable: a plain dark disc keeps the window usable
    FBackground.SetSize(size, size);
    FBackground.Canvas.Brush.Color := Color;
    FBackground.Canvas.FillRect(0, 0, size, size);
    FBackground.Canvas.Brush.Color := USB_GRAPHITE;
    FBackground.Canvas.Pen.Color   := USB_GRAPHITE;
    FBackground.Canvas.Ellipse(0, 0, size, size);
    rgn := CreateEllipticRgn(0, 0, size, size);
  end;
  FBackgroundSize    := size;
  UsButtonBackground := FBackground;
  SetWindowRgn(Handle, rgn, True); // the window owns rgn from here on
  Invalidate;
end;

procedure TMain.FormPaint(Sender: TObject);
begin
  if (not FClassic) and (FBackground <> nil) then
    Canvas.Draw(0, 0, FBackground);
end;

procedure TMain.FormResize(Sender: TObject);
begin
  // DPI change or monitor move: the LCL rescaled the controls, redo the coin
  if (not FClassic) and (FMedallion <> nil) and (ClientWidth <> FBackgroundSize) then
    RenderBackground;
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
  UsButtonBackground := nil;
  FreeAndNil(FBackground);
  FreeAndNil(FMedallion);
end;

procedure TMain.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // No title bar: dragging any free spot of the coin moves the window.
  // The classic window has a title bar for that, like every other program.
  if (Button = mbLeft) and not FClassic then
  begin
    ReleaseCapture;
    SendMessage(Handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
  end;
end;

procedure TMain.Btn_minimizeClick(Sender: TObject);
begin
  // Only the window's own minimize button sends it to the tray: this
  // minus button on the medallion, the title bar button in the classic
  // look (see TitleBarMinimizeProc). A taskbar click minimizes normally
  // and keeps the taskbar entry, like every other Windows program.
  // Setting WindowState in code does not fire OnWindowStateChange, so
  // the button acts directly.
  If USC_TrayIconEnabled Then
    MinimizeToTray
  Else
    Application.Minimize;              // Minimize to the taskbar button
end;

procedure TMain.MinimizeToTray;
begin
  Main.Hide;                       // Hide; tray icon brings it back
  Main.ShowInTaskBar := stNever;   // Remove from task bar
  us_update_server_state;          // Update menus
end;

{====================================================================
Classic window: the title bar minimize button goes to the tray, like
the minus button of the medallion, so both looks behave the same.
The LCL minimizes the whole application in its own WM_SYSCOMMAND
handling before the form sees the message, so the form window is
subclassed and SC_MINIMIZE is taken off it first. Only the form gets
this message from the title bar button (and Alt+Space > Minimize);
a taskbar click goes to the hidden Application window and still
minimizes normally. CreateWnd runs again whenever the window look
switch recreates the window, so the hook is set on every new handle.
--------------------------------------------------------------------}
function TitleBarMinimizeProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM; uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
begin
  if (uMsg = WM_SYSCOMMAND) and ((wParam and $FFF0) = SC_MINIMIZE)
     and USC_TrayIconEnabled then
  begin
    TMain(dwRefData).MinimizeToTray;
    Exit(0);
  end;
  if uMsg = WM_NCDESTROY then              // required before the window goes away
    RemoveWindowSubclass(hWnd, SUBCLASSPROC(@TitleBarMinimizeProc), uIdSubclass);
  Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;

procedure TMain.CreateWnd;
begin
  inherited CreateWnd;
  SetWindowSubclass(Handle, @TitleBarMinimizeProc, TITLE_BAR_SUBCLASS_ID, DWORD_PTR(Self));
end;

procedure TMain.Btn_closeClick(Sender: TObject);
begin
  Close;
end;

function TMain.MenuItemForTab(ATab: TUsButton): TMenuItem;
begin
  Result := nil;
  if ATab = Tab_general then Result := MM_general
  else if ATab = Tab_extra then Result := MenuItem1   // "Extra"
  else if ATab = Tab_apache then Result := MM_apache
  else if ATab = Tab_mysql then Result := MM_mysql
  else if ATab = Tab_php then Result := MM_php
  else if ATab = Tab_perl then Result := MM_perl
  else if ATab = Tab_about then Result := MM_about;
end;

{====================================================================
Menu tabs replace the menu bar, which a borderless window cannot show.
A tab opens its top-level item's submenu as a popup below the tab. The
form has no menu attached, so the LCL cannot route WM_COMMAND for these
items: TrackPopupMenu returns the chosen command and it is dispatched here.
--------------------------------------------------------------------}
procedure TMain.TabClick(Sender: TObject);
var
  tab         : TUsButton;
  item, chosen: TMenuItem;
  p           : TPoint;
  cmd         : LongInt;
begin
  tab  := Sender as TUsButton;
  item := MenuItemForTab(tab);
  if item = nil then Exit;

  if item.Count = 0 then      // plain entry such as About
  begin
    item.Click;
    Exit;
  end;

  p   := tab.ClientToScreen(Classes.Point(0, tab.Height)); // Point() alone would be the Windows type
  cmd := LongInt(TrackPopupMenuEx(item.Handle,
           TPM_LEFTALIGN or TPM_TOPALIGN or TPM_LEFTBUTTON or TPM_RETURNCMD,
           p.X, p.Y, Handle, nil));
  tab.ResetVisualState;       // the popup swallowed the mouse-up
  if cmd <> 0 then
  begin
    chosen := MainMenu1.FindItem(cmd, fkCommand);
    if chosen <> nil then chosen.Click;
  end;
end;

{====================================================================
The form is designed with 'MySQL' in every database caption. The bundle
ships MariaDB and MySQL (since 2.4.0), and core\mysql\us_opt.ini names
the active engine (US_MYMAR_TXT). Rename every caption at start-up and
after each Switch database engine, so the user sees the engine they
actually run: menu tree (the tabs mirror it in SyncMenuTabs), utilities
label, console button. FShownEngineName remembers the name the captions
carry now. The start/stop button gets its text from START_MY/STOP_MY.
--------------------------------------------------------------------}
procedure TMain.ApplyDatabaseEngineName;

  function Renamed(const ACaption: string): string;
  begin
    Result := StringReplace(ACaption, FShownEngineName, US_MYMAR_TXT, [rfReplaceAll]);
  end;

  procedure RenameMenu(AItem: TMenuItem);
  var
    i: Integer;
  begin
    AItem.Caption := Renamed(AItem.Caption);
    for i := 0 to AItem.Count - 1 do RenameMenu(AItem.Items[i]);
  end;

begin
  if FShownEngineName = '' then FShownEngineName := DB_ENGINE_MYSQL; // the design text
  if (US_MYMAR_TXT = '') or (US_MYMAR_TXT = FShownEngineName) then Exit;
  RenameMenu(MainMenu1.Items);
  Lbl_mysql_utilities.Caption := Renamed(Lbl_mysql_utilities.Caption);
  Btn_mysql_console.Caption   := Renamed(Btn_mysql_console.Caption);
  FShownEngineName := US_MYMAR_TXT;
  UpdateEngineSwitchItem;     // built in code, its caption is its own
end;

procedure TMain.SyncMenuTabs;

  procedure Sync(ATab: TUsButton; AItem: TMenuItem);
  begin
    ATab.Caption := AItem.Caption;
    ATab.Enabled := AItem.Enabled;
  end;

begin
  Sync(Tab_general, MM_general);
  Sync(Tab_extra,   MenuItem1);
  Sync(Tab_apache,  MM_apache);
  Sync(Tab_mysql,   MM_mysql);
  Sync(Tab_php,     MM_php);
  Sync(Tab_perl,    MM_perl);
  Sync(Tab_about,   MM_about);
  // Say why a menu is greyed out instead of leaving the user guessing
  if MM_php.Enabled then
    Tab_php.Hint := ''
  else
    Tab_php.Hint := 'PHP menu unavailable: no PHP version selected';
  if MM_perl.Enabled then
    Tab_perl.Hint := ''
  else
    Tab_perl.Hint := 'Perl menu unavailable: Perl is not installed in ' + US_PERL;
end;

procedure TMain.Btn_start_apacheClick(Sender: TObject);
var
  url:string;      // Page url displayed in default browser
  url_base:string; // Scheme://server:port prefix (https when SSL is on)
begin
   //--Apache installed as a Windows service (WinpachoService): the controller has
   //  no right to kill the service's process, so the button drives the service
   //  itself through an elevated sc.exe call (Windows shows the UAC prompt).
   If (Main.Btn_start_apache.Caption = START_AP_SVC) or
      (Main.Btn_start_apache.Caption = STOP_AP_SVC) Then
    begin
     Btn_start_apache.Enabled := False;                           // No double clicks while sc.exe runs
     try
       us_control_windows_service(USC_APACHE_SERVICE_NAME,
                                  Main.Btn_start_apache.Caption = START_AP_SVC);
     finally
       Btn_start_apache.Enabled := True;
       us_update_server_state;  // Update server state. Set button and indicator state
     end;
     Exit;
    end;

   If (Main.Btn_start_apache.Caption  = START_AP) Then
    begin
     us_warn_if_vcruntime_too_old(UENV_PHP_SELECT); // Warn early: Apache or selected PHP may need a newer VC++ runtime
     Btn_start_apache.Enabled := False; // Disable button
     us_start_apache_program;           // Start Apache server
     us_update_server_state;            // Update server state. Set button and indicator state

     //--Display user configured pages at start-up.
     //  Prefer https when SSL is enabled and a certificate exists, so the
     //  start page opens as https://<server> instead of plain http.
     If AP_SSL_ENABLED and FileExists(USF_CERT) Then
        url_base := 'https://' + UENV_US_SERVERNAME + ':' + UENV_AP_SSL_PORT
     Else
        url_base := 'http://'  + UENV_US_SERVERNAME + ':' + UENV_AP_PORT;

     If USUC_DISPLAY_PAGE_1 = 'yes' Then
      begin
        url := url_base + USUC_PAGE_1;

        //Change url if PHP not enabled. Replace file index.php with ""
        If UENV_PHP_SELECT = 'None' Then
         begin
            url := StringReplace(url, 'index.php','',[rfReplaceAll]);  // Replace index.php with /
         end;

        browser_display_url(url); //Display URL in default/portable browser
      end;

      If USUC_DISPLAY_PAGE_2 = 'yes' Then
      begin
       url := url_base + USUC_PAGE_2;

       //Change url if PHP not enabled. Replace file index.php with ""
       If UENV_PHP_SELECT = 'None' Then
        begin
           url := StringReplace(url, 'index.php','',[rfReplaceAll]);  // Replace index.php with /
        end;

       browser_display_url(url); //Display URL in default/portable browser
      end;

    end
  Else
    begin
     us_kill_apache_program;  // Button Stop Apache - Kill Apache server
     us_update_server_state;  // Update server state. Set button and indicator state
    end;

end;

//Default button function is the database tool Adminer (home\us_opt1, text and page from its us_opt.ini)
procedure TMain.Btn_opt1Click(Sender: TObject);
var
  url :string;
begin
  url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/us_opt1/' + US_OPT1_PAGE;
  browser_display_url(url); //Display URL in default/portable browser
end;

procedure TMain.MMS_apache_syntax_checkClick(Sender: TObject);
begin
    us_apache_syntax_check; //Opens a CMD (DOS) window and displays syntax check result
end;

procedure TMain.FormWindowStateChange(Sender: TObject);
begin
 // Taskbar click, Win+D, Win+M: plain minimize/restore, the taskbar
 // entry stays. Only Btn_minimize sends the window to the tray.
 us_update_server_state; // Update menus
end;

procedure TMain.MMSS_display_at_startup_page1Click(Sender: TObject);
begin
  If Main.MMSS_display_at_startup_page1.Checked Then
   begin
     Main.MMSS_display_at_startup_page1.Checked := False; // Set to un-checked
     USUC_DISPLAY_PAGE_1 := 'no';                         // Do not display at start-up
   end
  Else
   begin
    Main.MMSS_display_at_startup_page1.Checked := True;   // Set to checked
    USUC_DISPLAY_PAGE_1 := 'yes';                         // Display at start-up
   end;
   us_ini_set(USF_US_USER_INI,'USER','DISPLAY_PAGE_1',USUC_DISPLAY_PAGE_1); // save to config file
  us_update_server_state;                                 // Update menus
  msg_restart_apache;                                     // If running display message
end;

procedure TMain.MMSS_display_at_startup_page2Click(Sender: TObject);
begin
    If Main.MMSS_display_at_startup_page2.Checked Then
   begin
     Main.MMSS_display_at_startup_page2.Checked := False;  // Set to un-checked
     USUC_DISPLAY_PAGE_2 := 'no';                          // Do not display at start-up
   end
  Else
   begin
    Main.MMSS_display_at_startup_page2.Checked := True;    // Set to checked
    USUC_DISPLAY_PAGE_2 := 'yes';                          // Display at start-up
   end;
  us_ini_set(USF_US_USER_INI,'USER','DISPLAY_PAGE_2',USUC_DISPLAY_PAGE_2); // save to config file
  us_update_server_state;                                                  // Update menus
  msg_restart_apache;                                                      // If running display message
end;

procedure TMain.MMSS_php70Click(Sender: TObject);
begin
 //Toggle action
 If Main.MMSS_php70.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php70';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php70');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT));   // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file
end;

procedure TMain.MMSS_php71Click(Sender: TObject);
begin
 //Toggle action
 If Main.MMSS_php71.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php71';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php71');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT));   // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file
end;

procedure TMain.MMSS_php72Click(Sender: TObject);
begin
 //Toggle action
 If Main.MMSS_php72.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php72';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php72');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT));   // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file
end;

procedure TMain.MMSS_php73Click(Sender: TObject);
begin
 //Toggle action
 If Main.MMSS_php73.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php73';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php73');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT));   // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file
end;

procedure TMain.MMSS_php74Click(Sender: TObject);
begin
 //Toggle action
 If Main.MMSS_php74.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php74';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php74');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT));   // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file
end;

procedure TMain.MMSS_php80Click(Sender: TObject);
begin
 //Toggle action
 If Main.MMSS_php80.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php80';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php80');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT)); // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file
end;

procedure TMain.MMSS_php81Click(Sender: TObject);
begin
  //Toggle action
 If Main.MMSS_php81.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php81';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php81');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT)); // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file

end;

procedure TMain.MMSS_php82Click(Sender: TObject);
begin
  //Toggle action
 If Main.MMSS_php82.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php82';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php82');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT)); // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file

end;

procedure TMain.MMSS_php83Click(Sender: TObject);
begin
  //Toggle action
 If Main.MMSS_php83.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php83';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php83');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT)); // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 us_warn_if_vcruntime_too_old(UENV_PHP_SELECT); // Warn if this PHP needs a newer VC++ runtime (config-driven)
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file

end;

procedure TMain.MMSS_php84Click(Sender: TObject);
begin
  //Toggle action
 If Main.MMSS_php84.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php84';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php84');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT)); // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 us_warn_if_vcruntime_too_old(UENV_PHP_SELECT); // Warn if this PHP needs a newer VC++ runtime (config-driven)
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file

end;

procedure TMain.MMSS_php85Click(Sender: TObject);
begin
  //Toggle action
 If Main.MMSS_php85.Checked Then
   begin
    UENV_PHP_SELECT :='None';                                            // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','None');              // save to config file
   end
 Else
   begin
    UENV_PHP_SELECT :='php85';                                           // Set var
    us_ini_set(USF_US_USER_INI,'USER','PHP_SELECT','php85');             // save to config file
   end;
 windows.SetEnvironmentVariable('PHP_SELECT',PCHAR(UENV_PHP_SELECT)); // PHP Select
 us_set_environment_path;  // Set new enironment paths
 us_update_server_state;   // Update menus
 us_warn_if_vcruntime_too_old(UENV_PHP_SELECT); // PHP 8.5 needs VC++ runtime 14.44+; warn at selection
 msg_restart_apache;       // Reminder dialog - Restart apache.
 us_update_go_pear_config; // update paths in go-pear configuration file

end;

procedure TMain.MMSS_select_page_to_display1Click(Sender: TObject);
var
  page1:         string; // User selected page
begin
    page1:='';

  //Get a valid web page to display at start-up and save to config file
  If us_get_valid_web_page(page1) Then
   begin
     USUC_PAGE_1   := page1;                            // Set var
     us_ini_set(USF_US_USER_INI,'USER','PAGE_1',page1); // save to config file
     us_update_server_state;                            // Update menus
     us_MessageDlg('Page Info','New PAGE was set', mtcustom,[mbOk],0); //Display information
   end
  Else
      us_MessageDlg('Page Info','Cancel clicked: No action taken', mtcustom,[mbOk],0);

end;

procedure TMain.MMSS_select_page_to_display2Click(Sender: TObject);
var
  page2:         string; // User selected page
begin
    page2:='';

   //Get a valid web page to display at start-up and save to config file
   If us_get_valid_web_page(page2) Then
    begin
      USUC_PAGE_2   := page2;                            // Set var
      us_ini_set(USF_US_USER_INI,'USER','PAGE_2',page2); // save to config file
      us_update_server_state;                            // Update menus
       us_MessageDlg('Page Info','New PAGE was set', mtcustom,[mbOk],0); //Display information
    end
   Else
     us_MessageDlg('Page Info','Cancel clicked: No action taken', mtcustom,[mbOk],0);
end;

procedure TMain.MMSS_apache_access_logClick(Sender: TObject);
begin
  us_display_in_editor(USF_APACHE_ACCESS_LOG);
end;

procedure TMain.MMSS_apache_add_vhostClick(Sender: TObject);
begin
   vhost_create.ShowModal; //Dsplay vhost form
end;

procedure TMain.MMSS_apache_delete_all_logsClick(Sender: TObject);
begin
  // Delete logs
  If FileExists(USF_APACHE_ERROR_LOG)      Then
     DeleteFile(pchar(USF_APACHE_ERROR_LOG));
  If FileExists(USF_APACHE_ACCESS_LOG)     Then
     DeleteFile(pchar(USF_APACHE_ACCESS_LOG));
  If FileExists(USF_APACHE_SSL_ERROR_LOG)  Then
     DeleteFile(pchar(USF_APACHE_SSL_ERROR_LOG));
  If FileExists(USF_APACHE_SSL_ACCESS_LOG) Then
     DeleteFile(pchar(USF_APACHE_SSL_ACCESS_LOG));

  // The files above are only hard links to the current part of their
  // rotation ring; the rings themselves (and those of the vhost logs) live
  // in logs\rotated - clear that folder too, or nothing is freed.
  If DirectoryExists(USF_APACHE_ROTATED_LOGS) Then
     DeleteDirectory(USF_APACHE_ROTATED_LOGS, True);   // True: contents only, keep the folder

  us_update_server_state; // Update menus
end;

procedure TMain.MMSS_apache_delete_vhostClick(Sender: TObject);
begin
     vhost_delete.ShowModal; //Display orm
end;

procedure TMain.MMSS_apache_export_vhostsClick(Sender: TObject);
begin
  us_export_vhosts;  // List of host name + folder, for a new winpacho version
end;

procedure TMain.MMSS_apache_import_vhostsClick(Sender: TObject);
begin
  us_import_vhosts;  // Rebuild the vhosts from an exported list
end;

procedure TMain.MMSS_apache_edit_basicClick(Sender: TObject);
begin
  apache_basic.ShowModal;   //Dispay form
end;

procedure TMain.MMSS_apache_edit_httpd_confClick(Sender: TObject);
begin
    us_display_in_editor(USF_APACHE_CNF); //Display Apache coniguration file
end;

procedure TMain.MMSS_apache_edit_modulesClick(Sender: TObject);
begin
  apache_modules.ShowModal; //Display form
end;

procedure TMain.MMSS_apache_edit_ssl_confClick(Sender: TObject);
begin
    us_display_in_editor(USF_APACHE_SSL_CNF); //Display Apache SSL coniguration file
end;

procedure TMain.MMSS_apache_error_logClick(Sender: TObject);
begin
  us_display_in_editor(USF_APACHE_ERROR_LOG);
end;

procedure TMain.MMSS_apache_ssl_access_logClick(Sender: TObject);
begin
  us_display_in_editor(USF_APACHE_SSL_ACCESS_LOG);
end;

procedure TMain.MMSS_apache_ssl_error_logClick(Sender: TObject);
begin
  us_display_in_editor(USF_APACHE_SSL_ERROR_LOG);
end;

procedure TMain.MMSS_enable_disable_sslClick(Sender: TObject);
var
  str:String;
begin
  //Button action toggel.
  If  Main.MMSS_enable_disable_ssl.Caption = Btn_text_enable_ssl Then //Enable SSL
   begin
     //To enable SSL in Apache config file a server certificate must exist
     If FileExists(USF_CERT) Then
       us_enable_apache_ssl     // Enable Apache ssl in configuration file httpd.conf

     Else // Ask user if they wish to create a certificate
       begin
        // Server Certificate Not Found
        str := '';
        str := str +  'A server certificate was not found.' + sLineBreak + sLineBreak;
        str := str +  'Would you like to continue and '     + sLineBreak;
        str := str +  'generate a certificate and Key?';

        if us_MessageDlg('Server Certificate Not Found', str, mtConfirmation,[mbYes, mbNo],0) = mrYes then
             server_cert_key_gen.show; //Display certificate key generator form
        end;
   end
  Else //Disable SSL
     us_disable_apache_ssl; // Disable Apache ssl in configuration file httpd.conf

  //Update server state
  us_update_server_state;   // Update menus

  //Reminder
  msg_restart_apache;       // Check Apache runnning and inform user to restart Apache
end;

procedure TMain.MMSS_folder_ssl_access_passClick(Sender: TObject);
begin
  root_ssl_pass_access.ShowModal;
end;

procedure TMain.MMSS_folder_www_access_passClick(Sender: TObject);
begin
  root_www_pass_access.ShowModal;
end;

procedure TMain.MMSS_php_edit_basicClick(Sender: TObject);
begin
  edit_php_basic.ShowModal;
end;

procedure TMain.MMSS_php_edit_modulesClick(Sender: TObject);
begin
  php_extensions.Showmodal;
end;

procedure TMain.MMSS_server_cert_keyClick(Sender: TObject);
begin
    server_cert_key_gen.ShowModal;
end;

procedure TMain.MMSS_trust_certClick(Sender: TObject);
begin
    us_trust_ssl_cert;  // Add server certificate to the Windows user certificate store
end;

procedure TMain.MMSS_regen_cert_vhostsClick(Sender: TObject);
begin
    us_regenerate_cert_for_all_vhosts;  // Rebuild cert covering localhost + all vhost domains
    us_MessageDlg('Apache SSL',
      'The server certificate was rebuilt to cover localhost'  + sLineBreak +
      'and every Vhost domain in httpd-vhosts.conf.'           + sLineBreak + sLineBreak +
      'Next steps:'                                            + sLineBreak +
      '1. Apache SSL > Trust certificate in Windows (confirm with Yes)' + sLineBreak +
      '2. Restart your browser completely'                     + sLineBreak +
      '3. Restart Apache',
      mtInformation,[mbOk],0);
end;


procedure TMain.MMSS_apache_change_portClick(Sender: TObject);
var
  old_apache_port:string;
  new_apache_port:string;
begin
   old_apache_port:= '';
   new_apache_port:= '';

 If us_get_new_port(UENV_AP_PORT,new_apache_port,'80') Then
   begin
     old_apache_port:= UENV_AP_PORT;                                  // Save old port value
     UENV_AP_PORT := new_apache_port;                                 // Set var
     us_ini_set(USF_US_USER_INI,'USER','AP_PORT',UENV_AP_PORT);       // save to config file
     windows.SetEnvironmentVariable('AP_PORT',PCHAR(UENV_AP_PORT));   // Set environoment variable
     us_proxy_file_port_update(old_apache_port,new_apache_port);      // Update PAC file with new port

     us_update_server_state;                                          // Update menus
     us_MessageDlg('Apache info','Port was changed', mtcustom,[mbOk],0) ; // Display message
     msg_restart_apache;                                              // If running display message
   end
 Else
    us_MessageDlg('Apache info','Cancel clicked: No action taken', mtcustom,[mbOk],0) ; //Display information

end;

procedure TMain.MMSS_apache_change_ssl_portClick(Sender: TObject);
var
  new_apache_ssl_port:string;
begin
   new_apache_ssl_port:= '';

 If us_get_new_port(UENV_AP_SSL_PORT,new_apache_ssl_port,'443') Then
   begin
     UENV_AP_SSL_PORT := new_apache_ssl_port;                               // Set var
     us_ini_set(USF_US_USER_INI,'USER','AP_SSL_PORT',UENV_AP_SSL_PORT);     // save to config file
     windows.SetEnvironmentVariable('AP_SSL_PORT',PCHAR(UENV_AP_SSL_PORT)); // Set environoment variable
     us_update_server_state;                                                // Update menus
     us_MessageDlg('Apache Info','Port was changed', mtcustom,[mbOk],0) ;       // Display message
     msg_restart_apache;                                                    // If running display message
   end
 Else
    us_MessageDlg('Apache Info','Cancel clicked: No action taken', mtcustom,[mbOk],0) ; //Display message

end;

procedure TMain.MMSS_apache_select_root_folder_sslClick(Sender: TObject);
var
  new_folder:string;
  folder_temp:string;
  drive1:string;
  drive2:string;
begin
    new_folder :='';   // Initial value
   If us_get_new_root_folder(new_folder,'ssl') Then
    begin
    //-----
    folder_temp := ''; //Set initial value
    new_folder := StringReplace(new_folder, '\','/',[rfReplaceAll]); // Replace back with forward slashes
    UENV_US_ROOTF_SSL := new_folder;                                 // Save full path

    //===Determine new value to save to configuration file.
    //Is selected folder in Uniform Server application folder
    If Pos(UniConPath_F,new_folder) = 1 then //New folder contains UniConPath_F
     Begin
       folder_temp :=  StringReplace(new_folder, UniConPath_F,'',[]); //Remove  UniConPath_F
       folder_temp := '.'+ folder_temp;                               //Add current folder marker '.'
     End
    Else
     begin
       //Is selected folder on the same drive as winpacho
       drive1 := ExtractFileDrive(new_folder);   //get drive e.g C:
       drive2 := ExtractFileDrive(UniConPath_F); //get drive e.g C:
       If (drive1 = drive2) Then                 //On same drive
        begin
          folder_temp := StringReplace(new_folder, drive1,'',[]); //Remove drive letter to give /.....
        end
        Else     //Not on the same drive
         begin
           folder_temp := new_folder; //Save folder unchanged
         end;
     end;
    us_ini_set(USF_US_USER_INI,'USER','US_ROOTF_SSL',folder_temp);            // save to config file
    USF_SSL_HTACCESS          :=  UENV_US_ROOTF_SSL+'\.htaccess';             // update path SSL Root htaccess file
    USF_SSL_HTACCESS_BACK     :=  UENV_US_ROOTF_SSL+'\.htaccess_back';        // update path SSL Root htaccess backup file
    windows.SetEnvironmentVariable('US_ROOTF_SSL',PCHAR(UENV_US_ROOTF_SSL));  // Set environoment variable

    us_MessageDlg('Apache Info','New Apache root-folder ssl set', mtcustom,[mbOk],0); //Display message
    us_update_server_state; // Update menus
    //----
    end
   Else
     us_MessageDlg('Apache Info','Cancel clicked: No action taken', mtcustom,[mbOk],0) ; //Display information message

end;

procedure TMain.MMSS_apache_select_root_folder_wwwClick(Sender: TObject);
var
  new_folder  :string;  // New path
  folder_temp :string;
  drive1 :string;
  drive2 :string;
begin
    new_folder :='';   //Initial value

  If us_get_new_root_folder(new_folder,'www') Then
   begin
   //---
   folder_temp := ''; //Set initial value
  new_folder := StringReplace(new_folder, '\','/',[rfReplaceAll]); // Replace back with forward slashes
  UENV_US_ROOTF_WWW := new_folder;                                 // Save full path

  //===Determine new value to save to configuration file.
  //Is selected folder in Uniform Server application folder
  If Pos(UniConPath_F,new_folder) = 1 then //New folder contains UniConPath_F
   Begin
     folder_temp :=  StringReplace(new_folder, UniConPath_F,'',[]); //Remove  UniConPath_F
     folder_temp := '.'+ folder_temp;                               //Add current folder marker '.'
   End
  Else
   begin
     //Is selected folder on the same drive as winpacho
     drive1 := ExtractFileDrive(new_folder);   //get drive e.g C:
     drive2 := ExtractFileDrive(UniConPath_F); //get drive e.g C:
     If (drive1 = drive2) Then                 //On same drive
      begin
        folder_temp := StringReplace(new_folder, drive1,'',[]); //Remove drive letter to give /.....
      end
      Else     //Not on the same drive
       begin
         folder_temp := new_folder; //Save folder unchanged
       end;
   end;
  us_ini_set(USF_US_USER_INI,'USER','US_ROOTF_WWW',folder_temp);            // save to config file
  USF_WWW_HTACCESS          :=  UENV_US_ROOTF_WWW+'\.htaccess';             // update path WWW Root htaccess file
  USF_WWW_HTACCESS_BACK     :=  UENV_US_ROOTF_WWW+'\.htaccess_back';        // update WWW Root htaccess backup file
  windows.SetEnvironmentVariable('US_ROOTF_WWW',PCHAR(UENV_US_ROOTF_WWW));  // Set environoment variable

  us_MessageDlg('Apache Info','New Apache root-folder www set', mtcustom,[mbOk],0); //Display message
  us_update_server_state; // Update menus

   //---
   end
  Else
    us_MessageDlg('Apache Info','Cancel clicked: No action taken', mtcustom,[mbOk],0); //Display message

end;

procedure TMain.MMSS_apache_server_informationClick(Sender: TObject);
var
  url :string;
begin
   url := 'http://'+ UENV_US_SERVERNAME +':'+ UENV_AP_PORT +'/server-info'; // Display Apache Server Information page
   browser_display_url(url);                                                // Display URL in default/portable browser
end;

procedure TMain.MMSS_apache_server_statusClick(Sender: TObject);
var
  url :string;
begin
  url := 'http://'+ UENV_US_SERVERNAME +':'+UENV_AP_PORT+'/server-status'; // Display Apache Server Status page
  browser_display_url(url);                                                // Display URL in default/portable browser
end;



procedure TMain.Btn_mysql_consoleClick(Sender: TObject);
begin
  us_display_mysql_prompt; // Display MySQL command console and MySQL prompt
end;

procedure TMain.Btn_view_sslClick(Sender: TObject);
var
  url:string;
begin
  url := 'https://' + UENV_US_SERVERNAME + ':' + UENV_AP_SSL_PORT + '/';
  browser_display_url(url); // Display URL in default/portable browser
end;

//Default button function is Adminer
procedure TMain.Btn_opt2Click(Sender: TObject);
var
  url:string;
begin
  url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/us_opt2/' + US_OPT2_PAGE;
  browser_display_url(url); // Display URL in default/portable browser
end;

//Default button function is phpMyBackupPro
procedure TMain.Btn_opt3Click(Sender: TObject);
var
  url:string;
begin
  url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/us_opt3/' + US_OPT3_PAGE;
  browser_display_url(url); //Display URL in default/portable browser
end;

procedure TMain.Btn_documentationClick(Sender: TObject);
 var
  url:string;
  PathFslash:string;
begin
  //URL Format eg: URL:='file:///G:/us_traymenu/docs/manual/index.html'

  PathFslash := StringReplace(US_DOCS, '\','/',[rfReplaceAll]);
  url        := 'file:///' + PathFslash + '/manual/index.html';
  browser_display_url(url);  // Display Server documentation page

end;

{====================================================================
Closing the controller (medallion x, title bar x, tray Exit, Alt+F4)
with Apache or MySQL still running as standard programs: they would
keep running invisibly, findable only in the Task Manager. So ask:
stop them first, leave them running, or stay in the controller.
Servers running as Windows services are left alone, they are meant
to outlive the controller (and can only be stopped elevated).
--------------------------------------------------------------------}
procedure TMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  ap_running, my_running: Boolean;
  names, msg: string;
begin
  If USC_CLI_MODE Then Exit;  // Scripts decide themselves (stop/start actions)

  ap_running := ApacheRunning() and not us_IsServiceRunning(USC_APACHE_SERVICE_NAME);
  my_running := MysqlRunning()  and not us_IsServiceRunning(USC_MYSQL_SERVICE_NAME);
  If not (ap_running or my_running) Then Exit;

  If ap_running and my_running Then names := 'Apache and ' + US_MYMAR_TXT + ' are'
  Else If ap_running Then names := 'Apache is'
  Else names := US_MYMAR_TXT + ' is';

  msg := names + ' still running.' + sLineBreak + sLineBreak +
         'Yes: stop the server(s), then close winpacho.' + sLineBreak +
         'No: close winpacho and keep the server(s) running in the' + sLineBreak +
         '      background. They are then only visible in the Task Manager;' + sLineBreak +
         '      start winpacho again to see and stop them.' + sLineBreak + sLineBreak +
         'Close this box with its x to stay in winpacho.';

  If not Main.Visible Then SystrayIconClick(Sender);  // Exit from the tray: show what is being asked about

  Case us_MessageDlg('Close winpacho', msg, mtConfirmation, [mbYes, mbNo], 0) of
    mrYes:
      begin
        If ap_running Then us_kill_apache_program;       // Same as the Stop Apache button
        If my_running Then us_clean_stop_mysql_program;  // Same as the Stop MySQL button
      end;
    mrNo: ;                                             // Leave them running
  Else
    CanClose := False;                                  // Dialog closed with x: stay
  end;
end;

procedure TMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   //--Clean up
  sList_cron.Free;   // Remove from memory
end;

procedure TMain.MMSS_php_acc_zop1Click(Sender: TObject);
begin
   disable_all_php_accelerators; // Disable accelerator

    //Check state of button
    If Main.MMSS_php_acc_zop.Checked = False Then
      enable_php_accelerator('zop');  // Enable Zend OpCache accelerator

    us_update_server_state; // Set button and indicator state
    msg_restart_apache;     // Reminder dialog - Restart apache.
end;

procedure TMain.MMSS_php_developmentClick(Sender: TObject);
begin
   UENV_PHP_INI_SELECT :='php_development.ini';                                 // Set var
   us_ini_set(USF_US_USER_INI,'USER','PHP_INI_SELECT','php_development.ini');   // save to config file
   windows.SetEnvironmentVariable('PHP_INI_SELECT',PCHAR(UENV_PHP_INI_SELECT)); // PHP Ini Select environoment
   us_update_server_state;                                                      // Update menus
   msg_restart_apache;     // Reminder dialog - Restart apache.
end;

procedure TMain.MMSS_php_iniClick(Sender: TObject);
begin
  UENV_PHP_INI_SELECT :='php_test.ini';                                        // Set var
  us_ini_set(USF_US_USER_INI,'USER','PHP_INI_SELECT','php_test.ini');          // save to config file
  windows.SetEnvironmentVariable('PHP_INI_SELECT',PCHAR(UENV_PHP_INI_SELECT)); // PHP Ini Select environoment
  us_update_server_state;                                                      // Update menus
  msg_restart_apache;     // Reminder dialog - Restart apache.
end;

procedure TMain.MMSS_php_productionClick(Sender: TObject);
begin
   UENV_PHP_INI_SELECT :='php_production.ini';                                  // Set var
   us_ini_set(USF_US_USER_INI,'USER','PHP_INI_SELECT','php_production.ini');    // save to config file
   windows.SetEnvironmentVariable('PHP_INI_SELECT',PCHAR(UENV_PHP_INI_SELECT)); // PHP Ini Select environoment
   us_update_server_state;                                                      // Update menus
   msg_restart_apache;     // Reminder dialog - Restart apache.
end;

procedure TMain.MMS_apache_select_root_folder_sslClick(Sender: TObject);
var
  new_folder:string;
  UENV_US_ROOTF_SSL_temp:string;  // Temp for Absolute path

begin
   new_folder :='';   //Initial value
   If us_get_new_root_folder(new_folder,'ssl') Then
    begin
      UENV_US_ROOTF_SSL := new_folder;                                               // Set new root folder var
      UENV_US_ROOTF_SSL := StringReplace(UENV_US_ROOTF_SSL, '\','/',[rfReplaceAll]); // Replace back with forward slashes
      UENV_US_ROOTF_SSL_temp := UENV_US_ROOTF_SSL;                                   // Save full path in _temp

      //Note If path selected is portable replace with environment variable %US_ROOTF% as appropriate
      UENV_US_ROOTF_SSL := StringReplace(UENV_US_ROOTF_SSL,UniConPath_F,'%US_ROOTF%',[rfReplaceAll]);

      us_ini_set(USF_US_USER_INI,'USER','US_ROOTF_SSL',UENV_US_ROOTF_SSL);     // save to config file
      windows.SetEnvironmentVariable('US_ROOTF_SSL',PCHAR(UENV_US_ROOTF_SSL)); // Set environoment variable

      //Update internal as if read from config file - expanded
      UENV_US_ROOTF_SSL := UENV_US_ROOTF_SSL_temp;    // Absolute path

      us_MessageDlg('Apache Info','New Apache root-folder ssl set', mtcustom,[mbOk],0) ; //Display message
      us_update_server_state;                         // Update menus

    end
   Else
     us_MessageDlg('Apache Info','Cancel clicked: No action taken', mtcustom,[mbOk],0) ; //Display message

end;

procedure TMain.Btn_start_mysqlClick(Sender: TObject);
begin
  //--Installed as a Windows service: control the service (UAC), see Apache button
  If (Main.Btn_start_mysql.Caption = START_MY_SVC) or
     (Main.Btn_start_mysql.Caption = STOP_MY_SVC) Then
   begin
     Btn_start_mysql.Enabled := False;                            // No double clicks while sc.exe runs
     try
       us_control_windows_service(USC_MYSQL_SERVICE_NAME,
                                  Main.Btn_start_mysql.Caption = START_MY_SVC);
     finally
       Btn_start_mysql.Enabled := True;
       us_update_server_state;      // Set button and indicator state
     end;
     Exit;
   end;

  If (Main.Btn_start_mysql.Caption  = START_MY) Then
     us_start_mysql_program       // Start MySQL server
  Else
     us_clean_stop_mysql_program; // Stop MySQL server

  us_update_server_state;         // Set button and indicator state
end;

procedure TMain.Btn_server_consoleClick(Sender: TObject);
begin
  us_display_server_console; // Display Console
end;

procedure TMain.Btn_view_wwwClick(Sender: TObject);
var
  url:string;
begin
  url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/';
  browser_display_url(url); // Display URL in default/portable browser
end;

procedure TMain.FormCreate(Sender: TObject);
var
 new_mysql_pwd:string;
begin
  new_mysql_pwd:='';
  Timer1.Enabled := False;          // Disable timer

  //--- Medallion window: the coin artwork is the form (see us_medallion.pas).
  //    Outline and background must exist before the window is first shown;
  //    ApplyGuiStyle below renders it once the chosen look is known.
  DoubleBuffered := True;
  FMedallion     := TUsMedallion.Create;
  Lbl_version.Caption := 'winpacho ' + US_RELOAD_VERSION;
  CreateTrayMenu;                   // Right-click menu of the notification area icon (Show / Exit)

If us_application_is_runable Then   // A draconian check. If a space found in path
                                    // or incorrect location WinpachoController is terminated.
 Begin
  us_command_line_start_up;         // WinpachoController started with parameters. Process and exit application

  us_main_init;                     // Set initial values for variables, paths and environment variables.
  us_rotate_app_logs;               // Rolling logs: MySQL error log, msmtp and cron logs (Apache rotates its own)
  If (ParamCount = 0) Then AskGuiStyleOnce; // First interactive start: classic window or medallion
  ApplyGuiStyle;                    // Shape the window in the chosen look before it is shown
  ApplyDatabaseEngineName;         // Menus and buttons name the installed engine (us_opt.ini), not 'MySQL'
  CreateEngineSwitchMenuItem;       // Database menu: switch between MariaDB and MySQL
  us_auto_generate_ssl_cert;        // First start: generate localhost certificate and enable SSL

  //--- First interactive start: proactively offer to trust the certificate
  //    (asked once) instead of hiding it in Apache > Apache SSL.
  //    Skipped for command line and PC-Win start-up runs (no dialogs there).
  If (ParamCount = 0) Then us_offer_trust_ssl_cert_once;
  If (ParamCount = 0) Then us_check_legacy_autostart; // "Start with Windows" entry from 2.0.0 still names UniController.exe
  us_update_server_state;           // Set button and indicator state
  us_update_go_pear_config;         // Update go-pear configuration file if it exists
  us_check_servers_are_runable;     // Warnings ports in use, ZoneAlarm running

   //---Set MySQL password if root password detected
   If DirectoryExists(US_MYSQL)           // Check MySQL installed
    and (us_get_mysql_password()= 'root') // Check new password not already set
    and (USC_NAG_USER)                    // Check user wants tobe reminded
    and MySqlPortFree                     // Check port is free to use
    and Not MySqlRunning                  // Cannot change password if running
   Then
    begin  // Set new root password or allow user to cancel
      If us_get_new_pwd(MY_PWD,new_mysql_pwd) Then   // Get new password. If set change password.
        mysql_change_root_password(new_mysql_pwd)    // Change existing password
      Else
         us_MessageDlg(US_MYMAR_TXT+' Info','Cancel clicked: No action taken', mtcustom,[mbOk],0); //Display information message
    end;

  us_set_icon_and_hover_text;      // Set icon displayed and hover text based on ServerType in config file

  //---TrayIcon - If enabled miniimise to TrayIcon
  If USC_TrayIconEnabled Then
   begin
     Main.visible:=False;                // Hide form
     Main.ShowInTaskBar := stNever;      // Hide from taskbar
     Application.ShowMainForm  := False; // Hide application
     SystrayIcon.Show;                   // Enable trayicon
   end;

  //--- If WinpachoController not started by a PC-Win start-up
  //    then display main form.
  If (ParamCount = 0) Then
   begin
    Application.ShowMainForm  := True; // Show application
   end;

  //--- If WinpachoController was started by a PC-Win start-up the following are
  //    automaticly started. Note: Parameter "pc_win_start" passed will initiate auto-run
  If (ParamCount >= 1) and (ParamStr(1) = 'pc_win_start') Then
   begin
     //showmessage('Auto run detected '+ParamStr(1));
     //== Items to run are defined in config file us_config.ini

     //Apache
     sleep(1000);
     If USC_RunApacheAtStartUp Then us_start_apache_program; // Start Apache

     //MySQL
     sleep(1000);
     If USC_RunMysqlAtStartUp Then us_start_mysql_program;   // Start MySQL

     //Update server state
     sleep(1000);
     us_update_server_state; // Set button and indicator state
   end;

  //OK to start timmed processes
  Timer1.Enabled := True;    // Enable timer
  end //us_application_is_runable
 else
  Application.Terminate;                         // Exit application
end;

procedure TMain.MMS_clean_upClick(Sender: TObject);
begin
  us_clean_up;     // Delete all files listed in config us_clean_up.ini
end;

procedure TMain.MMS_cronClick(Sender: TObject);
begin
  cron.ShowModal;  // Display Cron menu
end;

procedure TMain.MMS_edit_selected_php_configClick(Sender: TObject);
begin
  //==Edit selected PHP configuration file

    //--PHP 70 selected
    If UENV_PHP_SELECT ='php70' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_70);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_70);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_70);
      end;
     //--End PHP 70 selected

    //--PHP 71 selected
    If UENV_PHP_SELECT ='php71' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_71);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_71);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_71);
      end;
     //--End PHP 71 selected

    //--PHP 72 selected
    If UENV_PHP_SELECT ='php72' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_72);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_72);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_72);
      end;
     //--End PHP 72 selected

    //--PHP 73 selected
    If UENV_PHP_SELECT ='php73' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_73);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_73);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_73);
      end;
     //--End PHP 73 selected

    //--PHP 74 selected
    If UENV_PHP_SELECT ='php74' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_74);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_74);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_74);
      end;
     //--End PHP 74 selected

    //--PHP 80 selected
    If UENV_PHP_SELECT ='php80' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_80);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_80);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_80);
      end;
      //--End PHP 80 selected

    //--PHP 81 selected
    If UENV_PHP_SELECT ='php81' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_81);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_81);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_81);
      end;
     //--End PHP 81 selected

    //--PHP 82 selected
    If UENV_PHP_SELECT ='php82' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_82);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_82);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_82);
      end;
     //--End PHP 82 selected

     //--PHP 83 selected
    If UENV_PHP_SELECT ='php83' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_83);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_83);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_83);
      end;
     //--End PHP 83 selected

     //--PHP 84 selected
    If UENV_PHP_SELECT ='php84' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_84);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_84);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_84);
      end;
     //--End PHP 84 selected

     //--PHP 85 selected
    If UENV_PHP_SELECT ='php85' then
      begin
       //Edit config php_test.ini
           If UENV_PHP_INI_SELECT ='php_test.ini' Then
              us_display_in_editor(USF_PHP_INI_TEST_85);

       //Edit config php_development.ini
           If UENV_PHP_INI_SELECT ='php_development.ini' Then
              us_display_in_editor(USF_PHP_INI_DEV_85);

       //Edit config php_production.ini
           If UENV_PHP_INI_SELECT ='php_production.ini' Then
               us_display_in_editor(USF_PHP_INI_PROD_85);
      end;
     //--End PHP 85 selected
end;

procedure TMain.MMS_edit_uniformserver_pacClick(Sender: TObject);
begin
  us_display_in_editor(USF_PAC);  //View Edit PAC file
end;

procedure TMain.MMS_force_unix_shebangClick(Sender: TObject);
begin
   force_shebang_update(US_UNIX_SHEBANG); // Update to Unix shebang in all perl scripts
   us_MessageDlg('Perl Info','Perl Shebangs have been updated', mtcustom,[mbOk],0) ; //Display information message
end;

procedure TMain.MMS_force_windows_shebangClick(Sender: TObject);
begin
 force_shebang_update(US_WINDOWS_SHEBANG); // Update to Windows shebang in all perl scripts
    us_MessageDlg('Perl Info','Perl Shebangs have been updated', mtcustom,[mbOk],0) ; //Display information message
end;

procedure TMain.MMS_hostsClick(Sender: TObject);
begin
  us_launch_edit_hosts_utility; // Run Uniform Server Utility (asks for administrator rights)
  // The controller stays on screen. Upstream minimized here, and with the
  // tray icon enabled "minimized" means hidden into the notification area:
  // the window seemed to have vanished the moment the menu entry was clicked.
end;

procedure TMain.MMS_uniserviceClick(Sender: TObject);
begin
  us_display_uniservice; // Launch service module (Windows shows the UAC prompt)
end;

procedure TMain.MMS_mysql_change_portClick(Sender: TObject);
 var
   new_mysql_port:string;
begin
  new_mysql_port:= '';

  If MysqlRunning() Then
     msg_stop_mysql_port_change // Inform user to stop MySQL server
  Else                          // Not running change port
    begin
      If us_get_new_port(UENV_MYSQL_TCP_PORT,new_mysql_port,'3306') Then
       begin
         UENV_MYSQL_TCP_PORT := new_mysql_port;                                       // Set var
         us_ini_set(USF_US_USER_INI,'USER','MYSQL_TCP_PORT',UENV_MYSQL_TCP_PORT);     // save to config file
         windows.SetEnvironmentVariable('MYSQL_TCP_PORT',PCHAR(UENV_MYSQL_TCP_PORT)); // Set environoment variable
         us_update_server_state;                                                      // Update menus
         us_MessageDlg(US_MYMAR_TXT+' Info','Port was changed', mtcustom,[mbOk],0) ; //Display information message
       end
      Else
        us_MessageDlg(US_MYMAR_TXT+' Info','Cancel clicked: No action taken', mtcustom,[mbOk],0) ; //Display information message
    end;
end;

procedure TMain.MMS_mysql_change_pwdClick(Sender: TObject);
var
 new_mysql_pwd:string;        // New root password to create
begin
 new_mysql_pwd:= '';
 If us_get_new_pwd(MY_PWD,new_mysql_pwd) Then   // Get new password. If set change password.
   mysql_change_root_password(new_mysql_pwd)    // Change existing password
 Else
   us_MessageDlg(US_MYMAR_TXT+' Info','Cancel clicked: No action taken', mtcustom,[mbOk],0); //Display information message
end;

procedure TMain.MMS_mysql_create_userClick(Sender: TObject);
begin
    mysql_create_restricted_user.ShowModal;     //Display Create MySQL user;
end;

procedure TMain.MMS_mysql_database_backupClick(Sender: TObject);
begin
  mysql_database_backup.ShowModal;     //Display Database backup;
end;

procedure TMain.MMS_mysql_database_create_deleteClick(Sender: TObject);
begin
  mysql_db_create_delete.ShowModal;     //Display Database create-delete;
end;

procedure TMain.MMS_mysql_database_restoreClick(Sender: TObject);
begin
  mysql_database_restore.ShowModal;     //Display Database restore;
end;

procedure TMain.MMS_mysql_edit_configClick(Sender: TObject);
begin
    us_display_in_editor(USF_MYSQL_INI);
end;

procedure TMain.MMS_mysql_edit_userClick(Sender: TObject);
begin
  mysql_edit_restricted_user.ShowModal;     //Display Edit MySQL user;
end;

procedure TMain.MMS_mysql_error_logClick(Sender: TObject);
begin
  us_display_in_editor(USF_MYSQL_ERROR_LOG);
end;

procedure TMain.MMS_mysql_restore_root_pwdClick(Sender: TObject);
begin
   mysql_restore_root_password;     // Restore MySql root password
   us_update_server_state;
end;

procedure TMain.MMS_pc_win_startupClick(Sender: TObject);
begin
    pc_win_startup.ShowModal;     //Display PC-Win start-up
end;

//procedure TMain.MMS_pear_frontendClick(Sender: TObject);
// var
//  url :String;
//begin
// url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/us_pear/index.php';
// browser_display_url(url); // Display URL in default/portable browser
//end;

procedure TMain.MMS_perl_view_test_plClick(Sender: TObject);
var
  url :string;
begin
   url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/cgi-bin/test.pl';
   browser_display_url(url); // Display URL in default/portable browser
end;


procedure TMain.MMS_php_mail_msmtpClick(Sender: TObject);
begin
  msmtp_php_mail.ShowModal;
end;

procedure TMain.MMS_php_view_accelerator_control_panelClick(Sender: TObject);
begin
  view_selected_acc_control_panel;  // View selected accelerator, control pannel
end;

procedure TMain.MMS_select_php_versionClick(Sender: TObject);
begin

end;

procedure TMain.MMS_shebang_helpClick(Sender: TObject);
var
 title:string;
 str:string;
begin
  title     := 'Perl Shebang Help';
  str:='';
  str := str + 'Perl scripts developed on Unix will not run on a Window machine;' + sLineBreak;
  str := str + 'the Shebang requires conversion to a Windows format.' + sLineBreak+ sLineBreak;

  str := str + 'The Shebang allows Apache to find the Perl interpreter.' + sLineBreak;
  str := str + 'Windows Shebang - First line of a Perl script:' + sLineBreak;
  str := str + '#!perl' + sLineBreak+ sLineBreak;

  str := str + 'Note 1: After installing third-party scripts to the cgi-bin folder,' + sLineBreak;
  str := str + 'force a Windows Shebang update by running "Force Windows Shebang"' + sLineBreak;
  str := str + 'from the Perl drop-down menu.' + sLineBreak+ sLineBreak;

  str := str + 'Note 2: Before uploading scripts from the cgi-bin folder to a Unix server,' + sLineBreak;
  str := str + 'force a Unix Shebang update by running "Force Unix Shebang"' + sLineBreak;
  str := str + 'from the Perl drop-down menu.' + sLineBreak;

  us_MessageDlg(title, str, mtInformation,[mbOk],0) ;  //Display message
end;

procedure TMain.MMS_select_portable_browserClick(Sender: TObject);
begin
 If Main.MMS_select_portable_browser.Checked Then
  begin
    Main.MMS_select_portable_browser.Checked := False;
    Main.MMS_select_default_browser.Checked  := True;
    PortableBrowser                          := False; // Portable browser flag
  end
 Else
  begin
   Main.MMS_select_portable_browser.Checked := True;
   Main.MMS_select_default_browser.Checked  := False;
   PortableBrowser                          := True; // Portable browser flag
  end;
end;

procedure TMain.MMS_select_default_browserClick(Sender: TObject);
begin
 If Main.MMS_select_default_browser.Checked Then
  begin
    Main.MMS_select_portable_browser.Checked := True;
    Main.MMS_select_default_browser.Checked  := False;
    PortableBrowser                          := True; // Portable browser flag
  end
 Else
  begin
   Main.MMS_select_portable_browser.Checked := False;
   Main.MMS_select_default_browser.Checked  := True;
   PortableBrowser                          := False; // Portable browser flag
  end;
 end;

procedure TMain.MMS_view_phpinfoClick(Sender: TObject);
var
 url :String;
begin
  url := 'http://' + UENV_US_SERVERNAME + ':' + UENV_AP_PORT + '/us_extra/phpinfo.php';
  browser_display_url(url); // Display URL in default/portable browser
end;

procedure TMain.MM_aboutClick(Sender: TObject);
begin
  about.ShowModal;                              //Display About;
end;

procedure TMain.SystrayIconClick(Sender: TObject);
begin
   Main.ShowInTaskBar := stDefault;   //Back on the taskbar (tray minimize removed it)
   Application.Restore;               //Minimized via taskbar: restore as well
   Main.Show;              //Show main form
   Main.BringToFront;
   us_update_server_state; //State may have changed while hidden in the tray
end;

{====================================================================
Notification area icon: right-click menu. While the controller is
minimized into the tray the medallion is hidden and has no taskbar
entry, so without this menu the only way to quit was to click the
icon, wait for the window and close that. The menu is built in code
(no designer entry) and attached to SystrayIcon at start-up.
--------------------------------------------------------------------}
procedure TMain.CreateTrayMenu;
var
  item: TMenuItem;
begin
  FTrayMenu := TPopupMenu.Create(Self);

  item := TMenuItem.Create(FTrayMenu);
  item.Caption := 'Show winpacho';
  item.Default := True;                       // bold: what a left click does
  item.OnClick := @TrayShowClick;
  FTrayMenu.Items.Add(item);

  item := TMenuItem.Create(FTrayMenu);
  item.Caption := '-';
  FTrayMenu.Items.Add(item);

  item := TMenuItem.Create(FTrayMenu);
  item.Caption := 'Exit winpacho';
  item.OnClick := @TrayExitClick;
  FTrayMenu.Items.Add(item);

  SystrayIcon.PopUpMenu := FTrayMenu;
end;

procedure TMain.TrayShowClick(Sender: TObject);
begin
  SystrayIconClick(Sender);
end;

procedure TMain.TrayExitClick(Sender: TObject);
begin
  Close;                  // same path as the medallion's x button
end;

{====================================================================
Switch database engine. The bundle ships MariaDB and MySQL (since
2.4.0): the active one in core\mysql, the other in core\db_standby
(us_db_engine.pas swaps them). Someone who needs the other engine looks
in the database menu first, so the switch lives there as its last
entry. Built in code after ApplyDatabaseEngineName; the entry is shown
even without a standby engine, and then says how to get one.
--------------------------------------------------------------------}
procedure TMain.CreateEngineSwitchMenuItem;
var
  item: TMenuItem;
begin
  if FEngineSwitchItem <> nil then Exit;
  item := TMenuItem.Create(MM_mysql);
  item.Caption := '-';
  MM_mysql.Add(item);

  FEngineSwitchItem := TMenuItem.Create(MM_mysql);
  FEngineSwitchItem.OnClick := @EngineSwitchClick;
  MM_mysql.Add(FEngineSwitchItem);
  UpdateEngineSwitchItem;
end;

procedure TMain.UpdateEngineSwitchItem;
begin
  if FEngineSwitchItem = nil then Exit;
  FEngineSwitchItem.Caption := 'Switch database engine to ' + us_db_standby_engine + '...';
end;

procedure TMain.EngineSwitchClick(Sender: TObject);
var
  blocker, str, other: string;
begin
  other   := us_db_standby_engine;
  blocker := us_db_switch_blocker;
  if blocker <> '' then
  begin
    us_MessageDlg('Switch database engine', blocker, mtInformation, [mbOk], 0);
    Exit;
  end;

  str := 'Active now: ' + US_MYMAR_TXT + '. Make ' + other + ' the active database engine?' + sLineBreak + sLineBreak +
         'What happens:' + sLineBreak +
         '- ' + US_MYMAR_TXT + ' moves complete, with all its databases and users, to' + sLineBreak +
         '  ' + us_db_standby_folder(US_MYMAR_TXT) + sLineBreak +
         '  and waits there. Nothing is deleted; switching back brings it back.' + sLineBreak +
         '- ' + other + ' takes its place in core\mysql, on the same port ' + UENV_MYSQL_TCP_PORT + '.' + sLineBreak +
         '  Apps, Adminer and PHP (mysqli, PDO) connect to it as before.' + sLineBreak + sLineBreak +
         'The two engines cannot read each other''s data folder, so each one has' + sLineBreak +
         'its own databases, users and root password. To take databases along:' + sLineBreak +
         US_MYMAR_TXT + ' > Database backup now, then after the switch ' + other + ' > Database' + sLineBreak +
         'restore. Restricted users need to be created again in ' + other + '.' + sLineBreak + sLineBreak +
         'When to choose MySQL: the live server of your app (web hosting) runs MySQL,' + sLineBreak +
         'or the app relies on MySQL features such as the binary JSON type.' + sLineBreak +
         'MariaDB stores JSON as text with the same functions.';
  if us_MessageDlg('Switch database engine to ' + other, str, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if SwitchDatabaseEngine then
  begin
    ApplyDatabaseEngineName;  // captions: old engine name -> new one
    us_update_server_state;   // start button text, database menu caption
    SyncMenuTabs;
  end;
end;

{ Swaps the engines (us_db_engine.pas) and tells the user the outcome:
  the next step on success, the cause and the way out on failure. }
function TMain.SwitchDatabaseEngine: Boolean;
var
  msg, str: string;
begin
  Result := us_db_switch_engine(msg);
  if not Result then
  begin
    us_MessageDlg('Database engine not switched', msg, mtWarning, [mbOk], 0);
    Exit;
  end;
  str := US_MYMAR_TXT + ' is the active database engine now (folder core\mysql).' + sLineBreak +
         'Start it with the button Start ' + US_MYMAR_TXT + '. Its root password is the one it' + sLineBreak +
         'had when it was last active (as shipped: root).' + sLineBreak +
         'Switch back at any time: ' + US_MYMAR_TXT + ' > Switch database engine to ' + us_db_standby_engine + '.';
  if msg <> '' then str := str + sLineBreak + sLineBreak + msg;   // warning about the password file
  us_MessageDlg('Database engine switched', str, mtInformation, [mbOk], 0);
end;


{====================================================================
Toggle: minimize to system tray.
UI switch for TrayIconEnabled in us_config.ini, previously ini-only.
Off (default since 1.3.15): the window stays on the taskbar like any
other program. On: the window's own minimize button (medallion minus,
classic title bar) hides it into the notification area.
--------------------------------------------------------------------}
procedure TMain.MMS_tray_iconClick(Sender: TObject);
begin
 If Main.MMS_tray_icon.Checked Then
  begin
    Main.MMS_tray_icon.Checked := False;                            // Set to un-checked
    USC_TrayIconEnabled := False;                                   // Stay in taskbar when minimized
    us_ini_set(USF_US_CONF_INI,'APP','TrayIconEnabled','False');    // save to config file
    SystrayIcon.Hide;                                               // No tray icon without the option
  end
 Else
  begin
    Main.MMS_tray_icon.Checked := True;                             // Set to checked
    USC_TrayIconEnabled := True;                                    // Minimize to system tray
    us_ini_set(USF_US_CONF_INI,'APP','TrayIconEnabled','True');     // save to config file
    // The icon is otherwise only shown at start-up; without it a window
    // minimized to the tray could not be brought back.
    us_set_icon_and_hover_text;
    SystrayIcon.Show;
  end;
 us_update_server_state;                                            // Minimize button hint
end;


{====================================================================
This procedure periodically runs Cron.
If Cron is disabled the section is skipped.
Every fifth tick the server state is refreshed so changes made
outside this program (WinpachoService installing/starting the services,
services.msc) show up without user interaction.
--------------------------------------------------------------------}
procedure TMain.Timer1Timer(Sender: TObject);
begin
 Timer1.Enabled := False; //Disable timer

 //--- Auto run Cron
 If USC_enable_cron Then run_cron;            // Run Cron

 //--- Periodic server-state refresh
 Inc(state_refresh_tick);
 If state_refresh_tick >= 5 Then
  begin
    state_refresh_tick := 0;
    If Main.Visible Then us_update_server_state; // Update buttons/indicators/menus
  end;

 //--- Rolling logs, also while the controller just sits in the tray
 Inc(log_rotate_tick);
 If log_rotate_tick >= LOG_ROTATE_CHECK_TICKS Then
  begin
    log_rotate_tick := 0;
    us_rotate_app_logs;
  end;

 Timer1.Enabled := True;  //Enable timer
end;




end.

