# CROSSWAVE — Architecture

## 1. Design Principles

### 1.1 Database Access

- Each window / panel independently calls the open-logbook API
- No shared data objects between windows
- open-logbook (SQLite) is the single source of truth

### 1.2 Inter-window Communication

- No direct references between windows / panels (loose coupling)
- Notifications via `NotificationCenter`
- Notification names are defined in this document and shared across all panels

### 1.3 Multiple Board Instances

- Boards can be opened simultaneously (e.g., multiple QSO Boards during a pileup)
- Each board instance operates independently

---

## 2. Board Inventory

| ID | Name | Implementation | Status |
|----|------|---------------|--------|
| `control` | Control Board | WindowGroup (root) | ✅ Implemented |
| `list` | Log Board | NSPanel (FloatingPanel) | ✅ Implemented |
| `qso` | QSO Board | NSPanel (FloatingPanel) | ✅ Implemented |
| `voice` | Voice Input Board | NSPanel | Not implemented |
| `cw` | CW Board | NSPanel | Not implemented |
| `blacklist` | Blacklist Board | NSPanel | Not implemented |

---

## 3. Log Board

### 3.1 Database Interaction

- Fetches and displays DB contents with optional filters
- Default: no filter
- API: `GET /api/qso`

**Filter options**:
- Callsign (via LogBoardContext, implemented)
- Date range (from / to) — not yet implemented
- QSL status — not yet implemented

### 3.2 Refresh Triggers

- On app launch
- On receiving `qso.updated` notification → re-fetch via `GET /api/qso`
- Filtered Log Boards also refresh on `qso.updated`

### 3.3 Board Actions

| Action | Behavior |
|--------|----------|
| Toolbar "NEW QSO" / ⌘N | Open QSO Board in **new** mode |
| Toolbar "EXPORT" | Open ID range dialog (with last export preset) |
| Enter key | Open QSO Board in **new** mode (same as ⌘N) |
| Double-click row | `context.onSelect?(record.id)` — parent decides the action |
| ⌘\` | Board rotation |
| Right-click → Delete QSO | Confirmation dialog → `DELETE /api/qso/{id}` → fire `qso.updated` |
| Right-click → Edit QSO | Open QSO Board in **edit** mode |

### 3.4 Launch Context (LogBoardContext)

The Log Board receives a `LogBoardContext` at launch:

```swift
struct LogBoardContext {
    let callsignFilter: String?
    let onSelect: ((Int) -> Void)?

    static let `default` = LogBoardContext(callsignFilter: nil, onSelect: nil)
}
```

**Design principle**: The Log Board doesn't decide what happens. On double-click, it passes the DB `id` to the parent. Data fetching and decision-making is entirely the parent's responsibility.

| Launched from | callsignFilter | onSelect | Context menu |
|---------------|---------------|----------|-------------|
| Control Board | nil | Edit callback | Yes (Edit + Delete) |
| QSO Board | Callsign string | Inject callback | None (read-only) |

---

## 4. QSO Board

### 4.1 Modes

| Mode | How to open | Save API |
|------|------------|---------|
| New | NEW QSO button / ⌘N / Enter in Log Board | `POST /api/qso` |
| Edit | Double-click in Log Board / right-click → Edit QSO | `PUT /api/qso/{id}` |

### 4.2 New Mode Defaults

- DATE: Current date at launch (`YY/MM/DD`)
- TIME: Current time at launch (`HH:MMJ` / `HH:MMU`)
- All other fields: empty

### 4.3 NOW Button

- Located near DATE/TIME fields
- Overwrites DATE/TIME with current time (respects UTC/JST setting)

### 4.4 Input Validation

- SAVE button disabled when CALLSIGN is empty

### 4.5 Callsign Input Behavior

**CALLSIGN + Enter**:
```
Autocomplete candidates exist → confirm first candidate → open filtered Log Board
No candidates → open filtered Log Board
CALLSIGN empty → do nothing
```

**Autocomplete candidate click**: Confirm candidate (auto-fill NAME/QTH/CODE), then open filtered Log Board.

Field navigation uses Tab. Enter does not advance to the next field.

### 4.6 Callsign Autocomplete

```
CALLSIGN input (2+ chars, 200ms debounce)
  → GET /api/callsign_cache?q={prefix} → show candidates

CALLSIGN + Enter (on confirm)
  → GET /api/callsign/lookup?q={callsign} (async, non-blocking)
  → source is "hamlog" or "cache" → auto-fill NAME/QTH/CODE
  → source is "none" → no action
```

- Candidate source: `GET /api/callsign_cache?q={prefix}`
- On candidate selection: auto-fill NAME / QTH / CODE
- lookup is called only on Enter confirm (not during debounced input)
- If HAMLOG is unavailable / timeout: continue without autocomplete (no error shown)

### 4.7 Injection Pattern

When a filtered Log Board (opened from a QSO Board) receives a double-click, it passes the `id` back to the QSO Board for field injection.

**Flow**:
```
Log Board: double-click → context.onSelect?(record.id) ← id only
  → QSO Board: GET /api/qso/{id} → injectFromRecord()
