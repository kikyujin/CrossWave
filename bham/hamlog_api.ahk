; HAMLOG API Handler (for HTTP Server)
; Copyright Kikyujin / MULTiTApps Inc.
; Released under the MIT license
; Usage: AutoHotkey.exe hamlog_api.ahk <function> [args...]

#NoEnv
SetBatchLines, -1

; コマンドライン引数取得
if (A_Args.Length() < 1) {
    OutputJSON({"error": "No function specified"})
    ExitApp, 1
}

functionName := A_Args[1]

; 関数ルーティング
if (functionName = "CheckStatus") {
    CheckStatus()
} else if (functionName = "GetCallsignData") {
    if (A_Args.Length() < 2) {
        OutputJSON({"error": "Callsign parameter required"})
        ExitApp, 1
    }
    GetCallsignData(A_Args[2])
} else if (functionName = "CreateLog") {
    if (A_Args.Length() < 2) {
        OutputJSON({"error": "Log data required"})
        ExitApp, 1
    }
    CreateLog(A_Args[2])
} else if (functionName = "UpdateLog") {
    if (A_Args.Length() < 2) {
        OutputJSON({"error": "Log data required"})
        ExitApp, 1
    }
    UpdateLog(A_Args[2])
} else if (functionName = "ClearLog") {
    ClearLog()
} else {
    OutputJSON({"error": "Unknown function: " . functionName})
    ExitApp, 1
}

ExitApp, 0

; ========================================
; 関数定義
; ========================================

CheckStatus() {
    hwnd := GetHamlogWindow()
    if (hwnd) {
        OutputJSON({"status": "running", "hwnd": hwnd})
    } else {
        OutputJSON({"status": "not_running"})
    }
}

GetCallsignData(callsign) {
    hwnd := GetHamlogWindow()
    if (!hwnd) {
        OutputJSON({"error": "HAMLOG window not found"})
        return
    }

    ; ポップアップダイアログがあれば閉じる
    ClosePopupDialogs()

    ; 前回のデータが残らないようクリア
    WinActivate, ahk_id %hwnd%
    WinWaitActive, ahk_id %hwnd%,, 1
    Send, !a
    Sleep, 200

    ; コールサインをセットして検索
    ControlSetText, TEdit14, %callsign%, ahk_id %hwnd%
    Sleep, 100
    ControlSend, TEdit14, {Enter}, ahk_id %hwnd%
    Sleep, 300

    ; ポップアップが出ていたら閉じる
    ClosePopupDialogs()

    ; データ取得して返す(ダイアログには検索結果が残る)
    data := GetAllFields(hwnd)
    OutputJSON(data)
}

CreateLog(jsonData) {
    ; JSON文字列をパース(簡易版)
    data := ParseJSON(jsonData)
    
    hwnd := GetHamlogWindow()
    if (!hwnd) {
        OutputJSON({"error": "HAMLOG window not found"})
        return
    }
    
    WinActivate, ahk_id %hwnd%
    WinWaitActive, ahk_id %hwnd%,, 1
    
    ; まずクリア
    Send, !a
    Sleep, 200
    
    ; データセット
    SetAllFields(hwnd, data)
    Sleep, 300
    
    OutputJSON({"status": "success", "message": "Log data set to HAMLOG"})
}

UpdateLog(jsonData) {
    data := ParseJSON(jsonData)
    
    hwnd := GetHamlogWindow()
    if (!hwnd) {
        OutputJSON({"error": "HAMLOG window not found"})
        return
    }
    
    SetAllFields(hwnd, data)
    
    OutputJSON({"status": "success", "message": "Log data updated"})
}

ClearLog() {
    hwnd := GetHamlogWindow()
    if (!hwnd) {
        OutputJSON({"error": "HAMLOG window not found"})
        return
    }
    
    WinActivate, ahk_id %hwnd%
    WinWaitActive, ahk_id %hwnd%,, 1
    Send, !a
    Sleep, 300
    
    OutputJSON({"status": "success", "message": "Log cleared"})
}

; ========================================
; ユーティリティ関数
; ========================================

GetHamlogWindow() {
    ; boneless.ahkと同じロジック
    WinGet, idList, List, ahk_class TForm_A
    Loop, %idList%
    {
        this_id := idList%A_Index%
        WinGetTitle, title, ahk_id %this_id%
        if InStr(title, "ＬＯＧ")
            return this_id
    }
    
    ; 見つからなかったら起動試行
    WinActivate, ahk_class TThwin
    if WinExist("ahk_class TThwin") {
        ControlSend,, {Enter}, ahk_class TThwin
        Sleep, 500
        WinGet, this_id, ID, ahk_class TForm_A ahk_exe hamlogw.exe
        return this_id
    }
    
    return 0
}

GetAllFields(hwnd) {
    ; HAMLOGから全フィールド取得
    data := {}
    
    ControlGetText, callsign, TEdit14, ahk_id %hwnd%
    ControlGetText, date, TEdit13, ahk_id %hwnd%
    ControlGetText, time, TEdit12, ahk_id %hwnd%
    ControlGetText, his, TEdit11, ahk_id %hwnd%
    ControlGetText, my, TEdit10, ahk_id %hwnd%
    ControlGetText, freq, TEdit9, ahk_id %hwnd%
    ControlGetText, mode, TEdit8, ahk_id %hwnd%
    ControlGetText, code, TEdit7, ahk_id %hwnd%
    ControlGetText, gl, TEdit6, ahk_id %hwnd%
    ControlGetText, qsl, TEdit5, ahk_id %hwnd%
    ControlGetText, name, TEdit4, ahk_id %hwnd%
    ControlGetText, qth, TEdit3, ahk_id %hwnd%
    ControlGetText, rem1, TEdit2, ahk_id %hwnd%
    ControlGetText, rem2, TEdit1, ahk_id %hwnd%
    
    data.callsign := Trim(callsign)
    data.date := Trim(date)
    data.time := Trim(time)
    data.his := Trim(his)
    data.my := Trim(my)
    data.freq := Trim(freq)
    data.mode := Trim(mode)
    data.code := Trim(code)
    data.gl := Trim(gl)
    data.qsl := Trim(qsl)
    data.name := Trim(name)
    data.qth := Trim(qth)
    data.rem1 := Trim(rem1)
    data.rem2 := Trim(rem2)
    
    return data
}

