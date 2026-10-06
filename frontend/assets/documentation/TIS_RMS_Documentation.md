# Documentation Website

1. Per-Side Navigation Tab:
   - Add each individual page for every side of the system.
   - Each page should have Previous and Next navigation buttons at the bottom.
2. Overview Tab:
   - Add a dedicated page.
   - Add a brief introduction and description of the system.
3. Staff Roles & Access:
   - Add a dedicated page.
   - Teachers can register new students.
4. Sign In & Getting Started:
   - Add a dedicated page.
   - State that the system is available for the Android app and Windows app.
   - Explain that the system can be accessed outside the local network through a secure connection that makes the system accessible over the internet.
5. Module 1: Dashboard and Overview

- Dashboard Overview:
  - Add a dedicated page.
  - Remove the sentence about the recent activity feed.
- Admin and Teacher Side:
  - Both Admin and Teacher roles have access to Search, Notifications, and a Profile Dropdown.
    - Search: Allows users to search for students and navigate directly to the Students screen.
    - Notifications: Displays notifications based on the user's role. Administrators receive the same system notifications, while teachers only receive notifications related to their assigned sections.
    - Profile Dropdown: Displays the user's name, role, email, and phone number, along with buttons to navigate to Settings and Log Out.
- Admin Side:
  - Dashboard:
    - Has quick navigation for Academic & Class Management and Document Requirements screen
      - Add a link to the page for "Academic & Class Management" and "Document Requirements" page.
    - Has quick-access card buttons for Students, Documents, and Users screens.
    - The visual graphs include:
      - Digitalization Progress for JHS and SHS, showing the number of students who have completed their required documents, categorized by JHS and SHS.
      - Overall Document Status, showing the count and status breakdown of uploaded documents.
      - Document Breakdown by Grade Level, using a pie chart to show completed or submitted document requirements.
      - 30-Day Upload Trend, using a line graph to show document uploads over the past 30 days.
      - Storage Analytics, showing which types of documents consume the most storage space.
      - Top Students by Documents, showing a ranking of students based on the number of uploaded documents.
      - Students Needing Attention, showing students with missing documents and allowing administrators to view which documents are missing.
    - Each component should have a corresponding screenshot.
- Teacher Side:
  - Dashboard:
    - Has quick-access card buttons for navigating to the Students and Documents screens.
    - Top Students by Documents: Shows a ranking of students based on the number of uploaded documents from their assigned sections.
    - Students Needing Attention: Shows students with missing documents and allows teachers to view which documents are missing from their assigned sections.

6. Module 2: Student Information

- Student Information:
  - Add a dedicated page.
- Admin and Teacher Side:
  - Search: Allows users to search for students by last name, first name, LRN, grade level, or section.
  - Filter: Allows users to filter the student list by:
    - Grade Level: Displays grade levels based on the data available in the backend.
    - Section: Displays sections based on the data available in the backend.
    - 4Ps Beneficiary: Filters students by Yes or No.
    - Document Status / Attention: Filters students based on the number of missing documents:
      - Default: Displays all students.
      - Complete: Displays students with fewer missing documents.
      - Pending: Displays students with more missing documents.
    - Students per Page: Sets the number of students displayed on the list per page.
  - Student Information View: When a specific student is selected, the system displays:
    - Full Name
    - LRN
    - Status: Enrolled, Graduated, Dropout, Transferee, or Inactive
    - Sex
    - Birth Date
    - 4Ps Beneficiary
    - Enrollment History
    - Document Requirements, separated into JHS and SHS requirements.
    - Doc status, shows count of submitted over missing document, when clicked/hover shows all missing and completed documents
    - Open folder, navigates inside of student's folder
- Admin Side:
  - Add Students: Allows administrators to add students using OCR to speed up text-field input. Only SF9 and SF10 documents are supported. Students can also be added manually. The system supports bulk student registration using multiple SF9/SF10 documents from different students. Administrators can also use CSV to speed up the data-entry process.
    - Add a link to the Bulk Add Using OCR and CSV page for more information.
  - Edit Student Details: Allows administrators to edit the following student information:
    - LRN
    - Name
    - Sex
    - Status: Enrolled, Transferred, Dropped, or Inactive
    - Birth Date
    - 4Ps Beneficiary: Yes or No
  - Edit Enrollment: Allows administrators to edit a student's enrollment information. The system can scan uploaded documents associated with the selected student using OCR. Only SF9 and SF10 documents are supported. It also supports bulk enrollment addition and editing through CSV.
  - Multi-Select Actions: Supports long-press on touch devices or right-click on Windows devices to select multiple students. After selecting students, a menu is displayed with options to update their student status.
- Teacher Side:
  - Can edit student details, including:
    - LRN
    - Name
    - Sex
    - Birth Date
    - 4Ps Beneficiary: Yes or No

**7. Module 3: Documents & Student Folders**

- **Documents Screen:**
  - Add a dedicated page.
