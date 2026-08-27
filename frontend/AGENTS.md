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

<!-- # ARCHIVE SCREEN
- add in show menu icon convert to pdf only for excel files

# DOCUMENTS SCREEN ANDROID APP
- add in show menu icon convert to pdf only for excel files -->

<!-- # DOCUMENTS SCREEN AND ARCHIVE SCREEN -> opened stundent folder
- add space for table in bottom if no pagination 
- remove the space for table in bottom if it has pagination --> 

<!-- # STUDENT SCREEN
- add space for table in bottom if no pagination 
- remove the space for table in bottom if it has pagination --> 

<!-- # ARCHIVES SCREEN
- copy the table from the sudent folders tab to all archived docs, the pagination is inside of the table section -->

<!-- # recycle bin modal 
- apply dark theme responsive
- copy the multi select menu from the documents screen to this modal
- add delete all/ restore all when the multi select menu active -->

<!-- # TEACHERS ACADEMIC SETUP SCREEN
- Teachers tab: change the font color in dark theme acad year and section text
- Years tab: add validation cant add next two years for example this year is 2026 you cannot add acad year 2027-2028 upwards
- Years tab: fix automatic add years -> only add example this year is 2026 only add acad year 2026-2027
- Sections tab: filter dropdown -> tabs filtering by grades -->

<!-- # DOCUMENTS SCREEN AND ARCHIVES SCREEN
- apply excel icon for the documents in mobile
- add icons for all documents based on their file extension -->

<!-- # STUDENTS SCREEN
- ADD NEW STUDENT SCREEN -> enrollment step -> make the selection realtime when select year refresh the grade level, when selected grade level refresh the section
- EDIT STUDENT SCREEN -> "add enrollments" -> make the selection realtime when select year refresh the grade level, when selected grade level refresh the section -->

<!-- # STUDENT SCREEN -> EDIT STUDENT SCREEN -> Enrollments tab -> Add enrollment
- same size save button from cancel
- add left and right margin for the buttons layout -->

<!-- # STUDENT SCREEN
- add new student -> LRN field -> add preset "308035" first 6 digits for school id

# DOCUMENT SCREEN
- upload document -> review & upload step -> STUDENT LRN text field only number can input -->

<!-- # WINDOWS APP
- remove the logo in custom title bar (only for windows app) -->

<!-- # BACKDROP IMAGE
- add some overlay mini blur

# SEARCH BAR (ANDROID APP)
- add left and right margin for search bar
- dont make the backdrop image resize when the search bar is active -->

<!-- # DOCUMENT SCREEN AND ARCHIVE SCREEN
- copy from STUDENT SCREEN the table bottom spaces for pagination to the screen to these screen DOCUMENT AND ARCHIVES SCREEN -->

<!-- # DOCUMENT SCREEN AND ARCHIVES SCREEN for ANDROID APP
- make a menu FAB -> horizontal menu animation
- move the multi select menu to the menu FAB
- if only PRINT LIST need only to show, hide/remove the UPLOAD DOCUMENTS in menu FAB -->

<!-- # DOCUMENT SCREEN
- move filter icon between multi select and bulk add  -->

<!-- # DOCUMENT SCREEN AND ARCHIVES SCREEN
- Properties modal: add who uploads
- add in backend data for file size to get the accurate file size -->

<!-- - list view -> documents only keep the folder design -> Only file name, under the file name is size of file ex. [2MB], then right side the date ex. [Dec 20, 2024] then 3 dots for menu
- list view -> Folder only -> add count files inside ex. [3 items] -> keep the chips for JHS SHS just add, do not modify the chips code, only add under the file name
- hide/remove the status completed and chip in list view for documents only

- add multi select in more options like on windows app for android app
- make the grid view compact -> remove the background color sections -> Filename only, and Icon -> hide/remove the complete chip -> remove the 3 dots for menu in right side -->

<!-- # STUDENT SCREEN -> BULK ADD STUDENT -> APPLY ENROLLMENT STEP
- use LRN text field from ADD STUDENT SCREEN, do not edit the design and other text fields only the LRN text field -->

<!-- # STUDENT SCREEN
- use icon for multi select, no background color and border -->

<!-- # SEARCH BAR
- Windows app:
  - 'x' button not clickable and does not remove the history
  - make the history renders half of the screen
- Android app:
  - make the history renders half of the screen, dont modify other code, only the design -->

<!-- # DOCUMENT SCREEN
- Android app:
  - remove the multi select icon and in the more option icon also
  - keep only multi select icon in the menu FAB

# ARCHIVE SCREEN
- Android app:
  - remove the multi select icon in the more option
  - keep only multi select icon in the menu FAB -->

<!-- # DOCUMENT SCREEN AND ARCHIVES SCREEN
- Student Folders:
  - remove the title column in DOCUMENT SCREEN, but keep the count items and chip requirements progress
  - remove the title column in ARCHIVES SCREEN -> remove the LRN -> add right click/hold feature and actions a view student profile ->  show only Student name, under the student name the item count status chip next before the action button -->


<!-- # STUDENT SCREEN
- move the filter icon between the multi select icon and bulk add icon in windows app
- Filter modal: 
  - Doc status attention rename selections from "Default Doc Status Order, Low, High" to "Default, Completed, Pending"
  - remove the LRN Sort Order -->

<!-- # USER MANAGEMENT
- add another filter for inactive status, show in [all, admin, teacher] filter for active users -->

<!-- # CUSTOM DIALOGS
- add sound effects for success, error, warning, info, confirm -->

<!-- # STUDENT SCREEN
- student profile -> action icon button -> convert to bottom right FAB
- file delete moved to inside of recycle bin -> missing requirements count, dont count files inside of recycle bin -->

<!-- # STUDENT SCREEN
- fix/stay the table header when no student found -->

--- 

# DONT DO
- documents screen -> archive files hide in list -> move archive files into archive screen or in more icon
- recycle bin -> search history not delete history

- reports screen -> compliance -> students per year -> year filter
- reports screen -> horizontal scroll bar hint
- report screen -> dynamic year filter default as active year
- reports screen -> compliance hover on missing count shows all missing documents separated jhs shs
- dashboard screen -> kpi and analytics
- user management -> expired the jwt of deactivated user

- dashboard screen -> user friendly logs/histories
- notification separate admin and teacher
- teacher no assigned section theme color
- bug in bulk add student enrollment

- forget password sa admin side (email)
- search history dapat naalis
- lrn should not be fixed
- n/a add student in suffix part -> remove
- inactive academic year 
- multiple selection of files in select document type 
- how about when the pages needed to upload have two pages or more?
- archive still popping up even after archiving & overall number of docs are inaccurate in docs status
- overall number of docs are inaccurate in docs status
- table header on students directory
- accurate reports

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
