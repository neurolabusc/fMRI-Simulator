unit main; 

{$IFDEF FPC}{$mode objfpc}{$H+} {$ENDIF}

interface

uses
   Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  Buttons, ExtCtrls, Menus, Math;
const
     kHRFduration = 32000;//msec for 'full' HRF
     kMaxCond = 8;
     kColorRA: array [1..kMaxCond] of TColor = (clLime,clRed,clBlue,clPurple,clTeal,clFuchsia,clYellow,clBlack);
     kMaxOrderRA = 32000;
     //the next items are types of designs...
     kShowHRF = 0;
     kBlock = 1;
     kFixedISI = 2;
     kExpoISI = 3;
     kRandomISI = 4;
type
    TOrderRA = array [1..kMaxOrderRA] of byte;
    tDouble = array [1..1] of double;
    tDoubleRAp = ^tDouble;
    LongIntRA = array [1..1] of LongInt;
    LongIntRAp = ^LongIntRA;
    THRF = record
       p1,p2,p3,p4,p5: double;
    end;
    TFMRI = record
          FinalCondIsRest,Counterbalance: boolean;
          Htickwid: Double;
          EventOnsetRApts,SignalRApts,nCond, Volumes , TRmsec,OptimalBlockMSEC: integer;
          Design,nPermute,meanISI,minISI, Iterations: integer;
          VTitle,HTitle: string;
          //666 CondNameRA : array [1..kMaxCond] of string[255];
          EventOnsetRA,SignalRA:tDoubleRAp;
          EventCondRA: LongIntRAp;
    end;
procedure DrawGrafClick (l: TFMRI; GrafImage: TImage);
function CalcDesign( var g: TFMRI): boolean;
procedure CalcHRF (lDoubleGammaHRF: boolean);
var
        gHRF: THRF;
        gHRFra: array of double;

implementation

procedure ClearAllRA (var lFMRI: TFMRI);
begin
	 if lFMRI.SignalRAPts > 1 then freemem(lFMRI.SignalRA);
	 lFMRI.SignalRAPts := 0;
	 if lFMRI.EventOnsetRAPts > 1 then begin
		freemem(lFMRI.EventOnsetRA);
		freemem(lFMRI.EventCondRA);
	 end;
	 lFMRI.EventOnsetRAPts := 0;
end;

function SignalRAGetMem (lVolumes,lCond: integer; var lFMRI: TFMRI): boolean;
begin
  result := false;
  if lFMRI.SignalRAPts > 1 then freemem(lFMRI.SignalRA);
  lFMRI.SignalRAPts := lVolumes;
  if lFMRI.SignalRAPts < 1 then exit;
  if (lCond < 1) or (lCond > kMaxCond) then exit;
  lFMRI.nCond := lCond;
  getmem(lFMRI.SignalRA, lCond * lFMRI.SignalRAPts * sizeof(Double));
  //if gResetRandom then
  RandSeed := 0;
  result := true;
end;

FUNCTION Gamma(X: double): double;
//From Borland Pascal Programs for Scientists and Engineers }
//by Alan R. Miller, Copyright C 1993, SYBEX Inc }
VAR
  I, J: Integer;
  Y, Gam: double;

BEGIN    { Gamma function }
  IF X >= 0.0 THEN
    BEGIN
      Y := X + 2.0;
      Gam := Sqrt(2 * Pi/Y)
        * Exp(Y*Ln(Y) + (1 - 1/(30*Y*Y))/(12*Y)-Y);
      result := Gam / (X * (X+1))
    END
  ELSE  { X < 0 }
    BEGIN
      J := 0;  Y := X;
      REPEAT { increment argument until positive }
        J := J + 1;
        Y := Y + 1.0
      UNTIL Y > 0.0;
      Gam := Gamma(Y); { recursive call }
      FOR I := 0 TO J-1 DO
        Gam := Gam / (X + I);
      result := Gam
    END   { if }
END; { Gamma function }

function spm_Gpdf(x,h,l: double): double; //emulates spm_Gpdf.m
begin
	result := power(l,h)*power(x,(h-1))* exp(-l*x);
	result := result / gamma(h);
end;

procedure CalcHRF (lDoubleGammaHRF: boolean); //emulates spm_hrf.m
const
	TR = 0.001;

var
	lMax: double;
	lInc: integer;
begin
  if lDoubleGammaHRF then
     for lInc := 0 to kHRFduration do
	gHRFra[lInc] := spm_Gpdf(lInc,gHRF.p1/gHRF.p3,TR/gHRF.p3)- spm_Gpdf(lInc,gHRF.p2/gHRF.p4,TR/gHRF.p4)/gHRF.p5
  else //only single gamma
      for lInc := 0 to kHRFduration do
	gHRFra[lInc] := spm_Gpdf(lInc,gHRF.p1/gHRF.p3,TR/gHRF.p3);
  //find max
  lMax := gHRFra[0];
  for lInc := 0 to kHRFduration do
	if gHRFra[lInc] > lMax then
		lMax := gHRFra[lInc];
  //scale so max = 1;
  for lInc := 0 to kHRFduration do
		gHRFra[lInc] := gHRFra[lInc]/lMax;
