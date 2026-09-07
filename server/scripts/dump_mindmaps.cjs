const path = require('path');
const db = require('better-sqlite3')(path.join(__dirname, '..', 'data', 'knowledge.db'));
const r = db.prepare(`SELECT m.title mt, n.title t, n.kind k, substr(n.parent_id,1,8) p, n.x, n.y, n.sort s FROM mindmap_nodes n JOIN mindmaps m ON n.map_id=m.id ORDER BY m.title, n.sort`).all();
console.log(JSON.stringify(r, null, 1));
