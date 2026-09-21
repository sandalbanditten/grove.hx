# Merge File tree runs instead of Steel sort

Steel 0.8.3's `sort` degrades to quadratic time on nearly ordered input: 4000
already ascending values cost 1333ms against 18ms for the same values
scrambled, and 2000 cost 340ms. A directory listing arrives nearly ordered, so
every File tree scan hit that worst case with a comparator that reads paths.
Scanning one directory cost 745ms at 500 entries, 11.8s at 2000, and 48.5s at
4000. Grove observes synchronously on the Helix thread (ADR 0002, ADR 0003), so
each scan froze the editor for that whole time.

`tree.build` therefore merges its own ascending runs instead of calling `sort`.
Run detection keeps an already ordered listing linear and merging keeps the
scrambled case `n log n`. The same scans now cost 15ms, 41ms, and 114ms.

Revisit when Grove runs a Steel build whose `sort` is `n log n` on ordered
input and the scan benchmarks stay within these numbers without the merge.
