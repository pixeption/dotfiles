import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, SessionMessage } from 'claude-code'

const MINUTE = 60_000

const prompt = (text: string): SessionMessage => ({ role: 'user', text, toolUses: [] })
const said = (text: string): SessionMessage => ({ role: 'assistant', text, toolUses: [] })

const accepted = [prompt('STEP-1 hand-back: done'), said('accepted\nBEES: done=STEP-1')]
const working = [prompt('STEP-2 hand-back: blocked'), said('rebrief STEP-2')]

const orchestrator = (on: On, messages: SessionMessage[], contextTokens = 50_000, hasPruner = true) => {
  const clock = mock.clock(on, { now: 0 })
  const asked: (string | undefined)[] = []
  if (hasPruner) on('engine.create', async (_$, e, next) => ({ ...await next(e), beesPruner: { isReady: async () => true } }))
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

test('a session whose only done line is the user\'s is left alone', async ($, on) => {
  const { clock, asked } = orchestrator(on, [prompt('BEES: done=STEP-1'), ...working], 190_000)
  await endTurn($, clock)
  await clock.advance(2 * 60 * MINUTE)
  expect(asked).toEqual([])
})

test('without bees-budget loaded to answer it, nothing is asked', async ($, on) => {
  const { clock, asked } = orchestrator(on, [...accepted, ...working], 190_000, false)
  await endTurn($, clock)
  await clock.advance(2 * 60 * MINUTE)
  expect(asked).toEqual([])
})

test('a pending prune is dropped when the session ends or a new turn starts', async ($, on) => {
  const { clock, asked } = orchestrator(on, [...accepted, ...working])
  on('session.end', () => ({ sessionId: 's' }))
  on('turn.start', () => ({ turnId: 't2' }))
  await endTurn($, clock)
  await $.session.end({ reason: 'clear', sessionId: 's', resume: undefined as never })
  await clock.advance(2 * 60 * MINUTE)
  await endTurn($, clock)
  await $.turn.start({ text: 'next', turnId: 't2' })
  await clock.advance(2 * 60 * MINUTE)
  expect(asked).toEqual([])
})
