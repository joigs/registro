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
    @year  = (params[:year]  || Date.current.year ).to_i
    @month = (params[:month] || Date.current.month).to_i
    @days_in_month = Date.civil(@year, @month, -1).day
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

    @movilidades = parse_movilidad(MOVILIDAD_MOCK).select do |m|
      d = Date.parse(m.fecha_inspeccion)
      d.year == @year && d.month == @month
    end






    @facturacions.select! do |f|
      date = (f.fecha_inspeccion && Date.parse(f.fecha_inspeccion) rescue nil)
      date && date.year == @year && date.month == @month
    end

    @evaluacions.select! do |e|
      date = (e.fecha_inspeccion && Date.parse(e.fecha_inspeccion) rescue nil)
      date && date.year == @year && date.month == @month
    end

    if @current_oxy && !(@current_oxy.year == @year && @current_oxy.month == @month)
      @current_oxy = nil
    end


    @vertical_total_uf        = sum_precios(@facturacions)
    @oxy_total_uf             = to_decimal(@current_oxy&.total_uf)
    @evaluacion_vanilla_total = sum_precios(@evaluacions)
    @evaluacion_total_uf      = @evaluacion_vanilla_total + @oxy_total_uf
    @movilidad_total_uf       = sum_precios(@movilidades)
    @sum_month                = @vertical_total_uf + @evaluacion_total_uf + @movilidad_total_uf

    @vertical_daily_uf        = daily_sums(@facturacions, :fecha_inspeccion)
    @evaluacion_vanilla_daily = daily_sums(@evaluacions,   :fecha_inspeccion)
    @oxy_daily_uf             = oxy_daily_sums(@current_oxy)
    @evaluacion_daily_uf      = merge_daily(@evaluacion_vanilla_daily, @oxy_daily_uf)
    @movilidad_daily_uf       = daily_sums(@movilidades,  :fecha_inspeccion)
    @sum_daily_uf             = merge_daily(
      merge_daily(@vertical_daily_uf, @evaluacion_daily_uf),
      @movilidad_daily_uf
    )
    @vertical_month_by_empresa   = month_sums_by_company(@facturacions)
    @evaluacion_month_by_empresa = month_sums_by_company(@evaluacions)
    @movilidad_month_by_empresa  = month_sums_by_company(@movilidades)

    @oxy_month_by_empresa        = { "Oxy" => @oxy_total_uf }

    @month_by_empresa = merge_hashes(@vertical_month_by_empresa,
                                     @evaluacion_month_by_empresa,
                                     @movilidad_month_by_empresa,
                                     @oxy_month_by_empresa)

    @vertical_day_company   = daily_company(@facturacions, :fecha_inspeccion)
    @eval_vanilla_day_comp  = daily_company(@evaluacions,  :fecha_inspeccion)
    @movilidad_day_company = daily_company(@movilidades,  :fecha_inspeccion)
    @oxy_day_company        = build_oxy_day_company(@current_oxy)

    @evaluation_day_company = merge_nested(@eval_vanilla_day_comp, @oxy_day_company)
    @day_company            = merge_nested(@vertical_day_company,
                                           @evaluation_day_company,
                                           @movilidad_day_company)
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
        empresa:          f["empresa"],
        fecha_inspeccion: f["fecha_inspeccion"],
        precio:           f["precio"],
        pesos:            to_pesos(f["precio"], f["fecha_inspeccion"]),
        created_at:       f["created_at"],
        updated_at:       f["updated_at"]
      )
    end
  end

    MOVILIDAD_MOCK = [
      { "empresa" => "Arauco",   "fecha_inspeccion" => "2025-06-01", "precio" => "6.25"  },

    ].freeze


  def parse_movilidad(arr)
    Array(arr).map do |h|
      OpenStruct.new(
        empresa:          h["empresa"],
        fecha_inspeccion: h["fecha_inspeccion"],
        precio:           h["precio"]
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



  def month_sums_by_company(records)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa.presence || "sin_empresa").to_s
        h[empresa] += to_decimal(r.precio)
      end
    end
  end

  def daily_sums_by_company(records, date_attr)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        empresa  = (r.empresa.presence || "sin_empresa").to_s
        date_str = r&.public_send(date_attr)
        next if date_str.blank?

        day = Date.parse(date_str.to_s).day rescue next
        h[empresa][day] += to_decimal(r.precio)
      end
    end
  end


  def merge_daily(a, b)
    range = 1..@days_in_month
    Hash.new(BigDecimal("0")).tap { |h| range.each { |d| h[d] = a[d] + b[d] } }
  end

  def merge_hashes(*hashes)
    Hash.new(BigDecimal("0")).tap do |h|
      hashes.each { |hh| hh.each { |k,v| h[k] += v } }
    end
  end

  def merge_nested(*levels)
    range = 1..@days_in_month
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      levels.each do |lvl|
        lvl.each { |k,sub| range.each { |d| h[k][d] += sub[d] } }
      end
    end
  end

  def daily_company(records, date_attr)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        day = Date.parse(r.public_send(date_attr).to_s).day rescue next
        h[r.empresa.presence || "sin_empresa"][day] += to_decimal(r.precio)
      end
    end
  end

  def build_oxy_day_company(current_oxy)
    return {} unless current_oxy
    daily = oxy_daily_sums(current_oxy)

    { "Oxy" => daily }
  end

  def oxy_daily_sums(current_oxy)
    return Hash.new(BigDecimal("0")) unless current_oxy

    price_per_rec = to_decimal(current_oxy.suma)          # UF por registro
    arrastre_cnt  = to_decimal(current_oxy.arrastre)      # cantidad, no UF


    Hash.new(BigDecimal("0")).tap do |h|
      current_oxy.oxy_records.each do |rec|
        day = (rec.fecha.is_a?(Date) ? rec.fecha : Date.parse(rec.fecha.to_s)).day
        h[day] += price_per_rec
      end
      h[1] += arrastre_cnt * price_per_rec unless arrastre_cnt.zero?
    end
  end

end
