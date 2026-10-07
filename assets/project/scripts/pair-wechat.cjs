const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { spawn } = require('node:child_process');
const { StringDecoder } = require('node:string_decoder');
const root = path.resolve(__dirname, '..');
const cli = path.join(root, 'runtime', 'node_modules', 'openclaw', 'openclaw.mjs');
const QR = require(require.resolve('qrcode', { paths: [path.dirname(cli)] }));
const artifacts = path.join(root, 'artifacts');
const page = path.join(artifacts, 'wechat-pair.html');
const qrImage = path.join(artifacts, 'wechat-login-current.png');
const decoder = new StringDecoder('utf8');
const noBrowser = process.argv.includes('--no-browser');
const timeoutIndex = process.argv.indexOf('--timeout-seconds');
const timeoutSeconds = timeoutIndex >= 0 ? Number(process.argv[timeoutIndex+1]) : 0;
if (!Number.isInteger(timeoutSeconds) || timeoutSeconds < 0 || timeoutSeconds > 600) throw new Error('Invalid pairing timeout.');
fs.mkdirSync(artifacts, { recursive: true });
fs.copyFileSync(path.join(__dirname, 'wechat-pair.template.html'), page);
let pending = '', previous = '', opened = false, pairStatus = 'waiting', imageReady = false;
let imageQueue = Promise.resolve();
// Serve only a status page and one temporary QR image on loopback, never a directory.
const server = http.createServer((req, res) => {
  const route = new URL(req.url, 'http://localhost').pathname;
  res.setHeader('Cache-Control', 'no-store');
  if (route === '/') {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end(fs.readFileSync(page));
  } else if (route === '/wechat-login-current.png' && imageReady && pairStatus === 'waiting') {
    res.setHeader('Content-Type', 'image/png');
    res.end(fs.readFileSync(qrImage));
  } else { res.writeHead(404); res.end('Not available'); }
});
function finishPage(success) {
  pairStatus = success ? 'connected' : 'incomplete';
  const title = success ? '\u5fae\u4fe1\u5df2\u8fde\u63a5' : '\u672c\u6b21\u8fde\u63a5\u672a\u5b8c\u6210';
  const body = success ? '\u8bf7\u56de\u5230 Codex \u7ee7\u7eed\u6d4b\u8bd5\u5fae\u4fe1\u6536\u53d1\u3002' : '\u8bf7\u56de\u5230 Codex \u544a\u77e5\u9875\u9762\u72b6\u6001\u3002';
  fs.writeFileSync(page, '<!doctype html><meta charset="utf-8"><title>'+title+'</title><body style="font:22px/1.8 system-ui;text-align:center;padding:70px"><h1>'+title+'</h1><p>'+body+'</p>');
}
function openPage(url) {
  console.log('\nWECHAT_PAIR_PAGE: ' + url);
  console.log('WECHAT_QR_IMAGE: ' + qrImage);
  if (noBrowser) return;
  // Agent must still confirm visibility or render the local image; launch != visible.
  const opener = spawn('powershell.exe', ['-NoProfile','-NonInteractive','-WindowStyle','Hidden','-Command','Start-Process -FilePath $env:BRIDGE_PAIR_PAGE'], { env:{...process.env,BRIDGE_PAIR_PAGE:url}, windowsHide:true, stdio:'ignore' });
  opener.on('error', error => console.error('Browser launch error:', error.message));
  opener.on('close', code => { if (code !== 0) console.error('Browser launcher exited:', code); });
}
function consumeLine(line) {
  const match = line.match(/https:\/\/liteapp\.weixin\.qq\.com\/q\/[^\s\x1b]+/);
  if (!match) return;
  let url;
  try { url = new URL(match[0]); } catch { return; }
  if (url.hostname !== 'liteapp.weixin.qq.com' || !url.searchParams.get('qrcode') || url.href === previous) return;
  previous=url.href;
  imageQueue=imageQueue.then(async () => {
    const temporary=path.join(artifacts,'wechat-login-next.png');
    await QR.toFile(temporary,url.href,{width:600,margin:4,errorCorrectionLevel:'M'});
    fs.copyFileSync(temporary,qrImage);
    imageReady=true;
    console.log('\nQR_UPDATED: Scan the current QR on the pairing page.');
    if (!opened) { opened=true; openPage('http://127.0.0.1:'+server.address().port+'/'); }
  }).catch(error => console.error('QR image generation failed:',error.message));
}
server.on('error', error => { console.error(error.message); process.exitCode=1; });
server.listen(0,'127.0.0.1',() => {
  const child=spawn(process.execPath,[cli,'channels','login','--channel','openclaw-weixin'],{cwd:root,env:process.env,stdio:['inherit','pipe','pipe'],windowsHide:true});
  let childEnded=false;
  function terminateChild() {
    if (childEnded || !child.pid) return;
    // This PID is the still-running child created above, not a name-based match.
    const killer=spawn('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});
    killer.on('error',error => console.error('Pairing process cleanup error:',error.message));
  }
  const timer=timeoutSeconds ? setTimeout(() => { console.error('Pairing deadline reached without confirmed completion.'); terminateChild(); },timeoutSeconds*1000) : null;
  child.stdout.on('data',chunk => {
    process.stdout.write(chunk);
    pending+=decoder.write(chunk);
    const lines=pending.split(/\r?\n/); pending=lines.pop();
    for (const line of lines) consumeLine(line);
  });
  child.stderr.on('data',chunk => process.stderr.write(chunk));
  child.on('error',error => console.error('Login process error:',error.message));
  child.on('close',async code => {
    childEnded=true;
    if (timer) clearTimeout(timer);
    pending+=decoder.end(); if (pending) consumeLine(pending);
    await imageQueue;
    finishPage(code === 0);
    process.exitCode=code ?? 1;
    // Allow the visible page to refresh to its final status, then release the server.
    setTimeout(() => server.close(),5500);
  });
  process.on('SIGINT',terminateChild);
});
