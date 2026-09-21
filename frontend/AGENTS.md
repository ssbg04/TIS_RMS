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

<!-- # DASHBOARD SCREEN
- teacher side -> no assigned section theme color
- remove analytics and KPIs in teacher side keep only the top students by documents and needs attention -->

<!-- # DOCUMENTS SCREEN
- archive files hide in list -> move archive files into in more icon where the switch grid includes, show the "archives" when the student folder opened or if the student have archived files -> hide the archives files in the documents list, only show completed files -->

<!-- # REPORTS SCREEN
- compliance tab -> "students per year" section -> year filter list all acad year -> deafult selected is 4 consecutive years (ex. 2022-2023, 2023-2024, 2024-2025, 2025-2026)
- horizontal scroll bar hint for android app
- filter by year default as active year
- compliance hover on missing count shows all missing documents separated jhs shs
- compliance tab -> "Student list" section -> remove missing requirements -> make the missing column hover just like on "STUDENT SCREEN", can see missing documents separate jhs and shs same from "STUDENT SCREEN" -->

<!-- # REPORTS SCREEN
- horizontal scroll bar hint for android app all overlaps graphs
- hover missing document make the design theme color responsive
- 

# STUDENT SCREEN
- hover missing document make the design theme color responsive -->

<!-- # AUTHENTICATION
- user management -> expired the jwt of deactivated user
- i can receive a push notifications even i logged out -->

<!-- # DISCONNECTED OR NO CONNECTION
- add dialog to reconnect or loads the splash screen
- always check LAN connection then if the LAN connection not working then use the tunnel connection -->

<!-- # STUDENT SCREEN
- add new student screen -> remove N/A on suffix dropdown

# DASHBOARD SCREEN
- upload document limit document type limit -> duplicate files -> if one file for one document type already exist, dont allow to upload another one
- kpi and analytics (active year)
  - document status distribution -> count by document type uploaded not count of total documents uploaded
  - Document type breakdown -> add filter dropdown for all document type -> if selected one document type show all year level in one pie chart, then it has over to the total
  - top student by documents -> dont count all uploaded document, just count document type uploaded over the total missing required documents -->

<!-- # DASHBOARD SCREEN
- "Top students by documents" and "needs attention" view all -> make the tab responsive use 1 word for tab title or remove the icon

# STUDENT SCREEN
- student profile modal -> make the modal have fixed size so every loading its not smaller when loading -->

<!-- # STUDENT SCREEN
- user friendly logs/histories and "analytics & KPIs" that uses basic english understandable by normal user

# TEACHERS & ACADEMIC SETUP
- hide or remove from the list all users have deactivated status -->
<!-- 
# STUDENT SCREEN
- student profile modal -> make the lrn can be copy add icon button to automatically copy -->

<!-- 
# DOCUMENT REQUIREMENTS SCREEN
- teachers cannot upload documents

# REPORTS SCREEN


- fix all horizontal scroll bars always visible not hide -> need to touch the graphs to show -->

<!-- 
# TEACHER & ACADEMIC SETUP
- Academic year updated dialog -> just one title word "Updated" 
  -->



<!-- - Deped transparency board -> rephrase the the description use easy to understand -> make it simple and user friendly -> dont make it AI slop -> make it responsive -->

<!-- # STUDENT SCREEN
- table dropdowns only status have dropdown, other convert to icon click to change the sorting order -->

<!-- # REPORT SCREEN
- deped transparency board -> remove the access and equity -> change the enrollment by sex & year to data on enrollment which compares the previous year students count and active year students count, difference, and remarks if increasing or decreasing, separate the jhs and shs

# USER MANAGEMENT
- make the admin side that resets user password send into their email the link to reset password add expiration time -> then push notif the admin that successful or not that email link, if not successful or the time has expired send notif to admin, if successfull push notif the user and admin  -->


<!-- # DOCUMENT REQUIREMENTS
- redesign the screen keep all logic change the layout and design only -->

<!-- # SETTINGS SCREEN
- make it modal, add current password then new password, keep the indicators for password strength

# REPORT SCREEN
- move the export button inside of the compliance section -->

<!-- # DOCUMENT SCREEN AND ARCHIVES SCREEN
- grid view -> fix overflow folders card 

