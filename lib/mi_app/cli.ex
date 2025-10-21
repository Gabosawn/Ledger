defmodule MiApp.CLI do
  @moduledoc """
  Módulo de interfaz de línea de comandos (CLI) para la aplicación Ledger.

  Este módulo actúa como punto de entrada principal para la aplicación ejecutable
  (escript) y procesa los argumentos de línea de comandos recibidos.

  ## Propósito

  - Normalizar los argumentos recibidos desde la línea de comandos
  - Validar y procesar los argumentos usando el módulo Argumentos
  - Proporcionar una interfaz amigable para interactuar con el sistema Ledger

  ## Proceso de ejecución

  1. Recibe argumentos desde la línea de comandos
  2. Normaliza los argumentos (maneja casos especiales como rutas de archivos)
  3. Valida y ejecuta la operación correspondiente
  4. Muestra el resultado en pantalla

  ## Normalización de argumentos

  La normalización es necesaria porque algunos argumentos pueden contener puntos
  (como rutas de archivos: "data/file.csv") que podrían ser divididos incorrectamente
  por el shell. Este módulo agrupa esos segmentos nuevamente.

  ## Ejemplos de uso

      # Desde línea de comandos (balance)
      ./ledger balance -c1 cuenta_123 -m USD

      # Desde línea de comandos (transacciones)
      ./ledger transacciones -t data/transacciones.csv -c1 user1 -c2 user2

      # Desde código Elixir
      iex> MiApp.CLI.main(["balance", "-c1", "cuenta_123", "-m", "USD"])
  """

  alias Argumentos

  @doc """
  Función principal del CLI que procesa los argumentos de línea de comandos.

  Esta es la función de entrada cuando se ejecuta el escript. Recibe los argumentos,
  los normaliza para manejar casos especiales (como rutas con puntos), valida su
  formato y ejecuta la operación correspondiente.

  ## Parámetros

  - `args` - Lista de strings con los argumentos de línea de comandos.
    Típicamente en el formato: `[operación, flag1, valor1, flag2, valor2, ...]`

  ## Retorna

  El resultado de `Argumentos.validationArgs/1`, que puede ser:
  - `{:ok, mensaje}` - Si la operación fue exitosa
  - `{:error, mensaje}` - Si hubo errores de validación o ejecución

  ## Ejemplos

      # Consultar balance
      iex> MiApp.CLI.main(["balance", "-c1", "cuenta_123", "-m", "USD"])
      {:ok, "Operación realizada con exito"}

      # Listar transacciones desde archivo
      iex> MiApp.CLI.main(["transacciones", "-t", "data/file.csv", "-c1", "user1"])
      {:ok, "Operación realizada con exito"}

      # Operación inválida
      iex> MiApp.CLI.main(["operacion_invalida"])
      {:error, "Operación no válida"}

      # Argumentos con archivo que contiene punto (se normalizan correctamente)
      iex> MiApp.CLI.main(["balance", "-t", "data/transacciones", "csv"])
      # Los argumentos se normalizan a: ["balance", "-t", "data/transacciones.csv"]
  """
  def main(args) do
    args
    |> normalize_args()
    |> Argumentos.validationArgs()
    |> IO.inspect()
  end

  # Normaliza los argumentos de línea de comandos agrupando segmentos separados.
  #
  # Algunos valores de argumentos pueden contener puntos (como rutas de archivos:
  # "data/file.csv") que el shell podría dividir en múltiples elementos. Esta función
  # detecta esos casos y reagrupa los segmentos en un solo argumento.
  #
  # ## Proceso
  #
  # - Recorre los argumentos en orden inverso (usando reduce)
  # - Si un argumento contiene un punto, lo concatena con el argumento anterior
  # - Si no contiene punto, lo agrega normalmente a la lista
  # - Revierte la lista al final para mantener el orden original
  #
  # ## Parámetros
  #
  # - `args` - Lista de strings con los argumentos posiblemente fragmentados
  #
  # ## Retorna
  #
  # Lista de strings con los argumentos normalizados
  #
  # ## Ejemplos
  #
  #     # Ruta de archivo fragmentada
  #     normalize_args(["balance", "-t", "data/file", "csv"])
  #     #=> ["balance", "-t", "data/file.csv"]
  #
  #     # Argumentos sin puntos (sin cambios)
  #     normalize_args(["balance", "-c1", "cuenta_123", "-m", "USD"])
  #     #=> ["balance", "-c1", "cuenta_123", "-m", "USD"]
  #
  #     # Múltiples argumentos con puntos
  #     normalize_args(["-t", "input", "csv", "-o", "output", "txt"])
  #     #=> ["-t", "input.csv", "-o", "output.txt"]
  defp normalize_args(args) do
    args
    |> Enum.reduce([] ,fn arg, acc ->
      if (String.contains?(arg, ".")) do
        [hd | tl] = acc
        hd = hd <> arg
        [hd | tl]
      else
        [arg | acc]
      end
    end) |> Enum.reverse()
  end
end
