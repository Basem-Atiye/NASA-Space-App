const WebSocket = require('ws');
const ws = new WebSocket(process.argv[2]);
const expr = process.argv[3];
ws.on('open', () => {
  ws.send(JSON.stringify({id:1, method:'Runtime.evaluate', params:{expression: expr, awaitPromise:true, returnByValue:true}}));
});
ws.on('message', (d) => { console.log(d.toString()); ws.close(); process.exit(0); });
setTimeout(() => { console.error('timeout'); process.exit(2); }, 25000);
