unit frmautoinjectunit;

{$MODE Delphi}

interface

uses
  windows, LCLIntf, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Menus, CEFuncProc, StrUtils, types, ComCtrls, LResources,
  NewKernelHandler, SynEdit, SynHighlighterCpp, SynHighlighterAA, LuaSyntax, disassembler,
  MainUnit2, Assemblerunit, autoassembler, symbolhandler, SynEditSearch,
  MemoryRecordUnit, tablist, customtypehandler, registry, SynGutterBase, SynEditMarks,
  luahandler, memscan, foundlisthelper, ProcessHandlerUnit, commonTypeDefs;


type TCallbackRoutine=procedure(memrec: TMemoryRecord; script: string; changed: boolean) of object;
type TCustomCallbackRoutine=procedure(ct: TCustomType; script:string; changed: boolean; lua: boolean) of object;

type TScripts=array of record
                script: string;
                filename: string;
                undoscripts: array [0..4] of record
                               oldscript: string;
                               startpos: integer;
                             end;
                currentundo: integer;
              end;

type TBooleanArray = Array of Boolean;

{
The TDisassemblyLine originates from jgoemat  ( http://forum.cheatengine.org/viewtopic.php?t=566415 )
Originally it was just an Object but I changed it to a TObject because I think a
standalone TDisassembler object might be more efficient reducing the amount of
string parsing
}
type TDisassemblyLine = class(TObject)
  Address: ptrUint;                // actual address value
  AddressString: String;           // module+offset if specified
  Comment: String;                 // comment part (second parameter of disassembly)
  OriginalHexBytes : String;       // original hex from disassembly (grouped)
  Code: String;                    // code portion of disassembly
  Size: Integer;                   // number of bytes for this instruction
  Disassembler: TDisassembler;     // The disassembler used to disassemble (free by caller)

  procedure Init(_address: ptrUint; _mi: TModuleInfo);
  procedure Shorten(_newsize: Integer); // if we overran our injection point, change to 'db'
  function IsStarter : Boolean;
  function IsEnder : Boolean;
  function IsValid : Boolean;
  function GetHexBytes : String; // hex bytes with spaces between each byte
  function GetMaskFlags : TBooleanArray;
  constructor create;
  destructor destroy; override;
end;

type TAOBFind = Object
  Address: ptrUint;               // address where AOB was found
  CodeSize: Integer;              // size of code we will always use
  Size: Integer;
  Bytes: Array of Byte;           // bytes we'll read from memory

  procedure Init(_address: ptrUint; _codesize: Integer);
  function IsMatch(var maskBytes: Array Of Byte; var maskFlags : TBooleanArray; startIndex, endIndex: Integer): Boolean;
end;

type TScriptMode=(smAutoAssembler, smLua, smGnuAssembler);

type

  { TfrmAutoInject }

  TfrmAutoInject = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    menuAOBInjection: TMenuItem;
    menuFullInjection: TMenuItem;
    mifindNext: TMenuItem;
    miCallLua: TMenuItem;
    miNewWindow: TMenuItem;
    Panel1: TPanel;
    Button1: TButton;
    Load1: TMenuItem;
    Panel2: TPanel;
    Save1: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    Exit1: TMenuItem;
    Assigntocurrentcheattable1: TMenuItem;
    emplate1: TMenuItem;
    Codeinjection1: TMenuItem;
    CheatTablecompliantcodee1: TMenuItem;
    APIHook1: TMenuItem;
    SaveAs1: TMenuItem;
    PopupMenu1: TPopupMenu;
    Coderelocation1: TMenuItem;
    New1: TMenuItem;
    N2: TMenuItem;
    Syntaxhighlighting1: TMenuItem;
    closemenu: TPopupMenu;
    Close1: TMenuItem;
    Inject1: TMenuItem;
    Injectincurrentprocess1: TMenuItem;
    Injectintocurrentprocessandexecute1: TMenuItem;
    Find1: TMenuItem;
    Paste1: TMenuItem;
    Copy1: TMenuItem;
    Cut1: TMenuItem;
    Undo1: TMenuItem;
    N6: TMenuItem;
    FindDialog1: TFindDialog;
    undotimer: TTimer;
    View1: TMenuItem;
    AAPref1: TMenuItem;
    procedure Button1Click(Sender: TObject);
    procedure Load1Click(Sender: TObject);
    procedure menuAOBInjectionClick(Sender: TObject);
    procedure menuFullInjectionClick(Sender: TObject);
    procedure mifindNextClick(Sender: TObject);
    procedure miCallLuaClick(Sender: TObject);
    procedure miNewWindowClick(Sender: TObject);
    procedure Save1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Codeinjection1Click(Sender: TObject);
    procedure Panel1Resize(Sender: TObject);
    procedure CheatTablecompliantcodee1Click(Sender: TObject);

    procedure Assigntocurrentcheattable1Click(Sender: TObject);
    procedure APIHook1Click(Sender: TObject);
    procedure SaveAs1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure assemblescreenKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Coderelocation1Click(Sender: TObject);
    procedure New1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure TabControl1Change(Sender: TObject);
    procedure Syntaxhighlighting1Click(Sender: TObject);
    procedure TabControl1ContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure Close1Click(Sender: TObject);
    procedure Injectincurrentprocess1Click(Sender: TObject);
    procedure Injectintocurrentprocessandexecute1Click(Sender: TObject);
    procedure Cut1Click(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure Paste1Click(Sender: TObject);
    procedure Find1Click(Sender: TObject);
    procedure FindDialog1Find(Sender: TObject);
    procedure AAPref1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Undo1Click(Sender: TObject);
  private
    { Private declarations }

    AAHighlighter: TSynAASyn;
    CPPHighlighter: TSynCppSyn;
    LuaHighlighter: TSynLuaSyn;

    assembleSearch: TSynEditSearch;

    oldtabindex: integer;
    scripts: TScripts;

    selectedtab: integer;


    fScriptMode: TScriptMode;
    fluamode: boolean;
    fCustomTypeScript: boolean;

    procedure setluamode(state: boolean);
    procedure setScriptMode(mode: TScriptMode);

    procedure injectscript(createthread: boolean);
    procedure tlistOnTabChange(sender: TObject; oldselection: integer);
    procedure setCustomTypeScript(x: boolean);
    procedure gutterclick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
    procedure assemblescreenchange(sender: TObject);
    function GetUniqueAOB(mi: TModuleInfo; address: ptrUint; codesize: Integer; var resultOffset: Integer) : string;

  public
    { Public declarations }

    assemblescreen: TSynEdit;
    tlist: TTablist;

    editscript: boolean;
    editscript2: boolean;
    memrec: TMemoryRecord;

    customtype: TCustomType;

    callbackroutine: TCallbackroutine;
    CustomTypeCallback: TCustomCallbackroutine;
    injectintomyself: boolean;
    property CustomTypeScript: boolean read fCustomTypeScript write setCustomTypeScript;
    property ScriptMode: TScriptMode read fScriptMode write setScriptMode;
  end;


procedure Getjumpandoverwrittenbytes(address,addressto: ptrUINT; jumppart,originalcodepart: tstrings);
procedure generateAPIHookScript(script: tstrings; address: string; addresstogoto: string; addresstostoreneworiginalfunction: string=''; nameextension:string='0');



implementation


uses frmAAEditPrefsUnit,MainUnit,memorybrowserformunit,APIhooktemplatesettingsfrm,
  Globals, Parsers, MemoryQuery, GnuAssembler;

resourcestring
  rsExecuteScript = 'Execute script';
  rsLuaFilter = 'LUA Script (*.LUA)|*.LUA|All Files ( *.* )|*.*';
  rsLUAScript = 'LUA Script';
  rsGNUAScript = 'GNU Assembler Script';
  rsWriteCode = 'Write code';
  rsCEAFilter = 'Cheat Engine Assembly (*.CEA)|*.CEA|All Files ( *.* )|*.*';
  rsCEGAFilter = 'Cheat Engine GNU Assembly (*.CEGA)|*.CEGA|All Files ( *.* )|*.*';
  rsAutoAssembler = 'Auto assembler';
  rsCodeNeedsEnableAndDisable = 'The code needs an [ENABLE] and a [DISABLE] section if you want to use this script as a table entry';
  rsNotAllCodeIsInjectable = 'Not all code is injectable.'#13#10'%s'#13#10'Are you sure you wan''t to edit it to this?';
  rsCodeInjectTemplate = 'Code inject template';
  rsOnWhatAddressDoYouWantTheJump = 'On what address do you want the jump?';
  rsFailedToAddToTableNotAllCodeIsInjectable = 'Failed to add to table. Not all code is injectable';
  rsStartAddress = 'Start address';
  rsCodeRelocationTemplate = 'Code relocation template';
  rsEndAddressLastBytesAreIncludedIfNecesary = 'End address (last bytes are included if necessary)';
  rsAreYouSureYouWantToClose = 'Are you sure you want to close %s ?';
  rsWhatIdentifierDoYouWantToUse = 'What do you want to name the symbol for the injection point?';

procedure TfrmAutoInject.setCustomTypeScript(x: boolean);
begin
  fCustomTypeScript:=x;
  if x then
    editscript:=true;
end;

procedure TfrmAutoInject.setScriptMode(mode: TScriptMode);
begin
  fScriptMode:=mode;
  case mode of
    smLua:
    begin
      assemblescreen.Highlighter:=LuaHighlighter;

      //change gui to lua style
      button1.Caption:=rsExecuteScript;
      opendialog1.DefaultExt:='LUA';
      opendialog1.Filter:=rsLuaFilter;
      savedialog1.DefaultExt:='LUA';
      savedialog1.Filter:=rsLuaFilter;
      Assigntocurrentcheattable1.visible:=false;
      emplate1.Visible:=false;
      caption:=rsLUAScript;
     // inject1.Visible:=true;
      helpcontext:=19; //c-script help
    end;

    smAutoAssembler:
    begin
      assemblescreen.Highlighter:=AAHighlighter;


      //change gui to autoassembler style
      button1.caption:=rsWriteCode;
      opendialog1.DefaultExt:='CEA';
      opendialog1.Filter:=rsCEAFilter;
      savedialog1.DefaultExt:='CEA';
      savedialog1.Filter:=rsCEAFilter;
      Assigntocurrentcheattable1.Visible:=true;
      emplate1.Visible:=true;
      caption:=rsAutoAssembler;
      inject1.Visible:=false;
      helpcontext:=18; //auto asm help
    end;

    smGnuAssembler:
    begin
      assemblescreen.Highlighter:=nil; //no highlighter for it yet

      button1.Caption:=rsWriteCode;
      opendialog1.DefaultExt:='CEGA';
      opendialog1.Filter:=rsCEGAFilter;
      savedialog1.DefaultExt:='CEGA';
      savedialog1.Filter:=rsCEGAFilter;
      Assigntocurrentcheattable1.visible:=true; //yup
      emplate1.Visible:=false; //no templates right now
      caption:=rsGNUAScript;
    end;

  end;
end;

procedure TfrmAutoInject.setluamode(state: boolean);
begin

end;


procedure TfrmAutoInject.Button1Click(Sender: TObject);
var
    a,b: integer;

    aa: TCEAllocArray;

    //variables for injectintomyself:
    check: boolean;
    registeredsymbols: TStringlist;
    errmsg: string;
begin
{$ifndef standalonetrainerwithassembler}
  registeredsymbols:=tstringlist.Create;
  registeredsymbols.CaseSensitive:=false;
  registeredsymbols.Duplicates:=dupIgnore;

  case scriptmode of
    smlua:
    begin
      //execute
      LUA_DoScript(assemblescreen.Text);
      modalresult:=mrok; //not modal anymore, but can still be used to pass info
      if editscript2 or CustomTypeScript then close;
    end;

    smAutoAssembler:
    begin
      if editscript then
      begin
        //check if both scripts are valid before allowing the edit

        setlength(aa,1);
        getenableanddisablepos(assemblescreen.Lines,a,b);
        if not CustomTypeScript then
          if (a=-1) and (b=-1) then raise exception.create(rsCodeNeedsEnableAndDisable);


        try
          check:=autoassemble(assemblescreen.lines,false,true,true,injectintomyself,aa,registeredsymbols) and
                 autoassemble(assemblescreen.lines,false,false,true,injectintomyself,aa,registeredsymbols);

          if not check then
            errmsg:=format(rsNotAllCodeIsInjectable,['']);
        except
          on e: exception do
          begin
            check:=false;
            errmsg:=format(rsNotAllCodeIsInjectable,['('+e.Message+')']);
          end;
        end;

        if check then
        begin
          modalresult:=mrok; //not modal anymore, but can still be used to pass info
          if editscript2 or CustomTypeScript then close; //can only be used when not modal
        end
        else
        begin
          if messagedlg(errmsg, mtWarning, [mbyes, mbno], 0)=mryes then
          begin
            modalresult:=mrok; //not modal anymore, but can still be used to pass info
            if editscript2 or CustomTypeScript then close;
          end;
        end;
      end else autoassemble(assemblescreen.lines,true);
    end;

    smGnuAssembler:
    begin
      GnuAssemble(assemblescreen.lines);

    end;

  end;
  registeredsymbols.free;
{$endif}
end;

procedure TfrmAutoInject.Load1Click(Sender: TObject);
begin
{$ifndef standalonetrainerwithassembler}

  if opendialog1.Execute then
  begin

    assemblescreen.Lines.Clear;
    assemblescreen.Lines.LoadFromFile(opendialog1.filename);
    savedialog1.FileName:=opendialog1.filename;
    assemblescreen.AfterLoadFromFile;

  end;
{$endif}
end;

procedure TfrmAutoInject.mifindNextClick(Sender: TObject);
begin
  finddialog1.OnFind(finddialog1);
end;



procedure TfrmAutoInject.miNewWindowClick(Sender: TObject);
var f: TfrmAutoInject;
begin
  f:=TfrmAutoInject.Create(application);
  f.scriptmode:=ScriptMode;

  f.show;
end;

procedure TfrmAutoInject.Save1Click(Sender: TObject);
var f: tfilestream;
    s: string;
begin
  if (savedialog1.filename='') and (not savedialog1.Execute) then exit;   //filename was empty and the user clicked cancel

  f:=tfilestream.Create(savedialog1.filename,fmcreate);
  try
    s:=assemblescreen.text;
    f.Write(s[1],length(assemblescreen.text));

    assemblescreen.MarkTextAsSaved;

  finally
    f.Free;
  end;
end;

procedure TfrmAutoInject.Exit1Click(Sender: TObject);
begin
  close;
end;

procedure TfrmAutoInject.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
{$ifndef standalonetrainerwithassembler}

  if not editscript then
  begin
    if self<>MainForm.frmLuaTableScript then //don't free the lua table script
      action:=cafree;
  end
  else
  begin
    try
      if editscript2 then
      begin
        //call finish routine with script

        if modalresult=mrok then
          callbackroutine(memrec, assemblescreen.text,true)
        else
          callbackroutine(memrec, assemblescreen.text,false);

        action:=cafree;
      end
      else
      if CustomTypeScript then
      begin

        if modalresult=mrok then
          CustomTypeCallback(customtype, assemblescreen.text,true,scriptmode=smLua)
        else
          CustomTypeCallback(customtype, assemblescreen.text,false,scriptmode=smLua);

        action:=cafree;
      end;

    except
      on e: exception do
      begin
        modalresult:=mrNone;
        raise exception.create(e.message);
      end;
    end;
  end;
{$endif}
end;

procedure TfrmAutoInject.Codeinjection1Click(Sender: TObject);
function inttostr(i:int64):string;
begin
  if i=0 then result:='' else result:=sysutils.IntToStr(i);
end;

var address: string;
    originalcode: array of string;
    originalbytes: array of byte;
    codesize: integer;
    a: ptrUint;
    br: ptruint;
    c: ptrUint;
    x: string;
    i,j,k: integer;
    injectnr: integer;

    enablepos: integer;
    disablepos: integer;
    enablecode: tstringlist;
    disablecode: tstringlist;

    mi: TModuleInfo;
begin
{$ifndef standalonetrainerwithassembler}
  if parent is TMemoryBrowser then
    a:=TMemoryBrowser(parent).disassemblerview.SelectedAddress
  else
    a:=memorybrowser.disassemblerview.SelectedAddress;


  if symhandler.getmodulebyaddress(a,mi) then
    address:='"'+mi.modulename+'"+'+inttohex(a-mi.baseaddress,1)
  else
    address:=symhandler.getNameFromAddress(a);

  if inputquery(rsCodeInjectTemplate, rsOnWhatAddressDoYouWantTheJump, address) then
  begin
    try
      a:=StrToQWordEx('$'+address);
    except
      a:=symhandler.getaddressfromname(address);
    end;

    c:=a;

    injectnr:=0;
    for i:=0 to assemblescreen.Lines.Count-1 do
    begin
      j:=pos('alloc(newmem',lowercase(assemblescreen.lines[i]));
      if j<>0 then
      begin
        x:=copy(assemblescreen.Lines[i],j+12,length(assemblescreen.Lines[i]));
        x:=copy(x,1,pos(',',x)-1);
        try
          k:=strtoint(x);
          if injectnr<=k then
            injectnr:=k+1;
        except
          inc(injectnr);
        end;
      end;
    end;


    //disassemble the old code
    setlength(originalcode,0);
    codesize:=0;

    while codesize<5 do
    begin
      setlength(originalcode,length(originalcode)+1);
      originalcode[length(originalcode)-1]:=disassemble(c,x);
      i:=posex('-',originalcode[length(originalcode)-1]);
      i:=posex('-',originalcode[length(originalcode)-1],i+1);
      originalcode[length(originalcode)-1]:=copy(originalcode[length(originalcode)-1],i+2,length(originalcode[length(originalcode)-1]));
      codesize:=c-a;
    end;

    setlength(originalbytes,codesize);
    ReadProcessMemory(processhandle, pointer(a), @originalbytes[0], codesize, br);

    enablecode:=tstringlist.Create;
    disablecode:=tstringlist.Create;
    try
      with enablecode do
      begin
        if processhandler.is64bit then
          add('alloc(newmem'+inttostr(injectnr)+',2048,'+address+') ')
        else
          add('alloc(newmem'+inttostr(injectnr)+',2048)');
        add('label(returnhere'+inttostr(injectnr)+')');
        add('label(originalcode'+inttostr(injectnr)+')');
        add('label(exit'+inttostr(injectnr)+')');
        add('');
        add('newmem'+inttostr(injectnr)+': //this is allocated memory, you have read,write,execute access');
        add('//place your code here');

        add('');
        add('originalcode'+inttostr(injectnr)+':');
        for i:=0 to length(originalcode)-1 do
          add(originalcode[i]);
        add('');
        add('exit'+inttostr(injectnr)+':');
        add('jmp returnhere'+inttostr(injectnr)+'');

        add('');
        add(address+':');
        add('jmp newmem'+inttostr(injectnr)+'');
        while codesize>5 do
        begin
          add('nop');
          dec(codesize);
        end;

        add('returnhere'+inttostr(injectnr)+':');
        add('');
      end;

      with disablecode do
      begin
        add('dealloc(newmem'+inttostr(injectnr)+')');
        add(address+':');
        for i:=0 to length(originalcode)-1 do
          add(originalcode[i]);
        x:='db';
        for i:=0 to length(originalbytes)-1 do
          x:=x+' '+inttohex(originalbytes[i],2);
        add('//Alt: '+x);
      end;

      getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);
      //skip first comment(s)
      if enablepos>=0 then
      begin
        while enablepos<assemblescreen.lines.Count-1 do
        begin
          if pos('//',trim(assemblescreen.Lines[enablepos+1]))=1 then inc(enablepos) else break;
        end;
      end;

      for i:=enablecode.Count-1 downto 0 do
        assemblescreen.Lines.Insert(enablepos+1,enablecode[i]);

      getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);
      //skip first comment(s)
      if disablepos>=0 then
      begin
        while disablepos<assemblescreen.lines.Count-1 do
        begin
          if pos('//',trim(assemblescreen.Lines[disablepos+1]))=1 then inc(enablepos) else break;
            inc(disablepos);
        end;
        //only if there actually is a disable section place this code
        for i:=disablecode.Count-1 downto 0 do
          assemblescreen.Lines.Insert(disablepos+1,disablecode[i]);
      end;
    finally
      enablecode.free;
      disablecode.Free;
    end;

  end;

