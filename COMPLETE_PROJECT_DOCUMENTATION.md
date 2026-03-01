# Civic Admin App — Complete Project Documentation

## 1. Project Summary

Civic Admin App is a Flutter + Firebase complaint management system for municipal operations with role-based administration and escalation.

### Primary roles
- **AE (Assistant Engineer)** — Level 1 operational owner
- **AEE (Assistant Executive Engineer)** — Level 2 supervisory owner
- **EE (Executive Engineer)** — Level 3 final authority

### Escalation chain
`AE (L1) -> AEE (L2) -> EE (L3)`

### Core capabilities
- Role-based login and dashboard routing
- Complaint lifecycle and role-specific action controls
- SLA-based automatic escalation with escalation history
- Heatmap visualization by role and priority
- Firebase-backed real-time queue updates

---

## 2. Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend/Data:** Firebase Firestore + Firebase Authentication
- **Optional backend utilities:** Firebase Cloud Functions (partially present)
- **Map/Heatmap:** `flutter_map`, `flutter_map_heatmap`, `latlong2`

---

## 3. Workspace Structure (Important Files)

### Application entry
- `lib/main.dart`

### Role dashboards
- `lib/ae_dashboard/ae_dashboard_screen.dart`
- `lib/aee_dashboard/aee_home.dart`
- `lib/ee_dashboard/ee_home.dart`

### Role action screens
- `lib/ae_dashboard/complaint_details_screen.dart`
- `lib/aee_dashboard/intervention.dart`
- `lib/ee_dashboard/approval_hub.dart`

### Domain/services
- `lib/models/complaint_model.dart`
- `lib/services/complaint_service.dart`
- `lib/services/heatmap_service.dart`

### Shared widgets
- `lib/widgets/status_badge.dart`
- `lib/widgets/escalation_timer.dart`
- `lib/widgets/complaint_heatmap_section.dart`

### Firebase and rules
- `firebase.json`
- `firestore.rules`
- `functions/index.js` (optional/limited by plan)

---

## 4. Authentication and Role Routing

Users sign in with Firebase Auth. Role is read from Firestore user profile and routes to:
- AE dashboard
- AEE dashboard
- EE dashboard

Role names are normalized and enforced for queue filtering and action ownership checks.

---

## 5. Complaint Data Model (Operational Fields)

Main complaint fields used by workflow/escalation:
- `complaintId`, `title`, `description`, `category`, `priority`, `status`
- `assignedRole` (`ae | aee | ee`)
- `currentOwnerRole` (`AE | AEE | EE`)
- `assignedAt`, `slaDeadline`, `lastUpdated`
- `escalationLevel` (`1 | 2 | 3`)
- `isEscalated`, `lastEscalatedAt`
- `escalationHistory[]`
- `assignedResources`, `aeeNotes`, `resolutionNote`, `proofImage`
- `latitude`, `longitude`, `ward`

Escalation history item format:
```json
{
  "fromRole": "aee",
  "toRole": "ee",
  "reason": "SLA exceeded while unresolved",
  "timestamp": "Timestamp"
}
```

---

## 6. Workflow by Role

## 6.1 AE Workflow (Level 1)

AE handles first-level operational processing.

Typical status progression:
`classified -> under_review -> in_progress -> resolved`

AE can:
- Review/classify complaints
- Assign field staff
- Move work to in-progress
- Submit resolution
- Reopen resolved complaints (resets to AE path)

Queue rule:
- AE dashboard shows only `assignedRole == ae`

## 6.2 AEE Workflow (Level 2 Supervisory)

AEE is supervisory (not field execution).

AEE can:
- Supervise escalated complaints
- Assign/reassign resources
- Adjust deadline
- Add notes/comments
- Update workflow status
- Resolve directly when appropriate

AEE allowed statuses:
- `under_review`
- `in_progress`
- `resolved`

AEE queue rule:
- AEE dashboard shows only `assignedRole == aee`

Reliability controls:
- Transaction-safe updates
- Ownership validation inside transaction
- Read-only state if ownership moved away from AEE

