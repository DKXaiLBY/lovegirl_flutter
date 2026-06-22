import paramiko, base64, time

with open('/tmp/sshpw') as f:
    pw = f.read().strip()

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('47.121.119.191', username='root', password=pw, timeout=15)

# Get current app.js
si, so, se = c.exec_command('docker exec lovegirl-server cat /app/app.js')
app_js = so.read().decode()

privacy_line = "app.use('/api/privacy', require('./routes/privacy'));"

# Remove any existing privacy lines (the broken one at top)
lines = app_js.split('\n')
fixed_lines = []
for line in lines:
    if 'routes/privacy' in line and 'require' in line:
        continue
    fixed_lines.append(line)

# Add privacy line after travel route (which comes after app initialization)
new_lines = []
added = False
for line in fixed_lines:
    new_lines.append(line)
    if not added and "require('./routes/travel')" in line:
        new_lines.append(privacy_line)
        added = True

new_js = '\n'.join(new_lines)
count = new_js.count('routes/privacy')
print(f'Privacy occurrences: {count}, added after travel: {added}')

enc = base64.b64encode(new_js.encode()).decode()
c.exec_command('echo "' + enc + '" | base64 -d > /tmp/app_fixed.js')
c.exec_command('docker cp /tmp/app_fixed.js lovegirl-server:/app/app.js')
c.exec_command('docker restart lovegirl-server')
print('Fixed, restarting...')

time.sleep(8)
si, so, se = c.exec_command('docker ps --format "{{.Names}} {{.Status}}" | grep lovegirl')
print(so.read().decode())

# Check logs
si, so, se = c.exec_command('docker logs lovegirl-server --tail 5 2>&1')
logs = so.read().decode()
if 'Error' in logs or 'Cannot' in logs:
    print('ERROR in logs:', logs[:500])
else:
    print('No errors in logs')

c.close()
