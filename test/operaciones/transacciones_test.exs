defmodule Operaciones.TransaccionesTest do
  use ExUnit.Case
  alias Ledger.{Repo, Usuario, Transaccion, Moneda}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Moneda.changeset(:crear_moneda, %{nombre: "EUR", precio_dolar: 2})
    Moneda.changeset(:crear_moneda, %{nombre: "USD", precio_dolar: 1})
    Usuario.changeset(:crear_usuario, %{username: "Gabriel", nacimiento: "2003-07-14"})
    Usuario.changeset(:crear_usuario, %{username: "Alejandro", nacimiento: "2000-12-12"})

    moneda_usd = Repo.get_by!(Moneda, nombre: "EUR")
    moneda_eur = Repo.get_by!(Moneda, nombre: "USD")
    usuario_ga = Repo.get_by!(Usuario, username: "Gabriel")
    usuario_al = Repo.get_by!(Usuario, username: "Alejandro")

    Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: usuario_ga.id, moneda_origen_id: moneda_usd.id, monto: 100})
    Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: usuario_al.id, moneda_origen_id: moneda_eur.id, monto: 100})

    {:ok, usd: moneda_usd, eur: moneda_eur, gabriel: usuario_ga, alejandro: usuario_al}
  end

  test "Ok, alta cuenta", %{eur: moneda, gabriel: usuario} do
    res = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: usuario.id, moneda_origen_id: moneda.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, swap", %{eur: eur, usd: usd, gabriel: usuario} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: usuario.id, moneda_origen_id: usd.id, moneda_destino_id: eur.id, monto: 10})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, transferencia", %{usd: cuenta, gabriel: gabriel, alejandro: alejandro} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: gabriel.id, cuenta_destino_id: alejandro.id, moneda_origen_id: cuenta.id, monto: 10})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, deshacer", %{gabriel: cuenta, usd: moneda} do
    transaccion = Repo.get_by!(Transaccion, %{tipo: "alta_cuenta", cuenta_origen_id: cuenta.id, moneda_origen_id: moneda.id})
    res = Transaccion.changeset(:deshacer_transaccion, %{id: transaccion.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Ok, ver", %{gabriel: cuenta, usd: moneda} do
    transaccion = Repo.get_by!(Transaccion, %{tipo: "alta_cuenta", cuenta_origen_id: cuenta.id, moneda_origen_id: moneda.id})
    res = Transaccion.changeset(:ver_transaccion, %{id: transaccion.id})

    assert res == {:ok, "Operación realizada con exito"}
  end

  test "Error, casteo de datos id" do
    res_deshacer = Transaccion.changeset(:deshacer_transaccion, %{id: "uno"})
    res_ver = Transaccion.changeset(:ver_transaccion, %{id: "uno"})

    assert res_deshacer == {:error, deshacer_transaccion: "El id debe ser un número entero"}
    assert res_ver == {:error, ver_transaccion: "El id debe ser un número entero"}
  end

  test "Error, casteo de datos moneda origen" do
    res_alta = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: 1, moneda_origen_id: "uno"})
    res_swap = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: 1, moneda_origen_id: "uno", moneda_destino_id: 2, monto: 10})
    res_transferencia = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: 1, cuenta_destino_id: 2, moneda_origen_id: "uno", monto: 10})

    assert res_alta == {:error, alta_cuenta: "La moneda o moneda de origen debe ser un número entero"}
    assert res_swap == {:error, realizar_swap: "La moneda o moneda de origen debe ser un número entero"}
    assert res_transferencia == {:error, realizar_transferencia: "La moneda o moneda de origen debe ser un número entero"}
  end

  test "Error, casteo de datos moneda destino" do
    res_swap = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: 1, moneda_origen_id: 2, moneda_destino_id: "uno", monto: 10})
    res_transferencia = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: 1, cuenta_destino_id: 2, moneda_origen_id: 2, moneda_destino_id: "uno", monto: 10})

    assert res_swap == {:error, realizar_swap: "La moneda de destino debe ser un número entero"}
    assert res_transferencia == {:error, realizar_transferencia: "La moneda de destino debe ser un número entero"}
  end

  test "Error, casteo de datos monto" do
    res_alta = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: 1, moneda_origen_id: 2, monto: "diez"})
    res_swap = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: 1, moneda_origen_id: 2, moneda_destino_id: 3, monto: "diez"})
    res_transferencia = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: 1, cuenta_destino_id: 2, moneda_origen_id: 3, monto: "diez"})

    assert res_alta == {:error, alta_cuenta: "El monto debe ser un numero decimal"}
    assert res_swap == {:error, realizar_swap: "El monto debe ser un numero decimal"}
    assert res_transferencia == {:error, realizar_transferencia: "El monto debe ser un numero decimal"}
  end

  test "Error, casteo de datos cuenta origen" do
    res_alta = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: "uno", moneda_origen_id: 2, monto: 10})
    res_swap = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: "uno", moneda_origen_id: 2, moneda_destino_id: 3, monto: 10})
    res_transferencia = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: "uno", cuenta_destino_id: 2, moneda_origen_id: 3, monto: 10})

    assert res_alta == {:error, alta_cuenta: "El usuario o cuenta de origen debe ser un número entero"}
    assert res_swap == {:error, realizar_swap: "El usuario o cuenta de origen debe ser un número entero"}
    assert res_transferencia == {:error, realizar_transferencia: "El usuario o cuenta de origen debe ser un número entero"}
  end

  test "Error, casteo de datos cuenta destino" do
    res_transferencia = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: 1, cuenta_destino_id: "uno", moneda_origen_id: 3, monto: 10})

    assert res_transferencia == {:error, realizar_transferencia: "La cuenta de destino debe ser un número entero"}
  end

  test "Error, operaciones con datos faltantes" do
    res_alta = Transaccion.changeset(:alta_cuenta, %{})
    res_swap = Transaccion.changeset(:realizar_swap, %{})
    res_transferencia = Transaccion.changeset(:realizar_transferencia, %{})
    res_deshacer = Transaccion.changeset(:deshacer_transaccion, %{})
    res_ver = Transaccion.changeset(:ver_transaccion, %{})

    assert res_alta == {:error, alta_cuenta: "Los flags -u, -m son obligatorios"}
    assert res_swap == {:error, realizar_swap: "Los flags -a, -mo, -md, -u son obligatorios"}
    assert res_transferencia == {:error, realizar_transferencia: "Los flags -a, -o, -d, -m son obligatorios"}
    assert res_deshacer == {:error, deshacer_transaccion: "El flag -id es obligatorio"}
    assert res_ver == {:error, ver_transaccion: "El flag -id es obligatorio"}
  end

  test "Error, alta cuenta monto negativo" do
    res = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: 1, moneda_origen_id: 2, monto: -10})

    assert res == {:error, alta_cuenta: "El valor del monto debe ser un número positivo"}
  end

  test "Error, alta cuenta la cuenta no esta dada de alta en la base de datos" do
    res = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: 999, moneda_origen_id: 2, monto: 10})

    assert res == {:error, alta_cuenta: "Esta moneda no esta dada de alta en la base de datos"}
  end

  test "Error, swap la moneda no esta dada de alta en la base de datos", %{gabriel: cuenta, eur: moneda_destino} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: 99, moneda_destino_id: moneda_destino.id, monto: 10})

    assert res == {:error, realizar_swap: "Esta moneda origen id no esta dada de alta en la base de datos"}
  end

  test "Error, alta cuenta ya se hizo una alta para esa moneda en esa cuenta", %{gabriel: cuenta, usd: moneda} do
    res = Transaccion.changeset(:alta_cuenta, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda.id, monto: 10})

    assert res == {:error, alta_cuenta: "Ya se ha hecho un alta de esta moneda"}
  end

  test "Error, swap la cuenta no esta dada de alta en la base de datos", %{usd: moneda_origen, eur: moneda_destino} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: 99, moneda_origen_id: moneda_origen.id, moneda_destino_id: moneda_destino.id, monto: 10})

    assert res == {:error, realizar_swap: "Esta cuenta origen id no esta dada de alta en la base de datos"}
  end

  test "Error, swap la moneda de origen no esta dada de alta en la base de datos", %{gabriel: cuenta, eur: moneda_destino} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: 99, moneda_destino_id: moneda_destino.id, monto: 10})

    assert res == {:error, realizar_swap: "Esta moneda origen id no esta dada de alta en la base de datos"}
  end

  test "Error, swap la moneda de destino no esta dada de alta en la base de datos", %{gabriel: cuenta, usd: moneda_origen} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda_origen.id, moneda_destino_id: 99, monto: 10})

    assert res == {:error, realizar_swap: "Esta moneda destino id no esta dada de alta en la base de datos"}
  end

  test "Error, swap la moneda de destino debe ser diferente a la moneda de origen", %{gabriel: cuenta, usd: moneda_origen} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda_origen.id, moneda_destino_id: moneda_origen.id, monto: 10})

    assert res == {:error, realizar_swap: "La moneda de origen debe ser diferente a la moneda de destino"}
  end

  test "Error, swap el valor del monto debe ser un número positivo", %{gabriel: cuenta, usd: moneda_origen, eur: moneda_destino} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda_origen.id, moneda_destino_id: moneda_destino.id, monto: -10})

    assert res == {:error, realizar_swap: "El valor del monto debe ser mayor o igual a 0.1"}
  end

  test "Error, swap esta moneda no ha sido dada de alta en esta cuenta", %{gabriel: cuenta, eur: moneda_destino, usd: moneda_origen} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda_destino.id, moneda_destino_id: moneda_origen.id, monto: 10})

    assert res == {:error, realizar_swap: "Esta moneda no ha sido dada de alta en esta cuenta"}
  end

  test "Error, swap fondos insuficientes", %{gabriel: cuenta, usd: moneda_origen, eur: moneda_destino} do
    res = Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda_origen.id, moneda_destino_id: moneda_destino.id, monto: 1000})

    assert res == {:error, realizar_swap: "No tienes fondos suficientes para hacer esta transacción"}
  end

  test "Error, transferencia la cuenta de origen no esta dada de alta en la base de datos", %{usd: moneda_origen, alejandro: cuenta_destino} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: 99, moneda_origen_id: moneda_origen.id, cuenta_destino_id: cuenta_destino.id, monto: 10})

    assert res == {:error, realizar_transferencia: "Esta cuenta origen id no esta dada de alta en la base de datos"}
  end

  test "Error, transferencia la cuenta de destino no esta dada de alta en la base de datos", %{gabriel: cuenta_origen, usd: moneda_origen} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, cuenta_destino_id: 99, monto: 10})

    assert res == {:error, realizar_transferencia: "Esta cuenta destino id no esta dada de alta en la base de datos"}
  end

  test "Error, transferencia la moneda de origen no esta dada de alta en la base de datos", %{gabriel: cuenta_origen, alejandro: cuenta_destino} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: 99, cuenta_destino_id: cuenta_destino.id, monto: 10})

    assert res == {:error, realizar_transferencia: "Esta moneda origen id no esta dada de alta en la base de datos"}
  end

  test "Error, transferencia no se puede hacer transferencia a la misma cuenta", %{gabriel: cuenta_origen, usd: moneda_origen} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, cuenta_destino_id: cuenta_origen.id, monto: 10})

    assert res == {:error, realizar_transferencia: "La cuenta de origen debe ser diferente a la cuenta de destino"}
  end

  test "Error, transferencia el valor del monto debe ser un número positivo", %{gabriel: cuenta_origen, usd: moneda_origen, alejandro: cuenta_destino} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, cuenta_destino_id: cuenta_destino.id, monto: -10})

    assert res == {:error, realizar_transferencia: "El valor del monto debe ser mayor o igual a 0.1"}
  end

  test "Error, transferencia esta moneda no ha sido dada de alta en esta cuenta", %{gabriel: cuenta, alejandro: cuenta_destino, eur: moneda_destino} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta.id, moneda_origen_id: moneda_destino.id, cuenta_destino_id: cuenta_destino.id, monto: 10})

    assert res == {:error, realizar_transferencia: "Esta moneda no ha sido dada de alta en esta cuenta"}
  end

  test "Error, transferencia fondos insuficientes", %{gabriel: cuenta_origen, usd: moneda_origen, alejandro: cuenta_destino} do
    res = Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, cuenta_destino_id: cuenta_destino.id, monto: 1000})

    assert res == {:error, realizar_transferencia: "No tienes fondos suficientes para hacer esta transacción"}
  end

  test "Error, deshacer transaccion id no existe" do
    res = Transaccion.changeset(:deshacer_transaccion, %{id: 999})

    assert res == {:error, deshacer_transaccion: "El id proporcionado no existe"}
  end


  test "Error, deshacer transaccion no es la ultima del usuario o usuarios de la transaccion", %{gabriel: cuenta_origen, usd: moneda_origen, alejandro: cuenta_destino, eur: moneda_destino} do
    Transaccion.changeset(:realizar_transferencia, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, cuenta_destino_id: cuenta_destino.id, monto: 10})
    Transaccion.changeset(:realizar_swap, %{cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, moneda_destino_id: moneda_destino.id, monto: 10})
    transaccion = Repo.get_by!(Transaccion, %{tipo: "transferencia", cuenta_origen_id: cuenta_origen.id, moneda_origen_id: moneda_origen.id, cuenta_destino_id: cuenta_destino.id, monto: 10})
    res = Transaccion.changeset(:deshacer_transaccion, %{id: transaccion.id})

    assert res == {:error, deshacer_transaccion: "No se puede borrar porque esta no es la ultima transaccion"}
  end

  test "Error, ver transaccion id no existe" do
    res = Transaccion.changeset(:ver_transaccion, %{id: 999})

    assert res == {:error, ver_transaccion: "El id proporcionado no existe"}
  end

end