{$endif}
end;

procedure TfrmAutoInject.Panel1Resize(Sender: TObject);
begin
  button1.Left:=panel1.Width div 2-button1.Width div 2;
end;


procedure TfrmAutoInject.CheatTablecompliantcodee1Click(Sender: TObject);
var e,d: integer;
begin
{$ifndef standalonetrainerwithassembler}

  getenableanddisablepos(assemblescreen.lines,e,d);

  if e=-1 then //-2 is 2 or more, so bugged, and >=0 is has one
  begin
    assemblescreen.Lines.Insert(0,'[ENABLE]');
    assemblescreen.Lines.Insert(1,'//code from here to ''[DISABLE]'' will be used to enable the cheat');
    assemblescreen.Lines.Insert(2,'');
  end;

  if d=-1 then
  begin
    assemblescreen.Lines.Add(' ');
    assemblescreen.Lines.Add(' ');
    assemblescreen.Lines.Add('[DISABLE]');
    assemblescreen.Lines.Add('//code from here till the end of the code will be used to disable the cheat');
  end;
{$endif}
end;

procedure TfrmAutoInject.assemblescreenChange(Sender: TObject);
begin
  if self=mainform.frmLuaTableScript then
    mainform.editedsincelastsave:=true;


end;



procedure TfrmAutoInject.Assigntocurrentcheattable1Click(Sender: TObject);
var a,b: integer;
    aa:TCEAllocArray;
    registeredsymbols: TStringlist;
