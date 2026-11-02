# App Review response — Guidelines 4.3 and 4.2.6

STATUS: DRAFT. Do not submit until the bracketed ownership, provenance, and shared-component answers have been completed and verified by the developer.

Verified on 21 October 2026: App Store version 1.0 is REJECTED and is associated with build 8. Build 10 is available in internal TestFlight. Uploading build 10 did not replace the build attached to the rejected version. The response below distinguishes these builds.

---

Hello App Review Team,

Thank you for outlining your concerns. We are responding to your questions before making any new submission, as requested. Below we explain the application's intended use, the distinction from our other products, our beta testing, and its technical and ownership background.

1. What the app does and the primary problem it solves

Namaz Grubum provides shared prayer-participation workflows for people who want to support one another in maintaining their daily prayers. The problem it addresses is coordinating actual participation within a group: who has joined, who has acknowledged waking for the morning prayer, who has recorded completion, and who may benefit from a reminder.

A user creates or joins a group. A group can use direct check-ins or a photo-based workflow and can track selected prayers. Group owners and administrators manage membership and admission requests. During the applicable prayer period, members record actions such as “Kalktım” (I am awake) and “Kıldım” (I have prayed). Other members can view the group's participation state and send a wake-up reminder. Missed-prayer completion is recorded separately from an on-time check-in. Group-level 7-day and 30-day participation views provide continuity over time.

In photo-enabled groups, completing the photo flow opens the camera. Uploaded images are restricted to active group members and normally expire after 12 hours. Membership checks, check-in timing, photo access, and moderation operations are enforced by backend logic, rather than by a cosmetic interface over static content.

2. Intended audience

The primary intended audience is Turkish-speaking Muslims who already understand how to pray and want voluntary mutual support in maintaining a routine, particularly for the early-morning prayer. Examples include friends, family members, and community members who choose to participate in a group together. Group organizers also need an interface for reviewing join requests, managing membership, viewing participation, and sending reminders.

This audience's immediate task is group coordination and follow-through. Prayer times and individual reminders support that task; the core interaction is the shared membership and participation workflow.

3. Need addressed and substantive differentiation

Displaying prayer times tells a person when a prayer begins, but does not by itself tell a participating group whether its members have acknowledged waking or recorded completion. A general messaging thread can coordinate reminders, but requires members to manually interpret messages and maintain the participation record themselves.

Namaz Grubum combines prayer-period-aware actions with structured group membership, live participation states, member wake-up reminders, admission handling, optional restricted-access camera submissions, and group progress history. These components operate on the same group and prayer records. This is the specific product experience we ask you to evaluate.

We are not claiming that no other prayer application offers social features. Our differentiation is this integrated group workflow, which can be demonstrated directly in the app, rather than the presence of a prayer-time screen alone.

4. Beta testing and feedback applied

We used internal TestFlight builds and reviewed screenshot feedback submitted from physical iPhones. App Store Connect currently contains 17 screenshot-feedback submissions dated 10 September through 2 October 2026, covering builds 3, 4, 8, and 9. These are feedback submissions, not a claim of 17 independent testers. Development validation also included automated Flutter tests and backend integration scenarios using test accounts; the test accounts are not counted as human beta testers.

Examples recorded in our beta issue reports include:

- Feedback that onboarding appeared repeatedly after relaunch: the completion state was persisted before permission-related operations.
- Feedback about a pending join request appearing available again: the request button was changed to an explicit pending state; later work also restored the pending state from the backend when reopening the group.
- Feedback that a group title was broken on a narrow display: the title and role badge were separated, with line limits and overflow handling.
- Feedback that a join action could remain in a loading state: the action received a bounded timeout and explicit success, pending, and failure states.
- Feedback that prayers outside their valid period should not be confirmed normally: later builds added disabled future-prayer actions and a separate missed-prayer completion action.
- Feedback requesting an administrator notification for new join requests: later backend work added the notification and prevented duplicate sends for repeated requests.

For clarity, the rejected App Store version is currently associated with build 8. Some later improvements were delivered in builds 9 and 10 and should not be assumed to be present in build 8. The most recent build 9 report concerned slow startup; build 10 renders the initial Flutter screen before service initialization. Build 10 passed static analysis and 31 automated tests and is available in internal TestFlight. We have not resubmitted it in response to this rejection.

