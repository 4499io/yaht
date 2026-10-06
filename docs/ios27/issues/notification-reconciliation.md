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

Implementation branch: `fix/reconcile-reminders`; implementation prepared locally.
Remote issue: https://github.com/4499io/yaht/issues/3

## Implementation progress

Prepared on `fix/reconcile-reminders` (`b5a86c9`, `98a109a`). Lifecycle/query
reconciliation uses immutable snapshots and serialized transactions. It removes
obsolete reminders, retains unrelated requests, and enforces a shared 60-request
budget. Stable identifiers update directly; removals require observed completion
before reuse. Cancelled queued tasks stop before mutation. Removal timeouts defer
additions until a later foreground/data event.

Thirteen new fake-center regression cases are added but unrun without Xcode.
Independent source review found no remaining blocker; actual center ordering,
CloudKit changes, and device delivery still require Apple-platform validation.
The combined worktree is `integration/ios27-upgrade`. Branch publication remains
blocked by integration write/fork permissions. Issue remains open.