# SETTINGS SCREEN
- add padding reset password modal -->
 

<!-- # STUDENT SCREEN
- add/edit student birthdate use date picker 

# TEACHERS & ACADEMIC SETUP
- years tab -> add/edit -> use toggle acad year not dropdown 
- acad year success dialog title overflow

# DOCUMENT SCREEN
- upload dialog success title fix overflow 

# ARCHIVE SCREEN
- archive purge remove in frontend and backend, prevent removal of student information and documents when deleting archives files

# BACKEND SERVICES
- remind all teachers (email) -> send list of students need attentions
- notif fix not pushing notif on android
- email reset password cant send an email -->

<!-- # USER MANAGEMENT SCREEN
- fix the table column title
- user detail modal -> redesign the three action buttons make it simple, dont use many colors
- add send an email that their account was deactivated/activated, created -->

<!-- # STUDENT SCREEN
- optimize the cards like from "DASHBOARD SCREEN" ->  improve the components for low end android phones -->

<!-- # USER MANAGEMENT SCREEN
- make table column header title fixed on top when scroll down -->  

<!-- # DOCUMENTS SCREEN
- redesign the tab and its top header, make it simple and responsive, make the design similar to the multi select menu (done) -> improve the design for lower end android, add redesign the list view and its grid (done)

# ARCHIVES SCREEN
- redesign the tab and its top header, make it simple and responsive, make the design similar to the multi select menu (done) -> improve the design for lower end android, add redesign the list view and its grid (done) -->

<!-- # USER SCREEN
- reset password modal it has overflow under the buttons (done)

# SETTINGS SCREEN
- make the user details, academic year & auto graduation, auto enrollment into collapse (done)

# USER MANAGEMENT SCREEN
- move the add FAB and search icon into the navigation header like same from student screen and dashboard screen (done)
- remove the title and description of the screen (done)

# REPORT SCREENS 
- remove the title and description of the screen (done) -->

<!-- # SETTINGS SCREEN
- fix overflow in auto graduation skip dialog title (done)
- edit schedule section add selectable years from academic years can select not add new acad year, if selected automatic active that selection status into active year (make this realtime fetch from backend) (done)

# STUDENT SCREEN
- edit student screen -> enrollment tab -> add enrollment modal -> add list of all current enrollments can delete, edit (make this realtime fetch from backend) (done) -->

<!-- # SETTINGS SCREEN
- all widgets that is collapse only title and collapse icon, move inside other components (done)
- add in appearance enable/disable sound and vibration, update the title and make it collapse only title and collapse icon (done) -->

<!-- # SETTINGS SCREEN
- default the vibration into disable, vibration hide in windows app (done)
- in academic & auto graduation collapse too many information, remove the duplicated information in this section (done)
- auto uncollapse all collapsable component when leave from this screen (done) -->

<!-- # SEARCH BAR HISTORY
- fix the history make sure it works at all .net framework, the history not working when clear and closing the history, and sometimes it works but the history disappears you need to active the search bar again to appear (done) -->

<!-- # DASHBOARD SCREEN
- profile pic dropdown when it click many times it has delay and opens multiple dropdowns

# DOCUMENTS SCREEN
- file icon click enables multi select
- if possible: icon of each file is mini preview of the document
- filter modal: remove status filter
- download success dialog, add notes and its download path location  -->

<!-- # USER SCREEN
- edit/add modal, make the the name text field in android app stack each other, add required email or phone number
- dont show the password to success dialog, just show the username and action success and add sent an email to the user email
- add after type '@' in email shows common domains, like @gmail.com, @yahoo.com, etc

# STUDENT SCREEN
- in windows app, make it modal the add student screen -->

<!-- # SETTINGS SCREEN
- add deletion of the account, add at the very bottom of the settings -> sends an email where user needs to click a link to delete the account, add a hidden super admin account and hidden from the frontend only developers can access this the role is admin but hidden to the system only developer can use this account to manage the users

# ARCHIVE SCREEN 
- file icon click enables multi select
- if possible: icon of each file is mini preview of the document
- filter modal: remove status filter
- download success dialog, add notes and its download path location

# STUDENT, DOCUMENT, AND ARCHIVE SCREEN
- icon multi select animation, the icon clicked animated to checked icon, remove the checkbox icon next to icon -->

