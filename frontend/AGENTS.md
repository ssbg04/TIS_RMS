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

<!-- # ANDROID APP

# DOCUMENT SCREEN
- add back prevention active multi select
  - 1st back, deactivates multi select
  - 2nd back, navigates to dashboard screen
- if the mutli select deactive
  - 1st back, navigate to dashboard

- add back prevention inside student folder
  - 1st back, navigates back folder 'Student Folders' tab
  - 2nd back, navigates to dashboard screen
- if the open folder is not present
  - 1st back, navigate to dashboard

# STUDENT SCREEN
- add back prevention active multi select
  - 1st back, deactivates multi select
  - 2nd back, navigates to dashboard screen
- if the mutli select deactive
  - 1st back, navigate to dashboard

# ARCHIVES SCREEN
- add back prevention inside student folder
  - 1st back, navigates back folder 'Student Folders' tab
  - 2nd back, navigates to dashboard screen
- if the open folder is not present
  - 1st back, navigate to dashboard -->

<!-- # DOCUMENTS SCREEN
1. apply dark mode
# ARCHIVES SCREEN
1. apply dark mode -->


<!-- - seach feature
  - search icon into 'X' when searched an user, clears search and refresh users list
  - fix searched field didnt hide when searched an user -->

<!-- # DOCUMENTS SCREEN
- copy file rename format remove the timestamp in the copied filename
- remove the feature: excel to pdf

# STUDENT SCREEN
1. edit student screen -> enrollments tab -> auto enrollment OCR:
  - do not add in database if not 7-12 grade level detect
  - add manual validation to add year level, grade level, section before saving to database
  - in manual validation add actions accept, decline, or delete, use only icons.
  - for icon only icons no container, no background, no border
  - fix drag and drop not working in windows app
2. Add new student screen:
  - fix drag and drop not working in windows app -->


<!-- # AUTO ENROLLMENT
- currently supports only SF9 and SF10
- SF9 is equal to report card, Form 138, School Form 9, Student Report Card, SF1 for JHS/SF9 for SHS
- SF10 is equal to School Form 10, Form 137, Form 137-A, Student Permanent Record -->
<!-- 
# DASHBOARD SCREEN
- notification bell open -> in windows app disable slide feature its for android only

# STUDENTS SCREEN
- Add new student screen -> back button and next button in the bottom make the same size
- Bulk add student screen -> make the button not full rounded same from "add new student screen"

# DOCUMENTS SCREEN
- Document preveiew modal -> make it fullscreen modal -> add "add to print list" icon button -> move the zoom in/out inside of the pdf or image viewer -> add "open with" icon button for excel files to open external excel viewer
- hold feature to see more menu in android add "view student profile"  -->

<!-- # ARCHVES SCREEN
- From "DOCUMENTS SCREEN", add hold feature for android and right click for windows to see more menu, add multi select and its multi select menu, and FAB print list for android, button print list for windows
- fix grid view in all archived docs tab -->

<!-- # SETTINGS SCREEN
- remove the extension name buttons make it only shows in dropdown

# USERS SCREEN
- add new user wolt modal -> do not make the stepper clickable -> email address when tpyed '@' shows all common email domains -->

<!-- # ARCHIVES SCREEN
- remove background color and border of the filter icon button -->

<!-- # ANDROID APP PUSH NOTIFICATION
- notication only works when the app is open, make it work even the app is not opened -->

<!-- # REPORTS SCREEN
- fix all data in compliance sections not fetched from the backend realtime -->

<!-- # VIBRATION FEATURE
- android: add haptic feedback for android, add dynamic vibrate/normal vibrate for all success, error, info dialogs, dynamic vibrate depends what dialog it is -->
<!-- 
# DOCUMENTS SCREEN
- filter modal: remove status filter for verified, draft and pending

# SETTINGS SCREEN
- Academic year ...  -> font color for "Check/Run Auto... now" white in dark theme and black in light theme -->
<!-- 
# DASHBOARD SCREEN
- recent activites:
  - update: enrollment description -> [year] - [grade level] - [section] - student [full name] - [LRN last 4 digits then first as bullet point]
  - add: filter modal -> entity type of enrollments and user -->

<!-- # STUDENT SCREEN
- rename: filter modal 'Item per page' to 'Students per Page'
- student profile -> add fixed margin for modal so the loading makes the loading modal smaller then bigger
- ADD/EDIT STUDENT -> update the date of birth dont add automatic year only automatic hyphen, make deletable too
- add margin bellow of 4Ps toggle
--->

<!-- # STUDENT SCREEN
- Add new student modal -> Academic year fix need to reselect before selecting a section (done) -> grade level need to reselect to select section  -->

<!-- # SPLASH ANIMATION
- use the backdrop and detects landscape/portrait and device theme (light or dark)
- remove the server connection loading, instead show entertaining loading words -->

<!-- # LOGIN SCREEN
- Login section background color -> add animation transparency but not too transparent its like blur after the full screen animation -->

<!-- # ALL CIRCULAR LOADING IN BUTTON
- make loading not oblong render it fully circle  -->

<!-- # NATIVE SPLASH SCREEN IN ANDROID APP
- use  -->

<!-- # DOCUMENTS SCREEN -> Upload Files, STUDENT SCREEN -> Add new student screen
- "use camera" fix error after back shows error "failed to scan document: PlatformException (Document Scanner, Operation Cancelled, null, null)", use appropriate error message -->

<!-- # DASHBOARD LOGS
- recent activites:
  - update: enrollment description -> "Enrolled student [LRN last 4 digits then first as bullet point] in [year] - [grade level] - [section]"
  - update: description update student -> "Updated student [LRN last 4 digits then first as bullet point]"
  - update: bulk description -> "Updated [number] students [last name] - [LRN last 4 digit then first as bullet point]", use unlisted list for multiple students
  - UI UX:
    - use the dashboard list design inside the screen
    - use dashboard activity details modal inside the screen
    - use filter modal design in students screen
    - fix the color and layout of filter button and clear, theme responsive
- user account history:
  - update: description of created user -> "Added user: [username] as [user role]"
  - update: description of updated user -> "Updated user: [username] [what changes in bullet point]"
  - add: log for users deactivate/activate user -> "[Deactivated/Activated] user: [username]"
  - add: log for reset user password -> "Reset password for user: [username]"
  - UI UX:
    - use the dashboard list design inside the screen
    - use dashboard activity details modal inside the screen
    - use filter modal design in students screen
    - fix the color and layout of filter button and clear, theme responsive -->

<!-- # STUDENT SCREEN
- Add new student screen:
  - Android app:
    - change the layout in name section in stock each other -> first name -> middle name -> last name -> suffix
    - hide the back button and next button, when typing
  - Windows app:
    - change the layout in name section -> 2 rows -> first name -> middle name, last name -> suffix

- Responsive layout edit student screen: text boxes same from new "add new student screen layout" and buttons responsive

- student profile modal: error exception: no enrollment, add appropriate message -->

<!-- # ALL SCREEN NO CONNECTION TO SERVER OR NO DATA RETRIEVED
- make a single widget for all no server fetch/no connection retrieve data
- no internet or no server fetch message on all screen: use appropriate message -->

# recycle bin modal (dont do)

---

# TIS_RMS Server Manager (dont do)
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
- dark mode -> ongoing



---
