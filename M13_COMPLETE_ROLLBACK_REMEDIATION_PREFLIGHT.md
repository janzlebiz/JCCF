# M13 Complete Rollback Remediation — Preflight Audit

**Repository:** `https://github.com/janzlebiz/JCCF`
**Branch:** `main`
**Baseline Commit:** `917ae27f946073fd1cd195edc431be8aae397ac4`
**Production Project:** `ammsjbcpbspisbyynaga` (`ap-northeast-2`, PostgreSQL 17.11)

---

## 1. Baseline & Historical Hash Verification

The baseline commit `917ae27f946073fd1cd195edc431be8aae397ac4` was verified on `main...origin/main` with a clean working tree prior to remediation. All six historical SQL artifacts remain byte-for-byte unchanged:

| Artifact | SHA-256 (CRLF) | Status |
| :--- | :--- | :--- |
| `migrations/20261112_001_personalization_engine.sql` | `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E` | Preserved (Active Base) |
| `migrations/20261112_001_personalization_engine_rollback.sql` | `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4` | Preserved (Active Base Rollback) |
| `migrations/20261113_1335_m13_production_hardening.sql` | `4F74EC3B6660B49367639B0AD1981AA637F1D130F00C8E66163F46B23594A5EA` | Preserved (Superseded) |
| `migrations/20261113_1335_m13_production_hardening_rollback.sql` | `3D10A9C212250C270FC4E337B1539ED51B78BD0D42C29B09AD9D6F62AE8347C6` | Preserved (Superseded — Unsafe) |
| `migrations/20261113_2200_m13_rollback_provenance_fix.sql` | `561779C187F53EB2EE03FA0D3814DEE1CC8197C2F99A967ABC5C6DE65EED7976` | Preserved (Superseded) |
| `migrations/20261113_2200_m13_rollback_provenance_fix_rollback.sql` | `7F550EC266E203F8AE9664C376A194DD3719F1A95BA9F7381AA03CA8F5DF01D6` | Preserved (Superseded) |

---

## 2. Four Mandatory Findings Addressed

1. **Unsafe `1335` Rollback in Chain:** `20261113_1335_m13_production_hardening_rollback.sql` unconditionally executes `DROP INDEX IF EXISTS public.idx_order_customizations_session_id;`, and `20261113_2200` only recorded ownership when it created the index itself. Both `1335` and `2200` are superseded by the unified `20261113_2345_m13_hardening_and_provenance.sql` and `20261113_2345_m13_hardening_and_provenance_rollback.sql` pair.
2. **Test Report vs. Code Mismatch:** `RP-08` previously only dropped/recreated the index rather than dropping and recreating `public.order_customizations` to prove `table_oid` mismatch. Replaced with genuine table drop/recreate verification in `tests/test_m13_complete_rollback_chain_postgres.py`.
3. **Incomplete Sequence Testing:** Previous sequence tests skipped `1335` rollback and `001` rollback. New `SEQ-01` through `SEQ-07` execute the complete forward and reverse sequence including `20261113_2345` rollback and `20261112_001` rollback.
4. **SQL-Enforced Timeouts:** `SET LOCAL lock_timeout = '5s';` and `SET LOCAL statement_timeout = '30s';` are now explicitly enforced inside the `BEGIN; ... COMMIT;` blocks of both `20261113_2345` SQL files and verified by `TIMEOUT-01` through `TIMEOUT-05`.