end;


procedure DrawGrafClick (l: TFMRI; GrafImage: TImage);
const
        {$IFDEF LCLCocoa}
        kScale = 2;
        {$ELSE}
        kScale = 1;
        {$ENDIF}
        kHBrdr = 20 * kScale;
	kHRightBrdr = 5 * kScale;
	kVBrdr = 45 * kScale;
var
   lGrid: boolean;
   lVDiv,lVRngStart,lVRng,lEventsPerHPixel,lVScale,lVMin, lVMax, lEventWid: double;
   bmp: TBitmap;
     lMaxMS,lSignalRAPts,lnCond,lGrafWid,lGrafHt,lCondOffset,lHPos,
   lC,lInc,lVPos,lTxtOffset,lVDigits,lPos,lEvent,lHPixels,lGrafBtm: integer;
begin
     lGrid := true;
     lnCond := l.nCond;
     if l.TRmsec < 1 then
        exit;
     if (l.Volumes >= 0) and (l.nCond > 1) and (l.FinalCondIsRest) then
        lnCond := lnCond-1;
      lGrafWid := round(GrafImage.Width * kScale);
      lGrafHt := round(GrafImage.height * kScale);
      bmp := TBitmap.Create;
      bmp.Width := lGrafWid;
      bmp.height := lGrafHt;
      bmp.Canvas.pen.width := kScale;
      lTxtOffset :=  bmp.Canvas.TextHeight('H') div 2;
      bmp.Canvas.pen.color := clBlack;
      bmp.Canvas.Brush.Color := clWhite;
      bmp.Canvas.Font.Color := clBlack;
      bmp.Canvas.Pen.Style := psSolid;
      bmp.Canvas.Font.Size:= round(12 * kScale);
      bmp.Canvas.Rectangle (0,0,lGrafWid,lGrafHt);
      if (l.SignalRApts < 2) or (lGrafWid < (3*kHBrdr)) or (lGrafHt < (3*kVBrdr)) then exit;
      lEventWid := (lGrafWid - kHBrdr-kHRightBrdr) / (l.SignalRAPts-1);
      lVMin := l.SignalRA^[1];
      lVMax := l.SignalRA^[1];
      lPos := l.SignalRAPts * l.nCond;
       for lInc := 2 to lPos do begin
	       if l.SignalRA^[lInc] > lVMax then lVMax := l.SignalRA^[lInc];
	       if l.SignalRA^[lInc] < lVMin then lVMin := l.SignalRA^[lInc];
       end;
       if lVMax <= lVMin then exit;
       lVScale := (lGrafHt - kVBrdr- kVBrdr) / (lVMAx-lVMin);
       lGrafBtm := lGrafHt - kVBrdr;
       bmp.Canvas.pen.color := clBlack;
       bmp.Canvas.moveto(kHBrdr-2,lGrafBtm);
       bmp.Canvas.lineto(kHBrdr-2,round(lGrafBtm- ((lVMax-lVMin) * lVScale)));
       //Vertical bars follows
       lGrid := true;
       if (l.Htickwid > 0) and (l.SignalRApts > l.HtickWid) and (lGrid) then begin
		lInc := 1;
		lHPos := (kHBrdr+round((lInc)*l.HTickWid*lEventWid));
		while (lHpos <= (lGrafWid-kHRightBrdr)) do begin
			  bmp.Canvas.moveto(lHPos,lGrafBtm);
			  bmp.Canvas.lineto(lHPos,round(lGrafBtm- ((lVMax-lVMin) * lVScale)));
			  inc(lInc);
			  lHPos := (kHBrdr+round((lInc)*l.HTickWid*lEventWid));
		end;
	 end;
	 bmp.Canvas.pen.color := clSilver;
	 if (lVMin <= 0) and (lVMax > 0) then begin
                if lGrid then begin
		   bmp.Canvas.moveto(kHBrdr,round(lGrafBtm- ((0-lVMin) * lVScale)));
		   bmp.Canvas.lineto(lGrafWid-kHRightBrdr,round(lGrafBtm- ((0-lVMin) * lVScale)));
                end;
		if abs(lVMin) > lVMax then
		   lVRng := abs(lVMin)
		else
			lVRng := lVMax;
	 end else
		 lVRng := lVMax - lVMin;
	 //horizontal grid
	 if lVRng >= 1 then begin
		//lVDigits := length(inttostr(round(lVRng)));
                lVDigits := 2;
                lVDiv := 1;
		if lVDigits > 1 then begin
		   for lInc := 2 to lVDigits do
			   lVDiv := lVDiv * 10;
		end;
		lVRngStart := round(lVMax / lVDiv) * lVDiv;

		repeat
			  lVPos := round(lGrafBtm- ((lVRngStart-lVMin) * lVScale));
			  bmp.Canvas.TextOut(2,lVPos-lTxtOffset,inttostr(round(lVRngStart)));
                          if lGrid then begin
			     bmp.Canvas.moveto(kHBrdr,lVPos);
			     bmp.Canvas.lineto(lGrafWid-kHRightBrdr,lVPos);
                          end;
			  lVRngStart := lVRngStart - lVDiv;
		until lVRngStart < lVMin;
	 end else begin
		 if lVRng > 0.1 then
			lVDigits := 2
		 else if lVRng > 0.01 then
			 lVDigits := 3
		 else
			 lVDigits := 4;
		lVDiv := 1;
		if lVDigits > 1 then begin
		   for lInc := 2 to lVDigits do
			   lVDiv := lVDiv / 10;
		end;
		lVRngStart := round(lVMax / lVDiv) * lVDiv;
		repeat
			  lVPos := round(lGrafBtm- ((lVRngStart-lVMin) * lVScale));
			  if lVRngStart < lVDiv then
				 bmp.Canvas.TextOut(2,lVPos-lTxtOffset,floattostrf(0{lVRngStart},ffGeneral,lVDigits,4))
			  else
				  bmp.Canvas.TextOut(2,lVPos-lTxtOffset,floattostrf(lVRngStart,ffGeneral,lVDigits,4));
			  bmp.Canvas.moveto(kHBrdr,lVPos);
			  bmp.Canvas.lineto(lGrafWid-kHRightBrdr,lVPos);
			  lVRngStart := lVRngStart - lVDiv;
		until lVRngStart < lVMin;
	 end;
	 //Horizontal border follows
	 bmp.Canvas.pen.color := clGray;
	 bmp.Canvas.moveto(kHBrdr,lGrafBtm+2);
	 bmp.Canvas.lineto(lGrafWid-kHRightBrdr,lGrafBtm+2);
	 bmp.Canvas.pen.color := clBlack;
	 bmp.Canvas.TextOut(kHBrdr,lGrafBtm+8,'1');
	 bmp.Canvas.TextOut(lGrafWid-kHRightBrdr-bmp.Canvas.TextWidth(inttostr(l.SignalRApts))
	 ,lGrafBtm+8,inttostr(l.SignalRApts));
	 bmp.Canvas.TextOut((lGrafWid div 2)-bmp.Canvas.TextWidth(l.HTitle),lGrafBtm+8,l.HTitle);
         if l.Volumes = MaxInt then
            lSignalRAPts := 0
         else if (l.Volumes < 1) or (l.Volumes > l.SignalRAPts) or (lnCond < 1) then
            lSignalRAPts := l.SignalRAPts
         else begin
             lSignalRAPts := l.Volumes;
         end;
         lMaxMS :=  round((lSignalRAPts-1) );
	 if (lEventWid < 1) and (lMaxMS > 0) then begin
		lHPixels := lGrafWid - kHBrdr-kHRightBrdr;
		lEventsPerHPixel := 1/lEventWid;
                bmp.Canvas.pen.width := 3*kScale;
                for lC := 1 to lnCond do begin
		bmp.Canvas.pen.color := kColorRA[lC];
		lCondOffset := (lC-1)*l.SignalRApts;
		bmp.Canvas.moveto(kHBrdr,round(lGrafBtm- ((l.SignalRA^[1+lCondOffset]-lVMin) * lVScale)));
		for lInc := 2 to lHPixels do begin
			lEvent := round(lEventsPerHPixel * lInc);
			if (lEvent < 1) or (lEvent > l.SignalRApts) then lEvent := l.SignalRApts;
			bmp.Canvas.lineto(kHBrdr+(lInc-1),round(lGrafBtm- ((l.SignalRA^[lEvent+lCondOffset]-lVMin) * lVScale)));
		end;
	   end; //for each cond
           //next - event tickmarks
                 lPos := -1;
		 if (l.EventOnsetRApts > 0) and (lEventWid >= 1){} then begin
			for lInc := 1 to l.EventOnsetRApts do begin
				if ((kHBrdr+round((l.EventOnsetRA^[lInc]{-1})*lEventWid)) <> lPos) and (l.EventOnsetRA^[lInc] <= lMaxMS) then begin;
                                   if l.EventCondRA^[lInc] <= lnCond then begin
				      lPos := kHBrdr+round((l.EventOnsetRA^[lInc]{-1})*lEventWid);
				      bmp.Canvas.pen.color := kColorRA[ l.EventCondRA^[lInc]];
				      bmp.Canvas.moveto(kHBrdr+round((l.EventOnsetRA^[lInc]{-1})*lEventWid),2);
				      bmp.Canvas.lineto(kHBrdr+round((l.EventOnsetRA^[lInc]{-1})*lEventWid),6);
                                   end;
				end;
			end;
		 end;//eventpts >1
	 end else begin //eventwid > 1
		 //next -
                 bmp.Canvas.pen.width := 3*kScale;
		 for lC := 1 to lnCond do begin
			bmp.Canvas.pen.color := kColorRA[lC];
			lCondOffset := (lC-1)*l.SignalRApts;
			bmp.Canvas.moveto(kHBrdr{+round(lEventWid)},round(lGrafBtm- ((l.SignalRA^[1+lCondOffset]-lVMin) * lVScale)));
			for lInc := 2 to lSignalRApts do
				bmp.Canvas.lineto(kHBrdr+round((lInc-1)*lEventWid),round(lGrafBtm- ((l.SignalRA^[lInc+lCondOffset]-lVMin) * lVScale)));
		 end;
		 bmp.Canvas.pen.width := kScale;
		 //next -volume tick marks
		 bmp.Canvas.pen.color := clBlack;
		 for lInc := 1 to l.SignalRApts do begin
				lPos := kHBrdr+round((lInc-1)*lEventWid);
				bmp.Canvas.moveto(lPos,lGrafBtm+2);
				bmp.Canvas.lineto(lPos,lGrafBtm+6);
		 end;
		 if (l.EventOnsetRApts > 0)  then begin
                    if (lGrafWid/l.EventOnsetRApts)>= 6 then
				bmp.Canvas.pen.width := 3*kScale;
			for lInc := 1 to l.EventOnsetRApts do begin
                            if  (l.EventOnsetRA^[lInc] <= lMaxMS) then begin
                                if l.EventCondRA^[lInc] <= lnCond then begin
				   lPos := kHBrdr+round((l.EventOnsetRA^[lInc]{-1})*lEventWid);
				   bmp.Canvas.pen.color := kColorRA[ l.EventCondRA^[lInc]];
				   bmp.Canvas.moveto(lPos,2);
				   bmp.Canvas.lineto(lPos,16);
                                end;
                            end;
			end; //for each event
			bmp.Canvas.pen.width := kScale;
		 end;//eventpts >1
	 end; //event wid > 1
         GrafImage.Picture.Bitmap := bmp;
         //img.Height := round(1/scale * bmp.Height);
         //img.Width := round(1/scale * bmp.Width);
         GrafImage.AntialiasingMode:= amOn;
         bmp.free;