<!-- # DASHBOARD SCREEN
- in storage analytics, use fewer color, make it simple, and list 3-5 files make it dropdown if more than this list limit
- top bottom fade, show the top fade if it has a component on top, same logic in bottom fade

# STUDENT SCREEN
- in windows app, make it modal the edit student screen
- use card for student table in windows app, make sure hover of doc status working and action button
- add right click (windows app) and hold feature (android app) -> dropdown with action label (view details, edit (active student details tab), add enrollment (active enrollment tab), view documents/archive folder (if not enrolled, shows archive, same functionality of the action button of open document button), change status [graduate, transfer, drop, set inactive] )
- in android app add dropdown to show the doc status
- remove the multi select button on screen header
- make the add studen FAB into icon button right side of filter button, make the color attract attention dont add background and border color
- add fade at top and bottom same from "dashboard screen"
- top bottom fade, show the top fade if it has a component on top, same logic in bottom fade

# ALL SCREENS PAGINATION
- redesign the pagination UI based on this picture F:\SumbrerongBato\tis_rms_server\Pictures\Screenshot 2026-09-17 181328.png
  - Desktop: Option 02 (Full width, clear text, page dropdown).
  - Mobile: Option 01 (or compact: ‹ 1 2 3 › + Page [ 1 ▾ ]).

# DOCUMENT SCREEN
- all FAB in android move to the screen header title like in dashboard screen
- optimize mini preview/thumbnails (backend & frontend) for fast loading:
  - backend: generate & cache resized lightweight thumbnails (~250px WebP/JPEG) + HTTP Cache-Control headers instead of serving raw original files
  - frontend: add cacheWidth/cacheHeight image memory decode optimization to eliminate scroll lag
- do not use wolt modal for "upload & OCR modal" and print queue modal after this remove the package of wolt modal sheet
- in print queue, when printing Excel file(s), show dialog asking to automatically convert them to PDF and proceed with printing instead of showing a blocking error dialog
- print list modal
  - print list history, print email to the student: email (optional), add available date to pickup, message to email can be manual message typed by registrar/staff or preset message (optional) -->
 
<!-- # DASHBORD SCREEN
- use the icon from windows app for notifications, and search icon in android app screen header icons

# STUDENT SCREEN
- in android app, screen header icon for search icon like in dashboard screen
- click icon add animation that enables multi select in android app
- in android app, remove the multi select icon button in screen header


# DOCUMENTS SCREEN
- F:\SumbrerongBato\tis_rms_server\screenshots\screenshot1.png -> align tabs section to the list layout, decrease space bottom list between the pagination buttons, in android app
- remove the multi select icon, in android app
- in android app, screen header move the print list icon, upload icon
- in file preview screen add icon button of all dropdown menu from the more menu -->
 
<!-- # STUDENT SCREEN
- in android app, screen header icon add icon button for "add student" make it more attractive

# DOCUMENT SCREEN
- file preview screen -> in android app make it more menu icon only delete and copy, make it responsive in android app base on screen size for default icons are 4 exclude the copy and delete, always inside are copy and delete in more icon if screen size small put all in more icon
- in filter documents only add document type, make it dropdown not modal

# ARCHIVE SCREEN 
- do the same from document screen design from this chat today  -->

<!-- # STUDENT SCREEN
- for non-enrolled/archived students (Graduated, Transferred, Dropped, Inactive):
  - backend: in `studentController.js`, include 'Archived' status alongside 'Completed' (`status IN ('Completed', 'Archived')`) when calculating missing/completed document requirements so submitted documents don't reset to 0/3.
  - student card: if student status is not 'Enrolled', style the doc status as an archived badge (e.g., "📁 X / Y Docs (Archived)" with muted slate/grey indicator) instead of the active orange warning bar; if 0 requirements/no enrollment records, display "Pending Enrollment" or "No Active Requirements".

# DOCUMENT SCREEN
- in upload document modal (`upload_ocr_modal.dart`), when a student is matched/selected, display a compact requirements summary strip showing all applicable requirements (filtered by JHS/SHS grade level):
  - separate into **Needed / Missing** (highlighted in orange/warning for immediate action) and **Completed** (subtle green/grey checkmarks confirming existing files on record).
  - allow tapping a needed requirement chip to auto-assign that document type to the selected/pending file in the upload list.
  - in the "Select Document Type" dropdown, add subtle badges tagging each item as `(Needed)` or `(Completed)`.
