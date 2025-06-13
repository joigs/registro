# app/controllers/evaluacions_controller.rb
require "httparty"
require "json"
require "open3"
require "fileutils"

require 'bigdecimal'
require 'bigdecimal/util'
class EvaluacionsController < ApplicationController
  FACTURACIONS_API_URL = ENV.fetch(
    "FACTURACIONS_API_URL",
    "http://137.184.74.221:8082//api/v1/facturacions"
  ).freeze

  before_action :set_api_key!

  # GET /evaluacions
  def index
    @facturacions = parse_facturacions(fetch_facturacions)
  end



  # GET /evaluacions/:id
  def show
    raw = fetch_facturacion(params[:id])
    unless raw
      redirect_to evaluacions_path, alert: t("errors.not_found") and return
    end

    @facturacion = parse_facturacions([raw]).first
  end




  def export_excel
    raw   = fetch_facturacions
    data  = Array(raw).map do |f|
      {
        number:           f['number'],
        name:             f['name'],
        solicitud:        f['solicitud'],
        emicion:          f['emicion'],
        entregado:        f['entregado'],
        resultado:        f['resultado'],
        oc:               f['oc'],
        factura:          f['factura'],
        fecha_inspeccion: f['fecha_inspeccion'],
        precio:           f['precio'],
        pesos:            to_pesos(f['precio'], f['fecha_inspeccion'])
      }
    end

    json_data   = data.to_json
    timestamp   = Time.current.strftime("%Y%m%d_%H%M%S")
    tmp_dir     = Rails.root.join("tmp")
    FileUtils.mkdir_p(tmp_dir)
    output_file = tmp_dir.join("evaluaciones_#{timestamp}.xlsx").to_s
    script      = Rails.root.join("app","scripts","generate_evaluacions_excel.py").to_s

    stdout, stderr, status = Open3.capture3("python3", script, json_data, output_file)
    Rails.logger.info  stdout
    Rails.logger.error stderr unless stderr.blank?

    if status.success? && File.exist?(output_file)
      send_file output_file,
                filename: "evaluaciones_#{timestamp}.xlsx",
                disposition: "attachment"
    else
      flash[:alert] = "Error al generar Excel. Revisa los logs."
      redirect_to evaluacions_path
    end
  end

  private


  def fetch_facturacions
    query = filters_from_params
    response = api_get(FACTURACIONS_API_URL, query)

    response.success? ? JSON.parse(response.body) : []
  rescue JSON::ParserError => e
    Rails.logger.error("[FacturacionsAPI] JSON error: #{e.message}")
    []
  end

  def fetch_facturacion(id)
    response = api_get("#{FACTURACIONS_API_URL}/#{id}")

    response.success? ? JSON.parse(response.body) : nil
  rescue JSON::ParserError => e
    Rails.logger.error("[FacturacionsAPI] JSON error: #{e.message}")
    nil
  end





  def api_get(url, query = {})
    HTTParty.get(
      url,
      headers: { "X-API-KEY" => @api_key, "Accept" => "application/json" },
      query:   query,
      timeout: 5 # seg.
    )
  rescue HTTParty::Error, Net::OpenTimeout => e
    Rails.logger.error("[FacturacionsAPI] HTTP error: #{e.class} - #{e.message}")
    OpenStruct.new(success?: false, code: 503, body: nil)
  end

  def filters_from_params
    {}.tap do |q|
      q[:year]    = params[:year]    if params[:year].present?
      q[:month]   = params[:month]   if params[:month].present?
      q[:empresa] = params[:empresa] if params[:empresa].present?
    end
  end

  def set_api_key!
    @api_key = ENV.fetch("EVALUACION_API_KEY") do
      Rails.logger.warn("[FacturacionsAPI] Falta ENV['EVALUACION_API_KEY']")
      ""
    end
  end


  def parse_facturacions(records)
    Array(records).map do |f|
      OpenStruct.new(
        id:               f[:id] || f['id'],
        number:           f[:number] || f['number'],
        name:             f[:name] || f['name'],
        solicitud:        f[:solicitud] || f['solicitud'],
        emicion:          f[:emicion] || f['emicion'],
        entregado:        f[:entregado] || f['entregado'],
        resultado:        f[:resultado] || f['resultado'],
        oc:               f[:oc] || f['oc'],
        factura:          f[:factura] || f['factura'],
        fecha_inspeccion: f[:fecha_inspeccion] || f['fecha_inspeccion'],
        precio:           f[:precio] || f['precio'],
        pesos:            to_pesos(f['precio'], f['fecha_inspeccion']),
        created_at:       f[:created_at] || f['created_at'],
        updated_at:       f[:updated_at] || f['updated_at']
      )
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