end;

function HRF(ms: integer): double; //get value from lookup table
begin
	if (ms < 0) or (ms > kHRFduration) then
		result := 0
	else
		result := gHRFra[ms];
end;

function ConvolveData (var g: TFMRI): boolean;
var
  lHRFdurationTR,lHRFStart,lMinISITR,lISITR: double;
  lVol,lEvent,lCond,lCondOffset: integer;
begin
//next - convolve data
	result := false;
	if g.EventOnsetRAPts < 1 then exit;
	if g.SignalRAPts < 1 then exit;
	if g.nCond < 1 then exit;
        if g.TRmsec < 1 then
           exit;
        //determine minimum time between events...
        //first compute in terms of TR...
        lMinISITR := maxint;
        if g.EventOnsetRAPts > 1 then begin
	  for lVol := 1 to g.SignalRAPts do begin
              for lEvent := 2 to g.EventOnsetRAPts do begin
                  lISITR := g.EventOnsetRA^[lEvent] - g.EventOnsetRA^[lEvent-1];
                  if lISITR < lMinISITR then
                     lMinISITR := lISITR;//lISI;
              end; //for each event
	  end; //for each volume
        end; //at least two events...
        //convert from TRs to msec
        //next... convolve
	for lCond := 1 to g.nCond do begin
	  lCondOffset := (lCond-1) * g.SignalRAPts;
	  lHRFdurationTR := kHRFduration / g.TRmsec;
	  for lVol := 1 to g.SignalRAPts do begin
		 g.SignalRA^[lVol+lCondOffset] := 0;
		 lHRFStart := (lVol -1) -lHRFdurationTR;
		 lEvent := 1;
		 repeat
			   if (g.EventCondRA^[lEvent]=lCond) and ((g.EventOnsetRA^[lEvent]) >= lHRFstart) then begin
				  g.SignalRA^[lVol+lCondOffset] :=  g.SignalRA^[lVol+lCondOffset]
                                  + (HRF (round(kHRFduration-(g.EventOnsetRA^[lEvent]-lHRFStart)*g.TRmsec)));
			   end;
			   inc(lEvent);
		   until (lEvent > g.EventOnsetRAPts) {or (gEventOnsetRA[lEvent] > (lVol-1))};
	  end; //for each volume
	end; //for each condition
	result := true;
