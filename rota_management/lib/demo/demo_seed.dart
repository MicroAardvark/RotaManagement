import 'dart:math';

/// Made-up data for the demo build. Every name, address, phone number
/// and email here is fictional: phone numbers use Ofcom's 07700 900xxx
/// drama range, emails use example.com, and postcodes use the
/// non-existent "DM" area.

class DemoStaff {
  final String id;
  String name;
  final String email;
  String role; // 'manager' or 'employee'
  bool passwordSet;
  bool active;

  DemoStaff({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.passwordSet = true,
    this.active = true,
  });
}

class DemoClient {
  final String id;
  String name;
  String houseNumber;
  String addressLine1;
  String postcode;
  String phone;
  String email;
  String access;

  DemoClient({
    required this.id,
    required this.name,
    required this.houseNumber,
    required this.addressLine1,
    required this.postcode,
    this.phone = '',
    this.email = '',
    this.access = '',
  });
}

class DemoJobType {
  final String id;
  String name;

  DemoJobType({required this.id, required this.name});
}

class DemoShift {
  final String id;
  String employeeId;
  String clientId;
  String jobTypeId;
  DateTime startTime;
  DateTime endTime;
  String role; // the job type's name, as the server stores it
  String notes;
  bool published;
  bool notifyPending;

  DemoShift({
    required this.id,
    required this.employeeId,
    required this.clientId,
    required this.jobTypeId,
    required this.startTime,
    required this.endTime,
    required this.role,
    this.notes = '',
    this.published = false,
    this.notifyPending = true,
  });
}

/// One rota week's publish state, keyed by its local Monday 00:00 as a
/// UTC ISO string (the same `start` value the app sends to publish).
class DemoWeek {
  DateTime? publishedAt;
  final Set<String> pendingRemovals = {};
}

/// The starting state of the demo company.
class DemoSeed {
  /// Every seeded account uses this password.
  static const String password = 'demo1234';

  static const String managerEmail = 'alex.morgan@example.com';
  static const String employeeEmail = 'jamie.patel@example.com';

  static const String companyName = 'Brightside Cleaning (demo)';

  final List<DemoStaff> staff;
  final List<DemoClient> clients;
  final List<DemoJobType> jobTypes;
  final List<DemoShift> shifts;
  final Map<String, DemoWeek> weeks;

  DemoSeed._(this.staff, this.clients, this.jobTypes, this.shifts, this.weeks);

  /// The local Monday 00:00 of the week [day] falls in.
  static DateTime mondayOf(DateTime day) {
    final local = day.toLocal();
    return DateTime(local.year, local.month, local.day - (local.weekday - DateTime.monday));
  }

  /// Key for [DemoSeed.weeks]: matches what ApiService sends as `start`.
  static String weekKey(DateTime monday) =>
      DateTime(monday.year, monday.month, monday.day).toUtc().toIso8601String();

