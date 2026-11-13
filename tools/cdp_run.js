const fs = require('fs');
const WebSocket = require('ws');

const wsUrl = process.argv[2];
const exprPath = process.argv[3];
const expr = fs.readFileSync(exprPath, 'utf8');

const ws = new WebSocket(wsUrl);
ws.on('open', () => {
  ws.send(
    JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: { expression: expr, awaitPromise: true, returnByValue: true },
    }),
  );
});
ws.on('message', (d) => {
  console.log(d.toString());
  ws.close();
  process.exit(0);
});
setTimeout(() => {
  console.error('timeout');
  process.exit(2);
}, 25000);
