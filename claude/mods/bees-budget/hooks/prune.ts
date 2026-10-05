import type { SessionMessage } from 'claude-code'

export const PRUNE = '[bees:prune]'
export const PRUNE_IF_LARGER = `${PRUNE} if the finished units outweigh the rest`
const NOTE = '[bees] Finished units were removed from this context; the plan file and log hold their record.'

const UNIT = '[A-Z]+-?\\d+[a-z]?'
const UNIT_ID = new RegExp(`\\b${UNIT}\\b`, 'g')
const isUnitId = (id: string) => new RegExp(`^${UNIT}$`).test(id)
const DONE_LINE = /^BEES: done=(.+)$/gm
const RESULT_LINE = /^BEES: (?:results|reviews)=(.+)$/gm
const WORK_FILE = new RegExp(`\\b(?:impl|review|report)-(${UNIT})-(?:[a-z]+-)?r\\d+\\b`, 'g')

const textOf = (m: SessionMessage) =>
  [m.text, ...m.toolUses.map(t => `${JSON.stringify(t.input)}\n${t.text ?? ''}`), ...(m.toolResults ?? []).map(r => r.text)].join('\n')

export const tokensOf = (messages: readonly SessionMessage[]) =>
  messages.reduce((n, m) => n + textOf(m).length, 0) / 4

const isNote = (m: SessionMessage) => m.role === 'user' && m.text.startsWith(NOTE)
const isTurnStart = (m: SessionMessage) => m.role === 'user' && !m.toolResults?.length
const family = (id: string) => id.replace(/-?\d+[a-z]?$/, '')
const captures = (text: string, pattern: RegExp) => [...text.matchAll(pattern)].map(match => match[1] ?? '')

const turns = (messages: readonly SessionMessage[]) => {
  const all: SessionMessage[][] = []
  const unanswered = new Set<string>()
  for (const m of messages) {
    if (all.length === 0 || (isTurnStart(m) && unanswered.size === 0)) all.push([])
    all.at(-1)!.push(m)
    m.toolUses.forEach(t => unanswered.add(t.tool_use_id))
    m.toolResults?.forEach(r => unanswered.delete(r.tool_use_id))
  }
  return all
}

const doneIds = (messages: readonly SessionMessage[]) =>
  new Set(messages
    .filter(m => m.role === 'assistant' || isNote(m))
    .flatMap(m => captures(m.text, DONE_LINE).flatMap(ids => ids.split(/[\s,;]+/)))
    .filter(isUnitId))

const startedIds = (messages: readonly SessionMessage[]) =>
  messages.flatMap(m => {
    const text = textOf(m)
    const reported = captures(text, RESULT_LINE).flatMap(entries => entries.split(';').map(e => e.split(':')[0]?.trim() ?? ''))
    return [...reported, ...captures(text, WORK_FILE)].filter(isUnitId)
  })

const loadsSkill = (turn: SessionMessage[]) => turn.some(m => m.toolUses.some(t => t.tool === 'Skill'))

export const prune = (messages: readonly SessionMessage[]) => {
  const done = doneIds(messages)
  const families = new Set([...done, ...startedIds(messages)].map(family))
  const isFinished = (turn: SessionMessage[], index: number) => {
    const units = turn.flatMap(m => textOf(m).match(UNIT_ID) ?? []).filter(id => families.has(family(id)))
    return index > 0 && !loadsSkill(turn) && units.length > 0 && units.every(id => done.has(id))
  }
  const all = turns(messages.filter(m => !isNote(m)))
  const finished = all.map(isFinished)
  const kept = all.filter((_, i) => !finished[i]).flat()
  const removed = all.filter((_, i) => finished[i]).flat()
  const note: SessionMessage = { role: 'user', text: `${NOTE}\nBEES: done=${[...done].join(',')}`, toolUses: [] }
  return { messages: [note, ...kept], kept, removed }
}
