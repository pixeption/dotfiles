import { atom, read, update } from 'claude-code'
import type { EngineInterface, ModelUsage, Register } from 'claude-code'

import type { CodexLaunch, CodexSession } from '../types'
import { PRUNE, PRUNE_IF_LARGER, prune, tokensOf } from './prune'

const CONTINUE_LINE = 160_000
const RETIRE_AT = 200_000
const COLD_LIMIT = 100_000
const CLAUDE_TTL_MS = 5 * 60_000
const CODEX_TTL_MS = 30 * 60_000
const SHOWN_FOR_MS = 60 * 60_000
const REFRESH_MS = 15_000
const HANDOVER = '[bees:handover]'
const OPENCODE_URL = 'http://127.0.0.1:4096'

const contexts = atom({ plugin: 'bees-budget', key: 'contexts' } as const, {})
const codex = atom({ plugin: 'bees-budget', key: 'codex' } as const, [])
const launches = atom({ plugin: 'bees-budget', key: 'launches' } as const, [])

type Row = { vendor: string; model: string; label: string; tokens: number; at: number; ttlMs: number; isRunning: boolean; codex?: CodexSession }

const contextTokens = (u: ModelUsage) =>
  u.input_tokens + u.cache_read_input_tokens + u.cache_creation_input_tokens + u.output_tokens

const kilo = (n: number) => `${Math.round(n / 1000)}k`
const isRetired = (tokens: number) => tokens >= RETIRE_AT
const isCold = (r: Row, now: number) => !r.isRunning && now - r.at > r.ttlMs
const isBlocked = (r: Row, now: number) => isRetired(r.tokens) || (isCold(r, now) && r.tokens >= COLD_LIMIT)

const refusal = (r: Row, now: number) => {
  if (isRetired(r.tokens))
    return `${r.label} is at ${kilo(r.tokens)} context, past the ${kilo(RETIRE_AT)} retire line: spawn a fresh bee and hand the resource over (bees reference/budgets.md). A retirement message may start with ${HANDOVER}.`
  if (isBlocked(r, now))
    return `${r.label}'s cache is cold (idle ${Math.round((now - r.at) / 60_000)}m, clock ${r.ttlMs / 60_000}m) at ${kilo(r.tokens)} context, at or past ${kilo(COLD_LIMIT)}: spawn a fresh bee instead (bees reference/budgets.md).`
  return undefined
}

const modelEffort = (model: string, effort: string | null | undefined) => (effort ? `${model}-${effort}` : model)

const frontmatter = (text: string, key: string) => text.match(new RegExp(`^${key}:\\s*(\\S+)`, 'm'))?.[1]

const agentModels = new Map<string, Promise<string>>()

const readAgentModel = async ($: EngineInterface, type: string) => {
  const text = await $.fs.read(`${await $.env.get('HOME')}/.claude/agents/${type}.md`).catch(() => '')
  const model = (frontmatter(text, 'model') ?? '?').replace(/^claude-|-.*$/g, '')
  return modelEffort(model, frontmatter(text, 'effort'))
}

const agentModel = ($: EngineInterface, type: string) => {
  if (!agentModels.has(type)) agentModels.set(type, readAgentModel($, type))
  return agentModels.get(type)!
}

const beeRows = async ($: EngineInterface): Promise<(Row & { id: string })[]> => {
  const recorded = await read($, contexts)
  const bees = (await $.agent.list()).flatMap(a => {
    const bee = recorded[a.id]
    return a.type.startsWith('bee-') && bee ? [{ ...a, ...bee }] : []
  })
  return Promise.all(bees.map(async a => ({
    id: a.id, vendor: 'claude', model: await agentModel($, a.type), label: a.name ?? a.description,
    tokens: a.tokens, at: a.at, ttlMs: CLAUDE_TTL_MS, isRunning: a.status === 'running',
  })))
}

const assistant = `json_extract(data, '$.role') = 'assistant'`

