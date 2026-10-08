import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { AgentStatus, On, SessionUsage } from 'claude-code'

const MINUTE = 60_000

const hive = (on: On, opts: { tokens: number; type?: string; status?: AgentStatus; startedAt?: number }) => {
  const clock = mock.clock(on, { now: 0 })
  const { type = 'bee-opus-low', status = 'completed', startedAt = 0 } = opts
  mock.env(on, { HOME: '/home', KITTY_LISTEN_ON: 'unix:/tmp/kitty-1', KITTY_WINDOW_ID: '12' })
  on('fs.read', (_$, e) => ({ value: e.path === `/home/.claude/agents/${type}.md` ? '---\nmodel: claude-opus-5-5\neffort: low\n---\n' : '' }))
  on('agent.list', () => ({ value: [{ id: 'a1', name: 'worker', description: 'unit', type, status }] }))
  on('turn.step', async function* () {
    const usage = { input_tokens: 1, output_tokens: 0, cache_read_input_tokens: opts.tokens - 1, cache_creation_input_tokens: 0, model: 'm' }
    return { turnId: 't', index: 0, answer: '', toolUses: [], stopReason: 'end_turn' as const, usage }
  })
  on('session.send', () => ({ isDelivered: true as const }))
  on('session.usage', () => ({ value: { startedAt } as SessionUsage }))
  return clock
}

const stepAs = async ($: Engine, agentId: string) => {
  const stream = $.turn.step({ turnId: 't', index: 0, model: 'm', messageCount: 1, agentId })
  for await (const _ of stream);
}

const send = ($: Engine, text = 'next unit') =>
  $.session.send({ to: 'worker', text, origin: { kind: 'model' } })

test('a warm bee under the continue line gets the message', async ($, on) => {
  hive(on, { tokens: 149_000 })
  await stepAs($, 'a1')
  expect((await send($)).isDelivered).toBe(true)
})

test('a warm bee at the continue line is refused', async ($, on) => {
  hive(on, { tokens: 150_000 })
  await stepAs($, 'a1')
  const sent = await send($)
  expect(sent.isDelivered).toBe(false)
  expect(sent.reason).toMatch(/continue line/)
})

test('a bee at the retire line is refused', async ($, on) => {
  hive(on, { tokens: 200_000 })
  await stepAs($, 'a1')
  const sent = await send($)
  expect(sent.isDelivered).toBe(false)
  expect(sent.reason).toMatch(/retire/)
})

test('a handover message reaches a bee past the retire line', async ($, on) => {
  hive(on, { tokens: 250_000 })
  await stepAs($, 'a1')
  expect((await send($, '[bees:handover] stop at a safe point')).isDelivered).toBe(true)
})

test('a cold bee at 100k or more is refused', async ($, on) => {
  const clock = hive(on, { tokens: 100_000 })
  await stepAs($, 'a1')
  await clock.advance(6 * MINUTE)
  expect((await send($)).reason).toMatch(/cold/)
})

test('a cold bee under 100k gets the message', async ($, on) => {
  const clock = hive(on, { tokens: 90_000 })
  await stepAs($, 'a1')
  await clock.advance(6 * MINUTE)
  expect((await send($)).isDelivered).toBe(true)
})

test('a running bee is never cold', async ($, on) => {
  const clock = hive(on, { tokens: 120_000, status: 'running' })
  await stepAs($, 'a1')
  await clock.advance(30 * MINUTE)
  expect((await send($)).isDelivered).toBe(true)
})

test('agents that are not bees pass untouched', async ($, on) => {
  hive(on, { tokens: 300_000, type: 'general-purpose' })
  await stepAs($, 'a1')
  expect((await send($)).isDelivered).toBe(true)
})

const mountBand = ($: Engine) =>
  $.ui.mount({
    plugin: 'bees-budget',
    surface: 'terminal',
    component: 'AbovePrompt',
    props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100, scroll: { offset: 0, bodyRows: 10 }, view: {} },
  })

const band = async ($: Engine) => {
  const ui = await mountBand($)
  return (await ui.findAll({})).map(t => t.text).filter(Boolean).join(' ')
}

test('the band shows a bee warm with its countdown, then cold past the clock', async ($, on) => {
  const clock = hive(on, { tokens: 120_000 })
  await stepAs($, 'a1')
  await clock.advance(2 * MINUTE)
  expect(await band($)).toMatch(/claude opus-low worker 120k warm 3m/)
  await clock.advance(4 * MINUTE)
  expect(await band($)).toMatch(/worker 120k cold · spawn fresh/)
})

type Codex = { id: string; label: string; tokens: number; at: number; createdAt?: number; isRunning: 0 | 1 }

