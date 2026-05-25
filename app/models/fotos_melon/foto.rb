module FotosMelon
  class Foto < ::ApplicationRecord
    self.table_name = "fotos_melon_fotos"

    belongs_to :fecha_carpeta, class_name: "FotosMelon::FechaCarpeta"
    has_one_attached :imagen

    validates :nombre, presence: true
    validates :subido_por_id, presence: true

    def tamano_bytes
      return 0 unless imagen.attached?
      imagen.byte_size
    end

    def nombre_descarga
      return nombre unless imagen.attached?
      ext = File.extname(imagen.filename.to_s)
      base = File.basename(nombre, File.extname(nombre))
      "#{base}#{ext}"
    end
  end
end
