module FotosMelon
  class Patente < ::ApplicationRecord
    self.table_name = "fotos_melon_patentes"

    has_many :fechas, class_name: "FotosMelon::FechaCarpeta",
                      foreign_key: :patente_id, dependent: :destroy

    validates :nombre, presence: true, uniqueness: { case_sensitive: false }
    validates :creado_por_id, presence: true

    before_validation :normalizar_nombre

    def total_fotos
      FotosMelon::Foto.joins(:fecha_carpeta)
                      .where(fotos_melon_fechas: { patente_id: id })
                      .count
    end

    private

    def normalizar_nombre
      self.nombre = nombre.to_s.strip.upcase if nombre.present?
    end
  end
end
