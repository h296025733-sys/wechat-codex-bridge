const endpoints = [
  ['npm-registry', 'https://registry.npmjs.org/openclaw/latest', true],
  ['openai-discovery', 'https://auth.openai.com/.well-known/openid-configuration', true],
  ['wechat-host', 'https://ilinkai.weixin.qq.com', false],
];
(async () => {
  let failed = false;
  for (const [name, url, requireSuccess] of endpoints) {
    try {
      const result = await fetch(url, { signal: AbortSignal.timeout(15000) });
      console.log(JSON.stringify({ name, status: result.status, reachable: true, authenticated: false }));
      await result.body?.cancel();
      if (requireSuccess && !result.ok) failed = true;
    } catch (error) {
      failed = true;
      console.log(JSON.stringify({ name, reachable: false, error: error.cause?.code || error.message }));
    }
  }
  console.log('Public reachability only; this does not verify OAuth token exchange or model access.');
  process.exitCode = failed ? 1 : 0;
})();
