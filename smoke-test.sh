# Fail if any command returns non-zero
# Show executed commands
set -e -x

source .venv/bin/activate
pip install httpie kinto-http

SERVER="${SERVER:-http://localhost:8888/v1}"
AUTH="${AUTH:-user:pass}"
EDITOR_AUTH="${EDITOR_AUTH:-editor:pass}"
REVIEWER_AUTH="${REVIEWER_AUTH:-reviewer:pass}"

http --check-status PUT $SERVER/buckets/blog --auth $AUTH
http --check-status PUT $SERVER/buckets/blog/collections/articles --auth $AUTH

http --check-status $SERVER/__heartbeat__

# kinto.plugins.history
# Disabled until https://github.com/Kinto/kinto/issues/842 is fixed.
# http --check-status GET $SERVER/buckets/source/history --auth $AUTH | grep '"source"'

# kinto-attachment test
curl -O "http://kinto.readthedocs.io/en/stable/_images/kinto-logo.png"
http --check-status --form POST $SERVER/buckets/blog/collections/articles/records/80ec9929-6896-4022-8443-3da4f5353f47/attachment attachment@kinto-logo.png --auth $AUTH

# kinto-signer test
curl -O https://raw.githubusercontent.com/Kinto/kinto-signer/master/scripts/e2e.py
python e2e.py --server=$SERVER --auth=$AUTH --editor-auth=$EDITOR_AUTH --reviewer-auth=$REVIEWER_AUTH --source-bucket=source --source-col=source

# kinto-changes
http --check-status $SERVER/buckets/monitor/collections/changes/records | grep '"destination"'

# kinto-admin
http --check-status -h $SERVER/admin/
http --check-status -h $SERVER/admin/bundle.js
http --check-status -h $SERVER/admin/styles.css

# kinto-amo
APPID="\{ec8030f7-c20a-464f-9b0e-13a3a9e97384\}"
http --check-status $SERVER/blocklist/3/$APPID/46.0/
# .. Fill with production blocklist entries and compare XML output:
curl -O https://raw.githubusercontent.com/mozilla-services/amo-blocklist-ui/master/amo-blocklist.json
json2kinto --server $SERVER --addons-server https://addons.mozilla.org/ -S amo-blocklist.json

http --check-status $SERVER/blocklist/3/$APPID/46.0/ | grep 'youtube'
xml-verifier https://blocklist.addons.mozilla.org/blocklist/3/$APPID/46.0/ $SERVER/blocklist/3/$APPID/46.0/

http --check-status $SERVER/buckets/monitor/collections/changes/records | grep '"addons"'
http --check-status $SERVER/buckets/monitor/collections/changes/records | grep '"certificates"'
http --check-status $SERVER/buckets/monitor/collections/changes/records | grep '"plugins"'
http --check-status $SERVER/buckets/monitor/collections/changes/records | grep '"gfx"'

curl -O https://raw.githubusercontent.com/Kinto/kinto-signer/master/scripts/validate_signature.py
python validate_signature.py --server="http://localhost:8888/v1" --bucket=blocklists --collection=addons
python validate_signature.py --server="http://localhost:8888/v1" --bucket=blocklists --collection=certificates
python validate_signature.py --server="http://localhost:8888/v1" --bucket=blocklists --collection=plugins
python validate_signature.py --server="http://localhost:8888/v1" --bucket=blocklists --collection=gfx
