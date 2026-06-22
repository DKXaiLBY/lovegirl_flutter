import paramiko, base64, time

with open('/tmp/sshpw') as f:
    pw = f.read().strip()

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('47.121.119.191', username='root', password=pw, timeout=15)

# Get app.js
si, so, se = c.exec_command('docker exec lovegirl-server cat /app/app.js')
app_js = so.read().decode()

privacy_line = "app.use('/api/privacy', require('./routes/privacy'));"

if 'routes/privacy' in app_js:
    print('Privacy already registered!')
else:
    lines = app_js.split('\n')
    new_lines = []
    added = False
    for line in lines:
        if not added and 'routes/user' in line and 'require' in line:
            new_lines.append(privacy_line)
            added = True
        new_lines.append(line)

    if not added:
        new_lines = []
        for line in lines:
            new_lines.append(line)
            if not added and 'routes/auth' in line and 'require' in line:
                new_lines.append(privacy_line)
                added = True

    new_js = '\n'.join(new_lines)
    enc = base64.b64encode(new_js.encode()).decode()
    c.exec_command('echo "' + enc + '" | base64 -d > /tmp/app_new.js')
    c.exec_command('docker cp /tmp/app_new.js lovegirl-server:/app/app.js')
    print('app.js updated, privacy route added:', added)
    c.exec_command('docker restart lovegirl-server')
    time.sleep(7)
    print('Server restarted')

# Verify
si, so, se = c.exec_command("docker exec lovegirl-server grep privacy /app/app.js")
print('Verify:', so.read().decode().strip())

c.close()