end;

function ChooseRandomCond (var lEventCondRA : array of longint; var g: TFMRI): integer;
var
   lRand,lRemaining: integer;
begin
        result := random(g.nCond)+1;
     lRemaining := lEventCondRA[0];
     if lRemaining < 1 then begin
        //exhausted supply of conditions...
        result := random(g.nCond)+1;
        exit;
     end;
     lRand := (Random(lRemaining)) + 1;
     result := lEventCondRA[lRand];
     lEventCondRA[lRand] := lEventCondRA[lRemaining];
     lEventCondRA[0] := lRemaining - 1;
end;

function Modx (lNum,lDenom: integer): integer;
//remainder, indexed from 1 not zero
// mod(n,8) will return 0..7, while Modx(n,8) will return 1..8
begin
    result := lNum mod lDenom;
    if result = 0 then
       result := lDenom
end;

function  randomizeEventOrderCounterbalanced(var g: TFMRI): boolean;
var
   lPrevCond,lCondPerPrevCond,lCond,lSwap,lEvent: integer;
   lEventCondRA : array [1..kMaxCond] of  array of longint;
begin
     result := false;
     if (g.nCond < 2) or (g.nCond > kMaxCond) then
        exit;
     lCondPerPrevCond := (g.EventOnsetRAPts+g.nCond-1) div g.nCond;
     if (lCondPerPrevCond < 2) then
        exit;
     for lCond := 1 to g.nCond do begin
         setlength(lEventCondRA[lCond],(1+lCondPerPrevCond));
         lEventCondRA[lCond][0] := lCondPerPrevCond;
         for lSwap := 1 to lCondPerPrevCond do
              lEventCondRA[lCond][lSwap] := Modx(lSwap,g.nCond);
     end;
     lPrevCond := random(g.nCond)+1;
     for lEvent := 1 to g.EventOnsetRAPts do begin
         g.EventCondRA^[lEvent] :=  ChooseRandomCond (lEventCondRA[lPrevCond], g);
         lPrevCond := g.EventCondRA^[lEvent];
     end;
     for lCond := 1 to g.nCond do
         lEventCondRA[lCond] := nil;
     result := true;
