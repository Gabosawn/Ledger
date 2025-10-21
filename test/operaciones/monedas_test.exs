defmodule Operaciones.MonedasTest do
  use ExUnit.Case
  alias Ledger.{Repo, Usuario, Transaccion, Moneda}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Moneda.changeset(:crear_moneda, %{nombre: "EUR", precio_dolar: 2})

    {:ok, moneda: Repo.get_by!(Moneda, nombre: "EUR")}
  end

  test "Ok, crear moneda" do
    res = Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: 1})
    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, editar moneda", %{moneda: moneda} do
    res = Moneda.changeset(:editar_moneda, %{id: moneda.id, precio_dolar: 1.5})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, ver moneda", %{moneda: moneda} do
    res = Moneda.changeset(:ver_moneda, %{id: moneda.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, borrar moneda", %{moneda: moneda} do
    res = Moneda.changeset(:borrar_moneda, %{id: moneda.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Error, casteo del dato precio dolar" do
    res_crear = Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: "catorce"})
    res_editar = Moneda.changeset(:editar_moneda, %{id: 1, precio_dolar: "catorce"})

    assert res_crear == {:error, crear_moneda: "El precio dolar debe ser un numero decimal"}
    assert res_editar == {:error, editar_moneda: "El precio dolar debe ser un numero decimal"}
  end

  test "Error, casteo del dato id" do
    res_ver = Moneda.changeset(:ver_moneda, %{id: "uno"})
    res_borrar = Moneda.changeset(:borrar_moneda, %{id: "uno"})
    res_editar = Moneda.changeset(:editar_moneda, %{id: "uno", precio_dolar: 2})


    assert res_ver == {:error, ver_moneda: "El id debe ser un número entero"}
    assert res_borrar == {:error, borrar_moneda: "El id debe ser un número entero"}
    assert res_editar == {:error, editar_moneda: "El id debe ser un número entero"}
  end

  test "Error, datos faltantes en cada operacion" do
    res_ver = Moneda.changeset(:ver_moneda, %{})
    res_crear = Moneda.changeset(:crear_moneda, %{nombre: "USD"})
    res_borrar = Moneda.changeset(:borrar_moneda, %{})
    res_editar = Moneda.changeset(:editar_moneda, %{precio_dolar: 2})


    assert res_ver == {:error, ver_moneda: "El flag -id es obligatorio"}
    assert res_crear == {:error, crear_moneda: "Los flags -n, -p son obligatorios"}
    assert res_borrar == {:error, borrar_moneda: "El flag -id es obligatorio"}
    assert res_editar == {:error, editar_moneda: "Los flags -id, -p son obligatorios"}
  end

  test "Error, precio positivo en operaciones crear y editar" do
    res_crear = Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: -1})
    res_editar = Moneda.changeset(:editar_moneda, %{id: 1, precio_dolar: -2})

    assert res_crear == {:error, crear_moneda: "El valor del precio en dolar debe ser un número positivo"}
    assert res_editar == {:error, editar_moneda: "El valor del precio en dolar debe ser un número positivo"}
  end

  test "Error, crear moneda nombre con 3 a 4 letras" do
    res_crear = Moneda.changeset(:crear_moneda, %{nombre: "PR", precio_dolar: "12"})

    assert res_crear == {:error, crear_moneda: "El nombre de la moneda debe ser de 3 o 4 letras"}
  end

  test "Error, crear moneda nombre completamente en mayúsculas" do
    res_crear = Moneda.changeset(:crear_moneda, %{nombre: "usd", precio_dolar: "12"})

    assert res_crear == {:error, crear_moneda: "El nombre de la moneda debe estar completamente en mayúsculas"}
  end

  test "Error, crear moneda nombre usado" do
    res_crear = Moneda.changeset(:crear_moneda, %{nombre: "EUR", precio_dolar: "12"})

    assert res_crear == {:error, crear_moneda: "Este nombre de moneda ya se encuentra en uso"}
  end

  test "Error, no existe el id de la moneda" do
    res_ver = Moneda.changeset(:ver_moneda, %{id: 10})
    res_borrar = Moneda.changeset(:borrar_moneda, %{id: 10})
    res_editar = Moneda.changeset(:editar_moneda, %{id: 10, precio_dolar: 10})

    assert res_ver == {:error, ver_moneda: "El id proporcionado no existe"}
    assert res_borrar == {:error, borrar_moneda: "El id proporcionado no existe"}
    assert res_editar == {:error, editar_moneda: "El id proporcionado no existe"}
  end

  test "Error, borrar moneda que ha sido usada", %{moneda: moneda} do
    Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: "2003-12-12"})
    usuario = Repo.get_by!(Usuario, username: "Gabriel")
    Transaccion.changeset(:alta_cuenta, %{moneda_origen_id: moneda.id, cuenta_origen_id: usuario.id})

    res_borrar = Moneda.changeset(:borrar_moneda, %{id: moneda.id})

    assert res_borrar == {:error, borrar_moneda: "No se puede borrar porque la moneda ha sido usada"}
  end

  test "Error, editar moneda el precio de la moneda debe ser diferente al actual", %{moneda: moneda} do
    res_editar = Moneda.changeset(:editar_moneda, %{id: moneda.id, precio_dolar: 2})

    assert res_editar == {:error, editar_moneda: "El precio de la moneda debe ser diferente al acutal"}
  end
end
