# BACKEND WORKFLOW (F:\SumbrerongBato\tis_rms_server\backend)
1. Read/Analyze Task → Inspect backend directory.
2. Draft Code → Execute Quality Gate (Accept / Decline).
3. Post-Code Loop: Analyze Errors → Resolve → Re-verify until Errors == 0.
4. Terminal Exit: If build clean → Execute `git push`.

# FRONTEND WORKFLOW (F:\SumbrerongBato\tis_rms_server\frontend)
1. Read/Analyze Task → Inspect frontend directory.
2. Draft Components/Logic → Execute Quality Gate (Accept / Decline).
3. Post-Code Loop: Analyze UI/Build Errors → Resolve → Re-verify until Errors == 0.
4. Terminal Exit: If build clean & lint passes → Execute `git push`.

---

# ⚡️ TOKEN COMPRESSION PROTOCOL

## 1. INPUT RESTRICTIONS (CONTEXT DRYING)
- Ignore system-level file-tree re-reads unless files change (Δ).
- Avoid parsing historical chat history beyond the immediate code break.
- Reference internal libraries by name only; do not request full source mappings.

## 2. OUTPUT SYSTEM CONSTRAINTS (ZERO BLOAT)
- NO natural language intros, greetings, or conversational transitions.
- NO explanations, rationales, or "why this works" breakdowns.
- NO summaries of work completed or code recap commentary.
- Exclude all code comments, inline documentation, and docstrings.

## 3. PATCH FORMATTING (MICRO-DIFFS ONLY)
- BANNED: Full-file reprinting, multi-line blocks of unchanged code.
- MANDATORY: Return micro-diff format or target lines replacement only:
  ```diff
  - [old line]
  + [new line]
  ```
- If a file creation is required, generate minimal skeleton logic only.

## 4. QUOTA BRAKING
- Max output limit per prompt turn = 150 tokens.
- If patch logic requires >150 tokens: STOP, emit `[TOKEN LIMIT BRAKE]`, and wait for chunked instructions.

---

# 📱 FLUTTER UI/UX RULES
- Stack: Flutter (latest) + Riverpod (AsyncNotifier/Notifier) + Material 3 (`useMaterial3: true`).
- Palette: Use existing `Theme.of(context).colorScheme` tokens only. Never hardcode hex values.
- Layout: Stack actions vertically on Android (`Column` with full-width `ElevatedButton`).
- Output: No design essays. Return optimized widget code immediately.

---

# TODO
- dont do tasks with "(dont do)"

<!-- ## (dont do) Connected users api 
- i will use this to separate server manager
- create a api for this
- flutter: use heartbeat package
- connected users, detects windows or android, users admin or teacher, username, ip, login time datenow, last seen datenow
- every minute
- in memory list users
- server status, cpu mem usage, connected users, uptime
- separate the connected users and status api -->

<!-- ## (dont do) backup/restore feature
- Use better sqlite 3 backup api, db.backup()
- Automatic backups (Daily, Weekly, Monthly, or Custom)
- Configurable maximum number of snapshots (e.g., 5, 10, 20)
- Timestamp-based backup names
- Backup history in the UI
- One-click restore
- Automatic deletion of the oldest snapshot only after the newest backup is successfully created and verified
- Metadata for version and backup details
- Use configuration file json for backup and restore 
Files backup/restore - mirror mode or zip -->

<!-- ## settings screen
- add set start day, month and end year. month and day for the active year 
  - auto graduated the student that are grade 10 and grade 12 in the active year, make it sequential
    - add logs for these make it on one log compiled all students, separate per grade level 
  - if not set the start day, month, end year, do not auto graduate
- remove database management, this is separate windows app -->

<!-- # reports screen
- exports use the custom success/error dialog
- add clickable link path for success
- fix the overflow cards of overall compliance, students with issues, total missing documents -->

<!-- ## backend server backup/restore
- do not use zip and unzip -->

# LOGIN SCREEN
- apply dark theme
  - bring back the green background for the outer part of the login screen (the larger section)
  - use darker saturation for green background


---

TIS_RMS Server Manager (dont do)
Windows Service - NSSM nodejs
- backup/restore db and files
- backup: database backup, automatic schedule, snapshot retention 
- restore: restore database, validate backup, restart service automatically 
- files: mirror backup, verify files, restore files, 
- can choose where to store db and files separately 

- dashboard: server status, cpu mem usage, connected users, uptime 
- service: controls windows service stop start restart
- logs, server logs, error logs
- settings backup path, file backup path, database location

---

## (dont do) add some features
- dark mode
- documents screen
  - excel to pdf all tabs export into one pdf


---
