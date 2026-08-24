#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_dir="$(cd "$script_dir/.." && pwd)"
cd "$smoke_dir"

benchmark_log="$(mktemp -t sidekiq-ratomic-pool-ractor-benchmark.XXXXXX.log)"
benchmark_pid=''
cleanup() {
  if [[ -n "${benchmark_pid:-}" ]]; then
    kill "$benchmark_pid" 2>/dev/null || true
    wait "$benchmark_pid" 2>/dev/null || true
  fi
  if [[ "${KEEP_REDIS:-0}" != '1' ]]; then
    docker compose down --remove-orphans >/dev/null
  fi
  rm -f "$benchmark_log"
}
trap cleanup EXIT INT TERM

export REDIS_PORT="${REDIS_PORT:-6380}"
export REDIS_URL="${REDIS_URL:-redis://127.0.0.1:${REDIS_PORT}/0}"
export RACTOR_NATIVE_COUNT="${RACTOR_NATIVE_COUNT:-4}"
export RACTOR_NATIVE_THREADS="${RACTOR_NATIVE_THREADS:-20}"
export RATOMIC_POOL_SIZE="${RATOMIC_POOL_SIZE:-20}"
export RATOMIC_POOL_TIMEOUT="${RATOMIC_POOL_TIMEOUT:-1}"
export BENCHMARK_WORK_SECONDS="${BENCHMARK_WORK_SECONDS:-0.05}"
export BENCHMARK_JOB_COUNT="${BENCHMARK_JOB_COUNT:-$((RACTOR_NATIVE_COUNT * RACTOR_NATIVE_THREADS))}"
export BENCHMARK_RUN_ID="${BENCHMARK_RUN_ID:-$(date +%s%N)}"

bundle check >/dev/null 2>&1 || bundle install
docker compose up -d redis

redis_ready=''
for _attempt in $(seq 1 30); do
  if docker compose exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
    redis_ready='yes'
    break
  fi
  sleep 1
done
if [[ "$redis_ready" != 'yes' ]]; then
  docker compose logs --no-color redis
  exit 1
fi
redis_version="$(docker compose exec -T redis redis-cli INFO server |
  awk -F: '$1 == "redis_version" { gsub("\\r", "", $2); print $2; exit }')"

bundle exec ruby ./benchmark/ractor_native.rb >"$benchmark_log" 2>&1 &
benchmark_pid=$!

printf '\nCPU cores visible to the benchmark: '
nproc 2>/dev/null || getconf _NPROCESSORS_ONLN
printf 'Ruby: '; ruby -v
bundle exec ruby -e 'require "sidekiq"; require "ratomic"; puts "Sidekiq: #{Sidekiq::VERSION}"; puts "Ratomic: #{Ratomic::VERSION}"'
printf 'Redis: %s\n' "$redis_version"
printf 'Ractor benchmark PID: %s\n' "$benchmark_pid"
printf 'Run ID: %s\n' "$BENCHMARK_RUN_ID"
printf 'Ractors: %s, threads per Ractor: %s, pool size per Ractor: %s, checkout timeout: %ss\n' \
  "$RACTOR_NATIVE_COUNT" "$RACTOR_NATIVE_THREADS" "$RATOMIC_POOL_SIZE" "$RATOMIC_POOL_TIMEOUT"
printf 'Jobs: %s, work per job: %ss\n' "$BENCHMARK_JOB_COUNT" "$BENCHMARK_WORK_SECONDS"

while kill -0 "$benchmark_pid" 2>/dev/null; do
  printf '\n[%s] Ractor benchmark process/thread snapshot\n' "$(date '+%H:%M:%S')"
  ps -L -o pid,tid,psr,pcpu,nlwp,stat,comm -p "$benchmark_pid" 2>/dev/null || \
    ps -o pid,psr,pcpu,nlwp,stat,comm -p "$benchmark_pid" 2>/dev/null || true
  sleep 1
done

if ! wait "$benchmark_pid"; then
  cat "$benchmark_log"
  exit 1
fi

cat "$benchmark_log"
