// Repackage the installed 2.34.2 app for this Mac, preserving its Host and native helpers.
// Usage: node tools/package-mac-local.cjs <source.app> <output.app> <signing identity>
const assert = require('node:assert/strict')
const { execFileSync } = require('node:child_process')
const { createHash } = require('node:crypto')
const { closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, statSync, writeFileSync } = require('node:fs')
const { dirname, join, resolve } = require('node:path')
const asar = require('@electron/asar')
const { signAsync } = require('@electron/osx-sign')
const { applyRemixOverlay, patchRemixMenu } = require('./local-mac-remix.cjs')

const hash = (bytes) => createHash('sha256').update(bytes).digest('hex')
const run = (command, args) => execFileSync(command, args, { encoding: 'utf8' })
const plist = (path) => JSON.parse(run('plutil', ['-convert', 'json', '-o', '-', path]))

function isCode(file) {
  if (statSync(file).isDirectory()) return file.endsWith('.app') || file.endsWith('.framework')
  const fd = openSync(file, 'r')
  const magic = Buffer.alloc(4)
  try { readSync(fd, magic, 0, 4, 0) } finally { closeSync(fd) }
  return ['feedface', 'feedfacf', 'cefaedfe', 'cffaedfe', 'cafebabe', 'cafebabf', 'bebafeca', 'bfbafeca'].includes(magic.toString('hex'))
}

function replaceOnce(text, before, after) {
  assert.equal(text.split(before).length, 2, `Expected exactly one patch location: ${before}`)
  return text.replace(before, after)
}

async function main() {
  const [sourceArg, outputArg, identity] = process.argv.slice(2)
  assert.equal(process.platform, 'darwin', 'This local package is macOS-only.')
  assert(sourceArg && outputArg && identity, 'Provide source.app, output.app and a signing identity.')
  const source = resolve(sourceArg)
  const output = resolve(outputArg)
  assert(source.endsWith('.app') && output.endsWith('.app'))
  assert(!existsSync(output), 'The output must be a new app folder, never an installed app.')
  const info = plist(join(source, 'Contents/Info.plist'))
  assert.equal(info.CFBundleIdentifier, 'com.pokai.Codync')
  assert.equal(info.CFBundleShortVersionString, '2.34.2', 'Other base versions need a separate review.')
  assert(!info.CodyncLocalCustomization, 'Use an unmodified official base app.')
  const archive = join(source, 'Contents/Resources/app.asar')
  const originalHeader = asar.getRawHeader(archive)
  assert.equal(hash(originalHeader.headerString), info.ElectronAsarIntegrity['Resources/app.asar'].hash)
  const entries = asar.listPackage(archive)
  assert(entries.every((entry) => !asar.statFile(archive, entry.slice(1)).unpacked), 'Unpacked ASAR entries need a separate packaging path.')

  // Use the position from the fork's source, rather than maintaining another pair of offsets.
  const windowSource = readFileSync(join(__dirname, '../src/main/index.ts'), 'utf8')
  const position = /trafficLightPosition: (\{ x: \d+, y: \d+ \})/.exec(windowSource)?.[1]
  assert(position, 'The Mac window position is missing from the fork source.')
  const mainPath = 'out/main/index.js'
  const originalMain = asar.extractFile(archive, mainPath).toString()
  assert(!originalMain.includes('trafficLightPosition'), 'The base already customizes window buttons.')
  let main = replaceOnce(originalMain,
    'titleBarStyle: isMac ? "hidden" : "default",',
    `titleBarStyle: isMac ? "hidden" : "default",\n    ...(isMac ? { trafficLightPosition: ${position} } : {}),`)
  main = replaceOnce(main,
    'const enabled = electron.app.isPackaged && isMainEnvironment();',
    'const enabled = false; // Local customization: official updates would replace this app and its Host.')
  main = patchRemixMenu(main)

  mkdirSync(dirname(output), { recursive: true })
  run('ditto', [source, output])
  const work = join(dirname(output), 'local-package-work')
  mkdirSync(work)
  const extracted = join(work, 'asar')
  asar.extractAll(archive, extracted)
  writeFileSync(join(extracted, mainPath), main)
  const changed = applyRemixOverlay(extracted, output)
  changed.add(mainPath)
  run(process.execPath, ['--check', join(extracted, mainPath)])
  const packagedArchive = join(output, 'Contents/Resources/app.asar')
  await asar.createPackage(extracted, packagedArchive)
  for (const entry of entries) {
    const relative = entry.slice(1)
    const stat = asar.statFile(archive, relative)
    if (stat.files || stat.link || changed.has(relative)) continue
    assert.equal(hash(asar.extractFile(packagedArchive, relative)), hash(asar.extractFile(archive, relative)), `Unexpected ASAR change: ${relative}`)
  }
  const integrity = { 'Resources/app.asar': { algorithm: 'SHA256', hash: hash(asar.getRawHeader(packagedArchive).headerString) } }
  const infoPath = join(output, 'Contents/Info.plist')
  run('plutil', ['-replace', 'ElectronAsarIntegrity', '-json', JSON.stringify(integrity), infoPath])
  run('plutil', ['-insert', 'CodyncLocalCustomization', '-string', 'C0088+C0089+C0090; official 2.34.2 base; Remix 4.9.1; local updates disabled', infoPath])

  // Re-sign Electron with this Mac's valid development identity. Keep the independently
  // executed Host, speech and Screen helper byte-for-byte; their original signatures remain.
  await signAsync({
    app: output, identity, platform: 'darwin', type: 'development',
    preAutoEntitlements: false, preEmbedProvisioningProfile: false,
    ignore: (file) => file.startsWith(join(output, 'Contents/Resources/'))
      || file.startsWith(join(output, 'Contents/Library/'))
      || !isCode(file),
    optionsForFile(file) {
      const entitlements = execFileSync('codesign', ['-d', '--entitlements', ':-', file], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
      const path = join(work, `${hash(file)}.entitlements.plist`)
      writeFileSync(path, entitlements.trim() || '<?xml version="1.0"?><plist version="1.0"><dict/></plist>')
      return { entitlements: path, hardenedRuntime: true, timestamp: 'none' }
    },
  })
  for (const name of ['codync-host', 'codync-speech', 'account-config.json']) {
    const relative = join('Contents/Resources', name)
    assert.equal(hash(readFileSync(join(output, relative))), hash(readFileSync(join(source, relative))), `${name} changed`)
  }
  console.log(`Local signed app: ${output}`)
  console.log('Base 2.34.2; Host and account configuration unchanged; official app updates disabled.')
}

main().catch((error) => { console.error(error.message); process.exitCode = 1 })
