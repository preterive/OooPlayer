{ *
  * Copyright (C) 2014 ozok <ozok26@gmail.com>
  *
  * This file is part of OooPlayer.
  *
  * OooPlayer is free software: you can redistribute it and/or modify
  * it under the terms of the GNU General Public License as published by
  * the Free Software Foundation, either version 2 of the License, or
  * (at your option) any later version.
  *
  * OooPlayer is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  * GNU General Public License for more details.
  *
  * You should have received a copy of the GNU General Public License
  * along with OooPlayer.  If not, see <http://www.gnu.org/licenses/>.
  *
  * }

unit UnitMusicPlayer;

interface

uses System.Classes, BASS, BASS_AAC, BASSFLAC, BassWMA, BASSWV, BASS_AC3,
  BASS_ALAC, BASS_APE, BASS_MPC, BASS_OFR, BASS_SPX, BASS_TTA, BassOPUS,
  Windows, SysUtils, StrUtils, Generics.Collections, MediaInfoDll;

type
  TPlayerStatus = (psPlaying = 0, psPaused = 1, psStopped = 2, psStalled = 3, psUnkown = 4);

type
  TMusicPlayer = class
  private
    FBassHandle: HSTREAM;
    FPlayerStatus: TPlayerStatus;
    FErrorMsg: integer;
    FFileName: string;
    FVolumeLevel: integer;
    FPositionAsSec: integer;
    FTAKPluginHandle: Cardinal;

    function GetBassStreamStatus: TPlayerStatus;
    function GetTotalLength(): int64;
    function GetPosition(): int64;
    function GetLevels: Cardinal;
    function GetPositionStr: string;
    function GetSecondDuration: Integer;

    function IsM4AALAC: Boolean;
    function GetLeftLevel: Integer;
    function GetRightLevel: Integer;
    function GetBassErrorCode: Integer;
  public
    property PlayerStatus: TPlayerStatus read FPlayerStatus;
    property PlayerStatus2: TPlayerStatus read GetBassStreamStatus;
    property ErrorMsg: Integer read FErrorMsg;
    property FileName: string read FFileName write FFileName;
    property TotalLength: int64 read GetTotalLength;
    property Position: int64 read GetPosition;
    property Levels: Cardinal read GetLevels;
    property PositionStr: string read GetPositionStr;
    property DurationAsSec: integer read GetSecondDuration;
    property PositionAsSec: integer read FPositionAsSec;
    property Channel: Cardinal read FBassHandle;
    property LeftLevel: Integer read GetLeftLevel;
    property RightLevel: Integer read GetRightLevel;
    property BassErrorCode: Integer read GetBassErrorCode;
    property BassHandleValue: Cardinal read FBassHandle;

    constructor Create(const WinHandle: Cardinal);
    destructor Destroy; override;

    procedure Play;
    procedure Stop;
    procedure Pause;
    procedure Resume;
    procedure SetVolume(const Volume: integer);
    function SetPosition(const Position: int64): Boolean;
    function IntToTime(IntTime: Integer): string;
  end;

const
  MY_ERROR_OK = 0;
  MY_ERROR_BASS_NOT_LOADED = 1;
  MY_ERROR_COULDNT_STOP_STREAM = 2;
  MY_ERROR_STREAM_ZERO = 3;
  MY_ERROR_COULDNT_FREE_STREAM = 4;

implementation

{ TMusicPlayer }

constructor TMusicPlayer.Create(const WinHandle: Cardinal);
begin
  FPlayerStatus := psStopped;
  FErrorMsg := MY_ERROR_OK;
  BASS_SetConfig(BASS_CONFIG_FLOATDSP, 1);

  if not BASS_Init(-1, 44100, 0, WinHandle, nil) then
  begin
    FErrorMsg := MY_ERROR_BASS_NOT_LOADED;
  end;
  FTAKPluginHandle := BASS_PluginLoad('bass_tak2.4.dll', BASS_UNICODE);
  if FTAKPluginHandle < 1 then
  begin
    FErrorMsg := MY_ERROR_BASS_NOT_LOADED;
  end;
end;

destructor TMusicPlayer.Destroy;
begin
  if FTAKPluginHandle > 0 then
  begin
    BASS_PluginFree(FTAKPluginHandle)
  end;
  BASS_StreamFree(FBassHandle);
  BASS_Free();
  inherited;
end;

function TMusicPlayer.GetBassErrorCode: Integer;
begin
  Result := BASS_ErrorGetCode;
end;

function TMusicPlayer.GetBassStreamStatus: TPlayerStatus;
begin
  case BASS_ChannelIsActive(FBassHandle) of
    BASS_ACTIVE_STOPPED:
      Result := psStopped;
    BASS_ACTIVE_PLAYING:
      Result := psPlaying;
    BASS_ACTIVE_STALLED:
      Result := psStalled;
    BASS_ACTIVE_PAUSED:
      Result := psPaused;
  else
    Result := psUnkown;
  end;
end;

function TMusicPlayer.GetLeftLevel: Integer;
begin
  Result := Loword(BASS_ChannelGetLevel(FBassHandle))
end;

function TMusicPlayer.GetLevels: Cardinal;
begin
  Result := BASS_ChannelGetLevel(FBassHandle);
end;

function TMusicPlayer.GetPosition: int64;
begin
  Result := 0;
  if FBassHandle > 0 then
  begin
    Result := BASS_ChannelGetPosition(FBassHandle, BASS_POS_BYTE);
  end;
end;

function TMusicPlayer.GetPositionStr: string;
begin
  if FBassHandle > 0 then
  begin
    FPositionAsSec := Round(BASS_ChannelBytes2Seconds(FBassHandle, BASS_ChannelGetPosition(FBassHandle, BASS_POS_BYTE)));
    Result := IntToTime(FPositionAsSec);
  end;
