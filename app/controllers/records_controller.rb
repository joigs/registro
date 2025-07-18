# app/controllers/records_controller.rb


require Rails.root.join("app/models/secondary_models.rb")




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
    "https://ventas.chcert.cl/evaluacion/api/v1/facturacions"
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
    require "set"

    iva_row = Iva.find_by(year: @year, month: @month) ||
      Iva.where("DATE(CONCAT(year,'-',month,'-01')) <= ?", Date.new(@year, @month, 1) << 1)
         .order(year: :desc, month: :desc).first ||
      Iva.order(year: :desc, month: :desc).first

    @uf = BigDecimal(iva_row.valor.to_s)

    fecha_ini = Date.new(@year, @month, 1)
    fecha_fin = Date.civil(@year, @month, -1)



    checklists = SecondaryModels::CertChkLstExternal
                   .joins("JOIN CertActivo ON CertActivo.CertActivoId = CertChkLst.CertActivoId")
                   .joins("JOIN CerMan      ON CerMan.CerManRut      = CertActivo.CerManRut")
                   .joins(<<~SQL)
LEFT JOIN Valor
       ON Valor.CerManRut            = CertActivo.CerManRut
      AND Valor.CertActivoATrabId    = CertActivo.CertActivoATrabId
      AND Valor.CertClasePlantillaId = CertActivo.CertClasePlantillaId
      AND (
           (CertChkLst.CertChkLstReIns = 1 AND Valor.ValorTipoInspec = 2) OR
           (IFNULL(CertChkLst.CertChkLstReIns,0) = 0 AND Valor.ValorTipoInspec = 1)
          )
