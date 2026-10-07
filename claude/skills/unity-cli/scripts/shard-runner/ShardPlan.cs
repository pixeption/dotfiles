using System;
using System.Collections.Generic;
using System.Linq;

namespace UnitySuite
{
    // Pure planning, no Unity types, so tests/shard-plan.sh can compile it with plain dotnet.
    public static class ShardPlan
    {
        // Longest-processing-time packing of tests into `shards` bins. A fixture stays whole unless it
        // alone outweighs a bin; an unseen test weighs the median. Every tie breaks by ordinal name,
        // so every shard computes the same, disjoint, covering split from the same inputs.
        public static List<string>[] Pack(IEnumerable<(string Name, string Fixture)> tests,
                                          IReadOnlyDictionary<string, double> durations, int shards)
        {
            var all = tests.OrderBy(t => t.Name, StringComparer.Ordinal).ToList();
            var median = Median(all.Where(t => durations.ContainsKey(t.Name)).Select(t => durations[t.Name]));
            double Weight(string name) => durations.TryGetValue(name, out var d) ? d : median;

            var bin = all.Sum(t => Weight(t.Name)) / shards;
            var items = all.GroupBy(t => t.Fixture, StringComparer.Ordinal)
                .SelectMany(f => Split(f.Select(t => t.Name).ToList(), Weight, bin))
                .Select(names => (Names: names, Weight: names.Sum(Weight)))
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
        private static IEnumerable<List<string>> Split(List<string> names, Func<string, double> weight, double bin)
        {
            var total = names.Sum(weight);
            var groups = bin > 0 ? (int)Math.Ceiling(total / bin) : 1;
            if (groups <= 1)
            {
                yield return names;
                yield break;
            }
            var group = new List<string>();
            var done = 0.0;
            var made = 0;
            foreach (var name in names)
            {
                group.Add(name);
                done += weight(name);
                if (made < groups - 1 && done >= total * (made + 1) / groups)
                {
                    yield return group;
                    group = new List<string>();
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
