const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Trigger: when a task document is updated, set completedAt when status becomes 'completed'
exports.onTaskStatusChange = functions.firestore
  .document('tasks/{taskId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const prevStatus = (before.status || '').toString().toLowerCase();
    const newStatus = (after.status || '').toString().toLowerCase();
    const docRef = change.after.ref;

    const updates = {};

    // If the task was just completed, set server timestamp for completedAt if missing
    if (newStatus === 'completed' && !after.completedAt) {
      updates.completedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    // If the task moved to approved or completed, ensure rejectionReason is removed
    if ((newStatus === 'approved' || newStatus === 'completed') && after.rejectionReason) {
      updates.rejectionReason = admin.firestore.FieldValue.delete();
    }

    if (Object.keys(updates).length > 0) {
      try {
        await docRef.update(updates);
        console.log(`Task ${context.params.taskId} updated by function with:`, updates);
      } catch (err) {
        console.error('Failed to update task from function', err);
      }
    }

    return null;
  });
