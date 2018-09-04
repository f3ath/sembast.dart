# Performance result

## PC Test 1 (i5-4460 16Gb SSD) Ubuntu

i5-4460 CPU @ 3.20GHz 16Gb SSD 120Gb SATA3 Ubuntu 18.04

Generated from `test/database_perf_io_test.dart`

### Version 1.9.1+1

|nb records|times|transaction|size kb|elapsed ms|
|---|---|---|---|---|
|1|1| |11|6|
|10|1| |11|10|
|100|1| |11|104|
|100|20| |11|1484|
|1000|1| |11|309|
|1000|5| |11|2365|
|1|1| |10890|0|
|10|1| |10890|4|
|100|1| |10890|37|
|100|20| |10890|2042|
|1000|1| |10890|357|
|1000|5| |10890|4164|
|100|1|1|11|9|
|100|1|5|11|69|
|100|1|10|11|144|
|100|20|1|11|26|
|1000|1|1|11|79|
|1000|5|1|11|110|
|1000|20|1|11|223|
|10000|1|1|11|757|
|10000|5|1|11|1044|
|100|1|1|10890|13|
|100|20|1|10890|33|
|1000|1|1|10890|154|
|1000|5|1|10890|227|
|1000|5|5|10890|1674|
|1000|5|10|10890|3695|
|1000|20|1|10890|314|
|10000|1|1|10890|1797|
|10000|5|1|10890|1978|