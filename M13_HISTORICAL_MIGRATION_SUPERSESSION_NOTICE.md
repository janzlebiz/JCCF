# M13 Historical Migration Supersession Notice

**Effective Immediately for Future M13 Releases:**

The following historical SQL artifacts remain preserved in Git history and on disk **solely as immutable audit evidence** and **MUST NOT BE EXECUTED**:

| Superseded Artifact | SHA-256 (Preserved) | Reason Superseded |
| :--- | :--- | :--- |
| `migrations/20261113_1335_m13_production_hardening.sql` | `4F74EC3B6660B49367639B0AD1981AA637F1D130F00C8E66163F46B23594A5EA` | Does not record atomic index ownership provenance; lacks SQL-enforced `SET LOCAL` timeouts. |
| `migrations/20261113_1335_m13_production_hardening_rollback.sql` | `3D10A9C212250C270FC4E337B1539ED51B78BD0D42C29B09AD9D6F62AE8347C6` | **UNSAFE:** Unconditionally executes `DROP INDEX IF EXISTS public.idx_order_customizations_session_id;`, risking deletion of pre-existing indexes. |
| `migrations/20261113_2200_m13_rollback_provenance_fix.sql` | `561779C187F53EB2EE03FA0D3814DEE1CC8197C2F99A967ABC5C6DE65EED7976` | Add-on patch that could not remediate `1335_rollback` or enforce `SET LOCAL` timeouts. |
| `migrations/20261113_2200_m13_rollback_provenance_fix_rollback.sql` | `7F550EC266E203F8AE9664C376A194DD3719F1A95BA9F7381AA03CA8F5DF01D6` | Lacked SQL-enforced `SET LOCAL` timeouts and unified hardening reversal. |

**Superseding Replacement Pair:**
- `migrations/20261113_2345_m13_hardening_and_provenance.sql` (`SHA-256: 047C1C916CE48825D0516304F060C33488EC2F75D6869315572EF35478619BEA`)
- `migrations/20261113_2345_m13_hardening_and_provenance_rollback.sql` (`SHA-256: CE707D18B9A69B1E9A4806D3190935280909164081E405B1C7032405A5A51D8C`)
