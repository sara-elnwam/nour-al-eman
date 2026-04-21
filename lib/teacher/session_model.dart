import 'dart:convert';

List<SessionRecord> sessionRecordFromJson(String str) =>
    List<SessionRecord>.from(json.decode(str).map((x) => SessionRecord.fromJson(x)));

class GroupData {
  String? levelName;
  int? levelId;
  String? loc;
  List<GroupSession>? groupSessions;
  String? emp;
  int? empId;
  int? groupId;
  String? groupName;
  int? studentCount;

  GroupData({
    this.levelName,
    this.levelId,
    this.loc,
    this.groupSessions,
    this.emp,
    this.empId,
    this.groupId,
    this.groupName,
    this.studentCount,
  });

  factory GroupData.fromJson(Map<String, dynamic> json) {
    return GroupData(
      levelName: json["levelname"]?.toString() ?? "المستوى",
      levelId: json["levelId"],
      loc: json["loc"]?.toString() ?? "غير محدد",
      emp: json["emp"]?.toString(),
      empId: json["empid"],
      groupId: json["groupID"] ?? json["id"],
      groupName: json["groupName"]?.toString() ?? "بدون اسم",
      studentCount: json["studentCount"] ?? 0,
      groupSessions: json["groupSessions"] == null
          ? null
          : List<GroupSession>.from(json["groupSessions"].map((x) => GroupSession.fromJson(x))),
    );
  }
}

class Student {
  final int id;
  final String name;
  final String status;

  Student({
    required this.id,
    required this.name,
    required this.status,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json["id"] ?? json["studentId"] ?? 0,
      name: json["name"] ?? json["studentName"] ?? "اسم غير معروف",
      status: (json["active"] == true || json["status"] == "Active")
          ? "نشط"
          : "غير نشط",
    );
  }
}

class SessionRecord {
  int? id;
  Level? level;
  Location? loc;
  List<GroupSession>? groupSessions;
  String? name;
  bool? active;

  SessionRecord({
    this.id,
    this.level,
    this.loc,
    this.groupSessions,
    this.name,
    this.active
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: json["id"],
    level: json["level"] == null ? null : Level.fromJson(json["level"]),
    loc: json["loc"] == null ? null : Location.fromJson(json["loc"]),
    groupSessions: json["groupSessions"] == null
        ? null
        : List<GroupSession>.from(json["groupSessions"].map((x) => GroupSession.fromJson(x))),
    name: json["name"],
    active: json["active"],
  );
}

class Level {
  String? name;
  Level({this.name});
  factory Level.fromJson(Map<String, dynamic> json) => Level(name: json["name"]);
}

class Location {
  String? name;
  Location({this.name});
  factory Location.fromJson(Map<String, dynamic> json) => Location(name: json["name"]);
}

class GroupSession {
  int? day;
  String? hour;

  GroupSession({this.day, this.hour});

  factory GroupSession.fromJson(Map<String, dynamic> json) => GroupSession(
    day: json["day"],
    hour: json["hour"]?.toString(),
  );

  String get dayName {
    switch (day) {
      case 0: return "السبت";
      case 1: return "الأحد";
      case 2: return "الإثنين";
      case 3: return "الثلاثاء";
      case 4: return "الأربعاء";
      case 5: return "الخميس";
      case 6: return "الجمعة";
      default: return "";
    }
  }
}