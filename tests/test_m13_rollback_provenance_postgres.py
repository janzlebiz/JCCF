"""
PostgreSQL 17.11 Integration & Provenance Test Suite for M13 Rollback Safety
Covers RP-01 through RP-16, privilege isolation on m13_internal, and Phase F full sequence.
"""

import hashlib
import os
import subprocess
import sys
import time
import uuid
import psycopg2

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ORIG_MIG = os.path.join(ROOT_DIR, "migrations", "20261112_001_personalization_engine.sql")
HARDEN_MIG = os.path.join(ROOT_DIR, "migrations", "20261113_1335_m13_production_hardening.sql")
PROV_MIG = os.path.join(ROOT_DIR, "migrations", "20261113_2200_m13_rollback_provenance_fix.sql")
PROV_RB = os.path.join(ROOT_DIR, "migrations", "20261113_2200_m13_rollback_provenance_fix_rollback.sql")


def read_sql(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def get_conn(dbname: str = None, autocommit: bool = True):
    conn = psycopg2.connect(
        host=os.environ.get("PGHOST", "127.0.0.1"),
        port=int(os.environ.get("PGPORT", "5439")),
        dbname=dbname or os.environ.get("PGDATABASE", "postgres"),
        user=os.environ.get("PGUSER", "postgres"),
        password=os.environ.get("PGPASSWORD", ""),
    )
    conn.autocommit = autocommit
    return conn


def ensure_roles(cur):
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


def reset_m13_db(db_name: str, with_hardening: bool = False):
    adm = get_conn("postgres", autocommit=True)
    acur = adm.cursor()
    ensure_roles(acur)
    acur.execute(
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s AND pid <> pg_backend_pid();",
        (db_name,),
    )
    acur.execute(f"DROP DATABASE IF EXISTS {db_name};")
    acur.execute(f"CREATE DATABASE {db_name};")
    adm.close()

    conn = get_conn(db_name, autocommit=True)
    cur = conn.cursor()
    cur.execute(read_sql(ORIG_MIG))
    cur.execute("GRANT EXECUTE ON FUNCTION public.m13_set_updated_at() TO PUBLIC, anon, authenticated, service_role;")
    if with_hardening:
        cur.execute(read_sql(HARDEN_MIG))
    conn.close()


def has_index(cur, idx_name: str) -> bool:
    cur.execute(
        "SELECT count(*) FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'order_customizations' AND indexname = %s;",
        (idx_name,),
    )
    return cur.fetchone()[0] == 1


def run_tests():
    results = []

    def record(test_id: str, passed: bool, detail: str = ""):
        results.append((test_id, passed, detail))
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {test_id}: {detail}")
        if not passed:
            raise AssertionError(f"{test_id} failed: {detail}")

    db = "m13_prov_test"

    # RP-01 & RP-14 & RP-12 & RP-13 & ACL isolation
    reset_m13_db(db)
    conn = get_conn(db, autocommit=True)
    cur = conn.cursor()
    cur.execute(read_sql(PROV_MIG))
    cur.execute("SELECT migration_id, index_name, created_by_migration FROM m13_internal.migration_index_provenance;")
    prov_rows = cur.fetchall()
    record("RP-01", has_index(cur, "idx_order_customizations_session_id") and len(prov_rows) == 1 and prov_rows[0][2] is True, f"prov={prov_rows}")

    # Verify anon & authenticated cannot access/forge provenance
    for r in ("anon", "authenticated"):
        conn.autocommit = False
        cur.execute(f"SET LOCAL ROLE {r};")
        denied = False
        try:
            cur.execute("SELECT * FROM m13_internal.migration_index_provenance;")
        except Exception:
            denied = True
            conn.rollback()
        conn.autocommit = True
        record(f"RP-ACL-{r.upper()}", denied, "m13_internal access denied")

    # RP-12: Migration rerun -> no duplicate index or duplicate provenance
    cur.execute(read_sql(PROV_MIG))
    cur.execute("SELECT count(*) FROM m13_internal.migration_index_provenance;")
    cnt_prov = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename='order_customizations' AND indexdef LIKE '%(session_id)%';")
    cnt_idx = cur.fetchone()[0]
    record("RP-12", cnt_prov == 1 and cnt_idx == 1, f"prov_cnt={cnt_prov}, idx_cnt={cnt_idx}")

    # RP-14: Rollback after successful migration removes only owned index & provenance
    cur.execute(read_sql(PROV_RB))
    rb_tbl = None
    cur.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
    rb_tbl = cur.fetchone()[0]
    record("RP-14", (not has_index(cur, "idx_order_customizations_session_id")) and rb_tbl is None, f"idx_present=False, prov_tbl={rb_tbl}")

    # RP-13: Rollback rerun -> safe, deterministic, no unrelated index removed
    cur.execute(read_sql(PROV_RB))
    cur.execute("SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename='order_customizations';")
    orig_idx_cnt = cur.fetchone()[0]
    record("RP-13", orig_idx_cnt == 5, f"remaining original indexes={orig_idx_cnt}")
    conn.close()

    # RP-02 & RP-15: Exact target index exists before migration -> skip creation, rollback preserves index
    reset_m13_db(db)
    conn = get_conn(db, autocommit=True)
    cur = conn.cursor()
    cur.execute("CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")
    cur.execute(read_sql(PROV_MIG))
    cur.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
    prov_tbl = cur.fetchone()[0]
    record("RP-02", has_index(cur, "idx_order_customizations_session_id") and prov_tbl is None, f"pre-existing exact index preserved, prov_tbl={prov_tbl}")
    cur.execute(read_sql(PROV_RB))
    record("RP-15", has_index(cur, "idx_order_customizations_session_id"), "rollback preserved pre-existing exact index")
    conn.close()

    # RP-03: Equivalent index exists under another name -> skip creation, rollback preserves
    reset_m13_db(db)
    conn = get_conn(db, autocommit=True)
    cur = conn.cursor()
    cur.execute("CREATE INDEX idx_custom_alt_sess ON public.order_customizations (session_id);")
    cur.execute(read_sql(PROV_MIG))
    cur.execute(read_sql(PROV_RB))
    record("RP-03", has_index(cur, "idx_custom_alt_sess") and (not has_index(cur, "idx_order_customizations_session_id")), "equivalent index preserved")
    conn.close()

    # RP-04: Target index exists with incompatible definition -> aborts without partial changes
    reset_m13_db(db)
    conn = get_conn(db, autocommit=True)
    cur = conn.cursor()
    cur.execute("CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (order_id);")
    aborted = False
    try:
        cur.execute(read_sql(PROV_MIG))
    except Exception as e:
        aborted = "incompatible definition" in str(e)
        cur.execute("ROLLBACK;")
    cur.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
    record("RP-04", aborted and cur.fetchone()[0] is None, "incompatible index aborted cleanly")
    conn.close()

    # RP-05: Provenance record missing -> rollback does not drop index
    reset_m13_db(db)
    conn = get_conn(db, autocommit=True)
    cur = conn.cursor()
    cur.execute(read_sql(PROV_MIG))
    cur.execute("DELETE FROM m13_internal.migration_index_provenance;")
    cur.execute(read_sql(PROV_RB))
    record("RP-05", has_index(cur, "idx_order_customizations_session_id"), "missing provenance preserved index")
    conn.close()

    # Helper for fail-closed rollback mismatch tests (RP-06..RP-10)
    def expect_rb_fail_closed(test_id: str, mutate_sql: str, check_idx_name: str = "idx_order_customizations_session_id"):
        reset_m13_db(db)
        c = get_conn(db, autocommit=True)
        cu = c.cursor()
        cu.execute(read_sql(PROV_MIG))
        cu.execute(mutate_sql)
        failed = False
        err = ""
        try:
            cu.execute(read_sql(PROV_RB))
        except Exception as e:
            failed = True
            err = str(e).splitlines()[0]
            cu.execute("ROLLBACK;")
        preserved = has_index(cu, check_idx_name)
        c.close()
        record(test_id, failed and preserved, f"{err} | preserved={preserved}")

    # RP-06: Provenance references wrong index OID
    expect_rb_fail_closed("RP-06", "UPDATE m13_internal.migration_index_provenance SET index_oid = 999999;")

    # RP-07: Index dropped and recreated under same name (new OID)
    expect_rb_fail_closed("RP-07", "DROP INDEX public.idx_order_customizations_session_id; CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")

    # RP-08: Index definition changed after migration (via provenance/index mismatch)
    expect_rb_fail_closed("RP-08", "DROP INDEX public.idx_order_customizations_session_id; CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id, order_id);")

    # RP-09: Index renamed after migration -> does not drop renamed index
    expect_rb_fail_closed("RP-09", "ALTER INDEX public.idx_order_customizations_session_id RENAME TO idx_renamed_other;", check_idx_name="idx_renamed_other")

    # RP-10: Provenance record tampered with (created_by_migration = false)
    expect_rb_fail_closed("RP-10", "UPDATE m13_internal.migration_index_provenance SET created_by_migration = FALSE;")

    # RP-11: Migration transaction fails after index creation before commit -> no index or provenance survives
    reset_m13_db(db)
    c11 = get_conn(db, autocommit=True)
    cu11 = c11.cursor()
    mig_body = read_sql(PROV_MIG).replace("COMMIT;", "SELECT 1/0;\nCOMMIT;")
    failed11 = False
    try:
        cu11.execute(mig_body)
    except Exception:
        failed11 = True
        cu11.execute("ROLLBACK;")
    cur_tbl = None
    cu11.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
    cur_tbl = cu11.fetchone()[0]
    record("RP-11", failed11 and (not has_index(cu11, "idx_order_customizations_session_id")) and cur_tbl is None, "atomic rollback on mid-tx failure")
    c11.close()

    # RP-16: Conflicting lock / concurrent session fails safely without destructive guessing
    reset_m13_db(db)
    c_hold = get_conn(db, autocommit=False)
    c_hold.cursor().execute("LOCK TABLE public.order_customizations IN ACCESS EXCLUSIVE MODE;")
    c_try = get_conn(db, autocommit=True)
    cu_try = c_try.cursor()
    lt_err = ""
    try:
        cu_try.execute("SET lock_timeout = '300ms'; " + read_sql(PROV_MIG))
    except Exception as e:
        lt_err = str(e).splitlines()[0]
        cu_try.execute("ROLLBACK;")
    c_hold.rollback()
    c_hold.close()
    cu_try.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
    p16 = cu_try.fetchone()[0]
    c_try.close()
    record("RP-16", "lock timeout" in lt_err and p16 is None, lt_err)

    # Phase F1: Full sequence (Original -> Hardening -> Provenance Fix -> Verify -> Provenance Rollback -> Verify)
    reset_m13_db(db, with_hardening=True)
    cf = get_conn(db, autocommit=True)
    curf = cf.cursor()
    curf.execute(read_sql(PROV_MIG))
    curf.execute("SELECT proconfig, proacl::text FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
    f_cfg, f_acl = curf.fetchone()
    # Trigger check under service_role
    cf.autocommit = False
    tid, pid, sid, oid, ord_id = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    curf.execute("INSERT INTO public.personalization_templates (id, product_id, version, schema_definition, layout_template_path, updated_at) VALUES (%s,%s,'v1','{}'::jsonb,'/t', now() - INTERVAL '1 hour') RETURNING updated_at;", (tid, pid))
    t_b = curf.fetchone()[0]
    curf.execute("SET LOCAL ROLE service_role; UPDATE public.personalization_templates SET is_active = false WHERE id = %s RETURNING updated_at;", (tid,))
    t_a = curf.fetchone()[0]
    cf.rollback()
    cf.autocommit = True
    curf.execute(read_sql(PROV_RB))
    # Because hardening created idx_order_customizations_session_id before prov_mig ran, prov_mig skipped creation & recorded no provenance -> prov_rb preserved it!
    record("PHASE-F1-FULL-SEQ", f_cfg == ["search_path=pg_catalog"] and f_acl == "{postgres=X/postgres}" and t_a > t_b and has_index(curf, "idx_order_customizations_session_id"), "full sequence verified")
    cf.close()

    # Phase F2: Alternate path with pre-existing equivalent index before hardening + provenance
    reset_m13_db(db, with_hardening=False)
    cf2 = get_conn(db, autocommit=True)
    curf2 = cf2.cursor()
    curf2.execute("CREATE INDEX idx_pre_equiv_sess ON public.order_customizations (session_id);")
    curf2.execute(read_sql(HARDEN_MIG))
    curf2.execute(read_sql(PROV_MIG))
    curf2.execute(read_sql(PROV_RB))
    record("PHASE-F2-EQUIV-SEQ", has_index(curf2, "idx_pre_equiv_sess") and (not has_index(curf2, "idx_order_customizations_session_id")), "pre-existing equivalent index preserved through full sequence")
    cf2.close()

    print(f"\nTOTAL PROVENANCE & SEQUENCE TESTS: {len(results)} | PASSED: {sum(1 for r in results if r[1])} | FAILED: {sum(1 for r in results if not r[1])}")


if __name__ == "__main__":
    run_tests()
