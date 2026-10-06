# Local reminder reconciliation

While the app is active, `ContentView` observes habits and reminders through
SwiftData queries. It reconciles notification requests after authorization,
foreground transitions, and changes including CloudKit imports, edits, archive,
disable, and deletion. Only alert, sound, and badge authorization is requested.

The scheduler captures immutable model snapshots before suspension and serializes
authorization, reconciliation, and cancellation through a FIFO transaction lock.
The shared limit is 60 pending requests, including unrelated requests that the
scheduler preserves. Existing reminder identifiers are updated with `add`, which
[replaces a request with the same identifier](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/add(_:withcompletionhandler:)).

Only obsolete or budget-excluded identifiers are removed. Apple's
[removal API executes asynchronously](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:))
and provides no completion callback. The adapter therefore queries pending
requests until the removed identifiers are absent, with a two-second readiness
deadline between queries. It does not assume that a fixed delay proves removal.
If readiness remains unconfirmed, scheduling stops and remembers those identifiers;
the next reconciliation must observe their absence before it can add requests.
It does not reissue an unconfirmed removal that could later delete a replacement.

Cancelled tasks stop before mutation when they acquire the lock, after readiness
or authorization checks, and before additions. Once removal has started, its
bounded readiness check finishes even if the caller is cancelled, so ownership
does not transfer while deletion is assumed complete. A timeout keeps the same
unconfirmed-identifier protection across transactions. Already submitted additions
may complete; subsequent reconciliation applies the current model snapshot.

Fake-center tests cover imports and deletions, disabled and archived reminders,
permission denial, the shared budget, suspended concurrent operations, snapshots,
addition failures, delayed removals, and cancelled queued tasks. System behavior
still needs simulator/device validation, especially permission changes in Settings
and reminders arriving through CloudKit. No critical-alert entitlement is added.