  /// Builds the demo data around [now], so the rota always shows the
  /// current week: three past weeks, this week and next week published,
  /// a few unpublished changes next week, and the week after in draft.
  factory DemoSeed.generate(DateTime now) {
    final staff = [
      DemoStaff(id: 'staff-1', name: 'Alex Morgan', email: managerEmail, role: 'manager'),
      DemoStaff(id: 'staff-2', name: 'Jamie Patel', email: employeeEmail, role: 'employee'),
      DemoStaff(id: 'staff-3', name: 'Sam Clarke', email: 'sam.clarke@example.com', role: 'employee'),
      DemoStaff(id: 'staff-4', name: 'Ellie Hughes', email: 'ellie.hughes@example.com', role: 'employee'),
      DemoStaff(id: 'staff-5', name: 'Tom Evans', email: 'tom.evans@example.com', role: 'employee'),
      DemoStaff(id: 'staff-6', name: 'Grace Okafor', email: 'grace.okafor@example.com', role: 'employee'),
    ];

    final jobTypes = [
      DemoJobType(id: 'job-1', name: 'Regular clean'),
      DemoJobType(id: 'job-2', name: 'Deep clean'),
      DemoJobType(id: 'job-3', name: 'End of tenancy'),
      DemoJobType(id: 'job-4', name: 'Office clean'),
      DemoJobType(id: 'job-5', name: 'Oven clean'),
    ];

    final clients = [
      DemoClient(
        id: 'client-1', name: 'Margaret Hargreaves', houseNumber: '14', addressLine1: 'Larch Avenue',
        postcode: 'DM1 4QT', phone: '07700 900141', email: 'm.hargreaves@example.com',
        access: 'Key safe by the back door, code 4071.',
      ),
      DemoClient(
        id: 'client-2', name: 'The Whitfield family', houseNumber: '3', addressLine1: "Cooper's Row",
        postcode: 'DM2 7RE', phone: '07700 900233',
        access: 'Someone is usually home. If not, key is with the neighbour at no. 5.',
      ),
      DemoClient(
        id: 'client-3', name: 'Brookside Dental Practice', houseNumber: 'Unit 2', addressLine1: 'Mill Lane Business Park',
        postcode: 'DM3 1BX', phone: '07700 900318', email: 'practice@example.com',
        access: 'Alarm code 2580. Reception closes at 17:30, arrive after that.',
      ),
      DemoClient(
        id: 'client-4', name: 'Daniel Price', houseNumber: '22B', addressLine1: 'Station Road',
        postcode: 'DM1 9HL', phone: '07700 900427',
        access: 'Ground floor flat. Ring the buzzer marked Price.',
      ),
      DemoClient(
        id: 'client-5', name: 'Riverside Lettings', houseNumber: '8', addressLine1: 'Quayside Court',
        postcode: 'DM4 2NN', email: 'lettings@example.com',
        access: 'Collect keys from the Riverside office on Bridge Street before 10:00.',
      ),
      DemoClient(
        id: 'client-6', name: 'Helen & Mark Ashworth', houseNumber: '61', addressLine1: 'Orchard Way',
        postcode: 'DM2 3FD', phone: '07700 900652',
        access: 'Dog is friendly. Side gate is unlocked.',
      ),
      DemoClient(
        id: 'client-7', name: 'Priya Sharma', houseNumber: '5', addressLine1: 'Kestrel Close',
        postcode: 'DM5 6WA', phone: '07700 900719', email: 'priya.s@example.com',
        access: 'Key safe on the porch, code 1194.',
      ),
      DemoClient(
        id: 'client-8', name: 'Northgate Community Hall', houseNumber: '1', addressLine1: 'Northgate',
        postcode: 'DM3 8LP', phone: '07700 900804',
        access: 'Caretaker lets you in. Call when outside.',
      ),
      DemoClient(
        id: 'client-9', name: 'George Bennett', houseNumber: '40', addressLine1: 'Hawthorn Drive',
        postcode: 'DM4 5JU', phone: '07700 900966',
        access: 'Customer is home. Please park on the drive.',
      ),
      DemoClient(
        id: 'client-10', name: 'Fern Cottage', houseNumber: '2', addressLine1: 'Church Lane',
        postcode: 'DM5 1AG', email: 'ferncottage@example.com',
        access: 'Holiday let. Key safe on the garden wall, code 6620.',
      ),
    ];

    // Which job types suit which clients, so the rota reads sensibly.
    const homeJobs = ['job-1', 'job-1', 'job-1', 'job-2', 'job-5'];
    const jobsFor = <String, List<String>>{
      'client-3': ['job-4'],
      'client-5': ['job-3'],
      'client-8': ['job-4'],
      'client-10': ['job-3', 'job-2'],
    };
    const lengths = <String, int>{ // minutes
      'job-1': 120,
      'job-2': 240,
      'job-3': 300,
      'job-4': 90,
      'job-5': 90,
    };
    const notes = [
      'Bring the steam mop.',
      'Customer has asked for extra time on the kitchen.',
      'Please change the bed linen (left on the bed).',
      'Windows inside only.',
      'First visit, introduce yourself.',
    ];

    final random = Random(7); // fixed seed: the same rota every visit
    final thisMonday = mondayOf(now);
    final cleaners = staff.where((s) => s.role == 'employee').toList();
    final shifts = <DemoShift>[];
    final weeks = <String, DemoWeek>{};
    var nextId = 1;

    for (var weekOffset = -3; weekOffset <= 2; weekOffset++) {
      final monday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day + weekOffset * 7);
      final published = weekOffset <= 1;
      if (published) {
        // Published the Thursday before, never in the future
        var publishedAt = DateTime(monday.year, monday.month, monday.day - 4, 16, 30);
        final latest = now.subtract(const Duration(hours: 2));
        if (publishedAt.isAfter(latest)) publishedAt = latest;
        weeks[weekKey(monday)] = DemoWeek()..publishedAt = publishedAt;
      }

      for (var dayIndex = 0; dayIndex < 6; dayIndex++) { // Monday to Saturday
        final isSaturday = dayIndex == 5;
        for (final cleaner in cleaners) {
          // Jamie (the employee login) always works weekdays, so the
          // employee view has plenty to show.
          final dayOffChance = isSaturday ? 0.6 : (cleaner.id == 'staff-2' ? 0.0 : 0.15);
          if (random.nextDouble() < dayOffChance) continue;

          var start = DateTime(monday.year, monday.month, monday.day + dayIndex, 8, random.nextInt(3) * 30);
          final dayEnd = DateTime(start.year, start.month, start.day, isSaturday ? 13 : 17, 30);
          final jobsToday = 1 + random.nextInt(3);

          for (var j = 0; j < jobsToday; j++) {
            final client = clients[random.nextInt(clients.length)];
            final options = jobsFor[client.id] ?? homeJobs;
            final jobTypeId = options[random.nextInt(options.length)];
            final end = start.add(Duration(minutes: lengths[jobTypeId]!));
            if (end.isAfter(dayEnd)) break;

            shifts.add(DemoShift(
              id: 'shift-${nextId++}',
              employeeId: cleaner.id,
              clientId: client.id,
              jobTypeId: jobTypeId,
              startTime: start,
              endTime: end,
              role: jobTypes.firstWhere((t) => t.id == jobTypeId).name,
              notes: random.nextDouble() < 0.2 ? notes[random.nextInt(notes.length)] : '',
              published: published,
              notifyPending: !published,
            ));
            start = end.add(const Duration(minutes: 30)); // travel time
          }
        }
      }
    }

    // Next week: a couple of published shifts edited since publishing,
    // and a couple of new drafts, so "Publish" has something to send.
    final nextMonday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day + 7);
    final nextWeekEnd = DateTime(nextMonday.year, nextMonday.month, nextMonday.day + 7);
    final nextWeek = shifts
        .where((s) => !s.startTime.isBefore(nextMonday) && s.startTime.isBefore(nextWeekEnd))
        .toList();
    for (final i in const [3, 9]) {
      if (i >= nextWeek.length - 2) continue; // the last two become drafts below
      nextWeek[i]
        ..notifyPending = true
        ..notes = 'Changed since publishing: customer asked for a later start.';
    }
    for (final s in nextWeek.reversed.take(2)) {
      s.published = false;
      s.notifyPending = true;
    }

    return DemoSeed._(staff, clients, jobTypes, shifts, weeks);
  }
}
