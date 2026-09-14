# tests/fixtures/proj/.thoth/memory/MEMORY.md — a git-TRACKED stand-in for a PROJECT's own `.thoth/memory/`.
# tests/cases/core.cyr (test_memory_index_witness) walks to this store while naming the fixture home's index
# as "the global index": these bytes DIFFER from it, so the index witness must stay silent and the store is
# the project's (two layers, each read once). Never loaded outside the suite.
- FIXTURE-FACT-PROJ: a fact in a project store
