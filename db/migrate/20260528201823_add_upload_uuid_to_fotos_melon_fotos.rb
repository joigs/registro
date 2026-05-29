  class AddUploadUuidToFotosMelonFotos < ActiveRecord::Migration[7.1]
    def change
      add_column :fotos_melon_fotos, :upload_uuid, :string, limit: 64
      add_index  :fotos_melon_fotos, [:fecha_carpeta_id, :upload_uuid],
                 unique: true,
                 where: "upload_uuid IS NOT NULL",
                 name: "idx_fotos_melon_fotos_upload_uuid_por_fecha"
    end
end
