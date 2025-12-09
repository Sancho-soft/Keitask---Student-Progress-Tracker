# Keitask - Student Progress Tracker

Keitask is a comprehensive student progress tracking and task management application built with **Flutter** and **Firebase**.

## 🚀 Features

### for Professors
*   **Dashboard**: Overview of active tasks and grading status.
*   **Task Creation**: Create tasks with titles, descriptions, deadlines, and attachments.
*   **Grading**: Review student submissions, assign grades, and provide feedback.
*   **User Management**: (Admin only) Approve or ban users.

### for Students
*   **Dashboard**: View assigned, pending, and completed tasks.
*   **Task Submission**: Submit work (images, PDFs) directly through the app.
*   **Progress Tracking**: Visualize completion rates and leaderboard standing.
*   **Leaderboard**: Compete for top spots based on task completion points.

---

## 🛠️ v1.1.6 Beta Release Notes - "The Refactor Update"

### Additional Optimization
*   **Modular File Structure:** Complete migration to role-based directories (`lib/screens/admin/`, `professor/`, `student/`).
*   **Decoupled Dashboards:** Separated `UserDashboard` into specialized `ProfessorDashboard` and `StudentDashboard`.
*   **Stability:** Fixed context-related crashes in the grading dialog.
*   **Optimization:** 100% clean code analysis score.

---

## 🔧 Setup & Development

### Prerequisites
*   Flutter SDK
*   Firebase Project (Auth, Firestore, Storage)

### Installation
1.  Clone the repository:
    ```bash
    git clone https://github.com/Sancho-soft/Student-Progress-Tracker.git
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the app:
    ```bash
    flutter run
    ```

### Notifications
*   Uses `flutter_local_notifications` and FCM.
*   Ensure `google-services.json` is present in `android/app/`.

---

**Developed by Sancho-soft**