begin
{$ifndef standalonetrainerwithassembler}
  {$ifndef net}

  registeredsymbols:=tstringlist.Create;
  registeredsymbols.CaseSensitive:=false;
  registeredsymbols.Duplicates:=dupIgnore;

  try
    setlength(aa,0);
    getenableanddisablepos(assemblescreen.Lines,a,b);
    if (a=-1) and (b=-1) then raise exception.create(rsCodeNeedsEnableAndDisable);

    if autoassemble(assemblescreen.lines,false,true,true,false,aa,registeredsymbols) and
       autoassemble(assemblescreen.lines,false,false,true,false,aa,registeredsymbols) then
    begin
      //add a entry with type 255
      mainform.AddAutoAssembleScript(assemblescreen.text);


    end
    else showmessage(rsFailedToAddToTableNotAllCodeIsInjectable);
  finally
    registeredsymbols.Free;
  end;
  {$endif}
  {$endif}
end;

procedure Getjumpandoverwrittenbytes(address,addressto: ptrUint; jumppart,originalcodepart: tstrings);
//pre: jumppart and originalcodepart are declared objects
var x,y: ptrUint;
    z: string;
    i: integer;
    ab: TAssemblerBytes;
    jumpsize: integer;
begin
{$ifndef standalonetrainerwithassembler}
  Assemble('jmp '+inttohex(addressto,8),address,ab);
  jumpsize:=length(ab);

  x:=address;
  y:=address;

  while x-y<jumpsize do
  begin
    z:=disassemble(x);
    z:=copy(z,pos('-',z)+1,length(z));
    z:=copy(z,pos('-',z)+1,length(z));

    originalcodepart.add(z);
  end;

  jumppart.Add('jmp '+inttohex(addressto,8));

  for i:=jumpsize to x-y-1 do
    jumppart.Add('nop');
{$endif}
end;


procedure generateAPIHookScript(script: tstrings; address: string; addresstogoto: string; addresstostoreneworiginalfunction: string=''; nameextension:string='0');
var originalcode: array of string;
    originaladdress: array of ptrUint;
    i,j: integer;
    codesize: integer;
    a,b,c: ptrUint;
    br: ptruint;
    x: string;

    enablepos,disablepos: integer;
    disablescript: tstringlist;
    enablescript: tstringlist;

    originalcodebuffer: Pbytearray;
    ab: TAssemblerBytes;

    jumpsize: integer;
    tempaddress: ptrUint;

    specifier: array of ptrUint;
    specifiernr: integer;
    s,s2: string;

    d: TDisassembler;

    originalcodestart: integer;

    isThumbOrigin: boolean;
    isThumbDestination: boolean;
begin
  //disassemble the old code
  d:=TDisassembler.Create;
  d.showmodules:=false;
  d.showsymbols:=false;

  setlength(specifier,0);
  setlength(originalcode,0);
  setlength(ab,0);
  specifiernr:=0;


  try
    a:=symhandler.getAddressFromName(address);
  except
    on e: exception do
      raise exception.create(address+':'+e.message);
  end;

  try
    b:=symhandler.getAddressFromName(addresstogoto);
  except
    on e: exception do
      raise exception.create(addresstogoto+':'+e.message);
  end;

  if processhandler.SystemArchitecture=archarm then
  begin
    isThumbOrigin:=(a and 1)=1; //assuming that a name is used and not the real address it occurs on
    isThumbDestination:=(b and 1)=1;

    if isThumbOrigin or isThumbDestination then
      raise exception.create('The thumb instruction set is not yet suppported');


    jumpsize:=8;
    c:=ptruint(FindFreeBlockForRegion(a,2048));
    if (c>0) and (abs(integer(c-a))<31*1024*1024) then
      jumpsize:=4; //can be done with one instruction B <a>
  end
  else
  begin
    if processhandler.is64bit then
    begin
      //check if there is a region I can make use of for a jump trampoline
      if FindFreeBlockForRegion(a,2048)=nil then
      begin
        Assemble('jmp '+inttohex(b,8),a,ab);
        jumpsize:=length(ab);
      end
      else
        jumpsize:=5;
    end
    else
      jumpsize:=5;
  end;



  disablescript:=tstringlist.Create;
  enablescript:=tstringlist.Create;

  codesize:=0;
  b:=a;
  while codesize<jumpsize do
  begin
    setlength(originalcode,length(originalcode)+1);
    setlength(originaladdress,length(originalcode));

    originaladdress[length(originaladdress)-1]:=a;
    originalcode[length(originalcode)-1]:=d.disassemble(a,x);
    i:=posex('-',originalcode[length(originalcode)-1]);
    i:=posex('-',originalcode[length(originalcode)-1],i+1);
    originalcode[length(originalcode)-1]:=copy(originalcode[length(originalcode)-1],i+2,length(originalcode[length(originalcode)-1]));

    codesize:=a-b;
  end;

  getmem(originalcodebuffer,codesize);
  if ReadProcessMemory(processhandle,pointer(b), originalcodebuffer, codesize, br) then
  begin
    disablescript.Add(address+':');
    x:='db';

    for i:=0 to br-1 do
      x:=x+' '+inttohex(originalcodebuffer[i],2);

    disablescript.Add(x);
  end;

  freemem(originalcodebuffer);



  with enablescript do
  begin
    if (processhandler.SystemArchitecture=archx86) and (not processhandler.is64bit) then
      add('alloc(originalcall'+nameextension+',2048)')
    else
    begin
      add('alloc(originalcall'+nameextension+',2048,'+address+')');
      add('alloc(jumptrampoline'+nameextension+',64,'+address+') //special jump trampoline in the current region (64-bit)');

      if processhandler.SystemArchitecture=archx86 then
        add('label(jumptrampoline'+nameextension+'address)');
    end;

    add('label(returnhere'+nameextension+')');
    add('');
    if addresstostoreneworiginalfunction<>'' then
    begin
      add(addresstostoreneworiginalfunction+':');
      if processhandler.is64Bit then
        add('dq originalcall'+nameextension)
      else
        add('dd originalcall'+nameextension);
    end;
    add('');
    add('originalcall'+nameextension+':');

    originalcodestart:=enablescript.Count;

    for i:=0 to length(originalcode)-1 do
    begin
      if hasAddress(originalcode[i], tempaddress, nil ) then
      begin
        if InRangeX(tempaddress, b,b+codesize) then
        begin
          s2:='specifier'+nameextension+inttostr(specifiernr);
          setlength(specifier,length(specifier)+1);
          specifier[specifiernr]:=tempaddress;

          Insert(0,'label('+s2+')');
          if has4ByteHexString(originalcode[i], s) then //should be yes
          begin
            s:=copy(s,2,length(s)-1);

            originalcode[i]:=StringReplace(originalcode[i],s,s2,[rfIgnoreCase]);
          end;

          inc(specifiernr);
        end;
      end;
      add(originalcode[i]);
    end;

    //now find the originalcode line that belongs to the specifier
    inc(originalcodestart,specifiernr);
    for i:=0 to length(specifier)-1 do
    begin
      for j:=0 to length(originaladdress)-1 do
      begin
        if specifier[i]=originaladdress[j] then
        begin
          enablescript[originalcodestart+j]:='specifier'+nameextension+inttostr(i)+':'+enablescript[originalcodestart+j]
        end;
      end;
    end;

    i:=0;

    while i<enablescript.count do
    begin
      j:=pos(':',enablescript[i]);

      if j>0 then
      begin
        s:=enablescript[i];
        s2:=copy(s,j+1,length(s));
        delete(i);
        Insert(i,copy(s,1,j));
        inc(i);
        Insert(i,s2);
      end;

      inc(i);
    end;

    if processhandler.SystemArchitecture=archarm then
      add('b returnhere'+nameextension)
    else
      add('jmp returnhere'+nameextension);

    add('');

    if processhandler.systemarchitecture=archarm then
    begin
      add('jumptrampoline'+nameextension+':');
      if isThumbDestination then
      begin
        raise exception.create('Thumb instructions are not yet implemented');
        if isThumbOrigin then
        begin
          add('thumb:b '+addresstogoto);
        end
        else
        begin
          add('bx jumptrampoline_armtothumb+1');
          add('jumptrampoline_armtothumb:');
          add('thumb:bl '+addresstogoto);
          add('thumb:bx jumptrampoline_thumbtoarm');
          add('jumptrampoline_thumbtoarm');
          add('bx lr');
        end;
      end
      else
        add('b '+addresstogoto);

    end
    else
    if processhandler.is64bit then
    begin
      add('jumptrampoline'+nameextension+':');
      add('jmp [jumptrampoline'+nameextension+'address]');
      add('jumptrampoline'+nameextension+'address:');
      add('dq '+addresstogoto);
      add('');
    end;


    add(address+':');

    if processhandler.SystemArchitecture=archarm then
    begin
      add('B jumptrampoline'+nameextension);
    end
    else
    begin
      if processhandler.is64bit then
        add('jmp jumptrampoline'+nameextension)
      else
        add('jmp '+addresstogoto);

      while codesize>jumpsize do
      begin
        add('nop');
        dec(codesize);
      end;
    end;

    add('returnhere'+nameextension+':');

    add('');
  end;


  getenableanddisablepos(script,enablepos,disablepos);

  if disablepos<>-1 then
  begin
    for i:=0 to disablescript.Count-1 do
      script.Insert(disablepos+i+1,disablescript[i]);
  end;

  getenableanddisablepos(script,enablepos,disablepos); //idiots putting disable first

  if enablepos<>-1 then
  begin
    for i:=0 to enablescript.Count-1 do
      script.Insert(enablepos+i+1,enablescript[i]);
  end
  else
    script.AddStrings(enablescript);

  disablescript.free;
  enablescript.free;

  d.free;
end;



procedure TfrmAutoInject.APIHook1Click(Sender: TObject);
function inttostr(i:int64):string;
begin
  if i=0 then result:='' else result:=sysutils.IntToStr(i);
end;

