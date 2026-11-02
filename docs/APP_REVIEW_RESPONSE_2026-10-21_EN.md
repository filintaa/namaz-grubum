Hello App Review Team,

Thank you for the opportunity to clarify Namaz Grubum's purpose, ownership, and distinction from the other apps on my account. I am the developer and product owner. My original idea was to help people who already pray support their friends in waking for the morning prayer and maintaining participation together. I developed the application with AI-assisted coding and design tools for my own product, not for a client.

I am replying before resubmitting, as requested. Below are answers to all nine questions.

1. What does the app do, and what primary problem does it solve?

Namaz Grubum addresses coordination within a prayer group. A reminder can tell someone that a prayer time has arrived, but it does not tell their friends whether that person has acknowledged waking or recorded praying. The app turns those separate actions into a shared group workflow.

A person creates or joins a group that follows selected prayers. Group owners manage admission requests and membership. Members record “Kalktım” (I am awake) and “Kıldım” (I have prayed), view participation within the group, and send wake-up reminders to fellow members. The app distinguishes on-time prayer completion from a later missed-prayer completion record. Group progress can be viewed over time.

Groups can choose direct check-ins or a camera-based submission workflow. In photo-enabled groups, the relevant action opens the camera; uploaded photos are restricted to active group members and normally expire after 12 hours. Backend logic checks membership, prayer periods, and access permissions. Reporting, blocking, and group-management controls support this multi-user experience.

2. Who is the intended user?

The primary intended users are Turkish-speaking Muslims who already practice prayer but sometimes struggle to wake for the early-morning prayer or maintain particular daily prayers consistently. The specific use case is a group of friends, family members, or community members who voluntarily want to encourage one another.

An organizer needs to manage the group and its members. A participating member needs to acknowledge waking, record prayer completion, see participation, and send a reminder when appropriate. Users do not need to be learning how to pray to benefit from this application.

3. What need does it address beyond existing apps?

The specific need is structured, shared follow-through for a prayer group. A prayer timetable provides the time; an individual tracker records one person's history; a general messaging thread requires the group to interpret messages and maintain its own record manually.

Namaz Grubum combines membership and admission handling, prayer-specific participation states, member wake-up reminders, group progress, and optional restricted-access camera submissions in one workflow. The distinctive experience is the relationship between those functions, rather than simply displaying prayer times or changing the appearance of an existing tracker.

I am not claiming that no other app offers any comparable feature. I ask that Namaz Grubum be assessed on its implemented group-coordination experience and the use case described above.

4. What beta testing was conducted, and what feedback was applied?

I conducted a small internal TestFlight test with two installed tester accounts: my developer account and one additional tester. As verified in App Store Connect on 21 October 2026, the installed-device records show an iPhone SE (2nd generation) and an iPhone 14 Pro Max, both on build 1.0.0 (10). A third account is only in the invited state and is not counted as a participant.

App Store Connect contains 17 screenshot-feedback submissions dated 10 September through 2 October 2026, associated with builds 3, 4, 8, and 9. Fourteen came from my account and three came from the additional tester's account. This was a small developer-led internal test, not 17 independent testers or a large external beta study. The additional tester's three reports concerned the group-owner report menu, the brief acknowledgement after the wake-up action, and the join/loading flow. The remaining reports came from my own testing.

Concrete recorded issues and changes include:

- “Her acilista bu ekran geliyor” (This screen appears every time the app opens): onboarding completion was persisted before permission-related operations.
- “İsim kısmı bozuk düzelt” (The name area is broken): the group title and role badge were separated to avoid collisions on narrow screens.
- Feedback about a join action remaining in a loading state: a bounded timeout and explicit completed, pending, and error states were added.
- Feedback that a pending join request appeared available again: the pending state was made explicit; later work also restored it from backend records when reopening the group.
- Feedback that prayers outside their applicable period should not be confirmed normally: later builds added disabled future-prayer actions and a separate missed-prayer completion action.
- Feedback requesting that group owners be notified of join requests: later backend work added administrator notifications with duplicate-request protection.

There is an important build distinction: the rejected App Store version 1.0 is currently linked to build 8. Later improvements are available in TestFlight builds 9 and 10; I am not presenting all later changes as features of the build you reviewed. Build 10 addresses a further startup report from build 9 and passed static analysis and 31 automated tests. Automated tests and backend scenarios using test accounts supplement internal testing; they are not presented as independent human beta participation.

5. Is this a standalone product or part of a suite?

