unit DDU.WinAPI.MailSlots;

//*****************************************************************************
//
// DDUMETAL (DDUMailSlots)
// Copyright 2020 Clinton R. Johnson (xepol@xepol.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Version : 1.0
//
// Purpose : Simple Interprocess communication for Windows using Mailslots
//
// History : <none>
//
//*****************************************************************************

interface

{$I DVer.Inc}

uses
  System.Classes,
  System.SysUtils,
  WinAPI.Windows,
  WinAPI.Messages,
  VCL.Graphics,
  VCL.Controls, 
  VCL.Forms, 
  VCL.Dialogs;

{$I DTypes.Inc}

Type
  TDataEvent = Procedure(Sender : TObject; Data : String) of Object;
  TErrorEvent = Procedure(Sender : TObject; Error : String) of Object;

Type
  TCustomMailSlotDestination = class(TComponent)
  private
    { Private declarations }
    fEnabled      : Boolean;
    fLoadedOpen   : Boolean;
    fOnData       : TDataEvent;
    fOnError      : TErrorEvent;
    fSlotName     : String;
    TheThread     : TThread;
    fSlot         : THandle;

    Procedure SetEnabled(Value : Boolean) ; Virtual;
    Procedure SetSlotName(NewName : string) ; Virtual;
  protected
    { Protected declarations }
    Procedure Loaded; Override;

    Procedure DoError(anError : String);
    Procedure DoData(aData : String);
    Procedure DoTerminate(Sender : TObject);

    Procedure StartThread;
    Procedure StopThread;
  public
    { Public declarations }
    Constructor Create(AOwner : TComponent); Override;
    Destructor Destroy; Override;

    Property Enabled      : Boolean       Read fEnabled      Write SetEnabled      Default False;
    Property OnData       : TDataEvent    Read fOnData       Write fOnData;
    Property OnError      : TErrorEvent   Read fonError      Write fOnError;
    Property SlotName     : String        Read fSlotName     Write SetSlotName;
  End;


// Machine can be  . (local machine) or a computername or a domainname or * (entire network), see Win32 helpfile for more info.
type
  TCustomMailSlotSource = class(TComponent)
  private
    { Private declarations }
    fData         : String;
    fMachine      : String;
    fSlot         : THandle;
    fSlotName     : String;
    procedure SetMachine(const Value: String);
    procedure SetSlotName(const Value: String);
  protected
    { Protected declarations }
    Procedure SendData(NewValue : String);

    Procedure OpenSlot;
    Procedure CloseSlot;
  public
    { Public declarations }
    Constructor Create(AOwner : TComponent); OverRide;
    Destructor Destroy; Override;
    Function Send(ToSend : String) : {$IfDef Ver100}Integer{$Else}Cardinal{$EndIf};
    Procedure Reset;

    Property Data         : String        Read fData         Write SendData      Stored False;
    Property Machine      : String        Read fMachine      Write SetMachine;
    Property SlotName     : String        Read fSlotname     Write SetSlotName;
  end;

Type
  TMailSlotDestination = class(TCustomMailSlotDestination)
  published
    { Published declarations }
    Property Enabled;
    Property SlotName;
    Property OnData;
    Property OnError;
  End;

type
  TMailSlotSource = class(TCustomMailSlotSource)
  published
    { Published declarations }
    Property Data;
    Property Machine;
    Property SlotName;
  end;

implementation

Type
  TCustomMailSlotDestinationThread = class(TThread)
  private
    { Private declarations }
    fData         : String;
    fError        : String;
    fOwner        : TCustomMailSlotDestination; 
    fSlot         : THandle;
  protected
    Procedure DoError;
    Procedure DoData;
    procedure Execute; override;
  Public
    Constructor Create(aOwner : TCustomMailSlotDestination; aSlot : THandle);
  End;


constructor TCustomMailSlotDestinationThread.Create(aOwner: TCustomMailSlotDestination; aSlot : THandle);
begin
  Inherited Create(True);
  fOwner          := aOwner;
  fSlot           := aSlot;
  OnTerminate     := aOwner.DoTerminate;
  FreeOnTerminate := True;

  Self.Resume;
