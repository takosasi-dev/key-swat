// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後を見比べる用)。Chrome 1 回の起動で、画面ごとに窓の大きさだけ替えて撮る。
//     node tests/web/shots.mjs before     → build/web_shots/before/<画面>_<幅>x<高さ>.png
//     node tests/web/shots.mjs after
// スマホ(390×844)は「記録だけ」(落ちない・字が読める、を見る)。
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { open, OUT, serve, sleep } from './lib.mjs';

const PHASE = process.argv[2] || 'after';
const DIR = path.join(OUT, PHASE);
mkdirSync(DIR, { recursive: true });
const SIZES = [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]];
const LABELS = '1234567890qwertyuiopasdfghjkl;zxcvbnm,./'.split('');
const CLEAN = 0, NEST = 2;
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const press = (i) => page.key(LABELS[i]);
const play = async () => (await page.state()).play;

async function shootAll(name, settle = 250) {
	for (const [w, h] of SIZES) {
		await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(settle);
		const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
		writeFileSync(path.join(DIR, `${name}_${w}x${h}.png`), Buffer.from(data, 'base64'));
	}
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(150);
}

function pick(p) {
	let best = -1, bk = null;
	for (let i = 0; i < 40; i++) {
		if (!p.active[i] || p.state[i] === CLEAN) continue;
		const k = [p.state[i] === NEST ? 0 : p.target[i] >= 0 ? 1 : 2, p.spread_left[i], i];
		if (bk === null || k[0] < bk[0] || (k[0] === bk[0] && (k[1] < bk[1] || (k[1] === bk[1] && k[2] < bk[2])))) { best = i; bk = k; }
	}
	return best;
}

async function loseByMisses() {
	await press(23);
	await page.waitState((s) => s.play?.clock_running, 3000);
	for (let k = 0; k < 30; k++) {
		const s = await page.state();
		if (s.screen === 'result' || s.play?.over) break;
		await press(s.play.state.findIndex((st, i) => st === CLEAN && s.play.active[i]));
		await sleep(40);
	}
	return page.waitState((s) => s.screen === 'result', 5000);
}

try {
	console.log(`起動 ${page.bootMs} ms`);
	await page.waitState((s) => s.screen === 'gate', 30000);
	console.log(`S0 まで ${Date.now() - page.t0} ms`);
	await sleep(400);
	await shootAll('s0');
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await sleep(600);
	await shootAll('s1_title_first', 400);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(500);
	await shootAll('s4_settings');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play');
	await sleep(500);
	await shootAll('s2_start', 200);
	await press(23);
	await page.waitState((s) => s.play?.clock_running, 3000);
	// 正しい選び方で 50 秒ほど守り、巣と予兆のある場面を撮る
	for (const end = Date.now() + 50000; Date.now() < end;) {
		const p = await play();
		if (!p || p.over) break;
		const i = pick(p);
		if (i >= 0 && Math.random() < 0.6) await press(i);
		await sleep(90);
	}
	await shootAll('s2_play', 120);
	await page.key('Escape');
	await page.waitState((s) => s.paused, 3000);
	await sleep(500);
	await shootAll('s5_pause');
	await page.key('Escape');
	await page.waitState((s) => !s.paused, 3000);
	// 手を止めて感染で終わらせる
	await page.waitState((s) => s.screen === 'result', 120000);
	await sleep(1200);
	await shootAll('s3_result', 300);
	await page.key('r');
	await page.waitState((s) => s.screen === 'play', 3000);
	await loseByMisses();
	await sleep(1200);
	await shootAll('s3_result_second', 300);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title', 3000);
	await sleep(600);
	await shootAll('s1_title_record', 400);
	const base = page.url0.split('?')[0];
	await page.goto(base + '?keys=1&debug=1');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	await page.waitState((s) => s.screen === 'keys', 3000);
	for (const c of 'asdf;/') { await page.key(c); await sleep(30); }
	await sleep(300);
	await shootAll('keys');
	console.log(`コンソールのエラー ${page.errors().length} 件(読み込み中の画面を撮る前まで)`);
	for (const e of page.errors()) console.log('  ' + e.text);
	// 読み込み中の画面(index.wasm を止めて、Godot が立ち上がる前の画面のまま撮る)
	await page.cdp.send('Network.setBlockedURLs', { urls: ['*index.wasm*'] });
	await page.cdp.send('Page.navigate', { url: base });
	await sleep(2500);
	await shootAll('loading', 200);
	await page.cdp.send('Network.setBlockedURLs', { urls: [] });
} finally {
	await page.close();
	site.stop();
}
