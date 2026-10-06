# Reconcile reminders locally and serialize notification scheduling

Priority: P2. Code-confirmed integration gap and concurrency risk; not a
verified iOS 27 behavior change.

## Problem

`NotificationScheduler.rescheduleAll` has no callers. App startup only
requests authorization, so reminders imported via CloudKit are not reconciled
with this device's pending notifications. Scheduler methods suspend while
cancelling, checking budget, and adding requests. MainActor isolation alone
does not prevent operations from interleaving across those awaits.

## Acceptance criteria

- Reconcile enabled reminders after authorization and when relevant synced
  data changes or the app returns to the foreground.
- Serialize reconciliation and incremental updates without losing the latest
  edits or violating the shared pending-request budget.
- Snapshot values safely across asynchronous work.
- Test with a fake notification center: imported reminders, disabled/deleted
  reminders, permission denied/granted, concurrent edits, and budget limits.
- Verify actual scheduled requests and delivery on a supported Apple host.

Status: audited, not implemented.
Remote issue: not filed; API access is blocked.
