class RecordsController < ApplicationController
  # GET /records
  require 'httparty'
  require 'json'
  require "ostruct"
  require 'bigdecimal'
  require 'bigdecimal/util'
  require 'open3'

  def index


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
            number:   i['number'],
            name:     i['name'],
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
    base_url = 'https://vertical.chcert.cl/api/v1/facturacions'
    year     = params[:year]
    month    = params[:month]
    empresa  = params[:empresa]

    # Armar query
    query_params = {}
    query_params[:year]    = year    if year.present?
    query_params[:month]   = month   if month.present?
    query_params[:empresa] = empresa if empresa.present?

    # Llamada a la API
    response = HTTParty.get(
      base_url,
      headers: { 'X-API-KEY' => ENV['VERTICAL_API_KEY'] },
      query:   query_params
    )

    if response.code == 200
      raw = JSON.parse(response.body)

      facturaciones = raw.map do |f|
        inspecciones = (f['inspections'] || [])
        total_ins    = inspecciones.size
        cerradas     = inspecciones.count { |i| i['state'] == 'Cerrado' }
        # Ubicación: "Región. Comuna xN" o sin "x1"
        ubicaciones = inspecciones
                        .group_by { |i| [i['region'], i['comuna']] }
                        .map { |(r,c), arr| arr.size > 1 ? "#{r}. #{c} x#{arr.size}" : "#{r}. #{c}" }
                        .join(' | ')

        {
          number:                   f['number'],
          name:                     f['name'],
          fecha_inspeccion:         f['fecha_inspeccion'],
          inspecciones_completadas: "#{cerradas}/#{total_ins}",
          fecha_entrega:            f['fecha_entrega'],
          factura:                  f['factura'],
          precio:                   f['precio'],
          ubicacion:                ubicaciones,
          empresa:                  f['empresa'],
          pesos:                    to_pesos(f['precio'], f['fecha_inspeccion'])
        }
      end

      data_json   = facturaciones.to_json
      timestamp   = Time.now.strftime("%Y%m%d_%H%M%S")
      output_dir  = Rails.root.join("tmp")
      FileUtils.mkdir_p(output_dir)
      output_file = output_dir.join("facturaciones_#{timestamp}.xlsx").to_s
      script_path = Rails.root.join("app","scripts","generate_excel.py").to_s

      stdout, stderr, status = Open3.capture3(
        "python3", script_path,
        data_json, output_file
      )

      Rails.logger.info  "generate_excel stdout: #{stdout}"
      Rails.logger.error "generate_excel stderr: #{stderr}" if stderr.present?

      if status.success? && File.exist?(output_file)
        send_file output_file,
                  filename: "facturaciones_#{timestamp}.xlsx",
                  disposition: 'attachment'
      else
        flash[:alert] = "Error al generar el archivo Excel. Revisa los logs del servidor."
        redirect_to records_path
      end
    else
      flash[:alert] = "Error al obtener las ventas de transporte vertical (#{response.code})."
      redirect_to records_path
    end
  end




  private


  def to_pesos(precio_uf, fecha_str)
    return nil if precio_uf.blank? || fecha_str.blank?

    fecha = Date.parse(fecha_str) rescue nil
    return nil unless fecha

    iva = Iva.find_by(year: fecha.year, month: fecha.month)
    return nil unless iva

    total = precio_uf.to_d * iva.valor.to_d

    total.round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

end
