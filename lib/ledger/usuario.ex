defmodule Ledger.Usuario do
  @moduledoc """
  Módulo de esquema y operaciones CRUD para usuarios en el sistema Ledger.

  Este módulo gestiona la entidad de usuarios (cuentas) en la base de datos y proporciona
  operaciones completas de creación, lectura, actualización y eliminación (CRUD).

  ## Esquema de base de datos

  La tabla `usuarios` contiene:
  - `id` - Identificador único autogenerado
  - `username` - Nombre de usuario único (5-20 caracteres)
  - `nacimiento` - Fecha de nacimiento (debe ser mayor de 18 años)
  - `inserted_at` - Timestamp de creación
  - `updated_at` - Timestamp de última actualización

  ## Operaciones disponibles

  - **crear_usuario**: Crea una nueva cuenta de usuario en el sistema
  - **editar_usuario**: Actualiza el nombre de usuario de una cuenta existente
  - **borrar_usuario**: Elimina un usuario (solo si no ha realizado transacciones)
  - **ver_usuario**: Consulta los detalles de un usuario

  ## Flags disponibles

  - `-id`: ID del usuario (obligatorio para editar/borrar/ver)
  - `-n`: Nombre de usuario (obligatorio para crear/editar)
  - `-b`: Fecha de nacimiento en formato YYYY-MM-DD (obligatorio para crear)

  ## Restricciones

  - El username debe ser único en el sistema
  - El usuario debe ser mayor de 18 años al momento de crear la cuenta
  - No se pueden eliminar usuarios que han realizado transacciones
  - El username debe tener entre 5 y 20 caracteres

  ## Ejemplos

      # Crear usuario
      Ledger.Usuario.changeset(:crear_usuario,
        %{username: "john_doe", nacimiento: ~D[2000-01-15]})

      # Editar username
      Ledger.Usuario.changeset(:editar_usuario, %{id: 1, username: "jane_doe"})

      # Ver detalles
      Ledger.Usuario.changeset(:ver_usuario, %{id: 1})
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Ledger.Repo, as: Repo

  @headers %{id: "-id", username: "-n", nacimiento: "-b"}
  @errores [id: "El id debe ser un número entero", nacimiento: "La fecha de nacimiento debe tener este formato 1999-05-06"]

  schema "usuarios" do
    field :username, :string
    field :nacimiento, :date
    timestamps()
  end

  @doc """
  Retorna los headers (flags) y operaciones disponibles para el módulo de usuarios.

  ## Retorna

  Un mapa con dos claves:
  - `:flags` - Mapa con los flags disponibles y sus identificadores
  - `:operaciones` - Lista de operaciones soportadas

  ## Ejemplos

      iex> Ledger.Usuario.getHeaders()
      %{
        flags: %{id: "-id", username: "-n", nacimiento: "-b"},
        operaciones: ["crear_usuario", "editar_usuario", "borrar_usuario", "ver_usuario"]
      }
  """
  def getHeaders do
    Map.merge(%{flags: @headers}, %{operaciones: ["crear_usuario", "editar_usuario", "borrar_usuario", "ver_usuario"]})
  end

  @doc """
  Valida y ejecuta una operación CRUD sobre usuarios.

  Esta función actúa como punto de entrada para todas las operaciones de usuarios.
  Crea un changeset con los parámetros proporcionados y ejecuta la operación
  correspondiente aplicando las validaciones necesarias.

  ## Parámetros

  - `typeOperation` - Átomo que indica la operación a realizar:
    - `:crear_usuario` - Crear nuevo usuario
    - `:editar_usuario` - Actualizar username de usuario existente
    - `:borrar_usuario` - Eliminar usuario
    - `:ver_usuario` - Consultar detalles de usuario
  - `params` - Mapa con los parámetros necesarios según la operación:
    - Para crear: `%{username: "john_doe", nacimiento: ~D[2000-01-15]}`
    - Para editar: `%{id: 1, username: "jane_doe"}`
    - Para borrar: `%{id: 1}`
    - Para ver: `%{id: 1}`

  ## Retorna

  - `{:ok, String.t()}` - Si la operación fue exitosa
  - `{:error, Keyword.t()}` - Si hubo errores, con la clave siendo el tipo de
    operación y el valor el mensaje de error

  ## Ejemplos

      # Crear usuario exitosamente
      iex> Ledger.Usuario.changeset(:crear_usuario,
      ...>   %{username: "alice", nacimiento: ~D[1995-06-20]})
      {:ok, "Operación realizada con exito"}

      # Error por usuario menor de 18 años
      iex> Ledger.Usuario.changeset(:crear_usuario,
      ...>   %{username: "bobby", nacimiento: ~D[2010-01-01]})
      {:error, [crear_usuario: "El usuario debe ser mayor de 18 años"]}

      # Editar username exitosamente
      iex> Ledger.Usuario.changeset(:editar_usuario, %{id: 1, username: "alice_updated"})
      {:ok, "Operación realizada con exito"}

      # Error por ID inexistente
      iex> Ledger.Usuario.changeset(:ver_usuario, %{id: 999})
      {:error, [ver_usuario: "El id proporcionado no existe"]}
  """
  def changeset(typeOperation, params) do
    message_by_error = fn field, _meta -> @errores[field] end
    changeset = cast(%Ledger.Usuario{}, params, Map.keys(@headers), message: message_by_error)

    {state, res} = case typeOperation do
      :crear_usuario -> crear(changeset)
      :editar_usuario -> editar(changeset)
      :borrar_usuario -> borrar(changeset)
      :ver_usuario -> ver(changeset)
    end

    case state do
      :ok -> {:ok, "Operación realizada con exito"}
      :error ->
        {_, message} = res.errors |> Enum.at(Enum.count(res.errors) - 1)
        message = elem(message, 0)
        {:error, Keyword.new([{typeOperation, message}])}
    end
  end

  # Crea un nuevo usuario en la base de datos.
  #
  # Valida que los campos obligatorios estén presentes y cumplan con los
  # requisitos antes de insertar en la base de datos. La validación de edad
  # calcula dinámicamente la fecha hace 18 años desde hoy.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: username y nacimiento
  # - Username debe tener entre 5 y 20 caracteres
  # - Usuario debe ser mayor de 18 años (fecha de nacimiento anterior a hace 18 años)
  # - Username debe ser único (constraint de BD)
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con los datos del nuevo usuario
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Usuario{}}` - Si se creó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación
  #
  # ## Ejemplos
  #
  #     # Creación exitosa
  #     changeset = cast(%Ledger.Usuario{},
  #       %{username: "john_doe", nacimiento: ~D[1995-05-15]},
  #       [:username, :nacimiento])
  #     crear(changeset)
  #     #=> {:ok, %Ledger.Usuario{id: 1, username: "john_doe", nacimiento: ~D[1995-05-15]}}
  #
  #     # Error: menor de 18 años
  #     changeset = cast(%Ledger.Usuario{},
  #       %{username: "kid", nacimiento: ~D[2010-01-01]},
  #       [:username, :nacimiento])
  #     crear(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [nacimiento: {"El usuario debe ser mayor de 18 años", _}]}}
  defp crear(changeset) do
    today = Date.utc_today()
    invalid = Date.new!(today.year - 18, today.month, today.day)

    validate_required(changeset, [:username, :nacimiento], message: "Los flags " <> Enum.join([@headers.username, @headers.nacimiento], ", ") <> " son obligatorios")
    |> validate_exclusion(:nacimiento, Date.range(invalid, today), message: "El usuario debe ser mayor de 18 años")
    |> validate_length(:username, min: 5, max: 20, message: "El nombre de usuario debe tener como mínimo  #{5} letras y máximo  #{20} letras")
    |> unique_constraint(:username, message: "Este nombre de usuario ya se encuentra en uso")
    |> Repo.insert()

  end

  # Actualiza el nombre de usuario de un usuario existente.
  #
  # Valida que el usuario exista en la base de datos y que el nuevo username
  # sea diferente al actual antes de realizar la actualización.
  #
  # ## Validaciones aplicadas
  #
  # - Campos obligatorios: id y username
  # - Username debe tener entre 5 y 20 caracteres
  # - El ID debe existir en la base de datos
  # - El nuevo username debe ser diferente al actual
  # - El nuevo username debe ser único
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID y el nuevo username
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Usuario{}}` - Si se actualizó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación o el ID no existe
  #
  # ## Ejemplos
  #
  #     # Actualización exitosa
  #     changeset = cast(%Ledger.Usuario{}, %{id: 1, username: "new_username"}, [:id, :username])
  #     editar(changeset)
  #     #=> {:ok, %Ledger.Usuario{id: 1, username: "new_username"}}
  #
  #     # Error: ID no existe
  #     changeset = cast(%Ledger.Usuario{}, %{id: 999, username: "test"}, [:id, :username])
  #     editar(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"El id proporcionado no existe", _}]}}
  #
  #     # Error: username igual al actual
  #     changeset = cast(%Ledger.Usuario{}, %{id: 1, username: "current_name"}, [:id, :username])
  #     editar(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [username: {"El nombre de usuario debe ser diferente al acutal", _}]}}
  defp editar(changeset) do
    changeset = validate_required(changeset, [:id, :username], message: "Los flags " <> Enum.join([@headers.id, @headers.username], ", ") <> " son obligatorios")
    |> validate_length(:username, min: 5, max: 20, message: "El nombre de usuario debe tener como mínimo  #{5} letras y máximo  #{20} letras")

    cond do
      changeset.valid? == true ->
        respuesta = Repo.get(Ledger.Usuario, get_field(changeset, :id))
        case respuesta do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ ->
            respuesta = change(respuesta, changeset.changes)
            |> unique_constraint(:username, message: "Este nombre de usuario ya se encuentra en uso")
            cond do
              respuesta.changes == %{} -> {:error, add_error(changeset, :username, "El nombre de usuario debe ser diferente al acutal")}
              respuesta.changes != %{} -> Repo.update(respuesta)
            end
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end

  # Verifica si un usuario ha realizado alguna transacción.
  #
  # Esta función consulta la tabla de transacciones para determinar si el usuario
  # aparece como cuenta_origen o cuenta_destino en alguna transacción. Se utiliza
  # para prevenir la eliminación de usuarios que tienen historial de transacciones.
  #
  # ## Parámetros
  #
  # - `id_usuario` - ID del usuario a verificar
  #
  # ## Retorna
  #
  # - `true` - Si el usuario ha participado en al menos una transacción
  # - `false` - Si el usuario no ha realizado transacciones
  #
  # ## Ejemplos
  #
  #     ha_sido_usada?(1)
  #     #=> true (si el usuario 1 tiene transacciones)
  #
  #     ha_sido_usada?(99)
  #     #=> false (si el usuario 99 no tiene transacciones)
  defp ha_sido_usada?(id_usuario) do
    Ledger.Transaccion
    |> where([t], t.cuenta_origen_id == ^id_usuario)
    |> or_where([t], t.cuenta_destino_id == ^id_usuario)
    |> Repo.exists?()
  end

  # Elimina un usuario de la base de datos.
  #
  # Valida que el usuario exista y que no haya realizado transacciones antes de
  # permitir su eliminación. Esta restricción mantiene la integridad referencial
  # del sistema y preserva el historial de transacciones.
  #
  # ## Validaciones aplicadas
  #
  # - Campo obligatorio: id
  # - El ID debe existir en la base de datos
  # - El usuario no debe haber realizado transacciones
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID del usuario a eliminar
  #
  # ## Retorna
  #
  # - `{:ok, %Ledger.Usuario{}}` - Si se eliminó exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si hubo errores de validación, el ID no existe,
  #   o el usuario ha realizado transacciones
  #
  # ## Ejemplos
  #
  #     # Eliminación exitosa (usuario sin transacciones)
  #     changeset = cast(%Ledger.Usuario{}, %{id: 5}, [:id])
  #     borrar(changeset)
  #     #=> {:ok, %Ledger.Usuario{id: 5}}
  #
  #     # Error: usuario con transacciones
  #     changeset = cast(%Ledger.Usuario{}, %{id: 1}, [:id])
  #     borrar(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"No se puede borrar porque el usuario ha realizado transacciones", _}]}}
  #
  #     # Error: ID no existe
  #     changeset = cast(%Ledger.Usuario{}, %{id: 999}, [:id])
  #     borrar(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"El id proporcionado no existe", _}]}}
  defp borrar(changeset) do
    changeset = validate_required(changeset, [:id], message: "El flag " <> @headers.id <> " es obligatorio")

    cond do
      changeset.valid? == true ->
        usuario = Repo.get(Ledger.Usuario, get_field(changeset, :id))
        case usuario do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ ->
            case ha_sido_usada?(get_field(changeset, :id)) do
              true -> {:error, add_error(changeset, :id, "No se puede borrar porque el usuario ha realizado transacciones")}
              false -> Repo.delete(usuario)
            end
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end

  # Consulta y muestra los detalles de un usuario específico.
  #
  # Valida que el usuario exista y luego muestra sus detalles por pantalla
  # utilizando el módulo de Herramientas para el formateo.
  #
  # ## Validaciones aplicadas
  #
  # - Campo obligatorio: id
  # - El ID debe existir en la base de datos
  #
  # ## Parámetros
  #
  # - `changeset` - Changeset con el ID del usuario a consultar
  #
  # ## Retorna
  #
  # - `{:ok, resultado}` - Si se consultó y mostró exitosamente
  # - `{:error, Ecto.Changeset.t()}` - Si el ID no existe o hubo errores de validación
  #
  # ## Información mostrada
  #
  # - id: Identificador del usuario
  # - username: Nombre de usuario
  # - nacimiento: Fecha de nacimiento
  # - inserted_at: Fecha de creación
  # - updated_at: Fecha de última actualización
  #
  # ## Ejemplos
  #
  #     # Consulta exitosa
  #     changeset = cast(%Ledger.Usuario{}, %{id: 1}, [:id])
  #     ver(changeset)
  #     #=> {:ok, ...} # Muestra los detalles por pantalla
  #
  #     # Error: ID no existe
  #     changeset = cast(%Ledger.Usuario{}, %{id: 999}, [:id])
  #     ver(changeset)
  #     #=> {:error, %Ecto.Changeset{errors: [id: {"El id proporcionado no existe", _}]}}
  defp ver(changeset) do
    changeset = validate_required(changeset, [:id], message: "El flag " <> @headers.id <> " es obligatorio")

    cond do
      changeset.valid? == true ->
        user = Repo.get(Ledger.Usuario, get_field(changeset, :id))
        case user do
          nil -> {:error, add_error(changeset, :id, "El id proporcionado no existe")}
          _ -> Herramientas.mostrar_por_pantalla(Map.keys(@headers), [Map.from_struct(user)], changeset)
        end
      changeset.valid? == false -> {:error, changeset}
    end
  end
end
