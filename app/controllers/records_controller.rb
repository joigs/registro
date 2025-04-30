class RecordsController < ApplicationController
  # GET /records
  def index
    require 'httparty'
    require 'json'

    base_url = 'https://vertical.chcert.cl/api/v1/facturacions'

    year    = params[:year]
    month   = params[:month]
    empresa = params[:empresa]

    query_params = {}
    query_params[:year]    = year    if year.present?
    query_params[:month]   = month   if month.present?
    query_params[:empresa] = empresa if empresa.present?

    response = HTTParty.get(
      base_url,
      headers: { 'X-API-KEY' => ENV['VERTICAL_API_KEY'] },
      query:   query_params
    )


    if response.code == 200
      raw_data = JSON.parse(response.body)

      @facturacions = raw_data.map do |f|
        {
          id: f["id"],
          numero: f["number"],
          fecha_inspeccion: f["fecha_inspeccion"],
          empresa: f["empresa"],
          inspecciones: (f["inspections"] || []).map do |i|
            {
              id: i["id"],
              fecha: i["ins_date"],
              principal: i["principal"]
            }
          end
        }
      end
    else
      @facturacions = []
      puts "Error: #{response.code} - #{response.body}"
    end

  end


  def show
    require 'httparty'
    require 'json'

    url = "https://vertical.chcert.cl/api/v1/facturacions/#{params[:id]}"
    response = HTTParty.get(
      url,
      headers: { 'X-API-KEY' => ENV['VERTICAL_API_KEY'] },

    )

    if response.code == 200
      raw_data = JSON.parse(response.body)

      @facturacion = {
        id: raw_data["id"],
        numero: raw_data["number"],
        fecha_inspeccion: raw_data["fecha_inspeccion"],
        empresa: raw_data["empresa"],
        inspecciones: (raw_data["inspections"] || []).map do |i|
          {
            id: i["id"],
            fecha: i["ins_date"],
            principal: i["principal"]
          }
        end
      }
    else
      @facturacion = nil
      puts "Error: #{response.code} - #{response.body}"
    end
  end

  # GET /records/export_excel
  def export_excel
    require 'httparty'
    require 'json'

    base_url = 'https://vertical.chcert.cl/api/v1/facturacions'

    # Mismos parámetros
    year    = params[:year]
    month   = params[:month]
    empresa = params[:empresa]

    query_params = {}
    query_params[:year]    = year    if year.present?
    query_params[:month]   = month   if month.present?
    query_params[:empresa] = empresa if empresa.present?

    response = HTTParty.get(
      base_url,
      headers: { 'X-API-KEY' => ENV['VERTICAL_API_KEY'] },
      query:   query_params
    )

    if response.code == 200
      facturaciones = JSON.parse(response.body)


      data_json = facturaciones.to_json

      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      output_file = Rails.root.join("tmp", "facturaciones_#{timestamp}.xlsx")

      system(
        "facturas/bin/python",
        Rails.root.join("app", "scripts", "generate_excel.py").to_s,
        data_json,
        output_file.to_s
      )

      send_file output_file, filename: "facturaciones_#{timestamp}.xlsx"

    else
      flash[:alert] = "Error al obtener facturaciones del API."
      redirect_to records_path
    end
  end
end
