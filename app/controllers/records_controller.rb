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

    #Mensual por modulo
    @vertical_total_uf   = sum_precios(@facturacions)
    @evaluacion_vanilla_total_uf = sum_precios(@evaluacions)
    @oxy_total_uf        = to_decimal(@current_oxy&.total_uf)
    @evaluacion_total_uf = @evaluacion_vanilla_total_uf + (@oxy_daily_uf || 0)

    #Mensual global
    @sum_month = @vertical_total_uf + @evaluacion_total_uf


    #Diario por modulo
    @vertical_daily_uf   = daily_sums(@facturacions, :fecha_inspeccion)
    @evaluacion_vanilla_daily_uf = daily_sums(@evaluacions, :fecha_inspeccion)
    @oxy_daily_uf        = oxy_daily_sums(@current_oxy)
    @evaluacion_daily_uf = Hash.new(BigDecimal("0"))



    #Diario global
    @sum_daily_uf        = Hash.new(BigDecimal("0"))
    (1..31).each do |d|
      @evaluacion_daily_uf[d] = @evaluacion_vanilla_daily_uf[d] + @oxy_daily_uf[d]

      @sum_daily_uf[d] =  @vertical_daily_uf[d] + @evaluacion_daily_uf[d]
    end


    puts("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    puts("Vertical: #{@vertical_daily_uf.inspect}")
    puts("Evaluacion Vanilla: #{@evaluacion_vanilla_daily_uf.inspect}")
    puts("Oxy: #{@oxy_daily_uf.inspect}")
    puts("Evaluacion: #{@evaluacion_daily_uf.inspect}")
    puts("Sum: #{@sum_daily_uf.inspect}")


  end



  private

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
      arrastre:            data["arrastre"],
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


  def sum_precios(records)
    Array(records).sum(BigDecimal("0")) do |r|
      to_decimal(r&.precio)
    end
  end

  def to_decimal(val)
    return BigDecimal("0") if val.blank?
    BigDecimal(val.to_s)
  end





  def daily_sums(records, date_attr)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        date_str = r&.public_send(date_attr)
        next if date_str.blank?

        day = Date.parse(date_str.to_s).day rescue next
        h[day] += to_decimal(r.precio)
      end
    end
  end


  def oxy_daily_sums(current_oxy)
    return Hash.new(BigDecimal("0")) unless current_oxy

    price_per_record = to_decimal(current_oxy.suma)
    arrastre         = to_decimal(current_oxy.arrastre)
    suma = to_decimal(current_oxy.suma)

    Hash.new(BigDecimal("0")).tap do |h|
      Array(current_oxy.oxy_records).each do |rec|
        day = rec.fecha.is_a?(Date) ? rec.fecha.day : Date.parse(rec.fecha.to_s).day
        h[day] += price_per_record
      end
      h[1] += arrastre*suma
    end
  end


end
