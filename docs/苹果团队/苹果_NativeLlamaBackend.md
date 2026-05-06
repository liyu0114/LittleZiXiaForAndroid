# Native Llama Backend Notes

## Current State

`LittleZiXiaPocketLLMLlama` is an optional product that owns the llama.cpp runtime boundary. It currently compiles without external downloads, reports backend availability, validates GGUF files before native load, and preserves the same `PocketLLMRuntime` interface used by the deterministic runtime.

This keeps the main app and tests usable when GitHub or binary artifact downloads are slow. `Package.swift` now checks for a local `Vendor/llama.cpp/llama.xcframework` and only links the native binary target when that artifact exists. The native code path is already wired behind `#if canImport(llama)` for model loading, context creation, Qwen-style ChatML prompt formatting, tokenization, prompt decode, sampling, token decode, cancellation checks, and stream metrics.

The SwiftUI app now links the optional adapter product and exposes runtime selection in Settings. Deterministic mode remains the default for offline development; selecting llama.cpp rebuilds the local client and chat engine around `LlamaCppRuntime`, so model load, streaming chat, cancellation, and Metrics all go through the native runtime boundary when the vendored artifact is installed. Smoke preflight and exported smoke reports include the native runtime summary when the app can query it.

On this development machine, `scripts/bootstrap-llama-xcframework.sh --status` reports the b8953 archive fully downloaded and `Vendor/llama.cpp/llama.xcframework` installed. The artifact remains gitignored, so a fresh checkout still needs the bootstrap script before native linking is enabled.

The repository also includes `scripts/build-ios-app-bundle.sh`, which generates a temporary Xcode app host under `.build/ios-app-host`, links the local Swift package products, signs the app with the configured development team, and can install or launch it on `liyu的iPhone`. This is the bridge from compile-only package verification to real iPhone smoke runs.

For repeatable real-device smoke, `scripts/run-ios-smoke-model.sh /path/to/model.gguf` now runs a local model preflight, stages the model with `PocketLLMDevTools`, copies the generated `LittleZiXiaPocketLLM` document-store directory into the app data container, launches the app with `POCKETLLM_AUTOSMOKE=1`, validates the parsed automation result, and copies the smoke report back under `.build/ios-smoke-evidence/`.

Use `scripts/run-ios-smoke-model.sh --preflight /path/to/model.gguf` to validate the GGUF header and iPhone 11 model-fit estimate before any device build/install work. The full smoke run saves the same preflight JSON as `model-preflight.json` inside the evidence directory.

The automated run verifies local llama.cpp load/generation and writes metrics evidence. `scripts/validate-ios-smoke-result.sh` rejects missing/invalid JSON, non-passed status, zero generated tokens, empty response text, non-loaded runtime state, and invalid tokens/sec metrics. It records the Airplane Mode Chat checklist row as blocked, not passed, because iOS does not allow the script to toggle airplane mode; that row remains a manual confirmation step after the model smoke succeeds.

`scripts/test-ios-smoke-validator.sh` exercises the validator with pass/fail fixtures, and `scripts/verify-local.sh` runs that self-test before Swift and Xcode builds.

`scripts/fetch-smoke-model.sh` provides a resumable recommended-GGUF cache for this path. It currently mirrors the app's TinyLlama 15M, SmolLM2 135M, and Qwen2.5 0.5B recommended models, stores completed files under `.build/gguf-cache`, keeps incomplete downloads as `.partial`, can discover local `.gguf` files and print preflight/adopt commands, can probe a catalog or mirror URL for a GGUF header before starting a large download, can probe multiple Hugging Face-compatible endpoint candidates with `probe-endpoints`, can start a bounded download from the first passing endpoint with `resume-from-endpoints`, can inspect the manual handoff directory with `handoff-status`, can write current handoff status into `handoff-report`, can wait for a browser/AirDrop/manual handoff file to appear and settle at the suggested path with `wait-handoff` while reporting common browser temporary files, can override the Hugging Face endpoint with `POCKETLLM_HF_ENDPOINT` or `HF_ENDPOINT`, can override the full download source with `POCKETLLM_GGUF_URL`, can adopt an already-downloaded GGUF from another source after local preflight validation, can preflight a completed cached model, and can hand it directly to `scripts/run-ios-smoke-model.sh` through its `smoke` command. Completed downloads are preflight-validated before being promoted into the cache.

