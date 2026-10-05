import type { SessionMessage } from 'claude-code'

export const PRUNE = '[bees:prune]'
export const PRUNE_IF_LARGER = `${PRUNE} if the finished units outweigh the rest`
const NOTE = '[bees] Finished units were removed from this context; the plan file and log hold their record.'

const DONE_LINE = /^BEES: done=(.+)$/gm
const UNIT_ID = /\b[A-Z]+-?\d+[a-z]?\b/g

const textOf = (m: SessionMessage) =>
  [m.text, ...m.toolUses.map(t => `${JSON.stringify(t.input)}\n${t.text ?? ''}`), ...(m.toolResults ?? []).map(r => r.text)].join('\n')

export const tokensOf = (messages: readonly SessionMessage[]) =>
  messages.reduce((n, m) => n + textOf(m).length, 0) / 4

const isNote = (m: SessionMessage) => m.role === 'user' && m.text.startsWith(NOTE)
const isTurnStart = (m: SessionMessage) => m.role === 'user' && !m.toolResults?.length
const family = (id: string) => id.replace(/-?\d+[a-z]?$/, '')

const turns = (messages: readonly SessionMessage[]) =>
  messages.reduce<SessionMessage[][]>((all, m) => {
    const last = all.at(-1)
    if (last && !isTurnStart(m)) last.push(m)
    else all.push([m])
    return all
  }, [])

const doneIds = (messages: readonly SessionMessage[]) =>
  new Set(messages
    .filter(m => m.role === 'assistant' || isNote(m))
    .flatMap(m => [...m.text.matchAll(DONE_LINE)].flatMap(line => (line[1] ?? '').split(/[\s,;]+/).filter(Boolean))))

const loadsSkill = (turn: SessionMessage[]) => turn.some(m => m.toolUses.some(t => t.tool === 'Skill'))

export const prune = (messages: readonly SessionMessage[]) => {
  const done = doneIds(messages)
  const families = new Set([...done].map(family))
  const isFinished = (turn: SessionMessage[], index: number) => {
    const units = turn.flatMap(m => textOf(m).match(UNIT_ID) ?? []).filter(id => families.has(family(id)))
    return index > 0 && !loadsSkill(turn) && units.length > 0 && units.every(id => done.has(id))
  }
  const all = turns(messages.filter(m => !isNote(m)))
  const kept = all.filter((turn, i) => !isFinished(turn, i)).flat()
  const removed = all.filter(isFinished).flat()
  const note: SessionMessage = { role: 'user', text: `${NOTE}\nBEES: done=${[...done].join(',')}`, toolUses: [] }
  return { messages: [note, ...kept], kept, removed }
}
