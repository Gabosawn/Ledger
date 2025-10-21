import Config

# Configuración para el entorno de desarrollo
config :ledger, Ledger.Repo,
  database: "ledger_repo",
  username: "gabosawn",
  password: "140703",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  log: false

# Configurar el logger para desarrollo
config :logger, level: :debug
