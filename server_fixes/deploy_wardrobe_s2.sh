#!/bin/sh
set -e
R=/opt/love-girl/love-girl-server
# 挂载电子衣柜路由（幂等）
if ! grep -q 'routes/wardrobe' $R/app.js; then
  sed -i "s|app.use('/api/deploy', require('./routes/deploy_api'));|app.use('/api/deploy', require('./routes/deploy_api'));\napp.use('/api/wardrobe', require('./routes/wardrobe'));|" $R/app.js
fi
grep -n 'wardrobe' $R/app.js
# 容器内语法检查
docker exec lovegirl-server node -e "require('/app/routes/wardrobe.js'); console.log('ROUTE_SYNTAX_OK')"
docker restart lovegirl-server
sleep 6
docker logs lovegirl-server --tail 6
echo "HTTP_CODE:"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3001/api/wardrobe/bg-status
