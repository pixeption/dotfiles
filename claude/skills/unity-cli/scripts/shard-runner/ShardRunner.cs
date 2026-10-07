using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Xml;
using UnityEditor;
using UnityEditor.TestTools.TestRunner.Api;
using UnityEngine;

namespace UnitySuite
{
    // unity-suite --shards installs this into each shard project and launches it as
    //   -batchmode -executeMethod UnitySuite.ShardRunner.Run -shard k/N -timings <report> -shardOut <xml>
    // It runs bin k of N over the current Edit-Mode test list by exact name, writes the NUnit report
    // and a <xml>.plan.json the merge checks it against, then exits 0 (all passed), 2 (a failure) or
    // 3 (the runner itself failed).
    [InitializeOnLoad]
    public sealed class ShardRunner : ScriptableObject, ICallbacks
    {
        private const string OutputKey = "UnitySuite.ShardRunner.Output";

        [Serializable]
        private class Plan
        {
            public int total;
            public string[] explicitTests;
            public string[] tests;
        }

        // Callbacks do not survive a domain reload, and a test may cause one mid-run.
        static ShardRunner()
        {
            if (SessionState.GetString(OutputKey, "") != "") Listen();
        }

        public static void Run()
        {
            try
            {
                var shard = Arg("-shard").Split('/').Select(int.Parse).ToArray();
                var output = Path.GetFullPath(Arg("-shardOut"));
                var timings = Durations(Arg("-timings", required: false));
                var api = CreateInstance<TestRunnerApi>();
                api.RetrieveTestList(TestMode.EditMode, root => Guard(() => Start(api, root, shard[0], shard[1], output, timings)));
            }
            catch (Exception e)
            {
                Abort(e);
            }
        }

        private static void Start(TestRunnerApi api, ITestAdaptor root, int k, int n, string output,
                                  Dictionary<string, double> timings)
        {
            var leaves = Leaves(root).ToList();
            var explicitTests = leaves.Where(IsExplicit).Select(t => t.FullName).OrderBy(x => x, StringComparer.Ordinal).ToArray();
            var runnable = leaves.Where(t => !IsExplicit(t)).Select(t => (t.FullName, Fixture(t)));
            var mine = ShardPlan.Pack(runnable, timings, n)[k - 1].ToArray();

            var plan = new Plan { total = leaves.Count, explicitTests = explicitTests, tests = mine };
            File.WriteAllText(output + ".plan.json", JsonUtility.ToJson(plan));
            Debug.Log($"[ShardRunner] shard {k}/{n}: {mine.Length} of {leaves.Count} tests");

            // An empty testNames filter would run the whole suite.
            if (mine.Length == 0)
            {
                File.WriteAllText(output, "<test-run total=\"0\" passed=\"0\" failed=\"0\" skipped=\"0\" />");
                EditorApplication.Exit(0);
                return;
            }
            SessionState.SetString(OutputKey, output);
            Listen();
            api.Execute(new ExecutionSettings(new Filter { testMode = TestMode.EditMode, testNames = mine }));
        }

        private static void Listen() => TestRunnerApi.RegisterTestCallback(CreateInstance<ShardRunner>());

        public void RunFinished(ITestResultAdaptor result) => Guard(() =>
        {
            var output = SessionState.GetString(OutputKey, "");
            SessionState.EraseString(OutputKey);
            TestRunnerApi.SaveResultToFile(result, output);
            EditorApplication.Exit(result.FailCount > 0 ? 2 : 0);
        });

        public void RunStarted(ITestAdaptor testsToRun) { }
        public void TestStarted(ITestAdaptor test) { }
        public void TestFinished(ITestResultAdaptor result) { }

        private static IEnumerable<ITestAdaptor> Leaves(ITestAdaptor test) =>
            test.IsSuite ? test.Children.SelectMany(Leaves) : new[] { test };

        private static IEnumerable<ITestAdaptor> SelfAndAncestors(ITestAdaptor test)
        {
            for (var t = test; t != null; t = t.Parent) yield return t;
        }

        // A name filter runs an [Explicit] test, which a full run reports as skipped.
        private static bool IsExplicit(ITestAdaptor test) => SelfAndAncestors(test).Any(t => t.RunState == RunState.Explicit);

        // The nearest ancestor that is not a parameterized method's suite.
        private static string Fixture(ITestAdaptor test) =>
            SelfAndAncestors(test.Parent).First(t => t.Method == null || t.Parent == null).FullName;

        private static Dictionary<string, double> Durations(string report)
        {
            var durations = new Dictionary<string, double>();
            if (string.IsNullOrEmpty(report) || !File.Exists(report)) return durations;
            using var reader = XmlReader.Create(report);
            while (reader.ReadToFollowing("test-case"))
                if (double.TryParse(reader.GetAttribute("duration"), NumberStyles.Float, CultureInfo.InvariantCulture, out var d))
                    durations[reader.GetAttribute("fullname")] = d;
            return durations;
        }

        private static string Arg(string name, bool required = true)
        {
            var args = Environment.GetCommandLineArgs();
            var i = Array.IndexOf(args, name);
            if (i >= 0 && i + 1 < args.Length) return args[i + 1];
            if (required) throw new ArgumentException($"missing {name} <value>");
            return null;
        }

        private static void Guard(Action action)
        {
            try { action(); }
            catch (Exception e) { Abort(e); }
        }

        private static void Abort(Exception e)
        {
            Debug.LogException(e);
            EditorApplication.Exit(3);
        }
    }
}
