defmodule Ledger.Transaccion do
  @moduledoc """
  Módulo de esquema y operaciones para transacciones en el sistema Ledger.

  Este módulo gestiona todas las operaciones relacionadas con transacciones financieras
  en el sistema, incluyendo altas de cuenta, transferencias entre usuarios y swaps de monedas.

  ## Esquema de base de datos

  La tabla `transacciones` contiene:
  - `id` - Identificador único autogenerado
  - `tipo` - Tipo de transacción: "alta_cuenta", "transferencia" o "swap"
  - `monto` - Cantidad de la transacción (Decimal)
  - `moneda_origen_id` - ID de la moneda de origen (foreign key a monedas)
  - `moneda_destino_id` - ID de la moneda de destino (para swaps, foreign key a monedas)
  - `cuenta_origen_id` - ID de la cuenta/usuario origen (foreign key a usuarios)
  - `cuenta_destino_id` - ID de la cuenta/usuario destino (para transferencias, foreign key a usuarios)
  - `inserted_at` - Timestamp de creación
  - `updated_at` - Timestamp de última actualización

  ## Tipos de transacciones

  ### Alta de cuenta
  - Crea el primer registro de una moneda en una cuenta de usuario
  - Flags requeridos: `-u` (usuario), `-m` (moneda)
  - Monto opcional (default: 0)
  - No puede repetirse para la misma combinación usuario-moneda

  ### Transferencia
  - Transfiere fondos de una cuenta a otra en la misma moneda
  - Flags requeridos: `-o` (origen), `-d` (destino), `-m` (moneda), `-a` (monto)
  - Valida fondos suficientes en cuenta origen
  - Crea alta automática en destino si no existe

  ### Swap
  - Intercambia una moneda por otra dentro de la misma cuenta
  - Flags requeridos: `-u` (usuario), `-mo` (moneda origen), `-md` (moneda destino), `-a` (monto)
  - Valida fondos suficientes
  - Crea alta automática de moneda destino si no existe

  ## Operaciones disponibles

  - **alta_cuenta**: Registrar una nueva moneda en una cuenta
  - **realizar_transferencia**: Transferir fondos entre cuentas
  - **realizar_swap**: Intercambiar monedas dentro de una cuenta
  - **deshacer_transaccion**: Revertir la última transacción
  - **ver_transaccion**: Consultar detalles de una transacción

  ## Validaciones importantes

  - No se pueden deshacer transacciones que no sean las últimas
  - Se valida que haya fondos suficientes antes de transferencias/swaps
  - Se crean altas automáticas cuando es necesario
  - Las monedas origen y destino deben ser diferentes en swaps
  - Las cuentas origen y destino deben ser diferentes en transferencias

  ## Ejemplos

      # Alta de cuenta
      Ledger.Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: 1, moneda_origen_id: 1, monto: 1000})

      # Transferencia
      Ledger.Transaccion.changeset(:realizar_transferencia,
        %{cuenta_origen_id: 1, cuenta_destino_id: 2, moneda_origen_id: 1, monto: 100})

      # Swap
      Ledger.Transaccion.changeset(:realizar_swap,
        %{cuenta_origen_id: 1, moneda_origen_id: 1, moneda_destino_id: 2, monto: 50})
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ledger.Repo, as: Repo

  @headers %{id: "-id", moneda_origen_id: ["-mo", "-m"], moneda_destino_id: "-md", monto: "-a", cuenta_origen_id: ["-o", "-u"], cuenta_destino_id: "-d"}
  @errores [id: "El id debe ser un número entero",
            moneda_origen_id: "La moneda o moneda de origen debe ser un número entero",
            moneda_destino_id: "La moneda de destino debe ser un número entero",
            cuenta_origen_id: "El usuario o cuenta de origen debe ser un número entero",
            cuenta_destino_id: "La cuenta de destino debe ser un número entero",
            monto: "El monto debe ser un numero decimal"]

  @alta ["-u", "-m"]
  @transferencia ["-o", "-d", "-m"]
  @swap ["-mo", "-md", "-u"]

  schema "transacciones" do
    field :tipo, :string
    field :monto, :decimal
    belongs_to :moneda_origen, Ledger.Moneda, foreign_key: :moneda_origen_id
    belongs_to :cuenta_origen, Ledger.Usuario, foreign_key: :cuenta_origen_id
    belongs_to :cuenta_destino, Ledger.Usuario, foreign_key: :cuenta_destino_id
    belongs_to :moneda_destino, Ledger.Moneda, foreign_key: :moneda_destino_id
    timestamps()
  end

  @doc """
  Retorna los headers (flags) y operaciones disponibles para el módulo de transacciones.

  ## Retorna

  Un mapa con dos claves:
  - `:flags` - Mapa con los flags disponibles y sus identificadores (algunos tienen alias)
  - `:operaciones` - Lista de operaciones soportadas

  ## Ejemplos

      iex> Ledger.Transaccion.getHeaders()
      %{
        flags: %{
          id: "-id",
          moneda_origen_id: ["-mo", "-m"],
          moneda_destino_id: "-md",
          monto: "-a",
          cuenta_origen_id: ["-o", "-u"],
          cuenta_destino_id: "-d"
        },
        operaciones: ["alta_cuenta", "realizar_swap", "realizar_transferencia",
                      "deshacer_transaccion", "ver_transaccion"]
      }
  """
  def getHeaders do
    Map.merge(%{flags: @headers}, %{operaciones: ["alta_cuenta", "realizar_swap", "realizar_transferencia", "deshacer_transaccion", "ver_transaccion"]})
  end

  @doc """
  Retorna los flags requeridos para un tipo específico de operación.

  ## Parámetros

  - `typeOperation` - String con el tipo de operación: "alta_cuenta", "realizar_swap"
    o "realizar_transferencia"

  ## Retorna

  Lista de strings con los flags requeridos para esa operación

  ## Ejemplos

      iex> Ledger.Transaccion.flagsBy("alta_cuenta")
      ["-u", "-m"]

      iex> Ledger.Transaccion.flagsBy("realizar_swap")
      ["-mo", "-md", "-u"]

      iex> Ledger.Transaccion.flagsBy("realizar_transferencia")
      ["-o", "-d", "-m"]
  """
  def flagsBy(typeOperation) do
    case typeOperation do
      "alta_cuenta" -> @alta
      "realizar_swap" -> @swap
      "realizar_transferencia" -> @transferencia
    end
  end

  @doc """
  Valida y ejecuta una operación de transacción.

  Esta función actúa como punto de entrada para todas las operaciones de transacciones.
  Crea un changeset con los parámetros proporcionados y ejecuta la operación
  correspondiente aplicando las validaciones necesarias.

  ## Parámetros

  - `typeOperation` - Átomo que indica la operación a realizar:
    - `:alta_cuenta` - Dar de alta una moneda en una cuenta
    - `:realizar_swap` - Intercambiar monedas
    - `:realizar_transferencia` - Transferir fondos entre cuentas
    - `:deshacer_transaccion` - Revertir última transacción
    - `:ver_transaccion` - Consultar detalles de transacción
  - `params` - Mapa con los parámetros necesarios según la operación

  ## Retorna

  - `{:ok, String.t()}` - Si la operación fue exitosa
  - `{:error, Keyword.t()}` - Si hubo errores, con el tipo de operación y mensaje

  ## Ejemplos

      # Alta exitosa
      iex> Ledger.Transaccion.changeset(:alta_cuenta,
      ...>   %{cuenta_origen_id: 1, moneda_origen_id: 1, monto: 1000})
      {:ok, "Operación realizada con exito"}

      # Error: alta duplicada
      iex> Ledger.Transaccion.changeset(:alta_cuenta,
      ...>   %{cuenta_origen_id: 1, moneda_origen_id: 1})
      {:error, [alta_cuenta: "Ya se ha hecho un alta de esta moneda"]}

      # Transferencia exitosa
      iex> Ledger.Transaccion.changeset(:realizar_transferencia,
      ...>   %{cuenta_origen_id: 1, cuenta_destino_id: 2, moneda_origen_id: 1, monto: 100})
      {:ok, "Operación realizada con exito"}

      # Error: fondos insuficientes
      iex> Ledger.Transaccion.changeset(:realizar_swap,
      ...>   %{cuenta_origen_id: 1, moneda_origen_id: 1, moneda_destino_id: 2, monto: 999999})
      {:error, [realizar_swap: "No tienes fondos suficientes para hacer esta transacción"]}
  """
  def changeset(typeOperation, params) do
    message_by_error = fn field, _meta -> @errores[field] end
    changeset = cast(%Ledger.Transaccion{}, params, Map.keys(@headers), message: message_by_error)

    {state, res} = case typeOperation do
      :alta_cuenta -> alta(changeset)
      :realizar_swap -> swap(changeset)
      :realizar_transferencia -> transferencia(changeset)
      :deshacer_transaccion -> deshacer(changeset)
      :ver_transaccion -> ver(changeset)
    end

    case state do
      :ok -> {:ok, "Operación realizada con exito"}
      :error ->
        {_, message} = res.errors |> Enum.at(Enum.count(res.errors) - 1)
        message = elem(message, 0)
        {:error, Keyword.new([{typeOperation, message}])}
    end
  end

  @doc """
  Verifica y asigna un valor de monto al changeset.

  Si el monto no está especificado en el changeset, lo establece en 0.
  Esto es útil para operaciones de alta de cuenta donde el monto es opcional.

  ## Parámetros

  - `changeset` - Changeset de Ecto a verificar y modificar

  ## Retorna

  Changeset con el campo `:monto` establecido (0 si era nil, valor original en caso contrario)

  ## Ejemplos

      iex> changeset = cast(%Ledger.Transaccion{}, %{}, [:monto])
      iex> verificar_monto(changeset)
      #Ecto.Changeset<changes: %{monto: 0}>

      iex> changeset = cast(%Ledger.Transaccion{}, %{monto: 100}, [:monto])
      iex> verificar_monto(changeset)
      #Ecto.Changeset<changes: %{monto: 100}>
  """
  def verificar_monto(changeset) do
    case get_field(changeset, :monto) do
      nil -> put_change(changeset, :monto, 0)
      _ -> changeset
    end
  end

  # Procesa y valida una operación de alta de cuenta.
  #
  # Registra la primera vez que una moneda es asociada a una cuenta de usuario.
  # El monto es opcional y por defecto es 0.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: moneda_origen_id, cuenta_origen_id
  # - Monto debe ser >= 0
  # - La cuenta debe existir (foreign key)
  # - La moneda debe existir (foreign key)
  # - No puede haber un alta previa de la misma moneda en la misma cuenta
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con los datos del alta
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Transaccion{}}` - Si se creó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación
  defp alta(changeset) do
    validate_required(changeset, [:moneda_origen_id, :cuenta_origen_id], message: "Los flags " <> Enum.join(@alta, ", ") <> " son obligatorios")
    |> put_change(:tipo, "alta_cuenta")
    |> verificar_monto()
    |> validate_number(:monto, greater_than_or_equal_to: 0, message: "El valor del monto debe ser un número positivo")
    |> foreign_key_constraint(:cuenta_origen_id, message: "Esta cuenta no esta dada de alta en la base de datos")
    |> foreign_key_constraint(:moneda_origen_id, message: "Esta moneda no esta dada de alta en la base de datos")
    |> validar_alta_cuenta(:moneda_origen_id, :cuenta_origen_id)
    |> Repo.insert()
  end

  # Valida que una foreign key exista en la tabla referenciada.
  #
  # Verifica que el ID proporcionado exista en la tabla correspondiente
  # (Usuario o Moneda). Si no existe, agrega un error al changeset.
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset a validar
  # - `foreing_key` - Átomo con el nombre del campo foreign key
  # - `struct` - Módulo de la estructura a validar (Ledger.Usuario o Ledger.Moneda)
  #
  # ## Retorna
  #
  # Changeset sin modificar si la FK es válida o nil, con error agregado si no existe
  defp validate_fk(changeset, foreing_key, struct) do
    valor = get_field(changeset, foreing_key)
    case valor do
      nil -> changeset
      _ ->
        exist = Repo.exists?((from u in struct, where: u.id == ^valor))
        case exist do
          true -> changeset
          false -> add_error(changeset, foreing_key, "Esta #{Enum.join(String.split(Atom.to_string(foreing_key), "_"), " ")} no esta dada de alta en la base de datos")
        end
    end
  end

  # Valida que una moneda esté dada de alta en una cuenta, o crea el alta si es necesario.
  #
  # Esta función compleja maneja múltiples escenarios según el tipo de transacción:
  #
  # Para alta_cuenta:
  # - Verifica que NO exista un alta previa (error si existe)
  #
  # Para swap:
  # - Moneda origen: debe existir un alta previa (error si no existe)
  # - Moneda destino: crea alta automáticamente si no existe
  #
  # Para transferencia:
  # - Cuenta origen: debe existir alta previa (error si no existe)
  # - Cuenta destino: crea alta automáticamente si no existe
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset a validar
  # - `moneda` - Átomo del campo de moneda (:moneda_origen_id o :moneda_destino_id)
  # - `cuenta` - Átomo del campo de cuenta (:cuenta_origen_id o :cuenta_destino_id)
  #
  # ## Retorna
  #
  # Changeset sin modificar si pasa validación, con error si falla
  defp validar_alta_cuenta(changeset, moneda, cuenta) do
    case changeset.valid? do
      true -> exist = Herramientas.query_dada_alta?(get_field(changeset, cuenta), get_field(changeset, moneda))
        case moneda do
          :moneda_origen_id ->
            case get_field(changeset, :tipo) do
              "alta_cuenta" when exist -> add_error(changeset, moneda, "Ya se ha hecho un alta de esta moneda")
              "swap" when not exist -> add_error(changeset, moneda, "Esta moneda no ha sido dada de alta en esta cuenta")
              "transferencia" when not exist ->
                case cuenta do
                  :cuenta_origen_id ->
                    add_error(changeset, moneda, "Esta moneda no ha sido dada de alta en esta cuenta")
                  :cuenta_destino_id ->
                    {status, _} = changeset(:alta_cuenta,
                    %{cuenta_origen_id: get_field(changeset, cuenta), moneda_origen_id: get_field(changeset, moneda)})
                    case status do
                      :ok -> changeset
                      :error -> add_error(changeset, moneda, "No se pudo dar de alta a la moneda #{get_field(changeset, :moneda_destino_id)} en la cuenta #{get_field(changeset, :cuenta_origen_id)}")
                    end
                end
              _ -> changeset
            end

          :moneda_destino_id ->
            case exist do
              true -> changeset
              false -> {status, _} = changeset(:alta_cuenta,
                %{cuenta_origen_id: get_field(changeset, cuenta), moneda_origen_id: get_field(changeset, moneda)})
                case status do
                  :ok -> changeset
                  :error -> add_error(changeset, moneda, "No se pudo dar de alta a la moneda #{get_field(changeset, :moneda_destino_id)} en la cuenta #{get_field(changeset, :cuenta_origen_id)}")
                end
            end
        end
      false -> changeset
    end
  end

  # Valida que una cuenta tenga fondos suficientes para realizar una transacción.
  #
  # Calcula el balance actual de la cuenta en la moneda especificada y verifica
  # que sea suficiente para cubrir el monto de la transacción (swap o transferencia).
  #
  # ## Proceso
  #
  # 1. Obtiene todas las transacciones históricas de la cuenta
  # 2. Calcula el balance actual usando Estructuras.Balance
  # 3. Compara el balance con el monto a transferir/intercambiar
  # 4. Agrega error si los fondos son insuficientes
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con moneda_origen_id, cuenta_origen_id y monto
  #
  # ## Retorna
  #
  # Changeset sin modificar si hay fondos suficientes, con error si son insuficientes
  defp validar_fondos_suficientes(changeset) do
    case changeset.valid? do
      true ->
        moneda = get_field(changeset, :moneda_origen_id)
        cuenta = get_field(changeset, :cuenta_origen_id)

        transacciones = Herramientas.query_transacciones_id(cuenta)

        monedas = Ledger.Moneda
        |> select([m], %Estructuras.Moneda{nombre_moneda: m.nombre, precio_usd: m.precio_dolar})
        |> Ledger.Repo.all()

        {_status, res} = Estructuras.Balance.balance_cuenta(transacciones, monedas, Repo.get(Ledger.Usuario, cuenta).username, nil)
        fondos_suficientes = Enum.filter(res, fn map ->
          nombre_moneda = Repo.get(Ledger.Moneda, moneda)
          map
          |> Map.from_struct()
          |> Map.get(:MONEDA) == nombre_moneda.nombre end)
        |> hd()
        |> Map.get(:BALANCE)
        |> Decimal.new()
        |> Decimal.compare(get_field(changeset, :monto))


        case fondos_suficientes do
          :lt -> add_error(changeset, :monto, "No tienes fondos suficientes para hacer esta transacción")
          _ -> changeset
        end
      false -> changeset
    end
  end

  # Procesa y valida una operación de swap (intercambio de monedas).
  #
  # Permite a un usuario intercambiar una moneda por otra dentro de su propia cuenta,
  # usando las tasas de cambio actuales del sistema.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: moneda_origen_id, cuenta_origen_id, moneda_destino_id, monto
  # - Todas las foreign keys deben existir
  # - Moneda origen y destino deben ser diferentes
  # - Monto debe ser > 0.1
  # - Debe existir alta de moneda origen
  # - Debe haber fondos suficientes
  # - Crea alta automática de moneda destino si no existe
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con los datos del swap
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Transaccion{}}` - Si se creó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación
  defp swap(changeset) do
    validate_required(changeset, [:moneda_origen_id, :cuenta_origen_id, :moneda_destino_id, :monto], message: "Los flags " <> Enum.join(["-a" |@swap], ", ") <> " son obligatorios")
    |> put_change(:tipo, "swap")
    |> validate_fk(:cuenta_origen_id, Ledger.Usuario)
    |> validate_fk(:moneda_origen_id, Ledger.Moneda)
    |> validate_fk(:moneda_destino_id, Ledger.Moneda)
    |> validate_change(:moneda_origen_id, fn :moneda_origen_id, origen ->
      destino = get_field(changeset, :moneda_destino_id)
      if destino == origen, do: [moneda_origen_id: "La moneda de origen debe ser diferente a la moneda de destino"], else: []
    end) |> validate_number(:monto, greater_than_or_equal_to: 0.1, message: "El valor del monto debe ser mayor o igual a 0.1")
    |> validar_alta_cuenta(:moneda_origen_id, :cuenta_origen_id)
    |> validar_fondos_suficientes()
    |> validar_alta_cuenta(:moneda_destino_id, :cuenta_origen_id)
    |> Repo.insert()

  end

  # Procesa y valida una operación de transferencia entre cuentas.
  #
  # Permite transferir fondos de una cuenta a otra en la misma moneda.
  # Crea automáticamente el alta de la moneda en la cuenta destino si no existe.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: moneda_origen_id, cuenta_origen_id, cuenta_destino_id, monto
  # - Todas las foreign keys deben existir
  # - Cuenta origen y destino deben ser diferentes
  # - Monto debe ser > 0.1
  # - Debe existir alta de moneda en cuenta origen
  # - Crea alta automática en cuenta destino si no existe
  # - Debe haber fondos suficientes en cuenta origen
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con los datos de la transferencia
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Transaccion{}}` - Si se creó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación
  defp transferencia(changeset) do
    validate_required(changeset, [:moneda_origen_id, :cuenta_origen_id, :cuenta_destino_id, :monto], message: "Los flags " <> Enum.join(["-a" |@transferencia], ", ") <> " son obligatorios")
    |> put_change(:tipo, "transferencia")
    |> validate_fk(:cuenta_origen_id, Ledger.Usuario)
    |> validate_fk(:moneda_origen_id, Ledger.Moneda)
    |> validate_fk(:cuenta_destino_id, Ledger.Usuario)
    |> validate_change(:cuenta_origen_id, fn :cuenta_origen_id, origen ->
      destino = get_field(changeset, :cuenta_destino_id)
      if destino == origen, do: [cuenta_origen_id: "La cuenta de origen debe ser diferente a la cuenta de destino"], else: []
    end) |> validate_number(:monto, greater_than_or_equal_to: 0.1, message: "El valor del monto debe ser mayor o igual a 0.1")
    |> validar_alta_cuenta(:moneda_origen_id, :cuenta_origen_id)
    |> validar_alta_cuenta(:moneda_origen_id, :cuenta_destino_id)
    |> validar_fondos_suficientes()
    |> Repo.insert()
  end

  # Verifica si una transacción es la última para todas las cuentas involucradas.
  #
  # Para poder deshacer una transacción, debe ser la más reciente tanto para
  # la cuenta origen como para la cuenta destino (si existe). Esto previene
  # inconsistencias en el historial de transacciones.
  #
  # ## Parámetros
  #
  # - `transaccion` - Estructura de Ledger.Transaccion a verificar
  #
  # ## Retorna
  #
  # - `true` - Si es la última transacción de todas las cuentas involucradas
  # - `false` - Si no es la última transacción
  #
  # ## Ejemplos
  #
  #     # Para alta o swap (solo cuenta origen)
  #     transaccion = %Ledger.Transaccion{id: 10, tipo: "alta_cuenta", cuenta_origen_id: 1}
  #     es_la_ultima_transaccion_de_ambos_usuarios?(transaccion)
  #     #=> true (si ID 10 es el último de cuenta 1)
  #
  #     # Para transferencia (cuenta origen y destino)
  #     transaccion = %Ledger.Transaccion{id: 20, tipo: "transferencia",
  #                                        cuenta_origen_id: 1, cuenta_destino_id: 2}
  #     es_la_ultima_transaccion_de_ambos_usuarios?(transaccion)
  #     #=> true (si ID 20 es el último tanto para cuenta 1 como para cuenta 2)
  defp es_la_ultima_transaccion_de_ambos_usuarios?(transaccion) do
    query_origen = from t in Ledger.Transaccion,
    where: t.cuenta_origen_id == ^transaccion.cuenta_origen_id or t.cuenta_destino_id == ^transaccion.cuenta_origen_id,
    select: t.id

    case transaccion.cuenta_destino_id do
      nil ->
        lo = Ecto.Query.last(query_origen)
        |> Repo.one()

        transaccion.id == lo
      _ ->
        query_destino = from t in Ledger.Transaccion,
        where: t.cuenta_origen_id == ^transaccion.cuenta_destino_id or t.cuenta_origen_id == ^transaccion.cuenta_destino_id,
        select: t.id

        lo = Ecto.Query.last(query_origen)
        |> Repo.one()

        ld = Ecto.Query.last(query_destino)
        |> Repo.one()

        ultima_cuenta = (lo == ld)
        ultima_cuenta == transaccion.id
    end
  end

  # Deshace (elimina) una transacción del sistema.
  #
  # Solo se pueden deshacer transacciones que sean las más recientes para todas
  # las cuentas involucradas. Esta restricción mantiene la integridad del historial.
  #
  # ## Validaciones aplicadas
  #
  # - Campo obligatorio: id
  # - El ID debe existir en la base de datos
  # - Debe ser la última transacción de todas las cuentas involucradas
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID de la transacción a deshacer
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Transaccion{}}` - Si se eliminó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores (ID no existe o no es la última)
  #
  # ## Ejemplos
  #
  #     # Deshacer exitosamente
  #     changeset = cast(%Ledger.Transaccion{}, %{id: 10}, [:id])
  #     deshacer(changeset)
  #     #=> {:ok, %Ledger.Transaccion{id: 10}}
  #
  #     # Error: no es la última transacción
  #     changeset = cast(%Ledger.Transaccion{}, %{id: 5}, [:id])
  #     deshacer(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"No se puede borrar porque esta no es la ultima transaccion", _}]}}
  defp deshacer(changeset) do
    changeset = validate_required(changeset, [:id], message: "El flag " <> @headers.id <> " es obligatorio")

    cond do
      changeset.valid? == true ->
        transaccion = Repo.get(Ledger.Transaccion, get_field(changeset, :id))
        case transaccion do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ ->
            case es_la_ultima_transaccion_de_ambos_usuarios?(transaccion) do
              true -> Repo.delete(transaccion)
              false -> {:error, add_error(changeset, :id, "No se puede borrar porque esta no es la ultima transaccion")}
            end
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end

  # Consulta y muestra los detalles completos de una transacción.
  #
  # Realiza un JOIN con todas las tablas relacionadas (usuarios y monedas) para
  # obtener información legible en lugar de solo IDs. Formatea y muestra la
  # información por pantalla.
  #
  # ## Validaciones aplicadas
  #
  # - Campo obligatorio: id
  # - El ID debe existir en la base de datos
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID de la transacción a consultar
  #
  # ## Retorna
  #
  # - `{:ok, resultado}` - Si se consultó y mostró exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si el ID no existe
  #
  # ## Información mostrada
  #
  # - id_transaccion
  # - timestamp (fecha/hora de creación)
  # - moneda_origen (nombre, no ID)
  # - moneda_destino (nombre, no ID)
  # - monto
  # - cuenta_origen (username, no ID)
  # - cuenta_destino (username, no ID)
  # - tipo (alta_cuenta, transferencia o swap)
  defp ver(changeset) do
    changeset = validate_required(changeset, [:id], message: "El flag " <> @headers.id <> " es obligatorio")

    cond do
      changeset.valid? == true ->
        transaccion = Ledger.Transaccion
        |> join(:left, [t], cd in assoc(t, :cuenta_destino))
        |> join(:left, [t], co in assoc(t, :cuenta_origen))
        |> join(:left, [t], md in assoc(t, :moneda_destino))
        |> join(:left, [t], mo in assoc(t, :moneda_origen))
        |> where([t], t.id == ^get_field(changeset, :id))
        |> select([t, cd, co, md, mo], %{id_transaccion: t.id,
          timestamp: t.inserted_at,
          moneda_origen: mo.nombre,
          moneda_destino: md.nombre,
          monto: t.monto,
          cuenta_origen: co.username,
          cuenta_destino: cd.username,
          tipo: t.tipo})
        |> Repo.one()
        case transaccion do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ -> Herramientas.mostrar_por_pantalla(Estructuras.Transaccion.getHeaders(), [transaccion], changeset)
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end

end