const codexQuery = (since: number, liveSince: number) => `
  with touched as (select session_id, max(time_updated) as at from part group by session_id)
  select s.id, s.title as label, s.directory, s.time_created as createdAt,
    json_extract(l.data, '$.modelID') as model, json_extract(l.data, '$.variant') as effort,
    coalesce(json_extract(m.data, '$.tokens.total'),
      ifnull(json_extract(m.data, '$.tokens.input'), 0) + ifnull(json_extract(m.data, '$.tokens.output'), 0)
      + ifnull(json_extract(m.data, '$.tokens.reasoning'), 0) + ifnull(json_extract(m.data, '$.tokens.cache.read'), 0)
      + ifnull(json_extract(m.data, '$.tokens.cache.write'), 0)) as tokens,
    coalesce(json_extract(m.data, '$.time.completed'), s.time_created) as at,
    l.id is not null and json_extract(l.data, '$.time.completed') is null
      and json_extract(l.data, '$.error') is null and t.at > ${liveSince} as isRunning
  from session s join touched t on t.session_id = s.id
  left join message m on m.id = (
    select id from message where session_id = s.id and ${assistant}
      and json_extract(data, '$.time.completed') is not null
      and json_extract(data, '$.error') is null order by time_created desc limit 1)
  left join message l on l.id = (
    select id from message where session_id = s.id and ${assistant} order by time_created desc limit 1)
  where s.parent_id is null and t.at > ${since} order by t.at desc limit 20`

const queryOpencode = async <T,>($: EngineInterface, sql: string): Promise<T[]> => {
  const data = (await $.env.get('XDG_DATA_HOME')) || `${await $.env.get('HOME')}/.local/share`
  const ran = await $.process.run(['sqlite3', '-json', `${data}/opencode/opencode.db`, sql])
  return ran.exitCode === 0 && ran.stdout.trim() ? JSON.parse(ran.stdout) : []
}

const readCodexSessions = async ($: EngineInterface, now: number): Promise<CodexSession[]> =>
  (await queryOpencode<CodexSession>($, codexQuery(now - SHOWN_FOR_MS, now - CODEX_TTL_MS)))
    .map(s => ({ ...s, isRunning: Boolean(s.isRunning) }))

const isLaunchedHere = (s: CodexSession, ls: CodexLaunch[]) =>
  ls.some(l => l.id === s.id || (l.title === s.label && s.createdAt >= l.since))

const refresh = async ($: EngineInterface) => {
  const sessions = await readCodexSessions($, await $.clock.now())
  const { startedAt } = await $.session.usage()
  const ls = await read($, launches)
  await update($, codex, () => sessions.filter(s => isLaunchedHere(s, ls) && (s.isRunning || s.at >= startedAt)))
  $.ui.invalidate('ui.render')
}

