Hello App Review Team,

Thank you for requesting clarification. Namaz Grubum is my own standalone product for friends who already pray and want to help one another wake for morning prayer and maintain participation together. Below are answers to all nine questions.

1. What does the app do, and what problem does it solve?

It coordinates participation within a prayer group. Members create or join groups, acknowledge waking (“Kalktım”), record praying (“Kıldım”), view member participation, and send wake-up reminders. Owners manage membership and admission requests. Groups can use direct check-ins or camera-based submissions; photos are restricted to active members and normally expire after 12 hours. The app also distinguishes on-time prayer completion from missed-prayer completion. The problem is knowing who in a group has responded and who may need encouragement, beyond receiving an individual alarm.

2. Who is the intended user?

Turkish-speaking Muslims who already pray but sometimes struggle with morning or other daily prayers, particularly friends, families, and community members seeking voluntary mutual support. Group organizers manage participation; members acknowledge waking, record completion, and support fellow members. This is a group-coordination product for practicing users.

3. What gap does it address?

A timetable answers “When is the prayer?” An individual tracker records one person's history. Namaz Grubum answers “Who in our group has acknowledged waking or recorded completion, and who may need a reminder?” It combines structured membership, prayer-specific shared states, reminders between members, and optional restricted photo submissions. A messaging thread requires users to reconstruct this information manually. My claim is this implemented workflow, not that no other app has any comparable feature.

4. What beta testing and feedback informed the app?

Internal TestFlight records show two installed tester accounts: mine and one additional tester, using an iPhone SE (2nd generation) and iPhone 14 Pro Max. There are 17 screenshot-feedback records from 10 September–2 October 2026: 14 from my testing and three from the additional tester. This was a small internal test, not 17 independent participants.

Examples of feedback applied during development:

- Onboarding reappeared after relaunch: completion was persisted before permission operations.
- The group title collided with its role badge: these were separated for narrow displays.
- Joining could remain in a loading state: a timeout and explicit outcome states were added.
- The additional tester reported a group owner being offered “report own group”: this menu option was hidden for owners and administrators.
- The additional tester reported brief acknowledgement of the wake-up action: clearer confirmation was added for three seconds.

Build clarification: the rejected version 1.0 is linked to build 8. Later changes, including further startup improvements, are in TestFlight builds 9–10; I am not attributing those changes to build 8. Build 10 is VALID and passed static analysis and 31 automated tests. I have not resubmitted in response to this rejection.

5. Standalone product or part of a suite?

Standalone. The closest subject-area overlap is my app “Kolay Namaz İle Namaza Başla” (App ID 6806850484), but their intended tasks differ:

- Kolay Namaz supports people starting or returning to prayer: beginning with one daily prayer, individual learning and habit support, and access to an Islamic mentor.
- Namaz Grubum supports people who already pray: joining friends, coordinating waking, and following group participation.

Both have prayer times and reminders; the distinction is their primary workflow, not branding. Other products on my account address books (Libhane), personal goal-based alarms (Motivational Alarm Clock), travel (İstanbul Gezi Rehberi), a matcha journal (Matcha 21 Day Challenge), gifts (Takı Takip), chat analysis (Whatswho), and receipts (Fiş Takip). They are separate products, not editions in a prayer-app suite.

6. Why not consolidate it into another app?

Technically, group functions could be added to Kolay Namaz. I chose a separate product because a beginner working toward one daily prayer needs personal guidance, while friends already practicing prayer need a shared service with invitations, admission approval, member-visible records, reminders, and moderation. That group service is Namaz Grubum's main experience, not an additional lesson or content pack. Neither product requires the other.

7. Shared components with other apps on my account?

I developed the applications separately. I did not transfer first-party code, screens, logos, or content from Kolay Namaz or my other applications. Common third-party dependencies may recur, including Flutter, Firebase, Riverpod, GoRouter, and standard device-capability packages. Namaz Grubum's group membership, prayer check-ins, reminders, photo-access handling, and moderation were implemented for this product.

8. Shared components with third-party applications?

I developed the code with AI assistance rather than purchasing a completed application to rebrand. Visual references may have informed the interface; the theme source references Freud UI Kit, and I do not claim that reference material as my own original design work. I do not recall the precise extent of that visual reference and do not want to overstate its provenance.

Standard dependencies include Flutter; Firebase for authentication, data, storage, messaging, and backend infrastructure; Riverpod/GoRouter; adhan_dart for prayer-time calculation; and camera, location, notification, and sharing packages. The original product implementation around them is the multi-user prayer-group workflow described above.

9. Was it made for a client or another content provider?

No. The idea and Namaz Grubum brand are mine. I conceived the product so friends could help one another wake and maintain prayer participation. I developed it with AI-assisted tools and submit it through my own developer account. There is no client, partner, or separate content provider on whose behalf I publish. I am responsible for the product, support, and maintenance.

To locate the group functionality: open “Gruplarım” (My Groups), select a group, and inspect its participation and member screens. “Grup Oluştur” creates a group; “Katılım İstekleri” manages admission. Prayer actions depend on the applicable prayer period.

These answers are provided to clarify the existing submission before any resubmission. If a specific application or shared component remains a concern, please identify it so I can address that point directly.

Thank you,
Muhammet Çalış