end;

Procedure TCustomMailSlotDestinationThread.DoData;

Begin
  If GetCurrentThreadId<>MainThreadID Then
  Begin
    Synchronize(DoData);
  End
  Else
  Begin
    If Assigned(fOwner) Then
    Begin
      fOwner.DoData(fData);
    End;
  End;
End;

procedure TCustomMailSlotDestinationThread.DoError;
begin
  If GetCurrentThreadId<>MainThreadID Then
  Begin
    Synchronize(DoError);
  End
  Else
  Begin
    If Assigned(fOwner) Then
    Begin
      fOwner.DoError(fError);
    End;
  End;
end;

procedure TCustomMailSlotDestinationThread.Execute;

Var
  Size                   : DWord;
  Read                   : DWord;
  Buffer                 : PByteArray;
  UTF8Buffer             : UTF8String;

begin
  Size := 1024;
  GetMem(Buffer,Size);
  Try
    Repeat
      FillChar(Buffer,Size,0);
      Try
        If ReadFile(fSlot,Buffer^,Size,Read,Nil) Then
        Begin
          If (Buffer[Read-1]=0) Then Dec(Read,1);
          SetLength(UTF8Buffer,Read);
          If Read<>0 Then
          Begin
            Move(Buffer^,UTF8Buffer[1],Read);
          End;
          fData := String(UTF8Buffer);

          DoData;
        End;
      Except
        On E:Exception Do
        Begin
          fError := Format('Exception : [%s]%s',[E.ClassName,E.Message]);
          DoError;
        End;
      End;
    Until Terminated Or (fSlot=INVALID_HANDLE_VALUE);
  Finally
    FreeMem(Buffer,Size);
  End;
End;

Constructor TCustomMailSlotDestination.Create(AOwner : TComponent);

Begin
  Inherited Create(AOwner);
End;

Destructor TCustomMailSlotDestination.Destroy;

Begin
  StopThread;
  Inherited Destroy;
End;

procedure TCustomMailSlotDestination.DoData(aData: String);
begin
  If Assigned(fOnData) Then
  Begin
    fOnData(Self,aData);
  End;  
end;

procedure TCustomMailSlotDestination.DoError(anError: String);
begin
  If Assigned(fOnError) Then
  Begin
    fOnError(Self,anError);
  End;
end;

procedure TCustomMailSlotDestination.DoTerminate(Sender: TObject);
begin
  If (Sender=TheThread) Then
  Begin
    TheThread := Nil;   
    Enabled   := False; 
  End;
end;

Procedure TCustomMailSlotDestination.Loaded;

Begin
  Inherited Loaded;
  Enabled := fLoadedOpen;
End;

Procedure TCustomMailSlotDestination.SetEnabled(Value : Boolean);

Begin
  If (csLoading In ComponentState) Then
  Begin
    fLoadedOpen := Value;
  End
  Else
  Begin
    If (Value<>Enabled) Then
    Begin
      fEnabled := Value;
      Case Enabled Of
        True  : StartThread;
        False : StopThread;
      End;
    End;
  End;
End;

Procedure TCustomMailSlotDestination.SetSlotName(NewName : String);

Begin
  If Enabled Then
  Begin
    Raise Exception.Create('Can''t modify active Mailslot.');
  End;
  fSlotName := Trim(NewName);
End;

