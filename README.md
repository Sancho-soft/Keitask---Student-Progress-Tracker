🛠️ Developer Changelog - Keitask App Update
🚀 New Features & Enhancements
1. Professor & Admin Dashboard
Role-Based Navigation:
Admins: Access to "Manage Users" (Professor Approval) and full "Leaderboard" control.
Professors: New "Task Statistics" dashboard instead of Leaderboard. "New Task" shortcut added to the navigation bar.
Students: Standard view with Leaderboard.
Task Statistics (New Screen):
Implemented TaskStatisticsScreen using fl_chart to show weekly task completion trends.
Displays a bar chart of completed tasks for the current week.
Shows summary metrics: Total Tasks, Completed, Completion Rate.
2. User Management (Admin)
Professor Approval Flow:
Admins can now approve/unapprove professors from the UsersScreen.
Distinct UI cards for Professors vs. Students.
Ban Functionality:
Admins can "Ban" students, preventing them from logging in.
AuthService updated to check isBanned status on load.
3. Task Management
Create Task UI Overhaul:
Assignment Toggle: Added a clear "Single" vs "Multiple" toggle for assigning members.
Dynamic UI: Shows a Dropdown for single assignment and Filter Chips for multiple assignment.
Date/Time Pickers: Improved UI for selecting due dates and times.
Tasks Screen (Daily View):
Dynamic Date Header: AppBar title now updates to show the Month/Year of the currently visible dates (e.g., "November 2025").
Infinite Date Scroll: Replaced fixed date bar with an infinite, smooth-scrolling horizontal date selector.
UI Polish: "Capsule" style date cards, improved task card aesthetics with shadows and rounded corners.
Overflow Fixes: Increased height of date selector to prevent bottom overflow errors.
4. Leaderboard
Visual Upgrade:
Top 3 Podium: distinct styling for 1st (Gold), 2nd (Silver), and 3rd (Bronze) with crown icons and ring borders.
List View: Cleaned up list items with rank numbers (#4, #5...), user avatars, and points display.
Overflow Fixes: Handled long names and small screens to prevent layout breaks.
Logic:
Professors and Admins are now correctly excluded from the leaderboard rankings.
5. Authentication & Profile
Forgot Password: Implemented ForgotPasswordScreen with Firebase password reset email trigger.
Phone Number: Added phone number field to User model and Profile screen (editable).
Rank Display: Added a "Rank" badge to the Profile screen.
🐛 Bug Fixes & Refactoring
Lint Errors: Resolved multiple lint errors (null checks, unused imports, missing parameters).
Navigation: Fixed back button logic (showBackButton) across multiple screens (UsersScreen, LeaderboardScreen, TaskStatisticsScreen) to ensure correct navigation behavior within the Dashboard.
Data Models: Updated User and Task models to support new fields (phoneNumber, isBanned, completionStatus per user).
Performance: Optimized TasksScreen to listen to scroll events efficiently for the dynamic date header.
📝 Codebase Health
Modularization: Created separate service methods for banning users and updating profiles.
Clean Code: Refactored large build methods into smaller widgets (e.g., _buildTopUser, _buildTaskCard).
