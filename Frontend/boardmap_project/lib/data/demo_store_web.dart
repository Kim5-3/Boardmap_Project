import 'package:web/web.dart' as web;

String? readDemoValue(String key) => web.window.localStorage.getItem(key);

void writeDemoValue(String key, String value) =>
    web.window.localStorage.setItem(key, value);

void removeDemoValue(String key) => web.window.localStorage.removeItem(key);
String? readSessionValue(String key) => web.window.sessionStorage.getItem(key);
void writeSessionValue(String key, String value) =>
    web.window.sessionStorage.setItem(key, value);
void removeSessionValue(String key) =>
    web.window.sessionStorage.removeItem(key);
