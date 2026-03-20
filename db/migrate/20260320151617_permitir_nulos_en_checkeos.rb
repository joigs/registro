class PermitirNulosEnCheckeos < ActiveRecord::Migration[7.1]
  def change
    columnas = [
      :completado, :corregido_fuera_de_fecha, :extintor, :kit_derrame,
      :botiquin, :gata, :cadenas, :llave_rueda, :antena_radio,
      :permiso_circulacion, :revision_tecnica, :soap, :alcohol,
      :protector_solar, :carpeta, :panos_limpieza, :conos,
      :radio_comunicacion, :espejo_inspeccion, :toldo, :pie_de_metro,
      :tintas, :arnes, :falta_diclofenaco_cant, :falta_guantes_cant,
      :falta_parche_curita_cant, :falta_gasa_cant, :falta_venda_cant,
      :falta_suero_cant, :falta_tela_adhesiva_cant, :falta_palitos_cant
    ]

    columnas.each do |col|
      change_column_default :check_checkeos, col, nil
      change_column_null :check_checkeos, col, true
    end
  end
end