`scripts/smoke-doctor.sh` summarizes the native artifact, connected iPhone, selected model cache, manual handoff directory, local GGUF discovery, optional source probe, optional endpoint probe, and next commands for the real-device smoke path. Run `scripts/smoke-doctor.sh --probe-source` or set `SMOKE_DOCTOR_PROBE_SOURCE=1` when you want the doctor to perform the tiny GGUF byte-range check inline; run `scripts/smoke-doctor.sh --probe-endpoints` or set `SMOKE_DOCTOR_PROBE_ENDPOINTS=1` when you want it to try configured and built-in Hugging Face-compatible endpoints. A blocked catalog, mirror, or endpoint set is reported without failing the doctor command. Add `--json-report .build/smoke-doctor.json` to save the same readiness state as automation-friendly evidence, then run `scripts/validate-smoke-doctor-report.sh .build/smoke-doctor.json` to fail fast unless native llama.cpp, the target iPhone, and a usable GGUF source are ready. Use `--print-model-path` on the validator to emit the selected cached or discovered GGUF path for `scripts/run-ios-smoke-model.sh`. `scripts/run-ready-ios-smoke.sh --resume-from-endpoints 300` combines endpoint selection, bounded download, doctor, readiness validation, model selection, and handoff to the iPhone smoke harness; add `--adopt /path/to/model.gguf` to validate and copy a local GGUF into the cache before the readiness report is generated, add `--adopt-handoff` to refresh `.build/gguf-handoff.md` and adopt from the suggested manual-transfer path, add `--wait-for-handoff 600` to refresh the report, wait for the suggested file to settle, and then adopt it, or add `--preflight` to run only the local model-fit check.

## Intended Backend

The planned external backend is `mattt/llama.swift` tag `2.8953.0`, which exposes the llama.cpp C API through the `LlamaSwift` product and ships a prebuilt llama.cpp XCFramework. The inspected package currently targets Swift 6, iOS 16+, and llama.cpp build `b8953`.

The artifact source is:

```text
https://github.com/ggml-org/llama.cpp/releases/download/b8953/llama-b8953-xcframework.zip
```

Expected SHA-256:

```text
e0f5042a0f72bc21274bba727665b1e19129d2a3dad6873e3e7095bcd8d4c575
```

Run:

```bash
scripts/bootstrap-llama-xcframework.sh
```

Check local progress without starting a network download:

```bash
scripts/bootstrap-llama-xcframework.sh --status
```

Resume only for a bounded time window, which is useful when the network is slow:

```bash
scripts/bootstrap-llama-xcframework.sh resume-for 300
```

If the XCFramework is already installed, `resume-for` exits without starting a network download and prints the current artifact status.

This installs `Vendor/llama.cpp/llama.xcframework`. The directory is gitignored so the repository stays small; the Package manifest auto-enables the local binary target when the XCFramework is present.

The download is 176,339,336 bytes. If the network stalls, rerun the script; it uses curl resume mode and reports partial progress through `--status`. `resume-for` treats a time limit as a normal partial-progress result and only performs checksum/install after the archive reaches the expected size.

## Next Step

- Import a real small GGUF on Mac and `liyu的iPhone`, load it with `LittleZiXiaPocketLLMLlama`, and record Smoke tab evidence.
- When Hugging Face or another endpoint is reachable, run `scripts/fetch-smoke-model.sh resume-from-endpoints 300` until a small real GGUF completes, then run `scripts/fetch-smoke-model.sh preflight-all` followed by `scripts/fetch-smoke-model.sh smoke-all` and commit the resulting documented evidence summary. Those commands share one `SMOKE_RUN_ID` across Mac and iPhone evidence, and full Mac+iPhone smoke automatically writes `.build/smoke-run-summaries/<run-id>.json/.md`; use `scripts/summarize-smoke-run.sh --require-both <run-id>` to regenerate or audit the compact summary and its file-name, byte-size, and SHA-256 model identity checks. If terminal downloads remain blocked but browser/AirDrop/manual transfer works, run `scripts/fetch-smoke-model.sh handoff` or `scripts/fetch-smoke-model.sh handoff-report .build/gguf-handoff.md`, then run the report's `scripts/run-ready-ios-smoke.sh --with-mac-smoke --wait-for-handoff 600 --preflight` command while the file lands at the suggested path, or `--with-mac-smoke --adopt-handoff --preflight` after it already exists; the wrapper refreshes the handoff Markdown before adopting. The latest TinyLlama 15M endpoint probe on 2026-04-29 timed out after 10 seconds on both Hugging Face and hf-mirror with 0 downloaded bytes.
- Keep `llama.swift` as reference material instead of a required remote SwiftPM dependency, unless the network path becomes reliable enough for repeatable CI/dev builds.

## Acceptance

- `swift test` still passes without network.
- Native backend reports linked availability when the binary is present.
- A tiny GGUF loads on iPhone 11.
- One prompt produces streamed tokens, metrics, and a completion event.
