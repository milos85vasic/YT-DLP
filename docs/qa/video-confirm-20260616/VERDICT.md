# §11.4.153 video-confirmation — dashboard @ 20260615T221723Z
- rotation: removed prior ytdlp---dashboard---* (kept foreign helix*-/operator files)
- capture: OK -> /Volumes/T7/Downloads/Recordings/ytdlp---dashboard---20260615T221723Z.png (84844 bytes, window-scoped viewport §11.4.154)
- HelixAgent http://localhost:7061/health: {"status":"healthy"}
- HelixAgent /v1/chat/completions raw (first 700 chars):
```
{"error":{"code":400,"message":"Invalid request format: json: cannot unmarshal array into Go struct field OpenAIMessage.messages.content of type string","type":"invalid_request"}}
```
- ENSEMBLE VERDICT (content): 
_finished 2026-06-15T22:19:11Z_

## Conclusion (honest, §11.4.21)
- CAPTURE: PASS — real window-scoped 1366x900 PNG produced + correct ytdlp--- rotation.
- ENSEMBLE ANALYSIS: OPERATOR-BLOCKED — no vision-capable model available locally:
  HelixAgent (:7061) is text-only (content:string; /v1/vision/* stubbed), and
  helix_ollama_video (:11434) has only qwen2.5:3b (text). Unblock by deploying a
  vision model (e.g. `podman exec helix_ollama_video ollama pull llava` + point the
  harness at the Ollama vision endpoint, or configure a HelixAgent vision provider).
  The harness does NOT deploy a model itself (operator infra, §11.4.122) and does NOT
  fake a verdict.
