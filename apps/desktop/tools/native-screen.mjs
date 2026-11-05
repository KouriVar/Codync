// Builds the helper for Electron. Public release builds are signed by electron-builder.
// Personal builds use the Screen target's fixed development identity and keep that signature.
import { execFileSync } from 'node:child_process'
import { cpSync, mkdirSync, rmSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

if (process.platform !== 'darwin') process.exit(0)
const env = process.argv[2] ?? 'main'
if (!['main', 'dev'].includes(env)) throw new Error(`unknown environment ${env}`)
const name = env === 'dev' ? 'CodyncDevScreen' : 'CodyncScreen'
const configuration = env === 'dev' ? 'DevRelease' : 'Release'
const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const repo = join(root, '../..')
const derived = join(repo, 'build/dd')
const personal = process.argv.includes('--personal')
execFileSync('xcodebuild', [
  'build', '-project', join(repo, 'apps/Codync.xcodeproj'), '-scheme', env === 'dev' ? 'Screen Dev' : 'Screen', '-configuration', configuration,
  '-destination', 'generic/platform=macOS', '-derivedDataPath', derived, '-quiet',
  ...(personal ? ['ONLY_ACTIVE_ARCH=YES', `ARCHS=${process.arch === 'arm64' ? 'arm64' : 'x86_64'}`]
    : ['CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGNING_ALLOWED=NO']),
], { stdio: 'inherit' })
const out = join(root, `build/native/${name}.app`)
mkdirSync(dirname(out), { recursive: true })
rmSync(out, { recursive: true, force: true })
cpSync(join(derived, `Build/Products/${configuration}/${name}.app`), out, { recursive: true, verbatimSymlinks: true })
console.log('screen: built')
