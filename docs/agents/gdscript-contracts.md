# GDScript 契約與事件

新寫或正在改的呼叫，把依賴寫成看得到的契約。不要把對方標成 `Node`（或 `Object`）再呼叫它身上沒有宣告的方法。沒碰到的呼叫鏈不要為了這條風格整批重寫。

GDScript 沒有 `interface` 關鍵字。契約用 `@abstract` 類別；單向通知用 `signal`。

## 介面

對方可以繼承這支契約時，用抽象類別把方法簽章寫死。參數型別寫這個類別。子類別漏實作時，引擎會報錯。

```gdscript
@abstract
class_name TitleScreenHost
extends RefCounted

@abstract func install_title_screen() -> void

@abstract func uninstall_title_screen() -> void
```

## 事件

通知「發生了什麼」、或請已經 `extends` 別的類別的物件做事時，用 `signal`，由接收端 `connect`。遊戲主腳本是 `extends Node3D`，不能再繼承第二個基底；這種回呼走信號，不要握著主機再點一個未宣告的方法。

```gdscript
signal title_install_requested
signal title_uninstall_requested

func enter() -> void:
	title_install_requested.emit()
```

## 既有縫保持原樣

- Host 對 Reality scene adapter 仍走 interaction outcome 與 look pose，不用節點 signal 當這條 API。
- Framework 的 `FlowState` 仍是 `enter` / `exit` / `handle_input`。Framework 不 preload、不點名遊戲畫面。
- 遊戲態可以對自己的信號或抽象契約說話；不要把標題、樓層、手機塞進 Framework。

## Agents

Cursor rule: `.cursor/rules/gdscript-contracts.mdc` (always applied). `.cursor/` 在 `.gitignore`，本檔是進版本庫的那份。
