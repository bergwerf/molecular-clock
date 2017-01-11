// Copyright (c) 2017, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

import 'dart:io';
import 'dart:async';

import 'package:molecular_clock/pbdb.dart';
import 'package:molecular_clock/uniprot.dart';
import 'package:levenshtein/levenshtein.dart';
import 'package:csv/csv.dart';

/// Input genes
List<List<String>> genes = [
//  ['HBA1', 'Hemoglobin subunit alpha 1'],
//  ['HBA2', 'Hemoglobin subunit alpha 2'],
  ['HBB', 'Hemoglobin subunit beta']
];

/// Taxonomy data for various organisms.
Map<String, List<TaxonInfo>> organisms = {};

/// Data collected per gene.
class CollectedData {}

Future main() async {
  for (final gene in genes) {
    // Retrieve sequences.
    final uniprotData = await uniprotGet('gene:${gene[0]}',
        ['id', 'genes', 'protein names', 'organism', 'sequence']);

    // Collect one sequence per organism.
    print('Retrieved sequence data.');
    Map<String, String> sequences = {};
    for (final record in uniprotData) {
      if (record['protein names'].startsWith(new RegExp('${gene[1]}\\s?'))) {
        final organismRe = new RegExp(r'^([a-zA-Z\s]+)\(?');
        final match = organismRe.firstMatch(record['organism']);

        if (match != null) {
          sequences[match.group(1).trim()] = record['sequence'];
        }
      }
    }

    // For testing purposes: only use first three sequences.
    final organismNames = sequences.keys.toList();

    // Retrieve parent taxa per organism.
    for (var i = 0; i < organismNames.length; i++) {
      final organism = organismNames[i];
      if (!organisms.containsKey(organism)) {
        final taxa = await pbdbGetTaxa(organism);
        print('[$i/${organismNames.length}] Retrieved taxa for $organism.');
        if (taxa.isNotEmpty) {
          organisms[organism] = taxa;
        } else {
          // Discard this organism.
          organismNames.removeAt(i);
          i--;
        }
      }
    }

    // Table data structures.
    final distanceTable = new List<List>();
    final ancestorTable = new List<List>();
    final clockRateTable = new List<List>();

    // Special tables.
    final ancestorVsRate = new List<List>();
    final countedRate = new List<List>();

    ancestorVsRate.add(['Organism A', 'Organism B', 'Ancestor age', 'Rate']);
    countedRate.add(['Rate [100.000/div]', 'Count']);
    final rateMap = new Map<int, int>();

    // Do all computations.
    for (var i = 0; i < organismNames.length; i++) {
      distanceTable.add(new List());
      ancestorTable.add(new List());
      clockRateTable.add(new List());

      for (var j = 0; j <= i; j++) {
        // Compute edit distance.
        distanceTable.last.add(levenshtein(
            sequences[organismNames[i]], sequences[organismNames[j]]));

        // Compute common ancestor.
        int ancestorAge = 0;
        List<TaxonInfo> orgA = organisms[organismNames[i]];
        List<TaxonInfo> orgB = organisms[organismNames[j]];
        for (var t = 0; t < orgA.length && t < orgB.length; t++) {
          if (orgA[t].id != orgB[t].id) {
            // First non-common taxon: retrieve ages.
            ancestorAge = ((orgA[t].firstAppearanceMax +
                        orgA[t].firstAppearanceMin +
                        orgB[t].firstAppearanceMax +
                        orgB[t].firstAppearanceMin) /
                    4)
                .round();
            break;
          }
        }
        ancestorTable.last.add(ancestorAge);

        if (i != j) {
          // Compute clock rate.
          final clockRate = ancestorAge / distanceTable.last.last;
          clockRateTable.last.add(clockRate);

          // Add to ancestorVsRate.
          ancestorVsRate.add(
              [organismNames[i], organismNames[j], ancestorAge, clockRate]);

          // Add to rateMap.
          final rateDiv = (clockRate / 100000).round();
          rateMap.putIfAbsent(rateDiv, () => 0);
          rateMap[rateDiv]++;
        }
      }
    }

    // Put rateMap into countedRate.
    rateMap.forEach((int div, int count) {
      countedRate.add([div, count]);
    });

    // Save data to files.
    await new File('out/${gene[0]}_edit_distance.csv').writeAsString(
        const ListToCsvConverter()
            .convert(addColumnRowNames(organismNames, distanceTable)));
    await new File('out/${gene[0]}_ancestor.csv').writeAsString(
        const ListToCsvConverter()
            .convert(addColumnRowNames(organismNames, ancestorTable)));
    await new File('out/${gene[0]}_clock_rate.csv').writeAsString(
        const ListToCsvConverter()
            .convert(addColumnRowNames(organismNames, clockRateTable)));
    await new File('out/${gene[0]}_age_vs_rate.csv')
        .writeAsString(const ListToCsvConverter().convert(ancestorVsRate));
    await new File('out/${gene[0]}_counted_rate.csv')
        .writeAsString(const ListToCsvConverter().convert(countedRate));
  }
}

List<List> addColumnRowNames(List<String> names, List<List> data) {
  for (var i = 0; i < data.length; i++) {
    data[i].insert(0, names[i]);
  }
  data.insert(
      0,
      new List<String>.generate(
          names.length + 1, (i) => i == 0 ? '' : names[i - 1]));
  return data;
}
