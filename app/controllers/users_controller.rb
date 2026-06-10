class UsersController < ApplicationController
  CER_MAN_RUTS_PERMITIDOS = %w[
    85805200
  ].freeze



  MESES_ES = %w[
    enero febrero marzo abril mayo junio
    julio agosto septiembre octubre noviembre diciembre
  ].freeze

  def show
    @user = User.find_by!(username: params[:username])
    @approved_id = 5
    if Current.user&.id == @approved_id
      meses = meses_disponibles
      @opciones_meses = meses.map do |fecha|
        ["#{MESES_ES[fecha.month - 1]} - #{fecha.year}", fecha.strftime("%Y-%m")]
      end

      mes_seleccionado = parse_mes(params[:mes], meses) || meses.first
      @mes_valor = mes_seleccionado.strftime("%Y-%m")

      desde        = mes_seleccionado.change(day: 26)
      @nueva_fecha = mes_seleccionado.next_month.beginning_of_month

      scope =
        SecondaryModels::CertChkLstExternal
          .joins("INNER JOIN CertActivo ON CertActivo.CertActivoId = CertChkLst.CertActivoId")
          .where("CertActivo.CerManRut IN (?)", CER_MAN_RUTS_PERMITIDOS)
          .where("CertChkLst.CertChkLstFchFac >= ? AND CertChkLst.CertChkLstFchFac < ?", desde, @nueva_fecha)

      @cert_chk_lsts = scope.select(
        "CertChkLst.CertChkLstId,
       CertChkLst.CertActivoId,
       CertChkLst.CertChkLstFch,
       CertChkLst.CertChkLstFchFac,
       CertActivo.CerManRut,
       CertActivo.CertActivoNro"

      ).order("CertChkLst.CertChkLstFchFac DESC")

      if params[:preview].present?
        @aviso_cantidad = scope.count
        @aviso_fecha    = @nueva_fecha.strftime("%d/%m/%Y")
      end
    end
  end




  def actualizar_fac
    @user = User.find_by!(username: params[:username])
    head :forbidden and return unless Current.user&.id == 1

    meses = meses_disponibles
    mes_seleccionado = parse_mes(params[:mes], meses) || meses.first

    desde       = mes_seleccionado.change(day: 26)
    nueva_fecha = mes_seleccionado.next_month.beginning_of_month

    ids = SecondaryModels::CertChkLstExternal
            .joins("INNER JOIN CertActivo ON CertActivo.CertActivoId = CertChkLst.CertActivoId")
            .where("CertActivo.CerManRut IN (?)", CER_MAN_RUTS_PERMITIDOS)
            .where("CertChkLst.CertChkLstFchFac >= ? AND CertChkLst.CertChkLstFchFac < ?", desde, nueva_fecha)
            .pluck("CertChkLst.CertChkLstId")

    actualizados =
      if ids.any?
        SecondaryWrite::CertChkLstWritable
          .where(CertChkLstId: ids)
          .update_all(CertChkLstFchFac: nueva_fecha)
      else
        0
      end
    redirect_back fallback_location: perfil_path(username: @user.username),
                  notice: "Se actualizaron #{actualizados} registros. " \
                    "CertChkLstFchFac quedó en #{nueva_fecha.strftime('%d/%m/%Y')}."
  end




  private

  def meses_disponibles
    inicio = Date.new(2025, 12, 1)
    fin    = Date.current.beginning_of_month
    meses  = []
    fecha  = inicio
    while fecha <= fin
      meses << fecha
      fecha = fecha.next_month
    end
    meses.reverse
  end



  def parse_mes(valor, meses_validos)
    return nil if valor.blank?
    anio, mes = valor.split("-").map(&:to_i)
    fecha = Date.new(anio, mes, 1)
    meses_validos.include?(fecha) ? fecha : nil
  rescue ArgumentError
    nil
  end
end