```

**Injected fields**: CODE / NAME / QTH / REM1 / REM2
**Overwrite rule**: Overwrite if source is non-empty. Keep existing value if source is empty.
**Log Board stays open** (user can double-click additional records).

### 4.8 Post-save Behavior

1. `POST` / `PUT` succeeds
2. Fire `NotificationCenter.post("qso.updated")`
3. Close the board

### 4.9 Other UI

- Esc: Close board (confirmation dialog if there are unsaved changes)
- Full-width → half-width auto-conversion on input
- Closing QSO Board auto-closes child boards (filtered Log Board, etc.)

---

## 5. Notifications

### 5.1 Notification List

| Name | Fired by | Received by | Meaning |
|------|----------|-------------|---------|
| `qso.updated` | QSO Board (on save) / Control Board (after import) / Log Board (on delete) | Log Board | QSO data added/updated/deleted |
| `qso.inject` | Log Board (on double-click, via onSelect) | QSO Board | Record id for injection. Filtered by `boardId` |
| `hamlog.status.updated` | LogbookAPI (static timer, 30s interval) | ContentView | HAMLOG status change broadcast |

### 5.2 Design Notes

- Ideally, these events should be pushed from the DB (open-logbook) side
- Currently, app-side notifications are used since the QSO Board knows when it updated data
- When open-logbook gains WebSocket support, notification source can be switched to the DB
- `qso.inject` uses `targetBoardId` to address specific boards (supports multiple simultaneous QSO Boards)

---

## 6. Board Management

### 6.1 Panel Tracking

`FloatingPanelControllerWrapper` manages an array of all open panels.

- Opening a panel → add to array, return panel reference
- Panel closed → remove from array via `willCloseNotification`
- **Always use `close()` to hide panels, never `orderOut`** (`orderOut` does not fire the notification)

### 6.2 Parent-child Relationships

- Parent boards hold references to child board panels
- On parent close → `close()` all child panels
- Safe if child was already closed by the user (`close()` is a no-op)

### 6.3 Typical Parent-child Tree

```
Control Board              ← root
  ├─ Log Board (1)         ← onSelect=edit callback, right-click → Edit/Delete
  └─ QSO Board (A)        ← new or edit mode, holds child panel references
       └─ Log Board (2)   ← callsign-filtered, onSelect=inject, no context menu
```

---

## 7. Guidelines for New Boards

### 7.1 Database Access

- Call open-logbook API directly
- Do not reference other boards' ViewModels or data

### 7.2 Notifications

- If writing QSO data: fire `qso.updated`
- If displaying QSO data: listen for `qso.updated` and re-fetch

### 7.3 UI

- Implement as FloatingPanel (NSPanel)
- Design for multiple simultaneous instances (no singletons)
- Use `close()` to dismiss (never `orderOut`)

### 7.4 Parent-child

Pass `LogBoardContext` when opening a Log Board as a child. The Log Board returns only an `id` — what to do with it is the parent's decision.

Hold panel references for child boards and close them when the parent closes.

---

## 8. Control Board

### 8.1 Overview

- Root board (no parent)
- First board shown on app launch

### 8.2 Features

| Feature | Status |
|---------|--------|
| Open Log Board | ✅ Implemented |
| Open new QSO Board | ✅ Implemented |
| CSV Import (HAMLOG CSV) | ✅ Implemented |
| CSV Export | Implemented in Log Board |

### 8.3 Post-operation

- After DB operations (import, etc.), fire `qso.updated`

---

## 9. HAMLOG Bridge

### 9.1 Overview

Retrieves HAMLOG user database information via bonelessham-api (bham).
bham uses UI automation, so HAMLOG must be running on the host machine.

### 9.2 Status Monitoring

```
GET /api/hamlog/status (open-logbook)
  → health check to bham
  → {"status": "ready"} or {"status": "unavailable"}
```

CrossWave.app polls status every 30 seconds and displays it in the status bar. The polling timer is shared (static) across all board instances — only one request per 30 seconds regardless of how many boards are open.

| State | Display | Color |
|-------|---------|-------|
| Connected | ● HAMLOG | `#39ff8a` (green) |
| Disconnected / timeout | ● HAMLOG | `#ff4444` (red) |
| Unknown (just launched) | ● HAMLOG | Gray |

### 9.3 Callsign Lookup Flow

```
callsign_cache miss
  ↓ only if HAMLOG status is "ready"
bham → HAMLOG search
  ↓ if result is non-empty
upsert to callsign_cache → reflect in QSO Board
```

**Notes**:
- Empty results are not cached
- bham handles mutual exclusion and side effects internally

---

## 10. open-logbook API

| Method | Endpoint | Description | Status |
|--------|----------|-------------|--------|
| GET | `/api/qso` | List QSO logs | ✅ |
| GET | `/api/qso/{id}` | Get single record | ✅ |
| POST | `/api/qso` | Create new QSO | ✅ |
| PUT | `/api/qso/{id}` | Update QSO | ✅ |
| DELETE | `/api/qso/{id}` | Delete QSO | ✅ |
| POST | `/api/import/csv` | Import HAMLOG CSV | ✅ |
| GET | `/api/qso/export/csv` | Export Shift-JIS CSV | ✅ |
| GET | `/api/callsign_cache` | Callsign autocomplete | ✅ |
| GET | `/api/hamlog/status` | bham health check | ✅ |
| GET | `/api/callsign/lookup` | Callsign lookup via bham | ✅ |
