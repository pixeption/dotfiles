using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace UnitySuite
{
    // Pure planning, no Unity types, so tests/shard-plan.sh can compile it with plain dotnet.
    public static class ShardPlan
    {
        // Mirrors a batch run's selection: --filter is a regex per |-term on the full name, --category
        // one name, kept (Name) or excluded (!Name).
        public static bool Selected(string name, IEnumerable<string> categories, string filter, string category)
        {
            var byName = string.IsNullOrEmpty(filter) || filter.Split('|').Any(term => Regex.IsMatch(name, term));
            if (!byName || string.IsNullOrEmpty(category)) return byName;
            return categories.Contains(category.TrimStart('!')) != category.StartsWith("!");
        }

        // Longest-processing-time packing of tests into `shards` bins. A fixture stays whole unless it
        // alone outweighs a bin. An unseen test weighs its fixture's mean, else the median: a new case
        // of a slow parameterized fixture is as slow as its siblings. Every tie breaks by ordinal name,
        // so every shard computes the same, disjoint, covering split from the same inputs.
        public static List<string>[] Pack(IEnumerable<(string Name, string Fixture)> tests,
                                          IReadOnlyDictionary<string, double> durations, int shards)
        {
            var all = tests.OrderBy(t => t.Name, StringComparer.Ordinal).ToList();
            var known = all.Where(t => durations.ContainsKey(t.Name)).ToList();
            var median = Median(known.Select(t => durations[t.Name]));
            var fixtureMean = known.GroupBy(t => t.Fixture, StringComparer.Ordinal)
                .ToDictionary(f => f.Key, f => f.Average(t => durations[t.Name]), StringComparer.Ordinal);
            double Weight((string Name, string Fixture) t) =>
                durations.TryGetValue(t.Name, out var d) ? d : fixtureMean.TryGetValue(t.Fixture, out var mean) ? mean : median;

            var bin = all.Sum(Weight) / shards;
            var items = all.GroupBy(t => t.Fixture, StringComparer.Ordinal)
                .SelectMany(f => Split(f.ToList(), Weight, bin))
                .Select(group => (Names: group.Select(t => t.Name).ToList(), Weight: group.Sum(Weight)))
                .OrderByDescending(i => i.Weight).ThenBy(i => i.Names[0], StringComparer.Ordinal);

            var bins = Enumerable.Range(0, shards).Select(_ => new List<string>()).ToArray();
            var loads = new double[shards];
            foreach (var item in items)
            {
                var lightest = Array.IndexOf(loads, loads.Min());
                bins[lightest].AddRange(item.Names);
                loads[lightest] += item.Weight;
            }
            return bins;
        }

        // A fixture heavier than a bin becomes ceil(weight / bin) consecutive method groups of
        // about equal weight; any other fixture is one item.
        private static IEnumerable<List<T>> Split<T>(List<T> tests, Func<T, double> weight, double bin)
        {
            var total = tests.Sum(weight);
            var groups = bin > 0 ? (int)Math.Ceiling(total / bin) : 1;
            if (groups <= 1)
            {
                yield return tests;
                yield break;
            }
            var group = new List<T>();
            var done = 0.0;
            var made = 0;
            foreach (var test in tests)
            {
                group.Add(test);
                done += weight(test);
                if (made < groups - 1 && done >= total * (made + 1) / groups)
                {
                    yield return group;
                    group = new List<T>();
                    made++;
                }
            }
            if (group.Count > 0) yield return group;
        }

        private static double Median(IEnumerable<double> values)
        {
            var sorted = values.OrderBy(v => v).ToList();
            return sorted.Count == 0 ? 1 : sorted[sorted.Count / 2];
        }
    }
}
