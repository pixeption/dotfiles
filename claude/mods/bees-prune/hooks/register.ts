import type { EngineInterface, Register, SessionMessage, Timer } from 'claude-code'

const PRUNE = '[bees:prune]'
const PRUNE_IF_LARGER = `${PRUNE} if the finished units outweigh the rest`
const ORCHESTRATOR_TTL_MS = 60 * 60_000
const PRUNE_AT = 150_000
const DONE_LINE = /^BEES: done=/m

const isPrompt = (m: SessionMessage) => m.role === 'user' && !m.toolResults?.length
const recordsDone = (m: SessionMessage) => DONE_LINE.test(m.text)
const acceptedThisTurn = (messages: readonly SessionMessage[]) =>
  messages.slice(messages.findLastIndex(isPrompt)).some(m => m.role === 'assistant' && recordsDone(m))

const compactAfter = ($: EngineInterface, ms: number, instructions: string) =>
  $.clock.after(ms, () => void $.session.compact({ instructions }).catch(() => undefined))

export const register: Register = on => {
  let coldPrune: Timer | undefined

  on('turn.complete', async ($, e, next) => {
    const completed = await next(e)
    const messages = await $.session.messages()
    if (e.agentId !== undefined || !messages.some(recordsDone)) return completed
    coldPrune?.cancel()
    coldPrune = compactAfter($, ORCHESTRATOR_TTL_MS, PRUNE)
    const isFull = ((await $.session.usage()).context.tokens ?? 0) >= PRUNE_AT
    const now = isFull ? PRUNE : acceptedThisTurn(messages) ? PRUNE_IF_LARGER : undefined
    if (now) compactAfter($, 0, now)
    return completed
  })
}
