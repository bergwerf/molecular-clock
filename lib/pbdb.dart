// Copyright (c) 2017, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

library molecular_clock.pbdb;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const pbdbApiRoot = 'https://paleobiodb.org/data1.2';

Future<List<TaxonInfo>> pbdbGetTaxa(String species) async {
  final url =
      '$pbdbApiRoot/taxa/list.json?name=$species&rel=all_parents&show=app';
  final response = await http.get(url);

  // Decode response.
  final data = JSON.decode(response.body);
  final rows = new List<TaxonInfo>();
  for (Map<String, dynamic> row in data['records']) {
    // If any of the row values is not present: discard this call and return an
    // empyt list.
    if (!const ['oid', 'rid', 'nam', 'noc', 'fea', 'fla']
        .every((key) => row.containsKey(key))) {
      return [];
    }

    rows.add(new TaxonInfo.from(row));
  }

  return rows;
}

class TaxonInfo {
  final int id, referenceId;
  final String name;
  final int numberOfOccurences;
  final int firstAppearanceMax, firstAppearanceMin;

  TaxonInfo(this.id, this.referenceId, this.name, this.numberOfOccurences,
      this.firstAppearanceMax, this.firstAppearanceMin);

  factory TaxonInfo.from(Map<String, dynamic> data) {
    String oid = data['oid'];
    final id = int.parse(oid.substring(4));

    String rid = data['rid'];
    final referenceId = int.parse(rid.substring(4));

    return new TaxonInfo(
        id,
        referenceId,
        data['nam'],
        data['noc'],
        ((data['fea'] as num) * 1000000).round(),
        ((data['fla'] as num) * 1000000).round());
  }
}
