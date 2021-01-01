unit gui; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  Buttons, ExtCtrls, StdCtrls, Menus,main,Clipbrd;

type

  { TForm1 }

  TForm1 = class(TForm)
    RestCheck: TCheckBox;
    delay1: TEdit;
    delay2: TEdit;
    DesignDrop: TComboBox;
    disp1: TEdit;
    disp2: TEdit;
    DoubleGammaCheck: TCheckBox;
    CondEdit: TEdit;
    CounterbalanceCheck: TCheckBox;
    AdvancedCheck: TCheckBox;
    IterationEdit: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    fMRIpanel: TPanel;
    EventPanel: TPanel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    MainMenu1: TMainMenu;
    MeanISIEdit: TEdit;
    File1: TMenuItem;
    Export1: TMenuItem;
    Export2: TMenuItem;
    EditMenu: TMenuItem;
    CopyMenu: TMenuItem;
    MinISIEdit: TEdit;
    BlockPanel: TPanel;
    AdvancedPanel: TPanel;
    PermuteEdit: TEdit;
    OptimalBlockMSECEdit: TEdit;
    ratio1v2: TEdit;
    Timer1: TTimer;
    Image1: TImage;
    Panel1: TPanel;
    Timer2: TTimer;
    TREdit: TEdit;
    VolEdit: TEdit;
    procedure AdvancedCheckChange(Sender: TObject);
    procedure CopyMenuClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure HRFChange(Sender: TObject);
    procedure DesignDropChange(Sender: TObject);
    procedure DoubleGammaCheckChange(Sender: TObject);
    procedure Export1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure GetSet(out lFMRI: TFMRI);
    procedure Export2Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  Form1: TForm1; 

implementation

{$R *.lfm}

{ TForm1 }


function GetFloat(S: string; lMin,lDefault,lMax: single): single;
begin
  if S = '' then begin
     result := lDefault;
     exit;
  end;
  try
     	result := StrToFloat(S);
  except
    on Exception : EConvertError do
      result := ldefault;
  end;
  if result < lmin then
  	 result := lmin;
  if result > lmax then
     result := lmax;
end;

function GetInt(S: string; lMin,lDefault,lMax: integer): integer;
begin
  result := round(GetFloat(S,lMin,lDefault,lMax));

end;

procedure TForm1.GetSet(out lFMRI: TFMRI);
begin
     lFMRI.SignalRAPts := 0;
     lFMRI.EventOnsetRAPts := 0;
     lFMRI.TRmsec := GetInt(TREdit.Text,1,2000,15000);
     lFMRI.Volumes := GetInt(VolEdit.Text,1,2000,15000);
     lFMRI.nCond := GetInt(CondEdit.Text,1,2000,15000);
     lFMRI.meanISI := GetInt(MeanISIEdit.Text,2,2000,15000);
     lFMRI.minISI := GetInt(MinISIEdit.Text,1,lFMRI.meanISI div 2,lFMRI.meanISI-1);
     lFMRI.nPermute := GetInt(PermuteEdit.Text,0,2000,15000);
     lFMRI.Iterations := GetInt(IterationEdit.Text,0,2000,15000);
     lFMRI.FinalCondIsRest := RestCheck.Checked;
     lFMRI.Counterbalance:= Counterbalancecheck.checked;
     lFMRI.OptimalBlockMSEC:= GetInt(OptimalBlockMSECEdit.Text,lFMRI.meanISI,12000,40000);
    lFMRI.VTitle := 'Signal';
    lFMRI.Design := DesignDrop.ItemIndex;
    FMRIpanel.Visible := lFMRI.Design <> kShowHRF;
    RestCheck.Visible := lFMRI.nCond > 1;
    BlockPanel.Visible := lFMRI.Design = kBlock;
    EventPanel.Visible := (lFMRI.Design=kFixedISI) or (lFMRI.Design = kExpoISI) or (lFMRI.Design =kRandomISI);
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.enabled := false;
  DesignDropChange(nil);
end;

procedure TForm1.EditChange(Sender: TObject);
begin
  Timer1.enabled := false;
  Timer1.enabled := true;//reset timer
end;

procedure TForm1.Timer2Timer(Sender: TObject);
begin
  Timer2.enabled := false;
     gHRF.p1:= GetInt(Delay1.Text,1000,6000,18000)/1000; //delay of response
   gHRF.p2:=GetInt(Delay2.Text,1100,16000,28000)/1000;//delay of undershoot (relative to onset)
   gHRF.p3:=GetInt(Disp1.Text,100,1000,18000)/1000; //dispersion of response
   gHRF.p4:=GetInt(Disp2.Text,100,1000,18000)/1000; //dispersion of undershoot
   gHRF.p5:=GetInt(Ratio1v2.Text,1,6,18);  //ratio of response to undershoot
  CalcHrf(DoubleGammaCheck.Checked);
  EditChange(nil);
end;