end;

function TMusicPlayer.GetRightLevel: Integer;
begin
  Result := HiWord(BASS_ChannelGetLevel(FBassHandle));
end;

function TMusicPlayer.GetSecondDuration: Integer;
begin
  Result := 0;
  if FBassHandle > 0 then
  begin
    Result := Round(BASS_ChannelBytes2Seconds(FBassHandle, BASS_ChannelGetLength(FBassHandle, BASS_POS_BYTE)));
  end;
end;

function TMusicPlayer.GetTotalLength: int64;
begin
  Result := 0;
  if FBassHandle > 0 then
  begin
    Result := BASS_ChannelGetLength(FBassHandle, BASS_POS_BYTE);
  end;
end;

function TMusicPlayer.IntToTime(IntTime: Integer): string;
var
  hour: Integer;
  second: Integer;
  minute: Integer;
  strhour: string;
  strminute: string;
  strsecond: String;
begin

  if (Time > 0) then
  begin

    hour := IntTime div 3600;
    minute := (IntTime div 60) - (hour * 60);
    second := (IntTime mod 60);

    if (second < 10) then
    begin
      strsecond := '0' + FloatToStr(second);
    end
    else
    begin
      strsecond := FloatToStr(second);
    end;

    if (minute < 10) then
    begin
      strminute := '0' + FloatToStr(minute);
    end
    else
    begin
      strminute := FloatToStr(minute);
    end;

    if (hour < 10) then
    begin
      strhour := '0' + FloatToStr(hour);
    end
    else
    begin
      strhour := FloatToStr(hour);
    end;

    Result := strhour + ':' + strminute + ':' + strsecond;
  end
  else
  begin
    Result := '00:00:00';
  end;
end;

function TMusicPlayer.IsM4AALAC: Boolean;
var
  MediaInfoHandle: Cardinal;
  LCodec: string;
begin
  Result := False;
  if (FileExists(FFileName)) then
  begin
    // New handle for mediainfo
    MediaInfoHandle := MediaInfo_New();
    if MediaInfoHandle <> 0 then
    begin
      try
        // Open a file in complete mode
        MediaInfo_Open(MediaInfoHandle, PwideChar(FFileName));
        MediaInfo_Option(0, 'Complete', '1');
        LCodec := Trim(MediaInfo_Get(MediaInfoHandle, Stream_Audio, 0, 'Codec', Info_Text, Info_Name));
        Result := 'alac' = LCodec;
      finally
        MediaInfo_Close(MediaInfoHandle);
      end;
    end;
  end;
end;

procedure TMusicPlayer.Pause;
begin
  if GetBassStreamStatus = psPlaying then
  begin
    if BASS_ChannelPause(FBassHandle) then
      FPlayerStatus := psPaused;
  end;
end;

procedure TMusicPlayer.Play;
var
  LExt: string;
begin
  // free the stream first
  if FBassHandle <> 0 then
  begin
    if not BASS_StreamFree(FBassHandle) then
    begin
      FErrorMsg := MY_ERROR_COULDNT_FREE_STREAM;
      exit;
    end;
  end;
  // create stream according to file extension
  LExt := LowerCase(ExtractFileExt(FFileName));
  if (LExt = '.aac') or (LExt = '.m4b') then
  begin
    FBassHandle := BASS_MP4_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.m4a') then
  begin
    if IsM4AALAC then
    begin
      FBassHandle := BASS_ALAC_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT)
    end
    else
    begin
      FBassHandle := BASS_MP4_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
    end;
  end
  else if (LExt = '.flac') then
  begin
    FBassHandle := BASS_FLAC_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.ape') then
  begin
    FBassHandle := BASS_APE_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.ac3') then
  begin
    FBassHandle := BASS_AC3_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.wv') then
  begin
    FBassHandle := BASS_WV_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.ofr') then
  begin
    FBassHandle := BASS_OFR_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.spx') then
  begin
    FBassHandle := BASS_SPX_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.tta') then
  begin
    FBassHandle := BASS_TTA_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else if (LExt = '.opus') then
  begin
    FBassHandle := BASS_OPUS_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end
  else
  begin
    FBassHandle := Bass_StreamCreateFile(False, PwideChar(FFileName), 0, 0, BASS_UNICODE or BASS_SAMPLE_FLOAT);
  end;

  if FBassHandle > 0 then
  begin
    if BASS_ChannelPlay(FBassHandle, False) then
    begin
      FErrorMsg := MY_ERROR_OK;
      FPlayerStatus := psPlaying;
    end
    else
    begin
      FErrorMsg := MY_ERROR_STREAM_ZERO;
      FPlayerStatus := psStopped;
    end;
  end
  else
  begin
    FErrorMsg := MY_ERROR_STREAM_ZERO;
  end;
end;

procedure TMusicPlayer.Resume;
begin
  if GetBassStreamStatus = psPaused then
  begin
    if BASS_ChannelPlay(FBassHandle, False) then
      FPlayerStatus := psPlaying;
  end;
end;

function TMusicPlayer.SetPosition(const Position: int64): Boolean;
begin
  Result := BASS_ChannelSetPosition(FBassHandle, Position, BASS_POS_BYTE);
end;

procedure TMusicPlayer.SetVolume(const Volume: integer);
begin
  if BASS_ChannelSetAttribute(FBassHandle, BASS_ATTRIB_VOL, Volume / 100.0) then
  begin
    FVolumeLevel := Volume;
  end;
end;

procedure TMusicPlayer.Stop;
begin
  if GetBassStreamStatus <> psStopped then
  begin
    if BASS_ChannelStop(FBassHandle) then
      FPlayerStatus := psStopped;
  end;
end;

end.

