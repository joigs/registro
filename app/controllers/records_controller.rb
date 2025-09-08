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
    @full_year = params[:month].to_s == 'all'

    if @full_year

      @max_month = (@year.to_i == Date.current.year ? Date.current.month : 12)

      meta_resp = HTTParty.get(VERTICAL_URL, headers: { "X-API-KEY" => VERTICAL_KEY }, query: { meta: 1 })
      @filter_options = meta_resp.code == 200 ? JSON.parse(meta_resp.body) : { "anios" => [], "meses" => (1..12).to_a, "empresas" => [] }

      fact_resp = api_get(VERTICAL_URL, VERTICAL_KEY, { year: @year, month: "all" })
      fact_json = fact_resp.code == 200 ? JSON.parse(fact_resp.body) : {}
      @facturacions = parse_facturacions_anual(fact_json["facturacions"] || fact_json)
      @convenios    = parse_convenios_anual(fact_json["convenios"] || [])

      eval_body = nil
      eval_resp = api_get(EVAL_URL, EVAL_KEY, { year: @year, month: "all" })
      if eval_resp.code == 200
        eval_body = JSON.parse(eval_resp.body) rescue nil
        if eval_body.is_a?(Hash)
          @evaluacions   = parse_evaluacions_anual(eval_body["facturacions"] || [])
          @current_oxies = parse_oxy_anual(eval_body["current_oxy"])     if eval_body["current_oxy"].present?
          @current_cmpcs = parse_cmpc_anual(eval_body["current_cmpc"])   if eval_body["current_cmpc"].present?
          @current_alds  = parse_ald_anual(eval_body["current_ald"])     if eval_body["current_ald"].present?
          @otros         = parse_otros_anual(eval_body["otros"] || [])
        else
          @evaluacions   = parse_evaluacions_anual(eval_body || [])
          @current_oxies = []
          @current_cmpcs = []
          @current_alds  = []
          @otros         = []
        end
      else
        @evaluacions   = []
        @current_oxies = []
        @current_cmpcs = []
        @current_alds  = []
        @otros         = []
      end


      #puts("evaluacions_anual: #{@evaluacions.inspect}")
      #puts("current_oxies_anual: #{@current_oxies.inspect}")
      #puts("current_cmpcs_anual: #{@current_cmpcs.inspect}")
      #puts("current_alds_anual: #{@current_alds.inspect}")
      #puts("otros_anual: #{@otros.inspect}")



      @uf_map = uf_map_for_year(@year)
      last_uf = @uf_map[@max_month] || @uf_map.values.compact.last
      @uf = BigDecimal((last_uf || 0).to_s)

      fact_month_uf   = monthly_sums_anual(@facturacions, :fecha_venta, @year)
      fact_month_cnt  = monthly_counts_anual(@facturacions, :fecha_venta, @year)
      conv_month_uf   = monthly_sums_convenios_anual(@convenios, @year)
      conv_month_cnt  = monthly_counts_convenios_anual(@convenios, @year)
      @vertical_by_month_uf     = merge_monthly_anual(fact_month_uf,  conv_month_uf,  @year)
      @vertical_by_month_count  = merge_monthly_count_anual(fact_month_cnt, conv_month_cnt, @year)

      eval_van_month_uf  = monthly_sums_anual(@evaluacions, :fecha_inspeccion, @year)
      eval_van_month_cnt = monthly_counts_anual(@evaluacions, :fecha_inspeccion, @year)
      oxy_month_uf       = oxy_monthly_sums_anual(@current_oxies, @year)
      oxy_month_cnt      = oxy_monthly_counts_anual(@current_oxies, @year)
      cmpc_month_uf      = cmpc_monthly_sums_anual(@current_cmpcs, @year)
      cmpc_month_cnt     = cmpc_monthly_counts_anual(@current_cmpcs, @year)
      ald_month_uf       = ald_monthly_sums_anual(@current_alds, @year)
      ald_month_cnt      = ald_monthly_counts_anual(@current_alds, @year)
      otros_month_uf     = monthly_sums_otros_anual(@otros, @year)
      otros_month_cnt    = monthly_counts_otros_anual(@otros, @year)

      tmp_eval_uf  = merge_monthly_anual(eval_van_month_uf, oxy_month_uf, @year)
      tmp_eval_uf2 = merge_monthly_anual(ald_month_uf, otros_month_uf, @year)
      tmp_eval_uf3 = merge_monthly_anual(tmp_eval_uf2, cmpc_month_uf, @year)
      @evaluacion_by_month_uf = merge_monthly_anual(tmp_eval_uf, tmp_eval_uf3, @year)

      tmp_eval_ct  = merge_monthly_count_anual(eval_van_month_cnt, oxy_month_cnt, @year)
      tmp_eval_ct2 = merge_monthly_count_anual(ald_month_cnt, otros_month_cnt, @year)
      tmp_eval_ct3 = merge_monthly_count_anual(tmp_eval_ct2, cmpc_month_cnt, @year)
      @evaluacion_by_month_count = merge_monthly_count_anual(tmp_eval_ct, tmp_eval_ct3, @year)
      #puts("@evaluacion_by_month_count = #{@evaluacion_by_month_count.inspect}")
      @movilidad_by_month_uf    = Hash.new(BigDecimal("0"))
      @movilidad_by_month_count = Hash.new(0)

      flag_on = ->(v) { v == true || v == 1 || v.to_s == "1" }

      @empresa_month_movilidad        = Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }
      @empresa_month_movilidad_count  = Hash.new { |h,k| h[k] = Hash.new(0) }
      @movilidad_month_mandante       = Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }
      @movilidad_month_mandante_count = Hash.new { |h,k| h[k] = Hash.new(0) }

      @mandante_names                 = {}
      empresas_por_mandante_all       = Hash.new { |h,k| h[k] = [] }
      emp_to_mandante_all             = {}

      (1..@max_month).each do |mm|
        iva_row = Iva.find_by(year: @year, month: mm) ||
          Iva.where("DATE(CONCAT(year,'-',month,'-01')) <= ?", Date.new(@year, mm, 1) << 1)
             .order(year: :desc, month: :desc).first ||
          Iva.order(year: :desc, month: :desc).first
        uf_m = BigDecimal(iva_row.valor.to_s)

        fecha_ini = Date.new(@year, mm, 1)
        fecha_fin = Date.civil(@year, mm, -1)

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
        THEN Valor.ValorValor * #{uf_m}
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

        require "set"
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

          next if pid.zero? && !row.CertChkLstIndividual

          orig_day = row.CertChkLstFch.to_date
          key      = [pid, orig_day]

          if row.CertChkLstIndividual
            individual_children << row
            next
          end

          if row.CertActivoId.to_i == pid
            if per_padre_rows.key?(key)
              existing = per_padre_rows[key]

              if existing.CertChkLstReIns != row.CertChkLstReIns
                individual_children << row
              else
                if row.CertChkLstReIns
                  individual_children << row
                else
                  per_padre_rows[key] = row
                end
              end
            else
              per_padre_rows[key] = row
            end
          else
            if row.CertChkLstIndividual && parents_by_orig.include?(key)
              individual_children << row
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

        @empresa_month_count = Hash.new(0)
        @empresa_month       = Hash.new(BigDecimal("0"))
        @emp_to_mandante     = {}

        rows_ok
          .reject { |r| flag_on[r.CertChkLstCosto0] || flag_on[r.CertChkLstSinCosto] }
          .group_by { |r| [r.CerManRut, r.CerManNombre, r.CertChkLstFchFac.to_date] }
          .each do |(_rut, empresa, fecha), filas_dia|
          @empresa_month_count[empresa] += filas_dia.size
          monto_pesos = if _rut == 91_440_000
                          filas_dia.sum { |r| r.monto_checklist.to_d }
                        else
                          filas_dia
                            .group_by { |r| [r.CertActivoATrabId, r.CertClasePlantillaId, r.CertTipoActId] }
                            .sum { |_k,g| g.all? { |x| x.monto_checklist.to_d == g.first.monto_checklist.to_d } ?
                                            g.first.monto_checklist.to_d * g.size :
                                            g.sum { |x| x.monto_checklist.to_d } }
                        end
          monto_uf = (monto_pesos / uf_m).truncate(4)
          @empresa_month[empresa] += monto_uf

          ref          = filas_dia.first
          mand_rut     = ref.CerManRutN.to_s
          mand_nom     = ref.CerManRazonSocial.to_s.strip.presence || mand_rut
          @emp_to_mandante[empresa] = [mand_rut, mand_nom]
        end

        @empresas_por_mandante = Hash.new { |h,k| h[k] = [] }
        @emp_to_mandante.each { |empresa, (mand_rut, _)| @empresas_por_mandante[mand_rut] << empresa }

        mandante_month        = Hash.new(BigDecimal("0"))
        mandante_month_count  = Hash.new(0)
        @empresa_month.each do |empresa, uf_total|
          mand_rut, _mand_nom = @emp_to_mandante[empresa]
          mandante_month[mand_rut]       += uf_total
          mandante_month_count[mand_rut] += @empresa_month_count[empresa]
        end

        @movilidad_by_month_uf[mm]    = mandante_month.values.sum
        @movilidad_by_month_count[mm] = mandante_month_count.values.sum

        (@empresa_month || {}).each do |empresa, uf_total|
          @empresa_month_movilidad[empresa][mm]       += uf_total.to_d
          @empresa_month_movilidad_count[empresa][mm] += (@empresa_month_count[empresa] || 0).to_i
        end

        (mandante_month || {}).each do |rut, uf_total|
          @movilidad_month_mandante[rut][mm]       += uf_total.to_d
          @movilidad_month_mandante_count[rut][mm] += (mandante_month_count[rut] || 0).to_i
        end

        (@emp_to_mandante || {}).each do |empresa, (rut, nom)|
          emp_to_mandante_all[empresa] ||= [rut, nom]
          @mandante_names[rut] ||= nom
          empresas_por_mandante_all[rut] |= [empresa]
        end

      end

      @empresas_por_mandante = empresas_por_mandante_all
      @emp_to_mandante       = emp_to_mandante_all

      require "i18n" unless defined?(I18n)
      norm = ->s { I18n.transliterate(s.to_s).gsub(/[\s\.]/,'').downcase }

      grp_uf  = Hash.new(BigDecimal("0"))
      grp_cnt = Hash.new(0)
      @movilidad_month_mandante.each do |rut, per_month|
        name = (@mandante_names[rut] || rut).to_s
        key =
          if   norm[name].include?("forestalarauco") || rut == "85805200"
            "Forestal Arauco SA"
          elsif norm[name].include?("forestalmininco")
            "Planta Acreditación Vehículos Forestal"
          else
            "Otros"
          end
        grp_uf[key]  += per_month.values.sum.to_d
        grp_cnt[key] += (@movilidad_month_mandante_count[rut] || {}).values.sum.to_i
      end
      @movil_split_year_by_empresa       = grp_uf
      @movil_split_year_by_empresa_count = grp_cnt
      @movil_split_total_uf_year         = grp_uf.values.reduce(0.to_d, :+)

      vert_emp_month  = monthly_sums_by_company_anual(@facturacions, :fecha_venta, @year)
      conv_emp_month  = monthly_sums_by_company_convenios_anual(@convenios, @year)
      @vertical_month_company = merge_nested_monthly_anual(vert_emp_month, conv_emp_month, year: @year)

      vert_cnt_month  = monthly_count_company_anual(@facturacions, :fecha_venta, @year)
      conv_cnt_month  = monthly_count_company_convenios_anual(@convenios, @year)
      @vertical_month_company_count = merge_nested_count_monthly_anual(vert_cnt_month, conv_cnt_month, year: @year)
      @movil_split_month_company       = Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }
      @movil_split_month_company_count = Hash.new { |h,k| h[k] = Hash.new(0) }

      require "i18n" unless defined?(I18n)
      norm = ->s { I18n.transliterate(s.to_s).gsub(/[\s\.]/,'').downcase }

      @movilidad_month_mandante.each do |rut, per_month|
        raw_name = (@mandante_names[rut] || rut).to_s
        key =
          if   norm[raw_name].include?("forestalarauco") || rut == "85805200"
            "Forestal Arauco SA"
          elsif norm[raw_name].include?("forestalmininco")
            "Planta Acreditación Vehículos Forestal"
          else
            "Otros"
          end

        per_month.each do |m, ufv|
          @movil_split_month_company[key][m] += ufv.to_d
        end
        (@movilidad_month_mandante_count[rut] || {}).each do |m, cnt|
          @movil_split_month_company_count[key][m] += cnt.to_i
        end
      end

      eval_emp_month      = monthly_company_anual(@evaluacions, :fecha_inspeccion, @year)
      otros_emp_month     = monthly_company_otros_anual(@otros, @year)
      ald_emp_month       = { "ALD" => ald_month_uf }

      oxy_emp_month_raw   = build_oxy_month_company_anual(@current_oxies, @year)
      cmpc_emp_month_raw  = build_cmpc_month_company_anual(@current_cmpcs, @year)

      eval_cnt_month      = monthly_count_company_anual(@evaluacions, :fecha_inspeccion, @year)
      otros_cnt_month     = monthly_counts_company_otros_anual(@otros, @year)
      ald_cnt_month       = { "ALD" => ald_month_cnt }

      oxy_cnt_month_raw   = build_oxy_month_company_count_anual(@current_oxies, @year)
      cmpc_cnt_month_raw  = build_cmpc_month_company_count_anual(@current_cmpcs, @year)

      oxy_name = "Occidental Chemical Chile Limitada"
      cmpc_name = "EMPRESAS CMPC S.A"
      oxy_rut  = @mandante_names.key(oxy_name) || oxy_name
      cmpc_rut = @mandante_names.key(cmpc_name) || cmpc_name

      oxy_emp_month  = {}
      cmpc_emp_month = {}
      if oxy_emp_month_raw["Oxy"]
        oxy_emp_month[oxy_rut] = oxy_emp_month_raw["Oxy"]
      end
      if cmpc_emp_month_raw["Transporte de personal CMPC"]
        cmpc_emp_month[cmpc_rut] = cmpc_emp_month_raw["Transporte de personal CMPC"]
      end

      oxy_cnt_month  = {}
      cmpc_cnt_month = {}
      if oxy_cnt_month_raw["Oxy"]
        oxy_cnt_month[oxy_rut] = oxy_cnt_month_raw["Oxy"]
      end
      if cmpc_cnt_month_raw["Transporte de personal CMPC"]
        cmpc_cnt_month[cmpc_rut] = cmpc_cnt_month_raw["Transporte de personal CMPC"]
      end

      @evaluation_month_company = merge_nested_monthly_anual(
        eval_emp_month,
        otros_emp_month,
        ald_emp_month,
        oxy_emp_month,
        cmpc_emp_month,
        year: @year
      )

      @evaluation_month_company_count = merge_nested_count_monthly_anual(
        eval_cnt_month,
        otros_cnt_month,
        ald_cnt_month,
        oxy_cnt_month,
        cmpc_cnt_month,
        year: @year
      )

      @vertical_year_by_empresa   = @vertical_month_company.transform_values   { |per_m| per_m.values.reduce(0.to_d, :+) }
      @evaluation_year_by_empresa = @evaluation_month_company.transform_values { |per_m| per_m.values.reduce(0.to_d, :+) }
      @movilidad_year_by_empresa  = @movilidad_month_mandante.transform_values { |per_m| per_m.values.reduce(0.to_d, :+) }

      # Conteos: rolear a mandante y sumar meses
      @vertical_month_by_empresa_count_rolled   = rollup_counts_to_mandante_monthly_anual(@vertical_month_company_count,   @year)
      @evaluation_month_by_empresa_count_rolled = rollup_counts_to_mandante_monthly_anual(@evaluation_month_company_count, @year)

      vertical_year_by_empresa_count_rolled   = @vertical_month_by_empresa_count_rolled.transform_values   { |per_m| per_m.values.sum }
      evaluation_year_by_empresa_count_rolled = @evaluation_month_by_empresa_count_rolled.transform_values { |per_m| per_m.values.sum }
      @movilidad_year_by_empresa_count        = @movilidad_month_mandante_count.transform_values           { |per_m| per_m.values.sum }

      @module_years = {
        "Transporte Vertical"        => @vertical_year_by_empresa,
        "Evaluación de Competencias" => @evaluation_year_by_empresa,
        "Movilidad"                  => @movilidad_year_by_empresa
      }

      @module_years_count = {
        "Transporte Vertical"        => vertical_year_by_empresa_count_rolled,
        "Evaluación de Competencias" => evaluation_year_by_empresa_count_rolled,
        "Movilidad"                  => @movilidad_year_by_empresa_count
      }
      @alias_empresas_por_mandante_year = Hash.new { |h,k| h[k] = [] }

      mandantes_year = (@movilidad_year_by_empresa || {}).keys
      all_empresas_year = (@module_years || {})
                            .values.flat_map(&:keys).uniq

      mandantes_year.each do |mand_key|
        mname = display_name_for(mand_key).to_s
        all_empresas_year.each do |emp_key|
          next if emp_key == mand_key
          next if (@empresas_por_mandante || {})[mand_key].to_a.include?(emp_key)

          ename = display_name_for(emp_key).to_s
          if names_match?(ename, mname)
            @alias_empresas_por_mandante_year[mand_key] << emp_key
          end
        end
        @alias_empresas_por_mandante_year[mand_key].uniq!
      end

      @year_by_empresa       = merge_hashes(@vertical_year_by_empresa, @evaluation_year_by_empresa, @movilidad_year_by_empresa)
      @year_by_empresa_count = merge_counts_hashes(vertical_year_by_empresa_count_rolled, evaluation_year_by_empresa_count_rolled, @movilidad_year_by_empresa_count)
      require "set"
      require "i18n" unless defined?(I18n)


      _module_company_keys = (@vertical_year_by_empresa.keys | @evaluation_year_by_empresa.keys)

      @year_by_empresa       = @year_by_empresa.dup
      @year_by_empresa_count = @year_by_empresa_count.dup

      moved_keys = Set.new

      (@mandante_names || {}).each do |mand_rut, mand_name|
        next if mand_name.blank?

        _matches = @year_by_empresa.keys.select do |comp_name|
          next false if comp_name.to_s == mand_rut.to_s
          next false unless _module_company_keys.include?(comp_name)
          fuzzy_same_or_contains?(comp_name, mand_name)
        end

        _matches.each do |comp_name|
          next if moved_keys.include?(comp_name)

          val = @year_by_empresa.delete(comp_name)
          @year_by_empresa[mand_rut] = @year_by_empresa.fetch(mand_rut, 0.to_d) + (val || 0.to_d)

          cnt = @year_by_empresa_count.delete(comp_name)
          @year_by_empresa_count[mand_rut] = @year_by_empresa_count.fetch(mand_rut, 0) + (cnt || 0)

          moved_keys << comp_name
        end
      end

      @empresa_year       = @empresa_month_movilidad.transform_values       { |per_m| per_m.values.reduce(0.to_d, :+) }
      @empresa_year_count = @empresa_month_movilidad_count.transform_values { |per_m| per_m.values.sum }


      @vertical_total_uf     = @vertical_by_month_uf.values.sum
      @vertical_total_count  = @vertical_by_month_count.values.sum
      @evaluacion_total_uf   = @evaluacion_by_month_uf.values.sum
      @evaluacion_total_count= @evaluacion_by_month_count.values.sum
      @movilidad_total_uf    = @movilidad_by_month_uf.values.sum
      @movilidad_total_count = @movilidad_by_month_count.values.sum

  else

    @month = (params[:month] || Date.current.month).to_i
    @days_in_month = Date.civil(@year, @month, -1).day
    meta_resp = HTTParty.get(VERTICAL_URL, headers: { "X-API-KEY" => VERTICAL_KEY },
                             query:   { meta: 1 })
    @filter_options =
      meta_resp.code == 200 ? JSON.parse(meta_resp.body)
        : { "anios" => [], "meses" => (1..12).to_a, "empresas" => [] }

    fact_resp = api_get(VERTICAL_URL, VERTICAL_KEY, query)
    json      = fact_resp.code == 200 ? JSON.parse(fact_resp.body) : {}

    @facturacions = parse_facturacions(json["facturacions"] || json)
    @convenios    = parse_convenios(json["convenios"] || [])


    eval_resp = api_get(EVAL_URL, EVAL_KEY, query)

    if eval_resp.code == 200
      body = JSON.parse(eval_resp.body)
      if body.is_a?(Hash)
        @evaluacions = parse_evaluacions(body["facturacions"] || [])
        @current_oxy = parse_oxy(body["current_oxy"]) if body["current_oxy"].present?
    if body["current_cmpc"].present?

      @current_cmpc = parse_cmpc(body["current_cmpc"])

    else
      @current_cmpc = nil
    end
        
        @current_ald = parse_ald(body["current_ald"]) if body["current_ald"].present?
        @otros       = parse_otros(body["otros"] || [])

      else
        @evaluacions = parse_evaluacions(body)
        @current_cmpc = nil
        @current_oxy = nil
        @current_ald = nil
        @otros = []
      end
    else
      @evaluacions = []
      @current_oxy = nil
      @current_cmpc = nil
      @current_ald = nil
      @otros = []
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

      next if pid.zero? && !row.CertChkLstIndividual

      orig_day = row.CertChkLstFch.to_date
      key      = [pid, orig_day]

      if row.CertChkLstIndividual
        individual_children << row
        next
      end



      if row.CertActivoId.to_i == pid
        if per_padre_rows.key?(key)
          existing = per_padre_rows[key]

          if existing.CertChkLstReIns != row.CertChkLstReIns
            individual_children << row
          else
            if row.CertChkLstReIns
              individual_children << row
            else
              per_padre_rows[key] = row
            end
          end
        else
          per_padre_rows[key] = row
        end
      else
        if row.CertChkLstIndividual && parents_by_orig.include?(key)
          individual_children << row
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




    flag_on = ->(v) { v == true || v == 1 || v.to_s == "1" }




    rows_ok
      .reject { |r| flag_on[r.CertChkLstCosto0] || flag_on[r.CertChkLstSinCosto] }
      .group_by { |r| r.CerManNombre.to_s.strip.presence || r.CerManRut.to_s }
      .each do |empresa_peq, filas|



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





    @empresa_day_count   = Hash.new { |h, k| h[k] = Hash.new(0) }
    @empresa_month_count = Hash.new(0)
    rows_ok
      .reject { |r| flag_on[r.CertChkLstCosto0] || flag_on[r.CertChkLstSinCosto] }
      .group_by { |r| [r.CerManRut, r.CerManNombre, r.CertChkLstFchFac.to_date] }
      .each do |(_rut, empresa, fecha), filas_dia|
      @empresa_day_count[empresa][fecha.day] += filas_dia.size
      @empresa_month_count[empresa]          += filas_dia.size



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

    mandante_day_count   = Hash.new { |h, k| h[k] = Hash.new(0) }
    mandante_month_count = Hash.new(0)

    @empresa_day_count.each do |empresa, per_day|
      mand_rut, _mand_nom = @emp_to_mandante[empresa]
      per_day.each { |d, v| mandante_day_count[mand_rut][d] += v }
      mandante_month_count[mand_rut] += @empresa_month_count[empresa]
    end


    @movilidad_day_company_count      = mandante_day_count
    @movilidad_month_by_empresa_count = mandante_month_count
    @movilidad_daily_count = mandante_day_count.values
                                               .each_with_object(Hash.new(0)) { |per_day, h|
                                                 per_day.each { |d, v| h[d] += v }
                                               }
    @movilidad_total_count = mandante_month_count.values.sum


    #puts "@empresa_day_count                = #{@empresa_day_count.inspect}"
    #puts "@empresa_month_count              = #{@empresa_month_count.inspect}"
    #puts "@movilidad_day_company_count      = #{@movilidad_day_company_count.inspect}"
    #puts "@movilidad_month_by_empresa_count = #{@movilidad_month_by_empresa_count.inspect}"
    #puts "@movilidad_daily_count            = #{@movilidad_daily_count.inspect}"
    #puts "@movilidad_total_count            = #{@movilidad_total_count}"


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
        if   norm[raw_name].include?("forestalarauco") || rut == "85805200"
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




    grp_day_count   = Hash.new { |h,k| h[k] = Hash.new(0) }
    grp_month_count = Hash.new(0)

    mandante_day_count.each do |rut, per_day_count|
      raw_name = @mandante_names[rut] || rut
      key =
        if   norm[raw_name].include?("forestalarauco") || rut == "85805200"
          "Forestal Arauco SA"
        elsif norm[raw_name].include?("forestalmininco")
          "Planta Acreditación Vehículos Forestal"
        else
          "Otros"
        end

      per_day_count.each { |d,cnt| grp_day_count[key][d] += cnt }
      grp_month_count[key] += per_day_count.values.sum
    end

    @movil_split_day_company_count      = grp_day_count
    @movil_split_month_by_empresa_count = grp_month_count
    @movil_split_daily_count            = grp_day_count.values
                                                       .each_with_object(Hash.new(0)) { |per,h|
                                                         per.each { |d,c| h[d] += c }
                                                       }
    @movil_split_total_count            = grp_month_count.values.sum


    @facturacions.select! do |f|
      date = (f.fecha_venta && Date.parse(f.fecha_venta) rescue nil)
      date && date.year == @year && date.month == @month
    end

    @convenios.select do |c|
      date = (c.fecha_venta && Date.parse(c.fecha_venta) rescue nil)
      date && date.year == @year && date.month == @month
    end

    @evaluacions.select! do |e|
      date = (e.fecha_inspeccion && Date.parse(e.fecha_inspeccion) rescue nil)
      date && date.year == @year && date.month == @month
    end

    if @current_oxy && !(@current_oxy.year == @year && @current_oxy.month == @month)
      @current_oxy = nil
    end
    if @current_cmpc && !(@current_cmpc.year == @year && @current_cmpc.month == @month)
      @current_cmpc = nil
    end














    @vertical_total_uf = sum_precios(@facturacions) + sum_precios_convenios(@convenios)
    @oxy_total_uf             = to_decimal(@current_oxy&.total_uf)
    @cmpc_total_uf = to_decimal(@current_cmpc&.total_uf)

    @convenios_total_count = @convenios.sum { |c| c.n1.to_i + c.n2.to_i }
    @facturacions_total_count = @facturacions.sum { |f| f.n1.to_i }


    #puts("convenios_total_count=#{@convenios_total_count} ")
    #puts("facturacions_total_count=#{@facturacions_total_count} ")


    @vertical_total_count = @facturacions_total_count + @convenios_total_count
    #puts("vertical_total_count=#{@vertical_total_count} ")
    @oxy_total_count = @current_oxy ? @current_oxy.oxy_records.size : 0
    @oxy_total_count += @current_oxy.arrastre if @current_oxy
    @cmpc_total_count = @current_cmpc ? @current_cmpc.cmpc_records.size : 0

    #puts("cmpc_total_count=#{@cmpc_total_count} ")
    #puts("oxy_total_count=#{@oxy_total_count} ")


    @ald_total_uf = to_decimal(@current_ald&.total_uf)

    if @current_ald

      @ald_total_count = (@current_ald.n1.to_i || 0) + (@current_ald.n2.to_i || 0)

    else
      @ald_total_count = 0

    end

    @ald_daily_uf = Hash.new(BigDecimal("0")).tap do |h|
      if @current_ald
        h[@days_in_month] = @ald_total_uf
      end
    end


    @ald_daily_count = Hash.new(0).tap do |h|
      if @current_ald
        h[@days_in_month] = @ald_total_count
      end
    end

    @ald_month_by_empresa = { "ALD" => @ald_total_uf }
    @ald_month_count_by_empresa = { "ALD" => @ald_total_count }

    @otros_month_by_empresa = month_sums_by_company_otros(@otros)
    @otros_total_uf         = @otros_month_by_empresa.values.sum
    @otros_daily_uf         = daily_sums_otros(@otros)
    @otros_day_company      = daily_company_otros(@otros)

    @otros_total_count      = @otros.sum { |o| o.n1.to_i + o.n2.to_i }
    @otros_daily_count      = daily_counts_otros(@otros)
    @otros_day_company_count = daily_counts_company_otros(@otros)
    @otros_month_by_empresa_count = month_sums_by_company_otros_count(@otros)






    require "i18n" unless defined?(I18n)

    norm = ->s { I18n.transliterate(s.to_s).gsub(/[\s\.]/,'').downcase }

    target_rut = @mandante_names.find { |_rut, nom| norm[nom].include?("forestalarauco") }&.first
    target_rut ||= "Forestal Arauco SA"

    arauco_keys = @otros_month_by_empresa.keys.select { |k| norm[k].include?("arauco") }
    arauco_keys_count = @otros_month_by_empresa_count.keys.select { |k| norm[k].include?("arauco") }


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

    unless arauco_keys_count.empty?
      total_arauco_count = arauco_keys_count.sum { |k| @otros_month_by_empresa_count[k].to_i }
      @otros_month_by_empresa_count[target_rut] ||= 0
      @otros_month_by_empresa_count[target_rut]  += total_arauco_count
      arauco_keys_count.each { |k| @otros_month_by_empresa_count.delete(k) }

      ar_day_count_tot = Hash.new(0)
      arauco_keys_count.each do |k|
        @otros_day_company_count[k].each { |d,v| ar_day_count_tot[d] += v }
        @otros_day_company_count.delete(k)
      end
      @otros_day_company_count[target_rut] ||= Hash.new(0)
      ar_day_count_tot.each { |d,v| @otros_day_company_count[target_rut][d] += v }
    end



    #puts("otros_total_count=#{@otros_total_count} ")
    #puts("otros_daily_count=#{@otros_daily_count.inspect} ")
    #puts("otros_day_company_count=#{@otros_day_company_count.inspect} ")
    #puts("otros_month_by_empresa_count=#{@otros_month_by_empresa_count.inspect} ")


    @evaluacion_vanilla_total = sum_precios(@evaluacions)
    @evaluacion_total_uf = @evaluacion_vanilla_total + @oxy_total_uf + @ald_total_uf + @otros_total_uf + @cmpc_total_uf
    @sum_month                = @vertical_total_uf + @evaluacion_total_uf + @movilidad_total_uf

    @evaluacion_vanilla_count = @evaluacions.size

    @evaluacion_total_count = @evaluacion_vanilla_count + @oxy_total_count + @ald_total_count + @otros_total_count + @cmpc_total_count


    #puts("evaluacion_vanilla_count=#{@evaluacion_vanilla_count} ")
    #puts("oxy_total_count=#{@oxy_total_count} ")
    #puts("ald_total_count=#{@ald_total_count} ")
    #puts("otros_total_count=#{@otros_total_count} ")
    #puts("cmpc_total_count=#{@cmpc_total_count} ")

    #puts(@evaluacion_total_count.inspect)


    @count_month = @vertical_total_count + @evaluacion_total_count + @movilidad_total_count

    #puts("count_month=#{@count_month} ")

    vertical_facturacions_by_day = daily_sums(@facturacions, :fecha_venta)
    vertical_counts_by_day = vertical_daily_counts(@facturacions, :fecha_venta)
    vertical_convenios_by_day    = daily_sums_convenios(@convenios)
    convenios_counts_by_day = daily_counts_convenios(@convenios)

    @vertical_daily_uf = (1..@days_in_month).each_with_object(Hash.new(BigDecimal("0"))) do |day, h|
      h[day] = vertical_facturacions_by_day[day] + vertical_convenios_by_day[day]
    end

    @vertical_daily_count = (1..@days_in_month).each_with_object(Hash.new(0)) do |day, h|
      h[day] = vertical_counts_by_day[day].to_i + convenios_counts_by_day[day].to_i
    end

    #puts("vertical_daily_count=#{@vertical_daily_count.inspect} ")


    @evaluacion_vanilla_daily = daily_sums(@evaluacions,   :fecha_inspeccion)
    @evaluacion_vanilla_daily_count = daily_counts(@evaluacions, :fecha_inspeccion)
    @oxy_daily_uf             = oxy_daily_sums(@current_oxy)
    @oxy_daily_count          = oxy_daily_counts(@current_oxy)
    @cmpc_daily_uf            = cmpc_daily_sums(@current_cmpc)
    @cmpc_daily_count         = cmpc_daily_counts(@current_cmpc)
    @evaluacion_daily_uf = merge_daily(
      merge_daily(@evaluacion_vanilla_daily, @oxy_daily_uf),
      merge_daily(merge_daily(@ald_daily_uf, @otros_daily_uf), @cmpc_daily_uf)
    )


    @evaluacion_daily_count = merge_daily_count(
      merge_daily_count(@evaluacion_vanilla_daily_count, @oxy_daily_count),
      merge_daily_count(merge_daily_count(@ald_daily_count, @otros_daily_count), @cmpc_daily_count)
    )

    #puts("evaluacion_daily_count=#{@evaluacion_daily_count.inspect} ")



    @sum_daily_uf = merge_daily(
      merge_daily(@vertical_daily_uf, @evaluacion_daily_uf),
      @movilidad_daily_uf
    )



       @sum_daily_count = merge_daily_count(
         merge_daily_count(@vertical_daily_count, @evaluacion_daily_count),
         @movilidad_daily_count
       )

    vertical_facturacions_by_empresa = month_sums_by_company(@facturacions)
    vertical_convenios_by_empresa    = month_sums_by_company_convenios(@convenios)

    @vertical_month_by_empresa = vertical_facturacions_by_empresa.merge(vertical_convenios_by_empresa) do |_empresa, monto_f, monto_c|
      monto_f + monto_c
    end

    @evaluacion_month_by_empresa = month_sums_by_company(@evaluacions)

    oxy_name = "Occidental Chemical Chile Limitada"
    oxy_rut  = @mandante_names.key(oxy_name) || oxy_name

    cmpc_name = "EMPRESAS CMPC S.A"
    cmpc_rut = @mandante_names.key(cmpc_name) || cmpc_name

    @oxy_month_by_empresa = { oxy_rut => @oxy_total_uf }
    @cmpc_month_by_empresa = { cmpc_rut => @cmpc_total_uf }

    @month_by_empresa = merge_hashes(@vertical_month_by_empresa,
                                     @evaluacion_month_by_empresa,
                                     @movilidad_month_by_empresa,
                                     @oxy_month_by_empresa,
                                     @cmpc_month_by_empresa,
                                     @ald_month_by_empresa,
                                     @otros_month_by_empresa)


    #puts("month_by_empresa=#{@month_by_empresa.inspect} ")

    vertical_facturacions_by_day_company = daily_company(@facturacions, :fecha_venta)
    vertical_convenios_by_day_company    = daily_company_convenios(@convenios)

    @vertical_day_company = {}
    @vertical_day_company_count = {}

    vertical_facturacion_count_by_day_company = daily_count_company(@facturacions, :fecha_venta)
    vertical_convenio_count_by_day_company    = daily_count_company_convenios(@convenios)


    (empresas = vertical_facturacions_by_day_company.keys | vertical_convenios_by_day_company.keys).each do |empresa|
      dias = vertical_facturacions_by_day_company[empresa].keys | vertical_convenios_by_day_company[empresa].keys
      @vertical_day_company[empresa] ||= Hash.new(BigDecimal("0"))
      @vertical_day_company_count[empresa] ||= Hash.new(0)
      dias.each do |day|
        monto_f = vertical_facturacions_by_day_company[empresa][day] || BigDecimal("0")
        monto_c = vertical_convenios_by_day_company[empresa][day]    || BigDecimal("0")
        @vertical_day_company[empresa][day] = monto_f + monto_c
        @vertical_day_company_count[empresa][day] = (vertical_facturacion_count_by_day_company[empresa][day] || 0) + (vertical_convenio_count_by_day_company[empresa][day] || 0)
      end
    end

    #puts("vertical_day_company_count=#{@vertical_day_company_count.inspect} ")

    @vertical_month_by_empresa_count = @vertical_day_company_count.transform_values { |per_day| per_day.values.sum }

    #puts("vertical_month_by_empresa_count=#{@vertical_month_by_empresa_count.inspect} ")

    @eval_vanilla_day_comp  = daily_company(@evaluacions,  :fecha_inspeccion)
    @eval_vanilla_day_comp_count = daily_count_company(@evaluacions, :fecha_inspeccion)


    @oxy_day_company        = build_oxy_day_company(@current_oxy)
    @oxy_day_company_count = build_oxy_day_company_count(@current_oxy)


    @cmpc_day_company        = build_cmpc_day_company(@current_cmpc)
    @cmpc_day_company_count = build_cmpc_day_company_count(@current_cmpc)



    @evaluation_day_company = merge_nested(
      @eval_vanilla_day_comp,
      @oxy_day_company,
      @cmpc_day_company,
      @ald_day_company ||= { "ALD" => @ald_daily_uf },
      @otros_day_company
    )

    @evaluation_day_company_count = merge_nested_count(
      @eval_vanilla_day_comp_count,
      @oxy_day_company_count,
      @cmpc_day_company_count,
      @ald_day_company_count ||= { "ALD" => @ald_daily_count },
      @otros_day_company_count
    )

    #puts("evaluation_day_company_count=#{@evaluation_day_company_count.inspect} ")
    @evaluation_month_by_empresa_count =
      @evaluation_day_company_count.transform_values { |per_day| per_day.values.sum }

