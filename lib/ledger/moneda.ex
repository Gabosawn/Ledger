defmodule Ledger.Moneda do
  @moduledoc """
  Módulo de esquema y operaciones CRUD para monedas en el sistema Ledger.

  Este módulo gestiona la entidad de monedas en la base de datos y proporciona
  operaciones completas de creación, lectura, actualización y eliminación (CRUD).

  ## Esquema de base de datos

  La tabla `monedas` contiene:
  - `id` - Identificador único autogenerado
  - `nombre` - Código de la moneda (3-4 caracteres en mayúsculas, ej: USD, EUR, USDT)
  - `precio_dolar` - Precio de la moneda expresado en dólares USD (debe ser >= 0)
  - `inserted_at` - Timestamp de creación
  - `updated_at` - Timestamp de última actualización

  ## Operaciones disponibles

  - **crear_moneda**: Crea una nueva moneda en el sistema
  - **editar_moneda**: Actualiza el precio de una moneda existente
  - **borrar_moneda**: Elimina una moneda (solo si no ha sido usada)
  - **ver_moneda**: Consulta los detalles de una moneda

  ## Flags disponibles

  - `-id`: ID de la moneda (obligatorio para editar/borrar/ver)
  - `-p`: Precio en dólares (obligatorio para crear/editar)
  - `-n`: Nombre de la moneda (obligatorio para crear)

  ## Restricciones

  - El nombre de la moneda debe ser único
  - No se pueden eliminar monedas que han sido utilizadas en transacciones
  - El precio debe ser un número decimal positivo o cero

  ## Ejemplos

      # Crear una moneda
      Ledger.Moneda.changeset(:crear_moneda, %{nombre: "BTC", precio_dolar: 45000.0})

      # Editar precio
      Ledger.Moneda.changeset(:editar_moneda, %{id: 1, precio_dolar: 46000.0})

      # Ver detalles
      Ledger.Moneda.changeset(:ver_moneda, %{id: 1})
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ledger.Repo, as: Repo

  @headers  %{id: "-id", precio_dolar: "-p", nombre: "-n"}
  @errores [id: "El id debe ser un número entero", precio_dolar: "El precio dolar debe ser un numero decimal"]

  schema "monedas" do
    field :nombre, :string
    field :precio_dolar, :decimal
    timestamps()
  end

  @doc """
  Retorna los headers (flags) y operaciones disponibles para el módulo de monedas.

  ## Retorna

  Un mapa con dos claves:
  - `:flags` - Mapa con los flags disponibles y sus identificadores
  - `:operaciones` - Lista de operaciones soportadas

  ## Ejemplos

      iex> Ledger.Moneda.getHeaders()
      %{
        flags: %{id: "-id", precio_dolar: "-p", nombre: "-n"},
        operaciones: ["crear_moneda", "editar_moneda", "borrar_moneda", "ver_moneda"]
      }
  """
  def getHeaders do
    Map.merge(%{flags: @headers}, %{operaciones: ["crear_moneda", "editar_moneda", "borrar_moneda", "ver_moneda"]})
  end

  @doc """
  Valida y ejecuta una operación CRUD sobre monedas.

  Esta función actúa como punto de entrada para todas las operaciones de monedas.
  Crea un changeset con los parámetros proporcionados y ejecuta la operación
  correspondiente aplicando las validaciones necesarias.

  ## Parámetros

  - `typeOperation` - Átomo que indica la operación a realizar:
    - `:crear_moneda` - Crear nueva moneda
    - `:editar_moneda` - Actualizar precio de moneda existente
    - `:borrar_moneda` - Eliminar moneda
    - `:ver_moneda` - Consultar detalles de moneda
  - `params` - Mapa con los parámetros necesarios según la operación:
    - Para crear: `%{nombre: "USD", precio_dolar: 1.0}`
    - Para editar: `%{id: 1, precio_dolar: 1.05}`
    - Para borrar: `%{id: 1}`
    - Para ver: `%{id: 1}`

  ## Retorna

  - `{:ok, String.t()}` - Si la operación fue exitosa
  - `{:error, Keyword.t()}` - Si hubo errores, con la clave siendo el tipo de
    operación y el valor el mensaje de error

  ## Ejemplos

      # Crear moneda exitosamente
      iex> Ledger.Moneda.changeset(:crear_moneda, %{nombre: "BTC", precio_dolar: 45000})
      {:ok, "Operación realizada con exito"}

      # Error por nombre duplicado
      iex> Ledger.Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: 1.0})
      {:error, [crear_moneda: "Este nombre de moneda ya se encuentra en uso"]}

      # Editar precio exitosamente
      iex> Ledger.Moneda.changeset(:editar_moneda, %{id: 1, precio_dolar: 1.05})
      {:ok, "Operación realizada con exito"}

      # Error por ID inexistente
      iex> Ledger.Moneda.changeset(:ver_moneda, %{id: 999})
      {:error, [ver_moneda: "El id proporcionado no existe"]}
  """
  def changeset(typeOperation, params) do
    message_by_error = fn field, _meta -> @errores[field] end
    changeset = cast(%Ledger.Moneda{}, params, Map.keys(@headers), message: message_by_error)

    {state, res} = case typeOperation do
      :crear_moneda -> crear(changeset)
      :editar_moneda -> editar(changeset)
      :borrar_moneda -> borrar(changeset)
      :ver_moneda -> ver(changeset)
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
  Ejecuta una operación sobre monedas basándose en el tipo de operación especificado.

  Esta función es similar a `changeset/2` pero recibe el tipo de operación como
  string en lugar de átomo. Se utiliza principalmente para procesar operaciones
  desde interfaces de línea de comandos o APIs.

  ## Parámetros

  - `estructura` - Changeset de Ecto con los datos de la operación
  - `typeOperation` - String que indica la operación: "crear_moneda", "editar_moneda",
    "borrar_moneda" o "ver_moneda"

  ## Retorna

  - `{:ok, resultado}` - Si la operación fue exitosa
  - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación

  ## Ejemplos

      iex> changeset = cast(%Ledger.Moneda{}, %{nombre: "EUR", precio_dolar: 1.08}, [:nombre, :precio_dolar])
      iex> Ledger.Moneda.tomarErrores(changeset, "crear_moneda")
      {:ok, %Ledger.Moneda{}}
  """
  def tomarErrores(estructura, typeOperation) do
    case typeOperation do
      "crear_moneda" -> crear(estructura)
      "editar_moneda" -> editar(estructura)
      "borrar_moneda" -> borrar(estructura)
      "ver_moneda" -> ver(estructura)
    end
  end

  # Crea una nueva moneda en la base de datos.
  #
  # Valida que los campos obligatorios estén presentes y cumplan con los
  # requisitos de formato y valor antes de insertar en la base de datos.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: nombre y precio_dolar
  # - Precio debe ser >= 0
  # - Nombre debe tener 3-4 caracteres
  # - Nombre debe estar en mayúsculas
  # - Nombre debe ser único (constraint de BD)
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con los datos de la nueva moneda
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Moneda{}}` - Si se creó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación
  #
  # ## Ejemplos
  #
  #     changeset = cast(%Ledger.Moneda{}, %{nombre: "BTC", precio_dolar: 45000}, [:nombre, :precio_dolar])
  #     crear(changeset)
  #     #=> {:ok, %Ledger.Moneda{id: 1, nombre: "BTC", precio_dolar: 45000}}
  defp crear(changeset) do
    validate_required(changeset, [:precio_dolar, :nombre], message: "Los flags " <> Enum.join([@headers.nombre, @headers.precio_dolar], ", ") <> " son obligatorios")
    |> validate_number(:precio_dolar, greater_than_or_equal_to: 0, message: "El valor del precio en dolar debe ser un número positivo")
    |> validate_length(:nombre, min: 3, max: 4, message: "El nombre de la moneda debe ser de 3 o 4 letras")
    |> validate_format(:nombre, ~r/^[A-Z]+$/, message: "El nombre de la moneda debe estar completamente en mayúsculas")
    |> unique_constraint(:nombre, message: "Este nombre de moneda ya se encuentra en uso")
    |> Repo.insert()
  end

  # Actualiza el precio de una moneda existente.
  #
  # Valida que la moneda exista en la base de datos y que el nuevo precio
  # sea diferente al actual antes de realizar la actualización.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: id y precio_dolar
  # - Precio debe ser >= 0
  # - El ID debe existir en la base de datos
  # - El nuevo precio debe ser diferente al actual
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID y el nuevo precio
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Moneda{}}` - Si se actualizó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación o el ID no existe
  #
  # ## Ejemplos
  #
  #     # Actualización exitosa
  #     changeset = cast(%Ledger.Moneda{}, %{id: 1, precio_dolar: 46000}, [:id, :precio_dolar])
  #     editar(changeset)
  #     #=> {:ok, %Ledger.Moneda{id: 1, precio_dolar: 46000}}
  #
  #     # Error: ID no existe
  #     changeset = cast(%Ledger.Moneda{}, %{id: 999, precio_dolar: 100}, [:id, :precio_dolar])
  #     editar(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"El id proporcionado no existe", _}]}}
  defp editar(changeset) do
    changeset = validate_required(changeset, [:id, :precio_dolar], message: "Los flags " <> Enum.join([@headers.id, @headers.precio_dolar], ", ") <> " son obligatorios")
    |> validate_number(:precio_dolar, greater_than_or_equal_to: 0, message: "El valor del precio en dolar debe ser un número positivo")

    cond do
      changeset.valid? == true ->
        respuesta = Repo.get(Ledger.Moneda, get_field(changeset, :id))
        case respuesta do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ -> respuesta = change(respuesta, changeset.changes)
            cond do
              respuesta.changes == %{} -> {:error, add_error(changeset, :username, "El precio de la moneda debe ser diferente al acutal")}
              respuesta.changes != %{} -> Repo.update(respuesta)
            end
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end

  # Verifica si una moneda ha sido utilizada en alguna transacción.
  #
  # Esta función consulta la tabla de transacciones para determinar si la moneda
  # aparece como moneda_origen o moneda_destino en alguna transacción. Se utiliza
  # para prevenir la eliminación de monedas que están siendo referenciadas.
  #
  # ## Parámetros
  #
  # - `moneda` - Estructura de Ledger.Moneda con el ID a verificar
  #
  # ## Retorna
  #
  # - `true` - Si la moneda ha sido usada en al menos una transacción
  # - `false` - Si la moneda no ha sido usada
  #
  # ## Ejemplos
  #
  #     moneda = %Ledger.Moneda{id: 1, nombre: "USD"}
  #     ha_sido_usada?(moneda)
  #     #=> true
  #
  #     moneda_nueva = %Ledger.Moneda{id: 99, nombre: "XYZ"}
  #     ha_sido_usada?(moneda_nueva)
  #     #=> false
  defp ha_sido_usada?(moneda) do
    query = from t in Ledger.Transaccion, where: t.moneda_origen_id == ^moneda.id or t.moneda_destino_id == ^moneda.id

    Repo.exists?(query)
  end

  # Elimina una moneda de la base de datos.
  #
  # Valida que la moneda exista y que no haya sido utilizada en ninguna transacción
  # antes de permitir su eliminación. Esta restricción mantiene la integridad
  # referencial del sistema.
  #
  # ## Validaciones aplicadas
  #
  # - Campo obligatorio: id
  # - El ID debe existir en la base de datos
  # - La moneda no debe haber sido usada en transacciones
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID de la moneda a eliminar
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Moneda{}}` - Si se eliminó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación, el ID no existe,
  #   o la moneda ha sido usada
  #
  # ## Ejemplos
  #
  #     # Eliminación exitosa
  #     changeset = cast(%Ledger.Moneda{}, %{id: 5}, [:id])
  #     borrar(changeset)
  #     #=> {:ok, %Ledger.Moneda{id: 5}}
  #
  #     # Error: moneda ha sido usada
  #     changeset = cast(%Ledger.Moneda{}, %{id: 1}, [:id])
  #     borrar(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"No se puede borrar porque la moneda ha sido usada", _}]}}
  defp borrar(changeset) do
    changeset = validate_required(changeset, [:id], message: "El flag " <> @headers.id <> " es obligatorio")
    cond do
      changeset.valid? == true ->
        moneda = Repo.get(Ledger.Moneda, get_field(changeset, :id))
        case moneda do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ ->
            case ha_sido_usada?(moneda) do
              true -> {:error, add_error(changeset, :id, "No se puede borrar porque la moneda ha sido usada")}
              false -> Repo.delete(moneda)
            end
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end

  # Consulta y muestra los detalles de una moneda específica.
  #
  # Valida que la moneda exista y luego muestra sus detalles por pantalla
  # utilizando el módulo de Herramientas para el formateo.
  #
  # ## Validaciones aplicadas
  #
  # - Campo obligatorio: id
  # - El ID debe existir en la base de datos
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID de la moneda a consultar
  #
  # ## Retorna
  #
  # - `{:ok, resultado}` - Si se consultó y mostró exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si el ID no existe o hubo errores de validación
  #
  # ## Ejemplos
  #
  #     # Consulta exitosa
  #     changeset = cast(%Ledger.Moneda{}, %{id: 1}, [:id])
  #     ver(changeset)
  #     #=> {:ok, ...} # Muestra los detalles por pantalla
  #
  #     # Error: ID no existe
  #     changeset = cast(%Ledger.Moneda{}, %{id: 999}, [:id])
  #     ver(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"El id proporcionado no existe", _}]}}
  defp ver(changeset) do
    changeset = validate_required(changeset, [:id], message: "El flag " <> @headers.id <> " es obligatorio")

    cond do
      changeset.valid? == true ->
        moneda = Repo.get(Ledger.Moneda, get_field(changeset, :id))
        case moneda do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ -> Herramientas.mostrar_por_pantalla(Map.keys(@headers), [Map.from_struct(moneda)], changeset)
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end
end
