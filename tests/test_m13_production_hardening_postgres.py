"""
PostgreSQL 17.11 Integration & Failure Test Suite for M13 Production Hardening
Tests:
  D1: Function security (SECURITY INVOKER, body, search_path=pg_catalog, ACL)
  D2: Trigger regression across all 3 M13 tables
  D3: Index verification on public.order_customizations(session_id)
  D4: Idempotency (double execution + pre-existing equivalent index skip)
  D5: 12 fail-closed precondition, timeout, atomicity, and disconnect tests
  D6: Rollback restoration & original M13 object preservation
"""

import hashlib
import os
import subprocess
import sys
import time
import uuid
import psycopg2

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ORIG_MIG_PATH = os.path.join(ROOT_DIR, "migrations", "20261112_001_personalization_engine.sql")
HARDEN_MIG_PATH = os.path.join(ROOT_DIR, "migrations", "20261113_1335_m13_production_hardening.sql")
ROLLBACK_MIG_PATH = os.path.join(ROOT_DIR, "migrations", "20261113_1335_m13_production_hardening_rollback.sql")


def read_sql(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def get_conn(dbname: str = None, autocommit: bool = True):
    conn = psycopg2.connect(
        host=os.environ.get("PGHOST", "127.0.0.1"),
        port=int(os.environ.get("PGPORT", "5438")),
        dbname=dbname or os.environ.get("PGDATABASE", "postgres"),
        user=os.environ.get("PGUSER", "postgres"),
        password=os.environ.get("PGPASSWORD", ""),
    )
    conn.autocommit = autocommit
    return conn


def ensure_supabase_roles(cur):
    for role in ("anon", "authenticated", "service_role"):
        cur.execute(
            f"""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{role}') THEN
                    CREATE ROLE {role} NOLOGIN;
                END IF;
            END $$;
            """
        )


def reset_fresh_m13_db(db_name: str):
    adm = get_conn("postgres", autocommit=True)
    acur = adm.cursor()
    ensure_supabase_roles(acur)
    acur.execute(
        f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s AND pid <> pg_backend_pid();",
        (db_name,),
    )
    acur.execute(f"DROP DATABASE IF EXISTS {db_name};")
    acur.execute(f"CREATE DATABASE {db_name};")
    adm.close()

    conn = get_conn(db_name, autocommit=True)
    cur = conn.cursor()
    cur.execute(read_sql(ORIG_MIG_PATH))
    # Simulate Supabase default public function EXECUTE grants for realistic baseline
    cur.execute("GRANT EXECUTE ON FUNCTION public.m13_set_updated_at() TO PUBLIC, anon, authenticated, service_role;")
    conn.close()


def run_tests():
    results = []

    def record(test_id: str, passed: bool, detail: str = ""):
        results.append((test_id, passed, detail))
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {test_id}: {detail}")
        if not passed:
            raise AssertionError(f"{test_id} failed: {detail}")

    db_main = "m13_harden_test_main"
    reset_fresh_m13_db(db_main)
    conn = get_conn(db_main, autocommit=True)
    cur = conn.cursor()

    # Capture pre-hardening baseline for D6
    cur.execute("SELECT proconfig, proacl::text FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
    pre_proconfig, pre_proacl = cur.fetchone()

    # Apply corrective migration (Run 1)
    cur.execute(read_sql(HARDEN_MIG_PATH))

    # D1: Function security tests
    cur.execute("""
        SELECT p.prosecdef, p.proconfig, p.prosrc, p.proacl::text,
               has_function_privilege('public', p.oid, 'EXECUTE'),
               has_function_privilege('anon', p.oid, 'EXECUTE'),
               has_function_privilege('authenticated', p.oid, 'EXECUTE'),
               has_function_privilege('service_role', p.oid, 'EXECUTE'),
               has_function_privilege('postgres', p.oid, 'EXECUTE')
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';
    """)
    secdef, proconfig, prosrc, proacl, p_pub, p_anon, p_auth, p_srv, p_pg = cur.fetchone()
    record(
        "D1-FUNC-SEC",
        (not secdef)
        and proconfig == ["search_path=pg_catalog"]
        and "NEW.updated_at = now();" in prosrc
        and (not p_pub)
        and (not p_anon)
        and (not p_auth)
        and (not p_srv)
        and p_pg,
        f"secdef={secdef}, proconfig={proconfig}, acl={proacl}",
    )

    # D2: Trigger regression tests across all 3 tables (rolled back)
    conn.autocommit = False
    tid = str(uuid.uuid4())
    pid = str(uuid.uuid4())
    sid = str(uuid.uuid4())
    oid = str(uuid.uuid4())
    ord_id = str(uuid.uuid4())
    tok1 = hashlib.sha256(b"d2_s").hexdigest()
    tok2 = hashlib.sha256(b"d2_o").hexdigest()

    cur.execute(
        "INSERT INTO public.personalization_templates (id, product_id, version, schema_definition, layout_template_path, is_active) VALUES (%s, %s, 'v1', '{}'::jsonb, '/tmp/t', true) RETURNING updated_at;",
        (tid, pid),
    )
    t1_before = cur.fetchone()[0]
    time.sleep(0.05)
    cur.execute("UPDATE public.personalization_templates SET is_active = false WHERE id = %s RETURNING updated_at, version;", (tid,))
    t1_after, t1_ver = cur.fetchone()
    record("D2-TRG-TPL", t1_after > t1_before and t1_ver == "v1", f"updated_at {t1_before} -> {t1_after}")

    cur.execute(
        "INSERT INTO public.customization_sessions (id, template_id, token_hash) VALUES (%s, %s, %s) RETURNING updated_at;",
        (sid, tid, tok1),
    )
    s_before = cur.fetchone()[0]
    time.sleep(0.05)
    cur.execute("UPDATE public.customization_sessions SET current_step = 'photo' WHERE id = %s RETURNING updated_at, token_hash;", (sid,))
    s_after, s_tok = cur.fetchone()
    record("D2-TRG-SESS", s_after > s_before and s_tok == tok1, f"updated_at {s_before} -> {s_after}")

    cur.execute(
        "INSERT INTO public.order_customizations (id, order_id, session_id, download_token_hash) VALUES (%s, %s, %s, %s) RETURNING updated_at;",
        (oid, ord_id, sid, tok2),
    )
    o_before = cur.fetchone()[0]
    time.sleep(0.05)
    cur.execute("UPDATE public.order_customizations SET render_status = 'completed' WHERE id = %s RETURNING updated_at, download_token_hash;", (oid,))
    o_after, o_tok = cur.fetchone()
    record("D2-TRG-ORD", o_after > o_before and o_tok == tok2, f"updated_at {o_before} -> {o_after}")

    conn.rollback()
    conn.autocommit = True

    # D3: Index verification
    cur.execute("""
        SELECT i.relname, ix.indisvalid, ix.indisready,
               ARRAY(SELECT a.attname::text FROM unnest(ix.indkey) WITH ORDINALITY AS k(attnum, ord)
                     JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = k.attnum ORDER BY k.ord)
        FROM pg_index ix
        JOIN pg_class i ON i.oid = ix.indexrelid
        WHERE ix.indrelid = 'public.order_customizations'::regclass
          AND i.relname = 'idx_order_customizations_session_id';
    """)
    idx_row = cur.fetchone()
    record(
        "D3-INDEX",
        idx_row is not None and idx_row[1] and idx_row[2] and idx_row[3] == ["session_id"],
        f"idx={idx_row}",
    )

    # D4: Idempotency (Run 2)
    cur.execute(read_sql(HARDEN_MIG_PATH))
    cur.execute("SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename='order_customizations' AND indexdef LIKE '%(session_id)%';")
    idx_cnt = cur.fetchone()[0]
    record("D4-IDEMPOTENT", idx_cnt == 1, f"session_id index count after 2nd run = {idx_cnt}")

    # D6: Rollback test
    cur.execute(read_sql(ROLLBACK_MIG_PATH))
    cur.execute("SELECT proconfig, proacl::text FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
    rb_proconfig, rb_proacl = cur.fetchone()
    cur.execute("SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND indexname='idx_order_customizations_session_id';")
    rb_idx_cnt = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename IN ('personalization_templates','customization_sessions','order_customizations');")
    rb_tbl_cnt = cur.fetchone()[0]
    record(
        "D6-ROLLBACK",
        rb_proconfig == pre_proconfig and rb_proacl == pre_proacl and rb_idx_cnt == 0 and rb_tbl_cnt == 3,
        f"proconfig={rb_proconfig}, idx_cnt={rb_idx_cnt}, tables={rb_tbl_cnt}",
    )
    conn.close()

    # D4-EQUIV: Pre-existing equivalent covering index skips creating duplicate
    db_equiv = "m13_harden_test_equiv"
    reset_fresh_m13_db(db_equiv)
    c_eq = get_conn(db_equiv, autocommit=True)
    cur_eq = c_eq.cursor()
    cur_eq.execute("CREATE INDEX idx_custom_alt_session ON public.order_customizations (session_id);")
    cur_eq.execute(read_sql(HARDEN_MIG_PATH))
    cur_eq.execute("SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND indexname='idx_order_customizations_session_id';")
    dup_cnt = cur_eq.fetchone()[0]
    c_eq.close()
    record("D4-EQUIV-SKIP", dup_cnt == 0, f"duplicate idx_order_customizations_session_id count={dup_cnt}")

    # D5: 12 Failure Tests
    def expect_abort(test_id: str, setup_sql: str):
        db_f = "m13_harden_test_fail"
        reset_fresh_m13_db(db_f)
        cf = get_conn(db_f, autocommit=True)
        curf = cf.cursor()
        curf.execute(setup_sql)
        failed = False
        err_msg = ""
        try:
            curf.execute(read_sql(HARDEN_MIG_PATH))
        except Exception as e:
            failed = True
            err_msg = str(e).splitlines()[0]
        # Verify zero partial corrective changes
        curf.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
        row = curf.fetchone()
        no_search_path = (row is None) or (row[0] is None)
        curf.execute("SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND indexname='idx_order_customizations_session_id';")
        idx_c = curf.fetchone()[0]
        cf.close()
        record(test_id, failed and (no_search_path or "INCOMPAT" in test_id) and (idx_c == 0 or "IDX-COLLISION" in test_id), err_msg)

    expect_abort("D5-01-MISSING-FUNC", "DROP FUNCTION public.m13_set_updated_at() CASCADE;")
    expect_abort("D5-02-WRONG-SIG", "DROP FUNCTION public.m13_set_updated_at() CASCADE; CREATE FUNCTION public.m13_set_updated_at(x int) RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;")
    expect_abort("D5-03-WRONG-SECDEF", "ALTER FUNCTION public.m13_set_updated_at() SECURITY DEFINER;")
    expect_abort("D5-04-MISSING-TRG", "DROP TRIGGER trg_order_customizations_updated_at ON public.order_customizations;")
    expect_abort("D5-05-TRG-OTHER-FN", "CREATE FUNCTION public.other_fn() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END; $$; DROP TRIGGER trg_order_customizations_updated_at ON public.order_customizations; CREATE TRIGGER trg_order_customizations_updated_at BEFORE UPDATE ON public.order_customizations FOR EACH ROW EXECUTE FUNCTION public.other_fn();")
    expect_abort("D5-06-MISSING-FK", "ALTER TABLE public.order_customizations DROP CONSTRAINT order_customizations_session_id_fkey;")
    expect_abort("D5-07-WRONG-FK", "ALTER TABLE public.order_customizations DROP CONSTRAINT order_customizations_session_id_fkey; ALTER TABLE public.order_customizations ADD CONSTRAINT order_customizations_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.customization_sessions(id) ON DELETE CASCADE;")
    expect_abort("D5-08-IDX-COLLISION", "CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (order_id);")

    # D5-09: Lock timeout
    db_lt = "m13_harden_test_lt"
    reset_fresh_m13_db(db_lt)
    c_hold = get_conn(db_lt, autocommit=False)
    c_hold.cursor().execute("LOCK TABLE public.order_customizations IN ACCESS EXCLUSIVE MODE;")
    c_lt = get_conn(db_lt, autocommit=True)
    cur_lt = c_lt.cursor()
    lt_err = ""
    try:
        cur_lt.execute("SET lock_timeout = '300ms'; " + read_sql(HARDEN_MIG_PATH))
    except Exception as e:
        lt_err = str(e).splitlines()[0]
    c_hold.rollback()
    c_hold.close()
    cur_lt.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
    lt_cfg = cur_lt.fetchone()[0]
    c_lt.close()
    record("D5-09-LOCK-TIMEOUT", "lock timeout" in lt_err and lt_cfg is None, lt_err)

    # D5-10: Statement timeout
    db_st = "m13_harden_test_st"
    reset_fresh_m13_db(db_st)
    c_st = get_conn(db_st, autocommit=True)
    cur_st = c_st.cursor()
    st_err = ""
    try:
        cur_st.execute("SET statement_timeout = '200ms'; BEGIN; ALTER FUNCTION public.m13_set_updated_at() SET search_path = pg_catalog; SELECT pg_sleep(1); COMMIT;")
    except Exception as e:
        st_err = str(e).splitlines()[0]
    cur_st.execute("ROLLBACK;")
    cur_st.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
    st_cfg = cur_st.fetchone()[0]
    c_st.close()
    record("D5-10-STMT-TIMEOUT", "statement timeout" in st_err and st_cfg is None, st_err)

    # D5-11: Failure after earlier corrective statement rolls back atomically
    db_mid = "m13_harden_test_mid"
    reset_fresh_m13_db(db_mid)
    c_mid = get_conn(db_mid, autocommit=True)
    cur_mid = c_mid.cursor()
    mid_err = ""
    try:
        cur_mid.execute("BEGIN; ALTER FUNCTION public.m13_set_updated_at() SET search_path = pg_catalog; SELECT 1/0; COMMIT;")
    except Exception as e:
        mid_err = str(e).splitlines()[0]
    cur_mid.execute("ROLLBACK;")
    cur_mid.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
    mid_cfg = cur_mid.fetchone()[0]
    c_mid.close()
    record("D5-11-MID-TX-ROLLBACK", "division by zero" in mid_err and mid_cfg is None, mid_err)

    # D5-12: Client disconnect during open transaction
    psql_bin = os.environ.get("PSQL_BIN")
    if psql_bin and os.path.exists(psql_bin):
        db_dc = "m13_harden_test_dc"
        reset_fresh_m13_db(db_dc)
        p_dc = subprocess.Popen(
            [psql_bin, "-h", os.environ.get("PGHOST", "127.0.0.1"), "-p", os.environ.get("PGPORT", "5438"), "-U", "postgres", "-d", db_dc, "-X"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        p_dc.stdin.write("BEGIN;\nALTER FUNCTION public.m13_set_updated_at() SET search_path = pg_catalog;\nSELECT pg_sleep(5);\n")
        p_dc.stdin.flush()
        time.sleep(0.5)
        p_dc.terminate()
        p_dc.wait(timeout=5)
        time.sleep(0.3)
        c_dc = get_conn(db_dc, autocommit=True)
        cur_dc = c_dc.cursor()
        cur_dc.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
        dc_cfg = cur_dc.fetchone()[0]
        c_dc.close()
        record("D5-12-CLIENT-DISCONNECT", dc_cfg is None, f"proconfig after disconnect={dc_cfg}")
    else:
        raise RuntimeError("PSQL_BIN not set for D5-12-CLIENT-DISCONNECT")

    print(f"\nTOTAL HARDENING INTEGRATION TESTS: {len(results)} | PASSED: {sum(1 for r in results if r[1])} | FAILED: {sum(1 for r in results if not r[1])}")


if __name__ == "__main__":
    run_tests()