const unquote = (arg: string) => arg.replace(/^(['"])(.*)\1$/, '$2')
const flag = (command: string, name: string) => {
  const arg = command.match(new RegExp(`(?:^|\\s)${name}\\s+("[^"]*"|'[^']*'|\\S+)`))?.[1]
  return arg && unquote(arg)
}
const basename = (path: string) => path.split('/').pop() ?? path

const launchTitle = (command: string) => {
  const tool = command.match(/opencode-(implement|review)|opencode run/)?.[0]
  if (!tool) return undefined
  const title = flag(command, '--title')
  const out = flag(command, '-o')
  if (title || !out) return title
  return tool === 'opencode-review' ? `review ${basename(out)}` : basename(out)
}

const sessionIds = (text: string) => [...new Set(text.match(/\bses_[A-Za-z0-9]+/g) ?? [])]

const recordLaunches = async ($: EngineInterface, command: string, output: string) => {
  const since = await $.clock.now()
  const title = launchTitle(command)
  const found: CodexLaunch[] = [...sessionIds(`${command}\n${output}`).map(id => ({ id, since })), ...(title ? [{ title, since }] : [])]
  if (found.length) await update($, launches, all => [...all, ...found])
}

const attach = async ($: EngineInterface, s: CodexSession) => {
  const command = ['opencode', 'attach', OPENCODE_URL, '--dir', s.directory, '--session', s.id]
  const socket = await $.env.get('KITTY_LISTEN_ON')
  const window = await $.env.get('KITTY_WINDOW_ID')
  if (!socket || !window) return $.ui.toast(command.join(' '))
  const ran = await $.process.run(['kitty', '@', '--to', socket, 'launch', '--location=vsplit', `--next-to=id:${window}`,
    '--cwd', s.directory, '--title', `codex ${s.label}`, ...command])
  if (ran.exitCode !== 0) $.ui.toast(`kitty launch failed: ${ran.stderr.trim()}`)
}

const cacheText = (r: Row, now: number) =>
  r.isRunning ? 'running' : isCold(r, now) ? 'cold' : `warm ${Math.ceil((r.ttlMs - (now - r.at)) / 60_000)}m`

const statusColor = (r: Row, now: number) => (isBlocked(r, now) ? 'red' : r.isRunning ? 'green' : undefined)

const tokenColor = (tokens: number) =>
  isRetired(tokens) ? 'red' : tokens >= CONTINUE_LINE ? 'yellow' : undefined

const pruneSkip = (instructions: string, { kept, removed }: ReturnType<typeof prune>) =>
  removed.length === 0 ? 'bees: no finished units to prune'
    : instructions === PRUNE_IF_LARGER && tokensOf(removed) < tokensOf(kept) ? 'bees: finished units are still smaller than the rest'
      : undefined

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    $.clock.every(REFRESH_MS, () => void refresh($))
    void refresh($)
    return next(e)
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const ran = await next(e)
    const output = ran.deny === undefined && !ran.isError ? `${ran.result.stdout}\n${ran.result.stderr}` : ''
    await recordLaunches($, e.command, output)
    return ran
  })

  on('turn.step', async function* ($, e, next) {
    const step = yield* next(e)
    const { agentId } = e
    const { usage } = step
    if (agentId && usage) {
      const bee = { tokens: contextTokens(usage), at: await $.clock.now() }
      await update($, contexts, all => ({ ...all, [agentId]: bee }))
    }
    return step
  })

  on('session.send', async ($, e, next) => {
    if (e.text.startsWith(HANDOVER)) return next(e)
    const to = e.to.replace(/ \[[^\]]*\]$/, '')
    const bee = (await beeRows($)).find(r => r.id === to || r.label === to)
    const reason = bee && refusal(bee, await $.clock.now())
    return reason ? { isDelivered: false, reason } : next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const now = await $.clock.now()
    const codexRows = (await read($, codex)).map(s => ({
      ...s, vendor: 'codex', model: modelEffort(s.model?.split('-').pop() ?? '?', s.effort), ttlMs: CODEX_TTL_MS, codex: s,
    }))
    const rows = [...(await beeRows($)), ...codexRows].filter(r => r.isRunning || now - r.at < SHOWN_FOR_MS)
    if (rows.length === 0) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {rows.map(r => (
          <Box key={r.codex?.id ?? r.label} gap={2}>
            <Text dimColor>{r.vendor} {r.model}</Text>
            {r.codex
              ? <Button key={r.codex.id} plain onPress={() => void attach($, r.codex!)}>{r.label}</Button>
              : <Text wrap="truncate-end">{r.label}</Text>}
            <Text color={tokenColor(r.tokens)}>{kilo(r.tokens)}</Text>
            <Text dimColor={!statusColor(r, now)} color={statusColor(r, now)}>
              {cacheText(r, now)}{isBlocked(r, now) ? ' · spawn fresh' : ''}
            </Text>
          </Box>
        ))}
      </Box>
    )
  })

  on('engine.create', async (_$, e, next) => ({ ...await next(e), beesPruner: { isReady: async () => true } }))

  on('session.compact', async ($, e, next) => {
    if (!e.instructions?.startsWith(PRUNE)) return next(e)
    if (e.agentId) return { skip: 'bees: only the main conversation is pruned' }
    const pruned = prune(e.messages)
    const skip = pruneSkip(e.instructions, pruned)
    if (skip) return { skip }
    $.ui.log(`bees: pruned ${pruned.removed.length} messages of finished units`)
    return { messages: pruned.messages }
  })
}
