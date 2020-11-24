unit DDU.OTA.MailSlotsUI;

//*****************************************************************************
//
// DDUControls (DDUMailSlotsEditor)
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
// Purpose : IDE OTA extension for DDU.WinAPI.MailSlots.pas 
//
// History : <none>
//
//*****************************************************************************

interface

{$I DVer.inc}

uses
  System.SysUtils,
  System.Classes,
  System.RTLConsts,
  WinAPI.Windows,
  WinAPI.Messages,

  DesignIntf,
  DesignEditors,
  VCLEditors,

  VCL.Graphics, 
  VCL.Controls, 
  VCL.Forms, 
  VCL.Dialogs,

  DDU.WinAPI.MailSlots;
  
{$I DTypes.inc}

Procedure Register;

implementation

Type
  TMailSlotMachineEditor = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; Override;
    procedure GetValues(Proc: TGetStrProc); Override;
  End;

Function TMailSlotMachineEditor.GetAttributes: TPropertyAttributes;

Begin
  Result := [paValueList, paSortList, paMultiSelect, paAutoUpdate];
End;

procedure Register;

Begin
  RegisterPropertyEditor(TypeInfo(String), TMailSlotSource,'Machine',TMailSlotMachineEditor);
End;

procedure TMailSlotMachineEditor.GetValues(Proc: TGetStrProc);

begin
  Proc('.');
  Proc('*');
end;

end.

