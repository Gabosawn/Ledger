defmodule Estructuras.Argumentos do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ledger

  @moduledoc """
  Módulo para gestionar y validar los argumentos de entrada para las operaciones del sistema Ledger.

  Este módulo proporciona funcionalidades para validar y procesar argumentos de línea de comandos
  para dos tipos de operaciones principales:

  - **Balance**: Consulta el balance de una cuenta específica
  - **Transacciones**: Gestiona y procesa transacciones entre cuentas

  ## Flags disponibles

  - `-t`: Archivo de entrada (transacciones)
  - `-c1`: Cuenta origen
  - `-c2`: Cuenta destino
  - `-m`: Moneda
  - `-o`: Archivo de salida

  ## Esquema de datos

  El módulo define un esquema Ecto con los siguientes campos:
  - `archivo_input`: Ruta del archivo de entrada
  - `cuenta_origen`: Identificador de la cuenta origen
  - `cuenta_destino`: Identificador de la cuenta destino
  - `moneda`: Código de moneda (3-4 letras mayúsculas)
  - `archivo_output`: Ruta del archivo de salida

  ## Ejemplos

      # Validar operación de balance
      Estructuras.Argumentos.changeset(:balance, %{cuenta_origen: "123", moneda: "USD"})

      # Validar operación de transacciones
      Estructuras.Argumentos.changeset(:transacciones, %{cuenta_origen: "123", cuenta_destino: "456"})
  """

  @headers %{archivo_input: "-t", cuenta_origen: "-c1", cuenta_destino: "-c2", moneda: "-m", archivo_output: "-o"}

  schema "argumentos" do
    field :archivo_input, :string
    field :cuenta_origen, :string
    field :cuenta_destino, :string
    field :moneda, :string
    field :archivo_output, :string
  end

  @doc """
  Retorna un mapa con los headers (flags) disponibles y las operaciones soportadas.

  ## Retorna

  Un mapa con dos claves:
  - `:flags` - Mapa con los nombres de los flags y sus identificadores
  - `:operaciones` - Lista de operaciones disponibles ("transacciones", "balance")

  ## Ejemplos

      iex> Estructuras.Argumentos.getHeaders()
      %{
        flags: %{
          archivo_input: "-t",
          cuenta_origen: "-c1",
          cuenta_destino: "-c2",
          moneda: "-m",
          archivo_output: "-o"
        },
        operaciones: ["transacciones", "balance"]
      }
  """
  def getHeaders do
    Map.merge(%{flags: @headers}, %{operaciones: ["transacciones", "balance"]})
  end

  @doc """
  Valida y procesa los parámetros según el tipo de operación especificada.

  Esta función actúa como punto de entrada para validar argumentos de diferentes
  tipos de operaciones. Crea un changeset con los parámetros proporcionados y
  ejecuta las validaciones específicas según el tipo de operación.

  ## Parámetros

  - `typeOperation` - Átomo que indica el tipo de operación:
    - `:balance` - Para operaciones de consulta de balance
    - `:transacciones` - Para operaciones de gestión de transacciones
  - `params` - Mapa con los parámetros a validar. Puede incluir:
    - `:archivo_input` - Ruta del archivo de entrada
    - `:cuenta_origen` - Identificador de la cuenta origen
    - `:cuenta_destino` - Identificador de la cuenta destino
    - `:moneda` - Código de moneda
    - `:archivo_output` - Ruta del archivo de salida

  ## Retorna

  - `{:ok, String.t()}` - Si la operación fue exitosa
  - `{:error, Keyword.t()}` - Si hubo errores de validación, con la clave siendo el tipo
    de operación y el valor el mensaje de error

  ## Ejemplos

      # Operación de balance exitosa
      iex> Estructuras.Argumentos.changeset(:balance, %{cuenta_origen: "123", moneda: "USD"})
      {:ok, "Operación realizada con exito"}

      # Operación de balance sin cuenta origen
      iex> Estructuras.Argumentos.changeset(:balance, %{moneda: "USD"})
      {:error, [balance: "EL flag -c1 es obligatorio"]}

      # Operación de transacciones
      iex> Estructuras.Argumentos.changeset(:transacciones, %{cuenta_origen: "123", cuenta_destino: "456"})
      {:ok, "Operación realizada con exito"}
  """
   def changeset(typeOperation, params) do
    changeset = cast(%Estructuras.Argumentos{}, params, Map.keys(@headers))

    {state, res} = case typeOperation do
      :balance -> balance(changeset)
      :transacciones -> transacciones(changeset)
    end

    case state do
      :ok -> {:ok, "Operación realizada con exito"}
      :error ->
        {_, message} = res.errors |> Enum.at(Enum.count(res.errors) - 1)
        message = elem(message, 0)
        {:error, Keyword.new([{typeOperation, message}])}
    end
  end

  # Valida que el campo cuenta_destino no esté presente en operaciones de balance.
  #
  # Esta es una validación privada que asegura que en operaciones de balance no se utilice
  # el flag `-c2` (cuenta destino), ya que no es necesario para consultar un balance.
  # Una operación de balance solo requiere conocer la cuenta origen y opcionalmente la moneda.
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset de Ecto que contiene los datos a validar
  #
  # ## Retorna
  #
  # - `Ecto.Changeset.t()` - El changeset sin modificar si cuenta_destino es nil,
  #   o con un error agregado si cuenta_destino tiene un valor
  #
  # ## Ejemplos
  #
  #     # Sin cuenta destino - válido para balance
  #     iex> changeset = cast(%Estructuras.Argumentos{}, %{cuenta_origen: "123"}, [:cuenta_origen, :cuenta_destino])
  #     iex> validate_cuenta_destino_no_permitida(changeset)
  #     #Ecto.Changeset<valid?: true>
  #
  #     # Con cuenta destino - inválido para balance
  #     iex> changeset = cast(%Estructuras.Argumentos{}, %{cuenta_origen: "123", cuenta_destino: "456"}, [:cuenta_origen, :cuenta_destino])
  #     iex> validate_cuenta_destino_no_permitida(changeset)
  #     #Ecto.Changeset<valid?: false, errors: [cuenta_destino: {"En la operacion de balance el flag -c2 no esta permitido", []}]>
  defp validate_cuenta_destino_no_permitida(changeset) do
    case get_change(changeset, :cuenta_destino) do
      nil -> changeset
      _valor -> add_error(changeset, :cuenta_destino, "En la operacion de balance el flag -c2 no esta permitido")
    end
  end

  @doc """
  Procesa y valida los parámetros específicos para una operación de balance.

  Esta función aplica las validaciones necesarias para garantizar que una operación
  de balance tenga todos los parámetros requeridos y en el formato correcto.

  ## Validaciones aplicadas

  - **Cuenta origen obligatoria**: El flag `-c1` debe estar presente
  - **Longitud de moneda**: Si se proporciona, debe tener entre 3 y 4 caracteres
  - **Formato de moneda**: Debe estar completamente en mayúsculas (ej: USD, EUR, USDT)
  - **Cuenta destino no permitida**: El flag `-c2` no debe estar presente

  ## Parámetros

  - `changeset` - Changeset de Ecto con los parámetros de la operación

  ## Retorna

  - `{:ok, any()}` - Si las validaciones son exitosas y la operación se inicia correctamente
  - `{:error, Ecto.Changeset.t()}` - Si hay errores de validación, con detalles de los errores

  ## Ejemplos

      # Operación válida con moneda
      iex> changeset = cast(%Estructuras.Argumentos{}, %{cuenta_origen: "123", moneda: "USD"}, [:cuenta_origen, :moneda])
      iex> balance(changeset)
      {:ok, _resultado}

      # Operación inválida - sin cuenta origen
      iex> changeset = cast(%Estructuras.Argumentos{}, %{}, [:cuenta_origen])
      iex> balance(changeset)
      {:error, %Ecto.Changeset{errors: [cuenta_origen: {"EL flag -c1 es obligatorio", _}]}}

      # Operación inválida - moneda en minúsculas
      iex> changeset = cast(%Estructuras.Argumentos{}, %{cuenta_origen: "123", moneda: "usd"}, [:cuenta_origen, :moneda])
      iex> balance(changeset)
      {:error, %Ecto.Changeset{errors: [moneda: {"El nombre de la moneda debe estar completamente en mayúsculas", _}]}}
  """
  def balance(changeset) do
    changeset = validate_required(changeset, [:cuenta_origen], message: "EL flag " <> @headers.cuenta_origen <> " es obligatorio")
    |> validate_length(:moneda, min: 3, max: 4, message: "El nombre de la moneda debe ser de 3 o 4 letras")
    |> validate_format(:moneda, ~r/^[A-Z]+$/, message: "El nombre de la moneda debe estar completamente en mayúsculas")
    |> validate_cuenta_destino_no_permitida()


    cond do
      changeset.valid? == true -> Estructuras.Balance.initOperation(changeset)
      changeset.valid? == false -> {:error, changeset}
    end

  end

  # Procesa los parámetros para una operación de transacciones.
  #
  # Esta función privada delega la validación y procesamiento de transacciones
  # al módulo `Estructuras.Transaccion`, que contiene la lógica específica para
  # validar y ejecutar operaciones de transferencia entre cuentas.
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset de Ecto con los parámetros de la operación de transacción
  #
  # ## Retorna
  #
  # - El resultado de `Estructuras.Transaccion.initOperation/1`, que puede ser:
  #   - `{:ok, resultado}` si la operación fue exitosa
  #   - `{:error, changeset}` si hubo errores de validación
  defp transacciones(changeset) do
    Estructuras.Transaccion.initOperation(changeset)
  end
end
