import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool modified = false;

    // Replace Text('Error: $e')
    if (content.contains("Text('Error: \$e')")) {
      content = content.replaceAll(
        "Text('Error: \$e')",
        "Text(e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: \$e')"
      );
      modified = true;
    }
    
    // Replace Text('Error: $err')
    if (content.contains("Text('Error: \$err')")) {
      content = content.replaceAll(
        "Text('Error: \$err')",
        "Text(err.toString().contains('SocketException') || err.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: \$err')"
      );
      modified = true;
    }

    // Replace Text('Error: ${snap.error}')
    if (content.contains("Text('Error: \${snap.error}')")) {
      content = content.replaceAll(
        "Text('Error: \${snap.error}')",
        "Text(snap.error.toString().contains('SocketException') || snap.error.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: \${snap.error}')"
      );
      modified = true;
    }

    // Replace Text('Error: ${snapshot.error}')
    if (content.contains("Text('Error: \${snapshot.error}')")) {
      content = content.replaceAll(
        "Text('Error: \${snapshot.error}')",
        "Text(snapshot.error.toString().contains('SocketException') || snapshot.error.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: \${snapshot.error}')"
      );
      modified = true;
    }
    
    // Replace Text('Error: $errorMsg')
    if (content.contains("Text('Error: \$errorMsg')")) {
      content = content.replaceAll(
        "Text('Error: \$errorMsg')",
        "Text(errorMsg.toString().contains('SocketException') || errorMsg.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: \$errorMsg')"
      );
      modified = true;
    }

    if (modified) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
