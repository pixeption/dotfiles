#!/usr/bin/env python3
"""Build bees-context-tally's fixture projects (see tests/bees-context-tally.sh for the runs).

  context-tally-build.py <project-dir> <second-project-dir>

Lines follow the real sub-agent transcript shape: one JSONL line per content block, the lines of a
response share its message.id and input usage, and only its last line carries output_tokens_details.
"""
import base64, json, struct, sys
from pathlib import Path

S1, S2, S3 = ("11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222",
              "33333333-3333-3333-3333-333333333333")
MISSING = object()
PAUSE = "Context at 40k: stop at the next safe point and pause per your standing rules (Outcome: Paused)."
WARN = "Context at 30k: finish the current step; if more than a few steps of this unit remain, plan to pause at 45k."


class Run:
    def __init__(self, root, sid, aid, agent_type, effort, start):
        self.dir = Path(root) / sid / "subagents"
        self.dir.mkdir(parents=True, exist_ok=True)
        self.sid, self.aid, self.effort, self.t, self.lines, self.n = sid, aid, effort, start, [], 0
        if agent_type:
            (self.dir / f"agent-{aid}.meta.json").write_text(json.dumps({"agentType": agent_type}))

    def line(self, **kw):
        h, m, s = self.t
        self.lines.append({"isSidechain": True, "agentId": self.aid, "sessionId": self.sid,
                           "timestamp": f"{h}:{m:02d}:{s:02d}.000Z", **kw})
        self.t = (h, m, s + 5) if s < 55 else (h, m + 1, 0)

    def prompt(self, text="brief"):
        self.line(type="user", message={"role": "user", "content": text})

    def asst(self, ctx, blocks, thinking=MISSING):
        self.n += 1
        mid = f"msg_{self.aid}_{self.n}"
        for i, b in enumerate(blocks):
            if b["type"] == "tool_use":
                b = {**b, "id": f"toolu_{self.aid}_{self.n}"}
            last = i == len(blocks) - 1
            usage = {"input_tokens": 2, "cache_creation_input_tokens": 1000, "cache_read_input_tokens": ctx - 1002,
                     "output_tokens": 300 if last else 8}
            if last and thinking is not MISSING:
                usage["output_tokens_details"] = {"thinking_tokens": thinking}
            extra = {"effort": self.effort} if self.effort else {}
            self.line(type="assistant", **extra, message={"model": "claude-opus-5-5", "id": mid, "type": "message",
                      "role": "assistant", "content": [b], "usage": usage})

    def result(self, content):
        self.line(type="user", message={"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": f"toolu_{self.aid}_{self.n}", "content": content}]})

    def attach(self, att):
        self.line(type="attachment", attachment=att)

    def write(self):
        with open(self.dir / f"agent-{self.aid}.jsonl", "w") as f:
            f.writelines(json.dumps(l) + "\n" for l in self.lines)


def tool(name, **inp):
    return {"type": "tool_use", "name": name, "input": inp}


THINK = {"type": "thinking", "thinking": "", "signature": "sig"}
def text(t): return {"type": "text", "text": t}
def bash_x(): return tool("Bash", command="x")  # input {"command":"x"}: 15 characters
PAD = 3500 - 15  # a tool result that brings the interval's visible content to 1,000 tokens


def png(w, h):
    head = b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", w, h) + b"\x08\x06\x00\x00\x00"
    return base64.b64encode(head).decode() + "A" * 35000


