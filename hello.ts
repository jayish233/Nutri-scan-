import { Pool } from "pg";
import { attachDatabasePool } from "@neon/functions";

// Neon Functions are long-running: create the pool once at module scope and
// reuse it across requests. attachDatabasePool keeps an idle disconnect from
// crashing the isolate.
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 5 });
attachDatabasePool(pool);

export default async function hello(): Promise<Response> {
  const { rows } = await pool.query(
    "select current_database() as db, now() as db_time",
  );
  return Response.json({
    app: "NutriScan",
    ok: true,
    branch: process.env.NEON_BRANCH ?? null,
    database: rows[0].db,
    dbTime: rows[0].db_time,
  });
}
