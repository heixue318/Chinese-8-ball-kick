import { build } from 'esbuild';
import { mkdir, copyFile } from 'node:fs/promises';
await mkdir('dist', { recursive: true });
await build({ entryPoints: ['src/simulator.ts'], outfile: 'dist/simulator.mjs', bundle: true, platform: 'node', format: 'esm', sourcemap: true });
await build({ entryPoints: ['src/calibration-scenarios.ts'], outfile: 'dist/calibration-scenarios.mjs', bundle: true, platform: 'node', format: 'esm', sourcemap: true });
await build({ entryPoints: ['src/page.ts'], outfile: 'dist/page.js', bundle: true, platform: 'browser', format: 'esm', sourcemap: true });
await copyFile('index.html', 'dist/index.html');