def build(root, root2):
    r = Run(root, S1, "adone", "bee-opus-medium", "medium", ("2026-10-01T10", 0, 0))
    r.prompt()
    r.asst(10000, [THINK, text("Reading."), tool("Read", file_path="/u/.claude/skills/unity-cli/SKILL.md")], 200)
    r.result("s" * 7000)
    r.attach({"type": "total_tokens_reminder", "text": "<total_tokens>1 tokens left</total_tokens>"})
    r.asst(13000, [tool("Read", file_path="/r/docs/plans/2026-10-01-foo.md")], 0)
    r.result("p" * 3500)
    r.asst(15000, [tool("Read", file_path="/r/docs/plans/2026-10-01-foo.md", offset=10, limit=20)])
    r.result("q" * 350)
    r.asst(16000, [tool("Bash", command=f"cat /p/{S1}/tool-results/b1.txt")])
    r.result("t" * 1750)
    r.asst(17000, [tool("Bash", command='cat "$f"')])
    r.result("u" * 700)
    r.asst(18000, [tool("Bash", command="cat /r/docs/plans/x.md | head -5; cat /p/skills/a/SKILL.md /r/docs/plans/y.md")])
    r.result("v" * 1400)
    r.asst(19000, [tool("Read", file_path="/r/shot.png")])
    r.result([{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": png(300, 250)}}])
    r.asst(20000, [tool("Bash", command="cat > /r/docs/plans/z.md <<'EOF'\nhello\nEOF")])
    r.result("")
    r.asst(21000, [text("Outcome: Done\nBEES: results=SA-05:done:abc1234")])
    r.write()

    r = Run(root, S1, "aval", "bee-opus-high", "high", ("2026-10-01T11", 0, 0))
    r.prompt()
    r.asst(10000, [THINK, bash_x()], 1000); r.result("r" * PAD)
    r.asst(12000, [bash_x()], 0); r.result("r" * PAD)
    r.asst(13000, [bash_x()]); r.result("r" * PAD)
    r.asst(14500, [THINK, bash_x()], 500); r.result("r" * PAD)
    r.attach({"type": "skill_listing", "content": "?", "names": []})
    r.asst(16500, [THINK, bash_x()], 400); r.result("r" * PAD)
    r.asst(18100, [text("Outcome: Done\nBEES: results=SA-05:done:abc1234")])
    r.write()

    r = Run(root, S1, "aedge", "bee-opus-low", "low", ("2026-10-01T14", 0, 0))
    r.prompt()
    r.asst(5000, [tool("Bash", command='cat "$root/docs/plans/x.md"')], -5); r.result("a" * 350)
    r.asst(6000, [tool("Read", file_path="/r/docs/plans/m.md")], float("nan"))
    r.asst(7000, [tool("Bash", command="cat /p/skills/b/SKILL.md; cat /r/docs/plans/w.md")], float("inf"))
    r.result("w" * 700)
    r.asst(8000, [text("Outcome: Done\nBEES: results=SA-05:done:abc1234")])
    r.write()

    r = Run(root, S1, "alow", "bee-opus-low", "low", ("2026-10-01T12", 0, 0))
    r.prompt()
    r.asst(5000, [bash_x()], 0); r.result("r" * PAD)
    r.asst(6000, [text("Outcome: Done\nBEES: results=SA-05:done:abc1234")])
    r.write()

    r = Run(root, S1, "apause", "bee-opus-high", "high", ("2026-10-01T13", 0, 0))
    r.prompt()
    r.asst(30000, [bash_x()]); r.result("r" * 10)
    r.attach({"type": "hook_additional_context", "content": [WARN], "hookEvent": "PostToolUse"})
    r.asst(40000, [bash_x()]); r.result("r" * 10)
    r.attach({"type": "hook_additional_context", "content": [PAUSE], "hookEvent": "PostToolUse"})
    r.asst(46000, [bash_x()]); r.result("r" * 10)
    r.asst(48000, [text("Outcome: Paused\nBEES: results=SA-01:paused:-")])
    r.write()

    r = Run(root, S2, "acomp", None, None, ("2026-10-02T10", 0, 0))
    r.prompt()
    r.asst(50000, [bash_x()]); r.result("r" * 10)
    r.asst(60000, [bash_x()]); r.result("r" * 10)
    r.line(type="system", subtype="compact_boundary", content="Conversation compacted")
    r.line(type="user", isCompactSummary=True, message={"role": "user", "content": "summary"})
    r.asst(8000, [bash_x()]); r.result("r" * 10)
    r.asst(9000, [text("Stopped.")])
    r.write()

    r = Run(root, S3, "alate", "bee-opus-low", "low", ("2026-10-03T00", 0, 0))
    r.prompt()
    r.asst(1000, [bash_x()]); r.result("r")
    r.asst(2000, [text("BEES: results=X-01:done:abc1234")])
    r.write()

    r = Run(root2, S1, "aempty", "bee-opus-low", "low", ("2026-10-01T10", 0, 0))
    r.prompt()
    r.write()


build(sys.argv[1], sys.argv[2])