oxy_label  = "Oxy"
cmpc_label = "Transporte de personal CMPC"

if oxy_rut && @evaluation_month_by_empresa_count.key?(oxy_label)
  @evaluation_month_by_empresa_count[oxy_rut] =
    @evaluation_month_by_empresa_count.fetch(oxy_rut, 0).to_i +
    @evaluation_month_by_empresa_count.delete(oxy_label).to_i
end

if cmpc_rut && @evaluation_month_by_empresa_count.key?(cmpc_label)
  @evaluation_month_by_empresa_count[cmpc_rut] =
    @evaluation_month_by_empresa_count.fetch(cmpc_rut, 0).to_i +
    @evaluation_month_by_empresa_count.delete(cmpc_label).to_i
end

@evaluation_month_by_empresa_count_rolled =
  rollup_counts_to_mandante(@evaluation_month_by_empresa_count)

@vertical_month_by_empresa_count_rolled =
  rollup_counts_to_mandante(@vertical_month_by_empresa_count)

    @day_company            = merge_nested(@vertical_day_company,
                                           @evaluation_day_company,
                                           @movilidad_day_company)

    @day_company_count      = merge_nested_count(@vertical_day_company_count,
                                                 @evaluation_day_company_count,
                                                 @movilidad_day_company_count)



    puts("day_company_count=#{@day_company_count.inspect} ")

    @module_months = {
      "Transporte Vertical"        => @vertical_month_by_empresa,
      "Evaluación de Competencias" => merge_hashes(@evaluacion_month_by_empresa,
                                                   @ald_month_by_empresa,
                                                   @oxy_month_by_empresa,
                                                   @cmpc_month_by_empresa,
                                                   @otros_month_by_empresa),
      "Movilidad"                  => @movilidad_month_by_empresa,

    }




    @module_months_count = {
      "Transporte Vertical"        => @vertical_month_by_empresa_count_rolled,
      "Evaluación de Competencias" => @evaluation_month_by_empresa_count_rolled,
      "Movilidad"                  => @movilidad_month_by_empresa_count
    }

    @alias_empresas_por_mandante_month = Hash.new { |h,k| h[k] = [] }

    mandantes_month = (@movilidad_month_by_empresa || {}).keys
    all_empresas_month = (@module_months || {})
                           .values.flat_map(&:keys).uniq

    mandantes_month.each do |mand_key|
      mname = display_name_for(mand_key).to_s
      all_empresas_month.each do |emp_key|
        next if emp_key == mand_key
        next if (@empresas_por_mandante || {})[mand_key].to_a.include?(emp_key)

        ename = display_name_for(emp_key).to_s
        if names_match?(ename, mname)
          @alias_empresas_por_mandante_month[mand_key] << emp_key
        end
      end
      @alias_empresas_por_mandante_month[mand_key].uniq!
    end


    puts("@module_months_count=#{@module_months_count.inspect} ")


    @month_by_empresa_count = merge_counts_hashes(
      @vertical_month_by_empresa_count_rolled,
      @evaluation_month_by_empresa_count_rolled,
      @movilidad_month_by_empresa_count,
      )
    require "set"
    _module_company_keys = (
      @vertical_month_by_empresa.keys |
        @evaluacion_month_by_empresa.keys |
        @otros_month_by_empresa.keys |
        @ald_month_by_empresa.keys |
        @oxy_month_by_empresa.keys |
        @cmpc_month_by_empresa.keys
    )

    @month_by_empresa       = @month_by_empresa.dup
    @month_by_empresa_count = @month_by_empresa_count.dup

    moved = Set.new
    (@mandante_names || {}).each do |mand_rut, mand_name|
      next if mand_name.blank?
      matches = @month_by_empresa.keys.select do |k|
        k.to_s != mand_rut.to_s &&
          _module_company_keys.include?(k) &&
          names_match?(display_name_for(k), mand_name)
      end
      matches.each do |k|
        next if moved.include?(k)
        @month_by_empresa[mand_rut] =
          @month_by_empresa.fetch(mand_rut, 0.to_d) + @month_by_empresa.delete(k).to_d
        @month_by_empresa_count[mand_rut] =
          @month_by_empresa_count.fetch(mand_rut, 0) + @month_by_empresa_count.delete(k).to_i
        moved << k
      end
    end


    puts("month_by_empresa_count=#{@month_by_empresa_count.inspect} ")
    end
  end


  private

  def build_query
    {}.tap do |q|
      q[:year]    = params[:year]    if params[:year].present?
      q[:month]   = params[:month]   if params[:month].present?
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
        n1:               f["n1"],
        fecha_entrega:    f["fecha_entrega"],
        factura:          f["factura"],
        fecha_venta:      f["fecha_venta"],
        fecha_inspeccion: f["fecha_inspeccion"],
        empresa:          f["empresa"],
        precio:           f["precio"],
        pesos:            to_pesos(f["precio"], f["fecha_venta"]),
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
  def parse_convenios(arr)
    Array(arr).map do |c|
      OpenStruct.new(
        id:           c["id"],
        fecha_venta:  c["fecha_venta"],
        n1:           c["n1"],
        v1:           c["v1"],
        empresa_id:   c["empresa_id"],
        empresa_nombre: c["empresa_nombre"] || c["empresa"]
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

  def parse_cmpc(data)
    return nil unless data

    OpenStruct.new(
      id:         data["id"],
      month:      data["month"],
      year:       data["year"],
      numero_servicios: data["numero_servicios"],
      total_uf:   to_decimal(data["total_uf"] || data["total"] || 0.0),
      cmpc_records:         Array(data["cmpc_records"]).map do |r|
        OpenStruct.new(
          id:         r["id"],
          suma:       r["suma"],
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
      n2:         data["n2"],
      total_uf:   to_decimal(data["total"])
    )
  end

  def parse_otros(arr)
    Array(arr).map do |o|
      empresa_hash = o["empresa"] || {}
      fecha_parsed = o["fecha"] && Date.parse(o["fecha"]) rescue nil

      OpenStruct.new(
        id:             o["id"],
        fecha:          fecha_parsed,
        month:          o["month"] || fecha_parsed&.month,
        year:           o["year"]  || fecha_parsed&.year,
        n1:             to_decimal(o["n1"]),
        n2:             to_decimal(o["n2"]),
        total:          to_decimal(o["total"]),            # ⬅️ monto UF
        v1:             to_decimal(o.fetch("v1", "0.1")),
        empresa_id:     empresa_hash["id"] || o["empresa_id"],
        empresa_nombre: empresa_hash["nombre"] ||
          o["empresa_nombre"] ||
          o["empresa"] || "sin_empresa"
      )
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

  def sum_precios_convenios(records)
    Array(records).sum(BigDecimal("0")) { |r| to_decimal(r&.v1) }
  end


  def daily_sums_convenios(records)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        date_str = r&.fecha_venta
        next if date_str.blank?

        day = Date.parse(date_str.to_s).day rescue next
        h[day] += to_decimal(r.v1)
      end
    end
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



  def daily_counts(records, date_attr)
    Hash.new(0).tap do |h|
      Array(records).each do |r|
        date_str = r&.public_send(date_attr)
        next if date_str.blank?

        day = Date.parse(date_str.to_s).day rescue next
        h[day] += 1
      end
    end
  end

  def vertical_daily_counts(records, date_attr)
    Hash.new(0).tap do |h|
      Array(records).each do |r|
        date_str = r&.public_send(date_attr)
        next if date_str.blank?

        day = Date.parse(date_str.to_s).day rescue next
        h[day] += r.n1.to_i
      end
    end
  end
  def daily_counts_convenios(records)
    Hash.new(0).tap do |h|
      Array(records).each do |r|
        date_str = r&.fecha_venta
        next if date_str.blank?

        day = Date.parse(date_str.to_s).day rescue next
        h[day] += r.n1
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

  def month_sums_by_company_convenios(records)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa] += to_decimal(r.v1)
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

  def merge_daily_count(a, b)
    range = 1..@days_in_month
    Hash.new(0).tap { |h| range.each { |d| h[d] = (a[d] || 0) + (b[d] || 0) } }
  end

  def merge_hashes(*hashes)
    Hash.new(BigDecimal("0")).tap do |h|
      hashes.each { |hh| hh.each { |k,v| h[k] += v } }
    end
  end

  def merge_counts_hashes(*hashes)
    Hash.new(0).tap do |h|
      hashes.each { |hh| hh.each { |k,v| h[k] += v.to_i } }
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

  def merge_nested_count(*levels)
    range = 1..@days_in_month
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
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



  def daily_company_convenios(records)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        day = Date.parse(r.fecha_venta.to_s).day rescue next
        empresa = r.empresa_nombre.presence || "sin_empresa"
        h[empresa][day] += to_decimal(r.v1)
      end
    end
  end

  def daily_count_company(records, date_attr)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      Array(records).each do |r|
        day = Date.parse(r.public_send(date_attr).to_s).day rescue next
        h[r.empresa.presence || "sin_empresa"][day] += r.n1.to_i
      end
    end
  end

  def daily_count_company_convenios(records)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      Array(records).each do |r|
        day = Date.parse(r.fecha_venta.to_s).day rescue next
        empresa = r.empresa_nombre.presence || "sin_empresa"
        h[empresa][day] += r.n1
      end
    end
  end


  def sum_precios_otros(records)
    Array(records).sum(BigDecimal("0")) { |r| to_decimal(r.total) }
  end

  def daily_sums_otros(records)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        next if r.fecha.blank?
        day = (r.fecha.is_a?(Date) ? r.fecha : Date.parse(r.fecha.to_s)).day rescue next
        h[day] += to_decimal(r.total)
      end
    end
  end

  def daily_counts_otros(records)
    Hash.new(0).tap do |h|
      Array(records).each do |r|
        next if r.fecha.blank?
        day = (r.fecha.is_a?(Date) ? r.fecha : Date.parse(r.fecha.to_s)).day rescue next
        h[day] += r.n1.to_i + r.n2.to_i
      end
    end
  end

  def month_sums_by_company_otros(records)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa] += to_decimal(r.total)
      end
    end
  end

  def month_sums_by_company_otros_count(records)
    Hash.new(0).tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa] += r.n1.to_i + r.n2.to_i
      end
    end
  end

  def daily_company_otros(records)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        next if r.fecha.blank?
        day = (r.fecha.is_a?(Date) ? r.fecha : Date.parse(r.fecha.to_s)).day rescue next
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa][day] += to_decimal(r.total)
      end
    end
  end

  def daily_counts_company_otros(records)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      Array(records).each do |r|
        next if r.fecha.blank?
        day = (r.fecha.is_a?(Date) ? r.fecha : Date.parse(r.fecha.to_s)).day rescue next
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa][day] += r.n1.to_i + r.n2.to_i
      end
    end
  end


  def build_oxy_day_company(current_oxy)
    return {} unless current_oxy
    daily = oxy_daily_sums(current_oxy)

    { "Oxy" => daily }
  end

  def build_oxy_day_company_count(current_oxy)
    return {} unless current_oxy
    daily = oxy_daily_counts(current_oxy)

    { "Oxy" => daily }
  end

  def build_cmpc_day_company(current_cmpc)
    return {} unless current_cmpc
    daily = cmpc_daily_sums(current_cmpc)

    { "Transporte de personal CMPC" => daily }
  end

  def build_cmpc_day_company_count(current_cmpc)
    return {} unless current_cmpc
    daily = cmpc_daily_counts(current_cmpc)

    { "Transporte de personal CMPC" => daily }
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

  def oxy_daily_counts(current_oxy)
    return Hash.new(0) unless current_oxy

    Hash.new(0).tap do |h|
      current_oxy.oxy_records.each do |rec|
        day = (rec.fecha.is_a?(Date) ? rec.fecha : Date.parse(rec.fecha.to_s)).day
        h[day] += 1
      end
      h[1] += current_oxy.arrastre unless current_oxy.arrastre.zero?
    end
  end

  def cmpc_daily_sums(current_cmpc)
    return Hash.new(BigDecimal("0")) unless current_cmpc



    Hash.new(BigDecimal("0")).tap do |h|
      current_cmpc.cmpc_records.each do |rec|
        price_per_rec = to_decimal(rec.suma)
        day = (rec.fecha.is_a?(Date) ? rec.fecha : Date.parse(rec.fecha.to_s)).day
        h[day] += price_per_rec
      end
    end
  end

  def cmpc_daily_counts(current_cmpc)
    return Hash.new(0) unless current_cmpc

    Hash.new(0).tap do |h|
      current_cmpc.cmpc_records.each do |rec|
        day = (rec.fecha.is_a?(Date) ? rec.fecha : Date.parse(rec.fecha.to_s)).day
        h[day] += 1
      end
    end
  end

  def rollup_counts_to_mandante(map)
    Hash.new(0).tap do |rolled|
      map.each do |k, v|
        if @emp_to_mandante.key?(k)
          mand_rut, _ = @emp_to_mandante[k]
          rolled[mand_rut] += v.to_i
        else
          rolled[k] += v.to_i
        end
      end
    end
  end




  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales
  #Funciones anuales




  def parse_facturacions_anual(arr)
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
        n1:               f["n1"],
        fecha_entrega:    f["fecha_entrega"],
        factura:          f["factura"],
        fecha_venta:      f["fecha_venta"],
        fecha_inspeccion: f["fecha_inspeccion"],
        empresa:          f["empresa"],
        precio:           f["precio"],
        pesos:            to_pesos(f["precio"], f["fecha_venta"]),
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

  def parse_convenios_anual(arr)
    Array(arr).map do |c|
      OpenStruct.new(
        id:             c["id"],
        fecha_venta:    c["fecha_venta"],
        n1:             c["n1"],
        v1:             c["v1"],
        empresa_id:     c["empresa_id"],
        empresa_nombre: c["empresa_nombre"] || c["empresa"]
      )
    end
  end

  def parse_evaluacions_anual(arr)
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

  def ensure_array(x)
    return [] if x.nil?
    x.is_a?(Array) ? x : [x]
  end

  def parse_oxy_anual(arr)
    ensure_array(arr).select { |e| e.is_a?(Hash) }.map do |data|
      OpenStruct.new(
        id:                 data["id"] || data[:id],
        month:              data["month"] || data[:month],
        year:               data["year"] || data[:year],
        numero_conductores: data["numero_conductores"] || data[:numero_conductores],
        arrastre:           data["arrastre"] || data[:arrastre],
        suma:               data["suma"] || data[:suma],
        total_uf:           data["total_uf"] || data[:total_uf],
        oxy_records:        ensure_array(data["oxy_records"] || data[:oxy_records]).select { |r| r.is_a?(Hash) }.map do |r|
          OpenStruct.new(
            id:         r["id"] || r[:id],
            fecha:      r["fecha"] || r[:fecha],
            created_at: r["created_at"] || r[:created_at],
            updated_at: r["updated_at"] || r[:updated_at]
          )
        end
      )
    end
  end

  def parse_cmpc_anual(arr)
    ensure_array(arr).select { |e| e.is_a?(Hash) }.map do |data|
      OpenStruct.new(
        id:               data["id"] || data[:id],
        month:            data["month"] || data[:month],
        year:             data["year"] || data[:year],
        numero_servicios: data["numero_servicios"] || data[:numero_servicios],
        total_uf:         to_decimal((data["total_uf"] || data[:total_uf] || data["total"] || data[:total] || 0.0)),
        cmpc_records:     ensure_array(data["cmpc_records"] || data[:cmpc_records]).select { |r| r.is_a?(Hash) }.map do |r|
          OpenStruct.new(
            id:         r["id"] || r[:id],
            suma:       r["suma"] || r[:suma],
            fecha:      r["fecha"] || r[:fecha],
            created_at: r["created_at"] || r[:created_at],
            updated_at: r["updated_at"] || r[:updated_at]
          )
        end
      )
    end
  end

  def parse_ald_anual(arr)
    ensure_array(arr).select { |e| e.is_a?(Hash) }.map do |data|
      OpenStruct.new(
        id:       data["id"] || data[:id],
        month:    data["month"] || data[:month],
        year:     data["year"] || data[:year],
        n1:       data["n1"] || data[:n1],
        n2:       data["n2"] || data[:n2],
        total_uf: to_decimal(data["total"] || data[:total])
      )
    end
  end

  def parse_otros_anual(arr)
    ensure_array(arr).select { |e| e.is_a?(Hash) }.map do |o|
      empresa_hash = o["empresa"] || o[:empresa] || {}
      fecha_str = o["fecha"] || o[:fecha]
      fecha_parsed = fecha_str && (Date.parse(fecha_str) rescue nil)

      OpenStruct.new(
        id:             o["id"] || o[:id],
        fecha:          fecha_parsed,
        month:          o["month"] || o[:month] || fecha_parsed&.month,
        year:           o["year"]  || o[:year]  || fecha_parsed&.year,
        n1:             to_decimal(o["n1"] || o[:n1]),
        n2:             to_decimal(o["n2"] || o[:n2]),
        total:          to_decimal(o["total"] || o[:total]),
        v1:             to_decimal((o["v1"] || o[:v1] || "0.1")),
        empresa_id:     empresa_hash["id"] || empresa_hash[:id] || o["empresa_id"] || o[:empresa_id],
        empresa_nombre: empresa_hash["nombre"] || empresa_hash[:nombre] || o["empresa_nombre"] || o[:empresa_nombre] || o["empresa"] || o[:empresa] || "sin_empresa"
      )
    end
  end

  def months_range_for_year(year)
    y = year.to_i
    end_m = (y == Date.current.year ? Date.current.month : 12)
    (1..end_m)
  end

  def uf_value_for(year, month)
    rec = Iva.find_by(year: year.to_i, month: month.to_i)
    (rec&.valor || rec&.value || rec&.uf || rec&.monto).to_d
  end

  def uf_map_for_year(year)
    months_range_for_year(year).each_with_object({}) { |m,h| h[m] = uf_value_for(year, m) }
  end

  def monthly_sums_anual(records, date_attr, year)
    Hash.new(BigDecimal("0")).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0.to_d }
      Array(records).each do |r|
        date_str = r&.public_send(date_attr)
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[month] += to_decimal(r.precio)
      end
    end
  end

  def monthly_counts_anual(records, date_attr, year)
    Hash.new(0).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0 }
      Array(records).each do |r|
        date_str = r&.public_send(date_attr)
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[month] += r.n1.to_i + r.n2.to_i
      end
    end
  end

  def monthly_sums_convenios_anual(records, year)
    Hash.new(BigDecimal("0")).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0.to_d }
      Array(records).each do |r|
        date_str = r&.fecha_venta
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[month] += to_decimal(r.v1)
      end
    end
  end

  def monthly_counts_convenios_anual(records, year)
    Hash.new(0).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0 }
      Array(records).each do |r|
        date_str = r&.fecha_venta
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[month] += r.n1.to_i
      end
    end
  end

  def monthly_sums_by_company_anual(records, date_attr, year)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        empresa  = (r.empresa.presence || "sin_empresa").to_s
        date_str = r&.public_send(date_attr)
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[empresa][month] += to_decimal(r.precio)
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0.to_d }
      end
    end
  end

  def year_sums_by_company_anual(records)
    Hash.new(BigDecimal("0")).tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa.presence || "sin_empresa").to_s
        h[empresa] += to_decimal(r.precio)
      end
    end
  end

  def monthly_sums_by_company_convenios_anual(records, year)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        date_str = r&.fecha_venta
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[empresa][month] += to_decimal(r.v1)
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0.to_d }
      end
    end
  end

  def merge_monthly_anual(a, b, year)
    range = months_range_for_year(year)
    Hash.new(BigDecimal("0")).tap { |h| range.each { |m| h[m] = a[m].to_d + b[m].to_d } }
  end

  def merge_monthly_count_anual(a, b, year)
    range = months_range_for_year(year)
    Hash.new(0).tap { |h| range.each { |m| h[m] = a[m].to_i + b[m].to_i } }
  end

  def merge_nested_monthly_anual(*levels, year:)
    range = months_range_for_year(year)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      levels.each do |lvl|
        lvl.each { |k,sub| range.each { |m| h[k][m] += sub[m].to_d } }
      end
    end
  end

  def merge_nested_count_monthly_anual(*levels, year:)
    range = months_range_for_year(year)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      levels.each do |lvl|
        lvl.each { |k,sub| range.each { |m| h[k][m] += sub[m].to_i } }
      end
    end
  end

  def monthly_company_anual(records, date_attr, year)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa.presence || "sin_empresa").to_s
        date_str = r&.public_send(date_attr)
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[empresa][month] += to_decimal(r.precio)
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0.to_d }
      end
    end
  end

  def monthly_company_convenios_anual(records, year)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        empresa = r.empresa_nombre.presence || "sin_empresa"
        date_str = r&.fecha_venta
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[empresa][month] += to_decimal(r.v1)
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0.to_d }
      end
    end
  end

  def monthly_count_company_anual(records, date_attr, year)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      Array(records).each do |r|
        empresa = (r.empresa.presence || "sin_empresa").to_s
        date_str = r&.public_send(date_attr)
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[empresa][month] += r.n1.to_i + r.n2.to_i
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0 }
      end
    end
  end

  def monthly_count_company_convenios_anual(records, year)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      Array(records).each do |r|
        empresa = r.empresa_nombre.presence || "sin_empresa"
        date_str = r&.fecha_venta
        next if date_str.blank?
        month = Date.parse(date_str.to_s).month rescue next
        h[empresa][month] += r.n1.to_i
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0 }
      end
    end
  end

  def sum_precios_otros_anual(records)
    Array(records).sum(BigDecimal("0")) { |r| to_decimal(r.total) }
  end

  def monthly_sums_otros_anual(records, year)
    Hash.new(BigDecimal("0")).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0.to_d }
      Array(records).each do |r|
        next if r.fecha.blank?
        month = (r.fecha.is_a?(Date) ? r.fecha.month : (Date.parse(r.fecha.to_s).month rescue nil))
        next unless month
        h[month] += to_decimal(r.total)
      end
    end
  end

  def monthly_counts_otros_anual(records, year)
    Hash.new(0).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0 }
      Array(records).each do |r|
        next if r.fecha.blank?
        month = (r.fecha.is_a?(Date) ? r.fecha.month : (Date.parse(r.fecha.to_s).month rescue nil))
        next unless month
        h[month] += r.n1.to_i + r.n2.to_i
      end
    end
  end

  def monthly_company_otros_anual(records, year)
    Hash.new { |h,k| h[k] = Hash.new(BigDecimal("0")) }.tap do |h|
      Array(records).each do |r|
        next if r.fecha.blank?
        month = (r.fecha.is_a?(Date) ? r.fecha.month : (Date.parse(r.fecha.to_s).month rescue nil))
        next unless month
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa][month] += to_decimal(r.total)
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0.to_d }
      end
    end
  end

  def monthly_counts_company_otros_anual(records, year)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |h|
      Array(records).each do |r|
        next if r.fecha.blank?
        month = (r.fecha.is_a?(Date) ? r.fecha.month : (Date.parse(r.fecha.to_s).month rescue nil))
        next unless month
        empresa = (r.empresa_nombre.presence || "sin_empresa").to_s
        h[empresa][month] += r.n1.to_i + r.n2.to_i
      end
      months_range_for_year(year).each do |m|
        h.keys.each { |emp| h[emp][m] ||= 0 }
      end
    end
  end

  def oxy_monthly_sums_anual(oxies, year)
    Hash.new(BigDecimal("0")).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0.to_d }
      Array(oxies).each do |o|
        price_per_rec = to_decimal(o&.suma)
        arrastre_cnt  = to_decimal(o&.arrastre)
        month_key = o&.month.to_i
        if month_key > 0
          h[month_key] += (o.oxy_records.to_a.size.to_d * price_per_rec) + (arrastre_cnt * price_per_rec)
        else
          o.oxy_records.to_a.each do |rec|
            m = (rec.fecha.is_a?(Date) ? rec.fecha.month : (Date.parse(rec.fecha.to_s).month rescue nil))
            next unless m
            h[m] += price_per_rec
          end
          h[1] += arrastre_cnt * price_per_rec unless arrastre_cnt.zero?
        end
      end
    end
  end

  def oxy_monthly_counts_anual(oxies, year)
    Hash.new(0).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0 }
      Array(oxies).each do |o|
        month_key = o&.month.to_i
        if month_key > 0
          h[month_key] += o.oxy_records.to_a.size
          h[month_key] += o.arrastre.to_i unless o.arrastre.to_i.zero?

        end
      end
    end
  end

  def cmpc_monthly_sums_anual(cmpcs, year)
    Hash.new(BigDecimal("0")).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0.to_d }
      Array(cmpcs).each do |c|
        c.cmpc_records.to_a.each do |rec|
          m = (rec.fecha.is_a?(Date) ? rec.fecha.month : (Date.parse(rec.fecha.to_s).month rescue nil))
          next unless m
          h[m] += to_decimal(rec.suma)
        end
      end
    end
  end

  def cmpc_monthly_counts_anual(cmpcs, year)
    Hash.new(0).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0 }
      Array(cmpcs).each do |c|
        c.cmpc_records.to_a.each do |rec|
          m = (rec.fecha.is_a?(Date) ? rec.fecha.month : (Date.parse(rec.fecha.to_s).month rescue nil))
          next unless m
          h[m] += 1
        end
      end
    end
  end

  def ald_monthly_sums_anual(alds, year)
    Hash.new(BigDecimal("0")).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0.to_d }
      Array(alds).each do |a|
        m = a&.month.to_i
        next unless m > 0
        h[m] += to_decimal(a.total_uf || a.total)
      end
    end
  end

  def ald_monthly_counts_anual(alds, year)
    Hash.new(0).tap do |h|
      months_range_for_year(year).each { |m| h[m] = 0 }
      Array(alds).each do |a|
        m = a&.month.to_i
        next unless m > 0
        h[m] += a.n1.to_i + a.n2.to_i
      end
    end
  end

  def build_oxy_month_company_anual(oxies, year)
    { "Oxy" => oxy_monthly_sums_anual(oxies, year) }
  end

  def build_oxy_month_company_count_anual(oxies, year)
    { "Oxy" => oxy_monthly_counts_anual(oxies, year) }
  end

  def build_cmpc_month_company_anual(cmpcs, year)
    { "Transporte de personal CMPC" => cmpc_monthly_sums_anual(cmpcs, year) }
  end

  def build_cmpc_month_company_count_anual(cmpcs, year)
    { "Transporte de personal CMPC" => cmpc_monthly_counts_anual(cmpcs, year) }
  end

  def rollup_counts_to_mandante_monthly_anual(map, year)
    Hash.new { |h,k| h[k] = Hash.new(0) }.tap do |rolled|
      map.each do |k, sub|
        key = if @emp_to_mandante.key?(k)
                Array(@emp_to_mandante[k]).first
              else
                k
              end
        months_range_for_year(year).each do |m|
          rolled[key][m] += sub[m].to_i
        end
      end
    end
  end

  def clp_by_month_from_uf_map(monthly_uf_map, year)
    Hash.new(0).tap do |h|
      ufm = uf_map_for_year(year)
      monthly_uf_map.each { |m, ufv| h[m] = (ufv.to_d * ufm[m].to_d).round(0, BigDecimal::ROUND_HALF_UP).to_i }
    end
  end

  def clp_total_from_monthly_uf(monthly_uf_map, year)
    ufm = uf_map_for_year(year)
    monthly_uf_map.sum { |m, ufv| (ufv.to_d * ufm[m].to_d) }.round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def normalize_key(str)
    require "i18n" unless defined?(I18n)
    I18n.transliterate(str.to_s).gsub(/\s+/, "").downcase
  end

  def fuzzy_same_or_contains?(a, b)
    na = normalize_key(a)
    nb = normalize_key(b)
    return false if na.empty? || nb.empty?
    na == nb || na.include?(nb) || nb.include?(na)
  end
  def norm_name(str)
    require "i18n" unless defined?(I18n)
    I18n.transliterate(str.to_s).gsub(/\s+/, "").downcase
  end

  def names_match?(a, b)
    an = norm_name(a)
    bn = norm_name(b)
    an == bn || an.include?(bn) || bn.include?(an)
  end

  def display_name_for(key)
    (@mandante_names || {})[key] || key
  end

end
