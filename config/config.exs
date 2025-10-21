import Config

config :ledger, ecto_repos: [Ledger.Repo]

config :ledger, Ledger.Repo,
  database: "ledger_repo",
  username: "gabosawn",
  password: "140703",
  hostname: "localhost"

# Importar la configuración específica del entorno
import_config "#{config_env()}.exs"
