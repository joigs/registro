class RecordsController < ApplicationController
  # GET /records
  def index
    require 'httparty'
    require 'json'
    require "ostruct"

    base_url = 'https://vertical.chcert.cl/api/v1/facturacions'
    api_key    = ENV["VERTICAL_API_KEY"]

    meta_resp = HTTParty.get(
      base_url,
      headers: { 'X-API-KEY' => api_key },
      query:   { meta: 1 }
    )

    @filter_options =
      if meta_resp.code == 200
        JSON.parse(meta_resp.body)
      else
        { "anios" => [], "meses" => (1..12).to_a, "empresas" => [] }
      end
    query_params           = {}
    query_params[:year]    = params[:year]    if params[:year].present?
    query_params[:month]   = params[:month]   if params[:month].present?
    query_params[:empresa] = params[:empresa] if params[:empresa].present?

    response = HTTParty.get(
      base_url,
      headers: { "X-API-KEY" => api_key },
      query:   query_params
    )
    Rails.logger.info "META_STATUS=#{meta_resp.code}"
    Rails.logger.info "META_BODY=#{meta_resp.body.truncate(120)}"

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
            pesos:            to_pesos(f['precio'], f['fecha_inspeccion']),
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
        pesos:            to_pesos(f['precio'], f['fecha_inspeccion']),
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
      flash[:alert] = "Error al obtener las ventas de transporte vertical (#{response.code})."
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
      flash[:alert] = "Error al obtener las ventas de transporte vertical."
      redirect_to records_path
    end
  end


  private
  def to_pesos(precio_uf, fecha_str)
    return nil if precio_uf.blank? || fecha_str.blank?

    fecha = Date.parse(fecha_str) rescue nil
    return nil unless fecha

    iva   = Iva.find_by(year: fecha.year, month: fecha.month)
    return nil unless iva

    precio_uf.to_f * iva.valor
  end
end
