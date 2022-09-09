{
  ********************************************************************************

  Github - https://github.com/dliocode/datalogger

  ********************************************************************************

  MIT License

  Copyright (c) 2022 Danilo Lucas

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  ********************************************************************************
}

unit DataLogger.Provider.Events;

interface

uses
  DataLogger.Provider, DataLogger.Types,
  System.SysUtils, System.JSON;

type
  TLoggerItem = DataLogger.Types.TLoggerItem;

  TExecuteEvents = reference to procedure(const ALogFormat: string; const AItem: TLoggerItem; const AFormatTimestamp: string);

  TProviderEvents = class;

  TEventsConfig = class
  private
    FOnAny: TExecuteEvents;
    FOnTrace: TExecuteEvents;
    FOnDebug: TExecuteEvents;
    FOnInfo: TExecuteEvents;
    FOnSuccess: TExecuteEvents;
    FOnWarn: TExecuteEvents;
    FOnError: TExecuteEvents;
    FOnFatal: TExecuteEvents;
    FOnCustom: TExecuteEvents;
    procedure Init;
  public
    function OnAny(const AEvent: TExecuteEvents): TEventsConfig;
    function OnTrace(const AEvent: TExecuteEvents): TEventsConfig;
    function OnDebug(const AEvent: TExecuteEvents): TEventsConfig;
    function OnInfo(const AEvent: TExecuteEvents): TEventsConfig;
    function OnSuccess(const AEvent: TExecuteEvents): TEventsConfig;
    function OnWarn(const AEvent: TExecuteEvents): TEventsConfig;
    function OnError(const AEvent: TExecuteEvents): TEventsConfig;
    function OnFatal(const AEvent: TExecuteEvents): TEventsConfig;
    function OnCustom(const AEvent: TExecuteEvents): TEventsConfig;

    constructor Create;
    destructor Destroy; override;
  end;

  TProviderEvents = class(TDataLoggerProvider<TProviderEvents>)
  private
    FConfig: TEventsConfig;
  protected
    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    function Config(const AValue: TEventsConfig): TProviderEvents;

    procedure LoadFromJSON(const AJSON: string); override;
    function ToJSON(const AFormat: Boolean = False): string; override;

    constructor Create; overload;
    destructor Destroy; override;
  end;

implementation

{ TProviderEvents }

constructor TProviderEvents.Create;
begin
  inherited Create;

  Config(nil);
end;

destructor TProviderEvents.Destroy;
begin
  if Assigned(FConfig) then
    FConfig.Free;

  inherited;
end;

function TProviderEvents.Config(const AValue: TEventsConfig): TProviderEvents;
begin
  Result := Self;
  FConfig := AValue;
end;

procedure TProviderEvents.LoadFromJSON(const AJSON: string);
var
  LJO: TJSONObject;
begin
  if AJSON.Trim.IsEmpty then
    Exit;

  try
    LJO := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  except
    on E: Exception do
      Exit;
  end;

  if not Assigned(LJO) then
    Exit;

  try
    SetJSONInternal(LJO);
  finally
    LJO.Free;
  end;
end;

function TProviderEvents.ToJSON(const AFormat: Boolean): string;
var
  LJO: TJSONObject;
begin
  LJO := TJSONObject.Create;
  try
    ToJSONInternal(LJO);

    Result := TLoggerJSON.Format(LJO, AFormat);
  finally
    LJO.Free;
  end;
end;

procedure TProviderEvents.Save(const ACache: TArray<TLoggerItem>);
  procedure _Execute(const AEvent: TExecuteEvents; const AItem: TLoggerItem);
  begin
    if Assigned(AEvent) then
      AEvent(FLogFormat, AItem, FFormatTimestamp);
  end;

var
  LRetriesCount: Integer;
  LItem: TLoggerItem;
begin
  if not Assigned(FConfig) then
    raise EDataLoggerException.Create('Config not defined!');

  if Length(ACache) = 0 then
    Exit;

  for LItem in ACache do
  begin
    if LItem.InternalItem.LevelSlineBreak then
      Continue;

    LRetriesCount := 0;

    while True do
      try
        case LItem.Level of
          TLoggerLevel.Trace:
            _Execute(FConfig.FOnTrace, LItem);
          TLoggerLevel.Debug:
            _Execute(FConfig.FOnDebug, LItem);
          TLoggerLevel.Info:
            _Execute(FConfig.FOnInfo, LItem);
          TLoggerLevel.Warn:
            _Execute(FConfig.FOnWarn, LItem);
          TLoggerLevel.Error:
            _Execute(FConfig.FOnError, LItem);
          TLoggerLevel.Success:
            _Execute(FConfig.FOnSuccess, LItem);
          TLoggerLevel.Fatal:
            _Execute(FConfig.FOnFatal, LItem);
          TLoggerLevel.Custom:
            _Execute(FConfig.FOnCustom, LItem);
        end;

        _Execute(FConfig.FOnAny, LItem);

        Break;
      except
        on E: Exception do
        begin
          Inc(LRetriesCount);

          Sleep(50);

          if Assigned(FLogException) then
            FLogException(Self, LItem, E, LRetriesCount);

          if Self.Terminated then
            Exit;

          if LRetriesCount <= 0 then
            Break;

          if LRetriesCount >= FMaxRetries then
            Break;
        end;
      end
  end;
end;

{ TEventsConfig }

constructor TEventsConfig.Create;
begin
  Init;
end;

destructor TEventsConfig.Destroy;
begin
  Init;
  inherited;
end;

procedure TEventsConfig.Init;
begin
  FOnAny := nil;
  FOnTrace := nil;
  FOnDebug := nil;
  FOnInfo := nil;
  FOnWarn := nil;
  FOnError := nil;
  FOnSuccess := nil;
  FOnFatal := nil;
end;

function TEventsConfig.OnAny(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnAny := AEvent;
end;

function TEventsConfig.OnTrace(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnTrace := AEvent;
end;

function TEventsConfig.OnDebug(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnDebug := AEvent;
end;

function TEventsConfig.OnInfo(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnInfo := AEvent;
end;

function TEventsConfig.OnWarn(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnWarn := AEvent;
end;

function TEventsConfig.OnError(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnError := AEvent;
end;

function TEventsConfig.OnSuccess(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnSuccess := AEvent;
end;

function TEventsConfig.OnFatal(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnFatal := AEvent;
end;

function TEventsConfig.OnCustom(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnFatal := AEvent;
end;

procedure ForceReferenceToClass(C: TClass);
begin
end;

initialization

ForceReferenceToClass(TProviderEvents);

end.
