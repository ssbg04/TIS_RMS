# TIS RMS Design Improvement Plan

## Audit Summary

**Platform**: Flutter (Windows Desktop + Android)  
**Screens Analyzed**: 10 screen modules, 34 dart files, 3 layouts, 18 shared components  
**Design System**: AppColors (46 lines), AppSizes (20 lines), AppTheme (308 lines)  
**Scope**: Both Android and Windows platforms

---

## Priority Levels
- **P0 - Critical**: Broken functionality, visual bugs, or accessibility failures
- **P1 - High**: Inconsistency, maintainability blockers, or significant UX friction
- **P2 - Medium**: Polish, optimization, or minor inconsistencies
- **P3 - Low**: Nice-to-have improvements, future-proofing

---

## CATEGORY 1: Design System & Theming Issues

### 1.1 [P1] Hardcoded Colors Throughout Screens
**Problem**: ~68+ instances of `withOpacity()` (deprecated) instead of `withValues(alpha:)`, and inline hex colors bypassing `AppColors`.  
**Files Affected**:
- `documents_screen.dart` — inline `Colors.grey.shade200`, `Colors.black54`, etc.
- `students_screen.dart` — hardcoded greys for borders and backgrounds
- `archives_screen.dart` — duplicate color definitions
- `reports_screen.dart` — hardcoded table header colors
- `capstone_members_screen.dart` — **zero dark mode support**, all light theme colors hardcoded
- `app_theme.dart:29,43,180,207` — uses `withOpacity()` (deprecated API)

**Recommendation**:
- Migrate all 68 `withOpacity()` calls to `withValues(alpha:)`
- Add missing tokens to `AppColors`: `borderLight`, `borderDark`, `hoverLight`, `hoverDark`, `overlayLight`, `overlayDark`
- Fix `capstone_members_screen.dart` to use theme-aware colors

### 1.2 [P1] Incomplete Dark Mode on Multiple Screens
**Problem**: Dark mode checks are manual (`Theme.of(context).brightness == Brightness.dark`) scattered in every screen rather than using `colorScheme` tokens. Several screens have incomplete coverage.  
**Files Affected**:
- `capstone_members_screen.dart` — no dark mode at all
- `reports_screen.dart` — partial dark mode (table headers and data rows miss dark variants)
- `splash_screen.dart` — manual server entry dialog lacks dark mode styling
- Document/student widget files — inconsistent dark mode in filter panels

**Recommendation**:
- Use `Theme.of(context).colorScheme.surface` / `.onSurface` / `.surfaceContainerHighest` instead of manual brightness checks where possible
- Audit and fix every screen for complete dark mode coverage
- Create a `context.isDark` extension to reduce boilerplate

### 1.3 [P2] AppSizes Token Gaps
**Problem**: `AppSizes` only defines 8 padding values and 4 radii. Missing: icon sizes, elevation values, breakpoints, font sizes, line heights, animation durations.  
**Files Affected**: All screens use raw `double` literals for these.

**Recommendation**: Extend `AppSizes` with:
```dart
// Icon Sizes
static const double iconSmall = 16.0;
static const double iconMedium = 24.0;
static const double iconLarge = 32.0;

// Elevations
static const double elevationNone = 0.0;
static const double elevationLow = 2.0;
static const double elevationMedium = 4.0;

// Breakpoints
static const double breakpointMobile = 480.0;
static const double breakpointTablet = 800.0;
static const double breakpointDesktop = 1200.0;

// Animation Durations
static const Duration animFast = Duration(milliseconds: 200);
static const Duration animMedium = Duration(milliseconds: 300);
```

### 1.4 [P2] No Typography Scale
**Problem**: Font sizes are hardcoded throughout: `fontSize: 12`, `fontSize: 14`, `fontSize: 16`, `fontSize: 20`, etc. No central typography scale.  
**Files Affected**: Every screen file.

**Recommendation**: Use Material 3 `TextTheme` consistently (`Theme.of(context).textTheme.bodyMedium`, `.titleLarge`, etc.) instead of `GoogleFonts.inter(fontSize: X)` inline.

---

## CATEGORY 2: Architecture & Code Organization

