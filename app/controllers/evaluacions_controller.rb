# app/controllers/evaluacions_controller.rb
require "httparty"
require "json"

class EvaluacionsController < ApplicationController
  FACTURACIONS_API_URL = ENV.fetch(
    "FACTURACIONS_API_URL",
    "http://127.0.0.1:3000/api/v1/facturacions"
  ).freeze

  before_action :set_api_key!

  # GET /evaluacions
  def index
    @facturacions = parse_facturacions(fetch_facturacions)
  end



  # GET /evaluacions/:id
  def show
    @facturacion = fetch_facturacion(params[:id])
    redirect_to evaluacions_path, alert: t("errors.not_found") unless @facturacion
  end

  private

  # ---------- API helpers ----------

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
        pesos:            f[:pesos] || f['pesos'],
        created_at:       f[:created_at] || f['created_at'],
        updated_at:       f[:updated_at] || f['updated_at']
      )
    end
  end



end
