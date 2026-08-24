#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_dir="$(cd "$script_dir/.." && pwd)"
cd "$smoke_dir"

server_count="${SIDEKIQ_SERVER_COUNT:-4}"
server_concurrency="${BENCHMARK_CONCURRENCY:-20}"
pool_size="${RATOMIC_POOL_SIZE:-20}"
server_pids=()
server_logs=()
client_log="$(mktemp -t sidekiq-ratomic-pool-four-servers-client.XXXXXX.log)"
cleanup() {
  for server_pid in "${server_pids[@]}"; do
    kill "$server_pid" 2>/dev/null || true
  done
  for server_pid in "${server_pids[@]}"; do
    wait "$server_pid" 2>/dev/null || true
  done
  if [[ "${KEEP_REDIS:-0}" != '1' ]]; then
    docker compose down --remove-orphans >/dev/null
  fi
  for server_log in "${server_logs[@]}"; do
    rm -f "$server_log"
  done
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

for server_index in $(seq 1 "$server_count"); do
  server_log="$(mktemp -t sidekiq-ratomic-pool-server-${server_index}.XXXXXX.log)"
  server_logs+=("$server_log")
  RATOMIC_POOL_SIZE="$pool_size" bundle exec sidekiq -r ./benchmark/server.rb -q benchmark \
    -c "$server_concurrency" >"$server_log" 2>&1 &
  server_pids+=("$!")
done

sleep 1

printf '\nCPU cores visible to the benchmark: '
nproc 2>/dev/null || getconf _NPROCESSORS_ONLN
printf 'Sidekiq servers: %s, concurrency per server: %s, pool size per server: %s\n' \
  "$server_count" "$server_concurrency" "$pool_size"
printf 'Total worker threads: %s, total pool capacity: %s\n' \
  "$((server_count * server_concurrency))" "$((server_count * pool_size))"

bundle exec ruby ./benchmark/client.rb >"$client_log" 2>&1 &
client_pid=$!

while kill -0 "$client_pid" 2>/dev/null; do
  printf '\n[%s] Sidekiq process/thread snapshots\n' "$(date '+%H:%M:%S')"
  for server_pid in "${server_pids[@]}"; do
    ps -L -o pid,tid,psr,pcpu,nlwp,stat,comm -p "$server_pid" 2>/dev/null || \
      ps -o pid,psr,pcpu,nlwp,stat,comm -p "$server_pid"
  done
  sleep 1
done

if ! wait "$client_pid"; then
  cat "$client_log"
  for server_log in "${server_logs[@]}"; do
    printf '\nSidekiq server log: %s\n' "$server_log"
    cat "$server_log"
  done
  exit 1
fi

cat "$client_log"