SQL
                   .where("CertChkLst.CertChkLstFchFac BETWEEN ? AND ?", fecha_ini, fecha_fin)
                   .where("COALESCE(CertChkLst.CertChkLstSinCosto,0) = 0")
                   .select(
                     "CertChkLst.*",
                     "CertActivo.CertActivoId",
                     "CertActivo.CertActivoNro",
                     "CertActivo.CertActivoNombre",
                     "CertActivo.ActivoPadre",
                     "CertActivo.CertClasePlantillaId",
                     "CertActivo.CertActivoATrabId",
                     "CertActivo.CertTipoActId",
                     "CerMan.CerManRut",
                     "CerMan.CerManNombre",
                     "COALESCE(SUM(CASE
   WHEN Valor.ValorMoneda = 1
        THEN Valor.ValorValor * #{@uf}
   WHEN Valor.ValorMoneda = 2
        THEN IF(CertChkLst.CertChkLstIndividual = 1,
                Valor.ValorValorSolo / 1.19,
                Valor.ValorValor      / 1.19)
   ELSE 0
 END),0) AS monto_checklist"
                   )
                   .group(
                     "CertChkLst.CertChkLstId, CertActivo.CertActivoId, CertActivo.ActivoPadre,
 CertActivo.CertClasePlantillaId, CertActivo.CertActivoATrabId,
 CertActivo.CertTipoActId, CerMan.CerManRut, CertChkLst.CertChkLstIndividual"
                   )



    parent_ids = checklists.map(&:ActivoPadre).map(&:to_i).reject(&:zero?).uniq
    parent_info = {}
    unless parent_ids.empty?
      SecondaryModels::CertActivoExternal
        .where(CertActivoId: parent_ids)
        .pluck(:CertActivoId, :CertActivoNro, :CertActivoNombre,
               :CertActivoATrabId, :CertClasePlantillaId, :CertTipoActId)
        .each do |id, nro, nombre, atrab, plantilla, tipo|
        parent_info[id] = {
          patente:   [nro, nombre].map { _1.to_s.strip }.reject(&:blank?).first || id.to_s,
          atrab:     atrab,
          plantilla: plantilla,
          tipo_act:  tipo
        }
      end
    end



    parents_by_orig = Set.new
    checklists.each do |row|
      if row.CertActivoId.to_i == row.ActivoPadre.to_i && !row.ActivoPadre.to_i.zero?
        parents_by_orig << [row.ActivoPadre.to_i, row.CertChkLstFch.to_date]
      end
    end



    per_padre_rows      = {}
    individual_children = []

    checklists.each do |row|
      pid = row.ActivoPadre.to_i
      next if pid.zero?

      orig_day = row.CertChkLstFch.to_date
      key      = [pid, orig_day]

      if row.CertActivoId.to_i == pid
        per_padre_rows[key] = row
      else
        if row.CertChkLstIndividual && parents_by_orig.include?(key)
          individual_children << row
        else
          per_padre_rows[key] ||= row
        end
      end
    end




    per_padre_rows.each_value do |row|
      next if row.CertChkLstIndividual == 1
      info = parent_info[row.ActivoPadre.to_i]
      next unless info

      row.define_singleton_method(:patente_considerada) { info[:patente] }
      row.CertActivoATrabId    = info[:atrab]
      row.CertClasePlantillaId = info[:plantilla]
      row.CertTipoActId        = info[:tipo_act]
    end



    rows_ok = per_padre_rows.values + individual_children


    rows_ok
      .group_by { |r| [r.CerManRut, r.CerManNombre] }
      .each do |(rut, nombre), registros|

      desgloses = registros
                    .group_by { |r| [r.CertActivoATrabId,
                                     r.CertClasePlantillaId,
                                     r.CertTipoActId] }
                    .map do |(atrab, plantilla, tipo_act), grupo|

        monto =
          if rut == 91_440_000
            grupo.sum { |r| r.monto_checklist.to_d }
          elsif grupo.all? { |r| r.monto_checklist.to_d == grupo.first.monto_checklist.to_d }
            grupo.first.monto_checklist.to_d * grupo.size
          else
            grupo.sum { |r| r.monto_checklist.to_d }
          end

        {
          atrab_id:     atrab,
          plantilla_id: plantilla,
          tipo_act_id:  tipo_act,
          patentes:     grupo.map { |g|
            g.respond_to?(:patente_considerada) ? g.patente_considerada : g.CertActivoNro
          }.uniq,
          monto:        monto.to_f
        }
      end

      inspecciones   = registros.count { |r| !r.CertChkLstReIns }
      reinspecciones = registros.count { |r|  r.CertChkLstReIns }
      patentes       = registros.map { |r|
        r.respond_to?(:patente_considerada) ? r.patente_considerada : r.CertActivoNro
      }.uniq
      monto_total    = desgloses.sum { |d| d[:monto] }

      puts "\nEmpresa: #{nombre} (Rut: #{rut})"
      puts "  Patentes: #{patentes.join(', ')}"
      puts "  Inspecciones: #{inspecciones} | Reinspecciones: #{reinspecciones} | Total: #{registros.size}"
      puts "  Monto total: #{monto_total.round(2)}"
      puts "  -- DESGLOSE --"
      desgloses.each do |d|
        puts "    AT: #{d[:atrab_id]} | Plantilla: #{d[:plantilla_id]} | "\
               "TipoAct: #{d[:tipo_act_id]} | Patentes: #{d[:patentes].join(', ')} | "\
               "Monto: #{d[:monto].round(2)}"
      end
    end

    flag_on = ->(v) { v == true || v == 1 || v.to_s == "1" }

    @movilidad_day_company      = Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }
    @movilidad_month_by_empresa = Hash.new(BigDecimal("0"))

    rows_ok
      .reject { |r| flag_on[r.CertChkLstCosto0] || flag_on[r.CertChkLstSinCosto] }
      .group_by { |r| [r.CerManRut, r.CerManNombre, r.CertChkLstFchFac.to_date] }
      .each do |(rut, empresa, fecha), filas_dia|

      monto_pesos =
        filas_dia
          .group_by { |r| [r.CertActivoATrabId,
                           r.CertClasePlantillaId,
                           r.CertTipoActId] }
          .sum do |_k, g|
          if g.all? { |row| row.monto_checklist.to_d == g.first.monto_checklist.to_d }
            g.first.monto_checklist.to_d * g.size
          else
            g.sum { |row| row.monto_checklist.to_d }
          end
        end
      monto_pesos = filas_dia.sum { |row| row.monto_checklist.to_d } if rut == 91_440_000

      monto_uf = (monto_pesos / @uf).truncate(4)
      day      = fecha.day

      @movilidad_day_company[empresa][day] += monto_uf
      @movilidad_month_by_empresa[empresa] += monto_uf
    end

    @movilidad_daily_uf = Hash.new(BigDecimal("0")).tap do |h|
      @movilidad_day_company.each_value { |per_day| per_day.each { |d,val| h[d] += val } }
    end
    @movilidad_total_uf = @movilidad_month_by_empresa.values.sum

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
    @sum_month                = @vertical_total_uf + @evaluacion_total_uf + @movilidad_total_uf

    @vertical_daily_uf        = daily_sums(@facturacions, :fecha_inspeccion)
    @evaluacion_vanilla_daily = daily_sums(@evaluacions,   :fecha_inspeccion)
    @oxy_daily_uf             = oxy_daily_sums(@current_oxy)
    @evaluacion_daily_uf      = merge_daily(@evaluacion_vanilla_daily, @oxy_daily_uf)
    @sum_daily_uf             = merge_daily(
      merge_daily(@vertical_daily_uf, @evaluacion_daily_uf),
      @movilidad_daily_uf
    )
    @vertical_month_by_empresa   = month_sums_by_company(@facturacions)
    @evaluacion_month_by_empresa = month_sums_by_company(@evaluacions)

    @oxy_month_by_empresa        = { "Oxy" => @oxy_total_uf }

    @month_by_empresa = merge_hashes(@vertical_month_by_empresa,
                                     @evaluacion_month_by_empresa,
                                     @movilidad_month_by_empresa,
                                     @oxy_month_by_empresa)

    @vertical_day_company   = daily_company(@facturacions, :fecha_inspeccion)
    @eval_vanilla_day_comp  = daily_company(@evaluacions,  :fecha_inspeccion)
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
