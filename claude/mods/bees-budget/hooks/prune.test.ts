import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { SessionMessage, ToolUseSummary } from 'claude-code'

import { PRUNE, PRUNE_IF_LARGER } from './prune'

const prompt = (text: string): SessionMessage => ({ role: 'user', text, toolUses: [] })
const said = (text: string, ...toolUses: ToolUseSummary[]): SessionMessage => ({ role: 'assistant', text, toolUses })
const bash = (id: string, command: string): ToolUseSummary => ({ tool_use_id: id, tool: 'Bash', input: { command } })
const ran = (id: string, text: string): SessionMessage =>
  ({ role: 'user', text: '', toolUses: [], toolResults: [{ tool_use_id: id, text, isError: false }] })

const opening = [prompt('run phase 1: STEP-1 and STEP-10'), said('spawning both')]
const accepted = [
  prompt('STEP-1 hand-back: done'), said('', bash('t1', 'git log -1 STEP-1')), ran('t1', `abc feat: STEP-1\n${'+'.repeat(2_000)}`),
  said('accepted\nBEES: done=STEP-1'),
]
const inFlight = [prompt('STEP-10 hand-back: blocked'), said('', bash('t2', 'cat report-STEP-10.md')), ran('t2', 'blocked'), said('rebrief')]
const acceptAndSpawn = [prompt('STEP-1 review: approve'), said('BEES: done=STEP-1\nspawning STEP-2')]
const spawnOtherFamily = [
  prompt('STEP-1 recheck: approve'),
  said('BEES: done=STEP-1', bash('t3', 'opencode-implement -o docs/plans/p.work/impl-FIX-01-r1.txt')), ran('t3', 'started'),
]
const notifiedMidTool = [
  prompt('STEP-1 final pass'), said('', bash('t4', 'git log STEP-1')), prompt('STEP-10 hand-back: done'),
  ran('t4', 'abc'), said('BEES: done=STEP-1'),
]
const findingOfDone = [prompt('MAJ-01 of STEP-1 is fixed'), said('ok')]
const transcript = [...opening, ...accepted, ...inFlight, ...acceptAndSpawn, ...findingOfDone]

const compact = ($: Engine, messages: SessionMessage[], instructions = PRUNE) =>
  $.session.compact({ trigger: 'plugin', instructions, messages })

test('a prune drops whole turns about done units and keeps any turn naming a unit in flight', async ($, on) => {
  on('session.compact', () => ({ skip: 'core reached' }))
  const pruned = await compact($, transcript)
  expect(pruned.messages?.[0]?.text).toMatch(/^\[bees\].*\nBEES: done=STEP-1$/)
  expect(pruned.messages?.slice(1)).toEqual([...opening, ...inFlight, ...acceptAndSpawn])
})

test('a second prune replaces the note and keeps every done id in it', async ($, on) => {
  on('session.compact', () => ({ skip: 'core reached' }))
  const first = (await compact($, transcript)).messages ?? []
  const second = await compact($, [...first, prompt('STEP-10 recheck: approve'), said('BEES: done=STEP-10')])
  expect(second.messages?.[0]?.text).toMatch(/BEES: done=STEP-1,STEP-10$/)
  expect(second.messages?.slice(1)).toEqual([...opening, ...acceptAndSpawn])
})

test('a prune with nothing finished leaves the conversation as it is', async ($, on) => {
  on('session.compact', () => ({ skip: 'core reached' }))
  expect((await compact($, [...opening, ...inFlight])).skip).toMatch(/no finished units/)
})

test('a prune asked only if the finished units outweigh the rest waits until they do', async ($, on) => {
  on('session.compact', () => ({ skip: 'core reached' }))
  const longInFlight = [prompt('STEP-10 hand-back'), said('x'.repeat(4_000))]
  expect((await compact($, [...transcript, ...longInFlight], PRUNE_IF_LARGER)).skip).toMatch(/still smaller/)
  expect((await compact($, transcript, PRUNE_IF_LARGER)).messages?.slice(1)).toEqual([...opening, ...inFlight, ...acceptAndSpawn])
})

test('a turn that starts the first unit of another family is kept', async ($, on) => {
  on('session.compact', () => ({ skip: 'core reached' }))
  expect((await compact($, [...transcript, ...spawnOtherFamily])).messages?.slice(1))
    .toEqual([...opening, ...inFlight, ...acceptAndSpawn, ...spawnOtherFamily])
})

test('a notification between a tool use and its result never splits the pair', async ($, on) => {
  on('session.compact', () => ({ skip: 'core reached' }))
  expect((await compact($, [...transcript, ...notifiedMidTool])).messages?.slice(1))
    .toEqual([...opening, ...inFlight, ...acceptAndSpawn, ...notifiedMidTool])
})

test('a subagent\'s prune request is refused rather than summarized', async ($, on) => {
  on('session.compact', () => ({ messages: [] }))
  const asked = await $.session.compact({ trigger: 'plugin', instructions: PRUNE, messages: transcript, agentId: 'a1' })
  expect(asked.skip).toMatch(/main conversation/)
})
