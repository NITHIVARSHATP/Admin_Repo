# Civic Admin App - Complete Admin Documentation

## 1) Overview

This document describes the **admin-side architecture and workflows** for the Civic Admin App.

The admin system supports role-based operations for:
- AE (Assistant Engineer)
- AEE (Assistant Executive Engineer)
- EE (Executive Engineer)

Core admin capabilities:
- Role-based dashboard queues
- Complaint detail workflow actions
- SLA-based chained escalation (AE → AEE → EE)
- Complaint heatmap by role
- Escalation history tracking
- Admin utility migration trigger

---

## 2) Role Hierarchy and Ownership

### Role progression
- `ae` → `aee` → `ee`
- Escalation stops at `ee`

### Ownership field of record
- Complaint ownership is determined by `assignedRole` (lowercase: `ae`, `aee`, `ee`)
- `currentOwnerRole` is maintained for compatibility/display (`AE`, `AEE`, `EE`)

### Queue visibility
- AE dashboard shows only complaints where `assignedRole == ae`
- AEE dashboard shows only complaints where `assignedRole == aee`
- EE dashboard shows only complaints where `assignedRole == ee`

---

## 3) Admin Dashboards

### AE Dashboard
- File: [lib/ae_dashboard/ae_dashboard_screen.dart](lib/ae_dashboard/ae_dashboard_screen.dart)
- Features:
  - Complaint queue (AE-owned only)
  - Complaint heatmap section (role `ae`)
  - Admin utility button: **Run Escalation Migration**

### AEE Dashboard
- File: [lib/aee_dashboard/aee_home.dart](lib/aee_dashboard/aee_home.dart)
- Features:
  - Escalated queue (AEE-owned only)
  - Complaint heatmap section (role `aee`)

### EE Dashboard
- File: [lib/ee_dashboard/ee_home.dart](lib/ee_dashboard/ee_home.dart)
- Features:
  - Escalated queue (EE-owned only)
  - Complaint heatmap section (role `ee`)

---

## 4) Complaint Detail Workflow (AE Screen)

- File: [lib/ae_dashboard/complaint_details_screen.dart](lib/ae_dashboard/complaint_details_screen.dart)

### Workflow actions shown only when valid
Action buttons are guarded by:
1. complaint ownership (`assignedRole == ae`)
2. valid status transitions

### Status-based actions
- `classified` / `reopened` → Mark Under Review
- `classified` / `under_review` → Assign Field Staff
- `under_review` → Mark In Progress
- `in_progress` → Resolution Entry
- `resolved` → Reopen / Delete

### Workflow panel shows
- Current assigned role
- Assigned time
- Time remaining before escalation
- Next escalation target
- Escalation history timeline

### Overflow fix
Workflow card content is scrollable inside fixed panel height to avoid bottom overflow.

---

## 5) SLA-Based Escalation (Zero-Cost Mode)

## Current operating mode
Escalation runs **inside Flutter client** (no scheduler required), compatible with Firebase Spark plan.

- Service file: [lib/services/complaint_service.dart](lib/services/complaint_service.dart)
- Entry point: `checkAndProcessEscalations()`

### Trigger behavior
Runs once when each dashboard loads:
- AE dashboard init
- AEE dashboard init
- EE dashboard init

### SLA durations
- High: 4 hours
- Medium: 15 hours
- Low: 24 hours

### Escalation conditions
Escalation occurs only if all are true:
- status is not resolved
- current time > `slaDeadline`
- role is not EE / level < 3

### Escalation update payload
When escalation happens:
- `assignedRole` → next role
- `currentOwnerRole` → display role (`AE`/`AEE`/`EE`)
- `assignedAt` → now
- `slaDeadline` → recomputed (`assignedAt + duration`)
- `escalationLevel` → incremented by role mapping
- `isEscalated` → true
- `lastEscalatedAt` → now
- `escalationHistory[]` → append transition event

### Safety guarantees
- Uses Firestore transaction per complaint
- No downgrade path
- Stops at EE
- Avoids duplicate updates per run cycle

---

## 6) Escalation State Model

### Complaint document fields used by escalation
- `assignedRole`: `ae | aee | ee`
- `currentOwnerRole`: `AE | AEE | EE`
- `assignedAt`: Timestamp
- `slaDeadline`: Timestamp
- `priority`: `High | Medium | Low`
- `status`: workflow status string
- `escalationLevel`: `1 | 2 | 3`
- `isEscalated`: boolean
- `lastEscalatedAt`: Timestamp | null
- `escalationHistory`: array

### Escalation level mapping
- AE = 1
- AEE = 2
- EE = 3

