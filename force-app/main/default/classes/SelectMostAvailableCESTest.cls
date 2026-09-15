@IsTest
private class SelectMostAvailableCESTest {

    private static Integer idSeed = 1;

    private static Id fakeUserId() {
        return Id.valueOf('005000000000' + String.valueOf(idSeed++).leftPad(3, '0'));
    }

    private static User ces(Id uid, String name) {
        return new User(Id = uid, LastName = name, Email = name.toLowerCase() + '@johnsonturner.com');
    }

    /** An event blocking the whole of the next 14 days for one owner. */
    private static Event blockEverything(Id ownerId) {
        return new Event(
            OwnerId       = ownerId,
            StartDateTime = DateTime.now().addDays(-1),
            EndDateTime   = DateTime.now().addDays(20)
        );
    }

    private static List<SelectMostAvailableCES.ActionRequest> request(String fallbackId) {
        SelectMostAvailableCES.ActionRequest r = new SelectMostAvailableCES.ActionRequest();
        r.fallbackUserId = fallbackId;
        return new List<SelectMostAvailableCES.ActionRequest>{ r };
    }

    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void picksTheLeastBusyCes() {
        Id busyId = fakeUserId();
        Id freeId = fakeUserId();

        SelectMostAvailableCES.testPool = new List<User>{
            ces(busyId, 'Busy'), ces(freeId, 'Free')
        };
        // Busy is fully booked; Free has nothing.
        SelectMostAvailableCES.testEvents = new List<Event>{ blockEverything(busyId) };

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(request(null));
        Test.stopTest();

        System.assertEquals(true, r[0].success,
            'Expected success. errorMessage was: ' + r[0].errorMessage);
        System.assertEquals(String.valueOf(freeId), r[0].cesUserId,
            'The CES with open time must win over the fully booked one.');
        System.assert(r[0].openSlots > 0, 'The winner should have open slots.');
    }

    @IsTest
    static void neverReturnsSomeoneOutsideThePool() {
        Id a = fakeUserId();
        Id b = fakeUserId();
        SelectMostAvailableCES.testPool   = new List<User>{ ces(a, 'Anne'), ces(b, 'Kelly') };
        SelectMostAvailableCES.testEvents = new List<Event>();

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(request(null));
        Test.stopTest();

        System.assertEquals(true, r[0].success);
        System.assert(
            r[0].cesUserId == String.valueOf(a) || r[0].cesUserId == String.valueOf(b),
            'Selection must come from the CES pool, never anyone else. Got: ' + r[0].cesUserId);
    }

    @IsTest
    static void tiesAreDeterministic() {
        Id a = fakeUserId();
        Id b = fakeUserId();
        SelectMostAvailableCES.testPool   = new List<User>{ ces(a, 'Anne'), ces(b, 'Kelly') };
        SelectMostAvailableCES.testEvents = new List<Event>();

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> first  =
            SelectMostAvailableCES.selectCes(request(null));
        List<SelectMostAvailableCES.ActionResult> second =
            SelectMostAvailableCES.selectCes(request(null));
        Test.stopTest();

        System.assertEquals(first[0].cesUserId, second[0].cesUserId,
            'Identical availability must produce a stable choice.');
    }

    @IsTest
    static void returnsNameAndEmailForDownstreamUse() {
        Id a = fakeUserId();
        SelectMostAvailableCES.testPool   = new List<User>{ ces(a, 'Kristi') };
        SelectMostAvailableCES.testEvents = new List<Event>();

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(request(null));
        Test.stopTest();

        // User.Name is a server side formula, so it stays null on an in-memory record.
        // Email is the field that actually matters downstream.
        System.assertEquals('kristi@johnsonturner.com', r[0].cesEmail,
            'Email is needed so Zoom can host under this CES.');
        System.assertEquals(String.valueOf(a), r[0].cesUserId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FAILURE PATHS
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void emptyPoolWithoutFallbackFailsLoudly() {
        SelectMostAvailableCES.testPool   = new List<User>();
        SelectMostAvailableCES.testEvents = new List<Event>();

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(request(null));
        Test.stopTest();

        System.assertEquals(false, r[0].success);
        System.assertEquals(null, r[0].cesUserId, 'Must not invent a user.');
        System.assert(r[0].errorMessage.contains('No active Client Engagement Specialist'),
            r[0].errorMessage);
    }

    @IsTest
    static void everyoneBookedWithoutFallbackFailsLoudly() {
        Id a = fakeUserId();
        SelectMostAvailableCES.testPool   = new List<User>{ ces(a, 'Anne') };
        SelectMostAvailableCES.testEvents = new List<Event>{ blockEverything(a) };

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(request(null));
        Test.stopTest();

        System.assertEquals(false, r[0].success);
        System.assert(r[0].errorMessage.contains('open time'), r[0].errorMessage);
    }

    @IsTest
    static void fallbackIsUsedOnlyWhenSuppliedAndIsReported() {
        User realUser = [SELECT Id, Name, Email FROM User WHERE IsActive = true LIMIT 1];

        SelectMostAvailableCES.testPool   = new List<User>();
        SelectMostAvailableCES.testEvents = new List<Event>();

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(request(String.valueOf(realUser.Id)));
        Test.stopTest();

        System.assertEquals(true, r[0].success, 'A supplied fallback should still produce a link.');
        System.assertEquals(String.valueOf(realUser.Id), r[0].cesUserId);
        System.assertNotEquals(null, r[0].errorMessage,
            'Falling back must say why, so it is visible rather than silent.');
        System.assert(r[0].errorMessage.contains('Fell back to'), r[0].errorMessage);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WINDOW — five business days, weekends skipped
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void windowSkipsWeekends() {
        // Monday 8 Sep 2026. Five business days = Mon..Fri, ending Friday 12th at 5pm.
        DateTime monday = DateTime.newInstance(2026, 9, 7, 9, 0, 0);
        DateTime windowEnd = SelectMostAvailableCES.endOfBusinessDaysAhead(monday, 5);

        System.assertEquals(Date.newInstance(2026, 9, 11), windowEnd.date(),
            'Mon start, five business days, should end Friday.');
        System.assertEquals(17, windowEnd.hour(), 'Window should close at end of business.');
    }

    @IsTest
    static void windowFromThursdayReachesIntoNextWeek() {
        // Thursday. Five business days must not be half consumed by the weekend.
        DateTime thursday = DateTime.newInstance(2026, 9, 10, 9, 0, 0);
        DateTime windowEnd = SelectMostAvailableCES.endOfBusinessDaysAhead(thursday, 5);

        System.assertEquals(Date.newInstance(2026, 9, 16), windowEnd.date(),
            'Thu start should reach the following Wednesday, skipping Sat and Sun.');
    }

    @IsTest
    static void windowFromSaturdayStartsOnMonday() {
        DateTime saturday = DateTime.newInstance(2026, 9, 12, 9, 0, 0);
        DateTime windowEnd = SelectMostAvailableCES.endOfBusinessDaysAhead(saturday, 5);

        System.assertEquals(Date.newInstance(2026, 9, 18), windowEnd.date(),
            'A weekend start should count from the following Monday.');
    }

    @IsTest
    static void emptyRequestListIsSafe() {
        SelectMostAvailableCES.testPool   = new List<User>();
        SelectMostAvailableCES.testEvents = new List<Event>();

        Test.startTest();
        List<SelectMostAvailableCES.ActionResult> r =
            SelectMostAvailableCES.selectCes(new List<SelectMostAvailableCES.ActionRequest>());
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(false, r[0].success);
    }
}