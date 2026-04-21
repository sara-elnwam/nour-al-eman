import 'dart:convert';

List<TeacherScheduleModel> teacherScheduleFromJson(String str) =>
    List<TeacherScheduleModel>.from(json.decode(str).map((x) => TeacherScheduleModel.fromJson(x)));

class TeacherScheduleModel {
  int? id;
  Level? level;
  Loc? loc;
  List<GroupSession>? groupSessions;
  String? name;
  int? empId;

  TeacherScheduleModel({
    this.id,
    this.level,
    this.loc,
    this.groupSessions,
    this.name,
    this.empId,
  });

  factory TeacherScheduleModel.fromJson(Map<String, dynamic> json) => TeacherScheduleModel(
    id: json["id"],
    level: json["level"] == null ? null : Level.fromJson(json["level"]),
    loc: json["loc"] == null ? null : Loc.fromJson(json["loc"]),
    groupSessions: json["groupSessions"] == null
        ? null
        : List<GroupSession>.from(json["groupSessions"].map((x) => GroupSession.fromJson(x))),
    name: json["name"],
    empId: json["empId"],
  );
}

class GroupSession {
  int? serial;
  int? day;
  String? hour;
  bool? status;

  GroupSession({this.serial, this.day, this.hour, this.status});

  factory GroupSession.fromJson(Map<String, dynamic> json) => GroupSession(
    serial: json["serial"],
    day: json["day"],
    hour: json["hour"],
    status: json["status"],
  );

  String get dayName {
    switch (day) {
      case 1: return "السبت";
      case 2: return "الأحد";
      case 3: return "الإثنين";
      case 4: return "الثلاثاء";
      case 5: return "الأربعاء";
      case 6: return "الخميس";
      case 7: return "الجمعة";
      default: return "";
    }
  }
}

class Level {
  String? name;
  Level({this.name});
  factory Level.fromJson(Map<String, dynamic> json) => Level(name: json["name"]);
}

class Loc {
  String? name;
  Loc({this.name});
  factory Loc.fromJson(Map<String, dynamic> json) => Loc(name: json["name"]);
}