## 6.3 EE Workflow (Level 3 Final Authority)

EE performs executive decision/final closure.

Typical path:
`escalated -> approved -> resolved`

EE can:
- Approve executive actions with budget
- Mark complaint resolved
- Reopen to AE (controlled rollback)

EE queue rule:
- EE dashboard shows only `assignedRole == ee`

Reliability controls:
- Transaction-safe updates
- Ownership validation inside transaction
- Read-only state if ownership changed from EE

---

## 7. SLA and Escalation Logic

Implemented in `lib/services/complaint_service.dart`.

### SLA durations
- **High:** 4 hours
- **Medium:** 15 hours
- **Low:** 24 hours

### Escalation trigger
Escalation happens when complaint is unresolved and:
- `now > slaDeadline`
- current level is below 3
- role/status eligibility rules are satisfied

### Auto-escalation eligibility (current behavior)
- Never escalate `resolved` or `approved`
- AEE escalation eligibility is constrained to active actionable states (`pending` or `in_progress`)
- Escalation stops at EE

### On escalation update
- Role shifts to next owner (`ae->aee`, `aee->ee`)
- `assignedAt` reset to escalation time
- `slaDeadline` recalculated from new assignment time
- `escalationLevel` updated
- `isEscalated = true`
- `lastEscalatedAt` updated
- History appended with role transition event

---

## 8. Heatmap Module

### Files
- `lib/widgets/complaint_heatmap_section.dart`
- `lib/services/heatmap_service.dart`

### Behavior
- Embedded in AE/AEE/EE dashboards
- Role-filtered complaint coordinates
- Priority filtering (`All/High/Medium/Low`)
- Intensity bucket logic + visual legend

### Web runtime note
On Chrome, map tile fetches may show non-fatal aborted request logs from OSM tiles. App continues to function.

---

## 9. Firestore Rules and Security

Rules are in `firestore.rules`.

Current pattern supports role-based reads/writes for complaint operations. For production hardening, tighten per-role update scopes and explicit operation guards.

---

## 10. Cloud Functions Status

Functions exist in `functions/index.js` (including migration/escalation helpers), but scheduled/server-side escalation depends on deployment plan.

Current active mode is **client-triggered escalation checks** from dashboard init, suitable for zero-cost operation.

---

## 11. Build, Run, and Test

### Install dependencies
```bash
flutter pub get
```

### Run web (Chrome)
```bash
flutter run -d chrome
```

### Analyze
```bash
flutter analyze
```

### Tests
```bash
flutter test
```

### Build release APK
```bash
flutter build apk --release
```

Release APK output:
- `build/app/outputs/flutter-apk/app-release.apk`

---

## 12. Current Validation Status (latest session)

Verified successfully in recent run:
- Analyzer clean for AEE and EE modified workflow files
- Flutter tests passing
- Release APK generated successfully

---

## 13. Known Operational Notes

- Chrome map tile abort logs are mostly network/provider cancellations and generally non-blocking.
- A legacy/unused escalation service file may still exist (`lib/services/escalation_service.dart`) but active escalation path is through `complaint_service.dart`.
- Optional migration button in AE dashboard calls Cloud Function and may fail if callable function is not deployed.

---

## 14. Recommended Next Improvements

- Add role-scoped Firestore rule hardening per action transition.
- Add integration tests for escalation transitions (`ae->aee->ee`).
- Add audit dashboard for SLA breaches and escalation counts.
- Optionally integrate `flutter_map_cancellable_tile_provider` for smoother web tile handling.

---

## 15. Quick Functional Checklist

- [ ] AE queue only shows AE-owned complaints
- [ ] AEE queue only shows AEE-owned complaints
- [ ] EE queue only shows EE-owned complaints
- [ ] AEE/EE screens become read-only when ownership changes
- [ ] SLA deadlines are set and respected
- [ ] Escalation history entries append correctly
- [ ] Reopen resets ownership/path appropriately
- [ ] Heatmap renders role-matched coordinates