### History entry format
```json
{
  "fromRole": "ae",
  "toRole": "aee",
  "reason": "SLA time exceeded",
  "timestamp": "server timestamp"
}
```

---

## 7) Heatmap System

### Files
- Data service: [lib/services/heatmap_service.dart](lib/services/heatmap_service.dart)
- Reusable widget: [lib/widgets/complaint_heatmap_section.dart](lib/widgets/complaint_heatmap_section.dart)

### Placement
Embedded in all dashboards:
- AE dashboard
- AEE dashboard
- EE dashboard

### Data logic
- Reads complaint coordinates from Firestore
- Role filtering is resilient:
  - prefers `assignedRole`
  - falls back to `currentOwnerRole`
- Optional priority filter (`All`, `High`, `Medium`, `Low`)

### Visual logic
- Complaint points are bucketed geographically
- Intensity increases by:
  - complaint count bucket
  - priority weighting

### Legend
- Red: high intensity
- Orange/Yellow: medium
- Green: low

---

## 8) Migration Utility (Admin)

### Button
- Label: `Run Escalation Migration`
- Location: AE dashboard (admin utility area)
- Visible only for roles: `ae`, `aee`, `ee`

### Behavior
- Calls callable function `normalizeComplaintEscalationFields`
- Shows loading state and disables repeat clicks
- Snackbar result:
  - scanned count
  - updated count

### Important note
If Cloud Functions are not deployed (Spark-only/no Blaze), this call will fail and show an error snackbar.

---

## 9) Cloud Functions Status

Functions code exists in [functions/index.js](functions/index.js):
- `processComplaintEscalations` (scheduled)
- `normalizeComplaintEscalationFields` (callable)

Because project is running Spark/no-Blaze deployment path, scheduled backend is not active. Client-side escalation is the active production path in zero-cost mode.

---

## 10) Firestore Rules Summary

Rules file: [firestore.rules](firestore.rules)

Current behavior:
- Signed-in users can read complaints
- Admin roles can create/update complaints
- EE role can delete complaints

For strict production hardening, consider narrowing update/delete scopes per role and operation.

---

## 11) End-to-End Workflow Example

High-priority complaint:
1. Created and assigned to AE (`assignedRole = ae`, `escalationLevel = 1`)
2. SLA deadline set to +4h
3. If unresolved after SLA, next dashboard load triggers escalation to AEE
4. Recomputes SLA +4h from new `assignedAt`
5. If still unresolved after next SLA, escalates to EE (`escalationLevel = 3`)
6. Stops further escalation at EE

---

## 12) Validation Checklist

Use this checklist after release:
- Dashboards show only role-owned complaints
- AE complaint detail disables AE actions when not AE-owned
- SLA fields present in complaint docs
- Escalation level increments correctly (1→2→3)
- Escalation history entries append correctly
- Heatmap appears for each role when role-matching geo complaints exist
- No overflow issues in workflow panel

---

## 13) Troubleshooting

### Heatmap says “No complaint coordinates available for this role”
Check:
- complaints have numeric `latitude` and `longitude`
- complaints are role-matched (`assignedRole` or `currentOwnerRole`)
- priority filter is not excluding all entries

### Migration button shows `internal`
Cause:
- callable function not deployed

In Spark mode:
- keep client-side escalation as primary
- optionally hide/remove migration button if functions are intentionally disabled

### Wrong queue after escalation
Check complaint fields:
- `assignedRole`
- `currentOwnerRole`
- `escalationLevel`

---

## 14) Key Files Index

- [lib/services/complaint_service.dart](lib/services/complaint_service.dart)
- [lib/models/complaint_model.dart](lib/models/complaint_model.dart)
- [lib/widgets/complaint_heatmap_section.dart](lib/widgets/complaint_heatmap_section.dart)
- [lib/services/heatmap_service.dart](lib/services/heatmap_service.dart)
- [lib/ae_dashboard/ae_dashboard_screen.dart](lib/ae_dashboard/ae_dashboard_screen.dart)
- [lib/aee_dashboard/aee_home.dart](lib/aee_dashboard/aee_home.dart)
- [lib/ee_dashboard/ee_home.dart](lib/ee_dashboard/ee_home.dart)
- [lib/ae_dashboard/complaint_details_screen.dart](lib/ae_dashboard/complaint_details_screen.dart)
- [firestore.rules](firestore.rules)
- [functions/index.js](functions/index.js)

---

## 15) Recommended Next Improvements

- Add strict role-based write rules per workflow operation in Firestore rules
- Add explicit UI badges for `escalationLevel` and `SLA breached`
- Add lightweight telemetry counters for escalations per role
- Add admin toggle to hide migration button in Spark deployments
