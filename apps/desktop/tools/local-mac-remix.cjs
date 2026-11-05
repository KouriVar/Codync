// Apply the source Remix renderer to the retained official 2.34.2 bundle.
const assert = require('node:assert/strict')
const { execFileSync } = require('node:child_process')
const { cpSync, mkdirSync, readFileSync, readdirSync, writeFileSync } = require('node:fs')
const { join } = require('node:path')
const { buildSync } = require('esbuild')

exports.applyRemixOverlay = function (extracted, output) {
  const desktop = join(__dirname, '..')
  const assets = join(extracted, 'out/renderer/assets')
  const javascript = readdirSync(assets).filter((name) => /^index-.*\.js$/.test(name))
  const stylesheets = readdirSync(assets).filter((name) => /^index-.*\.css$/.test(name))
  assert.equal(javascript.length, 1)
  assert.equal(stylesheets.length, 1)
  const file = join(assets, javascript[0])
  let renderer = readFileSync(file, 'utf8')
  const start = 'function Icon({ name, size, weight = "regular", color, style, className, scaled = true, title }) {\n  const m = useManifest();'
  assert.equal(renderer.split(start).length, 2, 'The base Icon component changed; review before patching.')
  const helper = buildSync({
    entryPoints: [join(desktop, 'src/renderer/components/remix-icons.ts')],
    bundle: true, write: false, format: 'iife', globalName: 'CodyncRemixOverlay', platform: 'browser', target: 'chrome130',
  }).outputFiles[0].text
  renderer = renderer.replace(start, helper + '\n' + start + `
  const remix = window.codync?.platform === "darwin"
    ? CodyncRemixOverlay.remixIconProps({ name, size, color, style, className, scaled, title }) : null;
  if (remix) return jsxRuntimeExports.jsx("span", remix);`)
  writeFileSync(file, renderer)
  execFileSync(process.execPath, ['--check', file])
  const css = readFileSync(join(desktop, 'src/renderer/components/remix-icons.css'), 'utf8')
    .replace("../assets/remix/remixicon.ttf", "../remix/remixicon.ttf")
  const cssPath = join(assets, stylesheets[0])
  writeFileSync(cssPath, readFileSync(cssPath, 'utf8') + '\n' + css)
  const fonts = join(extracted, 'out/renderer/remix')
  mkdirSync(fonts)
  cpSync(join(desktop, 'src/renderer/assets/remix'), fonts, { recursive: true })
  execFileSync('swift', [join(desktop, 'tools/export-remix-menu.swift'), desktop], { stdio: 'inherit' })
  cpSync(join(desktop, 'resources/remix-menu'), join(output, 'Contents/Resources/remix-menu'), { recursive: true })
  return new Set([`out/renderer/assets/${javascript[0]}`, `out/renderer/assets/${stylesheets[0]}`])
}

exports.patchRemixMenu = function (main) {
  const before = 'if (process.platform === "darwin") return electron.nativeImage.createMenuSymbol(name);'
  assert.equal(main.split(before).length, 2, 'The base native menu component changed; review before patching.')
  return main.replace(before, `if (process.platform === "darwin") {
      const image = electron.nativeImage.createFromPath(node_path.join(process.resourcesPath, "remix-menu", name + ".png"));
      if (image.isEmpty()) return electron.nativeImage.createMenuSymbol(name);
      image.setTemplateImage(true);
      return image;
    }`)
}
