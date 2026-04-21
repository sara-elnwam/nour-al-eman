import 'dart:convert';

AttendanceResponse attendanceResponseFromJson(String str) => AttendanceResponse.fromJson(json.decode(str));

String attendanceResponseToJson(AttendanceResponse data) => json.encode(data.toJson());

class AttendanceResponse {
  List<Datum>? data;
  dynamic statusCode;
  dynamic error;

  AttendanceResponse({
    this.data,
    this.statusCode,
    this.error,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) => AttendanceResponse(
    data: json["data"] == null ? [] : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
    statusCode: json["statusCode"],
    error: json["error"],
  );

  Map<String, dynamic> toJson() => {
    "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "statusCode": statusCode,
    "error": error,
  };
}

class Datum {
  int? id;
  int? studentId;
  int? points;
  bool? isPresent;
  String? createBy;
  String? createFrom;
  DateTime? createDate;
  int? groupId;
  dynamic newAttendanceNote;
  dynamic oldAttendanceNote;
  String? note;

  Datum({
    this.id,
    this.studentId,
    this.points,
    this.isPresent,
    this.createBy,
    this.createFrom,
    this.createDate,
    this.groupId,
    this.newAttendanceNote,
    this.oldAttendanceNote,
    this.note,
  });

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    studentId: json["studentId"],
    points: json["points"],
    isPresent: json["isPresent"],
    createBy: json["createBy"],
    createFrom: json["createFrom"],
    createDate: json["createDate"] == null ? null : DateTime.parse(json["createDate"]),
    groupId: json["groupId"],
    newAttendanceNote: json["newAttendanceNote"],
    oldAttendanceNote: json["oldAttendanceNote"],
    note: json["note"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "studentId": studentId,
    "points": points,
    "isPresent": isPresent,
    "createBy": createBy,
    "createFrom": createFrom,
    "createDate": createDate?.toIso8601String(),
    "groupId": groupId,
    "newAttendanceNote": newAttendanceNote,
    "oldAttendanceNote": oldAttendanceNote,
    "note": note,
  };
}