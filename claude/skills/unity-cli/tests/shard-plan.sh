#!/usr/bin/env bash
# Offline test for the shard runner's planner (scripts/shard-runner/ShardPlan.cs), compiled with
# plain dotnet: the split is deterministic whatever the input order, disjoint, covers every test,
# keeps a fixture lighter than a bin whole and splits one heavier than a bin.
set -uo pipefail
command -v dotnet >/dev/null || { echo "FAIL: dotnet not on PATH - install the .NET SDK"; exit 1; }
PLAN="$(cd "$(dirname "$0")/.." && pwd)/scripts/shard-runner/ShardPlan.cs"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/t.csproj" <<XML
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net9.0</TargetFramework></PropertyGroup>
  <ItemGroup><Compile Include="$PLAN" /></ItemGroup>
</Project>
XML
cat >"$TMP/Program.cs" <<'CS'
using System;
using System.Collections.Generic;
using System.Linq;
using UnitySuite;

var tests = new List<(string Name, string Fixture)>();
var durations = new Dictionary<string, double>();
for (var f = 0; f < 30; f++)
    for (var m = 0; m < 3 + f % 7; m++)
    {
        var name = $"Ns.F{f:D2}.M{m}";
        tests.Add((name, $"Ns.F{f:D2}"));
        if ((f + m) % 4 != 0) durations[name] = 0.5 + (f * 7 + m * 3) % 11;
    }
for (var m = 0; m < 40; m++)
{
    tests.Add(($"Ns.Huge.M{m:D2}", "Ns.Huge"));
    durations[$"Ns.Huge.M{m:D2}"] = 9;
}

var failed = 0;
void Check(bool ok, string what)
{
    Console.WriteLine((ok ? "ok   " : "FAIL ") + what);
    if (!ok) failed++;
}
int BinsHolding(List<string>[] bins, string fixture) => bins.Count(b => b.Any(n => n.StartsWith(fixture + ".")));

var shuffled = tests.OrderBy(t => t.Name.GetHashCode() ^ 0x5bd1e995).ToList();
for (var n = 1; n <= 8; n++)
{
    var bins = ShardPlan.Pack(tests, durations, n);
    var again = ShardPlan.Pack(shuffled, durations, n);
    var all = bins.SelectMany(b => b).ToList();
    Check(bins.Length == n && bins.Zip(again, (a, b) => a.SequenceEqual(b)).All(x => x), $"N={n}: same split from a reordered list");
    Check(all.Count == all.Distinct().Count(), $"N={n}: bins are disjoint");
    Check(all.OrderBy(x => x, StringComparer.Ordinal).SequenceEqual(tests.Select(t => t.Name).OrderBy(x => x, StringComparer.Ordinal)), $"N={n}: bins cover every test");
}
var four = ShardPlan.Pack(tests, durations, 4);
Check(BinsHolding(four, "Ns.Huge") > 1, "a fixture heavier than a bin is split");
Check(Enumerable.Range(0, 30).All(f => BinsHolding(four, $"Ns.F{f:D2}") == 1), "a fixture lighter than a bin stays whole");
var two = tests.Where(t => t.Name.EndsWith(".M1") && t.Fixture.CompareTo("Ns.F02") < 0);
Check(ShardPlan.Pack(two, durations, 4).Count(b => b.Count == 0) == 2, "more shards than tests leaves bins empty");
return failed == 0 ? 0 : 1;
CS
out=$(dotnet run --project "$TMP/t.csproj" 2>&1); code=$?
printf '%s\n' "$out" | grep -E '^(ok|FAIL) |error' 
exit $code
