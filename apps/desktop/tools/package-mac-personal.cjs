// Packages a local app from source, then signs it with the same identity as the Screen target.
const assert = require('node:assert/strict')
const { execFileSync, spawnSync } = require('node:child_process')
const { closeSync, copyFileSync, mkdirSync, mkdtempSync, openSync, readFileSync, readSync, renameSync, rmSync, statSync, writeFileSync } = require('node:fs')
const { join, resolve, sep } = require('node:path')
const { build, Platform } = require('electron-builder')
const { signAsync } = require('@electron/osx-sign')
const { parse } = require('yaml')

const root = resolve(__dirname, '..')
const repo = resolve(root, '../..')
const output = join(repo, 'build/dd/desktop-personal')
const variant = process.argv[2] ?? 'main'
const run = (command, args) => execFileSync(command, args, { cwd: root, stdio: 'inherit' })

function isCode(file) {
  if (statSync(file).isDirectory()) return file.endsWith('.app') || file.endsWith('.framework')
  const fd = openSync(file, 'r')
  const magic = Buffer.alloc(4)
  try { readSync(fd, magic, 0, 4, 0) } finally { closeSync(fd) }
  return ['feedface', 'feedfacf', 'cefaedfe', 'cffaedfe', 'cafebabe', 'cafebabf', 'bebafeca', 'bfbafeca'].includes(magic.toString('hex'))
}

function verifyIdentity(app, bundleId, team, identity) {
  const inspect = (...args) => {
    const result = spawnSync('codesign', [...args, app], { encoding: 'utf8' })
    if (result.status !== 0) throw new Error(`Cannot inspect signature for ${app}.`)
    return result.stdout + result.stderr
  }
  const signature = inspect('-dv', '--verbose=4').split('\n')
  assert(signature.includes(`TeamIdentifier=${team}`), `${app} is missing signing team ${team}.`)
  assert(signature.includes(`Authority=${identity}`), `${app} is missing the fixed development identity.`)
  const requirement = inspect('-d', '-r-')
  assert(requirement.includes(`identifier "${bundleId}"`) && !requirement.includes('cdhash'), `${app} lacks a stable designated requirement.`)
}

async function pack(staging) {
  const config = variant === 'dev' ? require('./dev-builder.cjs') : parse(readFileSync(join(root, 'electron-builder.yml'), 'utf8'))
  const { DEVELOPMENT_TEAM: team, CODE_SIGN_IDENTITY: identity } =
    parse(readFileSync(join(repo, 'apps/project.yml'), 'utf8')).targets.Screen.settings.base
  const screenName = variant === 'dev' ? 'CodyncDevScreen' : 'CodyncScreen'
  const native = join(root, 'build/native')
  const screen = join(native, `${screenName}.app`)
  const screenId = `${config.appId}.screen`

  run(process.execPath, ['tools/account-config.mjs', variant])
  run(process.execPath, ['tools/native-screen.mjs', variant, '--personal'])
  verifyIdentity(screen, screenId, team, identity)
  run(process.execPath, ['tools/native-host.mjs', variant, '--native'])
  const speechDir = join(repo, 'build/dd/personal-speech')
  const speechArgs = ['build', '-c', 'release', '--arch', process.arch === 'arm64' ? 'arm64' : 'x86_64',
    '--package-path', 'native/speech-macos', '--scratch-path', speechDir]
  run('swift', speechArgs)
  const speech = execFileSync('swift', [...speechArgs, '--show-bin-path'], { cwd: root, encoding: 'utf8' }).trim()
  copyFileSync(join(speech, 'codync-speech'), join(native, 'codync-speech'))
  run('npm', ['run', 'build'])

  const configPath = join(staging, 'electron-builder.json')
  writeFileSync(configPath, JSON.stringify({
    ...config,
    publish: null,
    directories: { ...config.directories, output: staging },
    mac: { ...config.mac, target: 'dir', identity: null, notarize: false },
  }))
  let packed
  await build({
    projectDir: root,
    targets: Platform.MAC.createTarget('dir'),
    publish: 'never',
    // Loading this as the base config keeps electron-builder from appending the base resource lists again.
    config: {
      extends: configPath,
      afterPack: ({ appOutDir, packager }) => { packed = join(appOutDir, `${packager.appInfo.productFilename}.app`) },
    },
  })
  assert(packed, 'Electron did not produce an app bundle.')
  // A fresh service label avoids reusing the pre-migration Service Management record.
  // Keep the original plist so the app can unregister the previous embedded service.
  const agents = join(packed, 'Contents/Library/LaunchAgents')
  const personalLabel = `${screenId}.personal`
  const personalPlist = join(agents, `${personalLabel}.plist`)
  copyFileSync(join(agents, `${screenId}.plist`), personalPlist)
  run('/usr/bin/plutil', ['-replace', 'Label', '-string', personalLabel, personalPlist])
  run('/usr/bin/plutil', ['-insert', 'SpawnConstraint', '-json', JSON.stringify({
    'team-identifier': team,
    'signing-identifier': screenId,
  }), personalPlist])
  const packagedScreen = join(packed, 'Contents/Library/LoginItems', `${screenName}.app`)
  await signAsync({
    app: packed,
    identity,
    platform: 'darwin',
    type: 'development',
    preAutoEntitlements: false,
    preEmbedProvisioningProfile: false,
    ignore: (file) => file === packagedScreen || file.startsWith(packagedScreen + sep) || !isCode(file),
    optionsForFile: () => ({
      entitlements: join(root, config.mac.entitlements),
      hardenedRuntime: true,
      timestamp: 'none',
    }),
  })
  run('codesign', ['--verify', '--deep', '--strict', packed])
  verifyIdentity(packed, config.appId, team, identity)
  verifyIdentity(packagedScreen, screenId, team, identity)
  const final = join(output, `${config.productName}.app`)
  rmSync(final, { recursive: true, force: true })
  renameSync(packed, final)
  console.log(`Personal app signed for ${team}: ${final}`)
}

async function main() {
  assert.equal(process.platform, 'darwin', 'Personal packages require macOS.')
  assert(['main', 'dev'].includes(variant), 'Use main or dev.')
  process.env.DEVELOPER_DIR ??= '/Applications/Xcode.app/Contents/Developer'
  mkdirSync(output, { recursive: true })
  // Main and Dev share the native build directory and generated account configuration.
  const lock = join(output, '.pack-lock')
  mkdirSync(lock)
  try {
    const staging = mkdtempSync(join(output, '.pack-'))
    try { await pack(staging) } finally { rmSync(staging, { recursive: true, force: true }) }
  } finally {
    rmSync(lock, { recursive: true, force: true })
  }
}

main().catch((error) => { console.error(error.message); process.exitCode = 1 })
