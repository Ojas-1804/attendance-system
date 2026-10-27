class Stat {
  Stat({required this.present, required this.total, required this.percentage, required this.level});

  factory Stat.fromJson(Map<String, dynamic> j) => Stat(
        present: j['present'] as int,
        total: j['total'] as int,
        percentage: (j['percentage'] as num?)?.toDouble(),
        level: j['level'] as String,
      );

  final int present;
  final int total;
  final double? percentage;
  final String level; // HEALTHY | WARNING | LOW | NO_DATA

  String get label => percentage == null ? '--' : '${percentage!.toStringAsFixed(1)}%';
}

class SubjectStat extends Stat {
  SubjectStat({
    required this.subjectId,
    required this.name,
    required this.code,
    required super.present,
    required super.total,
    required super.percentage,
    required super.level,
  });

  factory SubjectStat.fromJson(Map<String, dynamic> j) {
    final s = Stat.fromJson(j);
    return SubjectStat(
      subjectId: j['subject_id'] as int,
      name: j['subject_name'] as String,
      code: j['subject_code'] as String,
      present: s.present,
      total: s.total,
      percentage: s.percentage,
      level: s.level,
    );
  }

  final int subjectId;
  final String name;
  final String code;
}

class AttendanceSummary {
  AttendanceSummary({required this.overall, required this.subjects, required this.minRequired, required this.warningMessage});

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) => AttendanceSummary(
        overall: Stat.fromJson(j['overall'] as Map<String, dynamic>),
        subjects: (j['subjects'] as List).map((e) => SubjectStat.fromJson(e as Map<String, dynamic>)).toList(),
        minRequired: (j['thresholds']['min_required'] as num).toDouble(),
        warningMessage: j['warning_message'] as String?,
      );

  final Stat overall;
  final List<SubjectStat> subjects;
  final double minRequired;
  final String? warningMessage;
}

class SessionItem {
  SessionItem({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.subjectCode,
    required this.teacherName,
    required this.room,
    required this.batch,
    required this.status,
  });

  factory SessionItem.fromJson(Map<String, dynamic> j) => SessionItem(
        id: j['id'] as int,
        date: DateTime.parse(j['date'] as String),
        startTime: j['start_time'] as String,
        endTime: j['end_time'] as String,
        subjectName: j['subject_name'] as String,
        subjectCode: j['subject_code'] as String,
        teacherName: j['teacher_name'] as String,
        room: j['room'] as String?,
        batch: j['batch'] as String,
        status: j['status'] as String, // PRESENT | ABSENT | UPCOMING | PENDING | CANCELLED
      );

  final int id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String subjectName;
  final String subjectCode;
  final String teacherName;
  final String? room;
  final String batch;
  final String status;

  String get timeRange => '$startTime - $endTime';
}

class Home {
  Home({
    required this.fullName,
    required this.rollNo,
    required this.batch,
    required this.overall,
    required this.warningMessage,
    required this.todays,
    required this.next,
    required this.recent,
  });

  factory Home.fromJson(Map<String, dynamic> j) => Home(
        fullName: j['full_name'] as String,
        rollNo: j['roll_no'] as String,
        batch: j['batch'] as String?,
        overall: Stat.fromJson(j['overall'] as Map<String, dynamic>),
        warningMessage: j['warning_message'] as String?,
        todays: (j['todays_classes'] as List).map((e) => SessionItem.fromJson(e as Map<String, dynamic>)).toList(),
        next: j['next_class'] == null ? null : SessionItem.fromJson(j['next_class'] as Map<String, dynamic>),
        recent: (j['recent'] as List).map((e) => SessionItem.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final String fullName;
  final String rollNo;
  final String? batch;
  final Stat overall;
  final String? warningMessage;
  final List<SessionItem> todays;
  final SessionItem? next;
  final List<SessionItem> recent;
}

class Profile {
  Profile({required this.fullName, required this.rollNo, required this.email, required this.batch});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        fullName: j['full_name'] as String,
        rollNo: j['roll_no'] as String,
        email: j['email'] as String,
        batch: j['batch'] as String?,
      );

  final String fullName;
  final String rollNo;
  final String email;
  final String? batch;
}
