import type { EngineInterface, Register, RenderElement } from 'claude-code'

const IMAGE_PATH = /(?:file:\/\/)?[^\s`'"()<>[\]]+\.(?:png|jpe?g|gif|webp|bmp|tiff?|heic)\b/gi
const CACHE_DIR = '/tmp/claude-image-preview'
const MAX_COLUMNS = 48
const MAX_ROWS = 16
const MAX_PER_MESSAGE = 4

type Preview = { path: string; png: string; columns: number; rows: number }
type TerminalRender = Extract<Parameters<EngineInterface['ui']['resolve']>[0], { surface: 'terminal' }>

const previews = new Map<string, Promise<Preview | null>>()

const homeDir = async ($: EngineInterface) => (await $.process.run(['printenv', 'HOME'])).stdout.trim()

const pixelSize = async ($: EngineInterface, png: string) => {
  const { stdout } = await $.process.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', png])
  const [width, height] = [/pixelWidth: (\d+)/, /pixelHeight: (\d+)/].map(re => Number(stdout.match(re)?.[1]))
  return { width, height }
}

const toPng = async ($: EngineInterface, path: string) => {
  if (/\.png$/i.test(path)) return path
  const png = `${CACHE_DIR}/${path.replace(/[^\w.-]/g, '_')}.png`
  await $.process.run(['mkdir', '-p', CACHE_DIR])
  const { exitCode } = await $.process.run(['sips', '-s', 'format', 'png', path, '--out', png])
  return exitCode === 0 ? png : null
}

const loadPreview = async ($: EngineInterface, raw: string): Promise<Preview | null> => {
  const spelled = raw.replace(/^file:\/\//, '').replace(/^~(?=\/)/, await homeDir($))
  const stat = await $.fs.stat(spelled, { resolve: true }).catch(() => undefined)
  const path = stat?.kind === 'file' ? stat.realPath : undefined
  const png = path && (await toPng($, path))
  if (!path || !png) return null
  const { width, height } = await pixelSize($, png)
  if (!width || !height) return null
  const columns = Math.min(MAX_COLUMNS, Math.ceil(width / 10))
  const rows = Math.max(1, Math.min(MAX_ROWS, Math.round((columns * height) / width / 2)))
  return { path, png, columns, rows }
}

const preview = ($: EngineInterface, raw: string) => {
  const cached = previews.get(raw) ?? loadPreview($, raw).catch(() => null)
  previews.set(raw, cached)
  void cached.then(p => p ?? previews.delete(raw))
  return cached
}

const withPreviews = async ($: EngineInterface, e: TerminalRender, own: RenderElement, paths: string[]) => {
  const found = (await Promise.all(paths.map(p => preview($, p)))).filter(p => p !== null)
  const unique = [...new Map(found.map(p => [p.path, p])).values()].slice(0, MAX_PER_MESSAGE)
  if (unique.length === 0) return own
  const { Box, Button, Image } = $.ui.resolve(e)
  return (
    <Box flexDirection="column">
      {own}
      {unique.map(p => (
        <Box key={p.path} flexDirection="column" marginLeft={2}>
          <Image source={{ file: p.png, format: 'png' }} columns={p.columns} rows={p.rows} alt={p.path} />
          <Button key={`open:${p.path}`} label={`open ${p.path.split('/').pop()} ↗`} onPress={() => $.process.run(['open', p.path])} />
        </Box>
      ))}
    </Box>
  )
}

export const register: Register = on => {
  on('ui.render', { component: 'ToolUse' }, async ($, e, next) => {
    const own = await next(e)
    const { tool, input, isRunning, isErrored } = e.props
    const filePath = (input as { file_path?: unknown } | undefined)?.file_path
    if (e.surface !== 'terminal' || tool !== 'Read' || isRunning || isErrored || typeof filePath !== 'string') return own
    return withPreviews($, e, own, filePath.match(IMAGE_PATH) ?? [])
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const own = await next(e)
    if (e.surface !== 'terminal') return own
    return withPreviews($, e, own, e.props.text.match(IMAGE_PATH) ?? [])
  })
}
