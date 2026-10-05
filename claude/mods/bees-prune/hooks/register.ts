import type { EngineInterface, Register, SessionMessage, Timer } from 'claude-code'

const PRUNE = '[bees:prune]'
const PRUNE_IF_LARGER = `${PRUNE} if the finished units outweigh the rest`
const ORCHESTRATOR_TTL_MS = 60 * 60_000
const PRUNE_AT = 150_000
const DONE_LINE = /^BEES: done=/m

const isPrompt = (m: SessionMessage) => m.role === 'user' && !m.toolResults?.length
const isPruneNote = (m: SessionMessage) => m.role === 'user' && m.text.startsWith('[bees] ')
const recordsDone = (m: SessionMessage) => (m.role === 'assistant' || isPruneNote(m)) && DONE_LINE.test(m.text)
const acceptedThisTurn = (messages: readonly SessionMessage[]) =>
  messages.slice(messages.findLastIndex(isPrompt)).some(m => m.role === 'assistant' && recordsDone(m))

const askToPrune = async ($: EngineInterface, instructions: string) => {
  if (await $.beesPruner.isReady()) await $.session.compact({ instructions })
}

const askAfter = ($: EngineInterface, ms: number, instructions: string) =>
  $.clock.after(ms, () => void askToPrune($, instructions).catch(() => undefined))

export const register: Register = on => {
  let pending: Timer[] = []
  const cancelPending = () => {
    pending.forEach(t => t.cancel())
    pending = []
  }

  on('session.end', (_$, e, next) => {
    cancelPending()
    return next(e)
  })

  on('turn.start', (_$, e, next) => {
    cancelPending()
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const completed = await next(e)
    if (e.agentId !== undefined) return completed
    cancelPending()
    const messages = await $.session.messages()
    if (!messages.some(recordsDone)) return completed
    pending.push(askAfter($, ORCHESTRATOR_TTL_MS, PRUNE))
    const isFull = ((await $.session.usage()).context.tokens ?? 0) >= PRUNE_AT
    const now = isFull ? PRUNE : acceptedThisTurn(messages) ? PRUNE_IF_LARGER : undefined
    if (now) pending.push(askAfter($, 0, now))
    return completed
  })
}