const codexWorld = (on: On, clock: { advance: (ms: number) => Promise<void> }) => {
  const sessions: Codex[] = []
  const ran: string[][] = []
  let bashOut = ''
  on('tool.call', { tool: 'Bash' }, () => ({ result: { stdout: bashOut, stderr: '', interrupted: false } }))
  on('process.run', (_$, e) => {
    ran.push([...e.argv])
    const rows = sessions.map(s => ({ createdAt: 0, directory: '/repo', model: 'gpt-6.1-sol', effort: 'high', ...s }))
    const stdout = e.argv[0] === 'sqlite3' ? JSON.stringify(rows) : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('session.start', () => ({ cwd: '/repo' }))
  return {
    ran,
    launch: ($: Engine, command: string, stdout = '') => {
      bashOut = stdout
      return $.tool.call({ tool: 'Bash', command })
    },
    show: async ($: Engine, shown: Codex[]) => {
      sessions.push(...shown)
      await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
      await clock.advance(15_000)
    },
  }
}

const IMPLEMENT = 'opencode-implement -C /repo -o /tmp/impl-G1-r1.txt --title GAP-05a -- brief'

test('the band shows a codex session as vendor, model-effort, title and its 30-minute clock', async ($, on) => {
  const clock = hive(on, { tokens: 1, type: 'general-purpose' })
  const codex = codexWorld(on, clock)
  await codex.launch($, IMPLEMENT)
  await clock.advance(60 * MINUTE)
  await codex.show($, [{ id: 's1', label: 'GAP-05a', tokens: 120_000, at: clock.now() - 20 * MINUTE, isRunning: 0 }])
  expect(await band($)).toMatch(/codex sol-high GAP-05a 120k warm 10m/)
})

test('the band shows a codex session mid-round as running', async ($, on) => {
  const clock = hive(on, { tokens: 1, type: 'general-purpose' })
  const codex = codexWorld(on, clock)
  await codex.launch($, IMPLEMENT)
  await clock.advance(60 * MINUTE)
  await codex.show($, [{ id: 's1', label: 'GAP-05a', tokens: 101_000, at: clock.now() - 40 * MINUTE, isRunning: 1 }])
  expect(await band($)).toMatch(/GAP-05a 101k running/)
})

test('the band shows only codex sessions this session launched or resumed', async ($, on) => {
  const clock = hive(on, { tokens: 1, type: 'general-purpose' })
  const codex = codexWorld(on, clock)
  await clock.advance(10 * MINUTE)
  await codex.launch($, IMPLEMENT)
  await codex.launch($, "opencode-review -o '/tmp/plan.md' -- brief", 'session ses_resumed pinned to /repo')
  await codex.show($, [
    { id: 's1', label: 'GAP-05a', tokens: 10_000, at: clock.now(), createdAt: clock.now(), isRunning: 1 },
    { id: 's2', label: 'review plan.md', tokens: 10_000, at: clock.now(), createdAt: clock.now(), isRunning: 1 },
    { id: 'ses_resumed', label: 'GAP-01', tokens: 10_000, at: clock.now(), isRunning: 1 },
    { id: 's3', label: 'GAP-10a', tokens: 10_000, at: clock.now(), createdAt: clock.now(), isRunning: 1 },
    { id: 's4', label: 'GAP-05a', tokens: 10_000, at: clock.now(), createdAt: 0, isRunning: 1 },
  ])
  const rows = await (await mountBand($)).findAll({ type: 'Button' })
  expect(rows.map(r => r.text)).toEqual(['GAP-05a', 'review plan.md', 'GAP-01'])
})

test('the band drops codex sessions from before a /clear', async ($, on) => {
  const clock = hive(on, { tokens: 1, type: 'general-purpose', startedAt: 50 * MINUTE })
  const codex = codexWorld(on, clock)
  await codex.launch($, 'opencode-implement -s ses_old -s ses_new -- brief')
  await clock.advance(60 * MINUTE)
  await codex.show($, [
    { id: 'ses_old', label: 'review-r1.txt', tokens: 106_000, at: clock.now() - 20 * MINUTE, isRunning: 0 },
    { id: 'ses_new', label: 'impl-r1.txt', tokens: 40_000, at: clock.now() - 5 * MINUTE, isRunning: 0 },
  ])
  const shown = await band($)
  expect(shown).toMatch(/impl-r1.txt/)
  expect(shown).not.toMatch(/review-r1/)
})

test('clicking a codex row attaches to it in a kitty vertical split beside this window', async ($, on) => {
  const clock = hive(on, { tokens: 1, type: 'general-purpose' })
  const codex = codexWorld(on, clock)
  await codex.launch($, IMPLEMENT)
  await codex.show($, [{ id: 's1', label: 'GAP-05a', tokens: 101_000, at: clock.now(), isRunning: 1 }])
  await (await mountBand($)).press({ key: 's1' })
  expect(codex.ran.find(argv => argv[0] === 'kitty')).toEqual([
    'kitty', '@', '--to', 'unix:/tmp/kitty-1', 'launch', '--location=vsplit', '--next-to=id:12', '--cwd', '/repo',
    '--title', 'codex GAP-05a', 'opencode', 'attach', 'http://127.0.0.1:4096', '--dir', '/repo', '--session', 's1',
  ])
})
