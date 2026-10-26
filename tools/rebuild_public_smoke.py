"""Opt-in public API QA with disposable users; never prints passwords or tokens.

Usage: python tools/rebuild_public_smoke.py --ledger <outside-repo.json> --image <fixture.png>
The ledger contains only temporary account IDs and record IDs for bounded cleanup.
Phone UI validation is separate; this does not claim two physical phones.
"""
import argparse
import concurrent.futures
import json
import secrets
import sys
import uuid
from pathlib import Path
import requests

BASE = 'http://47.121.119.191:3001'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ledger', required=True)
    parser.add_argument('--image', required=True)
    parser.add_argument('--accounts-stdin', action='store_true', help='Disposable QA accounts supplied in memory when public registration is closed')
    args = parser.parse_args()
    ledger = {'users': [], 'trips': [], 'works': [], 'spots': []}

    def record():
        Path(args.ledger).write_text(json.dumps(ledger, indent=2), encoding='utf-8')

    def call(session, method, endpoint, expected=200, **kwargs):
        response = session.request(method, BASE + endpoint, timeout=30, **kwargs)
        assert response.status_code == expected, (endpoint, response.status_code, response.json().get('message'))
        return response.json().get('data')

    sessions = []
    provided = json.load(sys.stdin) if args.accounts_stdin else None
    for index in range(3):
        session = requests.Session()
        if provided:
            account = provided[index]
            username, password, user_id = account['username'], account['password'], account['id']
        else:
            username = 'qapub_' + uuid.uuid4().hex[:14]
            password = secrets.token_urlsafe(32)
            data = call(session, 'POST', '/api/auth/register', json={'username': username, 'password': password,
                'nickname': 'Rebuild QA', 'gender': 'female' if index == 1 else 'male'})
            user_id = data['user']['id']
        ledger['users'].append({'id': user_id, 'username': username})
        record()
        login = call(session, 'POST', '/api/auth/login', json={'username': username, 'password': password})
        session.headers['Authorization'] = 'Bearer ' + (login.get('accessToken') or login['token'])
        sessions.append(session)
    a, b, outsider = sessions
    invite = call(a, 'POST', '/api/couple/invite')
    call(b, 'POST', '/api/couple/accept', json={'code': invite.get('invite_code') or invite.get('code')})
    print('PASS three independent public logins and real couple invitation')
    for i, (lat, lng) in enumerate([(30.2491, 120.1495), (30.2903, 120.2126)]):
        place = call(a, 'POST', '/api/travel/spots', json={'name': 'QA-PUBLIC-' + str(i), 'city': '杭州', 'status': 'wish', 'lat': lat, 'lng': lng})
        ledger['spots'].append(place['id']); record()
    plan = {'clientId': str(uuid.uuid4()), 'title': 'QA-PUBLIC-JOURNEY', 'days': 2,
        'stops': [{'key': 'first', 'spotId': ledger['spots'][0], 'day': 0, 'mode': 'walking', 'note': 'Keep'},
                  {'key': 'second', 'spotId': ledger['spots'][1], 'day': None, 'mode': 'bicycling', 'note': ''}]}
    trip = call(a, 'POST', '/api/journeys', json=plan)
    ledger['trips'].append(trip['id']); record()
    assert trip['clientId'] == plan['clientId']
    call(outsider, 'GET', '/api/journeys/' + str(trip['id']), expected=404)
    left = call(a, 'GET', '/api/journeys/' + str(trip['id']))
    right = call(b, 'GET', '/api/journeys/' + str(trip['id']))
    endpoint = '/api/journeys/' + str(trip['id'])
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        pending = [pool.submit(session.put, BASE + endpoint,
            json={**plan, 'revision': snapshot['revision'], 'title': 'QA-PUBLIC-' + name}, timeout=30)
            for session, snapshot, name in [(a, left, 'A'), (b, right, 'B')]]
        assert sorted(f.result().status_code for f in pending) == [200, 409]
    print('PASS two independently logged-in sessions get one save and one conflict')
    image = Path(args.image).read_bytes()
    document = {'kind': 'polaroid', 'templateId': 'tape', 'lookId': 'ccd_cool', 'title': 'QA-PUBLIC-PAPER',
        'note': 'A shared memory', 'transforms': [{'scale': 1.2, 'x': .1, 'y': 0}],
        'frontInk': [{'width': .006, 'color': 0xff202126, 'points': [[.1, .85], [.8, .9]]}]}
    work = call(a, 'POST', '/api/creations', data={'clientId': str(uuid.uuid4()), 'document': json.dumps(document), 'tripId': trip['id']},
        files={'preview': ('preview.png', image, 'image/png'), 'source0': ('source.png', image, 'image/png')})
    ledger['works'].append(work['id']); record()
    assert call(b, 'GET', '/api/creations/' + str(work['id']))['document']['frontInk'] == document['frontInk']
    call(outsider, 'GET', '/api/creations/' + str(work['id']), expected=404)
    assert any(w['id'] == work['id'] for w in call(b, 'GET', '/api/creations'))
    print('PASS multipart artwork preserves editable document and shares only with current partner')
    updated = call(b, 'PUT', endpoint, json={**plan, 'revision': 2,
        'stops': [{**s, 'day': 1} for s in reversed(plan['stops'])]})
    assert updated['stops'][1]['note'] == 'Keep' and updated['stops'][0]['mode'] == 'bicycling'
    call(a, 'DELETE', endpoint + '?revision=2', expected=409)
    call(a, 'DELETE', endpoint + '?revision=3')
    assert call(a, 'GET', '/api/creations/' + str(work['id']))['tripId'] is None
    assert len(call(b, 'GET', '/api/travel/spots')['list']) == 2
    call(a, 'DELETE', '/api/creations/' + str(work['id']) + '?revision=2')
    for spot in ledger['spots']:
        call(a, 'DELETE', '/api/travel/spots/' + str(spot))
    call(a, 'DELETE', '/api/couple')
    ledger['passed'] = True
    record()
    print('PASS cross-day reorder, stale deletion guard and unlink without deleting source places')
    print('Public API QA passed. Disposable account cleanup is still required using the ledger.')


if __name__ == '__main__':
    main()
