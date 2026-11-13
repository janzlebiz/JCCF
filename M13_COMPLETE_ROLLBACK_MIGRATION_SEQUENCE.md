# M13 Complete Rollback Migration Sequence

---

## 1. Canonical Forward Sequence (Recommended Only)

1. `migrations/20261112_001_personalization_engine.sql` (`SHA-256: 9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`)
2. `migrations/20261113_2345_m13_hardening_and_provenance.sql` (`SHA-256: 047C1C916CE48825D0516304F060C33488EC2F75D6869315572EF35478619BEA`)

---

## 2. Canonical Reverse Rollback Sequence (Recommended Only)

1. `migrations/20261113_2345_m13_hardening_and_provenance_rollback.sql` (`SHA-256: CE707D18B9A69B1E9A4806D3190935280909164081E405B1C7032405A5A51D8C`)
2. `migrations/20261112_001_personalization_engine_rollback.sql` (`SHA-256: 73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`)

---

## 3. Handling Pre-Existing & Historical States

- **Pre-existing exact-name or equivalent index:** `20261113_2345_m13_hardening_and_provenance.sql` preserves it and records zero provenance. `20261113_2345_m13_hardening_and_provenance_rollback.sql` preserves it on rollback.
- **Database where historical `20261113_1335_m13_production_hardening.sql` was already applied:** `20261113_2345` observes the existing index, does not retroactively claim ownership, and `20261113_2345_rollback` preserves the unowned index as a residual object requiring manual review (`SEQ-04`).
- **Clean database where `20261113_2345` creates the index:** `20261113_2345` records atomic OID + definition provenance, and `20261113_2345_rollback` safely drops the owned index and metadata (`SEQ-01`).