- post-download action for downloaded documents:
  - in download success dialog/notifications, add two action buttons: "Open File" and "View in Folder".
  - "Open File": immediately opens the downloaded document in the device's default viewer via `open_filex`.
  - "View in Folder":
    - in Android app: opens the device file manager directly inside `Download/TIS_RMS` via `android_intent_plus` (targeting `content://com.android.externalstorage.documents/document/primary:Download%2FTIS_RMS`, falling back to `ACTION_VIEW_DOWNLOADS`).
    - in Windows app: opens File Explorer highlighting the saved file (`explorer.exe /select, <path>`).
- print list & history (documents and archives screen):
  - history tab: add "Clear History" action with confirmation dialog.
  - student pickup email notification: if documents in queue belong to multiple students, group by student so notifications and documents are sent separately to each student/guardian (with optional custom message from registrar).
  - responsive UI: keep as modal dialog on Windows desktop, but use dedicated screen (or full-height bottom sheet) on Android app to prevent mobile keyboard overflow. -->

<!-- # STUDENT SCREEN
- in student profile detail modal (`student_profile_modal.dart` & `requirementController.js`):
  - backend (`requirementController.js` -> `getMissingRequirements`):
    - include both mandatory (`is_mandatory = 1`) and optional (`is_mandatory = 0`) document requirements so the frontend receives the full requirement checklist for the student's level (JHS/SHS).
    - include `'Archived'` document status alongside `'Completed'` (`status IN ('Completed', 'Archived')`) and return `d.status AS document_status` so the frontend knows whether a file is active or archived.
  - frontend (`student_profile_modal.dart`):
    - display both mandatory and optional document requirements with clear visual differentiation (`Mandatory` vs `Optional` tags/badges).
    - if a requirement's document on file is `'Archived'`, do NOT label it as "Done" or "Completed" — explicitly display it as **`Archived`** (with a slate/blue-grey archive badge and folder/archive icon).
    - ensure the UI is distinct from the student card's simple doc status progress bar (provide a dedicated checklist breakdown showing 4 explicit states: `Completed` [green], `Archived` [slate/blue archive], `Missing Mandatory` [warning], and `Optional Not Submitted` [muted info]).
- archived document counting rule across doc status & upload chips:
  - for **Enrolled** students: only active `Completed` documents count towards requirement completion; any archived document does NOT count as fulfilled (displays as `NEEDED` in the Document upload modal chips, and does not count towards active doc status progress).
  - for **Non-Enrolled** students (Graduated / Transferred / Dropped / Inactive): archived documents count towards their historical record (`📁 X / Y Docs [Archived]`). -->

<!-- # DOCUMENT SCREEN
- upload document on browse/scan document modal (`upload_ocr_modal.dart`):
  - **Completed fix**: a requirement marked as `Completed` must visually reflect its actual completed state (checked icon, green color); do not show it as still pending/unchecked.
  - **Collapsible requirement list**: make the document requirement list in the modal collapsible/expandable so it does not take up excessive vertical space on smaller screens.
  - **Responsive layout**: ensure the requirement list and its items resize/adapt properly across different screen widths (no overflow, no truncated text). -->

<!-- # REPORTS SCREEN
- DepEd Transparency Board separate section widgets:
  - clean minimal header banner with title, academic year filter, and PDF export (no clutter/info overload).
  - separate standalone section widgets/cards: 1. Data on Enrollment, 2. Dropouts & Transferees, and 3. 4Ps Beneficiaries.
  - each section card integrates its visual chart and detailed comparative table seamlessly without sub-tabs.

# ADD "UPDATE POP UP" AFTER SPLASH SCREEN
- detect version based on installed app vs latest tag version from GitHub repo https://github.com/ssbg04/TIS_RMS.
- `AppUpdateService` queries latest release via GitHub API, compares semver (`PackageInfo`), and resolves platform asset (.exe / .apk).
- `UpdateAvailableDialog` with installed vs latest version pill, platform asset tag, release notes, and download link.
- `SplashScreen` check with 4-second timeout and non-blocking background error handling. -->

