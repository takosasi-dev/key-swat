// 起動までの秒数を測る(ページを開いてから S0 の状態が出るまで)。毎回、使い捨てのプロフィールで Chrome を立ち上げ直す。
//     node tests/web/boot.mjs 3                          手元の build/web を 3 回
//     KS_URL=https://…/key-swat/ node tests/web/boot.mjs 3   公開した物を 3 回
import { open, serve } from './lib.mjs';

const N = Number(process.argv[2] || 3);
const site = serve();
const times = [];
try {
	for (let i = 0; i < N; i++) {
		const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
		try {
			const s = await page.waitState((st) => st.screen === 'gate', 60000);
			times.push(s ? Date.now() - page.t0 : NaN);
			console.log(`${i + 1} 回目: S0 まで ${times.at(-1)} ms・エラー ${page.errors().length} 件・版 ${await page.evaluate("document.title")}`);
		} finally {
			await page.close();
		}
	}
} finally {
	site.stop();
}
console.log(`S0 まで(ms): ${times.join(' / ')}`);