end;

procedure randomizeEventOrder(var g: TFMRI);
var
	lEvent,lRand,lSwap: integer;
begin
  if (g.EventOnsetRAPts< 1) then exit;
  if (g.Counterbalance) and (randomizeEventOrderCounterbalanced(g)) then
     exit;
  for lEvent := 1 to g.EventOnsetRAPts do begin
	g.EventCondRA^[lEvent] := lEvent mod g.nCond;
	if g.EventCondRA^[lEvent] = 0 then
		g.EventCondRA^[lEvent] :=  g.nCond;
  end;
  for lEvent := g.EventOnsetRAPts downto 1 do begin
			lRand := (Random(lEvent)) + 1;
			lSwap := g.EventCondRA^[lRand];
			g.EventCondRA^[lRand] := g.EventCondRA^[lEvent];
			g.EventCondRA^[lEvent] := lSwap;
	end;
end;

function randomizeBlockOrder (lnCond,lBlocksPerCond: integer; var gOrderRA: TOrderRA): boolean;
var
 lCountRA: array [1..kMaxCond] of integer;
 lBlock,lRan,lTotalBlocks,lPrev,lSwap,lSwapPos,lPreSwap,lPostSwap: integer;

begin
	result := false;
	lTotalBlocks := lnCond*lBlocksPerCond;
	if lTotalBlocks > kMaxOrderRA then exit;
	for lBlock := 1 to lnCond do
		lCountRA[lBlock] := lBlocksPerCond;
	lCountRA[1] := lBlocksPerCond-1; //start with cond 1}
	gOrderRA[1] := 1;
	for lBlock := 2 to lTotalBlocks do begin
	   lPrev := gOrderRA[lBlock-1];
	   repeat
		lRan := random(lnCond)+1;
	   until (lRan <> lPrev);
	   if (lCountRA[lRan] = 0) then begin //exhausted see if there are other options
			lSwap := 0;
			for lSwapPos := 1 to lnCond do begin
				if (lSwapPos <> lPrev) and (lCountRA[lSwapPos] > 0) then
					lSwap := 1;
			end;
			if lSwap > 0 then begin //other possibilities exist
				repeat
					lRan := random(lnCond)+1;
				until (lRan <> lPrev) and (lCountRA[lRan] <> 0);
			end;
	   end;
	   if (lCountRA[lRan] = 0) then begin //exhausted pick - need to swap
			repeat
				lRan := random(lnCond)+1;
			until   (lCountRA[lRan] <> 0);
			repeat
				lSwapPos := random(lBlock-3)+2;
				lPreSwap := gOrderRA[lSwapPos-1];
				lSwap := gOrderRA[lSwapPos];
				lPostSwap := gOrderRA[lSwapPos+1];
			until (lSwap <> lPrev)  and (lPreSwap<>lRan) and (lPostSwap <> lRan);
			gOrderRA[lSwapPos] := lRan;
			lRan := lSwap;
		end; //need to swap
		gOrderRA[lBlock] := lRan;
		dec(lCountRA[lRan]);
		//inc(lBlock);
	end; //for each block
	result := true;
end;

function EventRAGetMem (lEvents: integer; var g: TFMRI): boolean;
begin
	 result := false;
	 if lEvents < 1 then exit;
	 if g.EventOnsetRAPts > 1 then freemem(g.EventOnsetRA);
	 if g.EventOnsetRAPts > 1 then freemem(g.EventCondRA);
	 g.EventOnsetRAPts := lEvents;
	 getmem(g.EventOnsetRA,g.EventOnsetRAPts*sizeof(double));
	 getmem(g.EventCondRA,g.EventOnsetRAPts*sizeof(longint));
	 result := true;
end;

function generateBlockEvents ( var g: TFMRI): boolean ;
var
	lEventsPerBlock,lCond,lInc,lMS,lBlockNum,lBlockMS,lBlocksPerCond,lnCond: integer;
        gOrderRA: TOrderRA;
