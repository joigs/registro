# app/controllers/records_controller.rb
class RecordsController < ApplicationController
  require "httparty"
  require "json"
  require "ostruct"
  require "bigdecimal"
  require "bigdecimal/util"

  VERTICAL_URL = "https://vertical.chcert.cl/api/v1/facturacions".freeze
  VERTICAL_KEY = ENV.fetch("VERTICAL_API_KEY", "")

  EVAL_URL = ENV.fetch(
    "EVALUACION_API_URL",
    "http://137.184.74.221:8082/api/v1/facturacions"
  ).freeze
  EVAL_KEY = ENV.fetch("EVALUACION_API_KEY", "")

  def index
    query = build_query

    meta_resp = HTTParty.get(VERTICAL_URL, headers: { "X-API-KEY" => VERTICAL_KEY },
                             query:   { meta: 1 })
    @filter_options =
      meta_resp.code == 200 ? JSON.parse(meta_resp.body)
        : { "anios" => [], "meses" => (1..12).to_a, "empresas" => [] }

    fact_resp      = api_get(VERTICAL_URL, VERTICAL_KEY, query)
    @facturacions  = fact_resp.code == 200 ? parse_facturacions(JSON.parse(fact_resp.body)) : []

    eval_resp = api_get(EVAL_URL, EVAL_KEY, query)

    if eval_resp.code == 200
      body = JSON.parse(eval_resp.body)


      if body.is_a?(Hash)
        @evaluacions = parse_evaluacions(body["facturacions"] || [])
        @current_oxy = parse_oxy(body["current_oxy"]) if body["current_oxy"].present?
      else
        @evaluacions = parse_evaluacions(body)
        @current_oxy = nil
      end
    else
      @evaluacions = []
      @current_oxy = nil
    end


    puts("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    puts(@evaluacions.inspect)
    puts("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    puts(@current_oxy.inspect)

  end
  # -------------------------------------------------------------------------
  private
  # -------------------------------------------------------------------------

  def build_query
    {}.tap do |q|
      q[:year]    = params[:year]    if params[:year].present?
      q[:month]   = params[:month]   if params[:month].present?
      q[:empresa] = params[:empresa] if params[:empresa].present?
    end
  end

  def api_get(url, key, query = {})
    HTTParty.get(url,
                 headers: { "X-API-KEY" => key, "Accept" => "application/json" },
                 query:   query, timeout: 5)
  rescue HTTParty::Error, Net::OpenTimeout => e
    Rails.logger.error("[API] #{e.class}: #{e.message}")
    OpenStruct.new(code: 503, body: nil)
  end


  def parse_facturacions(arr)
    Array(arr).map do |f|
      OpenStruct.new(
        id:               f["id"],
        number:           f["number"],
        name:             f["name"],
        solicitud:        f["solicitud"],
        emicion:          f["emicion"],
        entregado:        f["entregado"],
        resultado:        f["resultado"],
        oc:               f["oc"],
        fecha_entrega:    f["fecha_entrega"],
        factura:          f["factura"],
        fecha_inspeccion: f["fecha_inspeccion"],
        empresa:          f["empresa"],
        precio:           f["precio"],
        pesos:            to_pesos(f["precio"], f["fecha_inspeccion"]),
        inspections:      Array(f["inspections"]).map do |i|
          OpenStruct.new(
            id:        i["id"],
            ins_date:  i["ins_date"],
            state:     i["state"],
            principal: i["principal"],
            comuna:    i["comuna"],
            region:    i["region"]
          )
        end
      )
    end
  end

  def parse_evaluacions(arr)
    Array(arr).map do |f|
      OpenStruct.new(
        id:               f["id"],
        number:           f["number"],
        name:             f["name"],
        solicitud:        f["solicitud"],
        emicion:          f["emicion"],
        entregado:        f["entregado"],
        resultado:        f["resultado"],
        oc:               f["oc"],
        factura:          f["factura"],
        fecha_inspeccion: f["fecha_inspeccion"],
        precio:           f["precio"],
        pesos:            to_pesos(f["precio"], f["fecha_inspeccion"]),
        created_at:       f["created_at"],
        updated_at:       f["updated_at"]
      )
    end
  end

  def parse_oxy(data)
    return nil unless data

    OpenStruct.new(
      id:                  data["id"],
      month:               data["month"],
      year:                data["year"],
      numero_conductores:  data["numero_conductores"],
      suma:                data["suma"],
      total_uf:            data["total_uf"],
      oxy_records:         Array(data["oxy_records"]).map do |r|
        OpenStruct.new(
          id:         r["id"],
          fecha:      r["fecha"],
          created_at: r["created_at"],
          updated_at: r["updated_at"]
        )
      end
    )
  end

  def to_pesos(precio_uf, fecha_str)
    return nil if precio_uf.blank? || fecha_str.blank?

    fecha = Date.parse(fecha_str) rescue nil
    return nil unless fecha

    iva = Iva.find_by(year: fecha.year, month: fecha.month)
    return nil unless iva

    (precio_uf.to_d * iva.valor.to_d).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end