SetAllFields(hwnd, data) {
    ; データをHAMLOGにセット
    if (data.callsign != "")
        ControlSetText, TEdit14, % data.callsign, ahk_id %hwnd%
    
    Sleep, 100
    
    ; コールサインセット後にEnter(HAMLOG仕様)
    if (data.callsign != "") {
        ControlSend, TEdit14, {Enter}, ahk_id %hwnd%
        Sleep, 300
    }
    
    if (data.date != "")
        ControlSetText, TEdit13, % data.date, ahk_id %hwnd%
    if (data.time != "")
        ControlSetText, TEdit12, % data.time, ahk_id %hwnd%
    if (data.his != "")
        ControlSetText, TEdit11, % data.his, ahk_id %hwnd%
    if (data.my != "")
        ControlSetText, TEdit10, % data.my, ahk_id %hwnd%
    if (data.freq != "")
        ControlSetText, TEdit9, % data.freq, ahk_id %hwnd%
    if (data.mode != "")
        ControlSetText, TEdit8, % data.mode, ahk_id %hwnd%
    if (data.code != "")
        ControlSetText, TEdit7, % data.code, ahk_id %hwnd%
    if (data.gl != "")
        ControlSetText, TEdit6, % data.gl, ahk_id %hwnd%
    if (data.qsl != "")
        ControlSetText, TEdit5, % data.qsl, ahk_id %hwnd%
    if (data.name != "")
        ControlSetText, TEdit4, % data.name, ahk_id %hwnd%
    if (data.qth != "")
        ControlSetText, TEdit3, % data.qth, ahk_id %hwnd%
    if (data.rem1 != "")
        ControlSetText, TEdit2, % data.rem1, ahk_id %hwnd%
    if (data.rem2 != "")
        ControlSetText, TEdit1, % data.rem2, ahk_id %hwnd%
}

RestoreAllFields(hwnd, data) {
    ; [未使用] 退避した状態をダイアログに書き戻す
    ; 全フィールドを無条件で上書き(空文字含む)
    ; 将来、状態復元が必要になった場合に使う
    ControlSetText, TEdit14, % data.callsign, ahk_id %hwnd%
    ControlSetText, TEdit13, % data.date, ahk_id %hwnd%
    ControlSetText, TEdit12, % data.time, ahk_id %hwnd%
    ControlSetText, TEdit11, % data.his, ahk_id %hwnd%
    ControlSetText, TEdit10, % data.my, ahk_id %hwnd%
    ControlSetText, TEdit9, % data.freq, ahk_id %hwnd%
    ControlSetText, TEdit8, % data.mode, ahk_id %hwnd%
    ControlSetText, TEdit7, % data.code, ahk_id %hwnd%
    ControlSetText, TEdit6, % data.gl, ahk_id %hwnd%
    ControlSetText, TEdit5, % data.qsl, ahk_id %hwnd%
    ControlSetText, TEdit4, % data.name, ahk_id %hwnd%
    ControlSetText, TEdit3, % data.qth, ahk_id %hwnd%
    ControlSetText, TEdit2, % data.rem1, ahk_id %hwnd%
    ControlSetText, TEdit1, % data.rem2, ahk_id %hwnd%
}

ClosePopupDialogs() {
    ; HAMLOG由来のポップアップダイアログを検出して閉じる
    ; 注意: TForm_A(LOGダイアログ)はWinCloseで閉じられないので触らない
    ; Delphi系のメッセージダイアログ等のみ対象
    popupClasses := ["TMessageForm", "#32770"]
    for i, cls in popupClasses
    {
        Loop {
            if !WinExist("ahk_class " . cls . " ahk_exe hamlogw.exe")
                break
            WinGet, popupId, ID, ahk_class %cls% ahk_exe hamlogw.exe
            ; WinCloseを試し、ダメならWM_CLOSE直送
            WinClose, ahk_id %popupId%
            Sleep, 100
            IfWinExist, ahk_id %popupId%
                PostMessage, 0x10, 0, 0,, ahk_id %popupId%  ; WM_CLOSE
            Sleep, 100
        }
    }
}

ParseJSON(jsonStr) {
    ; 簡易JSONパーサー(実用にはJxon.ahkなど推奨)
    data := {}
    
    ; クォート除去して基本的なパース
    jsonStr := RegExReplace(jsonStr, "^\s*\{\s*|\s*\}\s*$")
    
    Loop, Parse, jsonStr, `,
    {
        pair := A_LoopField
        if RegExMatch(pair, """(\w+)""\s*:\s*""([^""]*?)""", match) {
            key := match1
            value := match2
            data[key] := value
        }
    }
    
    return data
}

OutputJSON(obj) {
    ; オブジェクトをJSON文字列として標準出力
    ; 実用にはJxon.ahkなど推奨
    json := "{"
    first := true
    
    for key, value in obj {
        if (!first)
            json .= ","
        
        json .= """" . key . """:"
        
        if value is integer
            json .= value
        else
            json .= """" . StrReplace(value, """", "\""") . """"
        
        first := false
    }
    
    json .= "}"
    
    FileAppend, %json%, *
}