(*procedure CustomInput;
var
   lG: Tstrings;
   lTRsec: single;
   lCount,lSum,lN: integer;
begin
 ClearAllRA;
 lG:= TStringList.Create; //not sure why TStrings.Create does not work???
 //if not OpenDialog1.execute then exit;
 //lG.addstrings(OpenDialog1.Files);
 TREdit.value := 2200;
 if not OpenDialog1.execute then exit;
 lG.addstrings(OpenDialog1.Files);
 lSum := 0;
 if lG.count < 1 then
    exit;
 for lCount := 1 to lG.count do begin
     lN := ReadCond (lG.Strings[lCount-1], -1,lSum);
     lSum := lSum + lN;
     if lN < 1 then
        showmessage('Warning: no events found in file '+lG.Strings[lCount-1]);
 end;
 if lSum < 1 then
    exit;
 CondEdit.value := lG.count;
 EventRAGetMem(lSum);
 lSum := 0;
 for lCount := 1 to lG.count do begin
     lN := ReadCond (lG.Strings[lCount-1], lCount,lSum);
     lSum := lSum + lN;
 end;
 if not SignalRAGetMem (VolumeEdit.value,CondEdit.value) then exit;
 lTRsec := TRedit.value / 1000; //ms to sec
 for lCount := 1 to gEventOnsetRApts do
     gEventOnsetRA[lCount] := gEventOnsetRA[lCount]/lTRsec;
 //if not generateFixedEvents (meanISIedit.value,(gSignalRAPts * TREdit.value),TREdit.value) then exit;
 if not ConvolveData(TREdit.value) then exit;
 DrawGrafClick('Signal','Time (volumes) Variance='+realtostr(AveVar,3),round(60000 / TREdit.value),0);
 lG.free;

end; *)

procedure TForm1.DesignDropChange(Sender: TObject);
var
  lFMRI: TFMRI;
begin
  GetSet(lFMRI);
  //exit;
  CalcDesign(lFMRI);
  DrawGrafClick (lFMRI,Image1);
end;

procedure TForm1.HRFChange(Sender: TObject);
begin
  Timer2.enabled := false;
  Timer2.enabled := true;
end;

procedure TForm1.AdvancedCheckChange(Sender: TObject);
begin
  AdvancedPanel.Visible := AdvancedCheck.checked;
  (*if AdvancedCheck.Checked then
       Panel1.Height := 104
    else
      Panel1.Height := 68; *)
end;

procedure TForm1.CopyMenuClick(Sender: TObject);
begin
  Clipboard.Assign(Image1.Picture.Bitmap);
end;

procedure TForm1.DoubleGammaCheckChange(Sender: TObject);
begin
  CalcHrf(DoubleGammaCheck.Checked);
  EditChange(nil);
end;

procedure TForm1.Export1Click(Sender: TObject);
const
kT =chr(9);
kCR =chr(10);
var
	lInc,lCond: integer;
	  lFMRI: TFMRI;
          lTR: double;
          lMemo1: string;
begin
     GetSet(lFMRI);
     CalcDesign(lFMRI);
     DrawGrafClick (lFMRI,Image1);
     if (lFMRI.EventOnsetRAPts < 1) or (lFMRI.nCond < 1) then begin
        showmessage('No conditions to copy');
        exit;
     end;
     lTR := lFMRI.TRmsec/1000;
     lMemo1 := '';
     for lCond := 1 to lFMRI.nCond do begin
         lMemo1 := lMemo1+(' FSL 3-Column file to Condition '+inttostr(lCond))+kCR;
         for lInc := 1 to lFMRI.EventOnsetRAPts do begin
             if lFMRI.EventCondRA^[lInc] = lCond then
                lMemo1 := lMemo1+(floattostr(lFMRI.EventOnsetRA^[lInc]*lTR)+kT+'1'+kT+'1')+kCR;
         end;
     end;
          Clipboard.AsText:= lMemo1;
     showmessage('Exported data to the clipboard. You can now paste this into a spreadsheet application.');
end;

procedure TForm1.Export2Click(Sender: TObject);
const
kT =chr(9);
kCR =chr(10);
var
   lInc,lCond: integer;
   lFMRI: TFMRI;
   lMemo1,lS: string;
begin
     GetSet(lFMRI);
     CalcDesign(lFMRI);
     DrawGrafClick (lFMRI,Image1);
     if (lFMRI.SignalRApts < 1) or (lFMRI.nCond < 1) then begin
        showmessage('No conditions to copy');
        exit;
     end;
     lMemo1 := '';
     for lInc := 1 to lFMRI.SignalRApts do begin
         lS := '';
         for lCond := 1 to lFMRI.nCond do begin
             lS := lS + floattostr(lFMRI.SignalRA^[lInc+((lCond-1)*lFMRI.SignalRApts)] );
             if lCond < lFMRI.nCond then
                lS := lS + kT;
         end;
         lMemo1 := lMemo1+lS + kCR;
     end;
     Clipboard.AsText:= lMemo1;
     showmessage('Exported data to the clipboard. You can now paste this into a spreadsheet application.');
end;


procedure TForm1.FormShow(Sender: TObject);
begin
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  //DesignDrop.ItemIndex := 0;

end;

end.

