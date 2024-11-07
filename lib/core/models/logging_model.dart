
class LoggingModel {
  final String id;
  final DateTime time;
  final String uid;
  final String function;
  final Map<String, String> metaData;

  LoggingModel({
    required this.id,
    required this.time,
    required this.uid,
    required this.function,
    required this.metaData,
  });

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'uid': uid,
      'function': function,
      'metaData': metaData,
    };
  }
}
