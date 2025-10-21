defmodule Operaciones.UsuariosTest do
  use ExUnit.Case
  alias Estructuras.Moneda
  alias Ledger.{Repo, Usuario, Transaccion, Moneda}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: "2003-07-14"})

    {:ok, usuario: Repo.get_by!(Usuario, username: "Gabriel")}
  end

  test "Ok, crear usuario" do
    res = Usuario.changeset(:crear_usuario, %{username: "Heinly", nacimiento: "2002-11-30"})
    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, editar usuario", %{usuario: usuario} do
    res = Usuario.changeset(:editar_usuario, %{id: usuario.id, username: "Alejandro"})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, ver usuario", %{usuario: usuario} do
    res = Usuario.changeset(:ver_usuario, %{id: usuario.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, borrar usuario", %{usuario: usuario} do
    res = Usuario.changeset(:borrar_usuario, %{id: usuario.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Error, casteo del dato nacimiento" do
    res_crear = Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: "2003-7-1"})

    assert res_crear == {:error, crear_usuario: "La fecha de nacimiento debe tener este formato 1999-05-06"}
  end

  test "Error, casteo del dato id" do
    res_ver = Usuario.changeset(:ver_usuario, %{id: "uno"})
    res_borrar = Usuario.changeset(:borrar_usuario, %{id: "uno"})
    res_editar = Usuario.changeset(:editar_usuario, %{id: "uno", username: "Juanito"})


    assert res_ver == {:error, ver_usuario: "El id debe ser un número entero"}
    assert res_borrar == {:error, borrar_usuario: "El id debe ser un número entero"}
    assert res_editar == {:error, editar_usuario: "El id debe ser un número entero"}
  end

  test "Error, datos faltantes en cada operacion" do
    res_ver = Usuario.changeset(:ver_usuario, %{})
    res_crear = Usuario.changeset(:crear_usuario, %{username: "Juanito"})
    res_borrar = Usuario.changeset(:borrar_usuario, %{})
    res_editar = Usuario.changeset(:editar_usuario, %{})


    assert res_ver == {:error, ver_usuario: "El flag -id es obligatorio"}
    assert res_crear == {:error, crear_usuario: "Los flags -n, -b son obligatorios"}
    assert res_borrar == {:error, borrar_usuario: "El flag -id es obligatorio"}
    assert res_editar == {:error, editar_usuario: "Los flags -id, -n son obligatorios"}
  end

  test "Error, nombre de 5 a 20 letras en operaciones crear y editar" do
    res_crear = Usuario.changeset(:crear_usuario, %{username: "Luis", nacimiento: "2003-07-14"})
    res_editar = Usuario.changeset(:editar_usuario, %{id: 1, username: "René"})

    assert res_crear == {:error, crear_usuario: "El nombre de usuario debe tener como mínimo  #{5} letras y máximo  #{20} letras"}
    assert res_editar == {:error, editar_usuario: "El nombre de usuario debe tener como mínimo  #{5} letras y máximo  #{20} letras"}
  end

  test "Error, crear usuario mayor de 18 años" do
    res_crear = Usuario.changeset(:crear_usuario, %{username: "JuanitoAlcachofa", nacimiento: "2010-10-10"})

    assert res_crear == {:error, crear_usuario: "El usuario debe ser mayor de 18 años"}
  end

  test "Error, username usado en operaciones crear y editar", %{usuario: usuario} do
    Usuario.changeset(:crear_usuario, %{username: "Jenny", nacimiento: "2003-07-14"})

    res_crear = Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: "2003-07-14"})
    res_editar = Usuario.changeset(:editar_usuario, %{id: usuario.id, username: "Jenny"})

    assert res_crear == {:error, crear_usuario: "Este nombre de usuario ya se encuentra en uso"}
    assert res_editar == {:error, editar_usuario: "Este nombre de usuario ya se encuentra en uso"}
  end

  test "Error, no existe el id del usuario" do
    res_ver = Usuario.changeset(:ver_usuario, %{id: 10})
    res_borrar = Usuario.changeset(:borrar_usuario, %{id: 10})
    res_editar = Usuario.changeset(:editar_usuario, %{id: 10, username: "GABRIEL"})

    assert res_ver == {:error, ver_usuario: "El id proporcionado no existe"}
    assert res_borrar == {:error, borrar_usuario: "El id proporcionado no existe"}
    assert res_editar == {:error, editar_usuario: "El id proporcionado no existe"}
  end

  test "Error, borrar usuario que ha sido usado", %{usuario: usuario} do
    Moneda.changeset(:crear_moneda, %{nombre: "HEIN", precio_dolar: 5})
    moneda = Repo.get_by!(Moneda, nombre: "HEIN")
    Transaccion.changeset(:alta_cuenta, %{moneda_origen_id: moneda.id, cuenta_origen_id: usuario.id})

    res_borrar = Usuario.changeset(:borrar_usuario, %{id: usuario.id})

    assert res_borrar == {:error, borrar_usuario: "No se puede borrar porque el usuario ha realizado transacciones"}
  end

  test "Error, editar usuario el nombre de usuario debe ser diferente al actual", %{usuario: usuario} do
    res_editar = Usuario.changeset(:editar_usuario, %{id: usuario.id, username: "Gabriel"})

    assert res_editar == {:error, editar_usuario: "El nombre de usuario debe ser diferente al acutal"}
  end
end
