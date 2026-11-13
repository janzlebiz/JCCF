#!/usr/bin/env python3
"""
JCCF Subsystem M13 - Complete Rollback Chain, Provenance & Timeout Verification Suite
Executes against disposable local PostgreSQL 17.11 databases.
Zero production connections. Fails suite if any required test is not executed.
"""

import os
import sys
import time
import uuid
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parent.parent
ORIG_MIG = ROOT / "migrations" / "20261112_001_personalization_engine.sql"
ORIG_RB = ROOT / "migrations" / "20261112_001_personalization_engine_rollback.sql"
OLD_HARDEN_MIG = ROOT / "migrations" / "20261113_1335_m13_production_hardening.sql"
CORR_MIG = ROOT / "migrations" / "20261113_2345_m13_hardening_and_provenance.sql"
CORR_RB = ROOT / "migrations" / "20261113_2345_m13_hardening_and_provenance_rollback.sql"


def read_sql(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def get_conn(dbname: str = "postgres", autocommit: bool = True):
    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "127.0.0.1"),
        port=int(os.getenv("PGPORT", "5439")),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", "postgres"),
        dbname=dbname,
    )
    conn.autocommit = autocommit
    return conn


def ensure_roles_and_parents(cur):
    cur.execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
    END $$;
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS public.products (id UUID PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS public.orders (id UUID PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS public.unrelated_keep (id INT PRIMARY KEY, note TEXT);
    """)


def reset_db(dbname: str, apply_orig: bool = True):
    conn = get_conn("postgres", autocommit=True)
    cur = conn.cursor()
    cur.execute(f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{dbname}' AND pid <> pg_backend_pid();")
    cur.execute(f'DROP DATABASE IF EXISTS "{dbname}";')
    cur.execute(f'CREATE DATABASE "{dbname}";')
    conn.close()

    c = get_conn(dbname, autocommit=True)
    cu = c.cursor()
    ensure_roles_and_parents(cu)
    if apply_orig:
        cu.execute(read_sql(ORIG_MIG))
    c.close()


def has_index(cur, index_name: str) -> bool:
    cur.execute(
        "SELECT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        "WHERE n.nspname='public' AND c.relname=%s AND c.relkind='i');",
        (index_name,),
    )
    return bool(cur.fetchone()[0])


def get_index_oid(cur, index_name: str):
    cur.execute(
        "SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        "WHERE n.nspname='public' AND c.relname=%s AND c.relkind='i';",
        (index_name,),
    )
    row = cur.fetchone()
    return row[0] if row else None


def get_table_oid(cur, table_name: str):
    cur.execute("SELECT to_regclass(%s)::oid;", (f"public.{table_name}",))
    row = cur.fetchone()
    return row[0] if row else None


def run_tests():
    db = f"m13_chain_{uuid.uuid4().hex[:8]}"
    results = []

    def record(tid: str, ok: bool, detail: str):
        results.append((tid, ok, detail))
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {tid}: {detail}", flush=True)

    try:
        # ------------------------------------------------------------------
        # Provenance & Ownership Scenarios: RP-01 through RP-20
        # ------------------------------------------------------------------

        # RP-01: Index absent before forward migration -> creates index + provenance
        reset_db(db)
        c = get_conn(db)
        cu = c.cursor()
        cu.execute(read_sql(CORR_MIG))
        cu.execute("SELECT migration_id, owning_migration, index_name, created_by_migration FROM m13_internal.migration_index_provenance;")
        rows = cu.fetchall()
        ok = (
            has_index(cu, "idx_order_customizations_session_id")
            and len(rows) == 1
            and rows[0] == ("20261113_2345_m13_hardening_and_provenance", "20261113_2345_m13_hardening_and_provenance", "idx_order_customizations_session_id", True)
        )
        record("RP-01", ok, f"prov={rows}")
        c.close()

        # RP-02: Exact-name index exists before migration -> preserve, no ownership claim
        reset_db(db)
        c = get_conn(db)
        cu = c.cursor()
        cu.execute("CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")
        oid_before = get_index_oid(cu, "idx_order_customizations_session_id")
        cu.execute(read_sql(CORR_MIG))
        oid_after = get_index_oid(cu, "idx_order_customizations_session_id")
        cu.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
        prov_tbl = cu.fetchone()[0]
        record("RP-02", oid_before == oid_after and prov_tbl is None, f"oid_before={oid_before}, oid_after={oid_after}, prov_tbl={prov_tbl}")
        c.close()

        # RP-03: Equivalent index exists under another name -> preserve, no ownership claim
        reset_db(db)
        c = get_conn(db)
        cu = c.cursor()
        cu.execute("CREATE INDEX idx_alt_sess_covering ON public.order_customizations (session_id);")
        oid_before = get_index_oid(cu, "idx_alt_sess_covering")
        cu.execute(read_sql(CORR_MIG))
        oid_after = get_index_oid(cu, "idx_alt_sess_covering")
        cu.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
        prov_tbl = cu.fetchone()[0]
        record("RP-03", oid_before == oid_after and (not has_index(cu, "idx_order_customizations_session_id")) and prov_tbl is None, f"equiv_oid={oid_after}")
        c.close()

        # RP-04: Incompatible same-name index collision -> abort without mutation
        reset_db(db)
        c = get_conn(db)
        cu = c.cursor()
        cu.execute("CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (order_id);")
        aborted = False
        try:
            cu.execute(read_sql(CORR_MIG))
        except Exception as e:
            aborted = "incompatible definition" in str(e)
            cu.execute("ROLLBACK;")
        cu.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
        procfg = cu.fetchone()[0]
        record("RP-04", aborted and procfg is None, f"aborted={aborted}, proconfig={procfg}")
        c.close()

        # RP-05: Provenance missing -> rollback preserves index
        reset_db(db)
        c = get_conn(db)
        cu = c.cursor()
        cu.execute(read_sql(CORR_MIG))
        cu.execute("DELETE FROM m13_internal.migration_index_provenance;")
        cu.execute(read_sql(CORR_RB))
        record("RP-05", has_index(cu, "idx_order_customizations_session_id"), "missing provenance row preserved index")
        c.close()

        def expect_rb_fail_closed(tid: str, mutate_sql: str, check_idx: str = "idx_order_customizations_session_id", expected_substr: str = ""):
            reset_db(db)
            c_loc = get_conn(db)
            cu_loc = c_loc.cursor()
            cu_loc.execute(read_sql(CORR_MIG))
            cu_loc.execute(mutate_sql)
            failed = False
            err = ""
            try:
                cu_loc.execute(read_sql(CORR_RB))
            except Exception as e:
                failed = True
                err = str(e).splitlines()[0]
                cu_loc.execute("ROLLBACK;")
            preserved = has_index(cu_loc, check_idx)
            substr_ok = (expected_substr in err) if expected_substr else True
            c_loc.close()
            record(tid, failed and preserved and substr_ok, f"{err} | preserved={preserved}")

        # RP-06: Wrong index OID -> rollback preserves index
        expect_rb_fail_closed("RP-06", "UPDATE m13_internal.migration_index_provenance SET index_oid = 999999;", expected_substr="no longer exists")

        # RP-07: Same-name index dropped and recreated -> rollback detects replacement
        expect_rb_fail_closed(
            "RP-07",
            "DROP INDEX public.idx_order_customizations_session_id; CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);",
            expected_substr="no longer exists",
        )

        # RP-08: Genuine table drop and recreation -> rollback detects table_oid mismatch & preserves recreated table and index
        reset_db(db)
        c8 = get_conn(db)
        cu8 = c8.cursor()
        cu8.execute(read_sql(CORR_MIG))
        orig_tbl_oid = get_table_oid(cu8, "order_customizations")
        cu8.execute("DROP TABLE public.order_customizations CASCADE;")
        cu8.execute("""
            CREATE TABLE public.order_customizations (
                id UUID PRIMARY KEY,
                order_id UUID NOT NULL,
                session_id UUID NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            );
            CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);
        """)
        new_tbl_oid = get_table_oid(cu8, "order_customizations")
        failed8 = False
        err8 = ""
        try:
            cu8.execute(read_sql(CORR_RB))
        except Exception as e:
            failed8 = True
            err8 = str(e).splitlines()[0]
            cu8.execute("ROLLBACK;")
        ok8 = (
            failed8
            and new_tbl_oid is not None
            and new_tbl_oid != orig_tbl_oid
            and "Table OID mismatch" in err8
            and has_index(cu8, "idx_order_customizations_session_id")
            and get_table_oid(cu8, "order_customizations") == new_tbl_oid
        )
        record("RP-08", ok8, f"orig_oid={orig_tbl_oid}, new_oid={new_tbl_oid}, err={err8}")
        c8.close()

        # RP-09: Index altered or renamed -> rollback preserves changed object
        expect_rb_fail_closed("RP-09", "ALTER INDEX public.idx_order_customizations_session_id RENAME TO idx_renamed_by_ops;", check_idx="idx_renamed_by_ops", expected_substr="mismatch")

        # RP-10: Provenance tampered with -> fail closed
        expect_rb_fail_closed("RP-10", "UPDATE m13_internal.migration_index_provenance SET created_by_migration = FALSE;", expected_substr="integrity validation")

        # RP-11: Forward migration fails mid-transaction -> no partial index/provenance state
        reset_db(db)
        c11 = get_conn(db)
        cu11 = c11.cursor()
        bad_sql = read_sql(CORR_MIG).replace("COMMIT;", "SELECT 1/0;\nCOMMIT;")
        failed11 = False
        try:
            cu11.execute(bad_sql)
        except Exception:
            failed11 = True
            cu11.execute("ROLLBACK;")
        cu11.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
        prov11 = cu11.fetchone()[0]
        record("RP-11", failed11 and (not has_index(cu11, "idx_order_customizations_session_id")) and prov11 is None, "atomic rollback on mid-tx failure")
        c11.close()

        # RP-12: Forward migration rerun -> idempotent
        reset_db(db)
        c12 = get_conn(db)
        cu12 = c12.cursor()
        cu12.execute(read_sql(CORR_MIG))
        oid12_a = get_index_oid(cu12, "idx_order_customizations_session_id")
        cu12.execute(read_sql(CORR_MIG))
        oid12_b = get_index_oid(cu12, "idx_order_customizations_session_id")
        cu12.execute("SELECT count(*) FROM m13_internal.migration_index_provenance;")
        cnt12 = cu12.fetchone()[0]
        record("RP-12", oid12_a == oid12_b and cnt12 == 1, f"oid={oid12_b}, prov_cnt={cnt12}")
        c12.close()

        # RP-13: Rollback rerun -> safe idempotent behavior
        reset_db(db)
        c13 = get_conn(db)
        cu13 = c13.cursor()
        cu13.execute(read_sql(CORR_MIG))
        cu13.execute(read_sql(CORR_RB))
        cu13.execute(read_sql(CORR_RB))
        cu13.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
        prov13 = cu13.fetchone()[0]
        record("RP-13", (not has_index(cu13, "idx_order_customizations_session_id")) and prov13 is None, "rollback rerun safe")
        c13.close()

        # RP-14: Valid ownership -> remove only owned index and metadata, preserve other M13 indexes & unrelated provenance
        reset_db(db)
        c14 = get_conn(db)
        cu14 = c14.cursor()
        cu14.execute(read_sql(CORR_MIG))
        cu14.execute("INSERT INTO m13_internal.migration_index_provenance VALUES ('other_mig','other_mig','public','unrelated_keep',0,'idx_other',0,'CREATE INDEX idx_other ON public.unrelated_keep (id)',TRUE);")
        cu14.execute(read_sql(CORR_RB))
        cu14.execute("SELECT migration_id FROM m13_internal.migration_index_provenance;")
        rem_prov = [r[0] for r in cu14.fetchall()]
        record("RP-14", (not has_index(cu14, "idx_order_customizations_session_id")) and rem_prov == ["other_mig"], f"remaining_prov={rem_prov}")
        c14.close()

        # RP-15: Pre-existing index rollback -> preserve pre-existing index
        reset_db(db)
        c15 = get_conn(db)
        cu15 = c15.cursor()
        cu15.execute("CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")
        oid15_a = get_index_oid(cu15, "idx_order_customizations_session_id")
        cu15.execute(read_sql(CORR_MIG))
        cu15.execute(read_sql(CORR_RB))
        oid15_b = get_index_oid(cu15, "idx_order_customizations_session_id")
        record("RP-15", oid15_a == oid15_b, f"preserved_oid={oid15_b}")
        c15.close()

        # RP-16: Conflicting ownership records -> abort safely
        expect_rb_fail_closed(
            "RP-16",
            "INSERT INTO m13_internal.migration_index_provenance VALUES ('20261114_0001_conflict','20261114_0001_conflict','public','order_customizations',0,'idx_order_customizations_session_id',0,'CREATE INDEX ...',TRUE);",
            expected_substr="Conflicting ownership records",
        )

        # RP-17: Wrong migration identifier (owning_migration mismatch) -> preserve index
        expect_rb_fail_closed(
            "RP-17",
            "UPDATE m13_internal.migration_index_provenance SET owning_migration = '20261113_1335_m13_production_hardening';",
            expected_substr="integrity validation",
        )

        # RP-18: Wrong schema or relation identity -> preserve index
        expect_rb_fail_closed(
            "RP-18",
            "UPDATE m13_internal.migration_index_provenance SET table_name = 'customization_sessions';",
            expected_substr="integrity validation",
        )

        # RP-19: Provenance table structure unexpectedly changed -> abort safely
        expect_rb_fail_closed(
            "RP-19",
            "ALTER TABLE m13_internal.migration_index_provenance DROP COLUMN index_def;",
            expected_substr="structure unexpectedly modified",
        )

        # RP-20: Application-role access to provenance -> denied for anon and authenticated
        reset_db(db)
        c20 = get_conn(db)
        cu20 = c20.cursor()
        cu20.execute(read_sql(CORR_MIG))
        denied_roles = []
        for role in ("anon", "authenticated", "service_role"):
            c_role = get_conn(db, autocommit=False)
            cu_role = c_role.cursor()
            cu_role.execute(f"SET LOCAL ROLE {role};")
            try:
                cu_role.execute("SELECT * FROM m13_internal.migration_index_provenance;")
            except Exception:
                denied_roles.append(role)
            c_role.rollback()
            c_role.close()
        record("RP-20", denied_roles == ["anon", "authenticated", "service_role"], f"denied={denied_roles}")
        c20.close()

        # ------------------------------------------------------------------
        # Full Sequence Scenarios: SEQ-01 through SEQ-07
        # ------------------------------------------------------------------

        # SEQ-01: Clean database -> full forward -> full reverse
        reset_db(db, apply_orig=False)
        cs1 = get_conn(db)
        cus1 = cs1.cursor()
        cus1.execute(read_sql(ORIG_MIG))
        cus1.execute(read_sql(CORR_MIG))
        fwd_ok = (
            has_index(cus1, "idx_order_customizations_session_id")
            and get_table_oid(cus1, "personalization_templates") is not None
        )
        cus1.execute(read_sql(CORR_RB))
        mid_rb_ok = (
            not has_index(cus1, "idx_order_customizations_session_id")
            and get_table_oid(cus1, "order_customizations") is not None
        )
        cus1.execute(read_sql(ORIG_RB))
        end_rb_ok = (
            get_table_oid(cus1, "personalization_templates") is None
            and get_table_oid(cus1, "customization_sessions") is None
            and get_table_oid(cus1, "order_customizations") is None
            and get_table_oid(cus1, "unrelated_keep") is not None
        )
        record("SEQ-01", fwd_ok and mid_rb_ok and end_rb_ok, "full clean forward + reverse sequence verified")
        cs1.close()

        # SEQ-02: Pre-existing exact-name index -> full forward -> corrected hardening rollback preserves index
        reset_db(db, apply_orig=False)
        cs2 = get_conn(db)
        cus2 = cs2.cursor()
        cus2.execute(read_sql(ORIG_MIG))
        cus2.execute("CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")
        pre_oid2 = get_index_oid(cus2, "idx_order_customizations_session_id")
        cus2.execute(read_sql(CORR_MIG))
        cus2.execute(read_sql(CORR_RB))
        post_oid2 = get_index_oid(cus2, "idx_order_customizations_session_id")
        cus2.execute("SELECT proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='m13_set_updated_at';")
        cfg2 = cus2.fetchone()[0]
        record("SEQ-02", pre_oid2 == post_oid2 and cfg2 is None, f"pre_oid={pre_oid2}, post_oid={post_oid2}, proconfig={cfg2}")
        cs2.close()

        # SEQ-03: Pre-existing equivalent index under another name -> preserved across full forward + hardening rollback
        reset_db(db, apply_orig=False)
        cs3 = get_conn(db)
        cus3 = cs3.cursor()
        cus3.execute(read_sql(ORIG_MIG))
        cus3.execute("CREATE INDEX idx_pre_equiv_other ON public.order_customizations (session_id);")
        pre_oid3 = get_index_oid(cus3, "idx_pre_equiv_other")
        cus3.execute(read_sql(CORR_MIG))
        cus3.execute(read_sql(CORR_RB))
        post_oid3 = get_index_oid(cus3, "idx_pre_equiv_other")
        record("SEQ-03", pre_oid3 == post_oid3 and (not has_index(cus3, "idx_order_customizations_session_id")), f"equiv_oid={post_oid3}")
        cs3.close()

        # SEQ-04: Historical hardening state (1335 applied) -> corrected forward -> corrected rollback preserves unowned index
        reset_db(db, apply_orig=False)
        cs4 = get_conn(db)
        cus4 = cs4.cursor()
        cus4.execute(read_sql(ORIG_MIG))
        cus4.execute(read_sql(OLD_HARDEN_MIG))
        hist_oid = get_index_oid(cus4, "idx_order_customizations_session_id")
        cus4.execute(read_sql(CORR_MIG))
        cus4.execute(read_sql(CORR_RB))
        post_hist_oid = get_index_oid(cus4, "idx_order_customizations_session_id")
        record("SEQ-04", hist_oid is not None and hist_oid == post_hist_oid, f"historical_oid_preserved={post_hist_oid}")
        cs4.close()

        # SEQ-05: Replacement index -> drop/recreate -> rollback preserves replacement
        reset_db(db)
        cs5 = get_conn(db)
        cus5 = cs5.cursor()
        cus5.execute(read_sql(CORR_MIG))
        cus5.execute("DROP INDEX public.idx_order_customizations_session_id; CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")
        repl_oid = get_index_oid(cus5, "idx_order_customizations_session_id")
        failed5 = False
        try:
            cus5.execute(read_sql(CORR_RB))
        except Exception:
            failed5 = True
            cus5.execute("ROLLBACK;")
        record("SEQ-05", failed5 and get_index_oid(cus5, "idx_order_customizations_session_id") == repl_oid, f"replacement_oid={repl_oid}")
        cs5.close()

        # SEQ-06: Table replacement -> drop/recreate table & index -> rollback detects mismatch & preserves replacement
        reset_db(db)
        cs6 = get_conn(db)
        cus6 = cs6.cursor()
        cus6.execute(read_sql(CORR_MIG))
        cus6.execute("DROP TABLE public.order_customizations CASCADE; CREATE TABLE public.order_customizations (id UUID PRIMARY KEY, session_id UUID NOT NULL); CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);")
        repl_tbl_oid = get_table_oid(cus6, "order_customizations")
        failed6 = False
        try:
            cus6.execute(read_sql(CORR_RB))
        except Exception:
            failed6 = True
            cus6.execute("ROLLBACK;")
        record("SEQ-06", failed6 and get_table_oid(cus6, "order_customizations") == repl_tbl_oid and has_index(cus6, "idx_order_customizations_session_id"), f"repl_tbl_oid={repl_tbl_oid}")
        cs6.close()

        # SEQ-07: Failure and interruption (mid-tx error) -> atomic rollback, zero partial provenance
        reset_db(db)
        cs7 = get_conn(db)
        cus7 = cs7.cursor()
        failed7 = False
        try:
            cus7.execute(read_sql(CORR_MIG).replace("COMMIT;", "RAISE EXCEPTION 'simulated_interrupt';\nCOMMIT;"))
        except Exception:
            failed7 = True
            cus7.execute("ROLLBACK;")
        cus7.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
        prov7 = cus7.fetchone()[0]
        record("SEQ-07", failed7 and (not has_index(cus7, "idx_order_customizations_session_id")) and prov7 is None, "atomic rollback on simulated failure")
        cs7.close()

        # ------------------------------------------------------------------
        # Timeout Enforcement Tests: TIMEOUT-01 through TIMEOUT-05
        # ------------------------------------------------------------------
        fwd_sql = read_sql(CORR_MIG)
        rb_sql = read_sql(CORR_RB)

        # TIMEOUT-01: Verify SQL sets transaction-local lock_timeout = '5s'
        t01 = ("SET LOCAL lock_timeout = '5s';" in fwd_sql) and ("SET LOCAL lock_timeout = '5s';" in rb_sql)
        record("TIMEOUT-01", t01, "SET LOCAL lock_timeout = '5s' present in forward and rollback SQL")

        # TIMEOUT-02: Verify SQL sets transaction-local statement_timeout = '30s'
        t02 = ("SET LOCAL statement_timeout = '30s';" in fwd_sql) and ("SET LOCAL statement_timeout = '30s';" in rb_sql)
        record("TIMEOUT-02", t02, "SET LOCAL statement_timeout = '30s' present in forward and rollback SQL")

        # TIMEOUT-03: Simulate lock contention WITHOUT harness SET lock_timeout -> SQL aborts at ~5s with 55P03
        reset_db(db)
        c_hold = get_conn(db, autocommit=False)
        c_hold.cursor().execute("LOCK TABLE public.order_customizations IN ACCESS EXCLUSIVE MODE;")
        c_try = get_conn(db, autocommit=True)
        cu_try = c_try.cursor()
        t_start = time.monotonic()
        pgcode3 = None
        err3 = ""
        try:
            cu_try.execute(fwd_sql)
        except Exception as e:
            pgcode3 = getattr(e, "pgcode", None)
            err3 = str(e).splitlines()[0]
            cu_try.execute("ROLLBACK;")
        elapsed3 = time.monotonic() - t_start
        c_hold.rollback()
        c_hold.close()
        c_try.close()
        record("TIMEOUT-03", pgcode3 == "55P03" and 4.0 <= elapsed3 <= 8.5, f"pgcode={pgcode3}, elapsed={elapsed3:.2f}s, err={err3}")

        # TIMEOUT-04: Simulate statement timeout WITHOUT harness SET statement_timeout -> SQL aborts at ~30s with 57014
        reset_db(db)
        c_st = get_conn(db, autocommit=True)
        cu_st = c_st.cursor()
        slow_sql = fwd_sql.replace("COMMIT;", "SELECT pg_sleep(32);\nCOMMIT;")
        t_start4 = time.monotonic()
        pgcode4 = None
        err4 = ""
        try:
            cu_st.execute(slow_sql)
        except Exception as e:
            pgcode4 = getattr(e, "pgcode", None)
            err4 = str(e).splitlines()[0]
            cu_st.execute("ROLLBACK;")
        elapsed4 = time.monotonic() - t_start4
        cu_st.execute("SELECT to_regclass('m13_internal.migration_index_provenance');")
        prov4 = cu_st.fetchone()[0]
        idx4_exists = has_index(cu_st, "idx_order_customizations_session_id")
        c_st.close()
        record("TIMEOUT-04", pgcode4 == "57014" and 29.0 <= elapsed4 <= 34.0 and (not idx4_exists) and prov4 is None, f"pgcode={pgcode4}, elapsed={elapsed4:.2f}s, prov={prov4}, err={err4}")

        # TIMEOUT-05: Confirm SET LOCAL does not persist into subsequent transactions
        reset_db(db)
        c5 = get_conn(db, autocommit=True)
        cu5 = c5.cursor()
        cu5.execute("SHOW lock_timeout;")
        lt_before = cu5.fetchone()[0]
        cu5.execute("SHOW statement_timeout;")
        st_before = cu5.fetchone()[0]
        cu5.execute(fwd_sql)
        cu5.execute("SHOW lock_timeout;")
        lt_after = cu5.fetchone()[0]
        cu5.execute("SHOW statement_timeout;")
        st_after = cu5.fetchone()[0]
        record("TIMEOUT-05", lt_before == lt_after and st_before == st_after, f"lock_timeout: {lt_before}->{lt_after}, statement_timeout: {st_before}->{st_after}")
        c5.close()

        # ------------------------------------------------------------------
        # Event Trigger Compatibility: RLS-AUTO-ENABLE-EVENT-TRIGGER
        # ------------------------------------------------------------------
        reset_db(db, apply_orig=False)
        cet = get_conn(db, autocommit=True)
        cuet = cet.cursor()
        cuet.execute("""
            CREATE OR REPLACE FUNCTION public.rls_auto_enable()
            RETURNS event_trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
            DECLARE obj RECORD;
            BEGIN
                FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag = 'CREATE TABLE'
                LOOP
                    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', obj.object_identity);
                END LOOP;
            END;
            $$;
            CREATE EVENT TRIGGER rls_auto_enable_trg ON ddl_command_end WHEN TAG IN ('CREATE TABLE') EXECUTE FUNCTION public.rls_auto_enable();
        """)
        cuet.execute(read_sql(ORIG_MIG))
        cuet.execute(read_sql(CORR_MIG))
        cuet.execute("SELECT c.relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='m13_internal' AND c.relname='migration_index_provenance';")
        rls_on = cuet.fetchone()[0]
        cuet.execute(read_sql(CORR_RB))
        cuet.execute(read_sql(ORIG_RB))
        cuet.execute("SELECT count(*) FROM pg_event_trigger WHERE evtname = 'rls_auto_enable_trg';")
        evt_cnt = cuet.fetchone()[0]
        record("RLS-AUTO-ENABLE-EVENT-TRIGGER", rls_on is True and evt_cnt == 1, f"rls_on={rls_on}, evt_preserved={evt_cnt}")
        cet.close()

    finally:
        c_drop = get_conn("postgres", autocommit=True)
        cur_drop = c_drop.cursor()
        cur_drop.execute(f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{db}' AND pid <> pg_backend_pid();")
        cur_drop.execute(f'DROP DATABASE IF EXISTS "{db}";')
        c_drop.close()

    total = len(results)
    passed = sum(1 for r in results if r[1])
    failed = total - passed
    print(f"\nTOTAL COMPLETE CHAIN TESTS: {total} | PASSED: {passed} | FAILED: {failed}", flush=True)
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