begin
  result := false;
  if (g.meanISI < 1) or ((g.SignalRAPts * g.TRmsec) < 1) or (g.TRmsec < 1) then
  exit;
  lnCond := g.nCond;
  if lnCond = 1 then
      lnCond := 2; //need a rest to induce HRF variability
  lBlockMS := g.OptimalBlockMSEC;//12000;
  lBlocksPerCond :=  round((g.SignalRAPts * g.TRmsec) / (lBlockMS*lnCond));
  if lBlocksPerCond < 1 then begin
       showmessage('Study duration is not long enough to model - increase number of volumes.');
       exit;
  end;
  lBlockMS := round((g.SignalRAPts * g.TRmsec)/(lBlocksPerCond*lnCond));
  lEventsPerBlock := trunc (lBlockMS / g.meanISI);
  lBlockMS := (g.meanISI * lEventsPerBlock)+g.meanISI;
  if lEventsPerBlock < 1 then begin
  showmessage('You need to reduce the meanISI.');
  exit;
  end;
  if g.nCond > 2 then
      randomizeBlockOrder (g.nCond,lBlocksPerCond, gOrderRA);
  if not EventRAGetMem(g.nCond*lEventsPerBlock * lBlocksPerCond, g) then exit;
  lMS := 0;
  lBlockNum := 1;
  lCond := 1;
  for lInc := 1 to g.EventOnsetRAPts do begin
       g.EventOnsetRA^[lInc] := lMS/g.TRmsec;
       g.EventCondRA^[lInc] := lCond;
       if (g.nCond = 1) and (lInc mod lEventsPerBlock = 0) then
	      lMS := lMS + lBlockMS //rest block follows
       else
	       lMS := lMS + g.meanISI;
       if (lInc mod lEventsPerBlock) = 0 then begin
	       inc(lBlockNum);
	       if g.nCond > 2 then
		      lCond := gOrderRA[lBlockNum]
	       else begin
		      inc(lCond);
		      if lCond > g.nCond then
			      lCond := 1;
	       end;
       end;
  end;
  result := true;
end;

function xPermuteBlock(var g: TFMRI): boolean;
var
	lPermute,lRan,lRan2,lSwap: integer;
begin
	result := false;
	if (g.nPermute < 1) or (g.EventOnsetRAPts < 3) then exit;
	for lPermute := 1 to g.nPermute do begin
		repeat
			lRan := random(g.EventOnsetRAPts)+1;
			lRan2 := random(g.EventOnsetRAPts)+1;
		until lRan <> lRan2;
		lSwap := g.EventCondRA^[lRan];
		g.EventCondRA^[lRan] := g.EventCondRA^[lRan2];
		g.EventCondRA^[lRan2] := lSwap;
	end;
	result := true;
end;

function GenerateBlock(var g: TFMRI): boolean;
begin
	 result := false;
         ClearAllRA(g);
	 if not SignalRAGetMem (g.Volumes,g.nCond, g) then exit;
	 if not generateBlockEvents ( g) then exit;
         xPermuteBlock(g);
	 ConvolveData(g);
         result := true;
end;

function SexPo: single;
{(STANDARD-)  E X P O N E N T I A L   DISTRIBUTION
FOR DETAILS SEE:
AHRENS, J.H. AND DIETER, U. COMPUTER METHODS FOR SAMPLING FROM THE
EXPONENTIAL AND NORMAL DISTRIBUTIONS. COMM. ACM, 15,10 (OCT. 1972), 873 - 882.
ALL STATEMENT NUMBERS CORRESPOND TO THE STEPS OF ALGORITHM 'SA' IN THE ABOVE PAPER (SLIGHTLY MODIFIED IMPLEMENTATION)
Modified by Barry W. Brown, Feb 3, 1988 to use RANF instead of SUNIF.
The argument IR thus goes away.
	 Q(N) = SUM(ALOG(2.0)**K/K!)    K=1,..,N ,      THE HIGHEST N
	 (HERE 8) IS DETERMINED BY Q(N)=1.0 WITHIN STANDARD PRECISION}
label
	20, 30, 60,70;
const
	q: array [1..8] of single = (
	0.6931472,0.9333737,0.9888778,0.9984959,0.9998293,0.9999833,0.9999986,1.0);
var
	i: integer;
	a,u,ustar,umin: single;
begin
	a := 0.0;
	u := random;
	goto 30;
20:
	a := a+ q[1];
30:
	u := u + u;
	if(u <= 1.0) then goto 20;
	u := u - 1.0;
	if(u > q[1]) then goto 60;
	result := a+u;
	exit;
60:
	i := 1;
	ustar := random;
	umin := ustar;
70:
	ustar := random;
	if(ustar < umin) then
		umin := ustar;
	i := i + 1;
	if(u > (q[i])) then goto 70;
	result := a+umin*q[1];
end;

function genexp (Av: single): single;
//Generates a single random deviate from an exponential distribution with mean AV.
begin
	result := sexpo*av;
end;

function generateJitteredEvents ( lExponential: boolean; var g: TFMRI): boolean ;
//g.minISI,g.meanISI,(g.SignalRAPts * g.TRmsec),g.TRmsec,
var
	lRan,lErrorInt,lEvents,lInc: integer;
	lError,lAv: double;