- **Admin and Teacher Side:**
  - **Search:** Allows users to search documents and student folders by **student name** or **LRN**.
  - **Folder Tab:** Displays student folders and supports filtering by:
    - **Grade Level**
    - **Section**
  - **All Documents Tab:** Displays uploaded documents and allows filtering by **document requirements** retrieved from the backend.
  - **Upload Documents:** Allows users to upload documents to the system.
    - When uploading a document outside a student folder, the system displays a note indicating that the document is not currently associated with a student.
    - When uploading a document from inside a student's folder, the system automatically identifies the student's **LRN**.
    - The upload interface displays document requirements in a **collapsible list**, showing required and completed documents.
    - On Android, users can scan documents using the device's built-in document scanning capability.
    - Documents can still be uploaded from existing files on both supported platforms.
  - **Document Preview:** Displays mini previews/thumbnails for supported PDF and image files.
    - Images can only be viewed using the built-in viewer.
    - PDF files display a preview and available document actions.
  - **Add to Print List:** Allows users to add selected documents to the print list. Add a link for a page of a print batch records.
  - **Document Actions:** Provides actions such as preview, download, add to print list, archive, delete, and other available document operations depending on the user's role and document state.
  - **Multi-Select:** Supports selecting multiple documents for batch actions.
  - **Document Requirements:** The available document requirements are retrieved from the backend, allowing the document list to remain synchronized with the configured requirements. Add a link for a page of guides of document requirements.

## 8. Module 4: Student Archives

- **Archives Screen:**
  - Add a dedicated page.
- **Archive Records:**
  - Displays archived student records and documents separately from active records.
  - Allows users to access previous student records without mixing them with currently active student records.
- **Student Archives:**
  - Allows admin to open an archived student's folder and view their stored documents.
  - Archived records can be accessed independently from the active student list.
- **Document Archive:**
  - Documents can be moved from active documents to the archive.
  - Archived documents can be restored when permitted.
- **Automatic Archiving:**
  - The system can automatically process students who no longer have an enrollment in the active academic year after the configured grace period.
  - Administrators can configure the automatic archiving settings. Add a link for a page of automatic archiving.

## 9. Module 5: Batch Print Records

- **Print List:**
  - Add a dedicated page or documentation section.
- **Admin and Teacher Side:**
  - **Print List:** Opens a modal containing documents selected for printing.
  - Users can:
    - Remove individual documents from the print list.
    - Clear all documents from the print list.
    - Review the documents before printing.
  - **Student Pickup Notification:** Allows staff to notify a student or guardian when printed documents are ready for pickup.
    - **Student/Guardian Email**
    - **Pickup Date**
    - **Office Note or Instructions**
  - **Print History:** Displays previously processed print lists.
  - **Add to Print List:** Documents can be added to the print list directly from the document preview or document actions.
- **Batch Printing:**
  - Supports printing multiple student documents in a single print operation.
  - Excel-based records can be processed for printing when conversion to PDF is required.
  - The print workflow should display the appropriate confirmation when document conversion is required.

---

## 10. Module 6: Reports & Analytics

- **Reports & Analytics:**
  - Add a dedicated page.
  - Provides administrators with reports, compliance information, and school record statistics.
  - Report data is retrieved from the backend and refreshed so the displayed information reflects current records.
- **Student Statistics:**
  - Displays student counts by status, including:
    - Active / Enrolled
    - Dropped
    - Transferred
    - Graduated
- **Document Compliance:**
  - Displays the overall document compliance of students.
  - Shows students with missing document requirements.
  - Allows administrators to identify students who need attention.
  - Provides a breakdown of missing documents by document requirement type.
- **Grade-Level Compliance:**
  - Displays document compliance based on grade level.
  - Helps administrators identify grade levels with higher numbers of incomplete student records.
- **Document Status Analytics:**
  - Provides a visual breakdown of student statuses.
  - Uses charts to make student and document statistics easier to understand.
- **Academic Year Comparison:**
  - Provides historical comparisons between academic years.
  - Allows administrators to review changes in student and document-related statistics across school years.
- **Storage Analytics:**
  - Provides information about document storage usage.
  - Helps administrators identify document types or records that consume significant storage space.
- **Report Filters:**
  - Allows reports to be filtered using available academic year, grade level, section, and student status options.
  - Filtered results update the displayed statistics and student compliance information.
- **Student Compliance Table:**
  - Displays individual student compliance information.
  - Includes student identification, name, grade and section, status, and missing document count.
  - Supports searching and sorting of report results.
- **Excel Export:**
  - Administrators can export compliance reports to **Excel (.xlsx)**.
  - The export includes student statistics, missing document breakdowns, and a student compliance list.
  - A preview is provided before saving the exported report.

---

## 11. Module 7: User Accounts

