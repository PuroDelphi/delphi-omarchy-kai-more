'use strict';
// Only proxies the installed connector's authenticated Windows loopback endpoint.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const root = __dirname;
const discovery = path.join(process.env.LOCALAPPDATA, 'MCP2Delphi', 'Servers');
const read = p => JSON.parse(fs.readFileSync(p, {encoding:'utf8', flag:'rs'}).replace(/^\uFEFF/, ''));
const save = (name, value) => fs.writeFileSync(path.join(root, name), JSON.stringify(value));
function findServer() {
  const files = fs.readdirSync(discovery).filter(n => n.endsWith('.token.json'));
  for (const name of files.reverse()) {
    const s = read(path.join(discovery, name));
    const u = new URL(s.url);
    if (u.hostname === '127.0.0.1' && Number(u.port) >= 8776 && Number(u.port) <= 8786 && s.token) return s;
  }
  throw Error('No se encuentra el servidor del IDE. Reinicia Delphi tras instalar el paquete.');
}
function rpc(server, body) {
  const u = new URL(server.url);
  return new Promise((resolve,reject) => {
    const data = JSON.stringify(body);
    const req = http.request({hostname:'127.0.0.1',port:u.port,path:'/mcp',method:'POST',headers:{'Content-Type':'application/json','X-MCP2Delphi-Token':server.token,'Content-Length':Buffer.byteLength(data)}}, res => {
      let result='';
      res.setEncoding('utf8');
      res.on('data', c => {result+=c;if(result.length>8*1024*1024)req.destroy(Error('Respuesta demasiado grande'));});
      res.on('end', () => {try{if(res.statusCode!==200)throw Error('HTTP '+res.statusCode);resolve(JSON.parse(result));}catch(e){reject(e);}});
      res.on('error',reject);
    });
    req.setTimeout(180000,()=>req.destroy(Error('Tiempo de espera agotado')));
    req.on('error',reject);req.end(data);
  });
}
async function main() {
  const server=findServer();
  const tools=await rpc(server,{jsonrpc:'2.0',id:1,method:'tools/list',params:{}});
  if(tools.error || !tools.result?.tools)throw Error('No se pudo enumerar las herramientas del IDE');
  save('herramientas.json',tools);
  const statusTool=tools.result.tools.find(t=>t.name==='ide_status');
  if(statusTool)save('consulta-ide.json',await rpc(server,{jsonrpc:'2.0',id:2,method:'tools/call',params:{name:statusTool.name,arguments:{}}}));
  for(const name of ['request.json','response.json'])if(!fs.existsSync(path.join(root,name)))save(name,{idle:true});
  console.log('Conexion autenticada comprobada: '+tools.result.tools.length+' herramientas del IDE.');
  let lastId=null;
  while(true){
    save('estado.json',{updated:new Date().toISOString(),pid:process.pid,ready:true,tools:tools.result.tools.length});
    let message;
    try{message=read(path.join(root,'request.json'));}catch{}
    if(message && /^[a-f0-9]{32}$/.test(message.id) && message.id!==lastId){
      try{save('response.json',{id:message.id,result:await rpc(server,message.rpc)});}
      catch(e){save('response.json',{id:message.id,error:e.message});}
      lastId=message.id;
    }
    await new Promise(r=>setTimeout(r,300));
  }
}
main().catch(e=>{save('estado.json',{ready:false,error:e.message});console.error(e.message);process.exitCode=1;});