### 2.1 [P0] God-Class Screen Files
**Problem**: The 7 largest screen files are monolithic classes with 1,900-3,600+ lines each. Each `_ScreenState` contains 15-25+ private `_build*` methods, making them extremely hard to maintain, test, and review.  
**Files Affected**:
| File | Lines | Private Methods |
|------|-------|----------------|
| `reports_screen.dart` | 3,611 | ~25 |
| `documents_screen.dart` | 3,251 | ~20 |
| `students_screen.dart` | 2,902 | ~18 |
| `archives_screen.dart` | 2,449 | ~15 |
| `requirements_settings_screen.dart` | 2,233 | ~15 |
| `users_screen.dart` | 2,121 | ~12 |
| `settings_screen.dart` | 1,920 | ~10 |

**Recommendation**: Extract each `_build*` method into a standalone widget in a `widgets/` subdirectory. Target: no screen file exceeds 500 lines. Example for `documents_screen.dart`:
- `DocumentsHeader` widget
- `DocumentsFilterPanel` widget
- `DocumentsGridView` widget
- `DocumentsListView` widget
- `DocumentsMobileList` widget
- `BulkOperationsBar` widget

### 2.2 [P1] Duplicated Widget Patterns (500+ Lines of Duplication)
**Problem**: Identical patterns are copy-pasted across 3-5 screens.

| Duplicated Pattern | Files | Est. Duplicate Lines |
|-------------------|-------|---------------------|
| Error state widget (wifi_off icon + retry) | documents, students, users, archives, settings | ~120 lines |
| Empty state widget (icon + text) | documents, students, archives, users | ~80 lines |
| Search dialog (`showDialog` with `TextField`) | documents, students, archives, users | ~200 lines |
| Filter dropdown section | documents, students, archives | ~150 lines |
| Pagination controls | documents, students, archives, users | Uses `AppPagination` (good) |

**Recommendation**: Extract shared widgets:
- `AppErrorState({String message, VoidCallback onRetry})`
- `AppEmptyState({IconData icon, String title, String? subtitle})`
- `showAppSearchDialog(context, {onSearch, searchHistory})`
- `FilterDropdownSection({title, items, selectedValue, onChanged})`

### 2.3 [P1] Incomplete SnackBar-to-Dialog Migration
**Problem**: The codebase is mid-migration from `SnackBar` to custom `showSuccessDialog`/`showErrorDialog`. ~17 `SnackBar` instances remain, creating inconsistent feedback patterns.  
**Files with remaining SnackBars**:
- `students_screen.dart` — `_BulkEnrollModal` uses SnackBar for errors
- `documents/widgets/requirements_settings_modal.dart` — SnackBar for both success/error
- `archives_screen.dart` — some operations still use SnackBar
- `login_screen.dart` — mixed feedback patterns

**Recommendation**: Complete the migration. Replace all remaining `SnackBar` usages with `showSuccessDialog` / `showErrorDialog`.

---

## CATEGORY 3: Android-Specific Design Issues

### 3.1 [P0] Portrait Lock on All Orientations
**Problem**: `main.dart:48-51` locks orientation to `portraitUp`/`portraitDown` globally, including on tablets where landscape is expected.  
**Recommendation**: Only lock portrait on phones; allow landscape on tablets (check `shortestSide >= 600`).

### 3.2 [P1] Touch Target Sizes
**Problem**: Several interactive elements have touch targets below the Material 3 minimum of 48x48dp.
- Sidebar collapse/expand icon buttons
- Pagination chevron buttons (`AppPagination`) — no minimum size constraint
- Filter chips in compact mobile layouts
- Action icon buttons in table rows

**Recommendation**: Wrap all interactive icon elements with `ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48))` or use `IconButton` with proper padding.

### 3.3 [P1] Android Bottom Navigation Inconsistencies
**Problem**: `android_bottom_nav_layout.dart` uses a `NavigationBar` with 5 items (Dashboard, Documents, Students, Archives, Reports) but the hamburger drawer adds Settings, Users, About — creating a split navigation model that's not intuitive.  
**Recommendation**:
- Consider a unified drawer-based navigation for Android with grouped sections
- Or reduce bottom nav to 4 items (Material 3 recommends 3-5) and move Reports to the drawer

### 3.4 [P2] No Back Button Handling
**Problem**: Per the AGENTS.md TODO, back button prevention for multi-select mode and folder navigation is not yet implemented on Android.  
**Recommendation**: Implement `PopScope` (replaces deprecated `WillPopScope`) on Documents, Students, and Archives screens to handle:
- 1st back: deactivate multi-select
- 2nd back: navigate to parent folder or dashboard

