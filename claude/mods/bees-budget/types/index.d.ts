export type BeeContext = { tokens: number; at: number }
export type CodexSession = {
  id: string; label: string; directory: string; createdAt: number; model: string | null; effort: string | null
  tokens: number; at: number; isRunning: boolean
}
export type CodexLaunch = { id?: string; title?: string; since: number }

declare module 'claude-code' {
  interface PluginState {
    'bees-budget': { contexts: Record<string, BeeContext>; codex: CodexSession[]; launches: CodexLaunch[] }
  }
}
