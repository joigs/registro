module FotosMelon
  class FechaCarpeta < ::ApplicationRecord
    self.table_name = "fotos_melon_fechas"

    belongs_to :patente, class_name: "FotosMelon::Patente"
    has_many :fotos, class_name: "FotosMelon::Foto",
                     foreign_key: :fecha_carpeta_id, dependent: :destroy

    validates :fecha, presence: true
    validates :fecha, uniqueness: { scope: :patente_id }
    validates :creado_por_id, presence: true

    def nombre_mostrado
      nombre_personalizado.presence || fecha.strftime("%d/%m/%Y")
    end
  end
end