var address: string;

    a: ptrUint;
    x: string;
    i,j,k: integer;

    injectnr: integer;

begin
  if parent is TMemoryBrowser then
    a:=TMemoryBrowser(parent).disassemblerview.SelectedAddress
  else
    a:=memorybrowser.disassemblerview.SelectedAddress;

  address:=inttohex(a,8);

  with tfrmapihooktemplatesettings.create(self) do
//  if inputquery('Give the address of the api you want to hook',address) and inputquery('Give the address of the replacement function',address) then
  begin
    try
      injectnr:=0;
      for i:=0 to assemblescreen.Lines.Count-1 do
      begin
        j:=pos('alloc(newmem',lowercase(assemblescreen.lines[i]));
        if j<>0 then
        begin
          x:=copy(assemblescreen.Lines[i],j+12,length(assemblescreen.Lines[i]));
          x:=copy(x,1,pos(',',x)-1);
          try
            k:=strtoint(x);
            if injectnr<=k then
              injectnr:=k+1;
          except
            inc(injectnr);
          end;
        end;
      end;

      edit1.text:=address;
      if showmodal<>mrok then exit;


      generateAPIHookScript(assemblescreen.Lines,edit1.Text, edit2.Text, edit3.Text, inttostr(injectnr));


    finally
      free;
    end;
  end;

end;

procedure TfrmAutoInject.SaveAs1Click(Sender: TObject);
begin
  if savedialog1.Execute then
    save1.Click;
end;

procedure TfrmAutoInject.FormShow(Sender: TObject);
begin
  if editscript then
    button1.Caption:=strOK;

  assemblescreen.SetFocus;
end;

procedure TfrmAutoInject.assemblescreenKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
{   if (ssCtrl in Shift) and (key=ord('A'))  then
   begin
     TMemo(Sender).SelectAll;
     Key := 0;
   end; }
end;

procedure TfrmAutoInject.miCallLuaClick(Sender: TObject);
var
  luaserverinit: tstringlist;
  i: integer;

  needsinit1: boolean;
begin
  needsinit1:=true;

  for i:=0 to assemblescreen.Lines.Count-1 do
    if trim(assemblescreen.lines[i])='luacall(openLuaServer(''CELUASERVER''))' then
      needsinit1:=false;

  if needsinit1 then
  begin
    luaserverinit:=tstringlist.create;
    if processhandler.is64bit then
      luaserverinit.add('loadlibrary(luaclient-x86_64.dll)')
    else
      luaserverinit.add('loadlibrary(luaclient-i386.dll)');

    luaserverinit.add('luacall(openLuaServer(''CELUASERVER''))');
    luaserverinit.add('globalalloc(luainit, 128)');
    luaserverinit.add('globalalloc(LuaFunctionCall, 128)');
    luaserverinit.add('label(luainit_exit)');
    if processhandler.is64bit then
      luaserverinit.add('globalalloc(luaserverinitialized, 8)')
    else
      luaserverinit.add('globalalloc(luaserverinitialized, 4)');

    luaserverinit.add('globalalloc(luaservername, 12)');
    luaserverinit.add('');
    luaserverinit.add('luaservername:');
    luaserverinit.add('db ''CELUASERVER'',0');
    luaserverinit.add('');
    luaserverinit.add('luainit:');

    if processhandler.is64Bit then
      luaserverinit.add('sub rsp,8 //local scratchspace (and alignment)');

    luaserverinit.add('cmp [luaserverinitialized],0');
    luaserverinit.add('jne luainit_exit');


    if processhandler.is64Bit then
    begin
      luaserverinit.add('sub rsp,20 //allocate 32 bytes scratchspace for CELUA_Initialize');
      luaserverinit.add('mov rcx,luaservername');
    end
    else
      luaserverinit.add('push luaservername');

    luaserverinit.add('call CELUA_Initialize //this function is defined in the luaclient dll');
    if processhandler.is64Bit then
      luaserverinit.add('add rsp,20');

    luaserverinit.add('mov [luaserverinitialized],eax');
    luaserverinit.add('luainit_exit:');
    if processhandler.is64Bit then
      luaserverinit.add('add rsp,8  //undo local scratchspace ');

    luaserverinit.add('ret');
    luaserverinit.add('');

    luaserverinit.add('LuaFunctionCall:');
    if processhandler.is64bit then
    begin
      luaserverinit.add('sub rsp,8 //private scratchspace for this function');
      luaserverinit.add('mov [rsp+10],rcx //save address with function into pre-allocated scratchspace');
      luaserverinit.add('mov [rsp+18],rdx //save integer val');
      luaserverinit.add('sub rsp,20 //allocate 32 bytes of "shadow space" for the callee (not needed here, but good practice) ');
    end
    else
    begin
      luaserverinit.add('push ebp');
      luaserverinit.add('mov ebp,esp');
    end;
    luaserverinit.add('call luainit');

    if processhandler.is64bit then
    begin
      luaserverinit.add('add rsp,20');
      luaserverinit.add('mov rcx,[esp+10] //restore address of function');
      luaserverinit.add('mov rdx,[esp+18] //restore value');
    end;
    luaserverinit.add('');

    if processhandler.is64Bit then
    begin
      luaserverinit.add('sub rsp,20');
      luaserverinit.add('call CELUA_ExecuteFunction //this function is defined in the luaclient dll');
      luaserverinit.add('add rsp,20');
      luaserverinit.add('add rsp,8 //undo scratchpace (alignment fix) you can also combine it into add rsp,28');
      luaserverinit.add('ret');
    end
    else
    begin
      luaserverinit.add('push [ebp+c]');
      luaserverinit.add('push [ebp+8]');
      luaserverinit.add('call CELUA_ExecuteFunction');
      luaserverinit.add('pop ebp');
      luaserverinit.add('ret 8');
    end;

    luaserverinit.add('//luacall call example:');
    if processhandler.is64bit then
    begin
      luaserverinit.add('//Make sure rsp is aligned on a 16-byte boundary when calling this function');
      luaserverinit.add('//mov rcx, addresstostringwithfunction //(The lua function will have access to the variable passed by name "parameter")');
      luaserverinit.add('//mov rdx, integervariableyouwishtopasstolua');
      luaserverinit.add('//sub rsp,20');
      luaserverinit.add('//call LuaFunctionCall');
      luaserverinit.add('//add rsp,20');
      luaserverinit.add('//When done RAX will contain the result of the lua function');
    end
    else
    begin
      luaserverinit.add('//push integervariableyouwishtopasstolua');
      luaserverinit.add('//push addresstostringwithfunction  //(The lua function will have access to the variable passed by name "parameter")');
      luaserverinit.add('//call LuaFunctionCall');
      luaserverinit.add('//When done EAX will contain the result of the lua function');
    end;




    for i:=0 to luaserverinit.count-1 do
      assemblescreen.Lines.Insert(0+i, luaserverinit[i]);

    luaserverinit.free;
  end;





end;

procedure TfrmAutoInject.Coderelocation1Click(Sender: TObject);
var starts,stops: string;
    start,stop,current: ptrUint;
    x: ptrUint;
    i,j: integer;

    labels: tstringlist;
    output: tstringlist;
    s: string;

    a,b: string;
    prev: ptrUint;

    ok: boolean;

begin
{$ifndef standalonetrainerwithassembler}

  starts:=inttohex(memorybrowser.disassemblerview.SelectedAddress,8);
  stops:=inttohex(memorybrowser.disassemblerview.SelectedAddress+128,8);

  if inputquery(rsStartAddress+':', rsCodeRelocationTemplate, starts) then
  begin
    start:=StrToQWordEx('$'+starts);
    if inputquery(rsEndAddressLastBytesAreIncludedIfNecesary, rsCodeRelocationTemplate, stops) then
    begin
      stop:=StrToQWordEx('$'+stops);

      output:=tstringlist.Create;
      labels:=tstringlist.create;
      labels.Duplicates:=dupIgnore;
      labels.Sorted:=true;

      output.add('alloc(newmem,'+inttostr(abs(integer(stop-start))*2)+')');
      output.add('');
      output.add('newmem:');


      try
        current:=start;

        while current<stop do
        begin
          prev:=current;
          s:=disassemble(current);
          i:=posex('-',s);
          i:=posex('-',s,i+1);
          s:=copy(s,i+2,length(s));

          i:=pos(' ',s);
          a:=copy(s,1,i-1);
          b:=copy(s,i+1,length(s));


          if length(a)>1 then
          begin
            if (lowercase(a)='loop') or (lowercase(a[1])='j') or (lowercase(a)='call') then
            begin
              try
                x:=symhandler.getAddressFromName(b);
                if (x>=start) and (x<=stop) then
                begin
                  labels.Add('orig_'+inttohex(x,8));
                  s:=a+' orig_'+inttohex(x,8);
                end;
              except
                //nolabel
              end;
            end;
          end;

          output.add('orig_'+inttohex(prev,8)+':');
          output.add(s);
        end;

        labels.Sort;
        //now clean up output so that the result is a readable program
        for i:=0 to labels.Count-1 do
          output.Insert(2+i,'label('+labels[i]+')');

        output.Insert(2+labels.Count,'');

        i:=2+labels.Count+1;
        while i<output.Count do
        begin
          if pos('orig_',output[i])>0 then
          begin
            //determine if it's valid or not
            ok:=false;
            for j:=0 to labels.Count-1 do
              if labels[j]+':'=output[i] then
              begin
                ok:=true;
                break;
              end;

            if not ok then
              output.Delete(i)
            else
            begin
              output.Insert(i,'');
              inc(i,2);
            end;
          end
          else inc(i);
        end;

        assemblescreen.Lines.AddStrings(output);

      finally
        output.free;
      end;

    end;

  end;
{$endif}
end;

procedure TfrmAutoInject.New1Click(Sender: TObject);
var i: integer;
begin
{$ifndef standalonetrainerwithassembler}

  scripts[length(scripts)-1].script:=assemblescreen.Text;
  setlength(scripts,length(scripts)+1);

  scripts[length(scripts)-1].script:='';
  scripts[length(scripts)-1].undoscripts[0].oldscript:='';
  scripts[length(scripts)-1].currentundo:=0;

  assemblescreen.Text:='';


  if length(scripts)=2 then //first time new
  begin
    tlist.AddTab('Script 1');
    tlist.Visible:=true;
  end;

  i:=tlist.AddTab('Script '+inttostr(length(scripts)));
  tlist.SelectedTab:=i;
  oldtabindex:=i;
{$endif}
end;

