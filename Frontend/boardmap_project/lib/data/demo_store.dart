import 'demo_store_stub.dart'
    if (dart.library.html) 'demo_store_web.dart' as platform;

String? readDemoValue(String key) => platform.readDemoValue(key);
void writeDemoValue(String key, String value) =>
    platform.writeDemoValue(key, value);
void removeDemoValue(String key) => platform.removeDemoValue(key);
String? readSessionValue(String key) => platform.readSessionValue(key);
void writeSessionValue(String key, String value) =>
    platform.writeSessionValue(key, value);
void removeSessionValue(String key) => platform.removeSessionValue(key);
