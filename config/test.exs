import Config

# Configuración para el entorno de pruebas
config :ledger, Ledger.Repo,
  database: "ledger_repo_test",
  username: "gabosawn",
  password: "140703",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  log: false  # Deshabilitar logs SQL durante las pruebas

# Reducir el nivel de log durante las pruebas
config :logger, level: :warning
