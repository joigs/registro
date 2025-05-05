class RecordsController < ApplicationController
  # GET /records
  def index
    require 'httparty'
    require 'json'

    base_url = 'https://vertical.chcert.cl/api/v1/facturacions'

    query_params = {}
    query_params[:year]    = params[:year]    if params[:year].present?
    query_params[:month]   = params[:month]   if params[:month].present?
    query_params[:empresa] = params[:empresa] if params[:empresa].present?

    response = HTTParty.get(
      base_url,
      headers: { 'X-API-KEY' => ENV['VERTICAL_API_KEY'] },
      query:   query_params
    )

    require 'ostruct'

    @facturacions =
      if response.code == 200
        JSON.parse(response.body).map do |f|
          OpenStruct.new(
            id:               f['id'],
            number:           f['number'],
            name:             f['name'],
            solicitud:        f['solicitud'],
            emicion:          f['emicion'],
            entregado:        f['entregado'],
            resultado:        f['resultado'],
            oc:               f['oc'],
            fecha_entrega: f['fecha_entrega'],
            factura:          f['factura'],
            fecha_inspeccion: f['fecha_inspeccion'],
            empresa:          f['empresa'],
            precio:           f['precio'],
            inspections:      (f['inspections'] || []).map do |i|
              OpenStruct.new(
                id:    i['id'],
                ins_date: i['ins_date'],
                state: i['state'],
                principal: i['principal'],
                comuna: i['comuna'],
                region: i['region']
              )
            end
          )
        end
      else
        []
      end

  end



  def show
    require 'httparty'
    require 'json'
    require 'ostruct'

    url = "https://vertical.chcert.cl/api/v1/facturacions/#{params[:id]}"
    response = HTTParty.get(
      url,
      headers: { 'X-API-KEY' => ENV['VERTICAL_API_KEY'] }
    )

    if response.code == 200
      f = JSON.parse(response.body)

      @facturacion = OpenStruct.new(
        id:               f['id'],
        number:           f['number'],
        name:             f['name'],
        solicitud:        f['solicitud'],
        emicion:          f['emicion'],
        entregado:        f['entregado'],
        resultado:        f['resultado'],
        oc:               f['oc'],
        fecha_entrega:    f['fecha_entrega'],
        factura:          f['factura'],
        fecha_inspeccion: f['fecha_inspeccion'],
        empresa:          f['empresa'],
        precio:           f['precio'],
        inspections:      (f['inspections'] || []).map do |i|
          OpenStruct.new(
            id:        i['id'],
            ins_date:  i['ins_date'],
            state:     i['state'],
            principal: i['principal'],
            comuna:    i['comuna'],
            region:    i['region']
          )
        end
      )
    else
      flash[:alert] = "Error al obtener la facturación del API (#{response.code})."
      redirect_to records_path
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
