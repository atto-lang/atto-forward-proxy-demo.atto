# Forward-proxy performance evidence

The forward demo has two very different performance questions. They must not be collapsed into one chart.

## Runnable now: CONNECT admission policy

`bench/connect_policy_workload.ores` executes a fixed workload of 100,000 admitted CONNECT policy plans and 100,000 denied plans against one immutable generation snapshot. Every admitted result is checked to remain non-authorizing: `socket_authorized` is false and `may_connect` is false.

The manual `.github/workflows/perf-connect-policy.yml` lane compiler-checks the exact benchmark source, performs a warmup, runs five measured samples under `/usr/bin/time`, and retains wall/user/system time plus maximum RSS and machine/runtime provenance.

This is an **Oreslang internal regression benchmark**. It is not comparable with nginx or HAProxy request throughput because it opens no listening socket, performs no DNS lookup, establishes no CONNECT tunnel and relays no bytes.

## Required next: semantically equivalent CONNECT tunnel benchmark

The first publishable Oreslang-vs-nginx/HAProxy forward-proxy comparison must wait until Oreslang can complete the same network operation. The gate is:

1. all candidates receive the same canonical `CONNECT target:443 HTTP/1.1` request;
2. all candidates authenticate/admit the same target policy;
3. all candidates establish a connection to the same loopback-only target;
4. a successful CONNECT returns the same success semantics and relays bytes in both directions;
5. half-close, cancellation, idle timeout and hard-close behavior pass before timing;
6. forbidden targets, mismatched Host/authority and unsafe addresses fail before a socket is opened.

Once that exists, benchmark at least:

- CONNECT establish + close;
- 64 KiB and 1 MiB bidirectional relay;
- slow reader and slow writer;
- concurrency 1/16/64/256/1024;
- p50/p95/p99/p99.9 establishment and relay latency;
- tunnels/s, bytes/s, CPU, RSS, allocations/GC where applicable;
- cancellation/half-close resource-retirement latency.

Use nginx 1.31.8 and HAProxy 3.4.7 as pinned comparison candidates only after each configuration passes the same byte-relay and denial preflights. A parser-only, reject-only or plain TCP passthrough setup is not a valid substitute for equivalent HTTP CONNECT behavior.

## Benchmark hygiene

Use an isolated trusted runner and loopback-only targets. Do not expose the benchmark proxy to an external interface. Do not accept arbitrary commands, target hosts or images as workflow inputs. Pin candidate versions, capture image digests and exact Git/runtime hashes, rotate candidate order, separate load-generator and server CPUs when possible, and retain raw samples.

No relative-performance claim should be published from a single noisy run. Functional equivalence and security denial tests are merge gates that precede performance measurements.
