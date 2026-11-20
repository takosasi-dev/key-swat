// Web 版をまとめて確かめ、画面を撮る(Chrome 1 回の起動で済ませる): 起動の時間・S0→S1→S4→S2→S5→S3→もう1回(AC-18)・
// 盤の 40 キーが本物のキー(CDP の Input.dispatchKeyEvent)で届くか(R-2 の一部)・タブが裏で一時停止(AC-20)・
// 保存と ParryDuel の保存の共存(AC-24)・読み込み後の通信 0 件(AC-21)・押してから描くまで(NFR-2 の目安)・揺れ 切と点滅を弱める(NFR-12)。
// 今日の盤は JS の bot(巣 → 予兆中の元 → 広がりが近い順)で 2 分強守り、跳ぶ虫が出た後は手を止めて感染で終わらせる。4 分ほどかかる。
//     node tests/web/check.mjs            手元の build/web を配って確かめる
//     KS_URL=https://…/key-swat/ node tests/web/check.mjs   公開した物を確かめる
//     node tests/web/check.mjs --quick    今日の盤を 15 秒で切り上げる(公開 URL の確かめ用)
//     node tests/web/check.mjs --docs     README の画像を docs/ に写す
import { copyFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { expect, failureCount, open, OUT, ROOT, serve, sleep } from './lib.mjs';

const QUICK = process.argv.includes('--quick');
const LABELS = '1234567890qwertyuiopasdfghjkl;zxcvbnm,./'.split('');
const PK_NAMES = LABELS.map((c) => ({ ';': 'Semicolon', ',': 'Comma', '.': 'Period', '/': 'Slash' })[c] ?? c.toUpperCase());
const CLEAN = 0, NEST = 2, JUMPER = 3;
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const shot = (label) => page.shot(label);
const press = (i) => page.key(LABELS[i]); // 盤の番号 i のキーを押して離す
const play = async () => (await page.state()).play;

// 正しい bot と同じ選び方(仕様書 §9.10): 巣 → 予兆中の元(spread_left の小さい順)→ ほかの虫(spread_left の小さい順)
function pick(p) {
	let best = -1, bestKey = null;
	for (let i = 0; i < 40; i++) {
		if (!p.active[i] || p.state[i] === CLEAN) continue;
		const key = [p.state[i] === NEST ? 0 : p.target[i] >= 0 ? 1 : 2, p.spread_left[i], i];
		if (bestKey === null || key[0] < bestKey[0] || (key[0] === bestKey[0] && (key[1] < bestKey[1] || (key[1] === bestKey[1] && key[2] < bestKey[2])))) {
			best = i;
			bestKey = key;
		}
	}
	return best;
}

// F を潰してから、clean のキーを外し続けて耐久で終わらせる。before(p) が真の間は先にそちらを押す
async function loseByMisses(squashFirst = 0) {
	await press(23);
	await page.waitState((s) => s.play?.clock_running, 3000);
	for (let n = 0; n < squashFirst;) {
		const p = await play();
		const i = pick(p);
		if (i >= 0) { await press(i); n++; }
		await sleep(80);
	}
	for (let k = 0; k < 30; k++) {
		const s = await page.state();
		if (s.screen === 'result' || s.play?.over) break;
		await press(s.play.state.findIndex((st, i) => st === CLEAN && s.play.active[i]));
		await sleep(40);
	}
	return page.waitState((s) => s.screen === 'result', 5000);
}

try {
	expect(page.booted, `起動した(Godot の印字まで ${page.bootMs} ms)`);
	const s0 = await page.waitState((s) => s.screen === 'gate', 30000);
	expect(!!s0, `S0 が出る(ページを開いてから ${Date.now() - page.t0} ms。NFR-5 は 10 秒以内)`);
	const loadedAt = Date.now();
	await page.evaluate(`localStorage.setItem('parry-duel/save', '{"version":1,"keep":"me"}')`);
	await sleep(300);
	await shot('s0');
	await page.touch(...(await page.gameCss(640, 360)));
	await sleep(600);
	expect((await page.state()).screen === 'gate', 'タッチでは始まらない(FR-26)');
	await shot('s0_touch');
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'キーで S1');
	await sleep(300);
	await shot('s1_title_first');
	// 16:9 でない窓: 余りは背景色で、舞台は真ん中
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 860, deviceScaleFactor: 1, mobile: false });
	await sleep(400);
	await shot('s1_title_tall');
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(300);

	// S4 設定(↓↓ Enter)→ Esc で戻ると、設定のボタンが選ばれたまま
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings')), '↓↓ Enter で設定');
	await page.key('ArrowRight'); // 音量 75 → 100
	await sleep(200);
	await shot('s4_settings');
	await page.key('ArrowLeft');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'Esc でタイトルへ');
	await page.key('ArrowDown'); // 設定 → 今日の盤(一回りする)
	await page.key('Enter');
	const p0 = await page.waitState((s) => s.screen === 'play');
	expect(!!p0, '設定から戻って ↓ Enter で今日の盤(設定のボタンが選ばれたまま戻る)');
	await sleep(400);
	await shot('s2_start');
	await press(24); // G(clean)。時計が動く前の外れは数えない
	await sleep(60);
	expect((await play()).integrity === 100, '時計が動く前の外れで耐久が減らない');
	await press(23); // F
	expect(!!(await page.waitState((s) => s.play?.clock_running, 3000)), 'F の物理キーで F の虫が潰れ、時計が動く');
	await sleep(80);
	await shot('s2_first_squash');

	const seen = new Set();
	const snaps = {
		chain10: (p) => p.chain >= 10 && p.chain <= 11,
		nest: (p) => p.state.includes(NEST),
		unlock: (p) => p.clock >= 9640 && p.clock < 9700,
		digits: (p) => p.clock >= 9900 && p.state.slice(0, 10).some((s) => s !== CLEAN),
		jumper: (p) => p.state.includes(JUMPER),
	};
	let warnShot = false, pausedOnce = false, missed = false;
	const until = QUICK ? 15 * 120 : 14400 + 6 * 120;
	for (;;) {
		const p = await play();
		if (!p || p.over || p.clock >= until) break;
		// 予兆(D と K)が出るまで押さずに待ち、撮る。片方の元を潰して止め(緑の輪)、もう片方は広がらせる
		if (!warnShot) {
			warnShot = true;
			const w = await page.waitState((st) => st.play?.target.some((t) => t >= 0), 10000);
			expect(!!w, '予兆が出る');
			await sleep(150);
			await shot('s2_warn');
			await press(w.play.target.findIndex((t) => t >= 0));
			await sleep(70);
			await shot('s2_saved');
			await page.waitState((st) => st.play?.target.every((t) => t < 0), 2000);
			await sleep(40);
			await shot('s2_spread');
			continue;
		}
		for (const [label, when] of Object.entries(snaps)) {
			if (when(p)) { await shot('s2_' + label); delete snaps[label]; }
		}
		// わざと 1 回外す(×の光と揺れ)
		if (!missed && p.clock > 1500) {
			missed = true;
			await press([24, 25, 21, 28].find((k) => p.state[k] === CLEAN));
			await sleep(50);
			await shot('s2_miss');
			continue;
		}
		// 一時停止: Esc と、タブが裏に回る(E-10)
		if (!pausedOnce && p.clock > 3000) {
			pausedOnce = true;
			await page.key('Escape');
			expect(!!(await page.waitState((st) => st.paused, 3000)), 'Esc で一時停止');
			await sleep(300);
			await shot('s5_pause');
			const c0 = (await play()).clock;
			await sleep(1000);
			expect((await play()).clock === c0, '一時停止の間、時計が止まる');
			await page.key('ArrowDown');
			await page.key('ArrowDown');
			await page.key('Enter');
			expect(!!(await page.waitState((st) => st.screen === 'settings', 3000)), '一時停止から設定');
			await shot('s4_settings_from_pause');
			await page.key('Escape');
			expect(!!(await page.waitState((st) => st.screen === 'play' && st.paused, 3000)), '設定の戻るで一時停止へ');
			await page.key('Escape');
			expect(!!(await page.waitState((st) => !st.paused, 3000)), 'Esc で続ける');
			await page.hide();
			await sleep(1000);
			await page.show();
			expect(!!(await page.waitState((st) => st.paused, 5000)), 'タブが裏に回ると一時停止(AC-20)');
			const c1 = (await play()).clock;
			await sleep(800);
			expect((await play()).clock === c1, '戻っても自動では再開しない');
			await page.key('Escape');
			continue;
		}
		const i = pick(p);
		if (i >= 0) {
			await press(i);
			seen.add(i);
		}
		await sleep(60);
	}
	if (!QUICK) expect(Object.keys(snaps).length === 0, `プレイの場面が全部撮れた(残り: ${Object.keys(snaps).join(' ') || '無し'})`);
	console.log(`    bot が押した盤のキー: ${seen.size} 個`);

	// 手を止めて感染で終わらせる。山場(感染 25%)・終わり間際(30% 超で画面の縁が赤い)・終わった瞬間(赤い幕)を撮る
	const ends = {
		s2_climax: (p) => !p.over && p.infected * 100 >= p.active_count * 25,
		s2_danger: (p) => !p.over && p.infected * 100 > p.active_count * 30,
		s2_over: (p) => p.over,
	};
	let res = null;
	for (const end = Date.now() + 120000; Date.now() < end && !res;) {
		const s = await page.state();
		if (s.screen === 'result') res = s;
		else for (const [label, when] of Object.entries(ends)) {
			if (s.play && when(s.play)) { await shot(label); delete ends[label]; break; }
		}
		await sleep(30);
	}
	console.log(`    撮れなかった終わりの場面: ${Object.keys(ends).join(' ') || '無し'}`);
	expect(!!res, '感染で S3');
	await sleep(900);
	await shot('s3_result');
	expect(res?.share?.includes('(今日の盤・1回目)'), `共有する文字: ${JSON.stringify(res?.share)}`);
	const saved = await page.saved();
	expect(saved?.daily?.first != null, `今日の盤の 1 回目が key-swat/save に入る: ${JSON.stringify(saved)}`);
	expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"version":1,"keep":"me"}', 'ParryDuel の保存を消さない(AC-24)');
	await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
	await page.clickButton('copy');
	await sleep(500);
	const c1 = await page.clipboard();
	expect(c1.startsWith('KeySwat '), `コピーのボタン: ${JSON.stringify(c1).slice(0, 80)}`);
	await shot('s3_copied');

	// もう1回(R)→ 外し続けて耐久で終わる。最高との差は「最高まで −」
	await page.key('r');
	expect(!!(await page.waitState((s) => s.screen === 'play', 3000)), 'もう1回(R)');
	const r2 = await loseByMisses();
	expect(r2?.share?.includes('(今日の盤)'), `2 回目は「今日の盤」: ${JSON.stringify(r2?.share)}`);
	await sleep(900);
	await shot('s3_result_integrity');
	await page.clickButton('title');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), 'タイトルへ(マウス)');
	await sleep(300);
	await shot('s1_title_record');

	// 練習を 2 回: 2 回目は 4 匹潰してから外す → 新しい記録
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play', 3000);
	await loseByMisses();
	await sleep(400);
	await page.key('r');
	await page.waitState((s) => s.screen === 'play', 3000);
	const r4 = await loseByMisses(3);
	expect(r4?.share?.includes('(練習)'), `練習: ${JSON.stringify(r4?.share)}`);
	await sleep(900);
	await shot('s3_result_newbest');

	// 揺れ 切・点滅を弱める 入 で外す(NFR-12)
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title', 3000);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'settings', 3000);
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.key('ArrowDown');
	await page.key('Enter');
	await sleep(200);
	await shot('s4_settings_changed');
	const st = (await page.saved())?.settings;
	expect(st?.shake === false && st?.reduce_flash === true, `設定が保存に入る: ${JSON.stringify(st)}`);
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title', 3000);
	await page.key('ArrowUp'); // 設定 → 練習
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play', 3000);
	await press(23);
	await page.waitState((s) => s.play?.clock_running, 3000);
	let moved = false;
	for (let k = 0; k < 4; k++) {
		const p = await play();
		await press(p.state.findIndex((s, i) => s === CLEAN && p.active[i]));
		for (let j = 0; j < 4; j++) {
			if ((await play()).pos.some((v) => v !== 0)) moved = true;
			if (k === 0 && j === 0) await shot('s2_miss_reduced');
			await sleep(20);
		}
	}
	expect(!moved, '揺れを切ると外しても画面が動かない');

	const after = page.requests.filter((r) => r.at > loadedAt);
	expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
	console.log('    押してから描くまで・1 フレーム(ms): ' + JSON.stringify(await page.stats()));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));

	// キーの確かめの画面(?keys=1)で 40 キーを全部押す
	const base = page.url0.split('?')[0];
	expect(await page.goto(base + '?keys=1&debug=1'), 'キーの確かめの画面を開き直す');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'keys', 3000)), '?keys=1 でキーの確かめの画面');
	const names = [];
	for (const c of LABELS) {
		await page.key(c);
		await sleep(30);
		names.push((await page.state()).keys.at(-1).pk_name);
	}
	const wrong = LABELS.filter((c, i) => names[i] !== PK_NAMES[i]);
	expect(wrong.length === 0, `40 キーの physical_keycode が表のとおり(違う: ${wrong.join(' ') || '無し'})`);
	await shot('keys');
	// NFR-1 の負荷の場面(虫 15・破片 240・浮かぶ数字 20)を 60 秒
	if (!QUICK) {
		expect(await page.goto(base + '?debug=1&load=1'), '負荷の場面を開き直す');
		await page.waitState((s) => s.screen === 'gate', 20000);
		await page.key('x');
		await page.waitState((s) => s.screen === 'play', 3000);
		await sleep(60000);
		await shot('load');
		const lp = await play();
		expect((await page.state()).screen === 'play' && lp?.infected === 15 && lp?.active_count === 40, `負荷の場面が 60 秒続いた(虫 ${lp?.infected} / ${lp?.active_count})`);
		const f = (await page.stats()).frame;
		expect(f.p95 <= 16.7, `負荷の場面のフレーム 95% 値 ${f.p95} ms(${f.n} フレーム。窓なし Chrome の値で、本物の画面ではない)`);
	}
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
	if (process.argv.includes('--docs')) {
		mkdirSync(path.join(ROOT, 'docs'), { recursive: true });
		for (const f of ['s1_title_record', 's2_climax', 's3_result_newbest']) copyFileSync(path.join(OUT, f + '.png'), path.join(ROOT, 'docs', f + '.png'));
	}
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? '全部 OK' : `${failureCount()} 件 NG`);
process.exit(failureCount() === 0 ? 0 : 1);
