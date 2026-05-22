Ultimate Master Test Suite Release

- Summary: This release adds the Ultimate Master Test Suite, validating the entire Medallion Architecture stack end-to-end on production-like infrastructure.
- Components:
  - Linux Kernel data ingestion path (GitHub Linux commits).
  - Spark ELT (Bronze -> Silver -> GoldDelta).
  - Delta Lake: Gold and Silver data stores for QA metrics and Scrum context.
  - Jira MCP integration for real-time ticket and sprint data.
  - LLM orchestration (Llama 3.2, Mistral, and associated tooling).
- Goal: Ensure end-to-end functional validation via test-all.sh, with MinIO, MCP, Spark, Delta, and UI tests all green on deploy.
