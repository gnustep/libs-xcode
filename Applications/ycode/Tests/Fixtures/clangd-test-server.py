#!/usr/bin/env python3
"""Deterministic LSP peer: fragmented frames, unsaved changes, and process failure."""
import json
import sys


def send(message):
    body = json.dumps(message, ensure_ascii=False).encode('utf-8')
    packet = ('Content-Length: %d\r\n\r\n' % len(body)).encode() + body
    # Exercise framing independent of pipe read boundaries.
    for index in range(0, len(packet), 7):
        sys.stdout.buffer.write(packet[index:index + 7])
        sys.stdout.buffer.flush()


documents = {}
versions = {}
while True:
    length = None
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            sys.exit(0)
        if line == b'\r\n':
            break
        if line.lower().startswith(b'content-length:'):
            length = int(line.split(b':', 1)[1])
    message = json.loads(sys.stdin.buffer.read(length))
    method = message.get('method')
    params = message.get('params', {})
    if method == 'initialize':
        send({'jsonrpc': '2.0', 'id': message['id'], 'result': {
            'capabilities': {'positionEncoding': 'utf-16', 'textDocumentSync': 2,
                             'definitionProvider': True}}})
    elif method == 'textDocument/didOpen':
        doc = params['textDocument']
        documents[doc['uri']] = doc['text']
        versions[doc['uri']] = doc['version']
    elif method == 'textDocument/didChange':
        documents[params['textDocument']['uri']] = params['contentChanges'][0]['text']
        versions[params['textDocument']['uri']] = params['textDocument']['version']
    elif method == 'textDocument/didClose':
        documents.pop(params['textDocument']['uri'], None)
    elif method == 'textDocument/definition':
        uri = params['textDocument']['uri']
        content = documents[uri]
        if content == 'CRASH':
            sys.exit(1)
        if content == 'MALFORMED':
            sys.stdout.buffer.write(b'Content-Length: -1\r\n\r\n')
            sys.stdout.buffer.flush()
            continue
        send({'jsonrpc': '2.0', 'method': 'textDocument/publishDiagnostics',
              'params': {'uri': uri, 'diagnostics': []}})
        send({'jsonrpc': '2.0', 'id': message['id'], 'result': [{
            'uri': uri, 'range': {'start': params['position'], 'end': params['position']},
            'observedText': content}]})
    elif method in ('textDocument/hover', 'textDocument/documentSymbol',
                    'textDocument/references', 'textDocument/completion'):
        uri = params['textDocument']['uri']
        origin = {'line': 0, 'character': 0}
        span = {'start': origin, 'end': {'line': 0, 'character': 3}}
        for version in (versions[uri] - 1, None, versions[uri]):
            send({'jsonrpc': '2.0', 'method': 'textDocument/publishDiagnostics',
                  'params': {'uri': uri, 'version': version, 'diagnostics': [
                      {'range': span, 'severity': 2, 'message': 'Fixture warning'}]}})
        if method.endswith('/hover'):
            result = {'contents': {'kind': 'plaintext', 'value': 'int value'}}
        elif method.endswith('/documentSymbol'):
            assert 'position' not in params
            result = [{'name': 'value', 'kind': 13, 'range': span, 'selectionRange': span}]
        elif method.endswith('/references'):
            assert params['context']['includeDeclaration']
            result = [{'uri': uri, 'range': span}]
        else:
            result = {'isIncomplete': False, 'items': [
                {'label': 'value', 'detail': 'int value',
                 'textEdit': {'range': span, 'newText': 'value'}}]}
        send({'jsonrpc': '2.0', 'id': message['id'], 'result': result})
