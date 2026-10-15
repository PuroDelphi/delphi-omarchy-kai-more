#!/usr/bin/env python3
"""Conference client: Linux mailbox -> FMX app -> real local MCP HTTP endpoint."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import time
import uuid

DEFAULT = Path.home() / 'Windows' / 'CiudadVivaMCP' / 'Win32' / 'Debug' / 'DemoBridge'

def rpc(root, method, params=None):
    identity = uuid.uuid4().hex
    with (root / '.client.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with (root / 'request.json').open('r+', encoding='utf-8-sig') as stream:
            stream.seek(0)
            json.dump({'id': identity, 'rpc': {'jsonrpc': '2.0', 'id': identity,
                       'method': method, 'params': params or {}}}, stream)
            stream.truncate()
            stream.flush()
            os.fsync(stream.fileno())
        end = time.monotonic() + 25
        while time.monotonic() < end:
            try:
                reply = json.loads((root / 'response.json').read_text(encoding='utf-8-sig'))
                if reply.get('id') == identity:
                    if 'error' in reply:
                        raise RuntimeError(reply['error'])
                    return reply['result']
            except (FileNotFoundError, json.JSONDecodeError):
                pass
            time.sleep(.1)
        raise TimeoutError('La app no respondio. Comprueba que esta ejecutandose.')

def tool(root, name, arguments=None, expect_error=False):
    reply = rpc(root, 'tools/call', {'name': name, 'arguments': arguments or {}})
    failed = 'error' in reply or reply.get('result', {}).get('isError', False)
    if failed != expect_error:
        raise RuntimeError(json.dumps(reply, ensure_ascii=False))
    if expect_error:
        return reply
    return json.loads(reply['result']['content'][0]['text'])

def tour(root):
    rpc(root, 'initialize', {'protocolVersion': '2025-11-25', 'capabilities': {},
                            'clientInfo': {'name': 'conference-linux-client', 'version': '1.0'}})
    tools = rpc(root, 'tools/list')
    assert len(tools['result']['tools']) == 4
    print('1. Herramientas descubiertas:', ', '.join(t['name'] for t in tools['result']['tools']))
    rules = rpc(root, 'resources/read', {'uri': 'city://rules'})
    assert rules.get('result')
    print('2. Reglas obtenidas mediante resources/read.')
    before = tool(root, 'city_scenario', {'scenario': 'storm'})
    print('3. Tormenta:', json.dumps(before, ensure_ascii=False))
    tool(root, 'city_apply_plan', {'hospital_mw': 0, 'homes_mw': 45, 'industry_mw': 25}, expect_error=True)
    after = tool(root, 'city_status')
    assert before['allocation_mw'] == after['allocation_mw']
    print('4. Plan peligroso rechazado; asignaciones intactas.')
    safe = tool(root, 'city_apply_plan', {'hospital_mw': 30, 'homes_mw': 30, 'industry_mw': 15})
    assert safe['allocation_mw'] == {'hospital': 30, 'homes': 30, 'industry': 15}
    assert safe['overload'] is False
    verified = tool(root, 'city_status')
    assert verified == safe
    print('5. Plan seguro aplicado y verificado:', json.dumps(verified, ensure_ascii=False))
    print('PASS: MCP real, validacion atomica y actualizacion del estado de la app.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['status', 'tools', 'storm', 'tour', 'reset'], default='status', nargs='?')
    parser.add_argument('--bridge', type=Path, default=DEFAULT)
    args = parser.parse_args()
    if not args.bridge.is_dir():
        parser.error('Abre CiudadViva.exe en Windows para crear DemoBridge, o indica --bridge.')
    if args.command == 'tour':
        tour(args.bridge)
    elif args.command == 'tools':
        print(json.dumps(rpc(args.bridge, 'tools/list'), ensure_ascii=False, indent=2))
    else:
        name, params = {'status': ('city_status', {}), 'storm': ('city_scenario', {'scenario': 'storm'}),
                        'reset': ('city_reset', {})}[args.command]
        print(json.dumps(tool(args.bridge, name, params), ensure_ascii=False, indent=2))
