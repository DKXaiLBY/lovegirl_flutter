"""Read-only audit of retired screens and calls reachable from the real entrypoint."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
library = root / 'lib'
pending = [library / 'main.dart']
visited = set()
calls = []
retired = {
    'providers/daily_provider.dart',
    'screens/daily/daily_question_screen.dart',
    'screens/letter/slow_letter_screen.dart',
    'screens/beans/beans_screen.dart',
    'screens/profile/achievements_screen.dart',
    'screens/voucher/wish_voucher_screen.dart',
}
methods = (
    'getBeanBalance', 'getBeanTransactions', 'getBeanCheckInStatus', 'dailyBeanCheckIn',
    'getAchievements', 'checkAchievements', 'getDailyToday', 'answerDailyQuestion',
    'getDailyHistory', 'getLetterList', 'getLetter', 'sendLetter', 'getVoucherList',
    'createVoucher', 'setVoucherActive', 'redeemVoucher', 'deleteVoucher',
    'getVoucherRedemptions', 'doneVoucherRedemption', 'confirmVoucherRedemption',
    'cancelVoucherRedemption',
)
pattern = re.compile(r'\.(' + '|'.join(methods) + r')\s*\(')
while pending:
    file = pending.pop().resolve()
    if file in visited:
        continue
    assert file.is_relative_to(library) and file.is_file(), file
    visited.add(file)
    source = file.read_text(encoding='utf-8')
    for statement in re.findall(r'\b(?:import|export|part)\s+([^;]+);', source):
        for uri in re.findall(r"['\"]([^'\"]+\.dart)['\"]", statement):
            if uri.startswith('package:lovegirl_flutter/'):
                pending.append(library / uri.removeprefix('package:lovegirl_flutter/'))
            elif not uri.startswith(('package:', 'dart:')):
                pending.append(file.parent / uri)
    for number, line in enumerate(source.splitlines(), 1):
        if pattern.search(line):
            calls.append({'file': file.relative_to(library).as_posix(), 'line': number})
reachable = {file.relative_to(library).as_posix() for file in visited}
result = {
    'entrypoint': 'lib/main.dart',
    'reachableLibraries': len(visited),
    'retiredLibrariesStillReachable': sorted(retired & reachable),
    'retiredCallsInReachableCode': calls,
    'scope': 'static project imports and qualified retired API calls; not server retirement or runtime UI acceptance',
}
print(json.dumps(result, ensure_ascii=False, indent=2))
assert not result['retiredLibrariesStillReachable']
assert not calls
