// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.file_operations;

import 'dart:async';
import 'dart:core';
import 'dart:js';
import 'dart:typed_data';

import 'package:chrome_gen/chrome_app.dart' as chrome;

/**
 * Utility class to access HTML5 filesystem operations.
 * TODO(grv): Add unittests.
 *
 **/
abstract class FileOps {

  /**
   * Creates directories recursively in a given [path]. The immediate parent
   * of the path may or may nor exist.
   */
  static Future<chrome.DirectoryEntry> createDirectoryRecursive(
      chrome.DirectoryEntry dir, String path) {

    if (path[path.length - 1] == '/') {
      path = path.substring(0, path.length -1);
    }

    List<String> pathParts = path.split("/");
    int i = 0;

    createDirectories(chrome.DirectoryEntry dir) {
      return dir.createDirectory(pathParts[i]).then(
          (chrome.DirectoryEntry dir) {
        i++;
        if (i == pathParts.length) return dir;

        return createDirectories(dir);
      });
    }
    return createDirectories(dir);
  }

  /**
   * Creates a file with a given [content] and [type]. Creates parent
   * directories if the immediate parent is absent.
   */
  static Future<chrome.Entry> createFileWithContent(
      chrome.DirectoryEntry root, String path, content, String type) {

    createFile(chrome.DirectoryEntry dir, String fileName) {
      return dir.createFile(fileName).then((chrome.ChromeFileEntry entry) {
        if (type == 'Text') {
          return entry.writeText(content).then((_) => entry);
        } else if (type == 'blob') {
          if (content is Uint8List) {
            content = new chrome.ArrayBuffer.fromBytes(content.toList());
          }
          return entry.writeBytes(content).then((_) => entry);
        } else {
          throw new UnsupportedError(
              "Writing of content type:${type} is not supported.");
        }
      });
    }

    if (path[0] == '/') path = path.substring(1);
    List<String> pathParts = path.split('/');
    if (pathParts.length != 1) {
      return createDirectoryRecursive(root, path.substring(0,
          path.lastIndexOf('/'))).then((dir) {
        return createFile(dir, pathParts[pathParts.length - 1]);
      });
    } else {
      return createFile(root, path);
    }
  }

  static Future<dynamic> readFile(chrome.DirectoryEntry root, String path,
      String type) {
    Completer<String> completer = new Completer();
    root.getFile(path).then((chrome.ChromeFileEntry entry) {
      //TODO(grv): Implement a general read function, supporting different
      // formats.
      entry.readText().then((String content){
        completer.complete(content);
      });

    });
    return completer.future;
  }

  /**
   * Lists the files in a given [root] directory.
   */
  static Future<List<chrome.Entry>> listFiles(chrome.DirectoryEntry root) {
    return root.createReader().readEntries();
  }

  /**
   * Reads a given [blob] as a given [type].
   */
  static Future readBlob(chrome.Blob blob, String type) {
    Completer completer = new Completer();
    var reader = new JsObject(context['FileReader']);
    reader['onload'] = (var event) {
      completer.complete(reader['result']);
    };

    reader['onerror'] = (var domError) {
      completer.completeError(domError);
    };

    reader.callMethod('readAs' + type, [blob]);
    return completer.future;
  }
}
