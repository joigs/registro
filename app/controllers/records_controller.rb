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
      puts("body: #{body.inspect}") if Rails.env.development?

      if body.is_a?(Hash)
        @evaluacions = parse_evaluacions(body["facturacions"] || [])
        @current_oxy = parse_oxy(body["current_oxy"]) if body["current_oxy"].present?
        @current_ald = parse_ald(body["current_ald"]) if body["current_ald"].present?
        @otros_hash  = parse_otros(body["otros"] || [])
      else
        @evaluacions = parse_evaluacions(body)
        @current_oxy = nil
        @current_ald = nil
        @otros_hash  = {}
      end
    else
      @evaluacions = []
      @current_oxy = nil
      @current_ald = nil
      @otros_hash  = {}
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
                     "CerMan.CerManRutN",
                     "CerMan.CerManRazonSocial",
                     "COALESCE(SUM(CASE
   WHEN Valor.ValorMoneda = 1
        THEN Valor.ValorValor * #{@uf}
   WHEN Valor.ValorMoneda = 2
        THEN IF(CertChkLst.CertChkLstIndividual = 1,
                Valor.ValorValorSolo ,
                Valor.ValorValor      )
   ELSE 0
 END),0) AS monto_checklist"
                   )
                   .group(
                     "CertChkLst.CertChkLstId, CertActivo.CertActivoId, CertActivo.ActivoPadre,
 CertActivo.CertClasePlantillaId, CertActivo.CertActivoATrabId,
 CertActivo.CertTipoActId, CerMan.CerManRut,  CerMan.CerManRutN, CerMan.CerManRazonSocial, CertChkLst.CertChkLstIndividual"
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



      if row.CertChkLstIndividual
        next if pid.zero?
        individual_children << row
        next
      end


      if row.CertActivoId.to_i == pid
        if per_padre_rows.key?(key)
          existing = per_padre_rows[key]


          if existing.CertChkLstReIns != row.CertChkLstReIns
            individual_children << row
          else
            per_padre_rows[key] = row
          end
        else
          per_padre_rows[key] = row
        end

      else
        if row.CertChkLstIndividual && parents_by_orig.include?(key)
          individual_children << row
        elsif parents_by_orig.include?(key)
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



    end
    # ========= DEBUG  – checklist que llegan a Movilidad =========
    flag_on = ->(v) { v == true || v == 1 || v.to_s == "1" }

    rows_ok
      .reject { |r| flag_on[r.CertChkLstCosto0] || flag_on[r.CertChkLstSinCosto] }
      .group_by { |r| r.CerManNombre.to_s.strip.presence || r.CerManRut.to_s }
      .each do |empresa_peq, filas|

      puts "▶️  Empresa: #{empresa_peq.ljust(25)} — Registros movil. #{filas.size}"

      filas.each do |f|
        pat = f.respond_to?(:patente_considerada) ? f.patente_considerada : f.CertActivoNro
        uf  = (f.monto_checklist.to_d / @uf).truncate(4)

        puts "   • chk=#{f.CertChkLstId.to_s.ljust(6)}  "\
               "pat=#{pat.ljust(10)}  "\
               "orig=#{f.CertChkLstFch}  fac=#{f.CertChkLstFchFac}  "\
               "ind=#{f.CertChkLstIndividual ? 1 : 0}  "\
               "reIns=#{f.CertChkLstReIns ? 1 : 0}  "\
               "estado=#{f.CertChkLstEstado || '?'}  "\
               "pla=#{f.CertClasePlantillaId.to_s.ljust(4)}  "\
               "AT=#{f.CertActivoATrabId.to_s.ljust(4)}  "\
               "$=#{sprintf('%.2f', f.monto_checklist)}  "\
               "(#{uf.to_f} UF)"
      end

      # — resumen por AT-Plantilla-TipoAct —
      des = filas
              .group_by { |r| [r.CertActivoATrabId,
                               r.CertClasePlantillaId,
                               r.CertTipoActId] }
              .map do |(atrab, pla, tipo), g|
        {
          atrab: atrab,
          pla:   pla,
          tipo:  tipo,
          ins:   g.count { |r| !r.CertChkLstReIns },
          reins: g.count { |r|  r.CertChkLstReIns },
          pats:  g.map { |r|
            r.respond_to?(:patente_considerada) ?
              r.patente_considerada : r.CertActivoNro
          }.uniq,
          uf:    (g.sum { |r| r.monto_checklist.to_d } / @uf).truncate(4)
        }
      end

      puts "   -- DESGLOSE EMPRESA #{empresa_peq} --"
      des.each do |d|
        puts "      AT=#{d[:atrab]}  Pla=#{d[:pla]}  Tipo=#{d[:tipo]}  "\
               "Ins=#{d[:ins]}  ReIns=#{d[:reins]}  UF=#{d[:uf]}  "\
               "Patentes: #{d[:pats].join(', ')}"
      end
      puts
    end
    puts "========================================================================"


    @empresa_day     = Hash.new { |h,k| h[k] = Hash.new(BigDecimal('0')) }
    @empresa_month   = Hash.new(BigDecimal('0'))
    @emp_to_mandante = {}

    rows_ok
      .reject { |r| flag_on[r.CertChkLstCosto0] || flag_on[r.CertChkLstSinCosto] }
      .group_by { |r| [r.CerManRut, r.CerManNombre, r.CertChkLstFchFac.to_date] }
      .each do |(_rut, empresa, fecha), filas_dia|

      monto_pesos = if _rut == 91_440_000
                      filas_dia.sum { |r| r.monto_checklist.to_d }
                    else
                      filas_dia
                        .group_by { |r| [r.CertActivoATrabId,
                                         r.CertClasePlantillaId,
                                         r.CertTipoActId] }
                        .sum { |_k,g| g.all? { |x| x.monto_checklist.to_d == g.first.monto_checklist.to_d } ?
                                        g.first.monto_checklist.to_d * g.size :
                                        g.sum { |x| x.monto_checklist.to_d } }
                    end

      monto_uf = (monto_pesos / @uf).truncate(4)
      @empresa_day[empresa][fecha.day] += monto_uf
      @empresa_month[empresa]          += monto_uf

      ref          = filas_dia.first
      mand_rut     = ref.CerManRutN.to_s
      mand_nom     = ref.CerManRazonSocial.to_s.strip.presence || mand_rut
      @emp_to_mandante[empresa] = [mand_rut, mand_nom]
    end
    @empresas_por_mandante = Hash.new { |h,k| h[k] = [] }
    @emp_to_mandante.each do |empresa, (mand_rut, _mand_nom)|
      @empresas_por_mandante[mand_rut] << empresa
    end


    @mandante_names  = {}
    mandante_day     = Hash.new { |h,k| h[k] = Hash.new(BigDecimal('0')) }
    mandante_month   = Hash.new(BigDecimal('0'))

    @empresa_day.each do |empresa, per_day|
      mand_rut, mand_nom = @emp_to_mandante[empresa]
      @mandante_names[mand_rut] ||= mand_nom
      per_day.each { |d,val| mandante_day[mand_rut][d] += val }
      mandante_month[mand_rut]  += @empresa_month[empresa]
    end



    @movilidad_day_company      = mandante_day
    @movilidad_month_by_empresa = mandante_month
    @movilidad_daily_uf         = mandante_day.values
                                              .each_with_object(Hash.new(BigDecimal('0'))) { |per_day,h|
                                                per_day.each { |d,val| h[d] += val }
                                              }
    @movilidad_total_uf         = mandante_month.values.sum




    require "i18n" unless defined?(I18n)
    norm = ->s { I18n.transliterate(s.to_s).gsub(/[\s\.]/,'').downcase }

    grp_day   = Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }
    grp_month = Hash.new(BigDecimal("0"))

    mandante_day.each do |rut, per_day|
      raw_name = @mandante_names[rut] || rut
      key =
        if   norm[raw_name].include?("forestalarauco")
          "Forestal Arauco SA"
        elsif norm[raw_name].include?("forestalmininco")
          "Planta Acreditación Vehículos Forestal"
        else
          "Otros"
        end

      per_day.each { |d,v| grp_day[key][d] += v }
      grp_month[key]       += mandante_month[rut]
    end

    @movil_split_day_company      = grp_day
    @movil_split_month_by_empresa = grp_month
    @movil_split_daily_uf         = grp_day.values
                                           .each_with_object(Hash.new(BigDecimal("0"))) { |per,h|
                                             per.each { |d,v| h[d] += v }
                                           }
    @movil_split_total_uf         = grp_month.values.sum

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

    # ---------- ALD (único) ----------
    @ald_total_uf = to_decimal(@current_ald&.total_uf)
    @ald_daily_uf = Hash.new(BigDecimal("0")).tap do |h|
      if @current_ald
        h[@days_in_month] = @ald_total_uf
      end
    end
    @ald_month_by_empresa = { "ALD" => @ald_total_uf }

    @otros_month_by_empresa = @otros_hash.transform_values { |v| v } # ya es total_uf
    @otros_total_uf         = @otros_month_by_empresa.values.sum

    @otros_daily_uf = Hash.new(BigDecimal("0")).tap do |h|
      @otros_total_uf.zero? or h[@days_in_month] = @otros_total_uf
    end
    @otros_day_company = Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }
    @otros_month_by_empresa.each do |emp, total|
      @otros_day_company[emp][@days_in_month] = total
    end


    require "i18n" unless defined?(I18n)

    norm = ->s { I18n.transliterate(s.to_s).gsub(/[\s\.]/,'').downcase }

    target_rut = @mandante_names.find { |_rut, nom| norm[nom].include?("forestalarauco") }&.first
    target_rut ||= "Forestal Arauco SA"

    arauco_keys = @otros_month_by_empresa.keys.select { |k| norm[k].include?("arauco") }

    unless arauco_keys.empty?
      total_arauco = arauco_keys.sum { |k| @otros_month_by_empresa[k] }
      @otros_month_by_empresa[target_rut] ||= BigDecimal("0")
      @otros_month_by_empresa[target_rut]  += total_arauco
      arauco_keys.each { |k| @otros_month_by_empresa.delete(k) }

      ar_day_tot = Hash.new(BigDecimal("0"))
      arauco_keys.each do |k|
        @otros_day_company[k].each { |d,v| ar_day_tot[d] += v }
        @otros_day_company.delete(k)
      end
      @otros_day_company[target_rut] ||= Hash.new(BigDecimal("0"))
      ar_day_tot.each { |d,v| @otros_day_company[target_rut][d] += v }
    end


    @evaluacion_vanilla_total = sum_precios(@evaluacions)
    @evaluacion_total_uf = @evaluacion_vanilla_total + @oxy_total_uf + @ald_total_uf + @otros_total_uf
    @sum_month                = @vertical_total_uf + @evaluacion_total_uf + @movilidad_total_uf

    @vertical_daily_uf        = daily_sums(@facturacions, :fecha_inspeccion)
    @evaluacion_vanilla_daily = daily_sums(@evaluacions,   :fecha_inspeccion)
    @oxy_daily_uf             = oxy_daily_sums(@current_oxy)
    @evaluacion_daily_uf = merge_daily(
      merge_daily(@evaluacion_vanilla_daily, @oxy_daily_uf),
      merge_daily(@ald_daily_uf, @otros_daily_uf)
    )

    @sum_daily_uf = merge_daily(
      merge_daily(@vertical_daily_uf, @evaluacion_daily_uf),
      @movilidad_daily_uf
    )
    @vertical_month_by_empresa   = month_sums_by_company(@facturacions)
    @evaluacion_month_by_empresa = month_sums_by_company(@evaluacions)

    oxy_name = "Occidental Chemical Chile Limitada"
    oxy_rut  = @mandante_names.key(oxy_name) || oxy_name

    @oxy_month_by_empresa = { oxy_rut => @oxy_total_uf }

    @month_by_empresa = merge_hashes(@vertical_month_by_empresa,
                                     @evaluacion_month_by_empresa,
                                     @movilidad_month_by_empresa,
                                     @oxy_month_by_empresa,
                                     @ald_month_by_empresa,
                                     @otros_month_by_empresa)

    @vertical_day_company   = daily_company(@facturacions, :fecha_inspeccion)
    @eval_vanilla_day_comp  = daily_company(@evaluacions,  :fecha_inspeccion)
    @oxy_day_company        = build_oxy_day_company(@current_oxy)

    @evaluation_day_company = merge_nested(
      @eval_vanilla_day_comp,
      @oxy_day_company,
      @ald_day_company ||= { "ALD" => @ald_daily_uf },
      @otros_day_company
    )


    @day_company            = merge_nested(@vertical_day_company,
                                           @evaluation_day_company,
                                           @movilidad_day_company)


    @module_months = {
      "Transporte Vertical"        => @vertical_month_by_empresa,
      "Evaluación de Competencias" => merge_hashes(@evaluacion_month_by_empresa,
                                                   @ald_month_by_empresa,
                                                   @oxy_month_by_empresa,
                                                   @otros_month_by_empresa),
      "Movilidad"                  => @movilidad_month_by_empresa,

    }

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

  def parse_ald(data)
    return nil unless data
    OpenStruct.new(
      id:         data["id"],
      month:      data["month"],
      year:       data["year"],
      n1:         data["n1"],
      total_uf:   to_decimal(data["total"])
    )
  end

  def parse_otros(arr)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(arr).each do |o|
        empresa = o.dig("empresa", "nombre") || "sin_empresa"
        h[empresa] += to_decimal(o["total"])
      end
    end
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
