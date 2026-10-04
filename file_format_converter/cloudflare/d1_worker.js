/**
 * Cloudflare Worker — D1 REST Gateway
 * Deploy with: wrangler deploy --name d1-worker
 *
 * wrangler.toml:
 *   name = "d1-worker"
 *   compatibility_date = "2024-01-01"
 *   [[d1_databases]]
 *   binding = "DB"
 *   database_name = "file_converter_db"
 *   database_id = "<your-d1-database-id>"
 *
 * Set secrets:
 *   wrangler secret put API_KEY
 *   (enter your chosen secret key when prompted)
 */

export default {
  async fetch(request, env) {
    // ── Auth ────────────────────────────────────────────────────────────────────
    if (request.headers.get('X-API-Key') !== env.API_KEY) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      // ── Health check ──────────────────────────────────────────────────────────
      if (path === '/health' && method === 'GET') {
        return json({ status: 'ok' });
      }

      // ── GET /devices — list with optional filters ─────────────────────────────
      if (path === '/devices' && method === 'GET') {
        const params = Object.fromEntries(url.searchParams);
        let sql = 'SELECT * FROM user_devices';
        const values = [];
        const clauses = Object.entries(params).map(([k, v]) => {
          values.push(v);
          return `${k} = ?`;
        });
        if (clauses.length) sql += ' WHERE ' + clauses.join(' AND ');
        sql += ' ORDER BY last_seen DESC';
        const result = await env.DB.prepare(sql).bind(...values).all();
        return json(result.results.map(decodeRow));
      }

      // ── GET /devices/:id ──────────────────────────────────────────────────────
      const deviceMatch = path.match(/^\/devices\/([^/]+)$/);
      if (deviceMatch && method === 'GET') {
        const id = decodeURIComponent(deviceMatch[1]);
        const row = await env.DB
          .prepare('SELECT * FROM user_devices WHERE device_id = ?')
          .bind(id).first();
        if (!row) return json({ error: 'Not found' }, 404);
        return json(decodeRow(row));
      }

      // ── POST /devices — insert or upsert ──────────────────────────────────────
      if (path === '/devices' && method === 'POST') {
        const body = await request.json();
        const { action, device_id, data } = body;

        if (action === 'insert') {
          await insertDevice(env.DB, data);
          return json({ ok: true });
        }
        if (action === 'upsert') {
          await upsertDevice(env.DB, device_id, data);
          return json({ ok: true });
        }
        return json({ error: 'Unknown action' }, 400);
      }

      // ── POST /devices/:id — update ────────────────────────────────────────────
      if (deviceMatch && method === 'POST') {
        const id = decodeURIComponent(deviceMatch[1]);
        const body = await request.json();
        if (body.action === 'update') {
          await updateDevice(env.DB, id, body.fields);
          return json({ ok: true });
        }
        return json({ error: 'Unknown action' }, 400);
      }

      // ── DELETE /devices/:id ───────────────────────────────────────────────────
      if (deviceMatch && method === 'DELETE') {
        const id = decodeURIComponent(deviceMatch[1]);
        await env.DB
          .prepare('DELETE FROM user_devices WHERE device_id = ?')
          .bind(id).run();
        return json({ ok: true });
      }

      // ── POST /devices/:id/increment ───────────────────────────────────────────
      const incrMatch = path.match(/^\/devices\/([^/]+)\/increment$/);
      if (incrMatch && method === 'POST') {
        const id = decodeURIComponent(incrMatch[1]);
        const { column, by = 1 } = await request.json();
        // Whitelist columns to prevent SQL injection.
        const allowed = ['total_conversions', 'session_count'];
        if (!allowed.includes(column)) {
          return json({ error: 'Column not allowed' }, 400);
        }
        await env.DB
          .prepare(`UPDATE user_devices SET ${column} = COALESCE(${column},0) + ? WHERE device_id = ?`)
          .bind(by, id).run();
        return json({ ok: true });
      }

      return json({ error: 'Not found' }, 404);
    } catch (err) {
      return json({ error: err.message }, 500);
    }
  },
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function decodeRow(row) {
  // conversions_by_type is stored as a JSON string in D1.
  if (typeof row.conversions_by_type === 'string') {
    try { row.conversions_by_type = JSON.parse(row.conversions_by_type); }
    catch (_) {}
  }
  row.force_logout = row.force_logout === 1;
  return row;
}

async function insertDevice(db, data) {
  const row = prepareRow(data);
  const cols = Object.keys(row).join(', ');
  const placeholders = Object.keys(row).map(() => '?').join(', ');
  await db
    .prepare(`INSERT OR IGNORE INTO user_devices (${cols}) VALUES (${placeholders})`)
    .bind(...Object.values(row)).run();
}

async function upsertDevice(db, deviceId, data) {
  const row = { ...prepareRow(data), device_id: deviceId };
  const cols = Object.keys(row).join(', ');
  const placeholders = Object.keys(row).map(() => '?').join(', ');
  const updates = Object.keys(row)
    .filter(k => k !== 'device_id')
    .map(k => `${k} = excluded.${k}`)
    .join(', ');
  await db
    .prepare(`INSERT INTO user_devices (${cols}) VALUES (${placeholders}) ON CONFLICT(device_id) DO UPDATE SET ${updates}`)
    .bind(...Object.values(row)).run();
}

async function updateDevice(db, deviceId, fields) {
  const row = prepareRow(fields);
  const setClauses = Object.keys(row).map(k => `${k} = ?`).join(', ');
  await db
    .prepare(`UPDATE user_devices SET ${setClauses} WHERE device_id = ?`)
    .bind(...Object.values(row), deviceId).run();
}

function prepareRow(data) {
  const row = { ...data };
  delete row.device_id;
  if (row.conversions_by_type && typeof row.conversions_by_type === 'object') {
    row.conversions_by_type = JSON.stringify(row.conversions_by_type);
  }
  if (typeof row.force_logout === 'boolean') {
    row.force_logout = row.force_logout ? 1 : 0;
  }
  return row;
}
