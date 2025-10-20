# app/services/pausa/reports/pdf_builder.rb
# frozen_string_literal: true
require "prawn"
require "prawn/table"

module Pausa
  module Reports
    class PdfBuilder
      Cell = Struct.new(:morning_done, :evening_done, :estado_false)

      def self.build(start_date:, end_date:, logs:, users:, windows:)
        # Fechas del rango solo lunes a viernes
        all_days = (start_date..end_date).select { |d| (1..5).include?(d.wday) }
        # Agrupar por lunes de la semana (semana ISO L–D; usamos L–V para columnas)
        weeks = all_days.group_by { |d| monday_of(d) }.sort_by { |monday, _| monday }

        # Indexar logs por (user_id, fecha) para lookup rápido
        by_key = logs.group_by { |l| [l.app_user_id, l.fecha] }

        Prawn::Document.new(page_size: "A4", margin: 24) do |pdf|
          pdf.font_size 10
          pdf.text "Reporte Pausas Activas", size: 16, style: :bold, align: :center
          pdf.move_down 6
          pdf.text "Rango: #{fmt_dmy(start_date)} – #{fmt_dmy(end_date)}", align: :center
          pdf.move_down 4
          pdf.text "Horario: Mañana #{fmt_hhmm(windows[:morning])} / Tarde #{fmt_hhmm(windows[:evening])}", align: :center
          pdf.move_down 10

          weeks.each_with_index do |(monday, days_in_week), idx|
            # Aseguramos que solo estén L–V y dentro del rango
            days = (0..4).map { |i| monday + i }.select { |d| d >= start_date && d <= end_date }

            # Subtítulo de semana
            pdf.start_new_page if idx.positive?
            pdf.text "Semana del #{fmt_dmy(days.first)} al #{fmt_dmy(days.last)}",
                     size: 12, style: :bold, align: :left
            pdf.move_down 6

            # Cabecera de tabla
            header = %w[Nombre RUT Horario] + days.map { |d| fmt_dm(d) }

            # Preconstruir grilla por usuario/día
            grid = Hash.new { |h, k| h[k] = {} }
            users.each do |u|
              days.each do |d|
                l = by_key[[u.id, d]]&.first
                grid[u.id][d] = Cell.new(l&.morning_done, l&.evening_done, (u.estado == false))
              end
            end

            # Filas: dos por usuario (Mañana / Tarde)
            rows = []
            users.each do |u|
              row_m = [u.nombre, u.rut, "Mañana"]
              row_e = ["", "", "Tarde"]

              days.each do |d|
                cell = grid[u.id][d]
                if cell&.estado_false
                  row_m << "—"
                  row_e << "—"
                else
                  row_m << (cell&.morning_done ? "Sí" : "No")
                  row_e << (cell&.evening_done ? "Sí" : "No")
                end
              end

              rows << row_m
              rows << row_e
            end

            # Render de tabla
            pdf.table([header] + rows, header: true, cell_style: { size: 9 }) do |t|
              t.row(0).font_style       = :bold
              t.row(0).background_color = "F0F0F0"
              t.cells.border_width      = 0.5
              # Columnas fijas para identificación; días se auto-ajustan
              t.columns(0).width = 150  # Nombre
              t.columns(1).width = 90   # RUT
              t.columns(2).width = 60   # Horario
            end
          end

          pdf.number_pages "<page>/<total>", at: [pdf.bounds.right - 40, 0], size: 9
        end.render
      end

      # Helpers
      def self.monday_of(date)
        date - ((date.cwday - 1)) # cwday: 1=lunes..7=domingo
      end

      def self.fmt_dmy(d) = d.strftime("%d-%m-%Y")
      def self.fmt_dm(d)  = d.strftime("%d-%m")
      def self.fmt_hhmm(hm)
        "%02d:%02d" % [hm[:h], hm[:m]]
      end
    end
  end
end
