"""Run against the owned QA schema using two unbound, password-verified sessions."""
import json
import uuid


def run(request, query, first, second):
    marker = 'QA_PREP_' + uuid.uuid4().hex[:12]
    pair = sorted([first, second])
    report = []
    fixture = {'trip': None, 'items': [], 'outfit': None, 'codes': []}

    def ok(role, path, method='GET', body=None):
        status, result = request(role, path, method, body)
        assert status == 200, (method, path, status)
        return result.get('data')

    def bind():
        invite = ok('first', '/api/couple/invite', 'POST', {})
        code = invite['invite_code']
        fixture['codes'].append(code)
        ok('second', '/api/couple/accept', 'POST', {'code': code})

    def item(key, label, **extra):
        return {'key': key, 'label': label, 'category': 'clothes', 'packed': False, **extra}

    existing = query("const[r]=await pool.query('SELECT id FROM couples WHERE user1_id IN (?,?) OR user2_id IN (?,?)', [FIRST,SECOND,FIRST,SECOND]);return r;".replace('FIRST', str(first)).replace('SECOND', str(second)))
    assert not existing, 'Use dedicated unbound actors without pre-existing relationships'
    try:
        bind()
        plan = {'title': marker, 'days': 2, 'startDate': '2026-12-01',
                'endDate': '2026-12-02', 'stops': [], 'clientId': uuid.uuid4().hex}
        journey = ok('first', '/api/journeys', 'POST', plan)
        fixture['trip'] = journey['id']
        path = '/api/travel-preparation/' + str(journey['id'])
        a = ok('first', path)
        assert request('unrelated', path)[0] == 404
        key = a['relationshipKey']
        assert a['trip']['days'] == 2 and a['mine']['revision'] == 0 and a['shared']['revision'] == 0
        seed = json.dumps({'first': first, 'second': second, 'marker': marker})
        wardrobe = query("""const f=FIXTURE;const ids=[];for(const owner of [f.first,f.second]){
          const[r]=await pool.query("INSERT INTO wardrobe_items(user_id,image_url,category,brand,status) VALUES (?,?,'上装',?,'在柜')",[owner,'/uploads/wardrobe/'+f.marker+'_'+owner+'.png',f.marker]);ids.push(r.insertId);
        }const[o]=await pool.query("INSERT INTO wardrobe_outfits(user_id,worn_date,source,item_ids,status,note) VALUES (?,'2026-12-01','组合',?,'待确认',?)",[f.first,JSON.stringify([ids[0]]),f.marker]);return {ids,outfit:o.insertId};""".replace('FIXTURE', seed))
        fixture['items'] = wardrobe['ids']
        fixture['outfit'] = wardrobe['outfit']
        own = {'revision': 0, 'items': [item('private_a', '我的外套')], 'outfits': [
            {'day': 0, 'outfitId': wardrobe['outfit'], 'itemIds': []},
            {'day': 1, 'itemIds': [wardrobe['ids'][0]]},
        ]}
        saved = ok('first', path + '/private', 'PUT', own)
        assert saved['revision'] == 1 and len(saved['outfits']) == 2
        assert ok('second', path)['mine']['items'] == []
        status, _ = request('second', path + '/private', 'PUT', {
            'revision': 0, 'items': [], 'outfits': [{'day': 0, 'itemIds': [wardrobe['ids'][0]]}]})
        assert status == 403
        status, _ = request('second', path + '/private', 'PUT', {
            'revision': 0, 'items': [], 'outfits': [{'day': 0, 'outfitId': wardrobe['outfit']}]})
        assert status == 403
        report.append('private list and clothes are owner-scoped, with both saved outfits and individual pieces')

        shared = {'revision': 0, 'relationshipKey': key,
                  'items': [item('shared_a', '共同充电器', assigneeId=second)]}
        saved = ok('first', path + '/shared', 'PUT', shared)
        assert saved['revision'] == 1
        assert ok('second', path)['shared']['items'][0]['assigneeId'] == second
        shared['revision'] = 1
        shared['items'][0]['packed'] = True
        saved = ok('second', path + '/shared', 'PUT', shared)
        assert saved['items'][0]['packed'] is True
        assert request('first', path + '/shared', 'PUT', shared)[0] == 409
        assert ok('first', path)['shared']['items'][0]['packed'] is True
        report.append('shared assignment and packed state persist, stale revisions cannot overwrite them')

        query("const[r]=await pool.query(\"UPDATE wardrobe_items SET status='退役' WHERE id=? AND user_id=?\", [ITEM,OWNER]);return r.affectedRows;".replace('ITEM', str(wardrobe['ids'][0])).replace('OWNER', str(first)))
        ok('first', '/api/wardrobe/outfits/' + str(wardrobe['outfit']), 'DELETE')
        saved = ok('first', path)['mine']
        assert not saved['outfits'][0]['available'] and not saved['outfits'][1]['items'][0]['available']
        assert saved['outfits'][1]['items'][0]['imageUrl'] is None
        current = ok('first', '/api/journeys/' + str(journey['id']), 'PUT', {
            **plan, 'revision': journey['revision'], 'title': marker + ' renamed', 'days': 1, 'endDate': '2026-12-01'})
        changed = ok('first', path)
        assert changed['trip']['title'].endswith(' renamed') and changed['mine']['outfits'][1]['outsideTrip']
        own['revision'] = saved['revision']
        own['items'][0]['packed'] = True
        kept = ok('first', path + '/private', 'PUT', own)
        assert kept['items'][0]['packed'] and kept['outfits'][1]['outsideTrip']
        report.append('retired clothes, removed outfits and days outside a shortened journey retain historical selections')

        own_second = {'revision': 0, 'items': [item('private_b', '我的证件')], 'outfits': []}
        ok('second', path + '/private', 'PUT', own_second)
        ok('first', '/api/couple', 'DELETE')
        previous = ok('second', path)
        assert previous['archived'] and previous['shared'] is None
        assert previous['mine']['items'][0]['label'] == '我的证件'
        bind()
        rebound = ok('first', path)
        assert rebound['relationshipKey'] != key and rebound['shared']['revision'] == 0
        assert request('first', path + '/shared', 'PUT', {**shared, 'revision': 0})[0] == 409
        report.append('unlink retains private records, revokes shared reads, and rejects stale writes after rebinding')

        ok('first', path + '/shared', 'PUT', {**shared, 'revision': 0, 'relationshipKey': rebound['relationshipKey']})
        ok('first', '/api/journeys/' + str(journey['id']) + '?revision=' + str(current['revision']), 'DELETE')
        archived = ok('first', path)
        assert archived['archived'] and archived['mine']['items'][0]['packed']
        assert archived['shared']['items'][0]['label'] == '共同充电器'
        assert sum(row['id'] == journey['id'] for row in ok('first', '/api/travel-preparation/archives')) == 1
        assert request('first', path + '/private', 'PUT', {**own, 'revision': kept['revision']})[0] == 409
        wardrobe_kept = query("const[r]=await pool.query('SELECT id FROM wardrobe_items WHERE id IN (?,?)',[ONE,TWO]);return r.length;".replace('ONE', str(wardrobe['ids'][0])).replace('TWO', str(wardrobe['ids'][1])))
        assert wardrobe_kept == 2
        report.append('deleting a journey archives both lists, preserves wardrobe records and stops edits')
    finally:
        data = json.dumps({**fixture, 'marker': marker, 'pair': pair})
        query("""const f=FIXTURE;const conn=await pool.getConnection();try{await conn.beginTransaction();
          const[c]=await conn.query('SELECT id FROM couples WHERE user1_id=? AND user2_id=?',f.pair);
          if(f.trip){const[t]=await conn.query('SELECT title,user_id FROM travel_trips WHERE id=?',[f.trip]);
            if(t.length && (!t[0].title.startsWith(f.marker)||!f.pair.includes(t[0].user_id)))throw Error('Unexpected trip');
            await conn.query("DELETE FROM travel_preparation WHERE trip_id=? AND scope='private' AND scope_id IN (?,?)",[f.trip,...f.pair]);
            for(const row of c)await conn.query("DELETE FROM travel_preparation WHERE trip_id=? AND scope='shared' AND scope_id=?",[f.trip,row.id]);
            await conn.query('DELETE FROM travel_trip_spots WHERE trip_id=?',[f.trip]);
            await conn.query('DELETE FROM travel_itinerary_state WHERE trip_id=?',[f.trip]);
            await conn.query('DELETE FROM travel_trips WHERE id=? AND user_id IN (?,?)',[f.trip,...f.pair]);}
          if(f.outfit)await conn.query('DELETE FROM wardrobe_outfits WHERE id=? AND note=?',[f.outfit,f.marker]);
          for(const id of f.items)await conn.query('DELETE FROM wardrobe_items WHERE id=? AND brand=?',[id,f.marker]);
          for(const code of f.codes)await conn.query('DELETE FROM couple_invites WHERE code=? AND creator_id IN (?,?)',[code,...f.pair]);
          for(const row of c)await conn.query('DELETE FROM couples WHERE id=? AND user1_id=? AND user2_id=?',[row.id,...f.pair]);
          await conn.commit();return {cleaned:true};}catch(e){await conn.rollback();throw e;}finally{conn.release();}""".replace('FIXTURE', data))
    return {'checks': report, 'ownedFixturesCleaned': True, 'productionMutations': 0}
