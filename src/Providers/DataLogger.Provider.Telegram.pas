{
  *************************************
  Created by Danilo Lucas
  Github - https://github.com/dliocode
  *************************************
}

unit DataLogger.Provider.Telegram;

interface

uses
{$IF DEFINED(DATALOGGER_TELEGRAM_USE_INDY)}
  DataLogger.Provider.REST.Indy,
{$ELSEIF DEFINED(DATALOGGER_TELEGRAM_USE_NETHTTPCLIENT)}
  DataLogger.Provider.REST.NetHTTPClient,
{$ELSE}
  DataLogger.Provider.REST.HTTPClient,
{$ENDIF}
  DataLogger.Types,
  System.SysUtils, System.NetEncoding;

type
  TTelegramParseMode = (tpNone, tpHTML, tpMarkdown);

{$IF DEFINED(DATALOGGER_TELEGRAM_USE_INDY)}

  TProviderTelegram = class(TProviderRESTIndy)
{$ELSEIF DEFINED(DATALOGGER_TELEGRAM_USE_NETHTTPCLIENT)}
  TProviderTelegram = class(TProviderRESTNetHTTPClient)
{$ELSE}
  TProviderTelegram = class(TProviderRESTHTTPClient)
{$ENDIF}
  private
    FBotToken: string;
    FChatId: string;
    FParseMode: TTelegramParseMode;
  protected
    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    property BotToken: string read FBotToken write FBotToken;
    property ChatId: string read FChatId write FChatId;
    property ParseMode: TTelegramParseMode read FParseMode write FParseMode;

    constructor Create(const ABotToken: string; const AChatId: string; const AParseMode: TTelegramParseMode = tpMarkdown); reintroduce;
  end;

implementation

{ TProviderTelegram }

const
  TELEGRAM_API_SENDMSG = 'https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s';
  TELEGRAM_API_UPDATE = 'https://api.telegram.org/bot%s/getUpdates'; // https://api.telegram.org/bot<TOKEN>/getUpdates
  TELGRAM_API_MARKDOWN = '&parse_mode=MarkdownV2';
  TELGRAM_API_HTML = '&parse_mode=HTML';

constructor TProviderTelegram.Create(const ABotToken: string; const AChatId: string; const AParseMode: TTelegramParseMode = tpMarkdown);
begin
  FBotToken := ABotToken;
  FChatId := AChatId;
  FParseMode := AParseMode;

  inherited Create('', 'application/json');
end;

procedure TProviderTelegram.Save(const ACache: TArray<TLoggerItem>);
var
  LItemREST: TArray<TLogItemREST>;
  LItem: TLoggerItem;
  LLogItemREST: TLogItemREST;
  LMessage: string;
  LParseMode: string;

  procedure SerializeMessageParseMode;
  const
    FormattingMarkdown: array [0 .. 17] of string = ('_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!');
  var
    I: Integer;
  begin
    case FParseMode of
      tpHTML:
        begin
          LParseMode := TELGRAM_API_HTML;

          case LItem.&Type of
            All:
              ;
            Trace:
              ;
            Debug:
              ;
            Info:
              ;
            Success:
              ;
            Warn:
              LMessage := '<u>' + LMessage + '</u>';

            Error:
              LMessage := '<b>' + LMessage + '</b>';

            Fatal:
              LMessage := '' + LMessage + '';
          end;
        end;

      tpMarkdown:
        begin
          LParseMode := TELGRAM_API_MARKDOWN;

          // https://core.telegram.org/bots/api#formatting-options
          for I := Low(FormattingMarkdown) to High(FormattingMarkdown) do
            LMessage := LMessage.Replace(FormattingMarkdown[I], '\' + FormattingMarkdown[I]);

          case LItem.&Type of
            All:
              ;
            Trace:
              ;
            Debug:
              ;
            Info:
              ;
            Success:
              ;
            Warn:
              LMessage := '__' + LMessage + '__';

            Error, Fatal:
              LMessage := '*' + LMessage + '*';
          end;
        end;
    end;
  end;

begin
  LItemREST := [];

  if Length(ACache) = 0 then
    Exit;

  for LItem in ACache do
  begin
    if LItem.&Type = TLoggerType.All then
      Continue;

    LParseMode := '';
    LMessage := TLoggerLogFormat.AsString(FLogFormat, LItem, FFormatTimestamp).Trim;

    if FParseMode <> tpNone then
      SerializeMessageParseMode;

    LLogItemREST.Stream := nil;
    LLogItemREST.LogItem := LItem;

    LMessage := TNetEncoding.URL.Encode(LMessage);
    LLogItemREST.URL := Format(TELEGRAM_API_SENDMSG + LParseMode, [FBotToken, FChatId, LMessage]);

    LItemREST := Concat(LItemREST, [LLogItemREST]);
  end;

  InternalSave(TLoggerMethod.tlmGet, LItemREST);
end;

end.