- **User Management:**
  - Add a dedicated page.
  - Administrators can manage staff accounts.
  - Administrators can create accounts for:
    - **Administrator**
    - **Teacher**
  - Administrators can search and filter staff accounts.
  - User accounts can be filtered by role and account status.
  - Administrators can view user account information and manage account status.
  - Account actions include:
    - Creating an account
    - Editing account information
    - Activating an account
    - Deactivating an account
    - Sending a password reset link
- **Teacher Access:**
  - Teachers can only access student records associated with their assigned sections.
  - Teachers can edit permitted student information within their assigned sections.
  - Teachers cannot register new students.
  - Teachers cannot modify restricted information such as student status or enrollment.
  - Enrollment management remains an administrator function.
- **Account Security:**
  - Users can change their passwords.
  - Users can update their own profile information.
  - Supports self-service password recovery.
  - Forgot-password recovery uses an email OTP verification process before allowing the password to be reset.
  - Administrators can initiate a password reset for staff accounts.
  - Password reset links require the user's registered email address.
  - Account activation and deactivation immediately affect the user's ability to access the system.
  - Account-related actions are recorded in the system history.

---

## 12. Module 8: Activity History

- **Activity History:**
  - Add a dedicated page.
  - Provides administrators with a record of important actions performed within the system.
  - Activity records can be reviewed to determine what action was performed and by which user.
- **Activity Logs:**
  - Records system activities such as adding, updating, archiving, deleting, and other supported actions.
  - Activity entries include information about the action, affected record, user, and date/time.
  - Administrators can open an activity entry to view additional details.
- **User Account History:**
  - Records account lifecycle events such as:
    - Creating a user
    - Updating a user
    - Activating a user
    - Deactivating a user
    - Resetting a user's password
  - Shows the user account affected and the administrator who performed the action.
- **Login & Session History:**
  - Provides information about user login sessions.
  - Allows administrators to review login and session activity.
  - Session information can include the username, user name, platform, IP address, login time, and session status.
- **Search and Filters:**
  - Allows users to search activity records.
  - Activity history can be filtered by:
    - Date range
    - Action
    - User
    - User role
  - Login sessions provide their own search and filtering options.
- **Pagination:**
  - History records are displayed using pagination to keep large activity logs manageable.
- **Access Control:**
  - User account history and login/session history are restricted to administrators.
  - Teachers are limited to the activity information available to their role.

---

## 13. Module 9: School Settings & Document Checklist

- **Settings:**
  - Add a dedicated page.
  - Provides administrators with controls for academic setup, document requirements, reminders, archiving, and system configuration.
  - Users can also manage their own profile and security settings.
- **Academic & Class Management:**
  - Administrators can manage:
    - **Academic Years**
    - **Grade Levels**
    - **Sections**
    - **Class Advisers / Teacher Assignments**
  - Teacher assignments determine which sections teachers can access and manage.
  - Academic year, grade level, and section information is retrieved from the backend.
  - Changes to academic and class information affect available enrollment and filtering options throughout the system.
  - Academic year setup also supports the system's automatic graduation process where configured.
- **Document Requirements:**
  - Administrators can manage the document requirements used throughout the system.
  - Administrators can:
    - Add new document requirements.
    - Edit existing document requirements.
    - Enable or disable requirements.
    - Set whether a requirement is mandatory.
    - Configure the applicable school level, such as **JHS** or **SHS**.
    - Configure accepted file types.
    - Configure the maximum number of files that may be uploaded when applicable.
    - Set a due date when applicable.
  - Enabled requirements appear in active student document checklists.
  - Disabled requirements are removed from active checklists without automatically deleting previously uploaded documents.
  - Document requirements are retrieved from the backend so changes are reflected across the system.
- **Teacher Document Reminders:**
  - Administrators can enable or disable automated reminders for teachers.
  - Administrators can configure how many days before the due date teachers should be reminded.
  - When enabled, teachers can receive notifications about missing document requirements for students in their assigned sections.
- **Automatic Archiving:**
  - Administrators can configure the automatic archiving feature.
  - Automatic archiving can be enabled or disabled.
  - Administrators can configure the grace period used before records are automatically archived.
  - The system can use the configured academic-year schedule when determining records eligible for archiving.
- **Automatic Graduation:**
  - The system supports an automatic graduation check for eligible students.
  - The process can identify eligible **Grade 10** and **Grade 12** students based on the configured academic-year schedule.
  - Administrators can manually run the automatic graduation check when permitted.
  - The system reports whether the graduation process was executed or skipped based on the configured schedule.
- **System Settings:**
  - Administrators can manage available system-level settings.
  - Settings are synchronized with the backend.
  - System configuration changes are reflected across the applicable screens.
- **Account Settings:**
  - Users can view and update their own profile information.
  - Profile information may include:
    - First name
    - Middle name
    - Last name
    - Name extension
    - Phone number
    - Email address
  - Users can manage security-related settings such as password changes.
  - Administrators have additional system-management options that are not available to teachers.
- **About, Support & System Information:**
  - Provides information about the Talisay Integrated School Records Management System.
  - Includes application and system information.
  - Provides developer/support information for system-related assistance.