procedure tfrmautoinject.tlistOnTabChange(sender: TObject; oldselection: integer);
begin
{$ifndef standalonetrainerwithassembler}

  scripts[oldselection].script:=assemblescreen.text;
  scripts[oldselection].filename:=opendialog1.FileName;

  assemblescreen.text:=scripts[tlist.SelectedTab].script;
  opendialog1.FileName:=scripts[tlist.SelectedTab].filename;

  oldtabindex:=tlist.SelectedTab;

  assemblescreen.ClearUndo;

{$endif}
end;

procedure tfrmAutoInject.gutterclick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
begin
  if assemblescreen.Lines.Count>line then
  begin
    assemblescreen.CaretY:=line;
    assemblescreen.CaretX:=0;
    assemblescreen.SelectLine(true);
  end;
end;



procedure TfrmAutoInject.FormCreate(Sender: TObject);
var x: array of integer;
    reg: tregistry;
begin


  {$ifndef standalonetrainerwithassembler}

  setlength(scripts,1);
  scripts[0].currentundo:=0;
  oldtabindex:=0;
{  assemblescreen.SelStart:=0;
  assemblescreen.SelLength:=0; }


  AAHighlighter:=TSynAASyn.Create(self);
  CPPHighlighter:=TSynCppSyn.create(self);
  LuaHighlighter:=TSynLuaSyn.Create(self);



  assembleSearch:=TSyneditSearch.Create;

  tlist:=TTablist.Create(self);
  tlist.height:=20;
  tlist.Align:=alTop;
  tlist.Visible:=false;
  tlist.OnTabChange:=tlistOnTabChange;

  tlist.Parent:=panel2;


  assemblescreen:=TSynEdit.Create(self);
  assemblescreen.Highlighter:=AAHighlighter;
  assemblescreen.Options:=SYNEDIT_DEFAULT_OPTIONS - [eoScrollPastEol]+[eoTabIndent];
  assemblescreen.Font.Quality:=fqDefault;
  assemblescreen.WantTabs:=true;
  assemblescreen.TabWidth:=4;


  assemblescreen.Gutter.MarksPart.Visible:=false;
  assemblescreen.Gutter.Visible:=true;
  assemblescreen.Gutter.LineNumberPart.Visible:=true;
  assemblescreen.Gutter.LeftOffset:=1;
  assemblescreen.Gutter.RightOffset:=1;

  assemblescreen.Align:=alClient;
  assemblescreen.PopupMenu:=PopupMenu1;
  assemblescreen.Parent:=panel2;

  assemblescreen.Gutter.OnGutterClick:=gutterclick;

  assemblescreen.name:='Assemblescreen';
  assemblescreen.Text:='';

  assemblescreen.OnChange:=assemblescreenchange;

  setlength(x,0);
  loadformposition(self,x);

  reg:=tregistry.create;
  try
    if reg.OpenKey('\Software\Cheat Engine\Auto Assembler\',false) then
    begin
      if reg.valueexists('Font.name') then
        assemblescreen.Font.Name:=reg.readstring('Font.name');

      if reg.valueexists('Font.size') then
        assemblescreen.Font.size:=reg.ReadInteger('Font.size');

      if reg.valueexists('Font.quality') then
        assemblescreen.Font.quality:=TFontQuality(reg.ReadInteger('Font.quality'));

      if reg.valueexists('Show Line Numbers') then
        assemblescreen.Gutter.linenumberpart.visible:=reg.ReadBool('Show Line Numbers');

      if reg.valueexists('Show Gutter') then
        assemblescreen.Gutter.Visible:=reg.ReadBool('Show Gutter');

      if reg.valueexists('smart tabs') then
        if reg.ReadBool('smart tabs') then assemblescreen.Options:=assemblescreen.options+[eoSmartTabs];

      if reg.valueexists('tabs to spaces') then
        if reg.ReadBool('tabs to spaces') then assemblescreen.Options:=assemblescreen.options+[eoTabsToSpaces];

      if reg.valueexists('tab width') then
        assemblescreen.tabwidth:=reg.ReadInteger('tab width');
    end;

  finally
    reg.free;
  end;

{$endif}
end;

procedure TfrmAutoInject.TabControl1Change(Sender: TObject);
begin

end;

procedure TfrmAutoInject.Syntaxhighlighting1Click(Sender: TObject);
begin
{$ifndef standalonetrainerwithassembler}

  Syntaxhighlighting1.checked:=not Syntaxhighlighting1.checked;
  if Syntaxhighlighting1.checked then //enable
  begin
    if fluamode then
      assemblescreen.Highlighter:=LuaHighlighter
    else
      assemblescreen.Highlighter:=AAHighlighter
  end
  else //disabl
    assemblescreen.Highlighter:=nil;

{$endif}
end;

procedure TfrmAutoInject.TabControl1ContextPopup(Sender: TObject;
  MousePos: TPoint; var Handled: Boolean);
begin
  //selectedtab:=TabControl1.IndexOfTabAt(mousepos.x,mousepos.y);
  //closemenu.Popup(mouse.CursorPos.X,mouse.cursorpos.Y);
end;

procedure TfrmAutoInject.Close1Click(Sender: TObject);
var i: integer;
begin
{$ifndef standalonetrainerwithassembler}


  if messagedlg(Format(rsAreYouSureYouWantToClose, [tlist.TabText[selectedtab]]), mtConfirmation, [mbyes, mbno], 0)=mryes then
  begin
    scripts[oldtabindex].script:=assemblescreen.text; //save current script
    tlist.RemoveTab(selectedtab);

    for i:=selectedtab to length(scripts)-2 do
      scripts[i]:=scripts[i+1];

    setlength(scripts,length(scripts)-1);

    if oldtabindex=selectedtab then //it was the current one
    begin
      oldtabindex:=length(scripts)-1;
      tlist.SelectedTab:=oldtabindex;
      assemblescreen.text:=scripts[oldtabindex].script;
      assemblescreen.OnChange(assemblescreen);
    end;

    if (length(scripts)=1) then
    begin
      tlist.RemoveTab(0);
      tlist.Visible:=false;
    end;
//    tabcontrol1.tabs[selectedtab]

  end;
{$endif}
end;

procedure TfrmAutoInject.injectscript(createthread: boolean);
var i: integer;
    setenvscript: tstringlist;
    CEAllocArray: TCEAllocArray;
    callscriptscript: tstringlist;

    totalmem: dword;
    totalwritten: dword;
    address: pointer;
    mi: TModuleInfo;
    hasjustloadedundercdll: boolean;

    aawindowwithstub: tfrmautoinject;
   // setenv_done: dword;
//    setenv_done_value: dword;
    s: string;

    ignore: dword;
    th: thandle;
begin
{$ifndef standalonetrainerwithassembler}
 {
 obsolete
  //this will inject the script dll and generate a assembler script the user can use to call the script
  //first set the environment var for uc_home
  s:=assemblescreen.text;
  if not symhandler.getmodulebyname('undercdll.dll',mi) then
  begin
    //dll was not loaded yet

    setenvscript:=tstringlist.Create;

    with setenvscript do
    begin
      add('[enable]');
      Add('alloc(envname,8)');
      add('alloc(envvar,512)');
      add('alloc(myscript,512)');

      add('envname:');
      add('db ''UC_HOME'',0');
      add('envvar:');
      add('db '''+cheatenginedir+''' ,0');
      add('myscript:');
      add('push envvar');
      add('push envname');
      add('call SetEnvironmentVariableA');
      add('ret');

      //cleanup part:
      add('[disable]');
      add('dealloc(myscript)');
      add('dealloc(envvar)');
      add('dealloc(envname)');
    end;

    setlength(CEAllocArray,1);
    if autoassemble(setenvscript,false,true,false,false,CEAllocArray) then //enabled
    begin
      for i:=0 to length(ceallocarray)-1 do
        if ceallocarray[i].varname='myscript' then
        begin
          th:=createremotethread(processhandle,nil,0,pointer(ceallocarray[i].address),nil,0,ignore);
          if th<>0 then
            waitforsingleobject(th,4000); //4 seconds max

          break;
        end;



      //wait done
      autoassemble(setenvscript,false,false,false,false,CEAllocArray); //disable for the deallocs
    end;

    setenvscript.free;


    injectdll(cheatenginedir+'undercdll.dll','');
    symhandler.reinitialize;
    hasjustloadedundercdll:=true;
  end else hasjustloadedundercdll:=false;

  //now allocate memory for the script and write it to there
  totalmem:=length(assemblescreen.text);
  address:=VirtualAllocEx(processhandle,nil,totalmem+512,mem_commit,page_execute_readwrite);
  if address=nil then raise exception.create('Failed allocating memory for the script');
  if not WriteProcessMemory(processhandle,address,@s[1],totalmem,totalwritten) then
    raise exception.create('failed writing the script to the process');



  callscriptscript:=tstringlist.create;
  try
    with callscriptscript do
    begin
      add('label(result)');
      add(inttohex((ptrUint(address)+totalmem+$20) - (ptrUint(address) mod $10),8)+':');
      add('pushfd');
      add('pushad');
      add('push '+inttohex(ptrUint(address),8));
      add('call underc_executescript');
      add('mov [result],eax');
      add('popad');
      add('popfd');
      add('mov eax,[result]');
      add('ret');
      add('result:');
      add('dd 0');
    end;

    if hasjustloadedundercdll then
    begin
      //lets wait before injecting the callscript script
      symhandler.waitforsymbolsloaded;
      if not symhandler.getmodulebyname('undercdll.dll',mi) then
        raise exception.Create('Failure loading undercdll');
    end;
    if not autoassemble(callscriptscript,false,true,false,false,CEAllocArray) then raise exception.Create('Failed creating calling stub for script located at address '+inttohex(ptrUint(address),8));
  finally
    callscriptscript.free;
  end;

  aawindowwithstub:=tfrmautoinject.create(memorybrowser);
  with aawindowwithstub.assemblescreen.Lines do
  begin
    if createthread then
    begin
      add('createthread(myscript)');
      add('alloc(myscript,256)');
      add('myscript:');
    end;

    add('//Call this code to execute the script from assembler');
    add('call '+inttohex((ptrUint(address)+totalmem+$20) - (ptrUint(address) mod $10),8));
    add('');
    add('//eax==0 when successfully executed');
    add('//''call underc_geterror'' to get a pointer to the last generated error buffer');

    if createthread then
      add('ret //interesing thing with createthread is that the return param points to exitthread');
  end;
  aawindowwithstub.show;
     }
{$endif}
end;



procedure TfrmAutoInject.Injectincurrentprocess1Click(Sender: TObject);
begin
  injectscript(false);


end;

procedure TfrmAutoInject.Injectintocurrentprocessandexecute1Click(
  Sender: TObject);
begin
  injectscript(true);
end;

procedure TfrmAutoInject.Cut1Click(Sender: TObject);
begin
  assemblescreen.CutToClipboard;
end;

procedure TfrmAutoInject.Copy1Click(Sender: TObject);
begin
  assemblescreen.CopyToClipboard;
end;

procedure TfrmAutoInject.Paste1Click(Sender: TObject);
begin
  assemblescreen.PasteFromClipboard;
end;

procedure TfrmAutoInject.Find1Click(Sender: TObject);
begin
  if finddialog1.Execute then
    mifindNext.visible:=true;

end;

procedure TfrmAutoInject.FindDialog1Find(Sender: TObject);
begin
  //scan the text for the given text
  assemblescreen.SearchReplace(finddialog1.FindText,'',[]);

  FindDialog1.close;
end;

//follow is just a emergency fix since undo is messed up. At least it's better than nothing
procedure TfrmAutoInject.AAPref1Click(Sender: TObject);
var reg: tregistry;
begin
  with TfrmAAEditPrefs.create(self) do
  begin
    try
      if execute(assemblescreen) then
      begin
        //save these settings
        reg:=tregistry.create;
        try
          if reg.OpenKey('\Software\Cheat Engine\Auto Assembler\',true) then
          begin
            reg.WriteString('Font.name', assemblescreen.Font.Name);
            reg.WriteInteger('Font.size', assemblescreen.Font.size);
            reg.WriteInteger('Font.quality', integer(assemblescreen.Font.Quality));



            //assemblescreen.Font.

            reg.WriteBool('Show Line Numbers', assemblescreen.Gutter.linenumberpart.visible);
            reg.WriteBool('Show Gutter', assemblescreen.Gutter.Visible);

            reg.WriteBool('smart tabs', eoSmartTabs in assemblescreen.Options);
            reg.WriteBool('tabs to spaces', eoTabsToSpaces in assemblescreen.Options);
          end;

        finally
          reg.free;
        end;
      end;
    finally
      free;
    end;
  end;
end;

procedure TfrmAutoInject.FormDestroy(Sender: TObject);
begin
  //if editscript or editscript2 then
  begin
    saveformposition(self,[]);

  end;
end;

procedure TfrmAutoInject.Undo1Click(Sender: TObject);
begin
  assemblescreen.Undo;
end;

// \/   http://forum.cheatengine.org/viewtopic.php?t=566415 (jgoemat and some mods by db)
procedure TfrmAutoInject.menuFullInjectionClick(Sender: TObject);
var
  address: string;
  originalcode: array of string;
  originalbytes: array of byte;
  codesize: integer;
  a: ptrUint;
  br: ptruint;
  c: ptrUint;
  x: string;
  i,j,k: integer;
  injectnr: integer;
  nr: string; // injectnr as string
  aobString: string;
  p: integer;

  enablepos: integer;
  disablepos: integer;
  initialcode: tstringlist;
  enablecode: tstringlist;
  disablecode: tstringlist;

  mi: TModuleInfo;

  haveModule: boolean;
  originalAddress: ptrUint;
  AddressString: string;
  maxBytesSize: integer;
  addressList: tstringlist;
  bytesList: tstringlist;
  codeList: tstringlist;
  startIndex: integer;

  injectFirstLine: Integer;
  injectLastLine: Integer;
  dline: TDisassemblyLine;
  ddBytes: string;
begin
  {$ifndef standalonetrainerwithassembler}
    // now heavily modified code from "Code injection" menu
    a:=memorybrowser.disassemblerview.SelectedAddress;

    mi.baseaddress := 0;
    haveModule := symhandler.getmodulebyaddress(a,mi);
    if haveModule then
    begin
      address:='"'+mi.modulename+'"+'+inttohex(a-mi.baseaddress,1);
    end
    else
      address:=inttohex(a,8);

    if inputquery(rsCodeInjectTemplate, rsOnWhatAddressDoYouWantTheJump, address) then
    begin
      try
        a:=StrToQWordEx('$'+address);
      except
        a:=symhandler.getaddressfromname(address);
      end;
      c:=a;
      injectnr:=0;
      for i:=0 to assemblescreen.Lines.Count-1 do
      begin
        j:=pos('alloc(newmem',lowercase(assemblescreen.lines[i]));
        if j<>0 then
        begin
          x:=copy(assemblescreen.Lines[i],j+12,length(assemblescreen.Lines[i]));
          x:=copy(x,1,pos(',',x)-1);
          try
            k:=strtoint(x);
            if injectnr<=k then
              injectnr:=k+1;
          except
            inc(injectnr);
          end;
        end;
      end;
      if injectnr = 0 then nr := '' else nr := sysutils.IntToStr(injectnr);


      // disassemble the old code, simply for putting original code in the script
      // and for the bytes we assert must be there and will replace
      setlength(originalcode,0);
      codesize:=0;

      while codesize<5 do
      begin
        setlength(originalcode,length(originalcode)+1);
        originalcode[length(originalcode)-1]:=disassemble(c,x);
        i:=posex('-',originalcode[length(originalcode)-1]);
        i:=posex('-',originalcode[length(originalcode)-1],i+1);
        originalcode[length(originalcode)-1]:=copy(originalcode[length(originalcode)-1],i+2,length(originalcode[length(originalcode)-1]));
        codesize:=c-a;
      end;

      setlength(originalbytes,codesize);
      ReadProcessMemory(processhandle, pointer(a), @originalbytes[0], codesize, br);


      // same as menu option "Cheat Engine framework code", make sure we
      // have enable and disable
      getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);

      if enablepos=-1 then //-2 is 2 or more, so bugged, and >=0 is has one
      begin
        assemblescreen.Lines.Insert(0,'[ENABLE]');
        assemblescreen.Lines.Insert(1,'');
      end;

      if disablepos=-1 then
      begin
        assemblescreen.Lines.Add('[DISABLE]');
        assemblescreen.Lines.Add('');
      end;


      dline:=TDisassemblyLine.create;
      initialcode:=tstringlist.Create;
      enablecode:=tstringlist.Create;
      disablecode:=tstringlist.Create;
      addressList:=tstringlist.Create;
      bytesList:=tstringlist.Create;
      codeList:=tstringlist.Create;

      try
        aobString:='';
        for i:=0 to length(originalbytes)-1 do
        begin
          if i > 0 then
            aobString := aobString + ' ';
          aobString := aobString + inttohex(originalbytes[i], 2);
        end;

        with initialcode do
        begin
          add('define(address' + nr + ',' + address + ')');
          add('define(bytes' + nr + ',' + aobString + ')');
          add('');
        end;

        with enablecode do
        begin
          add('assert(address'+nr+',bytes'+nr+')');
          if processhandler.is64bit then
            add('alloc(newmem' + nr + ',$1000,' + address + ')')
          else
            add('alloc(newmem' + nr + ',$1000)');
          add('');
          add('label(code'+nr+')');
          add('label(return'+nr+')');
          add('');
          add('newmem'+nr+':');

          add('');
          add('code'+nr+':');
          for i:=0 to length(originalcode)-1 do
            add('  '+originalcode[i]);
          add('  jmp return'+nr+'');

          add('');
          add('address'+nr+':');
          add('  jmp code'+nr+'');
          while codesize>5 do
          begin
            add('  nop');
            dec(codesize);
          end;

          add('return'+nr+':');
          add('');
        end;

        with disablecode do
        begin
          add('address'+nr+':');
          add('  db bytes'+nr);
          for i:=0 to length(originalcode)-1 do
            add('  // ' + originalcode[i]);
          add('');
          add('dealloc(newmem'+nr+')');
        end;


        // add initial defines before enable
        getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);
        p:=0;
        if (enablepos>0) then
          p:=enablepos;
        for i:=initialcode.Count-1 downto 0 do
          assemblescreen.Lines.Insert(p,initialcode[i]);

        // add enable lines before disable
        getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);
        p:=assemblescreen.lines.Count-1;
        if(disablepos>0) then
          p:=disablepos;
        for i:=enablecode.Count-1 downto 0 do
          assemblescreen.Lines.Insert(p,enablecode[i]);

        // add disable lines at very end
        for i:=0 to disablecode.Count-1do
          assemblescreen.Lines.Add(disablecode[i]);

        // finally add comment at the beginning
        assemblescreen.Lines.Insert(0,'{ Game   : ' + copy(mainform.ProcessLabel.Caption, pos('-', mainform.ProcessLabel.Caption) + 1, length(mainform.ProcessLabel.Caption)));
        assemblescreen.Lines.Insert(1,'  Version: ');
        assemblescreen.Lines.Insert(2,'  Date   : ' + FormatDateTime('YYYY-MM-DD', Now));
        assemblescreen.Lines.Insert(3,'  Author : ' + UserName);
        assemblescreen.Lines.Insert(4,'');
        assemblescreen.Lines.Insert(5,'  This script does blah blah blah');
        assemblescreen.Lines.Insert(6,'}');
        assemblescreen.Lines.Insert(7,'');

        // now we disassemble quite a bit more code for comments at the
        // bottom so someone can easily find the code again if the game
        // is updated
        assemblescreen.Lines.Add('');
        assemblescreen.Lines.Add('{');
        assemblescreen.Lines.Add('// ORIGINAL CODE - INJECTION POINT: ' + address);
        assemblescreen.Lines.Add('');

        injectFirstLine := 0;
        injectLastLine := 0;
        maxBytesSize := 0;
        dline.Init(a - 128, mi);


        while dline.Address < (a + 128) do
        begin
          if (dline.Address < a) and ((dline.Address + dline.Size) > a) then dline.Shorten((dline.Address + dline.Size) - a);
          addressList.Add(dline.AddressString);
          ddBytes := dline.GetHexBytes;
          maxBytesSize := Max(maxBytesSize, Length(ddBytes));
          bytesList.Add(ddBytes);
          codeList.Add(dline.Code);
          if (dline.Address >= a) and (injectFirstLine <= 0) then injectFirstLine := addressList.Count - 1;
          if (dline.Address < a + codesize) then injectLastLine := addressList.Count - 1;
          dline.Init(dline.Address + dline.Size, mi);
        end;

        for i := injectFirstLine - 10 to injectLastLine + 10 do
        begin
          if i = injectFirstLine then assemblescreen.Lines.Add('// ---------- INJECTING HERE ----------');
          assemblescreen.Lines.Add(addressList[i] + ': ' + PadRight(bytesList[i],maxBytesSize) + ' - ' + codeList[i]);
          if i = injectLastLine then assemblescreen.Lines.Add('// ---------- DONE INJECTING  ----------');
        end;
        assemblescreen.Lines.Add('}');
      finally
        initialcode.free;
        enablecode.free;
        disablecode.Free;
        addressList.Free;
        bytesList.Free;
        codeList.Free;
        dline.free;
      end;

    end;
  {$endif}
end;

procedure TfrmAutoInject.menuAOBInjectionClick(Sender: TObject);
var
  address: string;
  a: ptrUint;                     // pointer to injection point
  originalcode: array of string;  // disassembled code we're replacing
  originalbytes: array of byte;   // bytes we're replacing
  codesize: integer;              // # of bytes we're replacing
  aobString: string;              // hex bytes we're replacing
  injectnr: integer;              // # of this injection (multiple can be in 1 script)
  nr: string;                     // injectnr as string

  // lines where [ENABLE] and [DISABLE] are
  enablepos: integer;
  disablepos: integer;

  // temp variables
  br: ptruint;
  c: ptrUint;
  x: string;
  i,j,k: integer;
  p: integer;

  // lines of code to inject in certain places
  initialcode: tstringlist;
  enablecode: tstringlist;
  disablecode: tstringlist;

  // these are for code in comment at bottom
  maxBytesSize: Integer;
  addressList: TStringList;
  bytesList: TStringList;
  codeList: TStringList;
  ddBytes: String;

  haveModule: boolean;        // true if address is in a module
  mi: TModuleInfo;            // info on the module
  dline: TDisassemblyLine;    // for disassembling code in the bottom comment
  injectFirstLine: Integer;
  injectLastLine: Integer;
  resultAOB: String;
  resultOffset: Integer;
  symbolName: String;
  symbolNameWithOffset: String;
begin
{$ifndef standalonetrainerwithassembler}
  // now heavily modified code from "Code injection" menu
  a:=memorybrowser.disassemblerview.SelectedAddress;

  mi.baseaddress := 0;
  haveModule := symhandler.getmodulebyaddress(a,mi);
  if haveModule then
  begin
    address:='"'+mi.modulename+'"+'+inttohex(a-mi.baseaddress,1);
  end
  else
    address:=inttohex(a,8);

  if inputquery(rsCodeInjectTemplate, rsOnWhatAddressDoYouWantTheJump, address) then
  begin
    try
      a:=StrToQWordEx('$'+address);
    except
      a:=symhandler.getaddressfromname(address);
    end;
    c:=a;
    injectnr:=0;
    for i:=0 to assemblescreen.Lines.Count-1 do
    begin
      j:=pos('alloc(newmem',lowercase(assemblescreen.lines[i]));
      if j<>0 then
      begin
        x:=copy(assemblescreen.Lines[i],j+12,length(assemblescreen.Lines[i]));
        x:=copy(x,1,pos(',',x)-1);
        try
          k:=strtoint(x);
          if injectnr<=k then
            injectnr:=k+1;
        except
          inc(injectnr);
        end;
      end;
    end;
    if injectnr = 0 then nr := '' else nr := sysutils.IntToStr(injectnr);


    // disassemble the old code, simply for putting original code in the script
    // and for the bytes we assert must be there and will replace
    setlength(originalcode,0);
    codesize:=0;

    while codesize<5 do
    begin
      setlength(originalcode,length(originalcode)+1);
      originalcode[length(originalcode)-1]:=disassemble(c,x);
      i:=posex('-',originalcode[length(originalcode)-1]);
      i:=posex('-',originalcode[length(originalcode)-1],i+1);
      originalcode[length(originalcode)-1]:=copy(originalcode[length(originalcode)-1],i+2,length(originalcode[length(originalcode)-1]));
      codesize:=c-a;
    end;

    setlength(originalbytes, codesize);
    ReadProcessMemory(processhandle, pointer(a), @originalbytes[0], codesize, br);

    // same as menu option "Cheat Engine framework code", make sure we
    // have enable and disable
    getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);

    if enablepos=-1 then //-2 is 2 or more, so bugged, and >=0 is has one
    begin
      assemblescreen.Lines.Insert(0,'[ENABLE]');
      assemblescreen.Lines.Insert(1,'');
    end;

    if disablepos=-1 then
    begin
      assemblescreen.Lines.Add('[DISABLE]');
      assemblescreen.Lines.Add('');
    end;

    dline:=TDisassemblyLine.create;
    initialcode:=tstringlist.Create;
    enablecode:=tstringlist.Create;
    disablecode:=tstringlist.Create;
    addressList:=tstringlist.Create;
    bytesList:=tstringlist.Create;
    codeList:=tstringlist.Create;

    try
      //************************************************************************
      //* Now do AOBScan and get name for injection symbol
      //************************************************************************
      resultAOB := GetUniqueAOB(mi, a, codesize, resultOffset);
      symbolName := 'INJECT' + nr;
      if not inputquery(rsCodeInjectTemplate, rsWhatIdentifierDoYouWantToUse, symbolName) then symbolName := 'INJECTION_POINT';
      if resultOffset <> 0 then
        symbolNameWithOffset := symbolName + '+' + IntToHex(resultOffset, 2)
      else
        symbolNameWithOffset := symbolName;

      aobString:='';
      for i:=0 to length(originalbytes)-1 do
      begin
        if i > 0 then
          aobString := aobString + ' ';
        aobString := aobString + IntToHex(originalbytes[i], 2);
      end;

      with enablecode do
      begin
        if (mi.baseAddress > 0) then
          add('aobscanmodule(' + symbolName + ',' + mi.modulename + ',' + resultAOB + ') // should be unique')
        else
          add('aobscan(' + symbolName + ',' + resultAOB + ') // should be unique');

        if processhandler.is64bit then
          add('alloc(newmem' + nr + ',$1000,' + address + ')')
        else
          add('alloc(newmem' + nr + ',$1000)');
        add('');
        add('label(code'+nr+')');
        add('label(return'+nr+')');
        add('');
        add('newmem'+nr+':');

        add('');
        add('code' + nr + ':');
        for i:=0 to length(originalcode) - 1 do
          add('  ' + originalcode[i]);
        add('  jmp return'+nr+'');

        add('');
        add(symbolNameWithOffset + ':');
        add('  jmp code' + nr + '');
        for i := 6 to codesize do
          add('  nop');
        add('return' + nr + ':');
        add('registersymbol(' + symbolName + ')');
        add('');
      end;

      with disablecode do
      begin
        add(symbolNameWithOffset+':');
        add('  db ' + aobString);
        add('');
        add('unregistersymbol(' + symbolName + ')');
        add('dealloc(newmem'+nr+')');
      end;


      // add initial defines before enable
      getenableanddisablepos(assemblescreen.lines,enablepos,disablepos);
      p:=0;
      if (enablepos>0) then
        p:=enablepos;
      for i:= initialcode.Count-1 downto 0 do
        assemblescreen.Lines.Insert(p, initialcode[i]);

      // add enable lines before disable
      getenableanddisablepos(assemblescreen.lines, enablepos, disablepos);
      p := assemblescreen.lines.Count - 1;
      if(disablepos > 0) then
        p := disablepos;
      for i:= enablecode.Count - 1 downto 0 do
        assemblescreen.Lines.Insert(p,enablecode[i]);

      // add disable lines at very end
      for i:= 0 to disablecode.Count - 1 do
        assemblescreen.Lines.Add(disablecode[i]);

      // add template comment at the beginning
      assemblescreen.Lines.Insert(0,'{ Game   : ' + copy(mainform.ProcessLabel.Caption, pos('-', mainform.ProcessLabel.Caption) + 1, length(mainform.ProcessLabel.Caption)));
      assemblescreen.Lines.Insert(1,'  Version: ');
      assemblescreen.Lines.Insert(2,'  Date   : ' + FormatDateTime('YYYY-MM-DD', Now));
      assemblescreen.Lines.Insert(3,'  Author : ' + UserName);
      assemblescreen.Lines.Insert(4,'');
      assemblescreen.Lines.Insert(5,'  This script does blah blah blah');
      assemblescreen.Lines.Insert(6,'}');
      assemblescreen.Lines.Insert(7,'');

      // now we disassemble quite a bit more code for comments at the
      // bottom so someone can easily find the code again if the game
      // is updated
      assemblescreen.Lines.Add('');
      assemblescreen.Lines.Add('{');
      assemblescreen.Lines.Add('// ORIGINAL CODE - INJECTION POINT: ' + address);
      assemblescreen.Lines.Add('');

      injectFirstLine := 0;
      injectLastLine := 0;
      maxBytesSize := 0;
      dline.Init(a - 128, mi);

      while dline.Address < (a + 128) do
      begin
        // see if we overshot our injection point
        if (dline.Address < a) and ((dline.Address + dline.Size) > a) then dline.Shorten((dline.Address + dline.Size) - a);
        addressList.Add(dline.AddressString);
        ddBytes := dline.GetHexBytes;
        maxBytesSize := Max(maxBytesSize, Length(ddBytes));
        bytesList.Add(ddBytes);
        codeList.Add(dline.Code);
        if (dline.Address >= a) and (injectFirstLine <= 0) then injectFirstLine := addressList.Count - 1;
        if (dline.Address < a + codesize) then injectLastLine := addressList.Count - 1;
        dline.Init(dline.Address + dline.Size, mi);
      end;
      for i := injectFirstLine - 10 to injectLastLine + 10 do
      begin
        if i = injectFirstLine then assemblescreen.Lines.Add('// ---------- INJECTING HERE ----------');
        assemblescreen.Lines.Add(addressList[i] + ': ' + PadRight(bytesList[i],maxBytesSize) + ' - ' + codeList[i]);
        if i = injectLastLine then assemblescreen.Lines.Add('// ---------- DONE INJECTING  ----------');
      end;
      assemblescreen.Lines.Add('}');
    finally
      initialcode.free;
      enablecode.free;
      disablecode.Free;
      addressList.Free;
      bytesList.Free;
      codeList.Free;
      dline.free;
    end;
  end;
{$ENDIF}
end;

function TfrmAutoInject.GetUniqueAOB(mi: TModuleInfo; address: ptrUint; codesize: Integer; var resultOffset: Integer) : string;
var
  size: integer;
  dline: TDisassemblyLine;

  maskFlags : Array of Boolean; // true if we need to use **
  maskBytes : Array of Byte;    // bytes around code we're replacing
  flags : Array of Boolean;     // temp for single instruction
  br : ptruint;
  aob : string;
  i, j, k : Integer;

  // variables used for memory scan
  ms : TMemScan;
  minaddress: ptruint;
  maxaddress: ptrUint;
  foundAddress: ptrUint;
  foundCount: Integer;
  fl: TFoundList;

  instructionOffset: Integer; // offset for copying mask flags to main list from instruction list
  shortestAfter: Integer; // # of bytes, including codesize, index is 20 of course because it only counts starting at original code
  shortestBeforeIndex: Integer; // index to start at, will be 0 - 20
  shortestBeforeLength: Integer; // # of bytes, including before, original code, and possibly after

  finds: Array of TAOBFind; // for each found address has bytes to use for comparison

  // count how many found addresses match the criteria
  function CountMatches(offset: Integer; size: Integer) : Integer;
  var
    i: Integer;
    count: Integer;
    flength: Integer;
  begin
    count := 0;
    for i := 0 to Length(finds) - 1 do
    begin
      if finds[i].IsMatch(maskBytes, maskFlags, offset, offset + size - 1) then count := count + 1;
      if count > 1 then break; // short-circuit, we only care if there is more than 1
    end;
    result := count;
  end;
begin
  size := 40 + codesize; // 20 bytes on each side of replaced code
  SetLength(maskBytes, size); // setup array for bytes around code we're looking for
  SetLength(maskFlags, size); // flags on whether they need masking or not
  ReadProcessMemory(processhandle, pointer(address - 20), @maskBytes[0], size, br);

  dline:=TDisassemblyLine.create;

  // get AOB to search for using the code we're replacing
  aob := '';
  for i := 0 to codesize - 1 do
  begin
    if (i > 0) then aob := aob + ' ';
    aob := aob + inttohex(maskBytes[20 + i], 2);
  end;

  // Do AOBSCAN for replaced code
  ms := tmemscan.create(nil);
  ms.parseProtectionflags('');
  ms.onlyone := false;
  if mi.baseaddress > 0 then
  begin
    minaddress := mi.baseaddress;
    maxaddress := mi.baseaddress + mi.basesize;
  end else
  begin
    minaddress := 0;
    {$ifdef cpu64}
    if processhandler.is64Bit then
      maxaddress := qword($7fffffffffffffff)
    else
    {$endif}
    begin
      if Is64bitOS then
        maxaddress := $ffffffff
      else
        maxaddress := $7fffffff;
    end;
  end;
  ms.OnlyOne := false;
  fl := TFoundlist.create(nil, ms, '');
  ms.FirstScan(soExactValue, vtByteArray, rtTruncated, aob, '', minaddress, maxaddress, true, false, false, true, fsmAligned, '1');
  ms.WaitTillReallyDone; //wait till it's finished scanning
  foundCount := fl.Initialize(vtByteArray, nil);



  // if there's only one result, the code's AOB is fine
  if foundCount = 1 then
  begin
    resultOffset := 0;
    result := aob;
    fl.free;
    ms.free;
    exit;
  end;

  // now we need to narrow it down.  start by disassembling around the injection
  // point and creating flags on which bytes need to be masked because they are
  // probably pointers to code or data that may frequently change
  dline.Init(address - 128, mi);

  // 0 to 19: address - 20 to address - 1: before
  // 20 to 20 + codesize - 1): original code
  // 20 + codesize to 39 + codesize: after
  while (dline.Address <= (address + 20)) do
  begin
    // if we overran injection address, shorten to 'db X X X' statement
    if (dline.Address < address) and ((dline.Address + dline.Size) > address) then dline.Shorten(address - dline.Address);
    j := (dline.Address + 20) - address;
    k := j + dline.Size - 1;
    if (k >= 0) and (j <= (codesize + 39)) then
    begin
      // we're in range, get mask flags
      flags := dline.GetMaskFlags();
      for i := j to k do
      begin
        instructionOffset := i - j;
        if (i >= 0) and (i <= 39 + codesize) and (instructionOffset >= 0) then
        begin
          if (i < 20) or (i >= (20 + codesize)) then
            maskFlags[i] := flags[instructionOffset]
          else
            maskFlags[i] := false;
        end;
      end;
    end;

    dline.Init(dline.Address + dline.Size, mi); // next instruction
  end;

  // prep 'finds' array to read memory and make searching easier
  SetLength(finds, foundCount);
  for i := 0 to foundCount - 1 do
  begin
    finds[i].Init(fl.GetAddress(i), codesize);
  end;

  //not needed anymore
  fl.free;
  ms.free;


  // find shortest way to get a single match starting at original code
  shortestAfter := 100;
  shortestBeforeIndex := 19;
  shortestBeforeLength := 100;
  for i := codesize + 1 to codesize + 20 do
  begin
    if CountMatches(20, i) = 1 then
    begin
      shortestAfter := i;
      break;
    end;
  end;

  // now for before, we step back one at a time and loop up to shortestAfter bytes
  for i := 19 downto 0 do
  begin
    // i is index, j is length (checking indices i to i+j-1
    for j := codesize + (20 - i) to Min(shortestBeforeLength - 1, Min(shortestAfter - 6, (40 + codesize) - i)) do // first round, 6 to 26
    begin
      if CountMatches(i, j) = 1 then
      begin
        shortestBeforeIndex := i;
        shortestBeforeLength := j;
        break;
      end;
    end;
  end;

  if shortestAfter < shortestBeforeLength then
  begin
    shortestBeforeLength := shortestAfter;
    shortestBeforeIndex := 20;
  end;

  // if we can't find unique AOB, return earlier aob with error
  if shortestBeforeLength >= 100 then begin
    result := 'ERROR: Could not find unique AOB, tried code "' + aob + '"';
    exit;
  end;

  // create AOB using masking
  aob := '';
  for i := 0 to shortestBeforeLength - 1 do
  begin
    if i <> 0 then aob := aob + ' ';
    if maskFlags[i + shortestBeforeIndex] then
      aob := aob + '*'
    else
      aob := aob + IntToHex(maskBytes[i + shortestBeforeIndex], 2);
  end;

  dline.free;

  resultOffset := 20 - shortestBeforeIndex;
  result := aob;
end;

procedure TDisassemblyLine.Init(_address: ptrUint; _mi: TModuleInfo);
var x:string;
    pos1:integer;
    pos2:integer;
    i:integer;
    original: string;
begin
  Address := _address;
  Original := disassembler.disassemble(_address, Comment);

  Size := _address - Address;
  OriginalHexBytes := disassembler.getLastBytestring;
  Code:=disassembler.LastDisassembleData.prefix+' '+Disassembler.LastDisassembleData.opcode+' '+disassembler.LastDisassembleData.parameters;

  if (_mi.basesize = 0) or (_address < _mi.baseaddress) or (_address > (_mi.baseaddress + _mi.basesize)) then
    AddressString := inttohex(Address, 8)
  else
    AddressString := '"' + _mi.modulename + '"+' + inttohex(Address - _mi.baseaddress, 1);
end;

function TDisassemblyLine.GetHexBytes : String;
var i: Integer;
begin
  result:='';

  if length(Disassembler.LastDisassembleData.Bytes)>=size then
  begin
    for i:=0 to size-1 do
      result:=result+inttohex(Disassembler.LastDisassembleData.Bytes[i],2)+' ';
  end;
end;

// true if it is an instruction that probably starts a procedure so we can
// start our commented code here
function TDisassemblyLine.IsStarter : Boolean;
begin
  result:=code = 'push ebp';
end;

// true if it is an instruction that probably ends a procedure so we can end
// our commented code here
function TDisassemblyLine.IsEnder : Boolean;
begin
  result := Disassembler.LastDisassembleData.isret;
end;

// true if it not an instruction (int3, or add [eax],al : 00 00) that probably is not meant to be
// executed, so we know if we are outside a group of code
function TDisassemblyLine.IsValid : Boolean;
begin
  result:=true;
  if size>0 then //always true (if init is called once)
  begin
    if Disassembler.LastDisassembleData.Bytes[0]=$cc then
      result := false
    else
    if size>1 then
    begin
      if (Disassembler.LastDisassembleData.Bytes[0]=0) and (Disassembler.LastDisassembleData.Bytes[1]=0) then
        result:=false;
    end;
  end;
end;

// array with a boolean for each byte telling if it should be masked or not
function TDisassemblyLine.GetMaskFlags : TBooleanArray;
var
  masked : TBooleanArray;
  index : Integer;
  i, pos1, pos2 : Integer;
  part : String;
  mask : Boolean;
  count : Integer;
begin
  setlength(result, size);

  pos1:=0;
  for i:=0 to Disassembler.LastDisassembleData.SeperatorCount-1 do
  begin
    pos2:=Disassembler.LastDisassembleData.Seperators[i];
    mask:=(pos2<=size) and (pos2-pos1=4) and (abs(pinteger(@Disassembler.LastDisassembleData.Bytes[pos1])^)>=$10000); //value is bigger than 65535 (positive and negative)

    for index := pos1 to pos2-1 do
      result[index] := mask;

    pos1:=pos2;
  end;

  for index := pos1 to size-1 do
    result[index]:=false;
end;

procedure TDisassemblyLine.Shorten(_newSize: Integer);
var
  i, j: Integer;
  hexbytes: String;
begin
  // GetHexBytes() gives us the bytes split out with spaces between
  // all, this way we can write our 'db' statement and all bytes will
  // be unmasked
  Size := _newSize;
  OriginalHexBytes := GetHexBytes;
  Code := 'db ' + OriginalHexBytes + ' // SHORTENED TO HIT INJECTION FROM: ' + Code;
end;

constructor TDisassemblyLine.create;
begin
  disassembler:=TDisassembler.Create;
  Disassembler.showsymbols:=false; //seeing that mi is given explicitly to init() I assume that modules are prefered over exports
  Disassembler.showmodules:=true;
  Disassembler.dataOnly:=false;
end;

destructor TDisassemblyLine.destroy;
begin
  if assigned(Disassembler) then
    Disassembler.free;

  inherited destroy;
end;


procedure TAOBFind.Init(_address: ptrUint; _codesize: Integer);
var
  i: integer;
  br: ptruint; // bytes actually read
begin
  Address := _address;
  Size := _codeSize + 40;
  SetLength(Bytes, Size);
  ReadProcessMemory(processhandle, pointer(Address - 20), @Bytes[0], Size, br);
end;

function TAOBFind.IsMatch(var maskBytes: Array Of Byte; var maskFlags : TBooleanArray; startIndex, endIndex: Integer): Boolean;
var
  i: Integer;
  mf: Boolean;
  mb: Byte;
  b: Byte;
begin
  for i := startIndex to endIndex do
  begin
    if (i > 0) and (i < Length(Bytes)) then
    begin
      mf := maskFlags[i];
      mb := maskBytes[i];
      b := Bytes[i];
      if not maskFlags[i] then
      begin
        if maskBytes[i] <> Bytes[i] then
        begin
          result := false;
          exit;
        end;
      end;
    end;
  end;
  result := true;
end;

// /\   http://forum.cheatengine.org/viewtopic.php?t=566415 (jgoemat and some mods by db)

initialization
  {$i frmautoinjectunit.lrs}

end.

