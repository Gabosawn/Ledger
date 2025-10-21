defmodule Herramientas do
  @moduledoc """
  Módulo de utilidades y funciones auxiliares para el sistema Ledger.

  Proporciona funciones de ayuda para:
  - Visualización de datos en formato tabla usando ANSI
  - Consultas complejas a la base de datos con joins
  - Validaciones de estado del sistema

  ## Funcionalidades principales

  - **Visualización**: Formateo de datos en tablas para mostrar en consola
  - **Consultas de transacciones**: Queries con joins para obtener información completa
  - **Validaciones**: Verificación de condiciones del sistema (ej: altas de monedas)

  ## Dependencias

  Este módulo utiliza:
  - `IO.ANSI.Table` para el formateo visual de tablas
  - `Ecto.Query` para construcción de queries dinámicas
  - Módulos del dominio: `Ledger.Transaccion`, `Ledger.Repo`, `Estructuras.Transaccion`

  ## Ejemplos

      # Mostrar datos en tabla
      Herramientas.mostrar_por_pantalla([:id, :nombre], [%{id: 1, nombre: "Usuario"}])

      # Obtener transacciones de una cuenta
      Herramientas.query_transacciones_id(1)

      # Verificar si una moneda está dada de alta
      Herramientas.query_dada_alta?(1, 2)
  """

  alias IO.ANSI.Table
  import Ecto.Query

  @doc """
  Muestra datos en formato de tabla en la consola usando IO.ANSI.Table.

  Esta función formatea y presenta datos tabulares de manera visual en la terminal,
  facilitando la lectura de resultados de operaciones.

  ## Parámetros

  - `headers` - Lista de átomos o strings representando los encabezados de la tabla
  - `data` - Lista de mapas o structs con los datos a mostrar
  - `changeset` - (opcional) Mensaje o changeset a retornar. Por defecto: "Operación realizada con exito"

  ## Retorna

  Una tupla `{tabla_formateada, changeset}` donde:
  - `tabla_formateada` es el string con la tabla formateada
  - `changeset` es el valor pasado como tercer parámetro

  ## Manejo de errores

  Utiliza `try/after` para asegurar que `Table.stop()` se ejecute incluso si hay errores.

  ## Ejemplos

      # Mostrar usuarios
      iex> headers = [:id, :username, :nacimiento]
      iex> data = [%{id: 1, username: "alice", nacimiento: ~D[1995-06-15]}]
      iex> Herramientas.mostrar_por_pantalla(headers, data)
      {tabla_formateada, "Operación realizada con exito"}

      # Con changeset personalizado
      iex> Herramientas.mostrar_por_pantalla([:id, :nombre], data, mi_changeset)
      {tabla_formateada, mi_changeset}

      # Mostrar balances
      iex> headers = [:MONEDA, :BALANCE]
      iex> balances = [%{MONEDA: "USD", BALANCE: 1500.50}]
      iex> Herramientas.mostrar_por_pantalla(headers, balances)
      # Muestra:
      # ┌────────┬─────────┐
      # │ MONEDA │ BALANCE │
      # ├────────┼─────────┤
      # │ USD    │ 1500.50 │
      # └────────┴─────────┘
  """
  def mostrar_por_pantalla(headers, data, changeset \\ "Operación realizada con exito") do
    try do
      Table.start(headers, count: Enum.count(data))
      {Table.format(data), changeset}
    after
      Table.stop()
    end
  end

  @doc """
  Consulta todas las transacciones de una cuenta específica por ID.

  Realiza una query compleja con múltiples LEFT JOINs para obtener información
  completa de las transacciones (con nombres de usuarios y monedas en lugar de IDs).

  ## Parámetros

  - `cuenta` - ID de la cuenta (usuario) para filtrar transacciones

  ## Retorna

  Lista de estructuras `%Estructuras.Transaccion{}` ordenadas por ID ascendente,
  conteniendo:
  - `id_transaccion` - ID de la transacción
  - `timestamp` - Fecha/hora de creación
  - `moneda_origen` - Nombre de la moneda origen
  - `moneda_destino` - Nombre de la moneda destino
  - `monto` - Cantidad de la transacción
  - `cuenta_origen` - Username de la cuenta origen
  - `cuenta_destino` - Username de la cuenta destino
  - `tipo` - Tipo de transacción

  ## Filtrado

  Incluye transacciones donde la cuenta aparece como origen O destino.

  ## Ejemplos

      iex> Herramientas.query_transacciones_id(1)
      [
        %Estructuras.Transaccion{
          id_transaccion: 1,
          timestamp: ~N[2025-01-15 10:30:00],
          moneda_origen: "USD",
          moneda_destino: nil,
          monto: Decimal.new(1000),
          cuenta_origen: "alice",
          cuenta_destino: nil,
          tipo: "alta_cuenta"
        },
        %Estructuras.Transaccion{
          id_transaccion: 5,
          timestamp: ~N[2025-01-16 14:20:00],
          moneda_origen: "USD",
          moneda_destino: nil,
          monto: Decimal.new(100),
          cuenta_origen: "alice",
          cuenta_destino: "bob",
          tipo: "transferencia"
        }
      ]
  """
  def query_transacciones_id(cuenta) do
    Ledger.Transaccion
    |> join(:left, [t], cd in assoc(t, :cuenta_destino))
    |> join(:left, [t], co in assoc(t, :cuenta_origen))
    |> join(:left, [t], md in assoc(t, :moneda_destino))
    |> join(:left, [t], mo in assoc(t, :moneda_origen))
    |> where([t, cd, co], t.cuenta_origen_id == ^cuenta or t.cuenta_destino_id == ^cuenta)
    |> order_by(asc: :id)
    |> select([t, cd, co, md, mo], %Estructuras.Transaccion{id_transaccion: t.id,
    timestamp: t.inserted_at,
    moneda_origen: mo.nombre,
    moneda_destino: md.nombre,
    monto: t.monto,
    cuenta_origen: co.username,
    cuenta_destino: cd.username,
    tipo: t.tipo})
    |> Ledger.Repo.all()
  end

  @doc """
  Consulta transacciones filtrando por cuenta origen, destino y/o moneda.

  Realiza una query dinámica que permite filtrar transacciones según múltiples
  criterios. Los filtros se construyen dinámicamente dependiendo de los parámetros
  proporcionados.

  ## Parámetros

  - `origen` - Username de la cuenta origen (nil para no filtrar por origen)
  - `destino` - Username de la cuenta destino (nil para no filtrar por destino)
  - `moneda` - (opcional) Nombre de la moneda (nil para no filtrar por moneda)

  ## Comportamiento de filtrado

  ### Cuando origen == destino:
  - Si ambos son `nil`: retorna todas las transacciones
  - Si tienen valor: retorna transacciones donde esa cuenta aparece como origen O destino

  ### Cuando origen != destino:
  - Si ambos son `nil`: retorna todas las transacciones
  - Si ambos tienen valor: retorna transacciones con ese origen Y ese destino
  - Si solo origen tiene valor: retorna transacciones de ese origen
  - Si solo destino tiene valor: retorna transacciones hacia ese destino

  ### Filtro de moneda:
  - Si es `nil`: no filtra por moneda
  - Si tiene valor: filtra por moneda_origen O moneda_destino

  ## Retorna

  Lista de estructuras `%Estructuras.Transaccion{}` ordenadas por ID ascendente

  ## Ejemplos

      # Todas las transacciones
      iex> Herramientas.query_transacciones(nil, nil, nil)
      [lista completa de transacciones]

      # Transacciones de una cuenta específica
      iex> Herramientas.query_transacciones("alice", "alice", nil)
      [transacciones donde alice es origen o destino]

      # Transferencias de alice a bob
      iex> Herramientas.query_transacciones("alice", "bob", nil)
      [transacciones de alice hacia bob]

      # Transacciones en USD
      iex> Herramientas.query_transacciones(nil, nil, "USD")
      [transacciones que involucran USD]

      # Transferencias en EUR de alice a bob
      iex> Herramientas.query_transacciones("alice", "bob", "EUR")
      [transacciones de alice a bob en EUR]
  """
  def query_transacciones(origen, destino, moneda \\ nil) do
    Ledger.Transaccion
    |> join(:left, [t], cd in assoc(t, :cuenta_destino))
    |> join(:left, [t], co in assoc(t, :cuenta_origen))
    |> join(:left, [t], md in assoc(t, :moneda_destino))
    |> join(:left, [t], mo in assoc(t, :moneda_origen))
    |> where([t, cd, co, md, mo],
      ^(if origen == destino do
        cond do
          origen == nil -> true
          true -> dynamic([t, cd, co, md, mo], co.username == ^origen or cd.username == ^origen)
        end
      else
        cond do
          origen == nil and destino == nil -> true
          origen != nil and destino != nil -> dynamic([t, cd, co, md, mo], co.username == ^origen and cd.username == ^destino)
          origen == nil and destino != nil -> dynamic([t, cd, co, md, mo], cd.username == ^destino)
          origen != nil and destino == nil -> dynamic([t, cd, co, md, mo], co.username == ^origen)
        end
      end)
    )
    |> where([t, cd, co, md, mo], ^(if moneda == nil, do: true, else: dynamic([t, cd, co, md, mo], mo.nombre == ^moneda or md.nombre == ^moneda)))
    |> order_by(asc: :id)
    |> select([t, cd, co, md, mo], %Estructuras.Transaccion{id_transaccion: t.id,
    timestamp: t.inserted_at,
    moneda_origen: mo.nombre,
    moneda_destino: md.nombre,
    monto: t.monto,
    cuenta_origen: co.username,
    cuenta_destino: cd.username,
    tipo: t.tipo})
    |> Ledger.Repo.all()
  end

  @doc """
  Verifica si existe un alta de una moneda específica para una cuenta.

  Consulta la base de datos para determinar si existe al menos una transacción
  de tipo "alta_cuenta" que vincule la cuenta con la moneda especificada.

  ## Parámetros

  - `id_cuenta` - ID de la cuenta (usuario) a verificar
  - `id_moneda` - ID de la moneda a verificar

  ## Retorna

  - `true` - Si existe un alta de esa moneda para esa cuenta
  - `false` - Si no existe un alta previa

  ## Uso

  Esta función se utiliza principalmente para validar:
  - Si se puede realizar un swap (debe existir alta de moneda origen)
  - Si se puede realizar una transferencia (debe existir alta en cuenta origen)
  - Si se puede crear un alta (no debe existir alta previa)

  ## Ejemplos

      # Verificar si la cuenta 1 tiene dada de alta la moneda 2
      iex> Herramientas.query_dada_alta?(1, 2)
      true

      # Verificar cuenta sin alta de moneda
      iex> Herramientas.query_dada_alta?(5, 3)
      false

      # Usar en validación antes de swap
      iex> if Herramientas.query_dada_alta?(cuenta_id, moneda_origen_id) do
      ...>   # Proceder con swap
      ...> else
      ...>   {:error, "Esta moneda no ha sido dada de alta en esta cuenta"}
      ...> end
  """
  def query_dada_alta?(id_cuenta, id_moneda) do
    Ledger.Transaccion
    |> where([t], t.cuenta_origen_id == ^id_cuenta)
    |> where([t], t.moneda_origen_id == ^id_moneda)
    |> Ledger.Repo.exists?()
  end
end
