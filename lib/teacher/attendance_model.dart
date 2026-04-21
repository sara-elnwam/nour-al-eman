import 'dart:convert';

AttendanceModel attendanceModelFromJson(String str) => AttendanceModel.fromJson(json.decode(str));

class AttendanceModel {
  List<AttendanceData>? data;
  dynamic statusCode;
  dynamic error;

  AttendanceModel({this.data, this.statusCode, this.error});

  factory AttendanceModel.fromJson(Map<String, dynamic> json) => AttendanceModel(
    data: json["data"] == null
        ? null
        : List<AttendanceData>.from(
        json["data"].map((x) => AttendanceData.fromJson(x))),
    statusCode: json["statusCode"],
    error: json["error"],
  );
}

class AttendanceData {
  String? userName;
  String? checkType;
  String? locationName;
  String? date;
  String? checkInTime;
  String? checkOutTime;
  String? workingHours;

  AttendanceData({
    this.userName,
    this.checkType,
    this.locationName,
    this.date,
    this.checkInTime,
    this.checkOutTime,
    this.workingHours,
  });

  factory AttendanceData.fromJson(Map<String, dynamic> json) => AttendanceData(
    userName: json["userName"] ?? json["username"],
    checkType: json["checkType"],
    locationName: json["locationName"],
    date: json["date"],
    checkInTime: json["checkInTime"],
    checkOutTime: json["checkOutTime"],
    workingHours: json["workingHours"],
  );
}