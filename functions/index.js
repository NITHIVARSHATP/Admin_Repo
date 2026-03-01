const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

admin.initializeApp();

function getEscalationDuration(priority) {
  const normalized = String(priority || "").trim().toLowerCase();
  if (normalized === "high") {
    return 4 * 60 * 60 * 1000;
  }
  if (normalized === "medium") {
    return 15 * 60 * 60 * 1000;
  }
  return 24 * 60 * 60 * 1000;
}

function roleToLevel(role) {
  const normalized = normalizeRole(role);
  if (normalized === "aee") return 2;
  if (normalized === "ee") return 3;
  return 1;
}

function getNextRole(currentRole) {
  const normalized = normalizeRole(currentRole);
  if (normalized === "ae") {
    return "aee";
  }
  if (normalized === "aee") {
    return "ee";
  }
  return "ee";
}

function normalizeRole(role) {
  const value = String(role || "").trim().toLowerCase();
  if (value === "aee") return "aee";
  if (value === "ee") return "ee";
  return "ae";
}

function normalizeStatus(status) {
  return String(status || "")
    .trim()
    .toLowerCase()
    .replace(/-/g, "_")
    .replace(/\s+/g, "_");
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function ownerRoleToDisplay(role) {
  if (role === "aee") return "AEE";
  if (role === "ee") return "EE";
  return "AE";
}

exports.processComplaintEscalations = onSchedule("every 30 minutes", async () => {
  const db = admin.firestore();
  const now = new Date();

  const snapshot = await db.collection("complaints").get();
  let escalatedCount = 0;

  for (const doc of snapshot.docs) {
    const escalated = await db.runTransaction(async (transaction) => {
      const latestSnapshot = await transaction.get(doc.ref);
      if (!latestSnapshot.exists) {
        return false;
      }

      const data = latestSnapshot.data() || {};
      const status = normalizeStatus(data.status);
      if (status === "resolved") {
        return false;
      }

      const currentRole = normalizeRole(data.assignedRole || data.currentOwnerRole || "ae");
      const currentLevel = Number(data.escalationLevel || roleToLevel(currentRole));
      if (currentRole === "ee" || currentLevel >= 3) {
        return false;
      }

      const assignedAt = toDate(data.assignedAt) || toDate(data.createdAt) || toDate(data.lastUpdated);
      if (!assignedAt) {
        transaction.update(doc.ref, {
          assignedAt: admin.firestore.FieldValue.serverTimestamp(),
          escalationLevel: roleToLevel(currentRole),
        });
        return false;
      }

      const existingSlaDeadline = toDate(data.slaDeadline);
      const escalationDurationMs = getEscalationDuration(data.priority);
      const computedSlaDeadline = new Date(assignedAt.getTime() + escalationDurationMs);
      const effectiveSlaDeadline = existingSlaDeadline || computedSlaDeadline;

      if (!existingSlaDeadline) {
        transaction.update(doc.ref, {
          slaDeadline: admin.firestore.Timestamp.fromDate(computedSlaDeadline),
        });
      }

      if (now <= effectiveSlaDeadline) {
        return false;
      }

      const nextRole = getNextRole(currentRole);
      if (nextRole === currentRole) {
        return false;
      }

      const nextLevel = roleToLevel(nextRole);
      const newAssignedAt = admin.firestore.Timestamp.now();
      const newSlaDeadline = admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() + getEscalationDuration(data.priority)),
      );

      transaction.update(doc.ref, {
        assignedRole: nextRole,
        currentOwnerRole: ownerRoleToDisplay(nextRole),
        assignedAt: newAssignedAt,
        slaDeadline: newSlaDeadline,
        escalationLevel: nextLevel,
        isEscalated: true,
        lastEscalatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        escalationHistory: admin.firestore.FieldValue.arrayUnion({
          fromRole: currentRole,
          toRole: nextRole,
          reason: "SLA time exceeded",
          timestamp: admin.firestore.Timestamp.now(),
        }),
      });
      return true;
    });

    if (escalated) {
      escalatedCount += 1;
    }
  }

  logger.info("Escalation scan completed", {
    scannedCount: snapshot.size,
    escalatedCount,
  });
});

exports.getEscalationDuration = getEscalationDuration;
exports.getNextRole = getNextRole;

exports.normalizeComplaintEscalationFields = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const db = admin.firestore();
  const userDoc = await db.collection("users").doc(request.auth.uid).get();
  const role = String(userDoc.data()?.role || "").trim().toLowerCase();
  if (!["ae", "aee", "ee"].includes(role)) {
    throw new HttpsError("permission-denied", "Admin role required.");
  }

  const snapshot = await db.collection("complaints").get();
  let batch = db.batch();
  let writeCount = 0;
  let updatedCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const assignedRoleRaw = String(data.assignedRole || "").trim();
    const currentOwnerRoleRaw = String(data.currentOwnerRole || "AE").trim();

    const ownerRole = normalizeRole(
      ["ae", "aee", "ee"].includes(assignedRoleRaw.toLowerCase())
        ? assignedRoleRaw
        : currentOwnerRoleRaw,
    );

    const assignedStaffRole =
      String(data.assignedStaffRole || "").trim() ||
      (["ae", "aee", "ee"].includes(assignedRoleRaw.toLowerCase())
        ? "Pending"
        : assignedRoleRaw || "Pending");

    const assignedAt =
      data.assignedAt || data.createdAt || data.lastUpdated || admin.firestore.FieldValue.serverTimestamp();

    const assignedAtDate =
      toDate(data.assignedAt) || toDate(data.createdAt) || toDate(data.lastUpdated) || new Date();
    const slaDeadline = data.slaDeadline || admin.firestore.Timestamp.fromDate(
      new Date(assignedAtDate.getTime() + getEscalationDuration(data.priority)),
    );
    const escalationLevel = Number(data.escalationLevel || roleToLevel(ownerRole));
    const history = Array.isArray(data.escalationHistory) ? data.escalationHistory : [];
    const isEscalated =
      data.isEscalated === true || (history.length > 0 && data.isEscalated !== false);
    const lastEscalatedAt = data.lastEscalatedAt || null;

    const updateData = {
      assignedRole: ownerRole,
      currentOwnerRole: ownerRoleToDisplay(ownerRole),
      assignedStaffRole,
      assignedAt,
      slaDeadline,
      escalationLevel,
      isEscalated,
      lastEscalatedAt,
      escalationHistory: history,
    };

    const hasChanges =
      data.assignedRole !== updateData.assignedRole ||
      data.currentOwnerRole !== updateData.currentOwnerRole ||
      data.assignedStaffRole !== updateData.assignedStaffRole ||
      data.assignedAt == null ||
      data.slaDeadline == null ||
      data.escalationLevel == null ||
      data.isEscalated == null ||
      data.lastEscalatedAt === undefined ||
      !Array.isArray(data.escalationHistory);

    if (!hasChanges) {
      continue;
    }

    batch.update(doc.ref, updateData);
    writeCount += 1;
    updatedCount += 1;

    if (writeCount === 400) {
      await batch.commit();
      batch = db.batch();
      writeCount = 0;
    }
  }

  if (writeCount > 0) {
    await batch.commit();
  }

  logger.info("Complaint escalation field normalization completed", {
    scannedCount: snapshot.size,
    updatedCount,
    triggeredByUid: request.auth.uid,
  });

  return {
    scannedCount: snapshot.size,
    updatedCount,
  };
});