Namaz Grubum is a standalone product. It does not require another app from my account, and it is not a separate branded or regional edition of another product.

The closest subject-area comparison on my account is “Kolay Namaz İle Namaza Başla” (App ID 6806850484). I acknowledge the overlap in prayer times, reminders, and prayer recording. However, the intended users and primary tasks differ:

- Kolay Namaz is for people who have not started praying, or have started and stopped. Its purpose is to support a gradual return, including beginning with one daily prayer, personal learning and habit support, and access to an Islamic mentor.
- Namaz Grubum is for people who already pray and want mutual support within a group, particularly around waking for morning prayer. Membership, participation states, reminders between members, and shared group follow-through are its core workflow.

The other apps on my account address distinct tasks: Libhane: Kitap Takip concerns book tracking; Motivational Alarm Clock concerns personal goal-based waking; İstanbul Gezi Rehberi: Rota concerns travel; Matcha 21 Day Challenge concerns a matcha routine and journal; Takı Takip: Düğün Nişan Sünnet concerns gift tracking; Whatswho: AI Chat Analyzer concerns chat analysis; and Fiş Takip: Market Fişi Tarama concerns receipts. Personal reminders or habit tracking may be common concepts, but these products are not editions of Namaz Grubum's prayer-group service.

6. Could this be an expansion within another app on the account?

Technically, group functions could be added to Kolay Namaz. I chose a separate product because the group service addresses a different immediate need and a different usage relationship.

Kolay Namaz supports the individual's decision to start or return to prayer through small steps and guidance. Namaz Grubum assumes an existing prayer practice and lets people coordinate with other members. It needs group creation, invitations, membership approval, member-visible participation, reminders between members, optional photos, and moderation as its main experience.

For example, a group of friends who already know how to pray should be able to join their shared morning-prayer group directly, without adopting a beginner program or mentor workflow. Conversely, a person taking their first step toward one daily prayer should not have to participate in a group. The separate product boundary follows these different needs; it is not a method of offering the same app under another name.

7. Does it share significant code, frameworks, or assets with another app on the account?

I developed the applications separately, with separate application code and different interface designs. I did not transfer first-party application code, screens, logos, or content from Kolay Namaz or another app on my account into Namaz Grubum.

Common third-party technologies may be used in more than one project. Namaz Grubum uses Flutter/Dart, Firebase, Riverpod, GoRouter, and standard notification, location, camera, and sharing packages. These are general development dependencies. Its product-specific implementation includes group admission and membership, prayer check-ins, member reminders, restricted photo handling, and moderation.

8. Does it share a codebase, SDK, or content library with third-party apps?

Namaz Grubum was developed as its own application, not by purchasing a completed app and changing its name or content. I used AI tools to help write code and develop the design. Visual references may have informed the design; I do not claim that every visual convention was invented without references. The project includes a Freud UI Kit reference in its theme source comment. That reference is separate from the implemented prayer-group service and does not establish that the application uses a shared executable app template or a third-party application's codebase.

The standard dependencies include Flutter for the interface, Firebase for authentication/data/storage/messaging/backend infrastructure, Riverpod and GoRouter for application state and navigation, and adhan_dart for prayer-time calculations. Camera, location, local-notification, and sharing packages provide device capabilities. The original functionality implemented around these components is the group membership, shared participation, member reminders, optional group camera submissions, and moderation workflow described above.

9. Was it created for a client, partner, or third party?

No. Namaz Grubum is my own product concept and brand. I conceived it because I thought friends should be able to form a prayer group and help one another wake and follow through. I developed it for my own operation and am submitting it through my own developer account.

There is no client or other content provider for whom I am acting as an app-generation or template-submission service. I am responsible for the product, its functionality, support, and ongoing development. AI assistance was a development tool, not a relationship in which I publish a client's product on their behalf.

Reviewing the core workflow

The key screens are “Grup Oluştur” (Create Group), “Gruplarım” (My Groups), a group's detail screen, its member list, and “Katılım İstekleri” (Join Requests). The group detail and member screens show the difference between the shared participation experience and an individual prayer timetable. With two participating app installations, the membership and shared-state workflow can be evaluated between members. Prayer actions are time-dependent, so their availability changes with the selected prayer's applicable period.

I respectfully request reconsideration based on these functional and ownership distinctions. If the concern relates to a particular app or shared component beyond the overlap with Kolay Namaz explained above, please identify it so I can address that specific point. I will follow your direction before making a new submission.

Thank you,
Muhammet Çalış
