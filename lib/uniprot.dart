// Copyright (c) 2017, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

library molecular_clock.uniprot;

import 'dart:async';

import 'package:http/http.dart' as http;

const uniprotApiRoot = 'http://www.uniprot.org/uniprot/';

/// Request data.
Future<List<Map<String, String>>> uniprotGet(
    String query, List<String> columns) async {
  final columnsStr = new List<String>.generate(
      columns.length, (i) => Uri.encodeComponent(columns[i])).join(',');
  final url = '$uniprotApiRoot?query=$query&format=tab&columns=$columnsStr';
  final response = await http.get(url);

  // Response data structure.
  final data = new List<Map<String, String>>();

  // Note: skip first line (column headers).
  for (final line in response.body.split('\n').sublist(1)) {
    final cols = line.split('\t');
    if (cols.length != columns.length) {
      continue;
    }

    data.add(new Map<String, String>());
    for (var i = 0; i < cols.length; i++) {
      data.last[columns[i]] = cols[i];
    }
  }

  return data;
}