### 3.5 [P2] No Pull-to-Refresh on Android
**Problem**: Mobile screens use polling timers (5s-15s intervals) but lack pull-to-refresh gesture, which is the expected interaction on mobile.  
**Recommendation**: Wrap list views in `RefreshIndicator` for manual refresh on Android.

---

## CATEGORY 4: Windows Desktop-Specific Design Issues

### 4.1 [P1] Sidebar Visual Polish
**Problem**: The Windows sidebar lacks hover state animations on nav items when collapsed. The collapsed sidebar shows only icons with tooltips, but tooltip positioning can overlap with the sidebar edge.  
**Recommendation**:
- Add `InkWell` hover feedback with subtle background color change
- Adjust tooltip `preferBelow` and `verticalOffset` for collapsed state

### 4.2 [P1] No Keyboard Navigation / Shortcuts
**Problem**: No keyboard shortcuts exist for common desktop operations:
- No `Ctrl+F` for search
- No `Ctrl+N` for new student/document
- No `Tab` / `Shift+Tab` focus traversal optimization
- No `Escape` to close modals (some modals handle this, others don't)

**Recommendation**: Add `Shortcuts` + `Actions` widgets for common operations. Ensure all modals respond to `Escape`.

### 4.3 [P2] Window Title Bar
**Problem**: Custom `WindowCaption` replaces the native title bar (`TitleBarStyle.hidden`), but the splash screen implements its own caption separately from the layout shells.  
**Recommendation**: Unify window caption handling — single `WindowCaption` widget used by all routes.

### 4.4 [P2] Right-Click Context Menus
**Problem**: Desktop users expect right-click context menus on items (documents, students, files). Currently only `PopupMenuButton` icon is used.  
**Recommendation**: Add `GestureDetector.onSecondaryTapUp` or use `ContextMenuRegion` for right-click context menus on desktop.

---

## CATEGORY 5: Responsive Design Issues

### 5.1 [P1] Inconsistent Breakpoints
**Problem**: Breakpoint values are scattered and inconsistent across screens.

| Screen | Breakpoints Used |
|--------|-----------------|
| `responsive_layout.dart` | 800 |
| `documents_screen.dart` | 400, 600, 800, 900, 1200 |
| `students_screen.dart` | 480, 600, 700, 800 |
| `reports_screen.dart` | 600, 800, 1200 |
| `dashboard_screen.dart` | 600, 800 |
| `splash_screen.dart` | 800 |

**Recommendation**: Define `AppBreakpoints` constant class:
```dart
class AppBreakpoints {
  static const double compact = 480;   // Phone
  static const double medium = 800;    // Tablet / small desktop
  static const double expanded = 1200; // Desktop
}
```
Use consistently across all screens.

### 5.2 [P2] Grid Column Count Logic Duplication
**Problem**: Multiple screens compute grid columns with `LayoutBuilder` + `MediaQuery` width using slightly different formulas (some divide by 200, others by 250, etc.).  
**Recommendation**: Create a `responsiveGridColumns(double width)` utility function.

---

## CATEGORY 6: UX & Interaction Design

### 6.1 [P1] No Loading Skeletons / Shimmer
**Problem**: All loading states use `CircularProgressIndicator` centered on screen. This causes layout shift when data loads and provides no visual context of what's loading.  
**Recommendation**: Implement shimmer/skeleton loading for:
- Dashboard stat cards
- Student list/grid
- Document list/grid
- Archives list

### 6.2 [P1] Modal Overuse on Desktop
**Problem**: Operations that could use inline editing (rename, status change) use full-screen modals, which is jarring on a desktop with ample screen space.  
**Recommendation**:
- Use inline editing / side panels for quick operations on desktop
- Reserve modals for complex multi-step operations (add student, upload document)

### 6.3 [P1] No Undo / Confirmation Consistency
**Problem**: Destructive operations have inconsistent confirmation patterns:
- Delete document: requires confirmation dialog
- Bulk delete: requires confirmation dialog
- Archive: requires confirmation dialog
- Remove from print queue: no confirmation
- Clear search history: no confirmation

**Recommendation**: Standardize: all destructive operations get confirmation. For reversible operations, use "undo" snackbar instead.

### 6.4 [P2] Empty States Lack Call-to-Action
**Problem**: Empty states show an icon and text like "No students found" but don't guide the user to add one.  
**Recommendation**: Add primary action button in empty states: "Add your first student", "Upload a document", etc.

### 6.5 [P2] No Onboarding / First-Run Experience
**Problem**: New users see a setup banner but no guided walkthrough. The system requires: create academic year → assign sections → add teachers → add students → upload documents.  
**Recommendation**: Add a setup progress checklist on the dashboard for first-time setup.

### 6.6 [P3] Polling Timer UX
**Problem**: Dashboard polls every 5s, Documents every 15s. No visual indicator of sync status or last-updated time. Users can't tell if data is fresh.  
**Recommendation**: Add a subtle "Last updated: X seconds ago" indicator or a refresh icon with timestamp.

---

## CATEGORY 7: Accessibility

### 7.1 [P0] No Semantic Labels
**Problem**: Almost no `Semantics` widgets used across the entire codebase. Screen readers cannot navigate the app.  
**Files Affected**: All screens.

**Recommendation**: Add `Semantics` labels to:
- All icon buttons (`semanticLabel` parameter)
- All images and decorative elements
- Navigation items
- Stat cards (describe the metric value)
- Status badges

### 7.2 [P1] Color-Only Status Indicators
**Problem**: Document statuses use color only (green=complete, orange=pending, red=missing) without text or icon differentiation.  
**Recommendation**: Always pair status colors with text labels and/or icons. Users with color vision deficiency cannot distinguish them otherwise.

### 7.3 [P2] Focus Indicator Visibility
**Problem**: No custom focus indicator styles. Default Material focus rings may not be visible on green-themed surfaces.  
**Recommendation**: Ensure focus indicators have sufficient contrast on all surface colors.

---

## CATEGORY 8: Performance-Related Design

### 8.1 [P1] IndexedStack Loads All Visited Screens in Memory
**Problem**: Both `WindowsSidebarLayout` and `AndroidBottomNavLayout` use `IndexedStack` with a `_visitedIndices` set. Once a screen is visited, it stays in the widget tree permanently.  
**Recommendation**: For screens with heavy data (Documents, Students, Reports), consider using `AutomaticKeepAliveClientMixin` with `PageView` or lazy `TabBarView` instead, allowing Flutter to dispose off-screen widgets.

### 8.2 [P2] Large Lists Without Virtualization
**Problem**: Some list views build all items at once instead of using `ListView.builder` with `itemCount`.  
**Recommendation**: Audit all `Column(children: items.map(...))` patterns and replace with `ListView.builder` for lists > 20 items.

---

## CATEGORY 9: Visual Polish

### 9.1 [P2] Inconsistent Card Elevation & Shadows
**Problem**: Cards across screens use different elevation values (0, 1, 2, 4) and some use `Container` with `BoxShadow` while others use `Card` widget.  
**Recommendation**: Standardize on `Card` widget with theme-defined elevation. Remove all `Container`+`BoxShadow` patterns.

### 9.2 [P2] No Micro-Animations
**Problem**: State transitions are instant (tab switches, filter applications, data loading). No subtle animations.  
**Recommendation**: Add:
- `AnimatedSwitcher` for content transitions
- `AnimatedContainer` for filter panel expand/collapse
- Staggered item animations for grid/list appearance

### 9.3 [P3] Inconsistent Icon Styles
**Problem**: Mix of Material Icons (filled), Material Icons Outlined, and a few custom icons. No consistent icon style.  
**Recommendation**: Standardize on outlined icons (Material Symbols Outlined) for consistency.

---

## Actionable Implementation Task Checklist

### Phase 1: Foundation & Design System Setup
- [X] **Task 1.1**: Extend `AppColors` (`lib/core/constants/app_colors.dart`)
  - Add `borderLight`, `borderDark`, `hoverLight`, `hoverDark`, `overlayLight`, `overlayDark`.
  - Fix dark mode color palette references.
- [X] **Task 1.2**: Create `AppBreakpoints` (`lib/core/constants/app_breakpoints.dart`)
  - Define `compact = 480`, `medium = 800`, `expanded = 1200`.
- [X] **Task 1.3**: Extend `AppSizes` (`lib/core/constants/app_sizes.dart`)
  - Add standard icon sizes (`iconSmall`, `iconMedium`, `iconLarge`), elevations, and animation durations.
- [X] **Task 1.4**: Add BuildContext Theme Extension (`lib/core/utils/theme_extension.dart`)
  - Add `context.isDark`, `context.colors`, and `context.textTheme` helpers.
- [X] **Task 1.5**: Migrate Deprecated Color API
  - Replace ~68 instances of `withOpacity()` with `withValues(alpha:)`.
- [X] **Task 1.6**: Fix `CapstoneMembersScreen` Dark Mode
  - Remove hardcoded light theme colors in `capstone_members_screen.dart`.

### Phase 2: Shared Component Extraction
- [X] **Task 2.1**: Build `AppErrorState` Component (`lib/ui/shared/widgets/app_error_state.dart`)
  - Extract duplicate error UI from 5 screens into a single configurable widget.
- [X] **Task 2.2**: Build `AppEmptyState` Component (`lib/ui/shared/widgets/app_empty_state.dart`)
  - Extract duplicate empty state UI with title, subtitle, icon, and optional CTA button.
- [X] **Task 2.3**: Build `FilterDropdownSection` & `FilterChipGroup`
  - Consolidate duplicated filter UI logic across `documents_screen.dart`, `students_screen.dart`, `archives_screen.dart`.
- [X] **Task 2.4**: Complete SnackBar to Dialog Migration
  - Replace 17 remaining `SnackBar` calls with `showSuccessDialog` / `showErrorDialog`.

### Phase 3: Screen Refactoring & Decomposition
- [X] **Task 3.1**: Refactor `documents_screen.dart` (3,251 lines)
  - Extract `DocumentsHeader`, `DocumentsFilterPanel`, `DocumentsGridView`, `DocumentsListView`, `DocumentsMobileList`, `BulkOperationsBar`.
- [X] **Task 3.2**: Refactor `reports_screen.dart` (3,611 lines)
  - Extract table cards, header filters, export dialog triggers, and compliance widgets into `lib/ui/screens/reports/widgets/`.
- [X] **Task 3.3**: Refactor `students_screen.dart` (2,902 lines)
  - Extract filter headers, table views, grid views, and mobile list items.
- [X] **Task 3.4**: Refactor `archives_screen.dart` (2,449 lines) and `settings` screens.

### Phase 4: Platform-Specific Optimization & Project TODO Alignment
- [x] **Task 4.1**: Android Optimizations & Back Prevention (`PopScope`)
  - Replace global orientation lock in `main.dart` with phone-only portrait lock (allow tablet landscape).
  - Implement `PopScope` back handling on Documents Screen, Students Screen, and Archives Screen:
    - 1st back inside multi-select: deactivate multi-select. 2nd back: navigate to Dashboard.
    - 1st back inside folder: return to 'Student Folders' tab. 2nd back: navigate to Dashboard.
  - Stack action buttons vertically on Android (`Column` with full-width `ElevatedButton`).
  - Add `RefreshIndicator` pull-to-refresh on mobile lists.
- [x] **Task 4.2**: Windows Desktop Optimizations & Drag-and-Drop Fixes
  - Fix desktop drag-and-drop file upload in Add Student Modal and Edit Student Modal.
  - Add keyboard shortcuts (`Shortcuts` + `Actions` for `Ctrl+F`, `Escape`, etc.).
  - Add right-click context menus (`onSecondaryTapUp`).
  - Improve sidebar hover states and tooltip placements.
- [x] **Task 4.3**: Screen-Specific Feature Fixes (per Project TODOs)
  - **Documents Screen**: Remove timestamp from copied filename format; remove Excel-to-PDF feature.
  - **Reports Screen**: Fix card overflow on overall compliance, students with issues, and total missing documents cards; add clickable path links in success dialogs.
  - **Students Screen (OCR Validation)**: Reject non 7-12 grade levels; add manual validation step for year/grade/section using icon-only buttons (no container, background, or border).
- [x] **Task 4.4**: Accessibility & Visual Polish
  - Add `Semantics` labels to interactive elements and icons.
  - Replace color-only status indicators with text + icon badges.
  - Add shimmer skeleton loading states for cards and tables.

---

## Implementation Roadmap

### Phase 1: Foundation Fixes (1-2 weeks)
| # | Task | Priority | Impact |
|---|------|----------|--------|
| 1 | Extend `AppColors` with missing tokens | P1 | All screens |
| 2 | Create `AppBreakpoints` constants | P1 | All screens |
| 3 | Extend `AppSizes` with icon/elevation/animation tokens | P2 | All screens |
| 4 | Migrate 68 `withOpacity()` → `withValues(alpha:)` | P1 | All screens |
| 5 | Create `context.isDark` extension | P1 | All screens |
| 6 | Fix `capstone_members_screen.dart` dark mode | P0 | 1 screen |

### Phase 2: Shared Widget Extraction (2-3 weeks)
| # | Task | Priority | Impact |
|---|------|----------|--------|
| 7 | Extract `AppErrorState` shared widget | P1 | 5 screens |
| 8 | Extract `AppEmptyState` shared widget | P1 | 4 screens |
| 9 | Extract `showAppSearchDialog()` utility | P1 | 4 screens |
| 10 | Extract `FilterDropdownSection` widget | P1 | 3 screens |
| 11 | Complete SnackBar → Dialog migration (17 instances) | P1 | 5 screens |

### Phase 3: Screen Decomposition (3-4 weeks)
| # | Task | Priority | Impact |
|---|------|----------|--------|
| 12 | Decompose `documents_screen.dart` (3,251 lines) | P0 | Maintainability |
| 13 | Decompose `reports_screen.dart` (3,611 lines) | P0 | Maintainability |
| 14 | Decompose `students_screen.dart` (2,902 lines) | P0 | Maintainability |
| 15 | Decompose `archives_screen.dart` (2,449 lines) | P1 | Maintainability |
| 16 | Decompose `settings` screens (2,233 + 1,920 lines) | P1 | Maintainability |

### Phase 4: Platform-Specific UX (2-3 weeks)
| # | Task | Priority | Impact |
|---|------|----------|--------|
| 17 | Android: Implement `PopScope` back handling | P2 | Android UX |
| 18 | Android: Add `RefreshIndicator` pull-to-refresh | P2 | Android UX |
| 19 | Android: Unlock landscape on tablets | P0 | Tablet UX |
| 20 | Windows: Add keyboard shortcuts (`Ctrl+F`, `Escape`) | P1 | Desktop UX |
| 21 | Windows: Add right-click context menus | P2 | Desktop UX |
| 22 | Windows: Improve sidebar hover states | P1 | Desktop polish |

### Phase 5: UX & Polish (2-3 weeks)
| # | Task | Priority | Impact |
|---|------|----------|--------|
| 23 | Add shimmer/skeleton loading states | P1 | All screens |
| 24 | Add semantic labels for accessibility | P0 | Accessibility |
| 25 | Fix color-only status indicators | P1 | Accessibility |
| 26 | Add empty state CTAs | P2 | UX |
| 27 | Standardize card elevation/shadows | P2 | Visual consistency |
| 28 | Add micro-animations (`AnimatedSwitcher`) | P2 | Polish |
| 29 | Use `TextTheme` instead of inline font sizes | P2 | Consistency |
| 30 | Standardize icon style (outlined) | P3 | Visual consistency |

---

## Quick Wins (Can Be Done Immediately)
1. Fix `capstone_members_screen.dart` dark mode (~30 min)
2. Create `context.isDark` extension (~10 min)
3. Add `AppBreakpoints` constant class (~15 min)
4. Extend `AppSizes` with missing tokens (~20 min)
5. Complete SnackBar migration (17 instances, ~1 hour)
6. Add `Semantics` labels to all `IconButton` widgets (~2 hours)

---

## Summary Metrics

| Category | Issues Found | P0 | P1 | P2 | P3 |
|----------|-------------|----|----|----|----|
| Design System & Theming | 4 | 0 | 2 | 2 | 0 |
| Architecture & Code | 3 | 1 | 2 | 0 | 0 |
| Android-Specific | 5 | 1 | 1 | 2 | 1 |
| Windows Desktop | 4 | 0 | 1 | 2 | 1 |
| Responsive Design | 2 | 0 | 1 | 1 | 0 |
| UX & Interaction | 6 | 0 | 2 | 2 | 2 |
| Accessibility | 3 | 1 | 1 | 1 | 0 |
| Performance | 2 | 0 | 1 | 1 | 0 |
| Visual Polish | 3 | 0 | 0 | 2 | 1 |
| **Total** | **32** | **3** | **11** | **13** | **5** |