begin
	 result := false;
	 if g.minISI >= g.meanISI then exit;
	 lAv :=  g.meanISI -g.minISI;
	 lEvents := trunc ((g.SignalRAPts * g.TRmsec) / g.meanISI);
	 if not EventRAGetMem(lEvents,g) then exit;
	randomizeEventOrder(g);
	if not lExponential  then begin
	 lRan := round(lAv*2);
	 for lInc := 1 to lEvents do
		g.EventOnsetRA^[lInc] := random(lRan)+ g.minISI;
	end else
	 for lInc := 1 to lEvents do
		g.EventOnsetRA^[lInc] := genexp(lAv)+ g.minISI;
	 //next calculate mean
	 lAv := 0;
	 for lInc := 1 to lEvents do
		lAv := lAv+ g.EventOnsetRA^[lInc];
	 lAv := lAv / g.EventOnsetRAPts;
	 //baseline correct
	 lError := g.meanISI - lAv;
	 for lInc := 1 to lEvents do begin
		g.EventOnsetRA^[lInc] := round(g.EventOnsetRA^[lInc]+lError);
		if g.EventOnsetRA^[lInc] < g.minISI then
			g.EventOnsetRA^[lInc] := g.minISI;
	 end;
	 //problem - rounding values may make whole session a few ms too long or too short
	 //also, we did not allow any values to be less than min time, so time tends to run long
	 //here we correct this
	 lAv := 0;
	 for lInc := 1 to lEvents do
		lAv := lAv+ g.EventOnsetRA^[lInc];//compute sum
	 lErrorInt := round( (g.EventOnsetRAPts*g.meanISI)-lAv);
	 if lErrorInt < 0 then begin
		for lInc := 1 to abs(lErrorInt) do begin
			lRan := random(g.EventOnsetRAPts)+1;
			g.EventOnsetRA^[lRan] := g.EventOnsetRA^[lRan]-1
		end;
	 end else if lErrorInt > 0 then begin
		for lInc := 1 to abs(lErrorInt) do begin
			lRan := random(g.EventOnsetRAPts)+1;
			g.EventOnsetRA^[lRan] := g.EventOnsetRA^[lRan]+1
		end;
	 end;
	 //present first stimuli at very beginning
	 g.EventOnsetRA^[1] := 0;
	 //compute onset time as cumulative
	 for lInc := 2 to g.EventOnsetRAPts do
		g.EventOnsetRA^[lInc] := g.EventOnsetRA^[lInc]+g.EventOnsetRA^[lInc-1];//cumulative MS
	 //compute onset time in scans
	 for lInc := 1 to g.EventOnsetRAPts do
		g.EventOnsetRA^[lInc] := g.EventOnsetRA^[lInc]/g.TRmsec;//cumulative TR
	 result := true;
end; //generateJitteredEvents

function generateFixedEvents ( var g: TFMRI): boolean ;
var
       lEvents,lInc,lMS: integer;
begin
       result := false;
       lEvents := trunc ((g.SignalRAPts * g.TRmsec) / g.meanISI);
       if not EventRAGetMem(lEvents,g) then exit;
       randomizeEventOrder(g);
       lMS := 0;
        for lInc := 1 to g.EventOnsetRAPts do begin
       	 g.EventOnsetRA^[lInc] := lMS/g.TRmsec ;
       	 lMS := lMS + g.meanISI;
        end;
        result := true;
end;

 function StDev (lCond: integer; var g: TFMRI): double;
var
	lScan,lCondOffset: integer;
	lSumSqr,lSum: double;
begin
	result := 0;
	if (g.SignalRAPts div g.nCond) < 3 then
		exit;
        if g.SignalRAPts < 2 then
           exit;
	lCondOffset := (lCond-1) * g.SignalRAPts;
	lSumSqr := 0;
	lSum := 0;
	 for lScan := 1 to g.SignalRAPts do begin
		lSum := lSum + g.SignalRA^[lScan+lCondOffset];
		lSumSqr := lSumSqr + Sqr(g.SignalRA^[lScan+lCondOffset]);
	 end;
	 result := (lSumSqr - ((Sqr(lSum))/g.SignalRAPts));
	 if  (result > 0) then
		result :=  Sqrt ( result/(g.SignalRAPts-1))
	 else
		result := 0;
end;

function AveVar (var g: TFMRI) : double;
var lCond: integer;
begin
	result := 0;
	if (g.nCond < 1) or (g.TRMsec < 1) then exit;
	for lCond := 1 to g.nCond do
		result := result + sqr(StDev(lCond, g));
	result := result / g.nCond;
end;

procedure CopyRA (lOnsetSource,lOnsetDest: tDoubleRAp; lOrderSource,lOrderDest: LongIntRAp; lItems: integer);
var
	lPos:integer;
begin
	for lPos := 1 to lItems do
		lOnsetDest^[lPos] := lOnsetSource^[lPos];
	for lPos := 1 to lItems do
		lOrderDest^[lPos] := lOrderSource^[lPos];
