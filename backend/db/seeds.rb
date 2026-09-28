# Idempotent: rates are upserted, existing users are kept, and employees are skipped if any exist.
# SEED_RESET=1 replaces all employees with the deterministic 10,000-row dataset.
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = DemoSeed.new(reset: ENV["SEED_RESET"] == "1").call
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

puts "Seeded #{result[:exchange_rates]} exchange rates, #{result[:users]} users, " \
  "employees: #{result[:employees]} (#{elapsed.round(2)}s)"
