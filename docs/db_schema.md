# CROSSWAVE — Database Schema

## Overview

SQLite database schema managed by open-logbook.
Database file: `logbook.db`

---

## Table: qso_log

### DDL

```sql
CREATE TABLE qso_log (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    callsign      TEXT NOT NULL,
    date          TEXT NOT NULL,
    time          TEXT NOT NULL,
    his_rst       TEXT DEFAULT '59',
    my_rst        TEXT DEFAULT '59',
    freq          TEXT NOT NULL,
    mode          TEXT NOT NULL,
    code          TEXT,
    grid_locator  TEXT,
    qsl_status    TEXT DEFAULT 'N',
    name          TEXT,
    qth           TEXT,
    remarks1      TEXT,
    remarks2      TEXT,
    notes         TEXT,
    flag          INTEGER DEFAULT 0,
    user          TEXT DEFAULT '',
    source        TEXT DEFAULT 'manual',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key (AUTOINCREMENT). Gaps allowed (deleted IDs are not reused) |
| `callsign` | TEXT | Remote station callsign (required) |
| `date` | TEXT | QSO date in `YY/MM/DD` format (e.g., `26/03/07`) |
| `time` | TEXT | QSO time. JST: `HH:MMJ`, UTC: `HH:MMU` (e.g., `20:29J`) |
| `his_rst` | TEXT | Remote station RST report (default: `59`) |
| `my_rst` | TEXT | My station RST report (default: `59`) |
| `freq` | TEXT | Frequency in MHz (e.g., `430`, `144`) |
| `mode` | TEXT | Mode (e.g., `FM`, `SSB`, `CW`) |
| `code` | TEXT | Member code, etc. (optional) |
| `grid_locator` | TEXT | Grid locator (optional, e.g., `PM84`) |
| `qsl_status` | TEXT | QSL exchange status (see below) |
| `name` | TEXT | Remote station operator name |
| `qth` | TEXT | Remote station location |
| `remarks1` | TEXT | Remarks 1 (QSO notes, etc.) |
| `remarks2` | TEXT | Remarks 2 (HAMLOG macro strings, e.g., `%愛知県弥富市 %Rig#46`) |
| `notes` | TEXT | Free-form notes (not exported to HAMLOG CSV) |
| `flag` | INTEGER | hQSL sent flag (`0`: not sent, `1`: sent) |
| `user` | TEXT | hQSL user identifier (default: empty string. Values: `""` / `hQSL` / `user`) |
| `source` | TEXT | Record origin (see below) |
| `created_at` | TIMESTAMP | Created timestamp (UTC) |
| `updated_at` | TIMESTAMP | Updated timestamp (UTC) |

### qsl_status Values

| Value | Description |
|-------|-------------|
| `N` | Not exchanged |
| `J` | Via JARL (bureau) |
| `JE` | JARL electronic (hQSL) |
| `J*` | Other JARL-related |
| `NE` | Electronic QSL (non-JARL) |

### source Values

| Value | Description |
|-------|-------------|
| `manual` | Manual entry from CrossWave.app |
| `draft` | Draft (reserved for future use) |
| `hamlog_csv` | Imported from HAMLOG CSV |

### Index

```sql
-- Deduplication index (used to skip duplicates during import)
CREATE UNIQUE INDEX idx_dedup ON qso_log (callsign, date, time);
```

---

## Table: callsign_cache

### DDL

```sql
CREATE TABLE callsign_cache (
    callsign  TEXT PRIMARY KEY,
    name      TEXT,
    qth       TEXT,
    code      TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `callsign` | TEXT | Callsign (primary key) |
| `name` | TEXT | Operator name |
| `qth` | TEXT | Location |
| `code` | TEXT | Member code, etc. |
| `updated_at` | TIMESTAMP | Last updated |

### Usage

- Callsign autocomplete in QSO Board (`GET /api/callsign_cache?q={prefix}`)
- Auto-upsert on `POST /api/qso`

---

## HAMLOG CSV Column Mapping

Mapping between HAMLOG CSV export and `qso_log` columns.
No header row. Shift-JIS encoding.

| CSV Column | Field | Notes |
|------------|-------|-------|
| 1 | `callsign` | |
| 2 | `date` | `YY/MM/DD` |
| 3 | `time` | `HH:MMJ` (JST) |
| 4 | `his_rst` | |
| 5 | `my_rst` | |
| 6 | `freq` | |
| 7 | `mode` | |
| 8 | `code` | |
| 9 | `grid_locator` | May be empty |
| 10 | `qsl_status` | |
| 11 | `name` | |
| 12 | `qth` | |
| 13 | `remarks1` | |
| 14 | `remarks2` | May be double-quoted |
| 15 | `flag` | `0` / `1` |
| 16 | `user` | hQSL user string |

Export uses the same column order (`source`, `created_at`, `updated_at` are excluded).
