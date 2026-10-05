import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, SessionMessage } from 'claude-code'

const MINUTE = 60_000

const prompt = (text: string): SessionMessage => ({ role: 'user', text, toolUses: [] })
const said = (text: string): SessionMessage => ({ role: 'assistant', text, toolUses: [] })

const accepted = [prompt('STEP-1 hand-back: done'), said('accepted\nBEES: done=STEP-1')]
const working = [prompt('STEP-2 hand-back: blocked'), said('rebrief STEP-2')]

const orchestrator = (on: On, messages: SessionMessage[], contextTokens = 50_000) => {
  const clock = mock.clock(on, { now: 0 })
  const asked: (string | undefined)[] = []
  on('session.messages', () => ({ value: messages }))
  on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200_000, tokens: contextTokens }, rateLimits: [] } }))
  on('session.compact', (_$, e) => {
    asked.push(e.instructions)
    return { skip: 'recorded' }
  })
  on('turn.complete', () => ({ text: '' }))
  return { clock, asked }
}

const endTurn = async ($: Engine, clock: { advance: (ms: number) => Promise<void> }) => {
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' })
  await clock.advance(1)
}

test('after a turn that accepts a unit it asks for a prune if the finished units outweigh the rest', async ($, on) => {
  const { clock, asked } = orchestrator(on, accepted)
  await endTurn($, clock)
  expect(asked).toEqual(['[bees:prune] if the finished units outweigh the rest'])
})

test('at 150k context it asks for a prune of whatever is finished', async ($, on) => {
  const { clock, asked } = orchestrator(on, [...accepted, ...working], 150_000)
  await endTurn($, clock)
  expect(asked).toEqual(['[bees:prune]'])
})

test('once the orchestrator has been idle past its cache clock it asks for a prune', async ($, on) => {
  const { clock, asked } = orchestrator(on, [...accepted, ...working])
  await endTurn($, clock)
  await clock.advance(59 * MINUTE)
  expect(asked).toEqual([])
  await clock.advance(MINUTE)
  expect(asked).toEqual(['[bees:prune]'])
})

test('a session that has never recorded a done unit is left alone', async ($, on) => {
  const { clock, asked } = orchestrator(on, working, 190_000)
  await endTurn($, clock)
  await clock.advance(2 * 60 * MINUTE)
  expect(asked).toEqual([])
})