end;

function GenerateEvent (var g: TFMRI): boolean;
label
        666;
var
	lnIteration,lIteration,lEventRAPts: integer;
	lBestSD,lSD: double;
	lBestOrderRA: LongIntRAp;
	lBestEventRA: tDoubleRAp;
begin
     result := false;
     ClearAllRA(g);
     if not SignalRAGetMem (g.Volumes,g.nCond,g) then exit;
     lEventRAPts := trunc ((g.SignalRAPts * g.TRmsec) / g.meanISI);
     if lEventRAPts < 1 then exit;
	 getmem(lBestEventRA,lEventRAPts*sizeof(double));
	 getmem(lBestOrderRA,lEventRAPts*sizeof(longint));
	 lBestSD := 0; //1st iteration will be best
	 lnIteration := g.Iterations;
	 if lnIteration < 1 then
		lnIteration := 1;
         for lIteration := 1 to lnIteration do begin
	   if g.Design = kFixedISI then begin
                 if not generateFixedEvents (g) then goto 666;
           end else
               if not generateJitteredEvents ((g.Design = kExpoISI), g) then goto 666;
	   if not ConvolveData(g) then goto 666;
		lSD := AveVar(g);
		if lSD > lBestSD then begin
			CopyRA(g.EventOnsetRA,lBestEventRA,g.EventCondRA,lBestOrderRA,lEventRAPts);
			lBestSD := lSD;
		end;
	 end;
	 CopyRA(lBestEventRA,g.EventOnsetRA,lBestOrderRA,g.EventCondRA ,lEventRAPts);
         ConvolveData(g);
         result := true;
       666:
         freemem(lBestEventRA);
	 freemem(lBestOrderRA);
end;

function GenerateHRF(var lFMRI: TFMRI): boolean;
var lInc,lNumDeriv: integer;
begin
     result := false;
     ClearAllRA(lFMRI);
        lNumDeriv := 1; //hom many derivatives...
        lFMRI.Volumes := kHRFduration; randomize;
        lFMRI.nCond := lNumDeriv+1;
        if not SignalRAGetMem(kHRFduration,lFMRI.nCond,lFMRI) then exit;
        //666 lFMRI.CondNameRA[1] := 'HemodynamicResponseFunction';
	 for lInc := 1 to lFMRI.SignalRApts do begin
		 lFMRI.SignalRA^[lInc] := HRF(lInc);
	 end;
         if lNumDeriv > 0 then begin //1st derivative
            //666 lFMRI.CondNameRA[2] := 'TemporalDerivative(HRF'')';
            lFMRI.SignalRA^[1+lFMRI.SignalRApts] := 0.0;
            lFMRI.SignalRA^[lFMRI.SignalRApts+lFMRI.SignalRApts] := 0.0;

            for lInc := 2 to (lFMRI.SignalRApts-1) do
		 lFMRI.SignalRA^[lInc+lFMRI.SignalRApts] := 1000*(HRF(lInc+1)-HRF(lInc-1));
         end;
         if lNumDeriv > 1 then begin //2nd derivative
            //666 lFMRI.CondNameRA[3] := '(HRF'''')';
            lFMRI.SignalRA^[1+lFMRI.SignalRApts+lFMRI.SignalRApts] := 0.0;
            lFMRI.SignalRA^[lFMRI.SignalRApts+lFMRI.SignalRApts+lFMRI.SignalRApts] := 0.0;
	    for lInc := 2 to (lFMRI.SignalRApts-1) do
		 lFMRI.SignalRA^[lInc+lFMRI.SignalRApts+lFMRI.SignalRApts] := 500*(lFMRI.SignalRA^[lInc+lFMRI.SignalRApts-1]-lFMRI.SignalRA^[lInc+lFMRI.SignalRApts+1]);
            lFMRI.SignalRA^[lFMRI.SignalRApts+lFMRI.SignalRApts+lFMRI.SignalRApts-1] := 0;
	 end;

         lFMRI.VTitle:= 'Signal';
         lFMRI.HTitle := 'Time (ms)';
         lFMRI.FinalCondIsRest := false;
         lFMRI.Htickwid:= -1;
         result := true;
end;

function CalcDesign(var g: TFMRI): boolean;
begin
     result := false;
     g.Htickwid := -1.0;
     if g.Design = kShowHRF then begin
        result := GenerateHRF(g);
        exit;
     end else if g.Design = kBlock then
        result := GenerateBlock(g)
     else
         result :=  GenerateEvent(g);
     if (g.TRmsec > 0.0) then
        g.Htickwid:= 60000.0/g.TRmsec;
     g.HTitle:= 'Time (volumes) Variance='+floattostr(AveVar(g));
end;


initialization
   gHRF.p1:= 6; //delay of response
   gHRF.p2:=16;//delay of undershoot (relative to onset)
   gHRF.p3:=1; //dispersion of response
   gHRF.p4:=1; //dispersion of undershoot
   gHRF.p5:=6;  //ratio of response to undershoot
  setlength(gHRFra,kHRFduration+1);//+1 since indexed from zero
  CalcHRF(true);
end.