procedure TCustomMailSlotDestination.StartThread;
begin
  If Not Assigned(TheThread) Then
  Begin
    If (SlotName='') THen
    Begin
      Raise Exception.Create('Could not create MailSlot without name!');
    End;
    fSlot := CreateMailSlot(PChar('\\.\mailslot\'+fSlotName),0,1000,Nil);
    If (fSlot=INVALID_HANDLE_VALUE) Then
    Begin
      Raise Exception.Create('Could not create MailSlot!'#13#10+SysErrorMessage(GetLastError));
    End;

    TheThread := TCustomMailSlotDestinationThread.Create(Self,fSlot);
  end;
end;

procedure TCustomMailSlotDestination.StopThread;
begin
  If Assigned(TheThread) Then
  Begin
    CloseHandle(fSlot);
    fSlot := INVALID_HANDLE_VALUE;
    Try
      TCustomMailSlotDestinationThread(TheThread).Suspend;
      TCustomMailSlotDestinationThread(TheThread).fSlot       := INVALID_HANDLE_VALUE;
      TCustomMailSlotDestinationThread(TheThread).OnTerminate := Nil;
      TCustomMailSlotDestinationThread(TheThread).fOwner      := Nil;
      TheThread.Terminate;
      TCustomMailSlotDestinationThread(TheThread).Resume;
    Except
    End;
    TheThread := Nil;
  End;
end;

procedure TCustomMailSlotSource.CloseSlot;
begin
  If (fSlot<>INVALID_HANDLE_VALUE) Then
  Begin
    CloseHandle(fSlot);
    fSlot := INVALID_HANDLE_VALUE;
  End;
end;

Constructor TCustomMailSlotSource.Create(AOwner : TComponent);

Begin
  Inherited Create(AOwner);
  fData         := '';
  fMachine      := '.';
  fSlotName     := '';
  fSlot         := INVALID_HANDLE_VALUE;
End;

destructor TCustomMailSlotSource.Destroy;
  Begin
  CloseSlot;
  inherited;
End;

procedure TCustomMailSlotSource.OpenSlot;
begin
  If (fSlot=INVALID_HANDLE_VALUE) Then
  Begin
    If (SlotName='') THen
    Begin
      Raise Exception.Create('Could not create MailSlot without name!');
    End;

    fSlot := CreateFile(PChar('\\'+Machine+'\mailslot\'+SlotName),Generic_Write,
                     File_Share_Read Or File_Share_Write,Nil,Open_Existing,0,0);
    If (fSlot=INVALID_HANDLE_Value) Then
    Begin
      Raise Exception.CreateFmt('Could not open mailslot for sending!'#13#10+
                                '\\'+Machine+'\mailslot\'+SlotName+#13#10+
                                'Error = %d'#13#10'%s',
                                [GetLastError,SysErrorMessage(GetLastError)]);
    End;
  End;
end;

procedure TCustomMailSlotSource.Reset;
begin
  CloseSlot;
end;

Procedure TCustomMailSlotSource.SendData(NewValue : String);

Begin
  if Not (csLoading In ComponentState) Then
  Begin
    Send(NewValue);
  End
  Else
  Begin
    fData := NewValue;
  End;
End;

procedure TCustomMailSlotSource.SetMachine(const Value: String);
begin
  CloseSlot;
  fMachine := Value;
end;

procedure TCustomMailSlotSource.SetSlotName(const Value: String);
begin
  CloseSlot;
  fSlotname := Value;
end;


{$IfDef Unicode}
Function TCustomMailSlotSource.Send(ToSend : String) : {$IfDef Ver100}Integer{$Else}Cardinal{$EndIf};

Var
  At                      : Pointer;
  ToWrite                 : Cardinal;
  UTF8Buffer              : UTF8String;

Begin
  OpenSlot;
  Try
    UTF8Buffer := UTF8String(ToSend);
    At         := Pointer(UTF8Buffer);
    ToWrite    := (Length(UTF8Buffer)+1); // Send the null as well I guess.

    WriteFile(fSlot,At^,ToWrite,Result,Nil);

    fData      := ToSend;
  Except
    CloseSlot;
    Raise;
  End;
End;
{$Else}
Function TCustomMailSlotSource.Send(ToSend : String) : {$IfDef Ver100}Integer{$Else}Cardinal{$EndIf};

Var
  At                      : Pointer;
  ToWrite                 : Cardinal;

Begin
  OpenSlot;
  Try
    At         := Pointer(ToSend);
    ToWrite    := (Length(ToSend)+1); // Send the null as well I guess.

    WriteFile(fSlot,At^,ToWrite,Result,Nil);

    fData      := String(ToSend);
  Except
    CloseSlot;
    Raise;
  End;
End;
{$EndIf}


end.