<!-- # STUDENT SCREEN
- student profile detail modal, remove the edit button beside the delete -> add separate edit button for student details and enrollment tab 
- delete button change into inactive
- edit student modal, status remove the inactive
- multi modal action, remove inactive
- in android app, the click icon on student icon add short delay not a instant enables multi select

# REPORT SCREEN
- DEPED TRANSPARENCY BOARD, add collapse information for each widgets add short description for what each widget is for 
- use tab design simple  -->
<!-- 
# DASHBOARD SCREEN
- dont count the super admin in count 

# SETTINGS SCREEN
- change password modal, rename the label UPDATE PASSWORD into UPDATE

# USER SCREEN
- user profile details, edit action buttons label use one word, make the button size the same -->

<!-- # REPORTS SCREEN
- add horizontal scroll bar for tab of sections in deped transparency board
- add in compliance and analytics in student document compliance missing status add bottom sheet modal and dropdown icon for missing status 
- compliance & analytics tab:
  - student document compliance, make the filter into modal, add it into screen header in android 
  - students per year, make the filter into modal, list all academic years and its checklist

# Automatic archiving
- not detect enrolled based on time limit on start date, complete the requirements to still enrolled (ex. 30 days), can dynamically change, no enrollment after the due date (auto archive), status (not enrolled, inactive)

# Audit Trail/History Screen and Tab
- new screen and tab, move user history and recent activities from dashboard to here

# Theme
- default the theme to light mode, not based on device theme -->

<!-- # DASHBOARD SCREEN
- document breakdown fix the overflowed
- remove from the frontend user history and recent activities

# STUDENT SCREEN
- fix overflow on edit details button on android app

# DOCUMENTS AND ARCHIVES SCREEN
- fix that on grid view, only large folder icon and under it the name and the status chip and count of docs ex. (3)

# REPORTS SCREEN
- academic year filter on deped transparency board not readable 
- compliance & analytics export label color is not theme responsive and reduce size

# SETTINGS SCREEN
- default the auto update enrollment turned off
- add input for automatic archiving grace period
- change password update label color not theme responsive
- the danger zone is transparent fix it -->

<!-- # STUDENT SCREEN
- add student button make the icon button more attractive
- edit student modal 'x' button from left move to the right
- student profile add little bit attrativeness on edit details and edit enrollment

# DOCUMENTS AND ARCHIVES SCREEN
- in grid view for folders, F:\SumbrerongBato\tis_rms_server\screenshots\folders.png check this screenshot check only folder icons copy that design the icon the label below it, then the two chip of JSH and SHS requirement are inside of the icon of folder
- fix the multi select menu that didnt match width same as the list widget check this image F:\SumbrerongBato\tis_rms_server\screenshots\Screenshot 2026-09-19 163043.png

# HISTORY SCREEN
- "F:\SumbrerongBato\tis_rms_server\screenshots\Screenshot 2026-09-19 164307.png" fix this windows app cant list the widgets because and fix too overflow and cant list the widgets in android app F:\SumbrerongBato\tis_rms_server\screenshots\history.png -->

# SETTINGS SCREEN
- Delete account -> update to self deactivates, remove email function for deletion, use email for deactivation add client side 2 times confirmation dialog

- report screen -> compliance -> fix fliter button label is in half
- settings screen -> acadmeic year and auto graduation -> edit schedule date modal -> fix button labels is in half

# DOCUMENT SCREEN
- file preview screen -> open with is not working

# WINDOWS SIDE NAV BAR
- windows app -> side bar nav move the archive tab to overview group

---

# DONT DO
<!-- - documents screen -> add how many files can be uploaded into a document requirement, the current limitation is only 1, so we can dynamically choose number files that can be uploaded into that document, update both frontend and backend, but first give me suggestion where will put the setting of this, ask me first   -->

- CSV bulk add student, academic and section [acad year, grade level, sections]

- print list history, print email to the student make it optional, add date of print, add status (done, not done, in progress, picked up), add message to email can be manual message typed by registrar/staff, 

- teacher no assigned section theme color
- bug in bulk add student enrollment

- recycle bin -> search history not delete history

- add missing students by document type kpi


- notification separate admin and teacher
- bug in bulk add student enrollment

- report all filter and export 
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
