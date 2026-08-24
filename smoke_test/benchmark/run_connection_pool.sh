#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_dir="$(cd "$script_dir/.." && pwd)"
cd "$smoke_dir"

server_log="$(mktemp -t sidekiq-ratomic-pool-connection-pool.XXXXXX.log)"
client_log="$(mktemp -t sidekiq-ratomic-pool-connection-pool-client.XXXXXX.log)"
server_pid=''
cleanup() {
  if [[ -n "${server_pid:-}" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ "${KEEP_REDIS:-0}" != '1' ]]; then
    docker compose down --remove-orphans >/dev/null
  fi
  rm -f "$server_log"
  rm -f "$client_log"
}
trap cleanup EXIT INT TERM

export REDIS_PORT="${REDIS_PORT:-6380}"
export REDIS_URL="${REDIS_URL:-redis://127.0.0.1:${REDIS_PORT}/0}"
export BENCHMARK_CONCURRENCY="${BENCHMARK_CONCURRENCY:-4}"
export RATOMIC_POOL_SIZE="${RATOMIC_POOL_SIZE:-4}"
export RATOMIC_POOL_TIMEOUT="${RATOMIC_POOL_TIMEOUT:-${CONNECTION_POOL_TIMEOUT:-1}}"
export BENCHMARK_WORK_SECONDS="${BENCHMARK_WORK_SECONDS:-0.05}"
export BENCHMARK_JOB_COUNT="${BENCHMARK_JOB_COUNT:-100}"
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

bundle exec sidekiq -r ./benchmark/connection_pool_server.rb -q benchmark \
  -c "$BENCHMARK_CONCURRENCY" >"$server_log" 2>&1 &
server_pid=$!

printf '\nCPU cores visible to the benchmark: '
nproc 2>/dev/null || getconf _NPROCESSORS_ONLN
printf 'Ruby: '; ruby -v
bundle exec ruby -e 'require "sidekiq"; require "ratomic"; require "connection_pool"; puts "Sidekiq: #{Sidekiq::VERSION}"; puts "Ratomic: #{Ratomic::VERSION}"; puts "connection_pool: #{Gem.loaded_specs.fetch("connection_pool").version}"'
printf 'Redis: %s\n' "$redis_version"
printf 'Sidekiq server PID: %s\n' "$server_pid"
printf 'Pool implementation: connection_pool\n'
printf 'Sidekiq concurrency: %s, pool size: %s, checkout timeout: %ss\n' \
  "$BENCHMARK_CONCURRENCY" "$RATOMIC_POOL_SIZE" "$RATOMIC_POOL_TIMEOUT"
printf 'Jobs: %s, work per job: %ss\n' "$BENCHMARK_JOB_COUNT" "$BENCHMARK_WORK_SECONDS"
printf 'Run ID: %s\n' "$BENCHMARK_RUN_ID"

bundle exec ruby ./benchmark/client.rb >"$client_log" 2>&1 &
client_pid=$!

while kill -0 "$client_pid" 2>/dev/null; do
  printf '\n[%s] Sidekiq process/thread snapshot\n' "$(date '+%H:%M:%S')"
  ps -L -o pid,tid,psr,pcpu,nlwp,stat,comm -p "$server_pid" 2>/dev/null || \
    ps -o pid,psr,pcpu,nlwp,stat,comm -p "$server_pid" 2>/dev/null || true
  sleep 1
done

if ! wait "$client_pid"; then
  cat "$client_log"
  printf '\nSidekiq server log:\n'
  cat "$server_log"
  exit 1
fi

cat "$client_log"
