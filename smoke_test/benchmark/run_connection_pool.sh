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

bundle exec sidekiq -r ./benchmark/connection_pool_server.rb -q benchmark \
  -c "${BENCHMARK_CONCURRENCY:-4}" >"$server_log" 2>&1 &
server_pid=$!

printf '\nCPU cores visible to the benchmark: '
nproc 2>/dev/null || getconf _NPROCESSORS_ONLN
printf 'Sidekiq server PID: %s\n' "$server_pid"

bundle exec ruby ./benchmark/client.rb >"$client_log" 2>&1 &
client_pid=$!

while kill -0 "$client_pid" 2>/dev/null; do
  printf '\n[%s] Sidekiq process/thread snapshot\n' "$(date '+%H:%M:%S')"
  ps -L -o pid,tid,psr,pcpu,nlwp,stat,comm -p "$server_pid" 2>/dev/null || \
    ps -o pid,psr,pcpu,nlwp,stat,comm -p "$server_pid"
  sleep 1
done

if ! wait "$client_pid"; then
  cat "$client_log"
  printf '\nSidekiq server log:\n'
  cat "$server_log"
  exit 1
fi

cat "$client_log"