We can provide the dated feedback and a demonstration of the relevant flows for the exact build you wish to evaluate.

5. Standalone product or part of a suite

[DEVELOPER TO CONFIRM: Namaz Grubum is intended as a standalone product, rather than a branded variant or a member of a coordinated suite. Explain any actual product-suite relationship if one exists.]

The most relevant comparison within our account is “Kolay Namaz İle Namaza Başla” (App ID 6806850484). Its current listing describes individual prayer learning and habit formation: a personal starting plan, instructional guides, individual progress, Qibla, and optional one-to-one guidance. Namaz Grubum focuses on multi-user membership, shared prayer participation, admission requests, group reminders, and optional group photo submissions. There is overlap in prayer times, reminders, and prayer tracking, and we acknowledge that overlap rather than presenting the products as entirely unrelated.

Other apps listed under our account are Libhane: Kitap Takip; Motivational Alarm Clock; İstanbul Gezi Rehberi: Rota; Matcha 21 Day Challenge; Takı Takip: Düğün Nişan Sünnet; Whatswho: AI Chat Analyzer; and Fiş Takip: Market Fişi Tarama. Their named subject areas concern books, goal-based alarms, travel, a matcha ritual, gift tracking, chat analysis, and receipts respectively. Motivational Alarm Clock has reminder/wake-up overlap, and Matcha has habit-tracking overlap; their published workflows do not describe Namaz Grubum's prayer-group membership and shared participation system.

[DEVELOPER TO COMPLETE: Confirm these descriptions against the actual products, identify any suite relationship, and disclose any relevant overlapping functionality beyond the listing information.]

6. Could it be delivered within another app on the account?

Technically, a group-coordination system could be built as an expansion to another application, especially Kolay Namaz. The question is therefore the intended product boundary, not technical impossibility.

[DEVELOPER TO CONFIRM OR REPLACE: We separated the products because Kolay Namaz's personal learning and private individual records serve a different immediate purpose from an account-based, multi-user group service. Namaz Grubum's group discovery, membership approval, member-visible participation, reminders between members, optional photos, and moderation form its primary experience rather than an optional content pack. Users joining such a group need that complete service without adopting a prayer-learning program. This is our reason for offering it separately.]

7. Significant shared code, frameworks, or assets with other apps on the account

[DEVELOPER MUST COMPLETE: Identify each app and every significant shared first-party component or asset, including reused alarm/prayer calculation wrappers, design components, themes, branding, backend modules, and content. Explain the role of each component. Do not answer “none” without checking the other repositories.]

The inspected Namaz Grubum project uses Flutter/Dart, Firebase, Riverpod, GoRouter, the Adhan prayer-calculation package, and standard camera, location, notification, and sharing packages. Their presence is ordinary third-party dependency reuse; it does not establish whether any first-party implementation is shared with another app. Namaz Grubum's inspected product-specific modules include group membership, prayer-period check-ins, restricted photo access, group reminders, and moderation.

8. Shared codebase, SDK, or content library with third-party apps

The standard third-party packages include Flutter, Firebase, Riverpod, GoRouter, adhan_dart, and the camera, location, local-notification, and sharing packages declared in our dependency manifest. The Adhan package provides prayer-time calculations; the Namaz Grubum-specific group and participation workflows are implemented around those calculations. Firebase supplies infrastructure for authentication, data, storage, messaging, and callable backend operations.

[DEVELOPER MUST COMPLETE: Disclose any commercial template, app-generation service, acquired code, additional SDK/content library, or reused third-party branding/assets. A theme source comment references “Freud UI Kit”; verify whether this is design inspiration, licensed design assets, or a code template, and explain the actual usage and rights. The comment alone is not proof of a commercial application template. Also verify the provenance and license of the brand graphics and bundled fonts.]

9. Client, partner, content ownership, and submitting account

[DEVELOPER MUST COMPLETE: State who originated and owns the app concept, brand, content, and service. If this is the account holder's own product, state that accurately and explain their responsibility for operation and support. If a client, partner, or other third party supplied the concept, branding, or content, identify that party and explain the submitting-account relationship. Do not claim direct ownership or deny a client relationship unless true.]

We would appreciate clarification of whether your primary concern is overlap with a specific app in our account, similarity to a third-party app, or the origin/submission model under guideline 4.2.6. We can then provide targeted evidence alongside the answers above.

Thank you for your review.
